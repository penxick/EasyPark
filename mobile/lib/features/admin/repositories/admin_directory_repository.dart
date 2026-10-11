import '../../../core/api/api_exception.dart';
import '../../auth/auth_user.dart';
import '../data/admin_api.dart';
import '../models/admin_directory.dart';

class AdminDirectoryRepository {
  const AdminDirectoryRepository(this.api, {this.onForbidden});
  final AdminApi api;
  final Future<void> Function()? onForbidden;
  Future<Object?> _get(String path, {int? page, String? category}) async {
    try {
      return await api.client.get(
        'admin/$path',
        query: page == null
            ? null
            : {'page': '$page', 'pageSize': '20', 'category': ?category},
      );
    } on ApiException catch (e) {
      if (e.kind == ApiErrorKind.forbidden) await onForbidden?.call();
      rethrow;
    }
  }

  void _id(String id) {
    if (!RegExp(r'^[1-9]\d*$').hasMatch(id) ||
        (int.tryParse(id) ?? 2147483648) > 2147483647) {
      throw const ApiException(ApiErrorKind.invalidRequest);
    }
  }

  AdminPage<T> _page<T>(
    Object? json,
    T Function(Object?) parse,
    int requested,
    int Function(T) id,
  ) {
    final result = AdminPage<T>.fromJson(json, parse);
    if (result.page != requested ||
        result.pageSize != 20 ||
        result.items.map(id).toSet().length != result.items.length) {
      throw const ApiException(ApiErrorKind.invalidResponse);
    }
    return result;
  }

  Future<AdminPage<AuthUser>> users(int page) async => _page(
    await _get('users', page: page),
    AuthUser.fromJson,
    page,
    (u) => u.id,
  );
  Future<AdminPage<AdminReservation>> reservations(
    int page,
    String category,
  ) async => _page(
    await _get('reservations', page: page, category: category),
    AdminReservation.fromJson,
    page,
    (r) => r.reservation.id,
  );
  Future<AdminUserDetails> user(String id, int page) async {
    _id(id);
    final result = AdminUserDetails.fromJson(
      await _get('users/$id', page: page),
    );
    if (result.user.id.toString() != id ||
        result.reservations.page != page ||
        result.reservations.pageSize != 20) {
      throw const ApiException(ApiErrorKind.invalidResponse);
    }
    return result;
  }

  Future<AdminReservation> reservation(String id) async {
    _id(id);
    final result = AdminReservation.fromJson(await _get('reservations/$id'));
    if (result.reservation.id.toString() != id) {
      throw const ApiException(ApiErrorKind.invalidResponse);
    }
    return result;
  }
}
