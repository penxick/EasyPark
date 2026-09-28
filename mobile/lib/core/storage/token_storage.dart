import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'token_provider.dart';

abstract interface class TokenStorage implements TokenProvider {
  Future<void> writeToken(String token);
  Future<void> deleteToken();
}

class TokenStorageException implements Exception {
  const TokenStorageException();
  @override
  String toString() =>
      'Не удалось открыть защищённое хранилище. Попробуйте ещё раз.';
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );
  static const _key = 'easypark.access_token';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> readToken() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      throw const TokenStorageException();
    }
  }

  @override
  Future<void> writeToken(String token) async {
    try {
      await _storage.write(key: _key, value: token);
    } catch (_) {
      throw const TokenStorageException();
    }
  }

  @override
  Future<void> deleteToken() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      throw const TokenStorageException();
    }
  }
}
