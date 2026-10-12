import 'package:easypark/core/constants/api_config.dart';
import 'dart:async';
import 'package:easypark/app.dart';
import 'package:easypark/core/api/api_client.dart';
import 'package:easypark/core/api/api_exception.dart';
import 'package:easypark/core/router/app_router.dart';
import 'package:easypark/features/auth/auth_controller.dart';
import 'package:easypark/features/map/parking_repository.dart';
import 'package:easypark/features/parking/parking_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'support/auth_fixture.dart';
import 'support/map_fixture.dart';

const detailsJson = {
  ...testParking,
  'workingHours': '08:00–22:00',
  'description': 'Учебная парковка',
};

void main() {
  test(
    'detail contract validates hours, optional counts and matching identity',
    () async {
      expect(ParkingDetails.fromJson(detailsJson).freeSpaces, isNull);
      expect(
        ParkingDetails.fromJson({
          ...detailsJson,
          'freeSpaces': 0,
          'totalSpaces': 0,
        }).totalSpaces,
        0,
      );
      for (final patch in [
        {'workingHours': null},
        {'description': 1},
        {'freeSpaces': -1},
        {'totalSpaces': 2.5},
        {'freeSpaces': 3, 'totalSpaces': 2},
      ]) {
        expect(
          () => ParkingDetails.fromJson({...detailsJson, ...patch}),
          throwsA(isA<ApiException>()),
        );
      }
      var requests = 0;
      final api = ApiClient(
        config: ApiConfig(baseUrl: 'https://example.test/api/'),
        tokenProvider: MemoryTokens('jwt'),
        client: MockClient((request) async {
          requests++;
          expect(request.headers['Authorization'], 'Bearer jwt');
          expect(request.url.path, '/api/parkings/8');
          return jsonResponse(detailsJson);
        }),
      );
      addTearDown(api.close);
      final repository = ParkingRepository(api);
      for (final id in [
        '0',
        '-1',
        '1.2',
        '../users/me',
        '999999999999999999999',
        'abc',
      ]) {
        await expectLater(
          repository.fetchOne(id),
          throwsA(isA<ApiException>()),
        );
      }
      expect(requests, 0);
      await expectLater(repository.fetchOne('8'), throwsA(isA<ApiException>()));
      expect(requests, 1);
    },
  );
  testWidgets('loading, retry, updated API details and direct-link back', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    var calls = 0;
    final auth = fixture(
      handler: (request) async {
        if (request.url.path == '/api/parkings') return jsonResponse([]);
        calls++;
        return calls == 1 ? pending.future : jsonResponse(detailsJson);
      },
    )..status = AuthStatus.signedIn;
    final router = createAppRouter(auth: auth, initialLocation: '/parking/7');
    addTearDown(auth.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(EasyParkApp(router: router));
    await tester.pump();
    expect(find.text('Загрузка парковки…'), findsOneWidget);
    pending.complete(jsonResponse({}, 503));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    for (final text in [
      'Тестовая парковка',
      'Учебный адрес',
      '60,25 ₽ / 30 мин.',
      '08:00–22:00',
      'Свободно',
      'Всего',
    ]) {
      expect(find.text(text), findsOneWidget);
    }
    expect(find.text('Нет данных'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();
    expect(find.text('Карта'), findsOneWidget);
  });
  testWidgets('404 and 401; changing route id loads the new parking', (
    tester,
  ) async {
    var status = 404;
    final requested = <String>[];
    final tokens = MemoryTokens('jwt');
    final auth = fixture(
      tokens: tokens,
      handler: (request) async {
        requested.add(request.url.path);
        return jsonResponse({
          ...detailsJson,
          'id': 8,
          'name': 'Другая парковка',
        }, status);
      },
    )..status = AuthStatus.signedIn;
    final router = createAppRouter(auth: auth, initialLocation: '/parking/7');
    addTearDown(auth.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(EasyParkApp(router: router));
    await tester.pumpAndSettle();
    expect(find.text('Парковка не найдена'), findsOneWidget);
    status = 200;
    router.go('/parking/8');
    await tester.pumpAndSettle();
    expect(find.text('Другая парковка'), findsOneWidget);
    expect(requested.last, '/api/parkings/8');
    status = 401;
    await tester.ensureVisible(find.text('Обновить данные'));
    await tester.tap(find.text('Обновить данные'));
    await tester.pumpAndSettle();
    expect(find.text('Вход в систему'), findsOneWidget);
    expect(tokens.value, isNull);
  });
  testWidgets('small screen and large text show real counts including zero', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final auth = fixture(
      handler: (_) async =>
          jsonResponse({...detailsJson, 'freeSpaces': 0, 'totalSpaces': 25}),
    )..status = AuthStatus.signedIn;
    final router = createAppRouter(auth: auth, initialLocation: '/parking/7');
    addTearDown(auth.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(EasyParkApp(router: router));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('0'));
    expect(find.text('0'), findsOneWidget);
    await tester.ensureVisible(find.text('25'));
    expect(find.text('25'), findsOneWidget);
    await tester.ensureVisible(find.text('Обновить данные'));
    expect(find.text('Обновить данные').hitTestable(), findsOneWidget);
    expect(find.text('Нет данных'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
