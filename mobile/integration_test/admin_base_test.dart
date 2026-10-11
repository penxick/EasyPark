import 'package:easypark/app.dart';
import 'package:easypark/features/auth/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android ADMIN login, restore, real dashboard, menu and logout', (
    tester,
  ) async {
    // Supply a disposable test ADMIN; never compile the system administrator password.
    const login = String.fromEnvironment('TEST_LOGIN');
    const password = String.fromEnvironment('TEST_PASSWORD');
    expect(login.startsWith('a7-'), true);
    expect(password.isNotEmpty, true);
    var auth = AuthController.platform();
    await auth.repository.tokens.deleteToken();
    await tester.pumpWidget(EasyParkApp(auth: auth));
    await tester.pumpAndSettle();
    Finder field(String name) => find.descendant(
      of: find.byKey(ValueKey('auth-$name')),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(field('email'), login);
    await tester.enterText(field('password'), password);
    await tester.ensureVisible(find.text('Войти'));
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 250),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 40),
    );
    expect(find.text('Обзор системы'), findsOneWidget);
    expect(auth.isAdmin, true);
    expect(find.text('Ошибка загрузки аналитики'), findsNothing);
    expect(await auth.repository.tokens.readToken(), isNotEmpty);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
    auth = AuthController.platform();
    await tester.pumpWidget(EasyParkApp(auth: auth));
    await tester.pumpAndSettle();
    expect(auth.isAdmin, true);
    expect(find.text('Обзор системы'), findsOneWidget);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('a7-dashboard');
    await tester.ensureVisible(find.text('Загруженность парковок'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('a7-dashboard-bottom');
    await tester.tap(find.byTooltip('Административное меню'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('a7-menu');
    await tester.tap(find.byKey(const ValueKey('admin-nav-5')));
    await tester.pumpAndSettle();
    expect(find.text('Профиль администратора'), findsOneWidget);
    await tester.ensureVisible(find.text('Выйти'));
    await tester.tap(find.text('Выйти'));
    await tester.pumpAndSettle();
    expect(find.text('Вход в систему'), findsOneWidget);
    expect(await auth.repository.tokens.readToken(), isNull);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
  });
}
