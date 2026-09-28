import 'package:easypark/app.dart';
import 'package:easypark/core/router/app_router.dart';
import 'package:easypark/features/auth/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/auth_fixture.dart';

void main() {
  testWidgets(
    'authenticated planned routes remain available and forms redirect home',
    (tester) async {
      final auth = fixture()..status = AuthStatus.signedIn;
      final router = createAppRouter(auth: auth);
      addTearDown(router.dispose);
      addTearDown(auth.dispose);
      await tester.pumpWidget(EasyParkApp(router: router));
      await tester.pumpAndSettle();
      for (final entry in {
        '/login': 'Карта',
        '/register': 'Карта',
        '/home': 'Карта',
        '/parking/42': 'Парковка',
        '/parking/42/spaces': 'Парковочные места',
        '/space/42': 'Парковочное место',
        '/reservations': 'Бронирования',
        '/profile': 'Профиль',
      }.entries) {
        router.go(entry.key);
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
        if (entry.key == '/space/42') {
          expect(find.text('42'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'unknown route recovers; protected routes redirect without a session',
    (tester) async {
      final auth = fixture()..status = AuthStatus.signedIn;
      final router = createAppRouter(auth: auth, initialLocation: '/missing');
      addTearDown(router.dispose);
      addTearDown(auth.dispose);
      await tester.pumpWidget(EasyParkApp(router: router));
      await tester.pumpAndSettle();
      expect(find.text('Страница не найдена'), findsOneWidget);
      await tester.tap(find.text('На главную'));
      await tester.pumpAndSettle();
      expect(find.text('Карта'), findsOneWidget);
      await auth.invalidate();
      await tester.pumpAndSettle();
      router.go('/profile');
      await tester.pumpAndSettle();
      expect(find.text('Вход в систему'), findsOneWidget);
      expect(find.text('Профиль'), findsNothing);
    },
  );

  testWidgets('placeholder supports small display and larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final auth = fixture()..status = AuthStatus.signedIn;
    final router = createAppRouter(
      auth: auth,
      initialLocation: '/parking/42/spaces',
    );
    addTearDown(router.dispose);
    addTearDown(auth.dispose);
    await tester.pumpWidget(EasyParkApp(router: router));
    await tester.pumpAndSettle();
    expect(find.text('Парковочные места'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
