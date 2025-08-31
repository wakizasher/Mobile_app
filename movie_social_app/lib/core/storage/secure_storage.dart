import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage wrapper for JWT tokens.
class SecureTokenStorage {
  static const _keyAccess = 'access_token';
  static const _keyRefresh = 'refresh_token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveTokens({required String access, String? refresh}) async {
    await _storage.write(key: _keyAccess, value: access);
    if (refresh != null) {
      await _storage.write(key: _keyRefresh, value: refresh);
    }
  }

  Future<String?> get accessToken async => _storage.read(key: _keyAccess);
  Future<String?> get refreshToken async => _storage.read(key: _keyRefresh);

  Future<void> clear() async {
    await _storage.delete(key: _keyAccess);
    await _storage.delete(key: _keyRefresh);
  }
}
