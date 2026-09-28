import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    super.key,
    this.label = 'Загрузка…',
    this.showLabel = true,
    this.size = 24,
    this.color,
  });
  final String label;
  final bool showLabel;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    liveRegion: true,
    child: ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: size,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: color ?? AppColors.primary,
            ),
          ),
          if (showLabel) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(label, textAlign: TextAlign.center),
          ],
        ],
      ),
    ),
  );
}
