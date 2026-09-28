import 'dart:io';
import 'dart:ui' as ui;
import 'package:easypark/core/theme/app_theme.dart';
import 'package:easypark/core/widgets/app_top_bar.dart';
import 'package:easypark/features/parking/parking_layout.dart';
import 'package:easypark/features/parking/parking_space.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('render parking layout', (tester) async {
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
    final spaces = <ParkingSpace>[];
    for (var column = 0; column < 4; column++) {
      for (var row = 0; row < 5; row++) {
        final status = column == 3 && row == 4
            ? 'UNAVAILABLE'
            : row == 1
            ? 'OCCUPIED'
            : row == 3
            ? 'RESERVED'
            : 'FREE';
        spaces.add(
          ParkingSpace.fromJson({
            'id': column * 5 + row + 1,
            'parkingId': 7,
            'code': '${String.fromCharCode(65 + column)}0${row + 1}',
            'status': status,
            'physicalOccupied': status == 'OCCUPIED',
            'x': [50, 150, 370, 470][column],
            'y': 50 + row * 50,
          }),
        );
      }
    }
    final boundaryKey = GlobalKey();
    for (final width in [390.0, 320.0]) {
      tester.view.physicalSize = Size(width, 844);
      tester.platformDispatcher.textScaleFactorTestValue = width == 320 ? 2 : 1;
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            theme: AppTheme.light,
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              appBar: AppTopBar(title: 'Парковочные места', onBack: () {}),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ParkingLayout(key: ValueKey(width), spaces: spaces),
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
          '../.artifacts/stage-11-layout-${width.toInt()}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
