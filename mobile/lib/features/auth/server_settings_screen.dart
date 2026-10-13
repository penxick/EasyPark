import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/constants/api_config.dart';
import 'auth_controller.dart';

class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({
    super.key,
    required this.auth,
    this.probeFactory,
  });
  final AuthController auth;
  final ApiClient Function(ApiConfig)? probeFactory;
  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  late final url = TextEditingController(
    text: widget.auth.repository.api.config.baseUri.toString(),
  );
  bool busy = false;
  String? message;
  @override
  void dispose() {
    url.dispose();
    super.dispose();
  }

  Future<void> run(bool save) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final config = ApiConfig.forServer(url.text);
      final healthConfig = ApiConfig(
        baseUrl: config.baseUri.resolve('/').toString(),
        timeout: config.timeout,
      );
      final probe =
          widget.probeFactory?.call(healthConfig) ??
          ApiClient(config: healthConfig);
      try {
        final health = await probe.request(
          'GET',
          'health',
          authenticated: false,
          expectedStatusCode: 200,
        );
        if (health is! Map ||
            health['service'] != 'easypark-backend' ||
            health['status'] != 'ok') {
          throw StateError('Не EasyPark API');
        }
      } finally {
        probe.close();
      }
      if (save) await widget.auth.changeServer(config.baseUri.toString());
      if (mounted) {
        setState(
          () => message = save
              ? 'Адрес сохранён. Войдите на выбранный сервер.'
              : 'EasyPark API доступен.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message =
              'Не удалось проверить или сохранить адрес. Проверьте URL, сеть и сертификат сервера.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Подключение к серверу')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: url,
              enabled: !busy,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'URL EasyPark API',
                hintText: 'https://example.trycloudflare.com/api/',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'При смене сервера текущая авторизация сбрасывается. JWT предыдущего сервера не передаётся новому.',
            ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(message!),
              ),
            OutlinedButton(
              onPressed: busy ? null : () => run(false),
              child: const Text('Проверить подключение'),
            ),
            FilledButton(
              onPressed: busy ? null : () => run(true),
              child: const Text('Сохранить'),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () {
                      url.text = ApiConfig.fromEnvironment().baseUri.toString();
                      setState(
                        () => message =
                            'Адрес по умолчанию восстановлен в поле. Нажмите «Сохранить».',
                      );
                    },
              child: const Text('Восстановить адрес по умолчанию'),
            ),
          ],
        ),
      ),
    ),
  );
}
