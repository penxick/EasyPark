import 'package:easypark/core/api/api_client.dart';
import 'package:easypark/core/constants/api_config.dart';
import 'package:easypark/core/storage/server_address_storage.dart';
import 'package:easypark/features/auth/auth_controller.dart';
import 'package:easypark/features/auth/auth_repository.dart';
import 'package:easypark/features/reservation/booking_screen.dart';
import 'package:easypark/features/reservation/parking_session_card.dart';
import 'package:easypark/features/reservation/reservation.dart';
import 'package:easypark/features/reservation/reservation_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/auth_fixture.dart';
import 'support/reservation_fixture.dart';

class MemoryServerAddress extends ServerAddressStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String address) async {
    value = address;
  }
}

void main() {
  test(
    'server switch deletes token, persists address, restores it; failure keeps old API',
    () async {
      final tokens = MemoryTokens('old-server-token');
      final storage = MemoryServerAddress();
      AuthController make() => AuthController(
        AuthRepository(
          tokens: tokens,
          api: ApiClient(
            config: ApiConfig(baseUrl: 'https://old.test/api/'),
            tokenProvider: tokens,
          ),
        ),
        serverStorage: storage,
      );
      final auth = make();
      addTearDown(auth.dispose);
      auth.status = AuthStatus.signedIn;
      tokens.failDelete = true;
      await expectLater(
        auth.changeServer('https://new.trycloudflare.com/api/'),
        throwsException,
      );
      expect(auth.repository.api.config.baseUri.host, 'old.test');
      expect(storage.value, isNull);
      tokens.failDelete = false;
      await auth.changeServer('https://new.trycloudflare.com/api/');
      expect(tokens.value, isNull);
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.repository.api.config.baseUri.host, 'new.trycloudflare.com');
      final reopened = make();
      addTearDown(reopened.dispose);
      await reopened.restore();
      expect(
        reopened.repository.api.config.baseUri.host,
        'new.trycloudflare.com',
      );
      expect(reopened.status, AuthStatus.signedOut);
    },
  );
  testWidgets(
    'metered mode hides duration, submits SBP and labels demo payment',
    (tester) async {
      final data = ReservationFixture();
      final auth = fixture(handler: data.handle);
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: BookingScreen(
            parkingId: '7',
            spaceId: '1',
            repository: ReservationRepository(auth.repository.api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('По счётчику'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('booking-hours')), findsNothing);
      expect(find.text('Как это работает'), findsOneWidget);
      await tester.ensureVisible(find.text('СБП'));
      await tester.tap(find.text('СБП'));
      await tester.ensureVisible(find.text('Начать парковку'));
      await tester.tap(find.text('Начать парковку'));
      await tester.pumpAndSettle();
      expect(data.sent, {
        'parkingSpaceId': 1,
        'mode': 'METERED',
        'paymentMethod': 'SBP',
      });
    },
  );
  testWidgets(
    'session timer uses server elapsed time and resumes from a fresh response',
    (tester) async {
      final auth = fixture(handler: (_) async => jsonResponse([]));
      addTearDown(auth.dispose);
      final repo = ReservationRepository(auth.repository.api);
      Reservation session(int elapsed, String state) => Reservation.fromJson({
        ...reservationJson(),
        'mode': 'METERED',
        'sessionState': state,
        'paymentMethod': 'CARD',
        'hourlyRateSnapshot': '80.00',
        'actualStartTime': '2026-09-28T10:00:00Z',
        'elapsedSeconds': elapsed,
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParkingSessionCard(
              reservation: session(60, 'PARKED'),
              repository: repo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('00:01:00'), findsOneWidget);
      // Stopwatch is monotonic wall time; re-opening reconciles against the server.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParkingSessionCard(
              reservation: session(135, 'PARKED'),
              repository: repo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('00:02:15'), findsOneWidget);
      expect(find.text('Текущая стоимость: 3,00 ₽'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
