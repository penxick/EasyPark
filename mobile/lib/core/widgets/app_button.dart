import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';
import 'app_loading_indicator.dart';

enum AppButtonVariant {
  primary,
  neutral,
  secondary,
  outline,
  ghost,
  destructive,
}

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.variant = AppButtonVariant.primary,
    this.fullWidth = false,
    this.accent = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final AppButtonVariant variant;
  final bool fullWidth;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final background = switch (variant) {
      AppButtonVariant.primary => AppColors.primary,
      AppButtonVariant.neutral => AppColors.neutral,
      AppButtonVariant.secondary => AppColors.secondary,
      AppButtonVariant.outline => AppColors.surface,
      AppButtonVariant.ghost => Colors.transparent,
      AppButtonVariant.destructive => AppColors.destructive,
    };
    final foreground = switch (variant) {
      AppButtonVariant.primary ||
      AppButtonVariant.neutral ||
      AppButtonVariant.destructive => Colors.white,
      _ => accent ? AppColors.primary : AppColors.neutral,
    };
    final button = TextButton(
      onPressed: loading ? null : onPressed,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 36)),
        tapTargetSize: MaterialTapTargetSize.padded,
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
        ),
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.focused)
                ? AppColors.focus
                : variant == AppButtonVariant.outline
                ? (accent ? AppColors.primary : AppColors.border)
                : Colors.transparent,
            width: states.contains(WidgetState.focused) ? 2 : 1,
          ),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.pressed) &&
                  variant == AppButtonVariant.primary
              ? AppColors.primaryPressed
              : background,
        ),
        foregroundColor: WidgetStatePropertyAll(foreground),
        overlayColor: WidgetStatePropertyAll(foreground.withValues(alpha: .08)),
        textStyle: WidgetStatePropertyAll(
          Theme.of(context).textTheme.labelLarge,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading) ...[
            AppLoadingIndicator(showLabel: false, size: 16, color: foreground),
            const SizedBox(width: AppSpacing.sm),
          ] else if (icon != null) ...[
            Icon(icon, size: 16),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    );
    return Opacity(
      opacity: onPressed == null || loading ? .5 : 1,
      child: fullWidth
          ? SizedBox(width: double.infinity, child: button)
          : button,
    );
  }
}
