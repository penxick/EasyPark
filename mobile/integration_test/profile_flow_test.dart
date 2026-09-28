import 'package:easypark/app.dart';
import 'package:easypark/core/router/app_router.dart';
import 'package:easypark/features/auth/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android profile reads real user and logout clears secure storage',
    (tester) async {
      const email = String.fromEnvironment('TEST_EMAIL');
      expect(
        RegExp(r'^stage15-[a-f0-9]{32}@example\.com$').hasMatch(email),
        isTrue,
      );
      final auth = AuthController.platform();
      await auth.register(
        'Проверка профиля',
        email,
        'EasyPark stage15 test password',
      );
      expect(auth.status, AuthStatus.signedIn, reason: auth.error);
      final router = createAppRouter(auth: auth, initialLocation: '/profile');
      await tester.pumpWidget(EasyParkApp(router: router));
      await tester.pumpAndSettle();
      expect(find.text('Проверка профиля'), findsOneWidget);
      expect(find.text(email), findsOneWidget);
      expect(find.text('Дата регистрации'), findsOneWidget);
      await tester.ensureVisible(find.text('Выйти'));
      await tester.tap(find.text('Выйти'));
      await tester.pumpAndSettle();
      expect(find.text('Вход в систему'), findsOneWidget);
      expect(await auth.repository.tokens.readToken(), isNull);
      router.go('/profile');
      await tester.pumpAndSettle();
      expect(find.text('Вход в систему'), findsOneWidget);
      final restored = AuthController.platform();
      await restored.restore();
      expect(restored.status, AuthStatus.signedOut);
      restored.dispose();
      await auth.login(email, 'EasyPark stage15 test password');
      expect(auth.status, AuthStatus.signedIn);
      router.go('/profile');
      await tester.pumpAndSettle();
      expect(find.text(email), findsOneWidget);
      await tester.ensureVisible(find.text('Выйти'));
      await tester.tap(find.text('Выйти'));
      await tester.pumpAndSettle();
      expect(await auth.repository.tokens.readToken(), isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
