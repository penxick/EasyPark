import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_fixture.dart';
import 'map_fixture.dart';
import 'parking_spaces_fixture.dart';

Map<String, Object?> reservationJson({
  String status = 'ACTIVE',
  int spaceId = 1,
}) => {
  'id': 10,
  'userId': 1,
  'parkingSpaceId': spaceId,
  'startTime': '2026-09-28T10:00:00Z',
  'endTime': '2026-09-28T11:00:00Z',
  'status': status,
  'totalPrice': 120.5,
};

class ReservationFixture {
  int posts = 0, patches = 0, gets = 0;
  int postStatus = 201, cancelStatus = 200;
  String? status;
  bool occupied = false, commitOnError = false;
  Future<http.Response>? pending;
  Map<String, dynamic>? sent;
  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    if ((path.endsWith('/reservations') ||
            path.endsWith('/reservations/sessions')) &&
        request.method == 'POST') {
      posts++;
      sent = jsonDecode(request.body) as Map<String, dynamic>;
      if (pending != null) return pending!;
      if (postStatus == 201 || commitOnError) status = 'ACTIVE';
      return jsonResponse(reservationJson(), postStatus);
    }
    if (path.endsWith('/cancel')) {
      patches++;
      if (cancelStatus == 200) status = 'CANCELLED';
      return jsonResponse(reservationJson(status: 'CANCELLED'), cancelStatus);
    }
    if (path.endsWith('/reservations/me')) {
      gets++;
      return jsonResponse(
        status == null ? [] : [reservationJson(status: status!)],
      );
    }
    if (path.endsWith('/spaces')) {
      return jsonResponse([
        spaceJson(
          1,
          occupied
              ? 'OCCUPIED'
              : status == 'ACTIVE'
              ? 'RESERVED'
              : 'FREE',
        ),
      ]);
    }
    if (path.endsWith('/parkings')) return jsonResponse([testParking]);
    return jsonResponse({
      ...testParking,
      'workingHours': 'Круглосуточно',
      'description': '',
    });
  }
}
