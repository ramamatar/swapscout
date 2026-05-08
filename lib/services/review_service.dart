import 'dart:convert';
import 'api_client.dart';

class ReviewService {
  static Future<Map<String, dynamic>> submitReview({
    required int swapRequestId,
    required int homeId,
    required int rating,
    String? comment,
  }) async {
    final Map<String, dynamic> body = {
      'swap_request_id': swapRequestId,
      'home_id': homeId,
      'rating': rating,
    };
    if (comment != null && comment.trim().isNotEmpty) {
      body['comment'] = comment.trim();
    }

    final response = await ApiClient.post('/reviews/', body);

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final errorMap = jsonDecode(response.body);
      throw Exception(errorMap['detail'] ?? 'Failed to submit review');
    }
  }

  static Future<List<dynamic>> getHomeReviews(int homeId) async {
    final response = await ApiClient.get('/reviews/homes/$homeId');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load reviews');
    }
  }

  static Future<Map<String, dynamic>?> getMyReviewForSwap(int swapRequestId) async {
    final response = await ApiClient.get('/reviews/swap-request/$swapRequestId/my-review');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 404) {
      return null; // Not found, which is fine
    } else {
      throw Exception('Failed to check review status');
    }
  }
}
