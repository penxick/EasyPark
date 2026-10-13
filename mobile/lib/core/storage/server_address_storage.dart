import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ServerAddressStorage {
  const ServerAddressStorage();
  static const _storage = FlutterSecureStorage();
  Future<String?> read() => _storage.read(key: 'easypark.server_url');
  Future<void> write(String value) =>
      _storage.write(key: 'easypark.server_url', value: value);
}
