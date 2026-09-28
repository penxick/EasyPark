import '../../core/api/api_exception.dart';

class Parking {
  const Parking({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.pricePerHour,
  });
  final int id;
  final String name, address;
  final double latitude, longitude, pricePerHour;

  factory Parking.fromJson(Object? value) {
    const invalid = ApiException(ApiErrorKind.invalidResponse);
    if (value is! Map<String, dynamic>) throw invalid;
    final id = value['id'], name = value['name'], address = value['address'];
    final lat = value['latitude'],
        lng = value['longitude'],
        price = value['pricePerHour'];
    if (id is! int ||
        id <= 0 ||
        id > 2147483647 ||
        name is! String ||
        name.trim().isEmpty ||
        address is! String ||
        address.trim().isEmpty ||
        lat is! num ||
        !lat.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lng is! num ||
        !lng.isFinite ||
        lng < -180 ||
        lng > 180 ||
        price is! num ||
        !price.isFinite ||
        price < 0 ||
        price > 99999999.99) {
      throw invalid;
    }
    return Parking(
      id: id,
      name: name,
      address: address,
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
      pricePerHour: price.toDouble(),
    );
  }

  String get formattedPrice {
    final text = pricePerHour.toStringAsFixed(2);
    return '${text.endsWith('.00') ? text.substring(0, text.length - 3) : text.replaceAll('.', ',')} ₽ / час';
  }
}
