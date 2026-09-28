import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/auth_form_screen.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/map/map_screen.dart';
import '../../features/map/parking_repository.dart';
import '../../features/parking/parking_details_screen.dart';
import '../../features/parking/parking_layout_screen.dart';
import '../../features/parking/parking_spaces_repository.dart';
import '../../features/navigation/main_shell.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/reservation/reservations_screen.dart';
import '../../features/reservation/booking_screen.dart';
import '../../features/reservation/reservation_repository.dart';
import 'app_routes.dart';

GoRouter createAppRouter({
  required AuthController auth,
  String initialLocation = AppRoutes.splash,
}) => GoRouter(
  initialLocation: initialLocation,
  refreshListenable: auth,
  redirect: (context, state) {
    final path = state.uri.path;
    final isForm = path == AppRoutes.login || path == AppRoutes.register;
    return switch (auth.status) {
      AuthStatus.checking || AuthStatus.restoreError =>
        path == AppRoutes.splash ? null : AppRoutes.splash,
      AuthStatus.signedOut => isForm ? null : AppRoutes.login,
      AuthStatus.signedIn =>
        isForm || path == AppRoutes.splash || path == '/'
            ? AppRoutes.home
            : null,
    };
  },
  routes: [
    GoRoute(path: '/', redirect: (_, _) => AppRoutes.splash),
    GoRoute(
      path: AppRoutes.splash,
      builder: (_, _) => SplashScreen(auth: auth),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (_, _) =>
          AuthFormScreen(key: const ValueKey('login'), auth: auth),
    ),
    GoRoute(
      path: AppRoutes.register,
      builder: (_, _) => AuthFormScreen(
        key: const ValueKey('register'),
        auth: auth,
        registration: true,
      ),
    ),
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => MainShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (_, _) =>
                  MapScreen(repository: ParkingRepository(auth.repository.api)),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.reservations,
              builder: (_, _) => ReservationsScreen(
                repository: ReservationRepository(auth.repository.api),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.profile,
              builder: (_, _) => ProfileScreen(auth: auth),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.parking,
      builder: (_, state) => ParkingDetailsScreen(
        id: state.pathParameters['id']!,
        repository: ParkingRepository(auth.repository.api),
      ),
    ),
    GoRoute(
      path: AppRoutes.parkingSpaces,
      builder: (_, state) => ParkingLayoutScreen(
        parkingId: state.pathParameters['id']!,
        repository: ParkingSpacesRepository(auth.repository.api),
      ),
    ),
    GoRoute(
      path: '/parking/:id/book/:spaceId',
      builder: (_, state) => BookingScreen(
        key: ValueKey(state.uri.path),
        parkingId: state.pathParameters['id']!,
        spaceId: state.pathParameters['spaceId']!,
        repository: ReservationRepository(auth.repository.api),
      ),
    ),
    for (final entry in const {AppRoutes.space: 'Парковочное место'}.entries)
      GoRoute(
        path: entry.key,
        builder: (_, state) => _RoutePlaceholder(
          title: entry.value,
          id: state.pathParameters['id'],
        ),
      ),
  ],
  errorBuilder: (_, _) =>
      const _RoutePlaceholder(title: 'Страница не найдена', isNotFound: true),
);

// Future feature screens remain placeholders until their respective stages.
class _RoutePlaceholder extends StatelessWidget {
  const _RoutePlaceholder({
    required this.title,
    this.id,
    this.isNotFound = false,
  });
  final String title;
  final String? id;
  final bool isNotFound;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, textAlign: TextAlign.center),
              if (id != null) Text(id!, textAlign: TextAlign.center),
              if (isNotFound)
                TextButton(
                  onPressed: () => context.go(AppRoutes.home),
                  child: const Text('На главную'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
