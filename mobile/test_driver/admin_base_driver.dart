import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    if (!RegExp(r'^a(?:[789]|13)-[a-z-]+$').hasMatch(name) || bytes.isEmpty) {
      return false;
    }
    final directory = Directory('../.artifacts/admin-${name.split('-').first}');
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png').writeAsBytes(bytes);
    return true;
  },
);
