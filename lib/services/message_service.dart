import 'dart:convert';
import 'api_client.dart';

class MessageService {
  /// Send a message
  static Future<Map<String, dynamic>> sendMessage({
    required int receiverId,
    required String content,
  }) async {
    final response = await ApiClient.post('/messages/', {
      'receiver_id': receiverId,
      'content': content,
    });
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to send message: ${response.body}');
    }
  }

  /// Get conversation with a user
  static Future<List<dynamic>> getConversation(int userId) async {
    final response = await ApiClient.get('/messages/conversation/$userId');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load conversation: ${response.body}');
    }
  }

  /// Get inbox (all conversations)
  static Future<List<dynamic>> getInbox() async {
    final response = await ApiClient.get('/messages/inbox');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load inbox: ${response.body}');
    }
  }
}

