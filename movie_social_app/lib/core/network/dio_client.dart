import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

import '../constants/env.dart';
import '../storage/secure_storage.dart';

/// Configured Dio client with JWT header injection and 401 retry.
class ApiClient {
  final Dio dio;
  final SecureTokenStorage tokenStorage;
  final _log = Logger('ApiClient');
  bool _isRefreshing = false;

  ApiClient({required this.tokenStorage})
      : dio = Dio(BaseOptions(
          baseUrl: Env.apiBaseUrl,
          // Prevent indefinite hangs during startup; keep UX responsive.
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        )) {
    debugPrint('ApiClient baseUrl: ${dio.options.baseUrl}');
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) async {
        debugPrint('HTTP REQUEST: ${options.method} ${options.uri}');
        final token = await tokenStorage.accessToken;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onResponse: (Response response, ResponseInterceptorHandler handler) {
        debugPrint('HTTP RESPONSE [${response.statusCode?.toString() ?? 'no status'}]: ${response.requestOptions.uri}');
        handler.next(response);
      },
      onError: (DioException err, ErrorInterceptorHandler handler) async {
        final status = err.response?.statusCode?.toString() ?? 'NO_STATUS';
        final type = err.type.toString();
        String bodySnippet = '';
        try {
          final data = err.response?.data;
          if (data != null) {
            final asString = data is String ? data : data.toString();
            bodySnippet = asString.length > 300 ? '${asString.substring(0, 300)}…' : asString;
          }
        } catch (_) {}
        debugPrint('HTTP ERROR [$status][$type]: ${err.requestOptions.uri} - ${err.message ?? ''}\nBody: $bodySnippet');
        if (err.response?.statusCode == 401) {
          // Attempt refresh if configured, otherwise forward error.
          if (Env.jwtRefreshEndpoint != null && !_isRefreshing) {
            try {
              _isRefreshing = true;
              final refreshed = await _tryRefreshToken();
              _isRefreshing = false;
              if (refreshed) {
                // Retry original request with new token
                final req = err.requestOptions;
                final newToken = await tokenStorage.accessToken;
                if (newToken != null) {
                  req.headers['Authorization'] = 'Bearer $newToken';
                }
                final response = await dio.fetch(req);
                return handler.resolve(response);
              }
            } catch (e, st) {
              _log.warning('Token refresh failed: $e', e, st);
            }
          }
        }
        handler.next(err);
      },
    ));
  }

  Future<bool> _tryRefreshToken() async {
    final refresh = await tokenStorage.refreshToken;
    if (refresh == null || refresh.isEmpty) return false;
    final refreshPath = Env.jwtRefreshEndpoint!; // only called if non-null
    try {
      final resp = await dio.post(refreshPath, data: {'refresh': refresh});
      final newAccess = resp.data['access'] as String?;
      if (newAccess != null) {
        await tokenStorage.saveTokens(access: newAccess);
        return true;
      }
    } catch (_) {}
    return false;
  }
}
