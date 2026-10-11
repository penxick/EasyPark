import 'dart:convert';
import 'package:easypark/core/api/api_client.dart';
import 'package:easypark/core/constants/api_config.dart';
import 'package:easypark/core/storage/token_storage.dart';
import 'package:easypark/features/auth/auth_controller.dart';
import 'package:easypark/features/auth/auth_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MemoryTokens implements TokenStorage {
  MemoryTokens([this.value]);
  String? value;
  bool failRead = false, failWrite = false, failDelete = false;
  @override
  Future<String?> readToken() async {
    if (failRead) throw const TokenStorageException();
    return value;
  }

  @override
  Future<void> writeToken(String token) async {
    if (failWrite) throw const TokenStorageException();
    value = token;
  }

  @override
  Future<void> deleteToken() async {
    if (failDelete) throw const TokenStorageException();
    value = null;
  }
}

const testUser = {
  'id': 1,
  'name': 'Роман',
  'email': 'roman@example.com',
  'role': 'USER',
  'createdAt': '2026-09-26T00:00:00.000Z',
  'updatedAt': '2026-09-26T00:00:00.000Z',
};
http.Response jsonResponse(Object? value, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(value)), status);
http.Response sessionResponse() =>
    jsonResponse({'accessToken': 'test-token', 'user': testUser});

AuthController fixture({
  MemoryTokens? tokens,
  Future<http.Response> Function(http.Request)? handler,
}) {
  final storage = tokens ?? MemoryTokens();
  late final AuthController controller;
  final api = ApiClient(
    config: ApiConfig(baseUrl: 'https://example.test/api/'),
    tokenProvider: storage,
    onUnauthorized: () => controller.invalidate(),
    client: MockClient(handler ?? (_) async => jsonResponse(testUser)),
  );
  controller = AuthController(AuthRepository(api: api, tokens: storage));
  return controller;
}
