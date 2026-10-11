import '../../../core/api/api_exception.dart';
import '../data/admin_api.dart';
import '../models/admin_summary.dart';
import '../models/admin_directory.dart';
import '../models/admin_parking_analytics.dart';

class AdminRepository {
  const AdminRepository(this.api, {this.onForbidden});
  final AdminApi api;
  final Future<void> Function()? onForbidden;

  Future<AdminPage<AdminParkingAnalytics>> parkings(int page) async {
    try {
      final result = AdminPage<AdminParkingAnalytics>.fromJson(
        await api.client.get(
          'admin/analytics/parkings',
          query: {'page': '$page', 'pageSize': '20'},
        ),
        AdminParkingAnalytics.fromJson,
      );
      if (result.page != page ||
          result.pageSize != 20 ||
          result.items.map((p) => p.id).toSet().length != result.items.length) {
        throw const ApiException(ApiErrorKind.invalidResponse);
      }
      return result;
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.forbidden) await onForbidden?.call();
      rethrow;
    }
  }

  Future<AdminSummary> summary() async {
    try {
      return AdminSummary.fromJson(await api.summary());
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.forbidden) await onForbidden?.call();
      rethrow;
    }
  }
}
