// Deterministic card rendering; real map tiles are checked on Android.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:easypark/core/theme/app_theme.dart';
import 'package:easypark/features/map/parking.dart';
import 'package:easypark/features/map/parking_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test/support/map_fixture.dart';

void main() {
  testWidgets('render parking card', (tester) async {
    const sdk = String.fromEnvironment('FLUTTER_SDK');
    if (sdk.isEmpty) throw StateError('Pass FLUTTER_SDK');
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
      final icons = FontLoader('packages/lucide_icons_flutter/Lucide')
        ..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
        );
      await icons.load();
    });
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final boundaryKey = GlobalKey();
    for (final width in [390.0, 320.0]) {
      tester.view.physicalSize = Size(width, 640);
      tester.platformDispatcher.textScaleFactorTestValue = width == 320 ? 2 : 1;
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            theme: AppTheme.light,
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: ParkingSummary(
                  parking: Parking.fromJson(testParking),
                  onDetails: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '../.artifacts/stage-8-card-${width.toInt()}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
