import '../../core/api/api_exception.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
  });
  final int id;
  final String name, email, role;
  final DateTime createdAt;

  factory AuthUser.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! int ||
        (value['id'] as int) <= 0 ||
        value['name'] is! String ||
        value['email'] is! String ||
        !['USER', 'ADMIN'].contains(value['role']) ||
        value['createdAt'] is! String) {
      throw const ApiException(ApiErrorKind.invalidResponse);
    }
    final date = DateTime.tryParse(value['createdAt'] as String);
    if (date == null) throw const ApiException(ApiErrorKind.invalidResponse);
    return AuthUser(
      id: value['id'] as int,
      name: value['name'] as String,
      email: value['email'] as String,
      role: value['role'] as String,
      createdAt: date,
    );
  }
}

class AuthSession {
  const AuthSession(this.token, this.user);
  final String token;
  final AuthUser user;
  factory AuthSession.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['accessToken'] is! String ||
        (value['accessToken'] as String).isEmpty) {
      throw const ApiException(ApiErrorKind.invalidResponse);
    }
    return AuthSession(
      value['accessToken'] as String,
      AuthUser.fromJson(value['user']),
    );
  }
}
