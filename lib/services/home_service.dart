import 'dart:convert';
import 'api_client.dart';

class HomeService {
  /// Get user's homes
  static Future<List<dynamic>> getMyHomes() async {
    final response = await ApiClient.get('/homes/mine');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load homes: ${response.body}');
    }
  }

  /// Create a new home
  static Future<Map<String, dynamic>> createHome({
    required String title,
    required String description,
    required String country,
    required String city,
    required int capacity,
    required String amenities,
    required String environment,
    required String propertyType,
    required String availableFrom,
    required String availableTo,
  }) async {
    final body = {
      'title': title,
      'description': description,
      'country': country,
      'city': city,
      'capacity': capacity,
      'amenities': amenities,
      'environment': environment,
      'property_type': propertyType,
      'available_from': availableFrom,
      'available_to': availableTo,
    };

    final response = await ApiClient.post('/homes/', body);
    
    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to create home: ${response.body}');
    }
  }

  /// Update a home
  static Future<Map<String, dynamic>> updateHome({
    required int homeId,
    String? title,
    String? description,
    String? country,
    String? city,
    int? capacity,
    String? amenities,
    String? environment,
    String? propertyType,
    String? availableFrom,
    String? availableTo,
    bool? isHidden,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (description != null) body['description'] = description;
    if (country != null) body['country'] = country;
    if (city != null) body['city'] = city;
    if (capacity != null) body['capacity'] = capacity;
    if (amenities != null) body['amenities'] = amenities;
    if (environment != null) body['environment'] = environment;
    if (propertyType != null) body['property_type'] = propertyType;
    if (availableFrom != null) body['available_from'] = availableFrom;
    if (availableTo != null) body['available_to'] = availableTo;
    if (isHidden != null) body['is_hidden'] = isHidden;

    final response = await ApiClient.put('/homes/$homeId', body);
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to update home: ${response.body}');
    }
  }

  /// Delete a home
  static Future<void> deleteHome(int homeId) async {
    final response = await ApiClient.delete('/homes/$homeId');
    
    if (response.statusCode != 204) {
      throw Exception('Failed to delete home: ${response.body}');
    }
  }

  /// Get a specific home by ID
  static Future<Map<String, dynamic>> getHome(int homeId) async {
    final response = await ApiClient.get('/homes/$homeId', includeAuth: false);
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load home: ${response.body}');
    }
  }

  /// Get home owner information
  static Future<Map<String, dynamic>> getHomeOwner(int homeId) async {
    final response = await ApiClient.get('/homes/$homeId/owner', includeAuth: false);
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load owner: ${response.body}');
    }
  }

  /// Search homes
  static Future<List<dynamic>> searchHomes({
    String? country,
    String? city,
    int? minCapacity,
    String? environment,
    String? propertyType,
    String? amenities,
    String? dateFrom,
    String? dateTo,
  }) async {
    final queryParams = <String, String>{};
    if (country != null && country.isNotEmpty) queryParams['country'] = country;
    if (city != null && city.isNotEmpty) queryParams['city'] = city;
    if (minCapacity != null) queryParams['min_capacity'] = minCapacity.toString();
    if (environment != null && environment.isNotEmpty) queryParams['environment'] = environment;
    if (propertyType != null && propertyType.isNotEmpty) queryParams['property_type'] = propertyType;
    if (amenities != null && amenities.isNotEmpty) queryParams['amenities'] = amenities;
    if (dateFrom != null && dateFrom.isNotEmpty) queryParams['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) queryParams['date_to'] = dateTo;

    final response = await ApiClient.get(
      '/homes/search',
      queryParams: queryParams.isNotEmpty ? queryParams : null,
      includeAuth: false,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to search homes: ${response.body}');
    }
  }
}

