import 'dart:async';
import 'dart:convert';
import 'package:easypark/app.dart';
import 'package:easypark/core/api/api_exception.dart';
import 'package:easypark/core/router/app_router.dart';
import 'package:easypark/features/admin/models/admin_summary.dart';
import 'package:easypark/features/auth/auth_validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'support/auth_fixture.dart';

final adminUser = {...testUser, 'role': 'ADMIN', 'name': 'Администратор'};
const summary = {
  'totalParkings': 3,
  'totalSpaces': 10,
  'freeSpaces': 4,
  'occupiedSpaces': 2,
  'reservedSpaces': 3,
  'unavailableSpaces': 1,
  'totalUsers': 17,
  'activeReservations': 2,
  'totalReservations': 20,
  'physicalOccupiedSpaces': 2,
  'occupancyPercent': 55.56,
};
Finder authField(String name) => find.descendant(
  of: find.byKey(ValueKey('auth-$name')),
  matching: find.byType(TextFormField),
);

void main() {
  test('summary requires real finite consistent counters', () {
    expect(AdminSummary.fromJson(summary).totalUsers, 17);
    for (final patch in [
      {'freeSpaces': -1},
      {'totalUsers': '17'},
      {'occupancyPercent': double.nan},
      {'occupancyPercent': 101},
      {'totalSpaces': 12},
      {'activeReservations': 99},
      {'physicalOccupiedSpaces': 99},
      {'totalParkings': null},
    ]) {
      expect(
        () => AdminSummary.fromJson({...summary, ...patch}),
        throwsA(isA<ApiException>()),
      );
    }
    expect(AuthValidators.login(' admin '), isNull);
    expect(AuthValidators.login(''), isNotNull);
    expect(AuthValidators.email('admin'), isNotNull);
  });
  testWidgets(
    'existing login accepts admin, preserves password and redirects by role',
    (tester) async {
      final auth = fixture(
        handler: (request) async {
          if (request.url.path.endsWith('/auth/login')) {
            expect(jsonDecode(request.body), {
              'login': 'admin',
              'password': ' test password ',
            });
            return jsonResponse({
              'accessToken': 'admin-token',
              'user': adminUser,
            });
          }
          expect(request.headers['Authorization'], 'Bearer admin-token');
          return jsonResponse(summary);
        },
      );
      await auth.restore();
      final router = createAppRouter(auth: auth);
      addTearDown(router.dispose);
      addTearDown(auth.dispose);
      await tester.pumpWidget(EasyParkApp(router: router));
      await tester.pumpAndSettle();
      expect(find.text('Логин / Email'), findsOneWidget);
      await tester.enterText(authField('email'), ' ADMIN ');
      await tester.enterText(authField('password'), ' test password ');
      await tester.tap(find.text('Войти'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/admin');
      expect(find.text('Обзор системы'), findsOneWidget);
      expect(find.text('17'), findsOneWidget);
      expect(router.canPop(), false);
    },
  );
  testWidgets('USER deep links never load admin data or display admin UI', (
    tester,
  ) async {
    var adminCalls = 0;
    final auth = fixture(
      tokens: MemoryTokens('user-token'),
      handler: (request) async {
        if (request.url.path.contains('/admin/')) adminCalls++;
        return jsonResponse(testUser);
      },
    );
    await auth.restore();
    final router = createAppRouter(auth: auth, initialLocation: '/admin');
    addTearDown(router.dispose);
    addTearDown(auth.dispose);
    await tester.pumpWidget(EasyParkApp(router: router));
    await tester.pumpAndSettle();
    for (final path in [
      '/admin',
      '/admin/parkings/new',
      '/admin/parkings/map',
      '/admin/parkings/pick-location',
      '/admin/parkings/1/edit',
      '/admin/users/1',
      '/admin/reservations/1',
      '/admin/analytics',
      '/admin/profile',
      '/admin/unknown',
    ]) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(find.text('Нет доступа'), findsOneWidget);
      expect(find.text('EasyPark · ADMIN'), findsNothing);
    }
    expect(adminCalls, 0);
  });
  testWidgets(
    'restored ADMIN gets menu, profile and logout clears session and routes',
    (tester) async {
      final tokens = MemoryTokens('stored');
      final auth = fixture(
        tokens: tokens,
        handler: (request) async => jsonResponse(
          request.url.path.endsWith('/users/me') ? adminUser : summary,
        ),
      );
      await auth.restore();
      final router = createAppRouter(auth: auth);
      addTearDown(router.dispose);
      addTearDown(auth.dispose);
      await tester.pumpWidget(EasyParkApp(router: router));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/admin');
      await tester.tap(find.byTooltip('Административное меню'));
      await tester.pumpAndSettle();
      for (final label in [
        'Главная',
        'Парковки',
        'Бронирования',
        'Пользователи',
        'Аналитика',
        'Профиль',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.byKey(const ValueKey('admin-nav-5')));
      await tester.pumpAndSettle();
      expect(find.text('Профиль администратора'), findsOneWidget);
      await tester.ensureVisible(find.text('Выйти'));
      await tester.tap(find.text('Выйти'));
      await tester.pumpAndSettle();
      expect(tokens.value, isNull);
      expect(find.text('Вход в систему'), findsOneWidget);
      router.go('/admin/users');
      await tester.pumpAndSettle();
      expect(find.text('Вход в систему'), findsOneWidget);
    },
  );
  testWidgets('dashboard loading error retry refresh and empty database', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    var calls = 0;
    final auth = fixture(
      tokens: MemoryTokens('stored'),
      handler: (request) async {
        if (request.url.path.endsWith('/users/me')) {
          return jsonResponse(adminUser);
        }
        calls++;
        if (calls == 1) return pending.future;
        if (calls == 2) return jsonResponse(summary);
        return jsonResponse({for (final key in summary.keys) key: 0});
      },
    );
    await auth.restore();
    final router = createAppRouter(auth: auth);
    addTearDown(router.dispose);
    addTearDown(auth.dispose);
    await tester.pumpWidget(EasyParkApp(router: router));
    await tester.pump();
    expect(find.text('Загрузка показателей…'), findsOneWidget);
    pending.complete(jsonResponse({'stack': 'private-error'}, 500));
    await tester.pumpAndSettle();
    expect(find.text('Ошибка загрузки аналитики'), findsOneWidget);
    expect(find.text('private-error'), findsNothing);
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('17'), findsOneWidget);
    await tester.tap(find.byTooltip('Обновить показатели'));
    await tester.pumpAndSettle();
    expect(find.text('Парковок пока нет'), findsOneWidget);
    expect(calls, 3);
  });
  testWidgets('403 refreshes role and revocation removes ADMIN access', (
    tester,
  ) async {
    var role = 'ADMIN';
    final auth = fixture(
      tokens: MemoryTokens('stored'),
      handler: (request) async {
        if (request.url.path.endsWith('/users/me')) {
          return jsonResponse({...testUser, 'role': role});
        }
        role = 'USER';
        return jsonResponse({}, 403);
      },
    );
    await auth.restore();
    final router = createAppRouter(auth: auth);
    addTearDown(router.dispose);
    addTearDown(auth.dispose);
    await tester.pumpWidget(EasyParkApp(router: router));
    await tester.pumpAndSettle();
    expect(find.text('Нет доступа'), findsOneWidget);
    expect(auth.isAdmin, false);
  });
  testWidgets(
    '403 with unchanged ADMIN role shows error without a reload loop',
    (tester) async {
      var calls = 0;
      final auth = fixture(
        tokens: MemoryTokens('stored'),
        handler: (request) async {
          if (request.url.path.endsWith('/users/me')) {
            return jsonResponse(adminUser);
          }
          calls++;
          return jsonResponse({}, 403);
        },
      );
      await auth.restore();
      final router = createAppRouter(auth: auth);
      addTearDown(router.dispose);
      addTearDown(auth.dispose);
      await tester.pumpWidget(EasyParkApp(router: router));
      await tester.pumpAndSettle();
      expect(
        find.text('Недостаточно прав для этого действия.'),
        findsOneWidget,
      );
      expect(calls, 1);
    },
  );
  for (final size in [const Size(320, 640), const Size(1200, 800)]) {
    testWidgets('admin layout fits $size with large text and analytics opens', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = size.width < 400
          ? 2
          : 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final auth = fixture(
        tokens: MemoryTokens('stored'),
        handler: (r) async => jsonResponse(
          r.url.path.endsWith('/users/me')
              ? adminUser
              : r.url.path.endsWith('/analytics/parkings')
              ? {
                  'items': [],
                  'total': 0,
                  'page': 1,
                  'pageSize': 20,
                  'totalPages': 0,
                }
              : summary,
        ),
      );
      await auth.restore();
      final router = createAppRouter(auth: auth);
      addTearDown(router.dispose);
      addTearDown(auth.dispose);
      await tester.pumpWidget(EasyParkApp(router: router));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Загруженность парковок'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      router.go('/admin/analytics');
      await tester.pumpAndSettle();
      expect(find.text('Распределение статусов мест'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
