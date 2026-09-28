import '../../core/api/api_exception.dart';
import '../map/parking.dart';

class ParkingDetails {
  const ParkingDetails({
    required this.parking,
    required this.workingHours,
    required this.description,
    this.freeSpaces,
    this.totalSpaces,
  });
  final Parking parking;
  final String workingHours, description;
  final int? freeSpaces, totalSpaces;

  factory ParkingDetails.fromJson(Object? value) {
    final parking = Parking.fromJson(value);
    final json = value as Map<String, dynamic>;
    final hours = json['workingHours'], description = json['description'];
    final free = json['freeSpaces'], total = json['totalSpaces'];
    if (hours is! String ||
        hours.trim().isEmpty ||
        description is! String ||
        (free != null && (free is! int || free < 0)) ||
        (total != null && (total is! int || total < 0)) ||
        (free is int && total is int && free > total)) {
      throw const ApiException(ApiErrorKind.invalidResponse);
    }
    return ParkingDetails(
      parking: parking,
      workingHours: hours,
      description: description,
      freeSpaces: free as int?,
      totalSpaces: total as int?,
    );
  }
}
