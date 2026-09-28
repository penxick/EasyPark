import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import 'parking_space.dart';

class ParkingSpacesRepository {
  const ParkingSpacesRepository(this.api);
  final ApiClient api;
  Future<List<ParkingSpace>> fetchAll(String parkingId) async {
    if (!RegExp(r'^[1-9]\d*$').hasMatch(parkingId) ||
        (int.tryParse(parkingId) ?? 2147483648) > 2147483647) {
      throw const ApiException(ApiErrorKind.invalidRequest);
    }
    final value = await api.get('parkings/$parkingId/spaces');
    if (value is! List) throw const ApiException(ApiErrorKind.invalidResponse);
    final spaces = value.map(ParkingSpace.fromJson).toList(growable: false);
    if (spaces.any((s) => s.parkingId != int.parse(parkingId)) ||
        spaces.map((s) => s.id).toSet().length != spaces.length ||
        spaces.map((s) => s.code).toSet().length != spaces.length) {
      throw const ApiException(ApiErrorKind.invalidResponse);
    }
    return List.unmodifiable(spaces);
  }
}
