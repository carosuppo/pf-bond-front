import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStorageService {
  static const String _sessionTokenKey = 'session_token';
  static const String _expiresAtKey = 'session_expires_at';

  final FlutterSecureStorage _storage;

  SessionStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveSession({
    required String sessionToken,
    required DateTime expiresAt,
  }) async {
    await Future.wait([
      _storage.write(key: _sessionTokenKey, value: sessionToken),
      _storage.write(key: _expiresAtKey, value: expiresAt.toIso8601String()),
    ]);
  }

  Future<String?> getSessionToken() {
    return _storage.read(key: _sessionTokenKey);
  }

  Future<DateTime?> getSessionExpiration() async {
    final value = await _storage.read(key: _expiresAtKey);

    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value);
  }

  Future<bool> hasSession() async {
    final token = await getSessionToken();

    return token != null && token.isNotEmpty;
  }

  Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: _sessionTokenKey),
      _storage.delete(key: _expiresAtKey),
    ]);
  }

  Future<bool> hasValidSession() async {
    final token = await getSessionToken();
    final expiration = await getSessionExpiration();

    if (token == null || token.isEmpty) {
      return false;
    }

    if (expiration == null) {
      return false;
    }

    return expiration.isAfter(DateTime.now().toUtc());
  }
}
