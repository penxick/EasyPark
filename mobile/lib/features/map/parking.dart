import '../../core/api/api_exception.dart';

class Parking {
  const Parking({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.pricePerHour,
    this.pricePer30MinKopecks = 0,
  });
  final int id;
  final int pricePer30MinKopecks;
  String get pricePer30Min =>
      '${pricePer30MinKopecks ~/ 100}.${(pricePer30MinKopecks % 100).toString().padLeft(2, '0')}';
  final String name, address;
  final double latitude, longitude, pricePerHour;

  factory Parking.fromJson(Object? value) {
    const invalid = ApiException(ApiErrorKind.invalidResponse);
    if (value is! Map<String, dynamic>) throw invalid;
    final id = value['id'], name = value['name'], address = value['address'];
    final tariff = (value['pricePer30Min'] ?? '0').toString();
    if (!RegExp(r'^(0|[1-9]\d{0,7})(\.\d{1,2})?$').hasMatch(tariff)) {
      throw invalid;
    }
    final parts = tariff.split('.');
    final cents =
        int.parse(parts.first) * 100 +
        int.parse(parts.length == 1 ? '0' : parts.last.padRight(2, '0'));
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
      pricePer30MinKopecks: cents,
    );
  }

  int get hourlyKopecks =>
      int.parse(pricePerHour.toStringAsFixed(2).replaceAll('.', ''));
  String get formattedPrice =>
      '${pricePerHour.toStringAsFixed(2).replaceAll('.', ',')} ₽/час';
}
