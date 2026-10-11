import 'package:latlong2/latlong.dart';

/// In-memory context for a form opened from the administrative map.
class AdminMapRequest {
  const AdminMapRequest({this.point});
  final LatLng? point;
}
