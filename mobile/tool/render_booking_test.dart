import 'dart:io';
import 'dart:ui' as ui;
import 'package:easypark/core/theme/app_theme.dart';
import 'package:easypark/features/reservation/booking_screen.dart';
import 'package:easypark/features/reservation/reservation_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test/support/auth_fixture.dart';
import '../test/support/reservation_fixture.dart';

void main() {
  testWidgets('render booking form and result', (tester) async {
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
      await (FontLoader('MaterialIcons')..addFont(
            File(
              '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytes().then(ByteData.sublistView),
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
      final data = ReservationFixture();
      final auth = fixture(handler: data.handle);
      addTearDown(auth.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            theme: AppTheme.light,
            debugShowCheckedModeBanner: false,
            home: BookingScreen(
              key: ValueKey(width),
              parkingId: '7',
              spaceId: '1',
              repository: ReservationRepository(auth.repository.api),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> capture(String label) async {
        expect(tester.takeException(), isNull);
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '../.artifacts/stage-13-$label-${width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('form');
      await tester.ensureVisible(find.text('Подтвердить бронирование'));
      await tester.tap(find.text('Подтвердить бронирование'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Бронирование подтверждено'));
      await tester.pumpAndSettle();
      await capture('success');
    }
  });
}
