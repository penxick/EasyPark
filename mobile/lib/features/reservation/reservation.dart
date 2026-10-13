import '../../core/api/api_exception.dart';

enum ReservationCategory {
  active('Активные', 'У вас пока нет активных бронирований.'),
  completed('Завершённые', 'У вас пока нет завершённых бронирований.'),
  cancelled('Отменённые', 'У вас пока нет отменённых бронирований.');

  const ReservationCategory(this.label, this.emptyMessage);
  final String label, emptyMessage;
}

class Reservation {
  const Reservation({
    required this.id,
    required this.userId,
    required this.parkingSpaceId,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.totalPrice,
    this.mode,
    this.sessionState,
    this.paymentMethod,
    this.plannedMinutes,
    this.hourlyRateSnapshot,
    this.preliminaryPrice,
    this.finalPrice,
    this.actualStartTime,
    this.actualEndTime,
    this.elapsedSeconds = 0,
  });
  final int id, userId, parkingSpaceId;
  final DateTime startTime, endTime;
  final String status;
  final double totalPrice;
  final String? mode,
      sessionState,
      paymentMethod,
      hourlyRateSnapshot,
      preliminaryPrice,
      finalPrice;
  final int? plannedMinutes;
  final int elapsedSeconds;
  final DateTime? actualStartTime, actualEndTime;

  bool get active => status == 'ACTIVE' || status == 'PENDING';
  ReservationCategory get category => active
      ? ReservationCategory.active
      : status == 'CANCELLED'
      ? ReservationCategory.cancelled
      : ReservationCategory.completed;
  String get statusLabel => switch (status) {
    'ACTIVE' => 'Активно',
    'PENDING' => 'Ожидает подтверждения',
    'CANCELLED' => 'Отменено',
    'COMPLETED' => 'Завершено',
    _ => 'Срок истёк',
  };
  factory Reservation.fromJson(Object? value) {
    const invalid = ApiException(ApiErrorKind.invalidResponse);
    if (value is! Map<String, dynamic>) throw invalid;
    final id = value['id'],
        user = value['userId'],
        space = value['parkingSpaceId'],
        price = value['totalPrice'],
        status = value['status'];
    final start = DateTime.tryParse(
      value['startTime'] is String ? value['startTime'] as String : '',
    );
    final end = DateTime.tryParse(
      value['endTime'] is String ? value['endTime'] as String : '',
    );
    if (id is! int ||
        id <= 0 ||
        user is! int ||
        user <= 0 ||
        space is! int ||
        space <= 0 ||
        price is! num ||
        !price.isFinite ||
        price < 0 ||
        start == null ||
        end == null ||
        !end.isAfter(start) ||
        !{
          'PENDING',
          'ACTIVE',
          'COMPLETED',
          'CANCELLED',
          'EXPIRED',
        }.contains(status)) {
      throw invalid;
    }
    return Reservation(
      id: id,
      userId: user,
      parkingSpaceId: space,
      startTime: start,
      endTime: end,
      status: status as String,
      totalPrice: price.toDouble(),
      mode: value['mode'] as String?,
      sessionState: value['sessionState'] as String?,
      paymentMethod: value['paymentMethod'] as String?,
      plannedMinutes: value['plannedMinutes'] as int?,
      hourlyRateSnapshot: value['hourlyRateSnapshot']?.toString(),
      preliminaryPrice: value['preliminaryPrice']?.toString(),
      finalPrice: value['finalPrice']?.toString(),
      actualStartTime: DateTime.tryParse(
        value['actualStartTime']?.toString() ?? '',
      ),
      actualEndTime: DateTime.tryParse(
        value['actualEndTime']?.toString() ?? '',
      ),
      elapsedSeconds: (value['elapsedSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}

String rubles(num amount) =>
    '${amount.toStringAsFixed(2).replaceAll('.', ',')} ₽';
String reservationTime(DateTime value) {
  final d = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
}
