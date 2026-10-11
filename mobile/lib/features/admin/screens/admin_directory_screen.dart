import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/state/load_controller.dart';
import '../../../core/state/load_state.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../auth/auth_user.dart';
import '../../profile/profile_screen.dart';
import '../../reservation/reservation.dart';
import '../models/admin_directory.dart';
import '../repositories/admin_directory_repository.dart';

class AdminDirectoryScreen extends StatefulWidget {
  const AdminDirectoryScreen({
    super.key,
    required this.repository,
    required this.users,
    this.id,
  });
  final AdminDirectoryRepository repository;
  final bool users;
  final String? id;
  @override
  State<AdminDirectoryScreen> createState() => _AdminDirectoryScreenState();
}

class _AdminDirectoryScreenState extends State<AdminDirectoryScreen>
    with WidgetsBindingObserver {
  final loader = LoadController<Object>();
  final scroll = ScrollController();
  int page = 1;
  String category = 'all';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    loader.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) load();
  }

  Future<void> load() => loader.load(() {
    if (widget.users) {
      return widget.id == null
          ? widget.repository.users(page)
          : widget.repository.user(widget.id!, page);
    }
    return widget.id == null
        ? widget.repository.reservations(page, category)
        : widget.repository.reservation(widget.id!);
  });
  void goPage(int value) {
    setState(() => page = value);
    if (scroll.hasClients) scroll.jumpTo(0);
    load();
  }

  Widget userCard(AuthUser user, {bool details = false}) => AppCard(
    title: 'Пользователь №${user.id}',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('ID: ${user.id}'),
        ProfileDetails(user: user),
        Text('Роль: ${user.role}'),
        if (!details) ...[
          const SizedBox(height: 12),
          AppButton(
            label: 'Открыть пользователя',
            variant: AppButtonVariant.outline,
            onPressed: () => context.push('/admin/users/${user.id}'),
          ),
        ],
      ],
    ),
  );
  Widget reservationCard(AdminReservation item, {bool details = false}) {
    final r = item.reservation;
    return AppCard(
      title: 'Бронирование №${r.id}',
      description: r.statusLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Пользователь: ${item.userName}'),
          if (details) Text('Email: ${item.email}'),
          Text('Парковка: ${item.parkingName}'),
          if (details) Text('Адрес: ${item.address}'),
          Text('Место: ${item.spaceCode}'),
          Text('Создано: ${reservationTime(item.createdAt)}'),
          Text('Начало: ${reservationTime(r.startTime)}'),
          Text('Окончание: ${reservationTime(r.endTime)}'),
          if (details) Text('Стоимость: ${rubles(r.totalPrice)}'),
          const SizedBox(height: 12),
          if (!details)
            AppButton(
              label: 'Открыть бронирование',
              variant: AppButtonVariant.outline,
              onPressed: () => context.push('/admin/reservations/${r.id}'),
            )
          else
            AppButton(
              label: 'Открыть пользователя',
              variant: AppButtonVariant.outline,
              onPressed: () => context.push('/admin/users/${r.userId}'),
            ),
        ],
      ),
    );
  }

  Widget pagination<T>(AdminPage<T> data) => Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      AppButton(
        label: 'Предыдущая',
        variant: AppButtonVariant.outline,
        onPressed: data.page > 1 ? () => goPage(data.page - 1) : null,
      ),
      Text(
        'Страница ${data.page} · всего ${data.totalPages}\nЗаписей: ${data.total}',
      ),
      AppButton(
        label: 'Следующая',
        variant: AppButtonVariant.outline,
        onPressed: data.page < data.totalPages
            ? () => goPage(data.page + 1)
            : null,
      ),
    ],
  );
  Widget history(AdminPage<AdminReservation> data) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (data.items.isEmpty)
        const AppCard(
          title: 'Бронирований нет',
          child: Text(
            'В выбранной категории или на этой странице пока нет записей.',
          ),
        ),
      for (final item in data.items) ...[
        reservationCard(item),
        const SizedBox(height: 12),
      ],
      const SizedBox(height: 12),
      pagination(data),
    ],
  );
  Widget content(Object data) => switch (data) {
    AdminPage<AuthUser>() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data.items.isEmpty)
          const AppCard(
            title: 'Пользователей нет',
            child: Text('На этой странице пока нет записей.'),
          ),
        for (final user in data.items) ...[
          userCard(user),
          const SizedBox(height: 12),
        ],
        pagination(data),
      ],
    ),
    AdminUserDetails() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        userCard(data.user, details: true),
        const SizedBox(height: 16),
        AppCard(
          title: 'Бронирования пользователя',
          child: Text(
            'Всего: ${data.reservationCount}\nАктивных: ${data.activeReservationCount}',
          ),
        ),
        const SizedBox(height: 16),
        history(data.reservations),
      ],
    ),
    AdminPage<AdminReservation>() => history(data),
    AdminReservation() => reservationCard(data, details: true),
    _ => const SizedBox.shrink(),
  };
  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: load,
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
                widget.users
                    ? (widget.id == null
                          ? 'Пользователи'
                          : 'Карточка пользователя')
                    : (widget.id == null
                          ? 'Бронирования'
                          : 'Информация о бронировании'),
                style: AppTypography.heading2,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (widget.id != null)
                    AppButton(
                      label: 'Назад к списку',
                      variant: AppButtonVariant.outline,
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go(
                            widget.users
                                ? '/admin/users'
                                : '/admin/reservations',
                          );
                        }
                      },
                    ),
                  AppButton(
                    label: 'Обновить',
                    variant: AppButtonVariant.outline,
                    onPressed: load,
                  ),
                ],
              ),
              if (!widget.users && widget.id == null) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in {
                      'all': 'Все',
                      for (final c in ReservationCategory.values)
                        c.name: c.label,
                    }.entries)
                      ChoiceChip(
                        label: Text(entry.value),
                        selected: category == entry.key,
                        selectedColor: AppColors.blueLight,
                        onSelected: (_) {
                          setState(() {
                            category = entry.key;
                            page = 1;
                          });
                          load();
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              ListenableBuilder(
                listenable: loader,
                builder: (context, _) => switch (loader.state) {
                  LoadSuccess<Object>(data: final data) => content(data),
                  LoadFailure<Object>(error: final error) => AppErrorView(
                    message: error.message,
                    onRetry: load,
                  ),
                  _ => const AppLoadingIndicator(),
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
