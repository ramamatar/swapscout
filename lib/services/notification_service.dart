import 'dart:convert';
import 'api_client.dart';

class NotificationService {
  /// Get user notifications
  static Future<List<dynamic>> getNotifications() async {
    final response = await ApiClient.get('/notifications/');
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['notifications'] as List<dynamic>;
    } else {
      throw Exception('Failed to load notifications: ${response.body}');
    }
  }

  /// Mark notification as read
  static Future<void> markAsRead(int notificationId) async {
    await ApiClient.post('/notifications/$notificationId/read', {});
  }
}

