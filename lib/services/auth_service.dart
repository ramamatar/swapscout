import 'dart:convert';
import 'api_client.dart';
import 'token_storage.dart';

class AuthService {
  /// REGISTER
  static Future<void> register({
    required String email,
    required String password,
    String? name,
  }) async {
    final body = {
      'email': email,
      'password': password,
      if (name != null && name.isNotEmpty) 'name': name,
    };

    final response = await ApiClient.post(
      '/auth/register',
      body,
      includeAuth: false,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data['access_token'] != null) {
        await TokenStorage.saveToken(data['access_token']);
      }
      return;
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['detail'] ?? 'Registration failed');
    }
  }

  /// LOGIN
  static Future<void> login({
    required String email,
    required String password,
  }) async {
    final response = await ApiClient.post(
      '/auth/login',
      {
        'email': email,
        'password': password,
      },
      includeAuth: false,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await TokenStorage.saveToken(data['access_token']);
      return;
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['detail'] ?? 'Login failed');
    }
  }

  /// LOGOUT
  static Future<void> logout() async {
    await TokenStorage.deleteToken();
  }
}
