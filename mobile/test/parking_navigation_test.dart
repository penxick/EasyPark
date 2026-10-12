import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:easypark/features/map/parking_navigation.dart';
import 'package:easypark/features/map/parking_map.dart';
import 'package:easypark/features/map/parking_repository.dart';
import 'package:easypark/features/map/map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'support/auth_fixture.dart';
import 'support/map_fixture.dart';

class TimeoutLocationPlatform extends GeolocatorPlatform {
  final requests = <LocationSettings?>[];
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    requests.add(locationSettings);
    if (requests.length == 1) throw TimeoutException('Fused provider timeout');
    return Position(
      longitude: 92,
      latitude: 56,
      timestamp: DateTime(2026),
      accuracy: 1,
      altitude: 0,
      altitudeAccuracy: 1,
      heading: 0,
      headingAccuracy: 1,
      speed: 0,
      speedAccuracy: 1,
    );
  }
}

class TestNavigation extends ParkingNavigation {
  int locations = 0;
  bool fail = false;
  @override
  Future<LatLng> locate() async {
    locations++;
    if (fail) throw const NavigationFailure('Геолокация отключена.');
    return const LatLng(56, 92.8);
  }

  @override
  Future<DrivingRoute> route(LatLng from, LatLng to) async =>
      DrivingRoute([from, to], 2500, 300);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test('timeout fallback is Android-only: $platform', () async {
      final original = GeolocatorPlatform.instance;
      final fake = TimeoutLocationPlatform();
      GeolocatorPlatform.instance = fake;
      debugDefaultTargetPlatformOverride = platform;
      final service = ParkingNavigation();
      addTearDown(() {
        service.dispose();
        GeolocatorPlatform.instance = original;
        debugDefaultTargetPlatformOverride = null;
      });
      if (platform == TargetPlatform.android) {
        expect(await service.locate(), const LatLng(56, 92));
        expect(fake.requests, hasLength(2));
        expect(
          (fake.requests.last as AndroidSettings).forceLocationManager,
          true,
        );
        expect(fake.requests.last!.timeLimit, const Duration(seconds: 15));
      } else {
        await expectLater(service.locate(), throwsA(isA<NavigationFailure>()));
        expect(fake.requests, hasLength(1));
      }
    });
  }
  test(
    'OSRM uses independent HTTPS client, driving GeoJSON and validates response',
    () async {
      final service = ParkingNavigation(
        client: MockClient((r) async {
          expect(r.url.scheme, 'https');
          expect(r.url.path, contains('/driving/92.0,56.0;93.0,57.0'));
          expect(r.headers.containsKey('Authorization'), false);
          return http.Response(
            jsonEncode({
              'code': 'Ok',
              'routes': [
                {
                  'distance': 1234,
                  'duration': 300,
                  'geometry': {
                    'type': 'LineString',
                    'coordinates': [
                      [92, 56],
                      [93, 57],
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(service.dispose);
      final result = await service.route(
        const LatLng(56, 92),
        const LatLng(57, 93),
      );
      expect(result.points.last.latitude, 57);
      expect(result.distance, 1234);
    },
  );
  test('no route, invalid geometry and offline produce safe errors', () async {
    for (final body in [
      {'code': 'NoRoute'},
      {
        'code': 'Ok',
        'routes': [
          {
            'distance': 1,
            'duration': 2,
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                [92, 156],
                [93, 57],
              ],
            },
          },
        ],
      },
      null,
    ]) {
      final service = ParkingNavigation(
        client: MockClient((r) async {
          if (body == null) throw http.ClientException('private detail');
          return http.Response(jsonEncode(body), 200);
        }),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.route(const LatLng(56, 92), const LatLng(57, 93)),
        throwsA(isA<NavigationFailure>()),
      );
    }
  });
  test(
    'GPS off and permission rejection are handled without coordinates',
    () async {
      const channel = MethodChannel('flutter.baseflow.com/geolocator');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <String>[];
      var enabled = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'isLocationServiceEnabled') return enabled;
        if (call.method == 'checkPermission') return 0;
        if (call.method == 'requestPermission') return 0;
        throw StateError('Unexpected ${call.method}');
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final service = ParkingNavigation();
      addTearDown(service.dispose);
      await expectLater(service.locate(), throwsA(isA<NavigationFailure>()));
      expect(calls, ['isLocationServiceEnabled']);
      enabled = true;
      calls.clear();
      await expectLater(service.locate(), throwsA(isA<NavigationFailure>()));
      expect(calls, contains('requestPermission'));
      expect(calls, isNot(contains('getCurrentPosition')));
    },
  );
  testWidgets('user map zoom, on-demand location, route, hide and GPS error', (
    tester,
  ) async {
    final nav = TestNavigation();
    addTearDown(nav.dispose);
    final auth = fixture(handler: (_) async => jsonResponse([testParking]));
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapScreen(
            repository: ParkingRepository(auth.repository.api),
            navigation: nav,
            tileProviderFactory: MemoryTileProvider.new,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(nav.locations, 0);
    final context = tester.element(find.byType(TileLayer));
    final initial = MapCamera.of(context).zoom;
    await tester.tap(find.byTooltip('Приблизить'));
    await tester.pumpAndSettle();
    expect(MapCamera.of(context).zoom, initial + 1);
    await tester.tap(find.byTooltip('Отдалить'));
    await tester.pumpAndSettle();
    expect(MapCamera.of(context).zoom, initial);
    await tester.tap(find.byTooltip('Моё местоположение'));
    await tester.pumpAndSettle();
    expect(nav.locations, 1);
    expect(
      tester.widget<ParkingMap>(find.byType(ParkingMap)).userPoint,
      isNotNull,
    );
    await tester.tap(find.byTooltip('Показать все парковки'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Моё местоположение'));
    await tester.pumpAndSettle();
    expect(nav.locations, 2);
    expect(
      MapCamera.of(context).center,
      tester.widget<ParkingMap>(find.byType(ParkingMap)).userPoint,
    );
    await tester.tap(find.byTooltip('Показать все парковки'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('parking-marker-7')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Построить маршрут'));
    await tester.tap(find.text('Построить маршрут'));
    await tester.pumpAndSettle();
    expect(find.byType(PolylineLayer), findsOneWidget);
    expect(find.text('2.5 км · ≈ 5 мин'), findsOneWidget);
    await tester.tap(find.text('Скрыть маршрут'));
    await tester.pumpAndSettle();
    expect(find.byType(PolylineLayer), findsNothing);
    nav.fail = true;
    await tester.tap(find.byTooltip('Моё местоположение'));
    await tester.pumpAndSettle();
    expect(find.text('Геолокация отключена.'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
