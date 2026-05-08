import 'dart:convert';
import 'api_client.dart';

class SwapRequestService {
  /// Create a new swap request mapping directly to the FastAPI schema
  static Future<Map<String, dynamic>> createSwapRequest({
    required int hostId,
    required int requesterHomeId,
    required int hostHomeId,
    required String startDate,
    required String endDate,
    String? introMessage,
  }) async {
    final body = {
      'host_id': hostId,
      'requester_home_id': requesterHomeId,
      'host_home_id': hostHomeId,
      'start_date': startDate,
      'end_date': endDate,
    };
    if (introMessage != null && introMessage.isNotEmpty) {
      body['intro_message'] = introMessage;
    }

    final response = await ApiClient.post('/swap-requests/', body);

    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to send swap request: ${response.body}');
    }
  }

  /// Fetch all swap requests involving the current user natively across dual axes.
  static Future<List<dynamic>> getMySwapRequests() async {
    final response = await ApiClient.get('/swap-requests/me');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load swap requests: ${response.body}');
    }
  }

  /// Strictly updates the state of a swap request checking constraints natively.
  static Future<Map<String, dynamic>> updateSwapRequestStatus(int requestId, String newStatus) async {
    final body = {
      'status': newStatus,
    };
    
    final response = await ApiClient.patch('/swap-requests/$requestId/status', body);
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      // Return clear error strings natively parsed for the UI to display on 400/409 errors
      final errorMap = jsonDecode(response.body);
      throw Exception(errorMap['detail'] ?? 'Failed to update swap request status');
    }
  }
}
