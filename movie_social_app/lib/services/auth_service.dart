import 'package:dio/dio.dart';

import '../core/constants/endpoints.dart';
import '../core/network/dio_client.dart';
import '../core/storage/secure_storage.dart';
import '../models/user.dart';

class AuthService {
  final ApiClient client;
  final SecureTokenStorage storage;

  AuthService({required this.client, required this.storage});

  Future<AppUser> me() async {
    final res = await client.dio.get(Endpoints.me);
    return AppUser.fromJson(res.data as Map<String, dynamic>);
  }

  Future<AppUser> login(String username, String password) async {
    // SimpleJWT returns only access/refresh. Persist them and then fetch the user via /auth/me/.
    final res = await client.dio.post(Endpoints.login, data: {
      'username': username,
      'password': password,
    });
    final data = res.data as Map<String, dynamic>;
    final access = data['access'] as String?;
    final refresh = data['refresh'] as String?;
    if (access == null || access.isEmpty) {
      throw DioException(requestOptions: RequestOptions(path: Endpoints.login), error: 'Missing access token');
    }
    await storage.saveTokens(access: access, refresh: refresh);
    // With token stored, /auth/me/ will include Authorization header via interceptor.
    return await me();
  }

  Future<AppUser> register({required String username, required String email, required String password}) async {
    // Backend returns created user only. Afterwards, login to obtain tokens and current user data consistently.
    await client.dio.post(Endpoints.register, data: {
      'username': username,
      'email': email,
      'password': password,
    });
    // Perform login to get tokens and user profile
    return await login(username, password);
  }

  Future<void> logout() async {
    await storage.clear();
  }
}
