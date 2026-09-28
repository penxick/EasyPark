import '../../core/api/api_exception.dart';

enum SpaceStatus { free, occupied, reserved, unavailable }

class ParkingSpace {
  const ParkingSpace({
    required this.id,
    required this.parkingId,
    required this.code,
    required this.status,
    required this.physicalOccupied,
    required this.x,
    required this.y,
  });
  final int id, parkingId;
  final String code;
  final SpaceStatus status;
  final bool physicalOccupied;
  final double x, y;
  SpaceStatus get displayStatus =>
      status == SpaceStatus.free && physicalOccupied
      ? SpaceStatus.occupied
      : status;
  bool get selectable => displayStatus == SpaceStatus.free;
  factory ParkingSpace.fromJson(Object? value) {
    const invalid = ApiException(ApiErrorKind.invalidResponse);
    if (value is! Map<String, dynamic>) throw invalid;
    final id = value['id'],
        parkingId = value['parkingId'],
        code = value['code'],
        status = value['status'],
        physical = value['physicalOccupied'],
        x = value['x'],
        y = value['y'];
    if (id is! int ||
        id <= 0 ||
        parkingId is! int ||
        parkingId <= 0 ||
        code is! String ||
        code.trim().isEmpty ||
        status is! String ||
        physical is! bool ||
        x is! num ||
        !x.isFinite ||
        x < 0 ||
        y is! num ||
        !y.isFinite ||
        y < 0) {
      throw invalid;
    }
    return ParkingSpace(
      id: id,
      parkingId: parkingId,
      code: code,
      status: switch (status) {
        'FREE' => SpaceStatus.free,
        'OCCUPIED' => SpaceStatus.occupied,
        'RESERVED' => SpaceStatus.reserved,
        _ => SpaceStatus.unavailable,
      },
      physicalOccupied: physical,
      x: x.toDouble(),
      y: y.toDouble(),
    );
  }
}
