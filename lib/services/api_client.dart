import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'token_storage.dart';
import '../utils/global_messenger.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

class ApiClient {
  static String get baseUrl {
    if (kIsWeb) return 'http://127.0.0.1:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
  }

  static String getFullImageUrl(String? path) {
    if (path == null || path.isEmpty) return 'https://placehold.co/600x400?text=No+Image';
    if (path.startsWith('http')) return path;
    return '\$baseUrl\$path';
  }

  static Future<Map<String, String>> getHeaders({bool includeAuth = true}) async {
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

  static Future<http.Response> _handleRequest(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(const Duration(seconds: 45));
      return response;
    } on SocketException {
      GlobalMessenger.showError("No internet connection.");
      rethrow;
    } on TimeoutException {
      GlobalMessenger.showError("Connection timed out.");
      rethrow;
    } catch (e) {
      GlobalMessenger.showError("An unexpected network error occurred.");
      rethrow;
    }
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
    
    return _handleRequest(() async => http.get(
      uri,
      headers: await getHeaders(includeAuth: includeAuth),
    ));
  }

  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool includeAuth = true,
  }) async {
    return _handleRequest(() async => http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: await getHeaders(includeAuth: includeAuth),
      body: jsonEncode(body),
    ));
  }

  static Future<http.Response> put(
    String endpoint,
    Map<String, dynamic> body, {
    bool includeAuth = true,
  }) async {
    return _handleRequest(() async => http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: await getHeaders(includeAuth: includeAuth),
      body: jsonEncode(body),
    ));
  }

  static Future<http.Response> patch(
    String endpoint,
    Map<String, dynamic> body, {
    bool includeAuth = true,
  }) async {
    return _handleRequest(() async => http.patch(
      Uri.parse('$baseUrl$endpoint'),
      headers: await getHeaders(includeAuth: includeAuth),
      body: jsonEncode(body),
    ));
  }

  static Future<http.Response> delete(
    String endpoint, {
    bool includeAuth = true,
  }) async {
    return _handleRequest(() async => http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: await getHeaders(includeAuth: includeAuth),
    ));
  }
}
