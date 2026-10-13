import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api/api_exception.dart';
import 'auth_controller.dart';

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key, required this.auth});
  final AuthController auth;
  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final email = TextEditingController(),
      code = TextEditingController(),
      password = TextEditingController();
  bool requested = false, busy = false, done = false;
  String? message;
  @override
  void dispose() {
    email.dispose();
    code.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit(bool confirm) async {
    if (busy) return;
    if (confirm &&
        (!RegExp(r'^\d{6}$').hasMatch(code.text) ||
            password.text.length < 8 ||
            password.text.length > 128 ||
            password.text.trim().isEmpty)) {
      setState(
        () => message =
            'Введите шестизначный код и пароль длиной 8–128 символов.',
      );
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await widget.auth.repository.api.post(
        'auth/password-reset/${confirm ? 'confirm' : 'request'}',
        authenticated: false,
        body: {
          'email': email.text.trim().toLowerCase(),
          if (confirm) 'code': code.text,
          if (confirm) 'password': password.text,
        },
      );
      if (mounted) {
        setState(() {
          requested = true;
          done = confirm;
          message = confirm
              ? 'Пароль изменён. Войдите с новым паролем.'
              : 'Если адрес зарегистрирован и почтовая служба доступна, вы получите код. Проверьте почту и папку «Спам». Код действует 10 минут.';
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(
          () => message = e.statusCode == 503
              ? 'Отправка писем недоступна. Обратитесь к администратору.'
              : e.statusCode == 400
              ? 'Проверьте email, код и пароль. Код мог истечь.'
              : e.message,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Восстановление пароля')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: email,
              enabled: !busy && !requested,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            if (requested && !done) ...[
              TextField(
                controller: code,
                enabled: !busy,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(labelText: 'Одноразовый код'),
              ),
              TextField(
                controller: password,
                enabled: !busy,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Новый пароль'),
              ),
            ],
            if (message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(message!),
              ),
            if (!done)
              FilledButton(
                onPressed: busy ? null : () => submit(requested),
                child: Text(requested ? 'Изменить пароль' : 'Отправить код'),
              ),
            if (requested && !done)
              TextButton(
                onPressed: busy ? null : () => submit(false),
                child: const Text('Запросить код повторно'),
              ),
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Вернуться ко входу'),
            ),
          ],
        ),
      ),
    ),
  );
}
