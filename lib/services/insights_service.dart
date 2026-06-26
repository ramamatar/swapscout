import 'dart:convert';
import 'api_client.dart';

class InsightsService {
  /// Get aggregated insights data from backend
  static Future<Map<String, dynamic>> getInsights() async {
    try {
      final response = await ApiClient.get('/users/me/insights');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to load insights: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to load insights: $e');
    }
  }
}
