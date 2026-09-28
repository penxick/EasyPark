import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_tokens.dart';
import 'app_button.dart';

/// Accepts a user-facing message, never a raw exception or server response.
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.message,
    this.title = 'Не удалось загрузить данные',
    this.onRetry,
  });
  final String message, title;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: AppSpacing.page,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const ExcludeSemantics(
          child: Icon(
            LucideIcons.circleAlert,
            size: 32,
            color: AppColors.destructive,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          liveRegion: true,
          child: Column(
            children: [
              Text(
                title,
                style: AppTypography.title,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                style: AppTypography.body.copyWith(
                  color: AppColors.bodySecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Повторить',
            icon: LucideIcons.refreshCw,
            onPressed: onRetry,
          ),
        ],
      ],
    ),
  );
}
