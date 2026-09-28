/// Read-only token contract used by the shared API client.
abstract interface class TokenProvider {
  Future<String?> readToken();
}
