import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../parking/parking_layout.dart';
import '../../parking/parking_space.dart';
import '../models/admin_space.dart';
import '../repositories/admin_spaces_repository.dart';

class AdminSpacesScreen extends StatefulWidget {
  const AdminSpacesScreen({
    super.key,
    required this.parkingId,
    required this.repository,
  });
  final String parkingId;
  final AdminSpacesRepository repository;
  @override
  State<AdminSpacesScreen> createState() => _AdminSpacesScreenState();
}

class _AdminSpacesScreenState extends State<AdminSpacesScreen>
    with WidgetsBindingObserver {
  final form = GlobalKey<FormState>();
  final scroll = ScrollController();
  final code = TextEditingController(),
      x = TextEditingController(),
      y = TextEditingController(),
      polygon = TextEditingController();
  List<AdminSpace> spaces = [];
  AdminSpace? editing;
  bool loading = true, busy = false, showForm = false, available = true;
  String name = '', error = '';
  int generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !showForm && !busy) load();
  }

  @override
  void dispose() {
    generation++;
    WidgetsBinding.instance.removeObserver(this);
    for (final c in [code, x, y, polygon]) {
      c.dispose();
    }
    scroll.dispose();
    super.dispose();
  }

  void top() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && scroll.hasClients) scroll.jumpTo(0);
  });
  String message(Object e, String action) {
    if (e is ApiException) {
      return switch (e.code) {
        'SPACE_CODE_EXISTS' =>
          'Парковочное место с таким кодом уже существует.',
        'SPACE_HAS_RESERVATIONS' =>
          'Нельзя удалить место с историей бронирований.',
        'SPACE_BUSY' => 'Место сейчас изменяется. Повторите попытку.',
        'SPACE_HAS_RELATED_DATA' =>
          'Операция невозможна: связанные данные места изменились.',
        _ =>
          '$action. ${e.statusCode == 409 ? 'Есть связанные данные или конфликт изменения.' : e.message}',
      };
    }
    return '$action. Повторите попытку.';
  }

  Future<void> load() async {
    final request = ++generation;
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final result = await widget.repository.load(widget.parkingId);
      if (!mounted || request != generation) return;
      name = result.name;
      spaces = result.spaces;
    } catch (e) {
      if (mounted && request == generation) {
        error = message(e, 'Не удалось загрузить места');
      }
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  void edit([AdminSpace? item]) {
    setState(() {
      editing = item;
      showForm = true;
      error = '';
      code.text = item?.space.code ?? '';
      x.text = item?.space.x.toString() ?? '0';
      y.text = item?.space.y.toString() ?? '0';
      polygon.text = item?.polygonText ?? '';
      available = item?.space.status != SpaceStatus.unavailable;
    });
    top();
  }

  double? number(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));
  String? coordinate(String? value) {
    final n = number(value ?? '');
    return n == null || !n.isFinite || n < 0
        ? 'Введите конечное число не меньше 0'
        : null;
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    final item = editing;
    final body = <String, Object?>{};
    if (item == null || code.text.trim() != item.space.code) {
      body['code'] = code.text.trim();
    }
    if (item == null || number(x.text) != item.space.x) {
      body['x'] = number(x.text);
    }
    if (item == null || number(y.text) != item.space.y) {
      body['y'] = number(y.text);
    }
    if (item == null || polygon.text != item.polygonText) {
      body['polygon'] = AdminSpace.parsePolygon(polygon.text);
    }
    if (item != null &&
        available != (item.space.status != SpaceStatus.unavailable)) {
      body['available'] = available;
    }
    if (body.isEmpty) {
      setState(() => showForm = false);
      await load();
      return;
    }
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await widget.repository.save(widget.parkingId, item?.space.id, body);
      if (!mounted) return;
      setState(() => showForm = false);
      await load();
      top();
    } catch (e) {
      if (mounted) {
        setState(() => error = message(e, 'Не удалось сохранить место'));
        top();
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> changeAvailability(AdminSpace item) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await widget.repository.save(widget.parkingId, item.space.id, {
        'available': item.space.status == SpaceStatus.unavailable,
      });
      if (mounted) await load();
    } catch (e) {
      if (mounted) {
        setState(() => error = message(e, 'Не удалось изменить доступность'));
        top();
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> remove(AdminSpace item) async {
    if (busy) return;
    setState(() => busy = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить парковочное место?'),
        content: Text(
          'Место ${item.space.code} будет удалено. Место с историей бронирований удалить нельзя.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          AppButton(
            label: 'Удалить',
            variant: AppButtonVariant.destructive,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (!mounted) return;
    try {
      if (confirmed == true) {
        await widget.repository.remove(item.space.id);
        if (mounted) await load();
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = message(e, 'Не удалось удалить место'));
        top();
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget spaceCard(AdminSpace item) {
    final s = item.space;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: spaceStatusColor(s.displayStatus),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  s.code,
                  style: AppTypography.title.copyWith(
                    color: s.displayStatus == SpaceStatus.reserved
                        ? AppColors.foreground
                        : Colors.white,
                  ),
                ),
              ),
              Text(
                '${spaceStatusLabel(s.displayStatus)} · ${s.status.name.toUpperCase()}',
                style: AppTypography.title,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Физическая занятость (physicalOccupied): ${s.physicalOccupied ? 'да' : 'нет'}',
          ),
          Text(
            'Активное бронирование: ${item.hasActiveReservation ? 'есть' : 'нет'}',
          ),
          Text('На схеме: X ${s.x} · Y ${s.y}'),
          Text(
            item.polygon == null
                ? 'Контур не задан'
                : 'Вершин контура: ${item.polygon!.length}',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppButton(
                label: 'Редактировать',
                variant: AppButtonVariant.outline,
                onPressed: busy ? null : () => edit(item),
              ),
              AppButton(
                label: s.status == SpaceStatus.unavailable
                    ? 'Вернуть в эксплуатацию'
                    : 'Отключить',
                variant: AppButtonVariant.outline,
                onPressed: busy ? null : () => changeAvailability(item),
              ),
            ],
          ),
          const Divider(height: 32),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: 'Удалить место',
              variant: AppButtonVariant.destructive,
              onPressed: busy ? null : () => remove(item),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: showForm || busy ? () async {} : load,
    child: SingleChildScrollView(
      controller: scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppSpacing.page,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                showForm
                    ? (editing == null
                          ? 'Добавить место'
                          : 'Редактировать место')
                    : 'Парковочные места',
                style: AppTypography.heading2,
              ),
              if (name.isNotEmpty) Text(name),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AppButton(
                    label: 'К парковке',
                    variant: AppButtonVariant.outline,
                    onPressed: busy
                        ? null
                        : () =>
                              context.go('/admin/parkings/${widget.parkingId}'),
                  ),
                  if (!showForm) ...[
                    AppButton(
                      label: '+ Добавить место',
                      onPressed: busy || loading || name.isEmpty
                          ? null
                          : () => edit(),
                    ),
                    AppButton(
                      label: 'Обновить',
                      variant: AppButtonVariant.outline,
                      onPressed: busy || loading ? null : load,
                    ),
                  ] else
                    AppButton(
                      label: 'Отмена',
                      variant: AppButtonVariant.outline,
                      onPressed: busy
                          ? null
                          : () {
                              setState(() => showForm = false);
                              load();
                            },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (loading)
                const AppLoadingIndicator()
              else ...[
                if (error.isNotEmpty)
                  AppErrorView(
                    message: error,
                    onRetry: busy
                        ? null
                        : showForm
                        ? save
                        : load,
                  ),
                if (showForm)
                  AppCard(
                    child: Form(
                      key: form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppTextField(
                            key: const ValueKey('space-code'),
                            label: 'Код места',
                            controller: code,
                            enabled: !busy,
                            validator: (value) {
                              final v = (value ?? '').trim();
                              if (v.isEmpty || v.runes.length > 20) {
                                return 'Код: от 1 до 20 символов';
                              }
                              if (spaces.any(
                                (s) =>
                                    s.space.id != editing?.space.id &&
                                    s.space.code == v,
                              )) {
                                return 'Парковочное место с таким кодом уже существует.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          for (final entry in [('x', x), ('y', y)]) ...[
                            AppTextField(
                              key: ValueKey('space-${entry.$1}'),
                              label: '${entry.$1.toUpperCase()} на схеме',
                              controller: entry.$2,
                              enabled: !busy,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: coordinate,
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            key: const ValueKey('space-polygon'),
                            controller: polygon,
                            enabled: !busy,
                            minLines: 3,
                            maxLines: 8,
                            decoration: const InputDecoration(
                              labelText: 'Контур места (polygon)',
                              helperText:
                                  'Одна вершина на строку: X; Y. От 3 до 1000 вершин. Пусто — без контура.',
                              helperMaxLines: 4,
                            ),
                            validator: (value) {
                              try {
                                AdminSpace.parsePolygon(value ?? '');
                                return null;
                              } catch (_) {
                                return 'Укажите 3–1000 строк с парой чисел X; Y';
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          if (editing != null)
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Место доступно для эксплуатации',
                              ),
                              value: available,
                              onChanged: busy
                                  ? null
                                  : (value) =>
                                        setState(() => available = value),
                            ),
                          const Text(
                            'Физическая занятость и бронирования определяются системой. Отключение места не отменяет существующую бронь.',
                          ),
                          const SizedBox(height: 16),
                          AppButton(
                            label: editing == null ? 'Создать' : 'Сохранить',
                            loading: busy,
                            onPressed: save,
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  if (spaces.isEmpty && error.isEmpty)
                    const AppCard(
                      title: 'Мест пока нет',
                      child: Text('Добавьте первое парковочное место.'),
                    ),
                  for (final item in spaces) ...[
                    spaceCard(item),
                    const SizedBox(height: 12),
                  ],
                ],
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
