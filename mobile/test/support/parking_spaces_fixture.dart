import 'package:easypark/features/parking/parking_space.dart';

Map<String, Object?> spaceJson(
  int id,
  String status, {
  bool occupied = false,
  int parkingId = 7,
}) => {
  'id': id,
  'parkingId': parkingId,
  'code': 'A0$id',
  'status': status,
  'physicalOccupied': occupied,
  'x': 50,
  'y': 50 + (id - 1) * 50,
  'polygon': null,
};
final testSpacesJson = [
  spaceJson(1, 'FREE'),
  spaceJson(2, 'OCCUPIED', occupied: true),
  spaceJson(3, 'RESERVED'),
  spaceJson(4, 'UNAVAILABLE'),
];
final testSpaces = testSpacesJson.map(ParkingSpace.fromJson).toList();
