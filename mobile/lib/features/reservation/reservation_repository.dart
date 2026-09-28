import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../map/parking.dart';
import '../map/parking_repository.dart';
import '../parking/parking_space.dart';
import '../parking/parking_spaces_repository.dart';
import 'reservation.dart';

class BookingContext {
  const BookingContext(this.parking, this.space);
  final Parking parking;
  final ParkingSpace space;
}

class ReservationEntry {
  const ReservationEntry(this.reservation, this.place);
  final Reservation reservation;
  final BookingContext? place;
}

class ReservationRepository {
  const ReservationRepository(this.api);
  final ApiClient api;
  Future<BookingContext> contextFor(String parkingId, String spaceId) async {
    if (!RegExp(r'^[1-9]\d*$').hasMatch(spaceId) ||
        (int.tryParse(spaceId) ?? 2147483648) > 2147483647) {
      throw const ApiException(ApiErrorKind.invalidRequest);
    }
    final parking = await ParkingRepository(api).fetchOne(parkingId);
    final spaces = await ParkingSpacesRepository(api).fetchAll(parkingId);
    final matches = spaces.where((s) => s.id == int.parse(spaceId));
    if (matches.isEmpty) throw const ApiException(ApiErrorKind.notFound);
    return BookingContext(parking.parking, matches.single);
  }

  Future<Reservation> create(int spaceId, int minutes) async {
    if (spaceId <= 0 || ![30, 60, 120, 180].contains(minutes)) {
      throw const ApiException(ApiErrorKind.invalidRequest);
    }
    final result = Reservation.fromJson(
      await api.post(
        'reservations',
        body: {'parkingSpaceId': spaceId, 'durationMinutes': minutes},
      ),
    );
    if (result.parkingSpaceId != spaceId || !result.active) {
      throw const ApiException(ApiErrorKind.invalidResponse);
    }
    return result;
  }

  Future<List<Reservation>> mine() async {
    final value = await api.get('reservations/me');
    if (value is! List) throw const ApiException(ApiErrorKind.invalidResponse);
    final items = value.map(Reservation.fromJson).toList();
    if (items.map((r) => r.id).toSet().length != items.length) {
      throw const ApiException(ApiErrorKind.invalidResponse);
    }
    return items;
  }

  Future<Reservation> cancel(int id) async {
    if (id <= 0) throw const ApiException(ApiErrorKind.invalidRequest);
    final result = Reservation.fromJson(
      await api.patch('reservations/$id/cancel'),
    );
    if (result.id != id || result.status != 'CANCELLED') {
      throw const ApiException(ApiErrorKind.invalidResponse);
    }
    return result;
  }

  Future<List<ReservationEntry>> active() async =>
      (await history()).where((entry) => entry.reservation.active).toList();

  Future<List<ReservationEntry>> history() async {
    final items = await mine();
    if (items.isEmpty) return [];
    final places = <int, BookingContext>{};
    final parks = await ParkingRepository(api).fetchAll();
    for (final park in parks) {
      final spaces = await ParkingSpacesRepository(api).fetchAll('${park.id}');
      for (final space in spaces) {
        places[space.id] = BookingContext(park, space);
      }
    }
    return items
        .map((r) => ReservationEntry(r, places[r.parkingSpaceId]))
        .toList();
  }
}
