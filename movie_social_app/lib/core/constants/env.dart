import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized environment configuration loaded from `.env`.
///
/// Required keys in `.env` (already added to pubspec assets):
/// - API_BASE_URL (e.g., http://localhost:8000/api)
/// - OMDB_API_KEY
/// Optional:
/// - JWT_REFRESH_ENDPOINT (if backend supports refresh; otherwise refresh is disabled)
/// - N8N_WEBHOOK_URL (absolute URL to a single webhook endpoint; events include an `event` field)
class Env {
  static String get apiBaseUrl {
    var v = dotenv.env['API_BASE_URL']?.trim() ?? 'http://localhost:8000/api';
    // Ensure trailing slash for correct relative URL resolution in Dio
    if (!v.endsWith('/')) v = '$v/';
    return v;
  }
  static String get omdbApiKey => dotenv.env['OMDB_API_KEY']?.trim() ?? '';
  static String? get jwtRefreshEndpoint => dotenv.env['JWT_REFRESH_ENDPOINT']?.trim();
  static String? get n8nWebhookUrl => dotenv.env['N8N_WEBHOOK_URL']?.trim();
}
