import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/app_bottom_navigation.dart';
import '../../core/widgets/app_top_bar.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: navigationShell.currentIndex == 0,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) navigationShell.goBranch(0);
    },
    child: Scaffold(
      appBar: const AppTopBar(title: 'EasyPark'),
      body: SafeArea(top: false, bottom: false, child: navigationShell),
      bottomNavigationBar: AppBottomNavigation(
        selectedIndex: navigationShell.currentIndex,
        onSelected: (index) {
          if (index != navigationShell.currentIndex) {
            navigationShell.goBranch(index);
          }
        },
      ),
    ),
  );
}
