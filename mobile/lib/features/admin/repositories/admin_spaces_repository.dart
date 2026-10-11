import '../../../core/api/api_exception.dart';
import '../../map/parking_repository.dart';
import '../data/admin_api.dart';
import '../models/admin_space.dart';

class AdminSpacesRepository {
  const AdminSpacesRepository(this.api, {this.onForbidden});
  final AdminApi api;
  final Future<void> Function()? onForbidden;
  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException catch (e) {
      if (e.kind == ApiErrorKind.forbidden) await onForbidden?.call();
      rethrow;
    }
  }

  Future<({String name, List<AdminSpace> spaces})> load(
    String parkingId,
  ) => _guard(() async {
    // Existing reader validates the parent ID and shares the same Parking entity.
    final parking = await ParkingRepository(api.client).fetchOne(parkingId);
    final response = await api.client.get('parkings/$parkingId/spaces');
    if (response is! List) {
      throw const ApiException(ApiErrorKind.invalidResponse);
    }
    final items = response.map(AdminSpace.fromJson).toList(growable: false);
    if (items.any((s) => s.space.parkingId != parking.parking.id) ||
        items.map((s) => s.space.id).toSet().length != items.length ||
        items.map((s) => s.space.code).toSet().length != items.length) {
      throw const ApiException(ApiErrorKind.invalidResponse);
    }
    return (name: parking.parking.name, spaces: items);
  });
  Future<AdminSpace> save(
    String parkingId,
    int? id,
    Map<String, Object?> body,
  ) => _guard(() async {
    final result = AdminSpace.fromJson(
      id == null
          ? await api.createSpace(parkingId, body)
          : await api.updateSpace(id, body),
    );
    if (result.space.parkingId.toString() != parkingId ||
        (id != null && result.space.id != id)) {
      throw const ApiException(ApiErrorKind.invalidResponse);
    }
    return result;
  });
  Future<void> remove(int id) => _guard(() => api.deleteSpace(id));
}
