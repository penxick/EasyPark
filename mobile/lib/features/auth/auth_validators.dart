abstract final class AuthValidators {
  static String? name(String? value) {
    final length = (value ?? '').trim().runes.length;
    return length < 1 || length > 100
        ? 'Введите имя: от 1 до 100 символов.'
        : null;
  }

  static String? email(String? value) {
    final email = (value ?? '').trim();
    return email.length > 254 ||
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
        ? 'Введите корректный email.'
        : null;
  }

  static String? password(String? value, {bool registration = false}) {
    final password = value ?? '';
    final min = registration ? 8 : 1;
    return password.runes.length < min ||
            password.runes.length > 128 ||
            (registration && password.trim().isEmpty)
        ? (registration
              ? 'Пароль: от 8 до 128 символов.'
              : 'Введите пароль (до 128 символов).')
        : null;
  }
}
