import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

const testParking = {
  'id': 7,
  'name': 'Тестовая парковка',
  'address': 'Учебный адрес',
  'latitude': 56.010563,
  'longitude': 92.852572,
  'pricePerHour': 120.5,
  'pricePer30Min': '60.25',
};

class MemoryTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

class FailedTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(Uint8List.fromList([0, 1, 2]));
}
