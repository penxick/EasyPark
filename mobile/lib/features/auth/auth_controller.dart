import 'package:flutter/foundation.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/storage/token_storage.dart';
import 'auth_repository.dart';
import 'auth_user.dart';

enum AuthStatus { checking, signedOut, signedIn, restoreError }

class AuthController extends ChangeNotifier {
  AuthController(this.repository);

  factory AuthController.platform() {
    final tokens = SecureTokenStorage();
    late final AuthController controller;
    controller = AuthController(
      AuthRepository(
        tokens: tokens,
        api: ApiClient(
          tokenProvider: tokens,
          onUnauthorized: () => controller.invalidate(),
        ),
      ),
    );
    return controller;
  }

  final AuthRepository repository;
  AuthStatus status = AuthStatus.checking;
  AuthUser? user;
  String? error;
  bool busy = false;
  bool _disposed = false;
  bool _logoutRequested = false;
  bool get logoutPending => _logoutRequested;
  bool get isAdmin => status == AuthStatus.signedIn && user?.role == 'ADMIN';
  int _generation = 0;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool _current(int generation) => !_disposed && generation == _generation;

  Future<void> restore() async {
    if (busy || _disposed) return;
    if (_logoutRequested) {
      await invalidate();
      return;
    }
    final generation = ++_generation;
    busy = true;
    error = null;
    status = AuthStatus.checking;
    _notify();
    try {
      final token = await repository.tokens.readToken();
      if (!_current(generation)) return;
      if (token == null || token.isEmpty) {
        user = null;
        status = AuthStatus.signedOut;
      } else {
        final restored = await repository.me();
        if (!_current(generation)) return;
        user = restored;
        status = AuthStatus.signedIn;
      }
    } catch (exception) {
      if (!_current(generation)) return;
      if (exception is ApiException &&
          exception.kind == ApiErrorKind.unauthorized) {
        await invalidate();
        return;
      }
      user = null;
      status = AuthStatus.restoreError;
      error = _message(exception);
    } finally {
      if (_current(generation)) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> login(String identifier, String password) =>
      _authenticate(() => repository.login(identifier, password));

  /// Revalidate a role without restarting the router or creating a 403 retry loop.
  Future<void> refreshIdentity() async {
    if (busy || _disposed || status != AuthStatus.signedIn) return;
    final generation = _generation;
    final current = await repository.me();
    if (_current(generation) && status == AuthStatus.signedIn) {
      user = current;
      _notify();
    }
  }

  Future<void> register(String name, String email, String password) =>
      _authenticate(() => repository.register(name, email, password));

  Future<void> _authenticate(Future<AuthSession> Function() action) async {
    if (busy || _disposed) return;
    final generation = ++_generation;
    busy = true;
    error = null;
    _notify();
    try {
      final session = await action();
      if (!_current(generation)) return;
      // Only grant access after the token is safely persisted.
      await repository.tokens.writeToken(session.token);
      if (!_current(generation)) return;
      user = session.user;
      status = AuthStatus.signedIn;
    } catch (exception) {
      if (!_current(generation)) return;
      error =
          exception is ApiException &&
              exception.kind == ApiErrorKind.unauthorized
          ? 'Неверный логин, email или пароль.'
          : _message(exception);
    } finally {
      if (_current(generation)) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> logout() async {
    if (busy || _disposed) return;
    _logoutRequested = true;
    await invalidate();
  }

  /// Used for expired sessions and an explicit restart of authentication.
  Future<void> invalidate() async {
    if (_disposed) return;
    final generation = ++_generation;
    busy = true;
    user = null;
    status = AuthStatus.checking;
    error = null;
    _notify();
    try {
      await repository.tokens.deleteToken();
      if (_current(generation)) {
        _logoutRequested = false;
        status = AuthStatus.signedOut;
      }
    } catch (exception) {
      if (_current(generation)) {
        status = AuthStatus.restoreError;
        error = _message(exception);
      }
    } finally {
      if (_current(generation)) {
        busy = false;
        _notify();
      }
    }
  }

  void clearError() {
    error = null;
    _notify();
  }

  static String _message(Object error) => switch (error) {
    TokenStorageException() =>
      'Не удалось сохранить или прочитать сессию. Проверьте доступ к защищённому хранилищу и повторите попытку.',
    ApiException(statusCode: 409) =>
      'Пользователь с таким email уже существует.',
    ApiException(statusCode: 429) =>
      'Слишком много попыток. Подождите минуту и попробуйте снова.',
    ApiException() => error.message,
    _ => 'Не удалось выполнить действие. Попробуйте ещё раз.',
  };

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    repository.close();
    super.dispose();
  }
}
