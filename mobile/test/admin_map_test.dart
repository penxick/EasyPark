import 'dart:convert';
import 'package:easypark/app.dart';
import 'package:easypark/core/router/app_router.dart';
import 'package:easypark/features/map/parking_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'support/auth_fixture.dart';
import 'support/map_fixture.dart';
import 'admin_parking_test.dart' show parking, field, tap;

void main() {
  Future<GoRouter> mount(
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
    final router = createAppRouter(
      auth: auth,
      initialLocation: path,
      adminMapTileProviderFactory: MemoryTileProvider.new,
    );
    addTearDown(router.dispose);
    addTearDown(auth.dispose);
    await tester.pumpWidget(EasyParkApp(router: router));
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> pick(WidgetTester tester) async {
    final map = find.byType(FlutterMap).last;
    await tester.ensureVisible(map);
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(map) + const Offset(-65, 30));
    await tester.pumpAndSettle(const Duration(milliseconds: 350));
  }

  testWidgets(
    'empty map supports create, transfers point, reloads and displays new marker',
    (tester) async {
      Map<String, dynamic>? created;
      var posts = 0;
      await mount(tester, '/admin/parkings/map', (r) async {
        if (r.method == 'POST') {
          posts++;
          created = {...parking, ...jsonDecode(r.body) as Map<String, dynamic>};
          return jsonResponse(created);
        }
        return jsonResponse(created == null ? [] : [created]);
      });
      expect(find.byType(FlutterMap), findsOneWidget);
      await tap(tester, '+ Добавить парковку');
      final proceed = find.ancestor(
        of: find.text('Продолжить'),
        matching: find.byType(TextButton),
      );
      expect(tester.widget<TextButton>(proceed).onPressed, isNull);
      await pick(tester);
      final point = tester
          .widget<ParkingMap>(find.byType(ParkingMap))
          .selectedPoint!;
      expect(
        find.byKey(const ValueKey('selected-parking-point')),
        findsOneWidget,
      );
      await tap(tester, 'Продолжить');
      expect(
        tester.widget<TextFormField>(field('latitude')).controller!.text,
        point.latitude.toStringAsFixed(6),
      );
      for (final entry in {
        'name': 'С карты',
        'description': 'Описание',
        'address': 'Адрес',
        'pricePerHour': '25',
        'workingHours': '24/7',
      }.entries) {
        await tester.ensureVisible(field(entry.key));
        await tester.enterText(field(entry.key), entry.value);
      }
      await tap(tester, 'Создать');
      expect(posts, 1);
      expect(find.text('Карта парковок'), findsOneWidget);
      expect(find.byKey(const ValueKey('parking-marker-7')), findsOneWidget);
      expect(created!['latitude'], closeTo(point.latitude, 0.000001));
    },
  );

  testWidgets(
    'edit picker cancel and system back retain draft; save relocates marker',
    (tester) async {
      var data = Map<String, dynamic>.from(parking);
      var patches = 0;
      await mount(tester, '/admin/parkings/map', (r) async {
        if (r.method == 'PATCH') {
          patches++;
          data.addAll(jsonDecode(r.body) as Map<String, dynamic>);
        }
        return jsonResponse(r.url.path.endsWith('/parkings') ? [data] : data);
      });
      await tester.tap(find.byKey(const ValueKey('parking-marker-7')));
      await tester.pumpAndSettle();
      await tester.enterText(field('name'), 'Название сохранится');
      await tap(tester, 'Выбрать положение на карте');
      await pick(tester);
      await tap(tester, 'Отмена');
      expect(
        tester.widget<TextFormField>(field('name')).controller!.text,
        'Название сохранится',
      );
      expect(
        tester.widget<TextFormField>(field('latitude')).controller!.text,
        '56.0',
      );
      await tap(tester, 'Выбрать положение на карте');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(field('name'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(field('name')).controller!.text,
        'Название сохранится',
      );
      await tap(tester, 'Выбрать положение на карте');
      await pick(tester);
      final point = tester
          .widget<ParkingMap>(find.byType(ParkingMap).last)
          .selectedPoint!;
      await tap(tester, 'Выбрать точку');
      expect(
        tester.widget<TextFormField>(field('name')).controller!.text,
        'Название сохранится',
      );
      await tap(tester, 'Сохранить');
      expect(patches, 1);
      final map = tester.widget<ParkingMap>(find.byType(ParkingMap));
      expect(map.parkings.single.latitude, closeTo(point.latitude, 0.000001));
      expect(map.parkings.single.longitude, closeTo(point.longitude, 0.000001));
      expect(map.parkings.single.name, 'Название сохранится');
    },
  );

  testWidgets('map API error retries and large-text layout stays scrollable', (
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
      '/admin/parkings/map',
      (r) async => ++calls == 1 ? jsonResponse({}, 500) : jsonResponse([]),
    );
    await tap(tester, 'Повторить');
    await tap(tester, '+ Добавить парковку');
    await tester.ensureVisible(find.byType(FlutterMap));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(FlutterMap), findsOneWidget);
  });
}
