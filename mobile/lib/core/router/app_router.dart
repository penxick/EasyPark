import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../features/admin/models/admin_map_request.dart';
import '../../features/admin/screens/admin_parking_map_screen.dart';
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
import '../../features/admin/data/admin_api.dart';
import '../../features/admin/repositories/admin_repository.dart';
import '../../features/admin/screens/admin_dashboard_screen.dart';
import '../../features/admin/screens/admin_profile_screen.dart';
import '../../features/admin/screens/admin_analytics_screen.dart';
import '../../features/admin/widgets/admin_shell.dart';
import '../../features/admin/screens/admin_parkings_screen.dart';
import '../../features/admin/repositories/admin_parking_repository.dart';
import '../../features/admin/repositories/admin_spaces_repository.dart';
import '../../features/admin/screens/admin_spaces_screen.dart';
import '../../features/admin/screens/admin_directory_screen.dart';
import '../../features/admin/repositories/admin_directory_repository.dart';

GoRouter createAppRouter({
  required AuthController auth,
  String initialLocation = AppRoutes.splash,
  TileProvider Function()? adminMapTileProviderFactory,
}) => GoRouter(
  initialLocation: initialLocation,
  refreshListenable: auth,
  redirect: (context, state) {
    final path = state.uri.path;
    final isForm = path == AppRoutes.login || path == AppRoutes.register;
    final isAdminPath =
        path == AppRoutes.admin || path.startsWith('${AppRoutes.admin}/');
    if (auth.status == AuthStatus.signedIn) {
      if (isAdminPath && !auth.isAdmin) return AppRoutes.accessDenied;
      if (auth.isAdmin && !isAdminPath) return AppRoutes.admin;
    }
    return switch (auth.status) {
      AuthStatus.checking || AuthStatus.restoreError =>
        path == AppRoutes.splash ? null : AppRoutes.splash,
      AuthStatus.signedOut => isForm ? null : AppRoutes.login,
      AuthStatus.signedIn =>
        isForm || path == AppRoutes.splash || path == '/'
            ? (auth.isAdmin ? AppRoutes.admin : AppRoutes.home)
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
    GoRoute(
      path: AppRoutes.accessDenied,
      builder: (_, _) =>
          const _RoutePlaceholder(title: 'Нет доступа', isNotFound: true),
    ),
    ShellRoute(
      builder: (_, state, child) => AdminShell(
        key: ValueKey('admin-${auth.user?.id}'),
        path: state.uri.path,
        child: child,
      ),
      routes: [
        GoRoute(
          path: AppRoutes.admin,
          builder: (_, _) => AdminDashboardScreen(
            key: ValueKey('dashboard-${auth.user?.id}'),
            repository: AdminRepository(
              AdminApi(auth.repository.api),
              onForbidden: auth.refreshIdentity,
            ),
          ),
        ),
        GoRoute(
          path: '/admin/profile',
          builder: (_, _) => AdminProfileScreen(auth: auth),
        ),
        for (final picker in [false, true])
          GoRoute(
            path: picker
                ? '/admin/parkings/pick-location'
                : '/admin/parkings/map',
            builder: (_, state) => AdminParkingMapScreen(
              key: ValueKey('${auth.user?.id}-${state.uri.path}'),
              repository: AdminParkingRepository(
                AdminApi(auth.repository.api),
                onForbidden: auth.refreshIdentity,
              ),
              picker: picker,
              initialPoint: state.extra is LatLng
                  ? state.extra as LatLng
                  : null,
              tileProviderFactory: adminMapTileProviderFactory,
            ),
          ),
        for (final path in [
          '/admin/parkings',
          '/admin/parkings/new',
          '/admin/parkings/:id/edit',
          '/admin/parkings/:id',
        ])
          GoRoute(
            path: path,
            builder: (_, state) => AdminParkingsScreen(
              key: ValueKey('${auth.user?.id}-${state.uri.path}'),
              repository: AdminParkingRepository(
                AdminApi(auth.repository.api),
                onForbidden: auth.refreshIdentity,
              ),
              id: state.pathParameters['id'],
              edit: path.endsWith('/new') || path.endsWith('/edit'),
              mapRequest: state.extra is AdminMapRequest
                  ? state.extra as AdminMapRequest
                  : null,
            ),
          ),
        GoRoute(
          path: '/admin/analytics',
          builder: (_, _) => AdminAnalyticsScreen(
            key: ValueKey('analytics-${auth.user?.id}'),
            repository: AdminRepository(
              AdminApi(auth.repository.api),
              onForbidden: auth.refreshIdentity,
            ),
          ),
        ),
        for (final path in [
          '/admin/users',
          '/admin/users/:id',
          '/admin/reservations',
          '/admin/reservations/:id',
        ])
          GoRoute(
            path: path,
            builder: (_, state) => AdminDirectoryScreen(
              key: ValueKey('${auth.user?.id}-${state.uri.path}'),
              users: path.startsWith('/admin/users'),
              id: state.pathParameters['id'],
              repository: AdminDirectoryRepository(
                AdminApi(auth.repository.api),
                onForbidden: auth.refreshIdentity,
              ),
            ),
          ),
        GoRoute(
          path: '/admin/parkings/:id/spaces',
          builder: (_, state) => AdminSpacesScreen(
            key: ValueKey('${auth.user?.id}-${state.pathParameters['id']}'),
            parkingId: state.pathParameters['id']!,
            repository: AdminSpacesRepository(
              AdminApi(auth.repository.api),
              onForbidden: auth.refreshIdentity,
            ),
          ),
        ),
      ],
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
