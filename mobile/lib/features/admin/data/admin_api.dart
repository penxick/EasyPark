import '../../../core/api/api_client.dart';

class AdminApi {
  const AdminApi(this.client);
  final ApiClient client;
  Future<Object?> summary() => client.get('admin/analytics');
  Future<Object?> createParking(Map<String, Object> body) =>
      client.post('admin/parkings', body: body);
  Future<Object?> updateParking(int id, Map<String, Object> body) =>
      client.patch('admin/parkings/$id', body: body);
  Future<void> deleteParking(int id) async {
    await client.delete('admin/parkings/$id');
  }

  Future<Object?> createSpace(String parkingId, Map<String, Object?> body) =>
      client.post('admin/parkings/$parkingId/spaces', body: body);
  Future<Object?> updateSpace(int id, Map<String, Object?> body) =>
      client.patch('admin/spaces/$id', body: body);
  Future<void> deleteSpace(int id) async {
    await client.delete('admin/spaces/$id');
  }
}
