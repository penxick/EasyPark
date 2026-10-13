import 'package:easypark/core/api/api_client.dart';
import 'package:easypark/core/constants/api_config.dart';
import 'package:easypark/core/storage/server_address_storage.dart';
import 'package:easypark/features/auth/auth_controller.dart';
import 'package:easypark/features/auth/auth_repository.dart';
import 'package:easypark/features/auth/server_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'support/auth_fixture.dart';

class Addresses extends ServerAddressStorage {
  String? value = 'https://old.test/api/';
  @override
  Future<void> write(String address) async {
    value = address;
  }
}

void main() {
  const good = {'status': 'ok', 'service': 'easypark-backend'};
  for (final suffix in ['/api/', '/api', '/', '']) {
    testWidgets('root health and save API URL $suffix', (tester) async {
      final tokens = MemoryTokens('old-token');
      final addresses = Addresses();
      final auth = AuthController(
        AuthRepository(
          tokens: tokens,
          api: ApiClient(config: ApiConfig(baseUrl: 'https://old.test/api/')),
        ),
        serverStorage: addresses,
      )..status = AuthStatus.signedIn;
      addTearDown(auth.dispose);
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ServerSettingsScreen(
            auth: auth,
            probeFactory: (config) => ApiClient(
              config: config,
              client: MockClient((r) async {
                calls++;
                expect(r.url.toString(), 'https://new.test:8443/health');
                expect(r.headers.containsKey('Authorization'), isFalse);
                return jsonResponse(good);
              }),
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byType(TextField),
        'https://new.test:8443$suffix',
      );
      await tester.tap(find.text('Проверить подключение'));
      await tester.pumpAndSettle();
      expect(tokens.value, 'old-token');
      expect(addresses.value, 'https://old.test/api/');
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(tokens.value, isNull);
      expect(auth.status, AuthStatus.signedOut);
      expect(
        addresses.value,
        ApiConfig.forServer('https://new.test:8443$suffix').baseUri.toString(),
      );
    });
  }
  for (final status in [404, 401, 500, 201, 204, 302, 200]) {
    testWidgets('failed health $status preserves address and authorization', (
      tester,
    ) async {
      final tokens = MemoryTokens('old-token');
      final addresses = Addresses();
      final auth = AuthController(
        AuthRepository(
          tokens: tokens,
          api: ApiClient(config: ApiConfig(baseUrl: 'https://old.test/api/')),
        ),
        serverStorage: addresses,
      )..status = AuthStatus.signedIn;
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ServerSettingsScreen(
            auth: auth,
            probeFactory: (config) => ApiClient(
              config: config,
              client: MockClient(
                (r) async => jsonResponse(
                  status == 200 ? {'status': 'ok', 'service': 'other'} : good,
                  status,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'https://new.test/api');
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(tokens.value, 'old-token');
      expect(auth.status, AuthStatus.signedIn);
      expect(addresses.value, 'https://old.test/api/');
      expect(auth.repository.api.config.baseUri.host, 'old.test');
      expect(find.textContaining('Не удалось проверить'), findsOneWidget);
    });
  }
  for (final suffix in ['/api/', '/api']) {
    test('normal API paths retain prefix exactly once $suffix', () async {
      final api = ApiClient(
        config: ApiConfig(baseUrl: 'https://new.test$suffix'),
        client: MockClient((r) async {
          expect(
            r.url.path,
            matches(r'^/api/(auth/login|auth/register|parkings|reservations)$'),
          );
          return jsonResponse({});
        }),
      );
      addTearDown(api.close);
      for (final path in [
        'auth/login',
        'auth/register',
        'parkings',
        'reservations',
      ]) {
        await api.request('GET', path, authenticated: false);
      }
    });
  }
}
