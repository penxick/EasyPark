import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/ui_kit.dart';

/// Development-only entry point: flutter run -t lib/ui_kit_preview.dart.
/// No API calls, credentials, routing, or domain state.
void main() => runApp(const UiKitPreviewApp());

class UiKitPreviewApp extends StatelessWidget {
  const UiKitPreviewApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'EasyPark UI Kit',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: const UiKitPreview(),
  );
}

class UiKitPreview extends StatefulWidget {
  const UiKitPreview({super.key});
  @override
  State<UiKitPreview> createState() => _UiKitPreviewState();
}

class _UiKitPreviewState extends State<UiKitPreview> {
  int _selected = 0;
  bool _hidden = true;
  int _retries = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppTopBar(title: 'EasyPark · UI Kit'),
    bottomNavigationBar: AppBottomNavigation(
      selectedIndex: _selected,
      onSelected: (value) => setState(() => _selected = value),
    ),
    body: SingleChildScrollView(
      padding: AppSpacing.page,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Компоненты интерфейса',
                style: AppTypography.heading1.copyWith(
                  color: AppColors.heading,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Каталог состояний · без подключения к серверу',
                style: AppTypography.small,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppCard(
                title: 'Кнопки',
                description: 'Основные действия и состояния',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppButton(
                      label: 'Продолжить',
                      icon: LucideIcons.arrowRight,
                      onPressed: () {},
                      fullWidth: true,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        AppButton(
                          label: 'Нейтральная',
                          variant: AppButtonVariant.neutral,
                          onPressed: () {},
                        ),
                        AppButton(
                          label: 'Вторичная',
                          variant: AppButtonVariant.secondary,
                          onPressed: () {},
                        ),
                        AppButton(
                          label: 'Контурная',
                          variant: AppButtonVariant.outline,
                          onPressed: () {},
                        ),
                        AppButton(
                          label: 'Без фона',
                          variant: AppButtonVariant.ghost,
                          onPressed: () {},
                        ),
                        AppButton(
                          label: 'Удалить',
                          variant: AppButtonVariant.destructive,
                          onPressed: () {},
                        ),
                        const AppButton(label: 'Недоступна'),
                        AppButton(
                          label: 'Загрузка',
                          loading: true,
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                title: 'Поля ввода',
                child: Column(
                  children: [
                    const AppTextField(
                      label: 'Email',
                      hintText: 'example@mail.ru',
                      prefixIcon: LucideIcons.mail,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Пароль',
                      hintText: 'Введите пароль',
                      obscureText: _hidden,
                      prefixIcon: LucideIcons.lock,
                      suffix: IconButton(
                        tooltip: _hidden ? 'Показать пароль' : 'Скрыть пароль',
                        icon: Icon(
                          _hidden ? LucideIcons.eye : LucideIcons.eyeOff,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _hidden = !_hidden),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const AppTextField(
                      label: 'Поле с ошибкой',
                      errorText: 'Проверьте введённое значение.',
                      hintText: 'Обязательное поле',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const AppTextField(
                      label: 'Недоступное поле',
                      hintText: 'Нет доступных данных',
                      enabled: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const AppCard(
                title: 'Типографика и палитра',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Заголовок 24', style: AppTypography.heading1),
                    Text('Заголовок 20', style: AppTypography.heading2),
                    Text('Заголовок 18', style: AppTypography.heading3),
                    Text('Основной текст 16', style: AppTypography.body),
                    Text('Подпись 14', style: AppTypography.small),
                    SizedBox(height: AppSpacing.lg),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _Swatch('Свободно', AppColors.free),
                        _Swatch('Занято', AppColors.occupied),
                        _Swatch('Бронь', AppColors.reserved),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const AppCard(title: 'Загрузка', child: AppLoadingIndicator()),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                title: 'Ошибка',
                footer: Text(
                  'Проверка кнопки повтора: $_retries',
                  style: AppTypography.small,
                ),
                child: AppErrorView(
                  message: 'Не удалось подключиться к серверу.',
                  onRetry: () => setState(() => _retries++),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: AppSpacing.sm),
      Flexible(child: Text(label, style: AppTypography.small)),
    ],
  );
}
