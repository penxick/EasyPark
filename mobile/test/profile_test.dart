import 'dart:async';
import 'package:easypark/app.dart';
import 'package:easypark/core/router/app_router.dart';
import 'package:easypark/features/auth/auth_controller.dart';
import 'package:easypark/features/auth/auth_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'support/auth_fixture.dart';

Future<void> tapProfileText(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  test(
    'logout deletes token offline, clears identity and prevents restoration',
    () async {
      var calls = 0;
      final tokens = MemoryTokens('jwt');
      final auth =
          fixture(
              tokens: tokens,
              handler: (_) async {
                calls++;
                throw http.ClientException('offline');
              },
            )
            ..status = AuthStatus.signedIn
            ..user = AuthUser.fromJson(testUser);
      addTearDown(auth.dispose);
      await auth.logout();
      expect(tokens.value, isNull);
      expect(auth.user, isNull);
      expect(auth.status, AuthStatus.signedOut);
      await auth.restore();
      expect(auth.status, AuthStatus.signedOut);
      expect(calls, 0);
    },
  );
  test(
    'storage deletion failure remains protected; retry deletes rather than restores old identity',
    () async {
      var calls = 0;
      final tokens = MemoryTokens('jwt')..failDelete = true;
      final auth = fixture(
        tokens: tokens,
        handler: (_) async {
          calls++;
          return jsonResponse(testUser);
        },
      )..status = AuthStatus.signedIn;
      addTearDown(auth.dispose);
      await auth.logout();
      expect(auth.status, AuthStatus.restoreError);
      expect(auth.logoutPending, isTrue);
      await auth.restore();
      expect(auth.status, AuthStatus.restoreError);
      expect(calls, 0);
      tokens.failDelete = false;
      await auth.restore();
      expect(tokens.value, isNull);
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.logoutPending, isFalse);
      expect(calls, 0);
    },
  );
  testWidgets(
    'profile uses JWT GET me, retries errors and updates current data',
    (tester) async {
      var code = 503, name = 'Новое имя', calls = 0;
      final auth = fixture(
        tokens: MemoryTokens('jwt'),
        handler: (request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/users/me');
          expect(request.headers['Authorization'], 'Bearer jwt');
          calls++;
          return jsonResponse({...testUser, 'name': name}, code);
        },
      )..status = AuthStatus.signedIn;
      final router = createAppRouter(auth: auth, initialLocation: '/profile');
      addTearDown(router.dispose);
      addTearDown(auth.dispose);
      await tester.pumpWidget(EasyParkApp(router: router));
      await tester.pumpAndSettle();
      expect(find.text('Не удалось загрузить профиль'), findsOneWidget);
      expect(find.text('Выйти'), findsOneWidget);
      code = 200;
      await tapProfileText(tester, 'Повторить');
      expect(find.text(name), findsOneWidget);
      expect(find.text('roman@example.com'), findsOneWidget);
      expect(find.text('Дата регистрации'), findsOneWidget);
      expect(find.text('26.09.2026'), findsOneWidget);
      name = 'Обновлённое имя';
      await tapProfileText(tester, 'Обновить профиль');
      expect(find.text(name), findsOneWidget);
      expect(calls, 3);
    },
  );
  testWidgets(
    'logout closes protected routes; late profile response cannot revive session',
    (tester) async {
      final pending = Completer<http.Response>();
      final tokens = MemoryTokens('jwt');
      final auth = fixture(tokens: tokens, handler: (_) => pending.future)
        ..status = AuthStatus.signedIn;
      final router = createAppRouter(auth: auth, initialLocation: '/profile');
      addTearDown(router.dispose);
      addTearDown(auth.dispose);
      await tester.pumpWidget(EasyParkApp(router: router));
      await tester.pump();
      expect(find.text('Загрузка профиля…'), findsOneWidget);
      await tapProfileText(tester, 'Выйти');
      expect(find.text('Вход в систему'), findsOneWidget);
      expect(tokens.value, isNull);
      pending.complete(jsonResponse(testUser));
      await tester.pumpAndSettle();
      router.go('/profile');
      await tester.pumpAndSettle();
      expect(find.text('Вход в систему'), findsOneWidget);
      expect(find.text('roman@example.com'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Профиль водителя'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('401 invalidates profile session', (tester) async {
    final tokens = MemoryTokens('expired');
    final auth = fixture(
      tokens: tokens,
      handler: (_) async => jsonResponse({}, 401),
    )..status = AuthStatus.signedIn;
    final router = createAppRouter(auth: auth, initialLocation: '/profile');
    addTearDown(router.dispose);
    addTearDown(auth.dispose);
    await tester.pumpWidget(EasyParkApp(router: router));
    await tester.pumpAndSettle();
    expect(find.text('Вход в систему'), findsOneWidget);
    expect(tokens.value, isNull);
  });
  testWidgets(
    'long profile fields fit narrow display with large text and logout remains reachable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final auth = fixture(
        tokens: MemoryTokens('jwt'),
        handler: (_) async => jsonResponse({
          ...testUser,
          'name': 'Александра Константинопольская',
          'email': 'very.long.profile.email.address@example.com',
        }),
      )..status = AuthStatus.signedIn;
      final router = createAppRouter(auth: auth, initialLocation: '/profile');
      addTearDown(router.dispose);
      addTearDown(auth.dispose);
      await tester.pumpWidget(EasyParkApp(router: router));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tapProfileText(tester, 'Выйти');
      expect(find.text('Вход в систему'), findsOneWidget);
    },
  );
}
