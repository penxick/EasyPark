import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_tokens.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({super.key, required this.title, this.onBack, this.actions});
  final String title;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: 64,
    automaticallyImplyLeading: false,
    leading: onBack == null
        ? null
        : IconButton(
            tooltip: 'Назад',
            icon: const Icon(LucideIcons.arrowLeft, size: 20),
            onPressed: onBack,
          ),
    titleSpacing: onBack == null ? AppSpacing.lg : 0,
    title: Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(
        context,
      ).textTheme.headlineSmall?.copyWith(color: AppColors.heading),
    ),
    actions: actions,
    shape: const Border(bottom: BorderSide(color: AppColors.border)),
  );
}
