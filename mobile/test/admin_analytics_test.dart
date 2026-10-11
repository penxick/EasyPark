import 'package:easypark/core/api/api_exception.dart';
import 'package:easypark/features/admin/data/admin_api.dart';
import 'package:easypark/features/admin/models/admin_parking_analytics.dart';
import 'package:easypark/features/admin/repositories/admin_repository.dart';
import 'package:easypark/features/admin/screens/admin_analytics_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/auth_fixture.dart';
import 'admin_test.dart' show summary;
import 'admin_directory_test.dart' show page;

final parking = {...summary, 'id': 1, 'name': 'Центральная'};
void main() {
  test('parking analytics rejects invalid ids and inconsistent aggregates', () {
    expect(AdminParkingAnalytics.fromJson(parking).metrics.freeSpaces, 4);
    for (final patch in [
      {'id': 0},
      {'name': ''},
      {'freeSpaces': 500},
      {'occupancyPercent': double.nan},
    ]) {
      expect(
        () => AdminParkingAnalytics.fromJson({...parking, ...patch}),
        throwsA(isA<ApiException>()),
      );
    }
  });
  testWidgets('real counters, page request and zero data remain finite', (
    tester,
  ) async {
    final requests = <String>[];
    final auth = fixture(
      handler: (r) async {
        requests.add(r.url.toString());
        if (r.url.path.endsWith('/parkings')) {
          final n = int.parse(r.url.queryParameters['page']!);
          return jsonResponse(
            n == 1
                ? page(
                    List.generate(
                      20,
                      (i) => {...parking, 'id': i + 1, 'name': 'Парковка $i'},
                    ),
                    total: 21,
                  )
                : page(
                    [
                      {...parking, 'id': 21, 'name': 'Последняя'},
                    ],
                    current: 2,
                    total: 21,
                  ),
          );
        }
        return jsonResponse(summary);
      },
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminAnalyticsScreen(
            repository: AdminRepository(AdminApi(auth.repository.api)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('17'), findsOneWidget);
    expect(find.text('Свободно: 4'), findsWidgets);
    await tester.ensureVisible(find.text('Далее'));
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    expect(find.text('Последняя'), findsOneWidget);
    expect(
      requests.any((r) => r.contains('page=2') && r.contains('pageSize=20')),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('empty results, safe retry and narrow large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var fail = true;
    final auth = fixture(
      handler: (r) async {
        if (r.url.path.endsWith('/parkings')) return jsonResponse(page([]));
        if (fail) return jsonResponse({'message': 'RAW STACK'}, 500);
        return jsonResponse({
          for (final entry in summary.entries) entry.key: 0,
        });
      },
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: AdminAnalyticsScreen(
            repository: AdminRepository(AdminApi(auth.repository.api)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ошибка загрузки аналитики'), findsOneWidget);
    expect(find.textContaining('RAW STACK'), findsNothing);
    fail = false;
    await tester.tap(find.byTooltip('Обновить аналитику'));
    await tester.pumpAndSettle();
    expect(find.text('Парковочных мест пока нет'), findsOneWidget);
    await tester.ensureVisible(find.text('Нет парковок на этой странице'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final bar in tester.widgetList<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    )) {
      expect(bar.value, 0);
    }
  });
}
