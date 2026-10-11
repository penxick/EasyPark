import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/state/load_controller.dart';
import '../../../core/state/load_state.dart';
import '../../../core/widgets/ui_kit.dart';
import '../models/admin_summary.dart';
import '../repositories/admin_repository.dart';
import '../widgets/admin_stat_card.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, required this.repository});
  final AdminRepository repository;
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with WidgetsBindingObserver {
  final _loader = LoadController<AdminSummary>();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  Future<void> _refresh() => _loader.load(widget.repository.summary);
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _refresh,
    child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppSpacing.page,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListenableBuilder(
            listenable: _loader,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Обзор системы',
                        style: AppTypography.heading2,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Обновить показатели',
                      onPressed: _loader.state is LoadInProgress
                          ? null
                          : _refresh,
                      icon: const Icon(LucideIcons.refreshCw),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                switch (_loader.state) {
                  LoadSuccess<AdminSummary>(data: final data) => _DashboardData(
                    data: data,
                  ),
                  LoadFailure<AdminSummary>(error: final error) => AppErrorView(
                    title: 'Ошибка загрузки аналитики',
                    message: error.message,
                    onRetry: _refresh,
                  ),
                  _ => const AppLoadingIndicator(
                    label: 'Загрузка показателей…',
                  ),
                },
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _DashboardData extends StatelessWidget {
  const _DashboardData({required this.data});
  final AdminSummary data;
  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Всего парковок', data.totalParkings),
      ('Всего мест', data.totalSpaces),
      ('Свободно', data.freeSpaces),
      ('Занято', data.occupiedSpaces),
      ('Забронировано', data.reservedSpaces),
      ('Недоступно', data.unavailableSpaces),
      ('Активные бронирования', data.activeReservations),
      ('Всего пользователей', data.totalUsers),
    ];
    final percent = data.occupancyPercent
        .toStringAsFixed(2)
        .replaceAll(RegExp(r'\.?0+$'), '')
        .replaceAll('.', ',');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data.totalParkings == 0) ...[
          const AppCard(
            title: 'Парковок пока нет',
            child: Text(
              'Показатели появятся по мере добавления парковок и мест.',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
            final columns = constraints.maxWidth >= 900
                ? 4
                : (constraints.maxWidth < 340 || largeText ? 1 : 2);
            final width =
                (constraints.maxWidth - AppSpacing.md * (columns - 1)) /
                columns;
            return Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (final metric in metrics)
                  SizedBox(
                    width: width,
                    child: AdminStatCard(
                      label: metric.$1,
                      value: metric.$2,
                      color: metric.$1 == 'Свободно'
                          ? AppColors.free
                          : AppColors.heading,
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          title: 'Загруженность парковок',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 8,
                children: [
                  const Text('Доступные места', style: AppTypography.small),
                  Text(
                    '$percent%',
                    style: AppTypography.title.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.control),
                child: LinearProgressIndicator(
                  value: data.occupancyPercent / 100,
                  minHeight: 12,
                  backgroundColor: AppColors.secondary,
                  color: AppColors.primary,
                  semanticsLabel: 'Загрузка доступных мест',
                  semanticsValue: '$percent%',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Занятые и забронированные места. Недоступные места исключены.',
                style: AppTypography.small,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
