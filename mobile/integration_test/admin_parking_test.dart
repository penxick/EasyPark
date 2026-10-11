import 'package:easypark/app.dart';
import 'package:easypark/features/auth/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android ADMIN parking CRUD through real API', (tester) async {
    const login = String.fromEnvironment('TEST_LOGIN');
    const password = String.fromEnvironment('TEST_PASSWORD');
    expect(login.startsWith('a8-'), true);
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

    await tester.enterText(field('auth-email'), login);
    await tester.enterText(field('auth-password'), password);
    await tap('Войти');
    expect(find.text('Обзор системы'), findsOneWidget);
    await tester.tap(find.byTooltip('Административное меню'));
    await tester.pumpAndSettle();
    await tap('Парковки');
    await tap('+ Добавить парковку');
    for (final entry in {
      'name': login,
      'description': 'Проверка A8',
      'address': 'Тестовый адрес A8',
      'workingHours': '24/7',
      'pricePerHour': '0',
      'latitude': '56.01',
      'longitude': '92.01',
    }.entries) {
      await tester.ensureVisible(field('parking-${entry.key}'));
      await tester.enterText(field('parking-${entry.key}'), entry.value);
    }
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('a8-form');
    await tap('Создать');
    expect(find.text('Информация о парковке'), findsOneWidget);
    expect(find.text(login), findsOneWidget);
    await binding.takeScreenshot('a8-details');
    await tap('Редактировать');
    await tester.ensureVisible(field('parking-address'));
    await tester.enterText(field('parking-address'), 'Обновлённый адрес A8');
    await tap('Сохранить');
    expect(find.text('Обновлённый адрес A8'), findsOneWidget);
    final rows = await auth.repository.api.get('parkings') as List;
    expect(
      rows.where((p) => p['name'] == login).single['address'],
      'Обновлённый адрес A8',
    );
    await tap('Удалить парковку');
    await tap('Отмена');
    expect(find.text(login), findsOneWidget);
    await tap('Удалить парковку');
    await tap('Удалить');
    expect(find.text('+ Добавить парковку'), findsOneWidget);
    final remaining = await auth.repository.api.get('parkings') as List;
    expect(remaining.where((p) => p['name'] == login), isEmpty);
    await binding.takeScreenshot('a8-list');
    await auth.logout();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
  });
}
