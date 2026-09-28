import 'dart:io';
import 'dart:ui' as ui;
import 'package:easypark/core/theme/app_theme.dart';
import 'package:easypark/core/widgets/app_top_bar.dart';
import 'package:easypark/features/auth/auth_controller.dart';
import 'package:easypark/features/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test/support/auth_fixture.dart';

void main() {
  testWidgets('render profile at normal and enlarged text sizes', (
    tester,
  ) async {
    const sdk = String.fromEnvironment('FLUTTER_SDK');
    await tester.runAsync(() async {
      final font = FontLoader('Roboto');
      for (final weight in ['regular', 'medium']) {
        font.addFont(
          File(
            '$sdk/bin/cache/artifacts/material_fonts/roboto-$weight.ttf',
          ).readAsBytes().then(ByteData.sublistView),
        );
      }
      await font.load();
      await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
            rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
          ))
          .load();
    });
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final width in [390.0, 320.0]) {
      tester.view.physicalSize = Size(width, 844);
      tester.platformDispatcher.textScaleFactorTestValue = width == 320 ? 2 : 1;
      final auth = fixture()..status = AuthStatus.signedIn;
      addTearDown(auth.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            theme: AppTheme.light,
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              appBar: const AppTopBar(title: 'EasyPark'),
              body: ProfileScreen(key: ValueKey(width), auth: auth),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> capture(String suffix) async {
        expect(tester.takeException(), isNull);
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '../.artifacts/stage-15-profile-${width.toInt()}$suffix.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('');
      if (width == 320) {
        await tester.ensureVisible(find.text('Выйти'));
        await tester.pumpAndSettle();
        await capture('-bottom');
      }
    }
  });
}
