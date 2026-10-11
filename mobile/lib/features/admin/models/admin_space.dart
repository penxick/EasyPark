import '../../../core/api/api_exception.dart';
import '../../parking/parking_space.dart';

class AdminSpace {
  const AdminSpace(this.space, this.hasActiveReservation, this.polygon);
  final ParkingSpace space;
  final bool hasActiveReservation;
  final List<List<double>>? polygon;
  factory AdminSpace.fromJson(Object? value) {
    final space = ParkingSpace.fromJson(value);
    final json = value as Map<String, dynamic>;
    final active = json['hasActiveReservation'];
    final polygon = json['polygon'];
    const invalid = ApiException(ApiErrorKind.invalidResponse);
    if (active is! bool || !json.containsKey('polygon')) throw invalid;
    if (polygon != null &&
        (polygon is! List ||
            polygon.length < 3 ||
            polygon.length > 1000 ||
            polygon.any(
              (p) =>
                  p is! List ||
                  p.length != 2 ||
                  p.any((n) => n is! num || !n.isFinite),
            ))) {
      throw invalid;
    }
    return AdminSpace(
      space,
      active,
      polygon == null
          ? null
          : List.unmodifiable(
              (polygon as List).map(
                (p) => List<double>.unmodifiable(
                  (p as List).map((n) => (n as num).toDouble()),
                ),
              ),
            ),
    );
  }
  String get polygonText =>
      polygon?.map((p) => '${p[0]}; ${p[1]}').join('\n') ?? '';

  static List<List<double>>? parsePolygon(String text) {
    if (text.trim().isEmpty) return null;
    final lines = text.trim().split('\n');
    if (lines.length < 3 || lines.length > 1000) {
      throw const FormatException('vertices');
    }
    return lines
        .map((line) {
          final parts = line.split(';');
          if (parts.length != 2) throw const FormatException('pair');
          return parts
              .map((part) {
                final value = double.tryParse(part.trim().replaceAll(',', '.'));
                if (value == null || !value.isFinite) {
                  throw const FormatException('number');
                }
                return value;
              })
              .toList(growable: false);
        })
        .toList(growable: false);
  }
}
