import '../../../core/api/api_exception.dart';
import '../../auth/auth_user.dart';
import '../../reservation/reservation.dart';

const _invalid = ApiException(ApiErrorKind.invalidResponse);
int _count(Object? n) {
  if (n is! int || n < 0) throw _invalid;
  return n;
}

String _text(Object? s) {
  if (s is! String || s.trim().isEmpty) throw _invalid;
  return s;
}

class AdminPage<T> {
  const AdminPage(
    this.items,
    this.total,
    this.page,
    this.pageSize,
    this.totalPages,
  );
  final List<T> items;
  final int total, page, pageSize, totalPages;
  factory AdminPage.fromJson(Object? value, T Function(Object?) parse) {
    if (value is! Map<String, dynamic> || value['items'] is! List) {
      throw _invalid;
    }
    final total = _count(value['total']),
        page = _count(value['page']),
        size = _count(value['pageSize']),
        pages = _count(value['totalPages']);
    if (page < 1 || size < 1 || size > 100 || pages != (total / size).ceil()) {
      throw _invalid;
    }
    final items = (value['items'] as List).map(parse).toList(growable: false);
    final expected = (total - (page - 1) * size).clamp(0, size);
    if (items.length != expected) throw _invalid;
    return AdminPage(List.unmodifiable(items), total, page, size, pages);
  }
}

class AdminReservation {
  const AdminReservation(
    this.reservation,
    this.createdAt,
    this.userName,
    this.email,
    this.parkingId,
    this.parkingName,
    this.address,
    this.spaceCode,
  );
  final Reservation reservation;
  final DateTime createdAt;
  final String userName, email, parkingName, address, spaceCode;
  final int parkingId;
  factory AdminReservation.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) throw _invalid;
    final user = value['user'],
        parking = value['parking'],
        space = value['space'];
    if (user is! Map<String, dynamic> ||
        parking is! Map<String, dynamic> ||
        space is! Map<String, dynamic>) {
      throw _invalid;
    }
    final reservation = Reservation.fromJson({
      ...value,
      'userId': user['id'],
      'parkingSpaceId': space['id'],
    });
    final created = DateTime.tryParse(_text(value['createdAt']));
    final parkingId = _count(parking['id']);
    if (created == null || parkingId == 0) throw _invalid;
    return AdminReservation(
      reservation,
      created,
      _text(user['name']),
      _text(user['email']),
      parkingId,
      _text(parking['name']),
      _text(parking['address']),
      _text(space['code']),
    );
  }
}

class AdminUserDetails {
  const AdminUserDetails(
    this.user,
    this.reservationCount,
    this.activeReservationCount,
    this.reservations,
  );
  final AuthUser user;
  final int reservationCount, activeReservationCount;
  final AdminPage<AdminReservation> reservations;
  factory AdminUserDetails.fromJson(Object? value) {
    final user = AuthUser.fromJson(value);
    final json = value as Map<String, dynamic>;
    final count = _count(json['reservationCount']),
        active = _count(json['activeReservationCount']);
    final history = AdminPage<AdminReservation>.fromJson(
      json['reservations'],
      AdminReservation.fromJson,
    );
    if (active > count ||
        history.items.any((r) => r.reservation.userId != user.id)) {
      throw _invalid;
    }
    return AdminUserDetails(user, count, active, history);
  }
}
