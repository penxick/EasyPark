import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.title,
    this.description,
    this.footer,
  });
  final Widget child;
  final String? title, description;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(AppRadii.card),
    ),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Semantics(
              header: true,
              child: Text(title!, style: AppTypography.title),
            ),
          if (description != null) ...[
            if (title != null) const SizedBox(height: 6),
            Text(
              description!,
              style: AppTypography.small.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ],
          if (title != null || description != null)
            const SizedBox(height: AppSpacing.xl),
          child,
          if (footer != null) ...[
            const SizedBox(height: AppSpacing.xl),
            footer!,
          ],
        ],
      ),
    ),
  );
}
