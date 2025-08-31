import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../core/network/dio_client.dart';
import '../core/storage/secure_storage.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final SecureTokenStorage _storage;
  final ApiClient _client;
  late final AuthService _authService;

  AuthStatus status = AuthStatus.unknown;
  AppUser? currentUser;
  String? lastError;

  AuthProvider(this._storage, this._client) {
    _authService = AuthService(client: _client, storage: _storage);
  }

  Future<void> bootstrap() async {
    try {
      debugPrint('Auth bootstrap: reading access token');
      // Avoid indefinite wait if secure storage has issues on desktop.
      final token = await _storage.accessToken
          .timeout(const Duration(seconds: 2), onTimeout: () => null);
      debugPrint('Auth bootstrap: token present? ${token != null && token.isNotEmpty}');
      if (token == null || token.isEmpty) {
        debugPrint('Auth bootstrap: no token, skipping /auth/me/');
        status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }
      try {
        // Fetch current user with a short timeout so the app doesn't hang on loading.
        debugPrint('Auth bootstrap: calling GET /auth/me/');
        currentUser = await _authService
            .me()
            .timeout(const Duration(seconds: 6));
        debugPrint('Auth bootstrap: /auth/me success');
        status = AuthStatus.authenticated;
      } catch (e) {
        debugPrint('Auth bootstrap: /auth/me failed: ${e.toString()}');
        if (e is DioException && e.response?.statusCode == 401) {
          debugPrint('Auth bootstrap: received 401, clearing tokens.');
          await _authService.logout();
        }
        status = AuthStatus.unauthenticated;
      }
      notifyListeners();
    } catch (e) {
      // Any unexpected exception should not block the app from showing the login screen.
      debugPrint('Auth bootstrap: unexpected error: ${e.toString()}');
      status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    try {
      currentUser = await _authService.login(username, password);
      status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> register(String username, String email, String password) async {
    try {
      lastError = null;
      currentUser = await _authService.register(username: username, email: email, password: password);
      status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      if (e is DioException) {
        lastError = _parseDioError(e);
      } else {
        lastError = e.toString();
      }
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    currentUser = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Debug helper to fully clear auth tokens and reset state.
  Future<void> debugClearAuth() async {
    debugPrint('Debug: clearing all auth tokens and resetting auth state');
    await _authService.logout();
    currentUser = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  String _parseDioError(DioException e) {
    // Prefer backend-provided validation messages
    final data = e.response?.data;
    if (data is Map) {
      // DRF error shape: {field: ["msg", ...], non_field_errors: [..]}
      final buf = StringBuffer();
      data.forEach((key, value) {
        if (value is List && value.isNotEmpty) {
          buf.writeln('$key: ${value.join(', ')}');
        } else if (value != null) {
          buf.writeln('$key: $value');
        }
      });
      final s = buf.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return e.message ?? 'Request failed';
  }
}
