import 'dart:convert';
import 'api_client.dart';

class UserService {
  static Future<Map<String, dynamic>> getMyProfile() async {
    final response = await ApiClient.get('/users/me');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load profile: ${response.body}');
    }
  }

  /// Update current user profile
  static Future<Map<String, dynamic>> updateMyProfile({
    String? name,
    String? country,
    String? city,
    String? lifestyleTags,
    String? bio,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (country != null) body['country'] = country;
    if (city != null) body['city'] = city;
    if (lifestyleTags != null) body['lifestyle_tags'] = lifestyleTags;
    if (bio != null) body['bio'] = bio;

    final response = await ApiClient.put('/users/me', body);
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to update profile: ${response.body}');
    }
  }

  /// Get Public Profile
  static Future<Map<String, dynamic>> getPublicProfile(int userId) async {
    final response = await ApiClient.get('/users/$userId/public');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load public profile: ${response.body}');
    }
  }
}

