import 'package:easypark/app.dart';
import 'package:easypark/core/router/app_router.dart';
import 'package:easypark/features/auth/auth_controller.dart';
import 'package:easypark/features/reservation/reservation_repository.dart';
import 'package:easypark/features/parking/parking_spaces_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android creates and cancels a reservation against real API', (
    tester,
  ) async {
    const email = String.fromEnvironment('TEST_EMAIL');
    const parking = String.fromEnvironment('TEST_PARKING');
    const space = String.fromEnvironment('TEST_SPACE');
    expect(
      RegExp(r'^stage13-[a-f0-9]{32}@example\.com$').hasMatch(email),
      isTrue,
    );
    final auth = AuthController.platform();
    await auth.register(
      'Проверка бронирования',
      email,
      'EasyPark stage13 test password',
    );
    expect(auth.status, AuthStatus.signedIn, reason: auth.error);
    final router = createAppRouter(
      auth: auth,
      initialLocation: '/parking/$parking/spaces',
    );
    await tester.pumpWidget(EasyParkApp(router: router));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(InteractiveViewer));
    await tester.tap(find.byKey(ValueKey('space-$space')));
    await tester.pumpAndSettle();
    Future<void> tap(String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    await tap('Забронировать');
    await tap('30 минут');
    expect(find.text('Стоимость: 60,26 ₽'), findsOneWidget);
    await tap('Подтвердить бронирование');
    expect(find.text('Бронирование подтверждено'), findsOneWidget);
    final repo = ReservationRepository(auth.repository.api);
    final mine = await repo.mine();
    expect(mine, hasLength(1));
    expect(mine.single.active, isTrue);
    expect(mine.single.totalPrice, 60.26);
    await tap('К схеме парковки');
    expect(find.text('Свободно: 0 из 1'), findsOneWidget);
    router.go('/reservations');
    await tester.pumpAndSettle();
    expect(find.text('Место T01'), findsOneWidget);
    await tap('Отменить бронирование');
    await tap('Да, отменить');
    expect(find.text('У вас пока нет активных бронирований.'), findsOneWidget);
    await tap('Отменённые');
    expect(find.text('Отменено'), findsOneWidget);
    await tap('Обновить бронирования');
    expect(find.text('Отменено'), findsOneWidget);
    await tap('Завершённые');
    expect(
      find.text('У вас пока нет завершённых бронирований.'),
      findsOneWidget,
    );
    await tap('Активные');
    expect(find.text('У вас пока нет активных бронирований.'), findsOneWidget);
    expect((await repo.mine()).single.status, 'CANCELLED');
    expect(
      (await ParkingSpacesRepository(
        auth.repository.api,
      ).fetchAll(parking)).single.selectable,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
