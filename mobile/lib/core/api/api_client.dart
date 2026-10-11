import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/api_config.dart';
import '../storage/token_provider.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({
    ApiConfig? config,
    http.Client? client,
    this.tokenProvider,
    this.onUnauthorized,
  }) : config = config ?? ApiConfig.fromEnvironment(),
       _client = client ?? http.Client();

  final ApiConfig config;
  final http.Client _client;
  final TokenProvider? tokenProvider;
  final Future<void> Function()? onUnauthorized;

  Future<Object?> get(String path, {Map<String, String>? query}) =>
      request('GET', path, query: query);

  Future<Object?> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) => request('POST', path, body: body, authenticated: authenticated);

  Future<Object?> patch(String path, {Object? body}) =>
      request('PATCH', path, body: body);

  Future<Object?> delete(String path) => request('DELETE', path);

  Future<Object?> request(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    final uri = _resolve(path, query);
    final abort = Completer<void>();
    try {
      final token = authenticated
          ? await tokenProvider?.readToken().timeout(config.timeout)
          : null;
      final request =
          http.AbortableRequest(method, uri, abortTrigger: abort.future)
            ..followRedirects = false
            ..headers['Accept'] = 'application/json';
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      if (body != null) {
        request.headers['Content-Type'] = 'application/json; charset=utf-8';
        request.body = jsonEncode(body);
      }
      final response =
          await (() async {
            final streamed = await _client.send(request);
            return http.Response.fromStream(streamed);
          })().timeout(
            config.timeout,
            onTimeout: () {
              abort.complete();
              throw TimeoutException('API request timed out');
            },
          );

      if (response.statusCode == 401 && token != null && token.isNotEmpty) {
        try {
          // A late 401 from an old session must not clear a newly saved token.
          if (await tokenProvider?.readToken().timeout(config.timeout) ==
              token) {
            await onUnauthorized?.call().timeout(config.timeout);
          }
        } catch (_) {
          // A session handler failure must not hide the original HTTP 401.
        }
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          _httpError(response.statusCode),
          statusCode: response.statusCode,
          code: _publicErrorCode(response),
        );
      }
      if (response.statusCode == 204 || response.bodyBytes.isEmpty) return null;
      try {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        throw const ApiException(ApiErrorKind.invalidResponse);
      }
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(ApiErrorKind.timeout);
    } on http.ClientException {
      throw const ApiException(ApiErrorKind.network);
    } on JsonUnsupportedObjectError {
      throw const ApiException(ApiErrorKind.invalidRequest);
    } catch (_) {
      throw const ApiException(ApiErrorKind.unexpected);
    }
  }

  Uri _resolve(String path, Map<String, String>? query) {
    final relative = Uri.tryParse(path);
    if (relative == null ||
        relative.hasScheme ||
        relative.hasAuthority ||
        relative.hasFragment ||
        relative.pathSegments.any((s) => s == '..' || s == '.')) {
      throw const ApiException(ApiErrorKind.invalidRequest);
    }
    final uri = config.baseUri.resolve(
      path.startsWith('/') ? path.substring(1) : path,
    );
    if (uri.origin != config.baseUri.origin ||
        !uri.path.startsWith(config.baseUri.path)) {
      throw const ApiException(ApiErrorKind.invalidRequest);
    }
    return query == null
        ? uri
        : uri.replace(queryParameters: {...uri.queryParameters, ...query});
  }

  static ApiErrorKind _httpError(int status) => switch (status) {
    401 => ApiErrorKind.unauthorized,
    403 => ApiErrorKind.forbidden,
    404 => ApiErrorKind.notFound,
    >= 500 => ApiErrorKind.server,
    >= 400 => ApiErrorKind.validation,
    _ => ApiErrorKind.invalidResponse,
  };

  static String? _publicErrorCode(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final code = body is Map ? body['code'] : null;
      const allowed = {
        'SPACE_CODE_EXISTS',
        'SPACE_HAS_RESERVATIONS',
        'SPACE_HAS_RELATED_DATA',
        'SPACE_BUSY',
      };
      return code is String && allowed.contains(code) ? code : null;
    } catch (_) {
      return null;
    }
  }

  /// The client owns its transport, including one provided via the constructor.
  void close() => _client.close();
}
