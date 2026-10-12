import 'package:easypark/app.dart';
import 'package:easypark/core/router/app_router.dart';
import 'package:easypark/core/api/api_exception.dart';
import 'package:easypark/features/auth/auth_controller.dart';
import 'package:easypark/features/map/parking_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('A13 real Android ADMIN to USER to ADMIN flow', (tester) async {
    const login = String.fromEnvironment('TEST_LOGIN');
    const password = String.fromEnvironment('TEST_PASSWORD');
    const email = String.fromEnvironment('TEST_EMAIL');
    expect(login.startsWith('a13-'), true);
    final auth = AuthController.platform();
    await auth.repository.tokens.deleteToken();
    await auth.restore();
    final router = createAppRouter(auth: auth);
    await tester.pumpWidget(EasyParkApp(router: router));
    await tester.pumpAndSettle();
    Finder field(String key) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(TextFormField),
    );
    Future<void> tap(String label) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(label).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    Future<void> signIn(String identifier) async {
      await tester.enterText(field('auth-email'), identifier);
      await tester.enterText(field('auth-password'), password);
      await tap('Войти');
      expect(auth.status, AuthStatus.signedIn, reason: auth.error);
    }

    await signIn(login);
    expect(find.text('Обзор системы'), findsOneWidget);
    router.go('/admin/parkings/map');
    await tester.pumpAndSettle();
    await tap('+ Добавить парковку');
    final map = find.byType(FlutterMap).last;
    await tester.ensureVisible(map);
    await tester.tapAt(tester.getCenter(map) + const Offset(-50, 20));
    await tester.pumpAndSettle();
    await tap('Продолжить');
    for (final entry in {
      'name': login,
      'description': 'A13 integration',
      'address': 'Адрес A13',
      'pricePerHour': '100',
      'pricePer30Min': '50.01',
      'workingHours': '24/7',
    }.entries) {
      await tester.ensureVisible(field('parking-${entry.key}'));
      await tester.enterText(field('parking-${entry.key}'), entry.value);
    }
    await tap('Создать');
    for (var i = 0; i < 40 && find.byType(ParkingMap).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    if (find.byType(ParkingMap).evaluate().isEmpty) {
      debugPrint(
        tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join('\n'),
      );
    }
    final created = tester
        .widget<ParkingMap>(find.byType(ParkingMap))
        .parkings
        .singleWhere((p) => p.name == login);
    final id = created.id;
    expect(find.byKey(ValueKey('parking-marker-$id')), findsOneWidget);
    router.go('/admin/parkings/$id/spaces');
    await tester.pumpAndSettle();
    await tap('+ Добавить место');
    await tester.enterText(field('space-code'), 'A13');
    await tap('Создать');
    expect(find.text('A13'), findsOneWidget);
    await tap('Отключить');
    expect(find.textContaining('UNAVAILABLE'), findsOneWidget);
    await tap('Вернуть в эксплуатацию');
    expect(find.textContaining('FREE'), findsOneWidget);
    final spaces = await auth.repository.api.get('parkings/$id/spaces') as List;
    final spaceId = spaces.single['id'];
    await auth.logout();
    await tester.pumpAndSettle();
    await auth.register('Пользователь A13', email, password);
    expect(auth.status, AuthStatus.signedIn, reason: auth.error);
    final userId = auth.user!.id;
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ParkingMap>(find.byType(ParkingMap))
          .parkings
          .any((p) => p.id == id),
      true,
    );
    await auth.restore();
    expect(auth.user!.id, userId);
    final cameraContext = tester.element(find.byType(TileLayer));
    final zoom = MapCamera.of(cameraContext).zoom;
    await tester.tap(find.byTooltip('Приблизить'));
    await tester.pumpAndSettle();
    expect(MapCamera.of(cameraContext).zoom, (zoom + 1).clamp(2, 19));
    await tester.tap(find.byTooltip('Отдалить'));
    await tester.pumpAndSettle();
    if (const bool.fromEnvironment('TEST_GPS')) {
      debugPrint('NAV_PERMISSION_READY');
      for (var i = 0; i < 120; i++) {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          break;
        }
        await tester.pump(const Duration(milliseconds: 250));
      }
      await tester.tap(find.byTooltip('Моё местоположение'));
      await tester.pumpAndSettle();
      for (
        var i = 0;
        i < 80 &&
            tester.widget<ParkingMap>(find.byType(ParkingMap)).userPoint ==
                null;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(
        tester.widget<ParkingMap>(find.byType(ParkingMap)).userPoint,
        isNotNull,
      );
      await tester.tap(find.byTooltip('Показать все парковки'));
      await tester.pumpAndSettle();
    }
    router.go('/admin/analytics');
    await tester.pumpAndSettle();
    expect(find.text('Нет доступа'), findsOneWidget);
    await expectLater(
      auth.repository.api.get('admin/analytics'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
    );
    router.go('/parking/$id/spaces');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(InteractiveViewer));
    await tester.tap(find.byKey(ValueKey('space-$spaceId')));
    await tester.pumpAndSettle();
    await tap('Забронировать');
    expect(find.text('30 минут'), findsOneWidget);
    expect(find.text('Стоимость: 50,01 ₽'), findsOneWidget);
    await tester.tap(find.byTooltip('Увеличить длительность'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Увеличить длительность'));
    await tester.pumpAndSettle();
    expect(find.text('90 минут'), findsOneWidget);
    expect(find.text('Стоимость: 150,03 ₽'), findsOneWidget);
    await tap('Подтвердить бронирование');
    expect(find.text('Бронирование подтверждено'), findsOneWidget);
    final mine = await auth.repository.api.get('reservations/me') as List;
    expect(mine.single['totalPrice'], 150.03);
    final reservationId = mine.single['id'];
    await auth.logout();
    await tester.pumpAndSettle();
    await signIn(login);
    router.go('/admin/reservations/$reservationId');
    await tester.pumpAndSettle();
    expect(find.text('Email: $email'), findsOneWidget);
    expect(find.text('Место: A13'), findsOneWidget);
    router.go('/admin/users/$userId');
    await tester.pumpAndSettle();
    expect(find.text('Всего: 1\nАктивных: 1'), findsOneWidget);
    router.go('/admin/analytics');
    await tester.pumpAndSettle();
    expect(find.text('Распределение статусов мест'), findsOneWidget);
    final overall = await auth.repository.api.get('admin/analytics') as Map;
    expect(overall['activeReservations'], greaterThanOrEqualTo(1));
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('a13-analytics');
    router.go('/admin/parkings/$id/spaces');
    await tester.pumpAndSettle();
    expect(find.text('Активное бронирование: есть'), findsOneWidget);
    await tap('Удалить место');
    await tap('Удалить');
    expect(
      find.text('Нельзя удалить место с историей бронирований.'),
      findsOneWidget,
    );
    await auth.logout();
    await tester.pumpAndSettle();
    await signIn(email);
    router.go('/reservations');
    await tester.pumpAndSettle();
    await tap('Отменить бронирование');
    await tap('Да, отменить');
    await tap('Отменённые');
    expect(find.text('Отменено'), findsOneWidget);
    router.go('/profile');
    await tester.pumpAndSettle();
    expect(find.text(email), findsOneWidget);
    await auth.logout();
    await tester.pumpAndSettle();
    expect(find.text('Войти'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    auth.dispose();
  });
}
