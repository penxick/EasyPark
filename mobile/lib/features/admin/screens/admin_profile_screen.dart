import '../../auth/server_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../auth/auth_controller.dart';
import '../../profile/profile_screen.dart';

class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key, required this.auth});
  final AuthController auth;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: auth,
    builder: (context, _) {
      final user = auth.user;
      if (user == null) return const SizedBox.shrink();
      return SingleChildScrollView(
        padding: AppSpacing.page,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  title: 'Профиль администратора',
                  description: 'Роль: ADMIN',
                  child: ProfileDetails(user: user),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Настройки → Подключение к серверу',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ServerSettingsScreen(auth: auth),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                AppButton(
                  label: 'Обновить профиль',
                  icon: LucideIcons.refreshCw,
                  onPressed: auth.busy ? null : auth.restore,
                  variant: AppButtonVariant.outline,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Выйти',
                  icon: LucideIcons.logOut,
                  loading: auth.busy,
                  onPressed: auth.logout,
                  variant: AppButtonVariant.destructive,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
