import '../../../core/api/api_exception.dart';

class AdminSummary {
  const AdminSummary({
    required this.totalParkings,
    required this.totalSpaces,
    required this.freeSpaces,
    required this.occupiedSpaces,
    required this.reservedSpaces,
    required this.unavailableSpaces,
    required this.totalUsers,
    required this.activeReservations,
    required this.totalReservations,
    required this.physicalOccupiedSpaces,
    required this.occupancyPercent,
  });
  final int totalParkings,
      totalSpaces,
      freeSpaces,
      occupiedSpaces,
      reservedSpaces,
      unavailableSpaces,
      totalUsers,
      activeReservations,
      totalReservations,
      physicalOccupiedSpaces;
  final double occupancyPercent;

  factory AdminSummary.fromJson(Object? json) {
    const invalid = ApiException(ApiErrorKind.invalidResponse);
    if (json is! Map<String, dynamic>) throw invalid;
    int count(String key) {
      final value = json[key];
      if (value is! int || value < 0) throw invalid;
      return value;
    }

    final occupancy = json['occupancyPercent'];
    if (occupancy is! num ||
        !occupancy.isFinite ||
        occupancy < 0 ||
        occupancy > 100) {
      throw invalid;
    }
    final result = AdminSummary(
      totalParkings: count('totalParkings'),
      totalSpaces: count('totalSpaces'),
      freeSpaces: count('freeSpaces'),
      occupiedSpaces: count('occupiedSpaces'),
      reservedSpaces: count('reservedSpaces'),
      unavailableSpaces: count('unavailableSpaces'),
      totalUsers: count('totalUsers'),
      activeReservations: count('activeReservations'),
      totalReservations: count('totalReservations'),
      physicalOccupiedSpaces: count('physicalOccupiedSpaces'),
      occupancyPercent: occupancy.toDouble(),
    );
    if (result.freeSpaces +
                result.occupiedSpaces +
                result.reservedSpaces +
                result.unavailableSpaces !=
            result.totalSpaces ||
        result.activeReservations > result.totalReservations ||
        result.physicalOccupiedSpaces > result.totalSpaces) {
      throw invalid;
    }
    return result;
  }
}
