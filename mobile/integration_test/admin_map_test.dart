import 'package:easypark/app.dart';
import 'package:easypark/features/auth/auth_controller.dart';
import 'package:easypark/features/map/parking_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android map create, relocate and USER visibility', (
    tester,
  ) async {
    const login = String.fromEnvironment('TEST_LOGIN');
    const password = String.fromEnvironment('TEST_PASSWORD');
    const userEmail = String.fromEnvironment('TEST_USER_EMAIL');
    expect(login.startsWith('a9-'), true);
    final auth = AuthController.platform();
    await auth.repository.tokens.deleteToken();
    await tester.pumpWidget(EasyParkApp(auth: auth));
    await tester.pumpAndSettle();
    Finder field(String key) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(TextFormField),
    );
    Future<void> tap(String label) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    Future<void> pick() async {
      final map = find.byType(FlutterMap).last;
      await tester.ensureVisible(map);
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(map) + const Offset(-50, 20));
      await tester.pumpAndSettle(const Duration(milliseconds: 350));
    }

    await tester.enterText(field('auth-email'), login);
    await tester.enterText(field('auth-password'), password);
    await tap('Войти');
    await tester.tap(find.byTooltip('Административное меню'));
    await tester.pumpAndSettle();
    await tap('Парковки');
    await tap('Открыть карту');
    await tap('+ Добавить парковку');
    await pick();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('a9-pick');
    await tap('Продолжить');
    for (final entry in {
      'name': login,
      'description': 'Проверка A9',
      'address': 'Тест A9',
      'pricePerHour': '0',
      'workingHours': '24/7',
    }.entries) {
      await tester.ensureVisible(field('parking-${entry.key}'));
      await tester.enterText(field('parking-${entry.key}'), entry.value);
    }
    await tap('Создать');
    final map = tester.widget<ParkingMap>(find.byType(ParkingMap));
    final created = map.parkings.singleWhere((p) => p.name == login);
    final id = created.id;
    expect(find.byKey(ValueKey('parking-marker-$id')), findsOneWidget);
    await binding.takeScreenshot('a9-created');
    await tester.ensureVisible(find.byKey(ValueKey('parking-marker-$id')));
    await tester.tap(find.byKey(ValueKey('parking-marker-$id')));
    await tester.pumpAndSettle();
    await tap('Выбрать положение на карте');
    await pick();
    await tap('Выбрать точку');
    await tap('Сохранить');
    final updated = tester
        .widget<ParkingMap>(find.byType(ParkingMap))
        .parkings
        .singleWhere((p) => p.id == id);
    expect(updated.longitude, isNot(created.longitude));
    await auth.logout();
    await tester.pumpAndSettle();
    await tester.enterText(field('auth-email'), userEmail);
    await tester.enterText(field('auth-password'), password);
    await tap('Войти');
    expect(auth.isAdmin, false);
    final userParking = tester
        .widget<ParkingMap>(find.byType(ParkingMap))
        .parkings
        .singleWhere((p) => p.id == id);
    expect(userParking.latitude, updated.latitude);
    expect(userParking.longitude, updated.longitude);
    await auth.logout();
    await tester.pumpAndSettle();
    await auth.login(login, password);
    await auth.repository.api.delete('admin/parkings/$id');
    await auth.logout();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
  });
}
