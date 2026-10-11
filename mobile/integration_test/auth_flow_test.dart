import 'package:easypark/app.dart';
import 'dart:convert';
import 'package:easypark/core/api/api_client.dart';
import 'package:easypark/features/auth/auth_repository.dart';
import 'package:http/http.dart' as http;
import 'package:easypark/core/storage/token_storage.dart';
import 'package:easypark/features/auth/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real backend registration, KeyStore restore and login', (
    tester,
  ) async {
    const email = String.fromEnvironment('TEST_EMAIL');
    expect(email.startsWith('stage5-'), true);
    const password = 'EasyPark integration password';
    final tokens = SecureTokenStorage();
    await tokens.deleteToken();
    final checks = <String>[];
    AuthController createAuth() {
      late final AuthController controller;
      final storage = SecureTokenStorage();
      controller = AuthController(
        AuthRepository(
          tokens: storage,
          api: ApiClient(
            tokenProvider: storage,
            onUnauthorized: () => controller.invalidate(),
            client: _TracingClient(checks, email, password),
          ),
        ),
      );
      return controller;
    }

    var auth = createAuth();
    await tester.pumpWidget(EasyParkApp(auth: auth));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Зарегистрироваться'));
    await tester.pumpAndSettle();
    Finder field(String name) => find.descendant(
      of: find.byKey(ValueKey('auth-$name')),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(field('name'), 'Проверка Android');
    await tester.enterText(field('email'), email);
    await tester.enterText(field('password'), password);
    await tester.enterText(field('confirm'), password);
    await tester.ensureVisible(find.text('Создать аккаунт'));
    await tester.tap(find.text('Создать аккаунт'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 250),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 40),
    );
    expect(
      find.text('Карта'),
      findsOneWidget,
      reason: auth.error ?? auth.status.name,
    );
    expect(await tokens.readToken(), isNotEmpty);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
    auth = createAuth();
    await tester.pumpWidget(EasyParkApp(auth: auth));
    await tester.pumpAndSettle();
    expect(
      find.text('Карта'),
      findsOneWidget,
      reason: auth.error ?? auth.status.name,
    );
    await auth.invalidate();
    await tester.pumpAndSettle();
    expect(await tokens.readToken(), isNull);
    await tester.enterText(field('email'), email);
    await tester.enterText(field('password'), 'wrong-password');
    await tester.ensureVisible(find.text('Войти'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();
    expect(find.text('Неверный email или пароль.'), findsOneWidget);
    // Wait for the native IME to reconnect after the disabled/loading state.
    await tester.tap(field('password'));
    await tester.pumpAndSettle();
    await tester.enterText(field('password'), password);
    await tester.ensureVisible(find.text('Войти'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(field('password')).controller!.text ==
          password,
      true,
      reason: 'Native IME must apply the replacement password',
    );
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();
    expect(
      find.text('Карта'),
      findsOneWidget,
      reason: auth.error ?? auth.status.name,
    );
    // Leave this temporary session stored to verify a real process restart via adb.
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
  });
}

class _TracingClient extends http.BaseClient {
  _TracingClient(this.checks, this.email, this.password);
  final List<String> checks;
  final String email, password;
  final _inner = http.Client();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request is http.Request && request.url.path.endsWith('/auth/login')) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      checks.add(
        'email matches: ${body['login'] == email}, password matches: ${body['password'] == password}',
      );
      debugPrint('Auth test request checks: $checks');
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
