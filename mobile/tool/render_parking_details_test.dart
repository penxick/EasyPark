// Deterministic card rendering; real map tiles are checked on Android.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:easypark/core/theme/app_theme.dart';
import 'package:easypark/features/parking/parking_details.dart';
import 'package:easypark/core/widgets/app_top_bar.dart';
import 'package:easypark/features/parking/parking_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test/support/map_fixture.dart';

void main() {
  testWidgets('render parking details', (tester) async {
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
              appBar: AppTopBar(title: 'Парковка', onBack: () {}),
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ParkingDetailsContent(
                      details: ParkingDetails.fromJson({
                        ...testParking,
                        'workingHours': '08:00–22:00',
                        'description': 'Учебная парковка',
                      }),
                      onRefresh: () {},
                    ),
                  ),
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
          '../.artifacts/stage-9-details-${width.toInt()}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
