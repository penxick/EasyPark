import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/api/api_exception.dart';
import '../../core/router/app_routes.dart';
import '../../core/state/load_controller.dart';
import '../../core/state/load_state.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_error_view.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../../core/widgets/app_top_bar.dart';
import '../map/parking_repository.dart';
import 'parking_details.dart';

class ParkingDetailsScreen extends StatefulWidget {
  const ParkingDetailsScreen({
    super.key,
    required this.id,
    required this.repository,
  });
  final String id;
  final ParkingRepository repository;
  @override
  State<ParkingDetailsScreen> createState() => _ParkingDetailsScreenState();
}

class _ParkingDetailsScreenState extends State<ParkingDetailsScreen> {
  final _loader = LoadController<ParkingDetails>();
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ParkingDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) _load();
  }

  void _load() =>
      unawaited(_loader.load(() => widget.repository.fetchOne(widget.id)));
  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppTopBar(title: 'Парковка', onBack: _back),
    body: SafeArea(
      top: false,
      child: ListenableBuilder(
        listenable: _loader,
        builder: (context, _) => switch (_loader.state) {
          LoadSuccess<ParkingDetails>(data: final details) =>
            SingleChildScrollView(
              padding: AppSpacing.page,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 672),
                  child: ParkingDetailsContent(
                    details: details,
                    onRefresh: _load,
                    onChooseSpace: () =>
                        context.push('/parking/${details.parking.id}/spaces'),
                  ),
                ),
              ),
            ),
          LoadFailure<ParkingDetails>(error: final error) => Center(
            child: SingleChildScrollView(
              child: AppErrorView(
                title: error.kind == ApiErrorKind.notFound
                    ? 'Парковка не найдена'
                    : 'Не удалось загрузить парковку',
                message: error.kind == ApiErrorKind.notFound
                    ? 'Возможно, эта парковка больше недоступна.'
                    : error.message,
                onRetry: error.kind == ApiErrorKind.invalidRequest
                    ? null
                    : _load,
              ),
            ),
          ),
          _ => const Center(
            child: AppLoadingIndicator(label: 'Загрузка парковки…'),
          ),
        },
      ),
    ),
  );
}

class ParkingDetailsContent extends StatelessWidget {
  const ParkingDetailsContent({
    super.key,
    required this.details,
    required this.onRefresh,
    this.onChooseSpace,
  });
  final ParkingDetails details;
  final VoidCallback onRefresh;
  final VoidCallback? onChooseSpace;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            details.parking.name,
            style: AppTypography.heading2.copyWith(color: AppColors.heading),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _Info(
          icon: LucideIcons.mapPin,
          label: 'Адрес',
          value: details.parking.address,
        ),
        const SizedBox(height: AppSpacing.lg),
        _Info(
          icon: LucideIcons.coins,
          label: 'Стоимость',
          value: details.parking.formattedPrice,
          accent: true,
        ),
        const SizedBox(height: AppSpacing.lg),
        _Info(
          icon: LucideIcons.clock,
          label: 'Режим работы',
          value: details.workingHours,
        ),
        const SizedBox(height: AppSpacing.xl),
        LayoutBuilder(
          builder: (context, constraints) {
            final stats = [
              _Count(
                label: 'Свободно',
                value: details.freeSpaces,
                available: true,
              ),
              _Count(label: 'Всего', value: details.totalSpaces),
            ];
            if (constraints.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(14) > 20) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  stats[0],
                  const SizedBox(height: AppSpacing.sm),
                  stats[1],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: stats[0]),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: stats[1]),
              ],
            );
          },
        ),
        if (details.freeSpaces == null || details.totalSpaces == null) ...[
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Информация о парковочных местах пока недоступна.',
            style: TextStyle(color: AppColors.mutedForeground),
          ),
        ],
        if (details.description.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(
            details.description,
            style: const TextStyle(color: AppColors.bodySecondary),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        TextButton.icon(
          onPressed: onRefresh,
          icon: const Icon(LucideIcons.refreshCw, size: 18),
          label: const Text('Обновить данные'),
        ),
        if (onChooseSpace != null)
          AppButton(
            label: 'Выбрать место',
            fullWidth: true,
            onPressed: onChooseSpace,
          ),
      ],
    ),
  );
}

class _Info extends StatelessWidget {
  const _Info({
    required this.icon,
    required this.label,
    required this.value,
    this.accent = false,
  });
  final IconData icon;
  final String label, value;
  final bool accent;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20, color: AppColors.bodySecondary),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.small.copyWith(
                color: AppColors.bodySecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: AppTypography.body.copyWith(
                color: accent ? AppColors.primary : AppColors.foreground,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Count extends StatelessWidget {
  const _Count({required this.label, this.value, this.available = false});
  final String label;
  final int? value;
  final bool available;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: available && value != null
          ? const Color(0xFFF0FDF4)
          : AppColors.background,
      borderRadius: BorderRadius.circular(AppRadii.control),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.small.copyWith(color: AppColors.bodySecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(value?.toString() ?? 'Нет данных', style: AppTypography.title),
      ],
    ),
  );
}
