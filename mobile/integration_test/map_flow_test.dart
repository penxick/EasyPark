import 'package:easypark/app.dart';
import 'package:easypark/core/router/app_router.dart';
import 'package:easypark/features/auth/auth_controller.dart';
import 'package:easypark/features/map/parking_map.dart';
import 'package:easypark/features/map/parking_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android map loads real parkings and opens their summary', (
    tester,
  ) async {
    const email = String.fromEnvironment('TEST_EMAIL');
    expect(
      RegExp(r'^stage8-[a-f0-9]{32}@example\.com$').hasMatch(email),
      isTrue,
    );
    final auth = AuthController.platform();
    await auth.register(
      'Проверка карты',
      email,
      'EasyPark stage8 test password',
    );
    expect(auth.status, AuthStatus.signedIn, reason: auth.error);
    final router = createAppRouter(auth: auth);
    await tester.pumpWidget(EasyParkApp(router: router));
    for (
      var i = 0;
      i < 100 && find.byType(ParkingMap).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(ParkingMap), findsOneWidget);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 200),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 40),
    );
    final layer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
    expect(layer.markers.length, greaterThanOrEqualTo(3));
    final map = tester.widget<ParkingMap>(find.byType(ParkingMap));
    final parking = map.parkings.first;
    final element = tester.element(find.byType(ParkingMap));
    await tester.tap(find.text('Бронирования'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Карта'));
    await tester.pumpAndSettle();
    expect(tester.element(find.byType(ParkingMap)), same(element));
    await tester.tap(find.byKey(ValueKey('parking-marker-${parking.id}')));
    await tester.pumpAndSettle();
    expect(find.byType(ParkingSummary), findsOneWidget);
    expect(find.text(parking.name), findsOneWidget);
    expect(find.text(parking.formattedPrice), findsOneWidget);
    await tester.tap(find.text('Подробнее'));
    await tester.pumpAndSettle();
    expect(find.text(parking.name), findsOneWidget);
    expect(find.text('Режим работы'), findsOneWidget);
    await tester.ensureVisible(find.text('Выбрать место'));
    await tester.tap(find.text('Выбрать место'));
    await tester.pumpAndSettle();
    expect(find.text('A01'), findsOneWidget);
    expect(find.text('D05'), findsOneWidget);
    expect(find.text('Свободно: 11 из 20'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ParkingMap), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('parking-marker-${parking.id}')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Keep the last frame available for a host-side screenshot after the test.
  });
}
