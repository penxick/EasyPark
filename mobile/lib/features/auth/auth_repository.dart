import '../../core/api/api_client.dart';
import '../../core/storage/token_storage.dart';
import 'auth_user.dart';

class AuthRepository {
  AuthRepository({required this.api, required this.tokens});
  final ApiClient api;
  final TokenStorage tokens;

  Future<AuthSession> login(String email, String password) async =>
      AuthSession.fromJson(
        await api.post(
          'auth/login',
          authenticated: false,
          body: {'email': email.trim().toLowerCase(), 'password': password},
        ),
      );
  Future<AuthSession> register(
    String name,
    String email,
    String password,
  ) async => AuthSession.fromJson(
    await api.post(
      'auth/register',
      authenticated: false,
      body: {
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
      },
    ),
  );
  Future<AuthUser> me() async => AuthUser.fromJson(await api.get('users/me'));
  void close() => api.close();
}
