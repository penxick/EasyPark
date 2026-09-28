import 'package:flutter/material.dart';
import '../../core/widgets/ui_kit.dart';
import 'auth_controller.dart';
import 'auth_layout.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, required this.auth});
  final AuthController auth;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: auth,
    builder: (context, _) => AuthLayout(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'EasyPark',
            style: AppTypography.heading1.copyWith(color: AppColors.heading),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (auth.status == AuthStatus.restoreError)
            AppCard(
              child: Column(
                children: [
                  AppErrorView(
                    title: auth.logoutPending
                        ? 'Не удалось завершить выход'
                        : 'Не удалось проверить сессию',
                    message: auth.error ?? 'Попробуйте ещё раз.',
                    onRetry: auth.restore,
                  ),
                  AppButton(
                    label: 'Войти снова',
                    variant: AppButtonVariant.ghost,
                    onPressed: auth.invalidate,
                  ),
                ],
              ),
            )
          else
            AppLoadingIndicator(
              label: auth.logoutPending
                  ? 'Выходим из аккаунта…'
                  : 'Проверяем сессию…',
            ),
        ],
      ),
    ),
  );
}
