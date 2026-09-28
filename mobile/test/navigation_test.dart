import 'package:easypark/app.dart';
import 'package:easypark/core/router/app_router.dart';
import 'package:easypark/core/widgets/app_bottom_navigation.dart';
import 'package:easypark/features/auth/auth_controller.dart';
import 'package:easypark/features/map/map_screen.dart';
import 'package:easypark/features/profile/profile_screen.dart';
import 'package:easypark/features/reservation/reservations_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/auth_fixture.dart';

void main() {
  testWidgets('tabs, direct links, back and session invalidation', (
    tester,
  ) async {
    final auth = fixture()..status = AuthStatus.signedIn;
    final router = createAppRouter(auth: auth, initialLocation: '/profile');
    addTearDown(router.dispose);
    addTearDown(auth.dispose);
    await tester.pumpWidget(EasyParkApp(router: router));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(
      tester
          .widget<AppBottomNavigation>(find.byType(AppBottomNavigation))
          .selectedIndex,
      2,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(MapScreen), findsOneWidget);
    final mapElement = tester.element(find.byType(MapScreen));
    for (final label in ['Бронирования', 'Профиль', 'Профиль', 'Карта']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(router.canPop(), isFalse);
    }
    expect(tester.element(find.byType(MapScreen)), same(mapElement));
    router.go('/reservations');
    await tester.pumpAndSettle();
    expect(find.byType(ReservationsScreen), findsOneWidget);
    expect(
      tester
          .widget<AppBottomNavigation>(find.byType(AppBottomNavigation))
          .selectedIndex,
      1,
    );
    await auth.invalidate();
    await tester.pumpAndSettle();
    expect(find.byType(AppBottomNavigation), findsNothing);
    expect(find.text('Вход в систему'), findsOneWidget);
  });

  testWidgets('all sections fit small screens and enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final auth = fixture()..status = AuthStatus.signedIn;
    final router = createAppRouter(auth: auth);
    addTearDown(router.dispose);
    addTearDown(auth.dispose);
    await tester.pumpWidget(EasyParkApp(router: router));
    await tester.pumpAndSettle();
    for (final label in ['Карта', 'Бронирования', 'Профиль']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(label).hitTestable(), findsOneWidget);
    }
  });
}
