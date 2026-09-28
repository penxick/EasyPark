import 'dart:io';

import 'package:easypark/core/api/api_client.dart';
import 'package:easypark/core/api/api_exception.dart';
import 'package:easypark/core/constants/api_config.dart';

// Development check only: health is deliberately outside the business /api prefix.
Future<void> main(List<String> arguments) async {
  final api = ApiClient(
    config: ApiConfig(
      baseUrl: arguments.isEmpty ? 'http://127.0.0.1:3000/' : arguments.single,
    ),
  );
  try {
    final health = await api.get('health');
    if (health is! Map ||
        health['status'] != 'ok' ||
        health['service'] != 'easypark-backend') {
      throw StateError('Unexpected health response');
    }
    try {
      await api.get('api/stage-2-missing-route');
      throw StateError('Expected an HTTP 404 error');
    } on ApiException catch (error) {
      if (error.kind != ApiErrorKind.notFound || error.statusCode != 404) {
        rethrow;
      }
    }
    stdout.writeln('ApiClient: real backend health OK; HTTP 404 handling OK.');
  } finally {
    api.close();
  }
}
