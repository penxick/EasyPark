class ApiConfig {
  ApiConfig({
    required String baseUrl,
    this.timeout = const Duration(seconds: 15),
  }) : baseUri = _parseBaseUrl(baseUrl) {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', 'Must be positive');
    }
  }

  factory ApiConfig.fromEnvironment() => ApiConfig(
    baseUrl: const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: '',
    ),
  );

  final Uri baseUri;
  final Duration timeout;

  static Uri _parseBaseUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError('API_BASE_URL must be an absolute HTTP(S) URL');
    }
    return uri.replace(
      path: uri.path.endsWith('/') ? uri.path : '${uri.path}/',
    );
  }
}
