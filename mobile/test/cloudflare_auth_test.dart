import 'dart:io' show HandshakeException;
import 'package:easypark/core/api/api_client.dart';
import 'package:easypark/core/constants/api_config.dart';
import 'package:easypark/core/storage/server_address_storage.dart';
import 'package:easypark/features/auth/auth_controller.dart';
import 'package:easypark/features/auth/auth_repository.dart';
import 'package:easypark/features/map/parking_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'support/auth_fixture.dart';

class SavedAddress extends ServerAddressStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String address) async {
    value = address;
  }
}

void main() {
  test(
    'bare origin previously resolves login without api; server normalization fixes it',
    () {
      expect(
        ApiConfig(
          baseUrl: 'https://example.trycloudflare.com',
        ).baseUri.resolve('auth/login').path,
        '/auth/login',
      );
      for (final suffix in ['', '/', '/api', '/api/']) {
        expect(
          ApiConfig.forServer(
            'https://example.trycloudflare.com$suffix',
          ).baseUri.resolve('auth/login').path,
          '/api/auth/login',
        );
      }
      expect(
        () => ApiConfig.forServer('https://example.test/api/api'),
        throwsArgumentError,
      );
    },
  );
  test(
    'switch and restart share current API for login registration and parkings',
    () async {
      final tokens = MemoryTokens();
      final saved = SavedAddress();
      final requests = <http.Request>[];
      await http.runWithClient(
        () async {
          AuthController make() => AuthController(
            AuthRepository(
              tokens: tokens,
              api: ApiClient(
                config: ApiConfig(baseUrl: 'http://10.0.2.2:3000/api/'),
              ),
            ),
            serverStorage: saved,
          );
          final auth = make();
          addTearDown(auth.dispose);
          await auth.changeServer('https://example.trycloudflare.com');
          await auth.login('test@example.test', 'not-a-real-password');
          expect(auth.status, AuthStatus.signedIn);
          await auth.register(
            'Test',
            'test@example.test',
            'not-a-real-password',
          );
          await ParkingRepository(auth.repository.api).fetchAll();
          final restarted = make();
          addTearDown(restarted.dispose);
          await restarted.restore();
          await restarted.login('test@example.test', 'not-a-real-password');
          expect(restarted.status, AuthStatus.signedIn);
          expect(requests.map((r) => '${r.method} ${r.url.path}'), [
            'POST /api/auth/login',
            'POST /api/auth/register',
            'GET /api/parkings',
            'GET /api/users/me',
            'POST /api/auth/login',
          ]);
          expect(
            requests.every((r) => r.url.host == 'example.trycloudflare.com'),
            isTrue,
          );
          expect(saved.value, 'https://example.trycloudflare.com/api/');
        },
        () => MockClient((r) async {
          requests.add(r);
          if (r.url.path.endsWith('/parkings')) return jsonResponse([]);
          if (r.url.path.endsWith('/me')) return jsonResponse(testUser);
          return sessionResponse();
        }),
      );
    },
  );
  for (final status in [400, 401, 404, 500]) {
    test(
      'auth HTTP $status is reported distinctly and diagnostic excludes secrets',
      () async {
        final lines = <String>[];
        final original = debugPrint;
        debugPrint = (String? message, {int? wrapWidth}) {
          lines.add(message ?? '');
        };
        addTearDown(() {
          debugPrint = original;
        });
        final auth = fixture(handler: (_) async => jsonResponse({}, status));
        addTearDown(auth.dispose);
        await auth.login('private@example.test', 'never-log-this-password');
        final expected = switch (status) {
          400 => 'Проверьте введённые данные.',
          401 => 'Неверный логин, email или пароль.',
          404 => 'Сервер не поддерживает запрошенный адрес API.',
          _ => 'Ошибка сервера. Попробуйте позже.',
        };
        expect(auth.error, expected);
        expect(
          lines.join(),
          contains('POST https://example.test/api/auth/login status=$status'),
        );
        expect(lines.join(), isNot(contains('private@example.test')));
        expect(lines.join(), isNot(contains('never-log-this-password')));
      },
    );
  }
  test('TLS failure is reported as connection failure', () async {
    final auth = fixture(
      handler: (_) async => throw const HandshakeException('private detail'),
    );
    addTearDown(auth.dispose);
    await auth.login('test@example.test', 'test-password');
    expect(auth.error, 'Не удалось подключиться к серверу.');
  });
  test('network failure is safe and distinct from 404', () async {
    final auth = fixture(
      handler: (_) async =>
          throw http.ClientException('Failed host lookup: example.test'),
    );
    addTearDown(auth.dispose);
    await auth.login('test@example.test', 'test-password');
    expect(auth.error, 'Не удалось подключиться к серверу.');
  });
}
