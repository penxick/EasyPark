import 'package:flutter/material.dart';
import '../../../core/widgets/ui_kit.dart';

class AdminStatCard extends StatelessWidget {
  const AdminStatCard({
    super.key,
    required this.label,
    required this.value,
    this.color = AppColors.heading,
  });
  final String label;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.small.copyWith(color: AppColors.mutedForeground),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('$value', style: AppTypography.heading1.copyWith(color: color)),
      ],
    ),
  );
}
