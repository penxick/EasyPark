import 'dart:async';
import 'dart:convert';
import 'package:easypark/features/auth/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'support/auth_fixture.dart';

void main() {
  test('empty storage opens login without requesting API', () async {
    final auth = fixture(
      handler: (_) async => throw StateError('must not call API'),
    );
    addTearDown(auth.dispose);
    await auth.restore();
    expect(auth.status, AuthStatus.signedOut);
  });

  test(
    'register sends only contract fields, saves token and restores with a new controller',
    () async {
      final tokens = MemoryTokens();
      final requests = <http.Request>[];
      final auth = fixture(
        tokens: tokens,
        handler: (request) async {
          requests.add(request);
          return sessionResponse();
        },
      );
      await auth.restore();
      await auth.register(' Роман ', ' ROMAN@EXAMPLE.COM ', '  пароль 🔑  ');
      expect(auth.status, AuthStatus.signedIn);
      expect(tokens.value, 'test-token');
      expect(jsonDecode(requests.single.body), {
        'name': 'Роман',
        'email': 'roman@example.com',
        'password': '  пароль 🔑  ',
      });
      expect(requests.single.headers['Authorization'], isNull);
      auth.dispose();
      final restarted = fixture(
        tokens: tokens,
        handler: (request) async {
          expect(request.url.path, '/api/users/me');
          expect(request.headers['Authorization'], 'Bearer test-token');
          return jsonResponse(testUser);
        },
      );
      addTearDown(restarted.dispose);
      await restarted.restore();
      expect(restarted.status, AuthStatus.signedIn);
      expect(restarted.user?.name, 'Роман');
    },
  );

  test(
    '401 removes expired token, network failure preserves it for retry',
    () async {
      final tokens = MemoryTokens('expired');
      var code = 401;
      final auth = fixture(
        tokens: tokens,
        handler: (_) async => jsonResponse(testUser, code),
      );
      addTearDown(auth.dispose);
      await auth.restore();
      expect(auth.status, AuthStatus.signedOut);
      expect(tokens.value, isNull);
      tokens.value = 'valid';
      code = 503;
      await auth.restore();
      expect(auth.status, AuthStatus.restoreError);
      expect(tokens.value, 'valid');
      code = 200;
      await auth.restore();
      expect(auth.status, AuthStatus.signedIn);
    },
  );

  test(
    'safe messages for wrong password, duplicate email and rate limiting',
    () async {
      var code = 401;
      final auth = fixture(
        handler: (_) async =>
            jsonResponse({'private': 'secret server data'}, code),
      );
      addTearDown(auth.dispose);
      await auth.restore();
      for (final entry in {
        401: 'Неверный email или пароль.',
        409: 'Пользователь с таким email уже существует.',
        429: 'Слишком много попыток.',
      }.entries) {
        code = entry.key;
        await auth.login('roman@example.com', 'incorrect');
        expect(auth.error, startsWith(entry.value));
        expect(auth.status, AuthStatus.signedOut);
        expect(auth.busy, false);
      }
    },
  );

  test(
    'storage failures do not grant access or discard recovery state',
    () async {
      final tokens = MemoryTokens()..failRead = true;
      final auth = fixture(
        tokens: tokens,
        handler: (_) async => sessionResponse(),
      );
      addTearDown(auth.dispose);
      await auth.restore();
      expect(auth.status, AuthStatus.restoreError);
      tokens.failRead = false;
      await auth.restore();
      tokens.failWrite = true;
      await auth.login('roman@example.com', 'password');
      expect(auth.status, AuthStatus.signedOut);
      expect(tokens.value, isNull);
      tokens.failDelete = true;
      await auth.invalidate();
      expect(auth.status, AuthStatus.restoreError);
      expect(auth.error, contains('хранилищу'));
    },
  );

  test(
    'busy suppresses duplicate submits; invalidation prevents late login persistence',
    () async {
      final pending = Completer<http.Response>();
      final tokens = MemoryTokens();
      var calls = 0;
      final auth = fixture(
        tokens: tokens,
        handler: (_) {
          calls++;
          return pending.future;
        },
      );
      addTearDown(auth.dispose);
      await auth.restore();
      final first = auth.login('roman@example.com', 'password');
      await auth.login('roman@example.com', 'password');
      await auth.invalidate();
      pending.complete(sessionResponse());
      await first;
      expect(calls, 1);
      expect(tokens.value, isNull);
      expect(auth.status, AuthStatus.signedOut);
    },
  );

  test(
    'late 401 from an old token does not invalidate a newer session',
    () async {
      final tokens = MemoryTokens('old-token');
      final pending = Completer<http.Response>();
      final sent = Completer<void>();
      final auth = fixture(
        tokens: tokens,
        handler: (_) {
          sent.complete();
          return pending.future;
        },
      );
      addTearDown(auth.dispose);
      final result = auth.repository.me();
      await sent.future;
      tokens.value = 'new-token';
      pending.complete(jsonResponse({}, 401));
      await expectLater(result, throwsException);
      expect(tokens.value, 'new-token');
    },
  );

  test(
    'malformed successful response is rejected and disposed controllers do not publish',
    () async {
      final tokens = MemoryTokens();
      final auth = fixture(
        tokens: tokens,
        handler: (_) async =>
            jsonResponse({'accessToken': 'token', 'user': {}}),
      );
      await auth.restore();
      await auth.login('roman@example.com', 'password');
      expect(auth.status, AuthStatus.signedOut);
      expect(tokens.value, isNull);
      auth.dispose();
      await auth.restore();
      await auth.login('roman@example.com', 'password');
    },
  );
}
