import '../../../core/api/api_exception.dart';
import '../../map/parking_repository.dart';
import '../../parking/parking_details.dart';
import '../data/admin_api.dart';

class AdminParkingRepository {
  const AdminParkingRepository(this.api, {this.onForbidden});
  final AdminApi api;
  final Future<void> Function()? onForbidden;
  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.forbidden) await onForbidden?.call();
      rethrow;
    }
  }

  Future<List<ParkingDetails>> all() =>
      _guard(ParkingRepository(api.client).fetchAllDetails);
  Future<ParkingDetails> one(String id) =>
      _guard(() => ParkingRepository(api.client).fetchOne(id));
  Future<ParkingDetails> save(int? id, Map<String, Object> body) =>
      _guard(() async {
        final result = ParkingDetails.fromJson(
          id == null
              ? await api.createParking(body)
              : await api.updateParking(id, body),
        );
        if (id != null && result.parking.id != id) {
          throw const ApiException(ApiErrorKind.invalidResponse);
        }
        return result;
      });
  Future<void> remove(int id) => _guard(() => api.deleteParking(id));
}
