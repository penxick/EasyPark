import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../models/admin_map_request.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../parking/parking_details.dart';
import '../repositories/admin_parking_repository.dart';

class AdminParkingsScreen extends StatefulWidget {
  const AdminParkingsScreen({
    super.key,
    required this.repository,
    this.id,
    this.edit = false,
    this.mapRequest,
  });
  final AdminParkingRepository repository;
  final String? id;
  final bool edit;
  final AdminMapRequest? mapRequest;
  @override
  State<AdminParkingsScreen> createState() => _AdminParkingsScreenState();
}

class _AdminParkingsScreenState extends State<AdminParkingsScreen> {
  static const labels = {
    'name': 'Название',
    'description': 'Описание',
    'address': 'Адрес',
    'pricePerHour': 'Стоимость за час',
    'workingHours': 'Режим работы',
    'latitude': 'Latitude',
    'longitude': 'Longitude',
  };
  final fields = {for (final key in labels.keys) key: TextEditingController()};
  final form = GlobalKey<FormState>();
  List<ParkingDetails> items = [];
  ParkingDetails? details;
  bool loading = true, busy = false;
  String? error;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    final point = widget.mapRequest?.point;
    if (point != null) {
      fields['latitude']!.text = point.latitude.toStringAsFixed(6);
      fields['longitude']!.text = point.longitude.toStringAsFixed(6);
    }
    load();
  }

  @override
  void dispose() {
    generation++;
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  String message(Object e, String fallback) {
    if (e is ApiException) {
      if (e.statusCode == 409) {
        return 'Не удалось удалить парковку: есть связанные данные или данные сейчас изменяются. История бронирований сохранена.';
      }
      if (e.statusCode == 404) return 'Парковка не найдена. Обновите список.';
      return '$fallback. ${e.message}';
    }
    return '$fallback. Повторите попытку.';
  }

  Future<void> load() async {
    final request = ++generation;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (widget.id != null) {
        final result = await widget.repository.one(widget.id!);
        if (!mounted || request != generation) return;
        details = result;
        final p = result.parking;
        final values = {
          'name': p.name,
          'description': result.description,
          'address': p.address,
          'pricePerHour': '${p.pricePerHour}',
          'workingHours': result.workingHours,
          'latitude': '${p.latitude}',
          'longitude': '${p.longitude}',
        };
        for (final key in fields.keys) {
          fields[key]!.text = values[key]!;
        }
      } else if (!widget.edit) {
        final result = await widget.repository.all();
        if (!mounted || request != generation) return;
        items = result;
      }
    } catch (e) {
      if (mounted && request == generation) {
        error = message(e, 'Не удалось загрузить парковки');
      }
    } finally {
      if (mounted && request == generation) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  double? number(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));
  String? validate(String key, String? input) {
    final value = (input ?? '').trim();
    if (value.isEmpty) return 'Обязательное поле';
    final limits = {
      'name': 200,
      'description': 10000,
      'address': 500,
      'workingHours': 200,
    };
    if (limits.containsKey(key)) {
      return value.runes.length > limits[key]!
          ? 'Не более ${limits[key]} символов'
          : null;
    }
    final n = number(value);
    final min = key == 'latitude'
        ? -90
        : key == 'longitude'
        ? -180
        : 0;
    final max = key == 'latitude'
        ? 90
        : key == 'longitude'
        ? 180
        : 99999999.99;
    if (n == null || !n.isFinite || n < min || n > max) {
      return 'Введите число от $min до $max';
    }
    if (key == 'pricePerHour' &&
        !RegExp(r'^\d+(?:[.,]\d{1,2})?$').hasMatch(value)) {
      return 'Стоимость: не более двух знаков после запятой';
    }
    return null;
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    final body = <String, Object>{
      for (final key in fields.keys)
        key: ['latitude', 'longitude', 'pricePerHour'].contains(key)
            ? number(fields[key]!.text)!
            : fields[key]!.text.trim(),
    };
    try {
      final result = await widget.repository.save(details?.parking.id, body);
      if (!mounted) return;
      if (widget.mapRequest != null && context.canPop()) {
        context.pop(result);
      } else {
        context.go('/admin/parkings/${result.parking.id}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = message(
            e,
            widget.id == null
                ? 'Не удалось создать парковку'
                : 'Не удалось сохранить парковку',
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> pickLocation() async {
    if (busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final lat = number(fields['latitude']!.text);
    final lng = number(fields['longitude']!.text);
    final initial =
        lat != null &&
            lng != null &&
            lat.isFinite &&
            lng.isFinite &&
            lat >= -90 &&
            lat <= 90 &&
            lng >= -180 &&
            lng <= 180
        ? LatLng(lat, lng)
        : null;
    final selected = await context.push<LatLng>(
      '/admin/parkings/pick-location',
      extra: initial,
    );
    if (!mounted || selected == null) return;
    setState(() {
      fields['latitude']!.text = selected.latitude.toStringAsFixed(6);
      fields['longitude']!.text = selected.longitude.toStringAsFixed(6);
    });
  }

  Future<void> remove(ParkingDetails item) async {
    if (busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить парковку?'),
        content: Text(
          '${item.parking.name}\nПарковка и связанные с ней данные могут стать недоступны.',
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
    if (confirmed != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.remove(item.parking.id);
      if (!mounted) return;
      if (widget.id != null) {
        context.go('/admin/parkings');
      } else {
        await load();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = message(e, 'Не удалось удалить парковку');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Widget card(ParkingDetails item, {bool full = false}) {
    final p = item.parking;
    return AppCard(
      title: p.name,
      description: p.address,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(p.formattedPrice, style: AppTypography.title),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Мест: ${item.totalSpaces ?? '—'} · Свободно: ${item.freeSpaces ?? '—'}',
          ),
          Text('Режим работы: ${item.workingHours}'),
          if (full) ...[
            const SizedBox(height: AppSpacing.md),
            Text(item.description),
            Text('Latitude: ${p.latitude}\nLongitude: ${p.longitude}'),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!full)
                AppButton(
                  label: 'Открыть',
                  onPressed: busy
                      ? null
                      : () => context.go('/admin/parkings/${p.id}'),
                ),
              AppButton(
                label: 'Редактировать',
                variant: AppButtonVariant.outline,
                onPressed: busy
                    ? null
                    : () => context.go('/admin/parkings/${p.id}/edit'),
              ),
              AppButton(
                label: 'Управлять местами',
                variant: AppButtonVariant.outline,
                onPressed: busy
                    ? null
                    : () => context.go('/admin/parkings/${p.id}/spaces'),
              ),
            ],
          ),
          const Divider(height: 32),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: 'Удалить парковку',
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
    onRefresh: widget.edit || busy ? () async {} : load,
    child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppSpacing.page,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.edit
                    ? (widget.id == null
                          ? 'Добавить парковку'
                          : 'Редактировать парковку')
                    : widget.id == null
                    ? 'Парковки'
                    : 'Информация о парковке',
                style: AppTypography.heading2,
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (widget.mapRequest != null && context.canPop())
                    AppButton(
                      label: 'Вернуться к карте',
                      variant: AppButtonVariant.outline,
                      onPressed: busy ? null : () => context.pop(),
                    ),
                  if (widget.id != null || widget.edit)
                    AppButton(
                      label: 'К списку парковок',
                      variant: AppButtonVariant.outline,
                      onPressed: busy
                          ? null
                          : () => context.go('/admin/parkings'),
                    ),
                  if (!widget.edit && widget.id == null)
                    AppButton(
                      label: 'Открыть карту',
                      variant: AppButtonVariant.outline,
                      onPressed: busy
                          ? null
                          : () => context.go('/admin/parkings/map'),
                    ),
                  if (!widget.edit && widget.id == null)
                    AppButton(
                      label: '+ Добавить парковку',
                      onPressed: busy
                          ? null
                          : () => context.go('/admin/parkings/new'),
                    ),
                  if (!widget.edit)
                    AppButton(
                      label: 'Обновить',
                      variant: AppButtonVariant.outline,
                      onPressed: busy || loading ? null : load,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (loading)
                const AppLoadingIndicator()
              else ...[
                if (error != null) ...[
                  AppErrorView(
                    title: 'Не удалось выполнить действие',
                    message: error!,
                    onRetry: busy
                        ? null
                        : widget.edit && (widget.id == null || details != null)
                        ? save
                        : load,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (widget.edit && (widget.id == null || details != null))
                  AppCard(
                    child: Form(
                      key: form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppButton(
                            label: 'Выбрать положение на карте',
                            variant: AppButtonVariant.outline,
                            onPressed: busy ? null : pickLocation,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          for (final key in fields.keys) ...[
                            AppTextField(
                              key: ValueKey('parking-$key'),
                              label: labels[key]!,
                              controller: fields[key],
                              enabled: !busy,
                              keyboardType:
                                  [
                                    'latitude',
                                    'longitude',
                                    'pricePerHour',
                                  ].contains(key)
                                  ? const TextInputType.numberWithOptions(
                                      decimal: true,
                                      signed: true,
                                    )
                                  : TextInputType.text,
                              validator: (value) => validate(key, value),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          AppButton(
                            label: widget.id == null ? 'Создать' : 'Сохранить',
                            loading: busy,
                            onPressed: save,
                          ),
                        ],
                      ),
                    ),
                  )
                else if (!widget.edit && details != null)
                  card(details!, full: true)
                else if (!widget.edit && widget.id == null) ...[
                  if (items.isEmpty && error == null)
                    const AppCard(
                      title: 'Парковок пока нет',
                      child: Text('Добавьте первую парковку.'),
                    ),
                  for (final item in items) ...[
                    card(item),
                    const SizedBox(height: AppSpacing.md),
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
