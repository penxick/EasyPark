import 'dart:async';
import 'package:easypark/app.dart';
import 'package:easypark/core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'support/auth_fixture.dart';

Finder field(String name) => find.descendant(
  of: find.byKey(ValueKey('auth-$name')),
  matching: find.byType(TextFormField),
);

void main() {
  testWidgets('empty form and mismatched passwords never call backend', (
    tester,
  ) async {
    var calls = 0;
    final auth = fixture(
      handler: (_) async {
        calls++;
        return sessionResponse();
      },
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(EasyParkApp(auth: auth));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();
    expect(find.text('Введите корректный email.'), findsOneWidget);
    await tester.ensureVisible(find.text('Зарегистрироваться'));
    await tester.tap(find.text('Зарегистрироваться'));
    await tester.pumpAndSettle();
    await tester.enterText(field('name'), 'Роман');
    await tester.enterText(field('email'), 'roman@example.com');
    await tester.enterText(field('password'), 'password1');
    await tester.enterText(field('confirm'), 'password2');
    await tester.ensureVisible(find.text('Создать аккаунт'));
    await tester.tap(find.text('Создать аккаунт'));
    await tester.pumpAndSettle();
    expect(find.text('Пароли не совпадают.'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets(
    'submit disables form, errors keep input, retry goes home without login in history',
    (tester) async {
      final pending = Completer<http.Response>();
      var calls = 0;
      final auth = fixture(
        handler: (_) {
          calls++;
          return calls == 1 ? pending.future : Future.value(sessionResponse());
        },
      );
      final router = createAppRouter(auth: auth);
      addTearDown(router.dispose);
      addTearDown(auth.dispose);
      await auth.restore();
      await tester.pumpWidget(EasyParkApp(router: router));
      await tester.pumpAndSettle();
      await tester.enterText(field('email'), 'roman@example.com');
      await tester.enterText(field('password'), 'password');
      await tester.tap(find.text('Войти'));
      await tester.pump();
      expect(tester.widget<TextFormField>(field('email')).enabled, false);
      expect(find.text('Вход…'), findsOneWidget);
      pending.complete(jsonResponse({}, 401));
      await tester.pumpAndSettle();
      expect(find.text('Неверный email или пароль.'), findsOneWidget);
      expect(find.text('roman@example.com'), findsOneWidget);
      await tester.tap(find.text('Войти'));
      await tester.pumpAndSettle();
      expect(find.text('Карта'), findsOneWidget);
      expect(router.canPop(), false);
    },
  );

  testWidgets('offline startup offers retry without deleting the session', (
    tester,
  ) async {
    var code = 503;
    final tokens = MemoryTokens('stored');
    final auth = fixture(
      tokens: tokens,
      handler: (_) async => jsonResponse(testUser, code),
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(EasyParkApp(auth: auth));
    await tester.pumpAndSettle();
    expect(find.text('Не удалось проверить сессию'), findsOneWidget);
    expect(tokens.value, 'stored');
    code = 200;
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('Карта'), findsOneWidget);
  });

  for (final registration in [false, true]) {
    testWidgets(
      'auth form registration=$registration fits 320px, 2x text and keyboard',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 240);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final auth = fixture();
        await auth.restore();
        final router = createAppRouter(
          auth: auth,
          initialLocation: registration ? '/register' : '/login',
        );
        addTearDown(router.dispose);
        addTearDown(auth.dispose);
        await tester.pumpWidget(EasyParkApp(router: router));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('auth-submit')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.text(registration ? 'Создать аккаунт' : 'Войти'),
          findsOneWidget,
        );
      },
    );
  }
}
