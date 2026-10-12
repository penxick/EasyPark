import 'package:easypark/features/map/parking_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:integration_test/integration_test.dart';

// Host setup: grant foreground location to the test APK and continuously send
// `adb emu geo fix 92.852572 56.010563` while this test requests a fresh fix.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android foreground GPS returns the injected emulator position', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('GPS device check'))),
    );
    debugPrint('GPS_DEVICE_READY');
    var permission = await Geolocator.checkPermission();
    final deadline = DateTime.now().add(const Duration(seconds: 45));
    while (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      permission = await Geolocator.checkPermission();
    }
    expect(
      permission,
      anyOf(LocationPermission.whileInUse, LocationPermission.always),
    );
    final navigation = ParkingNavigation();
    addTearDown(navigation.dispose);
    final point = await navigation.locate();
    expect(point.latitude, closeTo(56.010563, 0.001));
    expect(point.longitude, closeTo(92.852572, 0.001));
  });
}
