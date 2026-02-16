import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_storage.dart';

class ApiClient {
  static const String baseUrl = 'http://127.0.0.1:8000';

  static Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    
    if (includeAuth) {
      final token = await TokenStorage.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    
    return headers;
  }

  static Future<http.Response> get(
    String endpoint, {
    Map<String, String>? queryParams,
    bool includeAuth = true,
  }) async {
    var uri = Uri.parse('$baseUrl$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }
    
    return http.get(
      uri,
      headers: await _getHeaders(includeAuth: includeAuth),
    );
  }

  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool includeAuth = true,
  }) async {
    return http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _getHeaders(includeAuth: includeAuth),
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> put(
    String endpoint,
    Map<String, dynamic> body, {
    bool includeAuth = true,
  }) async {
    return http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _getHeaders(includeAuth: includeAuth),
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> delete(
    String endpoint, {
    bool includeAuth = true,
  }) async {
    return http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _getHeaders(includeAuth: includeAuth),
    );
  }
}
