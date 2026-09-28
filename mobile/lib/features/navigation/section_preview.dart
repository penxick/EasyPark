import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';

/// Temporary content while each feature awaits its implementation stage.
class SectionPreview extends StatelessWidget {
  const SectionPreview({super.key, required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: AppSpacing.page,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 672),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(icon, size: 32, color: AppColors.primary),
              const SizedBox(height: AppSpacing.lg),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.bodySecondary),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
