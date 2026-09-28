// Manual visual review utility, intentionally outside the regular test suite.
// flutter test tool/render_ui_kit_test.dart --dart-define=FLUTTER_SDK=<sdk root>
import 'dart:io';
import 'dart:ui' as ui;
import 'package:easypark/ui_kit_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('render UI catalog for visual review', (tester) async {
    const sdk = String.fromEnvironment('FLUTTER_SDK');
    if (sdk.isEmpty) {
      throw StateError('Pass --dart-define=FLUTTER_SDK=<sdk root>');
    }
    await tester.runAsync(() async {
      // Also replace the test engine's Ahem fallback for explicit TextStyles.
      for (final family in ['Roboto', 'Ahem']) {
        final font = FontLoader(family);
        for (final weight in ['regular', 'medium']) {
          font.addFont(
            File(
              '$sdk/bin/cache/artifacts/material_fonts/roboto-$weight.ttf',
            ).readAsBytes().then(ByteData.sublistView),
          );
        }
        await font.load();
      }
      final icons = FontLoader('packages/lucide_icons_flutter/Lucide');
      icons.addFont(
        rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
      );
      await icons.load();
    });
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final boundaryKey = GlobalKey();
    for (final width in [390.0, 320.0]) {
      tester.view.physicalSize = Size(width, 844);
      tester.platformDispatcher.textScaleFactorTestValue = width == 320 ? 2 : 1;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        RepaintBoundary(key: boundaryKey, child: const UiKitPreviewApp()),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      for (final section in ['top', 'fields', 'feedback']) {
        scroll.jumpTo(switch (section) {
          'top' => 0,
          'fields' => width == 390 ? 450 : 950,
          _ => scroll.maxScrollExtent,
        });
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            '../.artifacts/stage-3-${width.toInt()}-$section.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
  });
}
