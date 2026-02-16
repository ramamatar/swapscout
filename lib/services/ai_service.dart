
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

class AiService {
  static Future<List<Map<String, dynamic>>> getDestinationSuggestion(
      String mood, Set<String> tags, {String? homeLocation, String? dates}) async {
    try {
      final body = {
        'prompt': mood,
        'tags': tags.toList(),
      };
      
      if (homeLocation != null) body['home_location'] = homeLocation;
      if (dates != null) body['dates'] = dates;

      final response = await ApiClient.post(
        '/ai/suggest-destination',
        body,
        includeAuth: true,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['suggestions'] != null) {
          return List<Map<String, dynamic>>.from(data['suggestions']);
        }
      } else {
        if (kDebugMode) {
          print('AI Service Error: ${response.statusCode} - ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('AI Service Exception: $e');
      }
    }
    return [];
  }
}
