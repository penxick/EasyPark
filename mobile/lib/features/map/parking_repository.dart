import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import 'parking.dart';
import '../parking/parking_details.dart';

class ParkingRepository {
  const ParkingRepository(this.api);
  final ApiClient api;
  Future<ParkingDetails> fetchOne(String id) async {
    if (!RegExp(r'^[1-9]\d*$').hasMatch(id) ||
        (int.tryParse(id) ?? 2147483648) > 2147483647) {
      throw const ApiException(ApiErrorKind.invalidRequest);
    }
    final details = ParkingDetails.fromJson(await api.get('parkings/$id'));
    if (details.parking.id != int.parse(id)) {
      throw const ApiException(ApiErrorKind.invalidResponse);
    }
    return details;
  }

  Future<List<Parking>> fetchAll() async {
    final response = await api.get('parkings');
    if (response is! List) {
      throw const ApiException(ApiErrorKind.invalidResponse);
    }
    final items = response.map(Parking.fromJson).toList(growable: false);
    if (items.map((p) => p.id).toSet().length != items.length) {
      throw const ApiException(ApiErrorKind.invalidResponse);
    }
    return List.unmodifiable(items);
  }
}
