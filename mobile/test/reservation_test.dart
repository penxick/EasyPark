import 'dart:async';
import 'package:easypark/app.dart';
import 'package:easypark/core/api/api_exception.dart';
import 'package:easypark/core/router/app_router.dart';
import 'package:easypark/core/theme/app_theme.dart';
import 'package:easypark/features/auth/auth_controller.dart';
import 'package:easypark/features/reservation/booking_screen.dart';
import 'package:easypark/features/reservation/reservation.dart';
import 'package:easypark/features/reservation/reservation_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'support/auth_fixture.dart';
import 'support/reservation_fixture.dart';

Future<void> tapText(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'changing booking URL reloads place instead of reusing previous selection',
    (tester) async {
      final data = ReservationFixture();
      final auth = fixture(handler: data.handle)..status = AuthStatus.signedIn;
      final router = createAppRouter(
        auth: auth,
        initialLocation: '/parking/7/book/1',
      );
      addTearDown(router.dispose);
      addTearDown(auth.dispose);
      await tester.pumpWidget(EasyParkApp(router: router));
      await tester.pumpAndSettle();
      expect(find.text('Место A01'), findsOneWidget);
      router.go('/parking/7/book/2');
      await tester.pumpAndSettle();
      expect(find.text('Место A01'), findsNothing);
      expect(find.text('Запрошенные данные не найдены.'), findsOneWidget);
      expect(data.posts, 0);
    },
  );
  testWidgets(
    'unavailable space blocks create; expired JWT redirects to login',
    (tester) async {
      final data = ReservationFixture()..occupied = true;
      final tokens = MemoryTokens('jwt');
      final auth = fixture(tokens: tokens, handler: data.handle)
        ..status = AuthStatus.signedIn;
      final router = createAppRouter(
        auth: auth,
        initialLocation: '/parking/7/book/1',
      );
      addTearDown(router.dispose);
      addTearDown(auth.dispose);
      await tester.pumpWidget(EasyParkApp(router: router));
      await tester.pumpAndSettle();
      await tapText(tester, 'Подтвердить бронирование');
      expect(data.posts, 0);
      data.occupied = false;
      router.go('/reservations');
      await tester.pumpAndSettle();
      router.go('/parking/7/book/1');
      await tester.pumpAndSettle();
      data.postStatus = 401;
      await tapText(tester, 'Подтвердить бронирование');
      expect(find.text('Вход в систему'), findsOneWidget);
      expect(tokens.value, isNull);
    },
  );
  testWidgets(
    'cancellation failure is not shown as success and can be retried',
    (tester) async {
      final data = ReservationFixture()..cancelStatus = 503;
      final auth = fixture(handler: data.handle);
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BookingScreen(
            parkingId: '7',
            spaceId: '1',
            repository: ReservationRepository(auth.repository.api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Подтвердить бронирование');
      await tapText(tester, 'Отменить бронирование');
      await tapText(tester, 'Да, отменить');
      expect(find.text('Бронирование отменено'), findsNothing);
      expect(find.textContaining('Сервис временно недоступен'), findsOneWidget);
      data.cancelStatus = 200;
      await tapText(tester, 'Отменить бронирование');
      await tapText(tester, 'Да, отменить');
      expect(find.text('Бронирование отменено'), findsOneWidget);
      expect(data.patches, 2);
    },
  );
  test('reservation validation, statuses and precise display', () {
    expect(Reservation.fromJson(reservationJson()).active, isTrue);
    expect(
      Reservation.fromJson(reservationJson(status: 'CANCELLED')).active,
      isFalse,
    );
    expect(rubles(60.25), '60,25 ₽');
    for (final patch in [
      {'id': 0},
      {'status': 'OTHER'},
      {'totalPrice': -1},
      {'totalPrice': double.infinity},
      {'endTime': 'bad'},
      {'endTime': '2020-01-01T00:00:00Z'},
    ]) {
      expect(
        () => Reservation.fromJson({...reservationJson(), ...patch}),
        throwsA(isA<ApiException>()),
      );
    }
  });
  test(
    'repository sends JWT and only required fields; validates response identity',
    () async {
      final data = ReservationFixture();
      final auth = fixture(
        tokens: MemoryTokens('jwt'),
        handler: (request) async {
          expect(request.headers['Authorization'], 'Bearer jwt');
          return data.handle(request);
        },
      );
      addTearDown(auth.dispose);
      final repo = ReservationRepository(auth.repository.api);
      await repo.create(1, 30);
      expect(data.sent, {'parkingSpaceId': 1, 'durationMinutes': 30});
      expect(await repo.active(), hasLength(1));
      expect((await repo.cancel(10)).status, 'CANCELLED');
      expect(await repo.active(), isEmpty);
      await expectLater(repo.create(1, 45), throwsA(isA<ApiException>()));
      expect(data.posts, 1);
      final broken = fixture(
        handler: (_) async => jsonResponse(reservationJson(spaceId: 2)),
      );
      addTearDown(broken.dispose);
      await expectLater(
        ReservationRepository(broken.repository.api).create(1, 60),
        throwsA(isA<ApiException>()),
      );
    },
  );
  testWidgets(
    'choose place, duration, success, cancel confirmation and refreshed layout',
    (tester) async {
      final data = ReservationFixture();
      final auth = fixture(tokens: MemoryTokens('jwt'), handler: data.handle)
        ..status = AuthStatus.signedIn;
      final router = createAppRouter(
        auth: auth,
        initialLocation: '/parking/7/spaces',
      );
      addTearDown(router.dispose);
      addTearDown(auth.dispose);
      await tester.pumpWidget(EasyParkApp(router: router));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(InteractiveViewer));
      await tester.tap(find.byKey(const ValueKey('space-1')));
      await tester.pumpAndSettle();
      await tapText(tester, 'Забронировать');
      expect(find.text('Место A01'), findsOneWidget);
      expect(find.text('30 минут'), findsOneWidget);
      await tester.tap(find.byTooltip('Увеличить длительность'));
      await tester.pumpAndSettle();
      expect(find.text('Стоимость: 120,50 ₽'), findsOneWidget);
      await tester.tap(find.byTooltip('Уменьшить длительность'));
      await tester.pumpAndSettle();
      expect(find.text('Стоимость: 60,25 ₽'), findsOneWidget);
      await tapText(tester, 'Подтвердить бронирование');
      expect(data.sent?['durationMinutes'], 30);
      expect(find.text('Бронирование подтверждено'), findsOneWidget);
      expect(
        find.text('Стоимость: 120,50 ₽'),
        findsOneWidget,
      ); // Server result wins.
      await tapText(tester, 'Отменить бронирование');
      await tapText(tester, 'Оставить');
      expect(data.patches, 0);
      await tapText(tester, 'Отменить бронирование');
      await tapText(tester, 'Да, отменить');
      expect(find.text('Бронирование отменено'), findsOneWidget);
      await tapText(tester, 'К схеме парковки');
      expect(find.text('Свободно: 1 из 1'), findsOneWidget);
    },
  );
  testWidgets('pending submit blocks double tap and system back', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    final data = ReservationFixture()..pending = pending.future;
    final auth = fixture(handler: data.handle);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BookingScreen(
          parkingId: '7',
          spaceId: '1',
          repository: ReservationRepository(auth.repository.api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Подтвердить бронирование'));
    await tester.pump();
    await tester.tap(
      find.text('Подтвердить бронирование'),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(data.posts, 1);
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
    pending.complete(jsonResponse(reservationJson()));
    await tester.pumpAndSettle();
    expect(find.text('Бронирование подтверждено'), findsOneWidget);
  });
  for (final conflict in [true, false]) {
    testWidgets(
      conflict
          ? '409 blocks retry'
          : 'uncertain result reconciles without another POST',
      (tester) async {
        final data = ReservationFixture()
          ..postStatus = conflict ? 409 : 503
          ..commitOnError = !conflict;
        final auth = fixture(handler: data.handle);
        addTearDown(auth.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: BookingScreen(
              parkingId: '7',
              spaceId: '1',
              repository: ReservationRepository(auth.repository.api),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tapText(tester, 'Подтвердить бронирование');
        if (conflict) {
          expect(
            find.textContaining('Место больше недоступно.'),
            findsOneWidget,
          );
          await tapText(tester, 'Подтвердить бронирование');
        } else {
          await tapText(tester, 'Проверить бронирования');
          expect(find.text('Бронирование подтверждено'), findsOneWidget);
          expect(data.gets, 1);
        }
        expect(data.posts, 1);
      },
    );
  }
  testWidgets(
    'active reservations recover after reopening; narrow layout and large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final data = ReservationFixture()..status = 'ACTIVE';
      final auth = fixture(tokens: MemoryTokens('jwt'), handler: data.handle)
        ..status = AuthStatus.signedIn;
      final router = createAppRouter(
        auth: auth,
        initialLocation: '/reservations',
      );
      addTearDown(router.dispose);
      addTearDown(auth.dispose);
      await tester.pumpWidget(EasyParkApp(router: router));
      await tester.pumpAndSettle();
      expect(find.text('Место A01'), findsOneWidget);
      await tapText(tester, 'Отменить бронирование');
      await tapText(tester, 'Да, отменить');
      await tapText(tester, 'Обновить бронирования');
      expect(
        find.text('У вас пока нет активных бронирований.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
