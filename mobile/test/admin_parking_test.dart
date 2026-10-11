import 'dart:async';
import 'dart:convert';
import 'package:easypark/app.dart';
import 'package:easypark/core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'support/auth_fixture.dart';

const parking = {
  'id': 7,
  'name': 'Центральная',
  'address': 'Мира, 1',
  'description': 'Открытая парковка',
  'latitude': 56.0,
  'longitude': 92.0,
  'pricePerHour': 50.0,
  'workingHours': 'Круглосуточно',
  'totalSpaces': 10,
  'freeSpaces': 4,
};
Finder field(String key) => find.descendant(
  of: find.byKey(ValueKey('parking-$key')),
  matching: find.byType(TextFormField),
);
Future<void> tap(WidgetTester tester, String label) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  Future<void> mount(
    WidgetTester tester,
    String path,
    Future<http.Response> Function(http.Request) handler,
  ) async {
    final auth = fixture(
      tokens: MemoryTokens('admin'),
      handler: (r) async {
        if (r.url.path.endsWith('/users/me')) {
          return jsonResponse({...testUser, 'role': 'ADMIN'});
        }
        expect(r.headers['Authorization'], 'Bearer admin');
        return handler(r);
      },
    );
    await auth.restore();
    final router = createAppRouter(auth: auth, initialLocation: path);
    addTearDown(router.dispose);
    addTearDown(auth.dispose);
    await tester.pumpWidget(EasyParkApp(router: router));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'list, details and edit use shared data and refresh after saving',
    (tester) async {
      var data = Map<String, Object>.from(parking);
      var patches = 0;
      await mount(tester, '/admin/parkings', (r) async {
        if (r.method == 'PATCH') {
          patches++;
          expect(r.url.path, '/api/admin/parkings/7');
          data.addAll(Map<String, Object>.from(jsonDecode(r.body) as Map));
        }
        return jsonResponse(r.url.path.endsWith('/parkings') ? [data] : data);
      });
      expect(find.text('Мест: 10 · Свободно: 4'), findsOneWidget);
      expect(find.text('Режим работы: Круглосуточно'), findsOneWidget);
      await tap(tester, 'Открыть');
      expect(find.text('Открытая парковка'), findsOneWidget);
      await tap(tester, 'Редактировать');
      expect(
        tester.widget<TextFormField>(field('name')).controller!.text,
        'Центральная',
      );
      await tester.enterText(field('name'), 'Новая вывеска');
      await tap(tester, 'Сохранить');
      expect(patches, 1);
      expect(find.text('Новая вывеска'), findsOneWidget);
      await tap(tester, 'К списку парковок');
      expect(find.text('Новая вывеска'), findsOneWidget);
    },
  );

  testWidgets(
    'create validates fields and coordinates, accepts zero price and opens result',
    (tester) async {
      var posts = 0;
      Map<String, dynamic>? body;
      await mount(tester, '/admin/parkings/new', (r) async {
        if (r.method == 'POST') {
          posts++;
          body = jsonDecode(r.body) as Map<String, dynamic>;
          expect(r.url.path, '/api/admin/parkings');
        }
        return jsonResponse({...parking, ...?body});
      });
      await tap(tester, 'Создать');
      expect(posts, 0);
      expect(find.text('Обязательное поле'), findsWidgets);
      for (final entry in {
        'name': ' Тест ',
        'description': 'Описание',
        'address': 'Адрес',
        'workingHours': '24/7',
        'latitude': '91',
        'longitude': '181',
        'pricePerHour': '-1',
      }.entries) {
        await tester.ensureVisible(field(entry.key));
        await tester.enterText(field(entry.key), entry.value);
      }
      await tap(tester, 'Создать');
      expect(posts, 0);
      for (final entry in {
        'latitude': '56,12',
        'longitude': '92.34',
        'pricePerHour': '0',
      }.entries) {
        await tester.ensureVisible(field(entry.key));
        await tester.enterText(field(entry.key), entry.value);
      }
      await tap(tester, 'Создать');
      expect(posts, 1);
      expect(body!['name'], 'Тест');
      expect(body!['latitude'], 56.12);
      expect(body!['pricePerHour'], 0);
      expect(find.text('Информация о парковке'), findsOneWidget);
    },
  );

  testWidgets(
    'delete requires confirmation; conflict keeps parking; success refreshes list',
    (tester) async {
      var deletes = 0;
      var conflict = true;
      var exists = true;
      await mount(tester, '/admin/parkings', (r) async {
        if (r.method == 'DELETE') {
          deletes++;
          if (conflict) return jsonResponse({'stack': 'secret'}, 409);
          exists = false;
          return http.Response('', 204);
        }
        return jsonResponse(exists ? [parking] : []);
      });
      await tap(tester, 'Удалить парковку');
      expect(find.text('Удалить парковку?'), findsOneWidget);
      await tap(tester, 'Отмена');
      expect(deletes, 0);
      await tap(tester, 'Удалить парковку');
      await tap(tester, 'Удалить');
      expect(deletes, 1);
      expect(
        find.textContaining('История бронирований сохранена'),
        findsOneWidget,
      );
      expect(find.text('secret'), findsNothing);
      expect(find.text('Центральная'), findsOneWidget);
      conflict = false;
      await tap(tester, 'Удалить парковку');
      await tap(tester, 'Удалить');
      expect(deletes, 2);
      expect(find.text('Парковок пока нет'), findsOneWidget);
    },
  );

  testWidgets(
    'failed save preserves input and blocks duplicate requests while pending',
    (tester) async {
      final pending = Completer<http.Response>();
      var calls = 0;
      await mount(tester, '/admin/parkings/7/edit', (r) async {
        if (r.method == 'PATCH') {
          calls++;
          return pending.future;
        }
        return jsonResponse(parking);
      });
      await tester.enterText(field('name'), 'Сохранить это имя');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Сохранить'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сохранить'));
      await tester.pump();
      final button = find.ancestor(
        of: find.text('Сохранить'),
        matching: find.byType(TextButton),
      );
      expect(tester.widget<TextButton>(button).onPressed, isNull);
      expect(calls, 1);
      pending.complete(jsonResponse({}, 500));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(field('name')).controller!.text,
        'Сохранить это имя',
      );
      expect(
        find.textContaining('Не удалось сохранить парковку'),
        findsOneWidget,
      );
    },
  );

  testWidgets('loading failure can retry', (tester) async {
    var calls = 0;
    await mount(tester, '/admin/parkings', (r) async {
      calls++;
      return calls == 1 ? jsonResponse({}, 500) : jsonResponse([]);
    });
    expect(
      find.textContaining('Не удалось загрузить парковки'),
      findsOneWidget,
    );
    await tap(tester, 'Повторить');
    expect(find.text('Парковок пока нет'), findsOneWidget);
  });

  testWidgets('form fits narrow display with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await mount(
      tester,
      '/admin/parkings/7/edit',
      (r) async => jsonResponse(parking),
    );
    await tester.ensureVisible(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
