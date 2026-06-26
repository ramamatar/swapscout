import 'dart:convert';
import 'api_client.dart';

class MatchService {
  /// Create a match request
  static Future<Map<String, dynamic>> createMatchRequest(int homeId) async {
    final response = await ApiClient.post('/matches/', {'home_id': homeId});
    
    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['detail'] ?? 'Failed to create match request');
  }
}

  /// Get AI Compatibility Score for a specific home
  static Future<Map<String, dynamic>> getAICompatibility(int homeId) async {
    final response = await ApiClient.get('/matches/compatibility/$homeId');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to get compatibility: ${response.body}');
    }
  }

  /// Get AI Compatibility Score using explicit search parameters
  static Future<Map<String, dynamic>> getSearchCompatibility({
    required int homeId,
    int? requestedGuestCount,
    String? checkIn,
    String? checkOut,
    String? amenities,
    String? environment,
    String? propertyType,
  }) async {
    final params = <String, String>{};
    if (requestedGuestCount != null) params['requested_guest_count'] = requestedGuestCount.toString();
    if (checkIn != null && checkIn.isNotEmpty) params['check_in'] = checkIn;
    if (checkOut != null && checkOut.isNotEmpty) params['check_out'] = checkOut;
    if (amenities != null && amenities.isNotEmpty) params['amenities'] = amenities;
    if (environment != null && environment.isNotEmpty) params['environment'] = environment;
    if (propertyType != null && propertyType.isNotEmpty) params['property_type'] = propertyType;

    final queryString = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    final url = '/matches/compatibility/$homeId/search${queryString.isNotEmpty ? '?$queryString' : ''}';

    final response = await ApiClient.get(url);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to get search compatibility: ${response.body}');
    }
  }

  /// Get matches for current user
  static Future<List<dynamic>> getMatches() async {
    final response = await ApiClient.get('/matches/');
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['matches'] as List<dynamic>;
    } else {
      throw Exception('Failed to load matches: ${response.body}');
    }
  }

  /// Accept a match
  static Future<void> acceptMatch(int matchId) async {
    final response = await ApiClient.post('/matches/$matchId/accept', {});
    
    if (response.statusCode != 200) {
      throw Exception('Failed to accept match: ${response.body}');
    }
  }

  /// Reject a match
  static Future<void> rejectMatch(int matchId) async {
    final response = await ApiClient.post('/matches/$matchId/reject', {});
    
    if (response.statusCode != 200) {
      throw Exception('Failed to reject match: ${response.body}');
    }
  }

  /// Get incoming matches
  static Future<List<dynamic>> getIncomingMatches() async {
    final response = await ApiClient.get('/matches/incoming');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load incoming matches: ${response.body}');
    }
  }

  /// Get outgoing matches
  static Future<List<dynamic>> getOutgoingMatches() async {
    final response = await ApiClient.get('/matches/outgoing');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load outgoing matches: ${response.body}');
    }
  }

  /// Get accepted matches
  static Future<List<dynamic>> getAcceptedMatches() async {
    final response = await ApiClient.get('/matches/accepted');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load accepted matches: ${response.body}');
    }
  }
}

