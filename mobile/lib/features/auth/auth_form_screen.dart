import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/router/app_routes.dart';
import '../../core/widgets/ui_kit.dart';
import 'auth_controller.dart';
import 'auth_layout.dart';
import 'auth_validators.dart';

class AuthFormScreen extends StatefulWidget {
  const AuthFormScreen({
    super.key,
    required this.auth,
    this.registration = false,
  });
  final AuthController auth;
  final bool registration;
  @override
  State<AuthFormScreen> createState() => _AuthFormScreenState();
}

class _AuthFormScreenState extends State<AuthFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    for (final controller in [_name, _email, _password, _confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.auth.busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    if (widget.registration) {
      await widget.auth.register(_name.text, _email.text, _password.text);
    } else {
      await widget.auth.login(_email.text, _password.text);
    }
    if (mounted && widget.auth.status == AuthStatus.signedIn) {
      TextInput.finishAutofillContext();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.auth,
    builder: (context, _) {
      final registration = widget.registration;
      final busy = widget.auth.busy;
      return PopScope(
        canPop: !busy,
        child: AuthLayout(
          child: AppCard(
            child: AutofillGroup(
              onDisposeAction: AutofillContextAction.cancel,
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        registration ? 'Регистрация' : 'Вход в систему',
                        textAlign: TextAlign.center,
                        style: AppTypography.title.copyWith(
                          color: AppColors.heading,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      registration
                          ? 'Создайте новый аккаунт для использования EasyPark'
                          : 'Введите логин или email и пароль для продолжения',
                      textAlign: TextAlign.center,
                      style: AppTypography.small.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (registration) ...[
                      AppTextField(
                        key: const ValueKey('auth-name'),
                        label: 'Имя',
                        labelIcon: LucideIcons.user,
                        controller: _name,
                        hintText: 'Ваше имя',
                        enabled: !busy,
                        validator: AuthValidators.name,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    AppTextField(
                      key: const ValueKey('auth-email'),
                      label: registration ? 'Email' : 'Логин / Email',
                      labelIcon: LucideIcons.mail,
                      controller: _email,
                      hintText: registration
                          ? 'example@mail.ru'
                          : 'Логин или example@mail.ru',
                      enabled: !busy,
                      validator: registration
                          ? AuthValidators.email
                          : AuthValidators.login,
                      keyboardType: registration
                          ? TextInputType.emailAddress
                          : TextInputType.text,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [
                        AutofillHints.username,
                        AutofillHints.email,
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      key: const ValueKey('auth-password'),
                      label: 'Пароль',
                      labelIcon: LucideIcons.lock,
                      controller: _password,
                      hintText: 'Введите пароль',
                      enabled: !busy,
                      obscureText: true,
                      validator: (value) => AuthValidators.password(
                        value,
                        registration: registration,
                      ),
                      textInputAction: registration
                          ? TextInputAction.next
                          : TextInputAction.done,
                      onSubmitted: registration ? null : (_) => _submit(),
                      autofillHints: [
                        registration
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                    ),
                    if (registration) ...[
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        key: const ValueKey('auth-confirm'),
                        label: 'Повтор пароля',
                        labelIcon: LucideIcons.lock,
                        controller: _confirm,
                        hintText: 'Повторите пароль',
                        enabled: !busy,
                        obscureText: true,
                        validator: (value) =>
                            value == _password.text && (value ?? '').isNotEmpty
                            ? null
                            : 'Пароли не совпадают.',
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        autofillHints: const [AutofillHints.newPassword],
                      ),
                    ],
                    if (widget.auth.error != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          widget.auth.error!,
                          style: AppTypography.small.copyWith(
                            color: AppColors.destructive,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      key: const ValueKey('auth-submit'),
                      label: busy
                          ? (registration ? 'Регистрация…' : 'Вход…')
                          : (registration ? 'Создать аккаунт' : 'Войти'),
                      icon: registration
                          ? LucideIcons.userPlus
                          : LucideIcons.logIn,
                      loading: busy,
                      onPressed: _submit,
                      fullWidth: true,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (!registration) ...[
                      const Divider(height: 1),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Нет аккаунта?',
                        textAlign: TextAlign.center,
                        style: AppTypography.body.copyWith(
                          color: AppColors.bodySecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    AppButton(
                      label: registration
                          ? 'Вернуться ко входу'
                          : 'Зарегистрироваться',
                      icon: registration
                          ? LucideIcons.arrowLeft
                          : LucideIcons.userPlus,
                      variant: registration
                          ? AppButtonVariant.ghost
                          : AppButtonVariant.outline,
                      accent: !registration,
                      fullWidth: true,
                      onPressed: busy
                          ? null
                          : () {
                              widget.auth.clearError();
                              context.go(
                                registration
                                    ? AppRoutes.login
                                    : AppRoutes.register,
                              );
                            },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
