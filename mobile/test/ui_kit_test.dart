import 'package:easypark/core/theme/app_theme.dart';
import 'package:easypark/core/widgets/ui_kit.dart';
import 'package:easypark/ui_kit_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('button invokes once; disabled and loading prevent actions', (
    tester,
  ) async {
    var calls = 0;
    for (final variant in AppButtonVariant.values) {
      await tester.pumpWidget(
        host(
          AppButton(
            label: 'Действие',
            variant: variant,
            onPressed: () => calls++,
          ),
        ),
      );
      await tester.tap(find.text('Действие'));
      expect(calls, variant.index + 1);
    }
    await tester.pumpWidget(
      host(
        AppButton(label: 'Действие', loading: true, onPressed: () => calls++),
      ),
    );
    await tester.tap(find.text('Действие'));
    expect(calls, AppButtonVariant.values.length);
    expect(find.byType(AppLoadingIndicator), findsOneWidget);
    await tester.pumpWidget(host(const AppButton(label: 'Действие')));
    await tester.tap(find.text('Действие'));
    expect(calls, AppButtonVariant.values.length);
  });

  testWidgets('form validation, editing, submit and disabled field', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? submitted;
    await tester.pumpWidget(
      host(
        Form(
          key: key,
          child: AppTextField(
            label: 'Email',
            controller: controller,
            validator: (value) =>
                value == null || value.isEmpty ? 'Введите email' : null,
            onSubmitted: (value) => submitted = value,
          ),
        ),
      ),
    );
    expect(key.currentState!.validate(), false);
    await tester.pump();
    expect(find.text('Введите email'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'driver@example.com');
    expect(key.currentState!.validate(), true);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(submitted, 'driver@example.com');
    await tester.pump();
    expect(find.text('Введите email'), findsNothing);
    await tester.pumpWidget(
      host(
        AppTextField(label: 'Email', controller: controller, enabled: false),
      ),
    );
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
  });

  testWidgets('password stays obscured and loading is announced', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        const Column(
          children: [
            AppTextField(label: 'Пароль', obscureText: true),
            AppLoadingIndicator(),
          ],
        ),
      ),
    );
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).obscureText,
      true,
    );
    expect(find.bySemanticsLabel('Загрузка…'), findsOneWidget);
    semantics.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('retry and back are controlled callbacks', (tester) async {
    var retries = 0;
    var backs = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          appBar: AppTopBar(title: 'EasyPark', onBack: () => backs++),
          body: AppErrorView(
            message: 'Нет соединения',
            onRetry: () => retries++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Повторить'));
    await tester.tap(find.byTooltip('Назад'));
    expect(retries, 1);
    expect(backs, 1);
    await tester.pumpWidget(
      host(const AppErrorView(message: 'Нет соединения')),
    );
    expect(find.text('Повторить'), findsNothing);
  });

  testWidgets('navigation reports selection without performing routing', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var selected = 0;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) => Align(
            alignment: Alignment.bottomCenter,
            child: AppBottomNavigation(
              selectedIndex: selected,
              onSelected: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Бронирования'));
    await tester.pump();
    expect(selected, 1);
    expect(
      tester.getSemantics(find.text('Бронирования')),
      containsSemantics(
        isSelected: true,
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
        label: 'Бронирования',
        textDirection: TextDirection.ltr,
      ),
    );
    semantics.dispose();
  });

  for (final width in [320.0, 430.0, 768.0]) {
    testWidgets('catalog fits width $width with 2x text and scrolls to retry', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(const UiKitPreviewApp());
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Повторить'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Повторить'));
      await tester.pump();
      expect(find.text('Проверка кнопки повтора: 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Профиль'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
