import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/widgets/ui_kit.dart';

const adminSections = [
  ('/admin', 'Главная', LucideIcons.layoutDashboard),
  ('/admin/parkings', 'Парковки', LucideIcons.mapPin),
  ('/admin/reservations', 'Бронирования', LucideIcons.calendar),
  ('/admin/users', 'Пользователи', LucideIcons.users),
  ('/admin/analytics', 'Аналитика', LucideIcons.chartColumn),
  ('/admin/profile', 'Профиль', LucideIcons.user),
];

class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.child, required this.path});
  final Widget child;
  final String path;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide =
          constraints.maxWidth >= 1000 &&
          MediaQuery.textScalerOf(context).scale(16) <= 24;
      final selected = adminSections.indexWhere(
        (section) =>
            section.$1 == path ||
            (section.$1 != '/admin' && path.startsWith('${section.$1}/')),
      );
      Widget menu({required bool drawer}) => Material(
        color: AppColors.surface,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Администрирование', style: AppTypography.title),
            ),
            for (var index = 0; index < adminSections.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  key: ValueKey('admin-nav-$index'),
                  selected: index == selected,
                  selectedTileColor: AppColors.blueLight,
                  selectedColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.control),
                  ),
                  leading: Icon(adminSections[index].$3, size: 20),
                  title: Text(adminSections[index].$2),
                  onTap: () {
                    if (drawer) Navigator.of(context).pop();
                    context.go(adminSections[index].$1);
                  },
                ),
              ),
          ],
        ),
      );
      return PopScope(
        canPop: path == '/admin' || GoRouter.of(context).canPop(),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) context.go('/admin');
        },
        child: Scaffold(
          appBar: AppTopBar(
            title: 'EasyPark · ADMIN',
            leading: wide
                ? null
                : Builder(
                    builder: (context) => IconButton(
                      tooltip: 'Административное меню',
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      icon: const Icon(LucideIcons.menu, size: 20),
                    ),
                  ),
          ),
          drawer: wide
              ? null
              : Drawer(child: SafeArea(child: menu(drawer: true))),
          body: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (wide) ...[
                  SizedBox(width: 260, child: menu(drawer: false)),
                  const VerticalDivider(width: 1),
                ],
                Expanded(child: child),
              ],
            ),
          ),
        ),
      );
    },
  );
}
