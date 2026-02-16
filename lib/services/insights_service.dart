import 'match_service.dart';
import 'favorite_service.dart';
import 'message_service.dart';

class InsightsService {
  /// Get insights data
  static Future<Map<String, dynamic>> getInsights() async {
    try {
      // Get all matches
      final allMatches = await MatchService.getMatches();
      final acceptedMatches = await MatchService.getAcceptedMatches();
      final incomingMatches = await MatchService.getIncomingMatches();
      
      // Get favorites
      final favorites = await FavoriteService.getFavorites();
      
      // Get inbox (messages)
      final inbox = await MessageService.getInbox();
      
      return {
        'total_swaps': allMatches.length,
        'accepted_swaps': acceptedMatches.length,
        'pending_swaps': incomingMatches.length,
        'favorites_count': favorites.length,
        'messages_count': inbox.length,
        'matches': allMatches,
        'favorites': favorites,
        'messages': inbox,
      };
    } catch (e) {
      throw Exception('Failed to load insights: $e');
    }
  }
}

