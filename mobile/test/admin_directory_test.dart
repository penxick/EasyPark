import 'dart:async';
import 'package:easypark/app.dart';
import 'package:easypark/core/api/api_exception.dart';
import 'package:easypark/core/router/app_router.dart';
import 'package:easypark/features/admin/models/admin_directory.dart';
import 'package:easypark/features/auth/auth_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'support/auth_fixture.dart';
import 'admin_parking_test.dart' show tap;

Map<String, Object?> page(List<Object?> items, {int current = 1, int? total}) =>
    {
      'items': items,
      'total': total ?? items.length,
      'page': current,
      'pageSize': 20,
      'totalPages': ((total ?? items.length) / 20).ceil(),
    };
final booking = {
  'id': 9,
  'createdAt': '2026-10-11T00:00:00Z',
  'startTime': '2026-10-11T01:00:00Z',
  'endTime': '2026-10-11T02:00:00Z',
  'status': 'ACTIVE',
  'totalPrice': 50,
  'user': {'id': 1, 'name': 'Роман', 'email': 'roman@example.com'},
  'parking': {'id': 7, 'name': 'Центральная', 'address': 'Мира, 1'},
  'space': {'id': 4, 'code': 'A04'},
};
void main() {
  Future<void> mount(
    WidgetTester tester,
    String path,
    Future<http.Response> Function(http.Request) handler,
  ) async {
    final auth = fixture(
      tokens: MemoryTokens('admin'),
      handler: (r) async => r.url.path.endsWith('/users/me')
          ? jsonResponse({...testUser, 'role': 'ADMIN'})
          : handler(r),
    );
    await auth.restore();
    final router = createAppRouter(auth: auth, initialLocation: path);
    addTearDown(router.dispose);
    addTearDown(auth.dispose);
    await tester.pumpWidget(EasyParkApp(router: router));
    await tester.pumpAndSettle();
  }

  test('page and joined reservation validate external data', () {
    expect(AdminReservation.fromJson(booking).reservation.id, 9);
    expect(
      () => AdminReservation.fromJson({...booking, 'status': 'INVALID'}),
      throwsA(isA<ApiException>()),
    );
    expect(
      () => AdminPage<AuthUser>.fromJson({
        ...page([testUser]),
        'totalPages': 8,
      }, AuthUser.fromJson),
      throwsA(isA<ApiException>()),
    );
    expect(
      () => AdminUserDetails.fromJson({
        ...testUser,
        'reservationCount': 1,
        'activeReservationCount': 2,
        'reservations': page([booking]),
      }),
      throwsA(isA<ApiException>()),
    );
  });
  testWidgets('users pagination and details show counts and joined history', (
    tester,
  ) async {
    final requested = <String>[];
    await mount(tester, '/admin/users', (r) async {
      requested.add(r.url.toString());
      if (r.url.path.endsWith('/users/1')) {
        return jsonResponse({
          ...testUser,
          'reservationCount': 1,
          'activeReservationCount': 1,
          'reservations': page([booking]),
        });
      }
      if (r.url.path.endsWith('/reservations/9')) return jsonResponse(booking);
      final n = int.parse(r.url.queryParameters['page']!);
      return jsonResponse(
        n == 1
            ? page(
                List.generate(20, (i) => {...testUser, 'id': i + 1}),
                total: 21,
              )
            : page(
                [
                  {...testUser, 'id': 21, 'name': 'Последний'},
                ],
                current: 2,
                total: 21,
              ),
      );
    });
    await tap(tester, 'Следующая');
    expect(find.text('Последний'), findsOneWidget);
    await tap(tester, 'Предыдущая');
    await tester.ensureVisible(find.text('Открыть пользователя').first);
    await tester.tap(find.text('Открыть пользователя').first);
    await tester.pumpAndSettle();
    expect(find.text('Всего: 1\nАктивных: 1'), findsOneWidget);
    await tap(tester, 'Открыть бронирование');
    expect(find.text('Email: roman@example.com'), findsOneWidget);
    expect(find.text('Адрес: Мира, 1'), findsOneWidget);
    expect(
      requested.any((u) => u.contains('page=2') && u.contains('pageSize=20')),
      true,
    );
  });
  testWidgets(
    'reservation filters reset page and empty filter has no stale cards',
    (tester) async {
      final queries = <Map<String, String>>[];
      await mount(tester, '/admin/reservations', (r) async {
        queries.add(r.url.queryParameters);
        return jsonResponse(
          r.url.queryParameters['category'] == 'all'
              ? page([booking])
              : page([]),
        );
      });
      expect(find.text('Бронирование №9'), findsOneWidget);
      await tap(tester, 'Активные');
      expect(find.text('Бронирований нет'), findsOneWidget);
      expect(find.text('Бронирование №9'), findsNothing);
      await tap(tester, 'Завершённые');
      await tap(tester, 'Отменённые');
      await tap(tester, 'Все');
      expect(queries.map((q) => q['category']), [
        'all',
        'active',
        'completed',
        'cancelled',
        'all',
      ]);
      expect(queries.every((q) => q['page'] == '1'), true);
    },
  );
  testWidgets('late response cannot replace selected category', (tester) async {
    final pending = Completer<http.Response>();
    await mount(
      tester,
      '/admin/reservations',
      (r) async => r.url.queryParameters['category'] == 'active'
          ? pending.future
          : jsonResponse(page([])),
    );
    await tester.tap(find.text('Активные'));
    await tester.pump();
    await tester.tap(find.text('Отменённые'));
    await tester.pumpAndSettle();
    pending.complete(jsonResponse(page([booking])));
    await tester.pumpAndSettle();
    expect(find.text('Бронирование №9'), findsNothing);
  });
  testWidgets('detail 404 is safe and retry works with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    var calls = 0;
    await mount(
      tester,
      '/admin/reservations/9',
      (r) async => ++calls == 1
          ? jsonResponse({'stack': 'private'}, 404)
          : jsonResponse(booking),
    );
    expect(find.text('private'), findsNothing);
    await tap(tester, 'Повторить');
    await tester.ensureVisible(find.text('Открыть пользователя'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
