import 'package:easypark/core/theme/app_theme.dart';
import 'package:easypark/features/reservation/reservation.dart';
import 'package:easypark/features/reservation/reservation_repository.dart';
import 'package:easypark/features/reservation/reservations_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/auth_fixture.dart';
import 'support/reservation_fixture.dart';

void main() {
  test('all five server statuses have exactly one history category', () {
    for (final entry in {
      'ACTIVE': ReservationCategory.active,
      'PENDING': ReservationCategory.active,
      'COMPLETED': ReservationCategory.completed,
      'EXPIRED': ReservationCategory.completed,
      'CANCELLED': ReservationCategory.cancelled,
    }.entries) {
      expect(
        Reservation.fromJson(reservationJson(status: entry.key)).category,
        entry.value,
      );
    }
  });
  testWidgets(
    'categories filter server data, keep selection on refresh and forbid cancelling history',
    (tester) async {
      final data = ReservationFixture();
      var calls = 0, fail = false;
      final auth = fixture(
        handler: (request) async {
          if (request.url.path.endsWith('/reservations/me')) {
            calls++;
            if (fail) return jsonResponse({}, 503);
            return jsonResponse([
              for (final entry in [
                'ACTIVE',
                'PENDING',
                'COMPLETED',
                'EXPIRED',
                'CANCELLED',
              ].indexed)
                {...reservationJson(status: entry.$2), 'id': entry.$1 + 1},
            ]);
          }
          return data.handle(request);
        },
      );
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ReservationsScreen(
              repository: ReservationRepository(auth.repository.api),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Активно'), findsOneWidget);
      expect(find.text('Ожидает подтверждения'), findsOneWidget);
      expect(find.text('Отменить бронирование'), findsNWidgets(2));
      await tester.tap(find.text('Завершённые'));
      await tester.pumpAndSettle();
      expect(find.text('Завершено'), findsOneWidget);
      expect(find.text('Срок истёк'), findsOneWidget);
      expect(find.text('Отменить бронирование'), findsNothing);
      expect(calls, 1);
      await tester.tap(find.text('Отменённые'));
      await tester.pumpAndSettle();
      expect(find.text('Отменено'), findsOneWidget);
      expect(find.text('Завершено'), findsNothing);
      fail = true;
      await tester.tap(find.text('Обновить бронирования'));
      await tester.pumpAndSettle();
      expect(find.text('Не удалось загрузить бронирования.'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(find.text('Отменено'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Отменённые'))
            .selected,
        isTrue,
      );
    },
  );
  testWidgets(
    'confirmed cancellation moves immediately to cancelled and survives reload at 320px',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 720);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final data = ReservationFixture()..status = 'ACTIVE';
      final auth = fixture(handler: data.handle);
      addTearDown(auth.dispose);
      final repository = ReservationRepository(auth.repository.api);
      Future<void> mount() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(body: ReservationsScreen(repository: repository)),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> tap(String label) async {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      await mount();
      await tap('Отменить бронирование');
      await tap('Да, отменить');
      expect(
        find.text('У вас пока нет активных бронирований.'),
        findsOneWidget,
      );
      await tap('Отменённые');
      expect(find.text('Отменено'), findsOneWidget);
      await tap('Завершённые');
      expect(
        find.text('У вас пока нет завершённых бронирований.'),
        findsOneWidget,
      );
      await mount();
      await tap('Отменённые');
      expect(find.text('Отменено'), findsOneWidget);
      expect(data.patches, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
