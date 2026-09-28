import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import 'parking.dart';

class ParkingSummary extends StatelessWidget {
  const ParkingSummary({
    super.key,
    required this.parking,
    required this.onDetails,
  });
  final Parking parking;
  final VoidCallback onDetails;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: AppSpacing.page,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  parking.name,
                  style: AppTypography.heading2.copyWith(
                    color: AppColors.heading,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Закрыть',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.x),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            parking.address,
            style: const TextStyle(color: AppColors.bodySecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            parking.formattedPrice,
            style: AppTypography.heading3.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Данные о свободных местах пока недоступны.',
            style: TextStyle(color: AppColors.mutedForeground),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(label: 'Подробнее', fullWidth: true, onPressed: onDetails),
        ],
      ),
    ),
  );
}
