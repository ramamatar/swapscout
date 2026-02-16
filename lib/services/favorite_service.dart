import 'dart:convert';
import 'api_client.dart';

class FavoriteService {
  /// Add a home to favorites
  static Future<Map<String, dynamic>> addFavorite(int homeId) async {
    final response = await ApiClient.post('/favorites/', {'home_id': homeId});
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to add favorite: ${response.body}');
    }
  }

  /// Remove a home from favorites
  static Future<void> removeFavorite(int homeId) async {
    final response = await ApiClient.delete('/favorites/$homeId');
    
    if (response.statusCode != 204) {
      throw Exception('Failed to remove favorite: ${response.body}');
    }
  }

  /// Get user's favorites
  static Future<List<dynamic>> getFavorites() async {
    final response = await ApiClient.get('/favorites/');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load favorites: ${response.body}');
    }
  }
}

