import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_tokens.dart';

/// Controlled presentation component; routing is the caller's responsibility.
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  }) : assert(selectedIndex >= 0 && selectedIndex < 3);
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  static const _items = [
    (LucideIcons.map, 'Карта'),
    (LucideIcons.list, 'Бронирования'),
    (LucideIcons.user, 'Профиль'),
  ];

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth < 450 &&
                MediaQuery.textScalerOf(context).scale(14) > 20;
            if (stacked) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < _items.length; index++)
                    _item(index, horizontal: true),
                ],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < _items.length; index++)
                    Expanded(child: _item(index)),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );

  Widget _item(int index, {bool horizontal = false}) => MergeSemantics(
    child: Semantics(
      selected: selectedIndex == index,
      child: TextButton(
        onPressed: () => onSelected(index),
        style: TextButton.styleFrom(
          foregroundColor: selectedIndex == index
              ? AppColors.primary
              : AppColors.bodySecondary,
          backgroundColor: selectedIndex == index
              ? AppColors.blueLight
              : Colors.transparent,
          minimumSize: Size(48, horizontal ? 48 : 56),
          padding: EdgeInsets.symmetric(
            horizontal: horizontal ? 12 : 4,
            vertical: 8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
        ),
        child: horizontal
            ? Row(
                children: [
                  Icon(_items[index].$1, size: 20),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(_items[index].$2, style: AppTypography.small),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_items[index].$1, size: 20),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _items[index].$2,
                    textAlign: TextAlign.center,
                    style: AppTypography.small,
                  ),
                ],
              ),
      ),
    ),
  );
}
