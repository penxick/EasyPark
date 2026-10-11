import '../../../core/api/api_exception.dart';
import 'admin_summary.dart';

class AdminParkingAnalytics {
  const AdminParkingAnalytics(this.id, this.name, this.metrics);
  final int id;
  final String name;
  final AdminSummary metrics;
  factory AdminParkingAnalytics.fromJson(Object? json) {
    if (json is! Map<String, dynamic> ||
        json['id'] is! int ||
        (json['id'] as int) <= 0 ||
        json['name'] is! String ||
        (json['name'] as String).trim().isEmpty) {
      throw const ApiException(ApiErrorKind.invalidResponse);
    }
    // Reuse the shared validation of space and reservation aggregates.
    return AdminParkingAnalytics(
      json['id'] as int,
      json['name'] as String,
      AdminSummary.fromJson({...json, 'totalParkings': 1, 'totalUsers': 0}),
    );
  }
}
