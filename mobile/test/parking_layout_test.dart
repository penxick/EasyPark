import 'package:easypark/core/constants/api_config.dart';
import 'dart:async';
import 'package:easypark/app.dart';
import 'package:easypark/core/api/api_client.dart';
import 'package:easypark/core/api/api_exception.dart';
import 'package:easypark/core/router/app_router.dart';
import 'package:easypark/core/theme/app_theme.dart';
import 'package:easypark/features/auth/auth_controller.dart';
import 'package:easypark/features/parking/parking_layout.dart';
import 'package:easypark/features/parking/parking_space.dart';
import 'package:easypark/features/parking/parking_spaces_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'support/auth_fixture.dart';
import 'support/map_fixture.dart';
import 'support/parking_spaces_fixture.dart';

void main() {
  test(
    'space model accepts the extended reservation flag without changing USER behavior',
    () {
      final reserved = ParkingSpace.fromJson({
        ...spaceJson(1, 'RESERVED'),
        'hasActiveReservation': true,
      });
      expect(reserved.displayStatus, SpaceStatus.reserved);
      expect(reserved.selectable, false);
      final free = ParkingSpace.fromJson({
        ...spaceJson(2, 'FREE'),
        'hasActiveReservation': false,
      });
      expect(free.selectable, true);
    },
  );
  test('space status, physical occupancy and external geometry validation', () {
    expect(ParkingSpace.fromJson(spaceJson(1, 'FREE')).selectable, true);
    expect(
      ParkingSpace.fromJson(spaceJson(1, 'FREE', occupied: true)).selectable,
      false,
    );
    expect(
      ParkingSpace.fromJson(spaceJson(1, 'FUTURE_STATUS')).displayStatus,
      SpaceStatus.unavailable,
    );
    for (final patch in [
      {'id': 0},
      {'x': -1},
      {'y': double.infinity},
      {'code': ''},
      {'physicalOccupied': null},
    ]) {
      expect(
        () => ParkingSpace.fromJson({...spaceJson(1, 'FREE'), ...patch}),
        throwsA(isA<ApiException>()),
      );
    }
  });
  test(
    'repository checks JWT, endpoint, duplicate codes and parking isolation',
    () async {
      Object? payload = testSpacesJson;
      var calls = 0;
      final api = ApiClient(
        config: ApiConfig(baseUrl: 'https://example.test/api/'),
        tokenProvider: MemoryTokens('jwt'),
        client: MockClient((request) async {
          calls++;
          expect(request.url.path, '/api/parkings/7/spaces');
          expect(request.headers['Authorization'], 'Bearer jwt');
          return jsonResponse(payload);
        }),
      );
      addTearDown(api.close);
      final repo = ParkingSpacesRepository(api);
      expect((await repo.fetchAll('7')).length, 4);
      await expectLater(
        repo.fetchAll('../users'),
        throwsA(isA<ApiException>()),
      );
      expect(calls, 1);
      for (final bad in [
        {},
        [spaceJson(1, 'FREE', parkingId: 8)],
        [spaceJson(1, 'FREE'), spaceJson(1, 'FREE')],
      ]) {
        payload = bad;
        await expectLater(repo.fetchAll('7'), throwsA(isA<ApiException>()));
      }
      payload = [];
      expect(await repo.fetchAll('7'), isEmpty);
    },
  );
  testWidgets('layout codes, disabled statuses, selection and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ParkingLayout(spaces: testSpaces),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final status in SpaceStatus.values) {
      expect(find.text(spaceStatusLabel(status)), findsOneWidget);
    }
    for (final id in [2, 3, 4]) {
      expect(
        tester.widget<InkWell>(find.byKey(ValueKey('space-$id'))).onTap,
        isNull,
      );
    }
    await tester.ensureVisible(find.byType(InteractiveViewer));
    await tester.tap(find.byKey(const ValueKey('space-1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Выбрано место A01'));
    expect(find.text('Выбрано место A01'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'details link loads spaces, refresh, empty, 404 and expired session',
    (tester) async {
      Object? payload = testSpacesJson;
      var status = 200;
      final pending = Completer<http.Response>();
      var spaceRequests = 0;
      final tokens = MemoryTokens('jwt');
      final auth = fixture(
        tokens: tokens,
        handler: (request) async {
          if (!request.url.path.endsWith('/spaces')) {
            return jsonResponse({
              ...testParking,
              'workingHours': 'Круглосуточно',
              'description': '',
            });
          }
          spaceRequests++;
          if (spaceRequests == 1) return pending.future;
          return jsonResponse(payload, status);
        },
      )..status = AuthStatus.signedIn;
      final router = createAppRouter(auth: auth, initialLocation: '/parking/7');
      addTearDown(auth.dispose);
      addTearDown(router.dispose);
      await tester.pumpWidget(EasyParkApp(router: router));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Выбрать место'));
      await tester.tap(find.text('Выбрать место'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Загрузка мест…'), findsOneWidget);
      pending.complete(jsonResponse({}, 503));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(find.byType(ParkingLayout), findsOneWidget);
      payload = [];
      await tester.tap(find.byTooltip('Обновить места'));
      await tester.pumpAndSettle();
      expect(find.text('На этой парковке пока нет мест.'), findsOneWidget);
      status = 404;
      await tester.tap(find.text('Обновить'));
      await tester.pumpAndSettle();
      expect(find.text('Парковка не найдена'), findsOneWidget);
      status = 401;
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(find.text('Вход в систему'), findsOneWidget);
      expect(tokens.value, isNull);
    },
  );
}
