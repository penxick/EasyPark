import 'dart:io';
import 'dart:ui' as ui;
import 'package:easypark/core/theme/app_theme.dart';
import 'package:easypark/core/widgets/app_top_bar.dart';
import 'package:easypark/features/reservation/reservations_screen.dart';
import 'package:easypark/features/reservation/reservation_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test/support/auth_fixture.dart';
import '../test/support/reservation_fixture.dart';

void main() {
  testWidgets('render history categories', (tester) async {
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
      final auth = fixture(
        handler: (request) async {
          if (request.url.path.endsWith('/reservations/me')) {
            return jsonResponse([
              for (final entry in ['ACTIVE', 'COMPLETED', 'CANCELLED'].indexed)
                {...reservationJson(status: entry.$2), 'id': entry.$1 + 1},
            ]);
          }
          return data.handle(request);
        },
      );
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
              body: ReservationsScreen(
                key: ValueKey(width),
                repository: ReservationRepository(auth.repository.api),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final entry in {
        'active': 'Активные',
        'completed': 'Завершённые',
        'cancelled': 'Отменённые',
      }.entries) {
        await tester.ensureVisible(find.text(entry.value));
        await tester.tap(find.text(entry.value));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '../.artifacts/stage-14-${entry.key}-${width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
  });
}
