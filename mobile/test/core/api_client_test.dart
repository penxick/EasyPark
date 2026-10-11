import 'dart:convert';

import 'package:easypark/core/api/api_client.dart';
import 'package:easypark/core/api/api_exception.dart';
import 'package:easypark/core/constants/api_config.dart';
import 'package:easypark/core/storage/token_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class TestTokens implements TokenProvider {
  String? value = 'first-token';
  @override
  Future<String?> readToken() async => value;
}

Matcher errorKind(ApiErrorKind kind) =>
    isA<ApiException>().having((error) => error.kind, 'kind', kind);

void main() {
  test(
    'JSON, UTF-8, relative paths, query and current JWT are handled',
    () async {
      final tokens = TestTokens();
      final requests = <http.Request>[];
      final api = ApiClient(
        config: ApiConfig(baseUrl: 'https://example.test/api'),
        tokenProvider: tokens,
        client: MockClient((request) async {
          requests.add(request);
          return http.Response.bytes(utf8.encode('{"name":"Парковка"}'), 200);
        }),
      );
      addTearDown(api.close);
      expect(await api.get('/parkings', query: {'search': 'ТЦ'}), {
        'name': 'Парковка',
      });
      tokens.value = 'second-token';
      await api.post('reservations', body: {'minutes': 30});
      expect(requests[0].url.path, '/api/parkings');
      expect(requests[0].url.queryParameters['search'], 'ТЦ');
      expect(requests[0].headers['Authorization'], 'Bearer first-token');
      expect(requests[1].headers['Authorization'], 'Bearer second-token');
      expect(requests[1].headers['content-type'], contains('application/json'));
      expect(jsonDecode(requests[1].body), {'minutes': 30});
      expect(requests[1].followRedirects, false);
    },
  );

  test(
    '401 reports session invalidation but public login does not attach token',
    () async {
      var invalidations = 0;
      final api = ApiClient(
        config: ApiConfig(baseUrl: 'https://example.test/api/'),
        tokenProvider: TestTokens(),
        onUnauthorized: () async {
          invalidations++;
        },
        client: MockClient((request) async {
          if (request.url.path.endsWith('/login')) {
            expect(request.headers.containsKey('Authorization'), false);
          }
          return http.Response('not JSON', 401);
        }),
      );
      addTearDown(api.close);
      await expectLater(
        api.get('users/me'),
        throwsA(errorKind(ApiErrorKind.unauthorized)),
      );
      await expectLater(
        api.post('auth/login', authenticated: false),
        throwsA(errorKind(ApiErrorKind.unauthorized)),
      );
      expect(invalidations, 1);
    },
  );

  test('session callback failure cannot hide HTTP 401', () async {
    final api = ApiClient(
      config: ApiConfig(baseUrl: 'https://example.test/api/'),
      tokenProvider: TestTokens(),
      onUnauthorized: () async => throw StateError('storage failed'),
      client: MockClient((_) async => http.Response('', 401)),
    );
    addTearDown(api.close);
    await expectLater(
      api.get('users/me'),
      throwsA(errorKind(ApiErrorKind.unauthorized)),
    );
  });

  for (final entry in {
    400: ApiErrorKind.validation,
    403: ApiErrorKind.forbidden,
    404: ApiErrorKind.notFound,
    500: ApiErrorKind.server,
    503: ApiErrorKind.server,
    302: ApiErrorKind.invalidResponse,
  }.entries) {
    test('HTTP ${entry.key} maps to safe error', () async {
      final api = ApiClient(
        config: ApiConfig(baseUrl: 'https://example.test/api/'),
        client: MockClient(
          (_) async => http.Response('private error', entry.key),
        ),
      );
      addTearDown(api.close);
      await expectLater(api.get('test'), throwsA(errorKind(entry.value)));
    });
  }

  test('PATCH and DELETE support an empty 204 response', () async {
    final methods = <String>[];
    final api = ApiClient(
      config: ApiConfig(baseUrl: 'https://example.test/api/'),
      client: MockClient((request) async {
        methods.add(request.method);
        return http.Response('', 204);
      }),
    );
    addTearDown(api.close);
    expect(await api.patch('test', body: {'value': true}), isNull);
    expect(await api.delete('test'), isNull);
    expect(methods, ['PATCH', 'DELETE']);
  });

  test('malformed success response becomes invalidResponse', () async {
    final api = ApiClient(
      config: ApiConfig(baseUrl: 'https://example.test/api/'),
      client: MockClient((_) async => http.Response('<html>', 200)),
    );
    addTearDown(api.close);
    await expectLater(
      api.get('test'),
      throwsA(errorKind(ApiErrorKind.invalidResponse)),
    );
  });

  test('transport errors and timeouts are normalized', () async {
    final broken = ApiClient(
      config: ApiConfig(baseUrl: 'https://example.test/api/'),
      client: MockClient((_) async => throw http.ClientException('secret URL')),
    );
    final slow = ApiClient(
      config: ApiConfig(
        baseUrl: 'http://localhost/api',
        timeout: const Duration(milliseconds: 5),
      ),
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return http.Response('{}', 200);
      }),
    );
    addTearDown(broken.close);
    addTearDown(slow.close);
    await expectLater(
      broken.get('test'),
      throwsA(errorKind(ApiErrorKind.network)),
    );
    await expectLater(
      slow.get('test'),
      throwsA(errorKind(ApiErrorKind.timeout)),
    );
  });

  test('foreign URLs and traversal are rejected before transport', () async {
    final api = ApiClient(
      config: ApiConfig(baseUrl: 'https://example.test/api/'),
      client: MockClient((_) async => fail('must not send')),
    );
    addTearDown(api.close);
    for (final path in [
      'https://other.test',
      '//other.test',
      '../health',
      '%2e%2e/health',
      'test#fragment',
    ]) {
      await expectLater(
        api.get(path),
        throwsA(errorKind(ApiErrorKind.invalidRequest)),
      );
    }
  });

  test('invalid configuration is rejected', () {
    for (final url in [
      '',
      'not a url',
      'ftp://server/api',
      'https://user:pass@host/api',
      'http://host/api?token=x',
    ]) {
      expect(() => ApiConfig(baseUrl: url), throwsArgumentError);
    }
    expect(
      () => ApiConfig(baseUrl: 'http://host', timeout: Duration.zero),
      throwsArgumentError,
    );
  });
}
