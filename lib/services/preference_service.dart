import 'dart:convert';
import 'api_client.dart';

class PreferenceService {
  static Future<Map<String, dynamic>?> getMyPreferences() async {
    final response = await ApiClient.get('/preferences/me');
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data;
    } else if (response.statusCode == 404) {
      return null; // No preferences set yet
    } else {
      throw Exception('Failed to load preferences: ${response.body}');
    }
  }

  /// Create or update trip preferences
  static Future<Map<String, dynamic>> setMyPreferences({
    String? preferredCountry,
    String? preferredCity,
    String? startDate,
    String? endDate,
    int? guests,
    List<String>? lifestyleTags,
  }) async {
    final body = <String, dynamic>{};
    // Defaults for required backend fields
    body['preferred_country'] = (preferredCountry != null && preferredCountry.isNotEmpty) 
        ? preferredCountry 
        : 'Anywhere';
        
    body['preferred_city'] = (preferredCity != null && preferredCity.isNotEmpty) 
        ? preferredCity 
        : 'Anywhere';

    // Default dates if not provided (Next 30 days)
    if (startDate != null && startDate.isNotEmpty) {
      body['start_date'] = startDate;
    } else {
      final now = DateTime.now();
      body['start_date'] = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    }

    if (endDate != null && endDate.isNotEmpty) {
      body['end_date'] = endDate;
    } else {
      final future = DateTime.now().add(const Duration(days: 30));
      body['end_date'] = "${future.year}-${future.month.toString().padLeft(2, '0')}-${future.day.toString().padLeft(2, '0')}";
    }

    if (guests != null) {
      body['guests'] = guests;
    } else {
      body['guests'] = 1; // Default to 1 guest
    }

    if (lifestyleTags != null && lifestyleTags.isNotEmpty) {
      // Send as array/list, not comma-separated string
      body['lifestyle_tags'] = lifestyleTags;
    } else {
        body['lifestyle_tags'] = [];
    }

    final response = await ApiClient.post('/preferences/me', body);
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to save preferences: ${response.body}');
    }
  }
}

