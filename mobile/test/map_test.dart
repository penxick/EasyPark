import 'package:easypark/core/constants/api_config.dart';
import 'dart:async';
import 'package:easypark/app.dart';
import 'package:easypark/core/api/api_client.dart';
import 'package:easypark/core/api/api_exception.dart';
import 'package:easypark/core/router/app_router.dart';
import 'package:easypark/core/theme/app_theme.dart';
import 'package:easypark/core/widgets/app_bottom_navigation.dart';
import 'package:easypark/features/auth/auth_controller.dart';
import 'package:easypark/features/map/map_screen.dart';
import 'package:easypark/features/map/parking.dart';
import 'package:easypark/features/map/parking_map.dart';
import 'package:easypark/features/map/parking_repository.dart';
import 'package:easypark/features/map/parking_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'support/auth_fixture.dart';
import 'support/map_fixture.dart';

void main() {
  testWidgets('tile failure keeps markers and retry recovers on small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    var providers = 0;
    var selected = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          appBar: AppBar(title: const Text('EasyPark')),
          bottomNavigationBar: AppBottomNavigation(
            selectedIndex: 0,
            onSelected: (_) {},
          ),
          body: ParkingMap(
            parkings: [Parking.fromJson(testParking)],
            onSelect: (_) => selected = true,
            onRefresh: () {},
            tileProviderFactory: () =>
                ++providers == 1 ? FailedTileProvider() : MemoryTileProvider(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Не удалось загрузить фон карты.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Повторить загрузку карты'));
    await tester.pumpAndSettle();
    expect(find.text('Не удалось загрузить фон карты.'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('parking-marker-7')));
    expect(selected, isTrue);
    expect(tester.takeException(), isNull);
  });
  test('parking validates external data and formats prices', () {
    expect(Parking.fromJson(testParking).formattedPrice, '120,50 ₽/час');
    expect(
      Parking.fromJson({...testParking, 'pricePerHour': 100}).formattedPrice,
      '100,00 ₽/час',
    );
    for (final patch in [
      {'id': 0},
      {'id': '7'},
      {'latitude': 91},
      {'longitude': -181},
      {'pricePerHour': -1},
      {'pricePerHour': double.nan},
      {'name': ''},
      {'address': null},
    ]) {
      expect(
        () => Parking.fromJson({...testParking, ...patch}),
        throwsA(isA<ApiException>()),
      );
    }
  });
  test(
    'repository sends JWT to parkings, handles empty and rejects malformed lists',
    () async {
      Object? payload = [testParking];
      final api = ApiClient(
        config: ApiConfig(baseUrl: 'https://example.test/api/'),
        tokenProvider: MemoryTokens('jwt'),
        client: MockClient((request) async {
          expect(request.url.path, '/api/parkings');
          expect(request.headers['Authorization'], 'Bearer jwt');
          return jsonResponse(payload);
        }),
      );
      addTearDown(api.close);
      final repository = ParkingRepository(api);
      expect((await repository.fetchAll()).single.id, 7);
      payload = [];
      expect(await repository.fetchAll(), isEmpty);
      for (final bad in [
        null,
        {},
        [testParking, testParking],
        [
          {'id': 1},
        ],
      ]) {
        payload = bad;
        await expectLater(repository.fetchAll(), throwsA(isA<ApiException>()));
      }
    },
  );
  testWidgets('loading, API failure, retry and empty state', (tester) async {
    final pending = Completer<http.Response>();
    var requests = 0;
    final api = ApiClient(
      config: ApiConfig(baseUrl: 'https://example.test/api/'),
      client: MockClient(
        (_) =>
            ++requests == 1 ? pending.future : Future.value(jsonResponse([])),
      ),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: MapScreen(repository: ParkingRepository(api))),
      ),
    );
    await tester.pump();
    expect(find.text('Загрузка парковок…'), findsOneWidget);
    pending.complete(jsonResponse({}, 503));
    await tester.pumpAndSettle();
    expect(find.text('Не удалось загрузить данные'), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('Парковки пока не найдены.'), findsOneWidget);
    expect(requests, 2);
  });
  testWidgets(
    '401 from parking API invalidates session and redirects to login',
    (tester) async {
      final tokens = MemoryTokens('expired');
      final auth = fixture(
        tokens: tokens,
        handler: (_) async => jsonResponse({}, 401),
      )..status = AuthStatus.signedIn;
      final router = createAppRouter(auth: auth);
      addTearDown(auth.dispose);
      addTearDown(router.dispose);
      await tester.pumpWidget(EasyParkApp(router: router));
      await tester.pumpAndSettle();
      expect(tokens.value, isNull);
      expect(find.text('Вход в систему'), findsOneWidget);
      expect(find.byType(ParkingMap), findsNothing);
    },
  );
  for (final width in [390.0, 320.0]) {
    testWidgets('marker opens scrollable card and details route at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = width == 320 ? 2 : 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final api = ApiClient(
        config: ApiConfig(baseUrl: 'https://example.test/api/'),
        client: MockClient((_) async => jsonResponse([testParking])),
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: MapScreen(
                repository: ParkingRepository(api),
                tileProviderFactory: MemoryTileProvider.new,
              ),
            ),
          ),
          GoRoute(
            path: '/parking/:id',
            builder: (_, state) =>
                Scaffold(body: Text('Details ${state.pathParameters['id']}')),
          ),
        ],
      );
      addTearDown(api.close);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      );
      await tester.pumpAndSettle();
      final layer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
      expect(layer.markers.single.point.latitude, testParking['latitude']);
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('parking-marker-7')));
      await tester.pumpAndSettle();
      expect(find.byType(ParkingSummary), findsOneWidget);
      expect(find.text('120,50 ₽/час'), findsOneWidget);
      await tester.ensureVisible(find.text('Подробнее'));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Подробнее'));
      await tester.pumpAndSettle();
      expect(find.text('Details 7'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(ParkingMap), findsOneWidget);
      expect(find.byType(ParkingSummary), findsNothing);
    });
  }
}
