import 'package:flutter/material.dart';
import '../../../core/state/load_controller.dart';
import '../../../core/state/load_state.dart';
import '../../../core/widgets/ui_kit.dart';
import '../models/admin_summary.dart';
import '../models/admin_directory.dart';
import '../models/admin_parking_analytics.dart';
import '../repositories/admin_repository.dart';
import '../widgets/admin_stat_card.dart';
import '../widgets/admin_analytics_charts.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key, required this.repository});
  final AdminRepository repository;
  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen>
    with WidgetsBindingObserver {
  final summary = LoadController<AdminSummary>();
  final parkings = LoadController<AdminPage<AdminParkingAnalytics>>();
  int page = 1;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  Future<void> loadPage() =>
      parkings.load(() => widget.repository.parkings(page));
  Future<void> refresh() async {
    await Future.wait([summary.load(widget.repository.summary), loadPage()]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    summary.dispose();
    parkings.dispose();
    super.dispose();
  }

  Widget overview(AdminSummary data) {
    final metrics = [
      ('Парковки', data.totalParkings),
      ('Парковочные места', data.totalSpaces),
      ('Пользователи', data.totalUsers),
      ('Все бронирования', data.totalReservations),
      ('Активные бронирования', data.activeReservations),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                constraints.maxWidth >= 600 &&
                    MediaQuery.textScalerOf(context).scale(16) < 25
                ? 2
                : 1;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final metric in metrics)
                  SizedBox(
                    width:
                        (constraints.maxWidth - 12 * (columns - 1)) / columns,
                    child: AdminStatCard(label: metric.$1, value: metric.$2),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        AppCard(
          title: 'Общая загрузка',
          child: Column(
            children: [
              AdminAnalyticsBar(
                label: 'Доступные места',
                value: '${data.occupancyPercent}%',
                fraction: data.occupancyPercent / 100,
              ),
              const Text(
                'Занятые и забронированные места. Недоступные места исключены.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AdminStatusChart(data: data),
      ],
    );
  }

  Widget parkingData(AdminPage<AdminParkingAnalytics> data) {
    final maximum = data.items.fold<int>(
      0,
      (a, p) =>
          a > p.metrics.totalReservations ? a : p.metrics.totalReservations,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data.items.isEmpty)
          const AppCard(
            title: 'Нет парковок на этой странице',
            child: Text(
              'Добавьте парковку или вернитесь на предыдущую страницу.',
            ),
          ),
        for (final parking in data.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              title: parking.name,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Всего мест: ${parking.metrics.totalSpaces}'),
                  Text('Свободно: ${parking.metrics.freeSpaces}'),
                  Text('Занято: ${parking.metrics.occupiedSpaces}'),
                  Text('Забронировано: ${parking.metrics.reservedSpaces}'),
                  Text('Недоступно: ${parking.metrics.unavailableSpaces}'),
                  AdminAnalyticsBar(
                    label: 'Загрузка доступных мест',
                    value: '${parking.metrics.occupancyPercent}%',
                    fraction: parking.metrics.occupancyPercent / 100,
                  ),
                  Text('Бронирований: ${parking.metrics.totalReservations}'),
                  Text('Активных: ${parking.metrics.activeReservations}'),
                ],
              ),
            ),
          ),
        if (data.items.isNotEmpty)
          AppCard(
            title: 'Сравнение бронирований',
            description:
                'Парковки текущей страницы. Шкала — максимум на странице.',
            child: Column(
              children: [
                for (final parking in data.items)
                  AdminAnalyticsBar(
                    label: parking.name,
                    value: '${parking.metrics.totalReservations}',
                    fraction: maximum == 0
                        ? 0
                        : parking.metrics.totalReservations / maximum,
                  ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Text(
          'Страница ${data.page} из ${data.totalPages == 0 ? 1 : data.totalPages}. Всего парковок: ${data.total}',
        ),
        Wrap(
          spacing: 12,
          children: [
            TextButton(
              onPressed: page > 1
                  ? () {
                      page--;
                      loadPage();
                    }
                  : null,
              child: const Text('Назад'),
            ),
            TextButton(
              onPressed: page < data.totalPages
                  ? () {
                      page++;
                      loadPage();
                    }
                  : null,
              child: const Text('Далее'),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: refresh,
    child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppSpacing.page,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Аналитика', style: AppTypography.heading2),
                  ),
                  IconButton(
                    tooltip: 'Обновить аналитику',
                    onPressed: refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListenableBuilder(
                listenable: summary,
                builder: (context, _) => switch (summary.state) {
                  LoadSuccess<AdminSummary>(data: final data) => overview(data),
                  LoadFailure<AdminSummary>(error: final error) => AppErrorView(
                    title: 'Ошибка загрузки аналитики',
                    message: error.message,
                    onRetry: refresh,
                  ),
                  _ => const AppLoadingIndicator(),
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Статистика по парковкам',
                style: AppTypography.heading2,
              ),
              const SizedBox(height: 16),
              ListenableBuilder(
                listenable: parkings,
                builder: (context, _) => switch (parkings.state) {
                  LoadSuccess<AdminPage<AdminParkingAnalytics>>(
                    data: final data,
                  ) =>
                    parkingData(data),
                  LoadFailure<AdminPage<AdminParkingAnalytics>>(
                    error: final error,
                  ) =>
                    AppErrorView(
                      title: 'Ошибка загрузки парковок',
                      message: error.message,
                      onRetry: loadPage,
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
