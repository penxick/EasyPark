import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class NavigationFailure implements Exception {
  const NavigationFailure(this.message);
  final String message;
}

class DrivingRoute {
  const DrivingRoute(this.points, this.distance, this.duration);
  final List<LatLng> points;
  final double distance, duration;
}

class ParkingNavigation {
  ParkingNavigation({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  void dispose() => _client.close();
  Future<LatLng> locate() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const NavigationFailure(
        'Геолокация отключена. Включите её в настройках устройства.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const NavigationFailure(
        'Разрешите доступ к местоположению в настройках приложения.',
      );
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      throw const NavigationFailure('Доступ к местоположению не разрешён.');
    }
    try {
      Position p;
      try {
        p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } on TimeoutException {
        if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) rethrow;
        // Fused Location can stall while GPS itself remains available.
        // This foreground request still uses the platform's permission checks.
        p = await Geolocator.getCurrentPosition(
          locationSettings: AndroidSettings(
            forceLocationManager: true,
            accuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 15),
          ),
        );
      }
      if (!p.latitude.isFinite ||
          !p.longitude.isFinite ||
          p.latitude.abs() > 90 ||
          p.longitude.abs() > 180) {
        throw const NavigationFailure(
          'Не удалось получить координаты. Повторите попытку.',
        );
      }
      return LatLng(p.latitude, p.longitude);
    } on NavigationFailure {
      rethrow;
    } catch (_) {
      throw const NavigationFailure(
        'Не удалось определить местоположение. Проверьте GPS и повторите попытку.',
      );
    }
  }

  Future<DrivingRoute> route(LatLng from, LatLng to) async {
    try {
      const endpoint = String.fromEnvironment(
        'ROUTING_BASE_URL',
        defaultValue: 'https://router.project-osrm.org/route/v1/driving/',
      );
      final base = Uri.parse(endpoint);
      if (base.scheme != 'https' ||
          base.host.isEmpty ||
          base.userInfo.isNotEmpty ||
          base.hasQuery ||
          base.hasFragment) {
        throw const FormatException();
      }
      final url = base.replace(
        path:
            '${base.path.endsWith('/') ? base.path : '${base.path}/'}${from.longitude},${from.latitude};${to.longitude},${to.latitude}',
        queryParameters: {
          'overview': 'full',
          'geometries': 'geojson',
          'steps': 'false',
        },
      );
      final response = await _client
          .get(url)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) throw const FormatException();
      final body = jsonDecode(response.body);
      if (body is! Map ||
          body['code'] != 'Ok' ||
          body['routes'] is! List ||
          (body['routes'] as List).isEmpty) {
        throw const FormatException();
      }
      final route = body['routes'][0];
      final distance = route['distance'], duration = route['duration'];
      if (distance is! num ||
          duration is! num ||
          !distance.isFinite ||
          !duration.isFinite ||
          distance < 0 ||
          duration < 0 ||
          route['geometry']['type'] != 'LineString') {
        throw const FormatException();
      }
      final points = <LatLng>[];
      for (final pair in route['geometry']['coordinates']) {
        if (pair is! List ||
            pair.length != 2 ||
            pair[0] is! num ||
            pair[1] is! num) {
          throw const FormatException();
        }
        final lng = (pair[0] as num).toDouble(),
            lat = (pair[1] as num).toDouble();
        if (!lat.isFinite ||
            !lng.isFinite ||
            lat.abs() > 90 ||
            lng.abs() > 180) {
          throw const FormatException();
        }
        points.add(LatLng(lat, lng));
      }
      if (points.length < 2) throw const FormatException();
      return DrivingRoute(
        List.unmodifiable(points),
        distance.toDouble(),
        duration.toDouble(),
      );
    } catch (_) {
      throw const NavigationFailure(
        'Не удалось построить маршрут. Проверьте интернет или повторите позже.',
      );
    }
  }
}
