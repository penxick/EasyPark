import 'dart:convert';
import 'package:easypark/app.dart';
import 'package:easypark/core/api/api_exception.dart';
import 'package:easypark/core/router/app_router.dart';
import 'package:easypark/features/admin/models/admin_space.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'support/auth_fixture.dart';
import 'support/parking_spaces_fixture.dart';
import 'admin_parking_test.dart' show parking, tap;

Finder field(String key) => key == 'polygon'
    ? find.byKey(const ValueKey('space-polygon'))
    : find.descendant(
        of: find.byKey(ValueKey('space-$key')),
        matching: find.byType(TextFormField),
      );
Map<String, Object?> space() => {
  ...spaceJson(1, 'RESERVED', occupied: true),
  'hasActiveReservation': true,
  'polygon': [
    [0, 0],
    [20, 0],
    [20, 20],
  ],
};

void main() {
  Future<void> mount(
    WidgetTester tester,
    Future<http.Response> Function(http.Request) handler,
  ) async {
    final auth = fixture(
      tokens: MemoryTokens('admin'),
      handler: (r) async {
        if (r.url.path.endsWith('/users/me')) {
          return jsonResponse({...testUser, 'role': 'ADMIN'});
        }
        if (r.url.path == '/api/parkings/7') return jsonResponse(parking);
        return handler(r);
      },
    );
    await auth.restore();
    final router = createAppRouter(
      auth: auth,
      initialLocation: '/admin/parkings/7/spaces',
    );
    addTearDown(router.dispose);
    addTearDown(auth.dispose);
    await tester.pumpWidget(EasyParkApp(router: router));
    await tester.pumpAndSettle();
  }

  test('admin geometry and reservation flag are validated separately', () {
    final item = AdminSpace.fromJson(space());
    expect(item.space.physicalOccupied, true);
    expect(item.hasActiveReservation, true);
    expect(AdminSpace.parsePolygon(item.polygonText), [
      [0, 0],
      [20, 0],
      [20, 20],
    ]);
    expect(AdminSpace.parsePolygon(''), isNull);
    for (final text in [
      '0;0',
      '0;0\n1;1',
      'NaN;0\n1;0\n1;1',
      '0;0;0\n1;0\n1;1',
    ]) {
      expect(() => AdminSpace.parsePolygon(text), throwsFormatException);
    }
    expect(
      () => AdminSpace.fromJson({...space(), 'hasActiveReservation': null}),
      throwsA(isA<ApiException>()),
    );
  });
  testWidgets(
    'rename only patches changed field and preserves CV geometry and occupancy',
    (tester) async {
      var data = space();
      Map<String, dynamic>? sent;
      await mount(tester, (r) async {
        if (r.method == 'PATCH') {
          sent = jsonDecode(r.body) as Map<String, dynamic>;
          data.addAll(sent!);
          return jsonResponse(data);
        }
        return jsonResponse([data]);
      });
      expect(find.text('Активное бронирование: есть'), findsOneWidget);
      expect(
        find.text('Физическая занятость (physicalOccupied): да'),
        findsOneWidget,
      );
      await tap(tester, 'Редактировать');
      await tester.enterText(field('code'), 'B01');
      await tap(tester, 'Сохранить');
      expect(sent, {'code': 'B01'});
      expect(find.text('B01'), findsOneWidget);
      expect(find.text('Вершин контура: 3'), findsOneWidget);
    },
  );
  testWidgets(
    'disable and enable send only availability and display live reservation independently',
    (tester) async {
      var data = space();
      final bodies = <Object>[];
      await mount(tester, (r) async {
        if (r.method == 'PATCH') {
          final body = jsonDecode(r.body) as Map;
          bodies.add(body);
          data['status'] = body['available'] == true
              ? 'RESERVED'
              : 'UNAVAILABLE';
          return jsonResponse(data);
        }
        return jsonResponse([data]);
      });
      await tap(tester, 'Отключить');
      expect(find.text('Недоступно · UNAVAILABLE'), findsOneWidget);
      expect(find.text('Активное бронирование: есть'), findsOneWidget);
      await tap(tester, 'Вернуть в эксплуатацию');
      expect(bodies, [
        {'available': false},
        {'available': true},
      ]);
      expect(find.text('Забронировано · RESERVED'), findsOneWidget);
    },
  );
  testWidgets(
    'create validates coordinates and polygon, sends FREE contract and refreshes',
    (tester) async {
      Map<String, Object?>? created;
      var posts = 0;
      await mount(tester, (r) async {
        if (r.method == 'POST') {
          posts++;
          final b = jsonDecode(r.body) as Map<String, dynamic>;
          expect(b.keys.toSet(), {'code', 'x', 'y', 'polygon'});
          created = {
            ...spaceJson(2, 'FREE'),
            ...b,
            'hasActiveReservation': false,
          };
          return jsonResponse(created);
        }
        return jsonResponse(created == null ? [] : [created]);
      });
      expect(find.text('Мест пока нет'), findsOneWidget);
      await tap(tester, '+ Добавить место');
      await tester.enterText(field('code'), ' A02 ');
      await tester.enterText(field('x'), '-1');
      await tap(tester, 'Создать');
      expect(posts, 0);
      await tester.ensureVisible(field('x'));
      await tester.enterText(field('x'), '12,5');
      await tester.ensureVisible(field('polygon'));
      await tester.enterText(field('polygon'), '0;0\n1;1');
      await tap(tester, 'Создать');
      expect(posts, 0);
      await tester.ensureVisible(field('polygon'));
      await tester.enterText(field('polygon'), '0;0\n10;0\n10;10');
      await tap(tester, 'Создать');
      expect(posts, 1);
      expect(created!['x'], 12.5);
      expect(find.text('A02'), findsOneWidget);
    },
  );
  testWidgets(
    'delete confirmation preserves history and raw backend data stays hidden',
    (tester) async {
      var calls = 0;
      var conflict = true;
      await mount(tester, (r) async {
        if (r.method == 'DELETE') {
          calls++;
          return conflict
              ? jsonResponse({
                  'code': 'SPACE_HAS_RESERVATIONS',
                  'stack': 'private',
                }, 409)
              : http.Response('', 204);
        }
        return jsonResponse(conflict ? [space()] : []);
      });
      await tap(tester, 'Удалить место');
      await tap(tester, 'Отмена');
      expect(calls, 0);
      await tap(tester, 'Удалить место');
      await tap(tester, 'Удалить');
      expect(
        find.text('Нельзя удалить место с историей бронирований.'),
        findsOneWidget,
      );
      expect(find.text('private'), findsNothing);
      conflict = false;
      await tap(tester, 'Удалить место');
      await tap(tester, 'Удалить');
      expect(calls, 2);
      expect(find.text('Мест пока нет'), findsOneWidget);
    },
  );
  testWidgets('server duplicate code error preserves entered data', (
    tester,
  ) async {
    await mount(
      tester,
      (r) async => r.method == 'POST'
          ? jsonResponse({'code': 'SPACE_CODE_EXISTS'}, 409)
          : jsonResponse([]),
    );
    await tap(tester, '+ Добавить место');
    await tester.enterText(field('code'), 'A01');
    await tap(tester, 'Создать');
    expect(
      find.text('Парковочное место с таким кодом уже существует.'),
      findsOneWidget,
    );
    expect(tester.widget<TextFormField>(field('code')).controller!.text, 'A01');
  });
  testWidgets('large text and retry fit narrow display', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    var calls = 0;
    await mount(
      tester,
      (r) async =>
          ++calls == 1 ? jsonResponse({}, 500) : jsonResponse([space()]),
    );
    await tap(tester, 'Повторить');
    await tap(tester, 'Редактировать');
    await tester.ensureVisible(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
