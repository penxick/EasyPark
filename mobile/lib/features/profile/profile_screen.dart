import '../auth/server_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:async';
import '../../core/state/load_controller.dart';
import '../../core/state/load_state.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_error_view.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_user.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.auth});
  final AuthController auth;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  final _loader = LoadController<AuthUser>();
  bool _visible = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _refresh() => unawaited(_loader.load(widget.auth.repository.me));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.of(context);
    if (visible && !_visible) _refresh();
    _visible = visible;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _visible) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              title: 'Профиль водителя',
              description: 'Личные данные',
              child: ListenableBuilder(
                listenable: _loader,
                builder: (context, _) => switch (_loader.state) {
                  LoadSuccess<AuthUser>(data: final user) => ProfileDetails(
                    user: user,
                  ),
                  LoadFailure<AuthUser>(error: final error) => AppErrorView(
                    title: 'Не удалось загрузить профиль',
                    message: error.message,
                    onRetry: _refresh,
                  ),
                  _ => const AppLoadingIndicator(label: 'Загрузка профиля…'),
                },
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Настройки → Подключение к серверу',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ServerSettingsScreen(auth: widget.auth),
                ),
              ),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: 'Обновить профиль',
              icon: LucideIcons.refreshCw,
              variant: AppButtonVariant.outline,
              onPressed: _refresh,
            ),
            const SizedBox(height: 8),
            ListenableBuilder(
              listenable: widget.auth,
              builder: (context, _) => AppButton(
                label: 'Выйти',
                icon: LucideIcons.logOut,
                variant: AppButtonVariant.destructive,
                loading: widget.auth.busy,
                onPressed: widget.auth.logout,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ProfileDetails extends StatelessWidget {
  const ProfileDetails({super.key, required this.user});
  final AuthUser user;
  @override
  Widget build(BuildContext context) {
    final date = user.createdAt.toLocal();
    final formattedDate =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProfileField(label: 'Имя', value: user.name, icon: LucideIcons.user),
        const SizedBox(height: 16),
        _ProfileField(
          label: 'Email',
          value: user.email,
          icon: LucideIcons.mail,
        ),
        const SizedBox(height: 16),
        _ProfileField(
          label: 'Дата регистрации',
          value: formattedDate,
          icon: LucideIcons.calendar,
        ),
      ],
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Icon(icon, size: 16, color: AppColors.bodySecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: AppTypography.small)),
        ],
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        child: Text(value),
      ),
    ],
  );
}
