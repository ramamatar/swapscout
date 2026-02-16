import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/match_service.dart';
import 'house_detail.dart';
import 'matches_messages.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _isLoading = true;
  List<dynamic> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final notifications = await NotificationService.getNotifications();
      setState(() {
        _notifications = notifications;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load notifications: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'match_request':
        return Icons.swap_horiz;
      case 'match_accepted':
        return Icons.check_circle;
      case 'message':
        return Icons.message;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'match_request':
        return const Color(0xFFF28C64);
      case 'match_accepted':
        return Colors.green;
      case 'message':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return 'Recently';
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Recently';
    }
  }

  Future<void> _handleMatchRequest(int notificationId, int? matchId, bool accept) async {
    if (matchId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Match ID not found')),
        );
      }
      return;
    }

    try {
      if (accept) {
        await MatchService.acceptMatch(matchId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Match accepted! You can now message each other.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await MatchService.rejectMatch(matchId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Match rejected'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
      
      // Mark notification as read
      await NotificationService.markAsRead(notificationId);
      
      _loadNotifications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${accept ? 'accept' : 'reject'} match: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _loadNotifications,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.mail_outline, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MatchesMessagesPage(),
                ),
              );
            },
            tooltip: 'Messages',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF28C64)),
              ),
            )
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You\'re all caught up!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notification = _notifications[index] as Map<String, dynamic>;
                    final type = notification['type'] ?? '';
                    final title = notification['title'] ?? 'Notification';
                    final message = notification['message'] ?? '';
                    final timestamp = notification['created_at'] as String?;
                    final isRead = notification['read'] ?? false;
                    
                    final data = notification['data'] as Map<String, dynamic>?;
                    final matchId = notification['match_id'] as int? ?? data?['match_id'] as int?;
                    final homeId = notification['home_id'] as int? ?? data?['home_id'] as int?;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      color: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isRead ? const Color(0xFFE2E2E2) : const Color(0xFFF28C64),
                          width: isRead ? 1 : 1.5,
                        ),
                      ),
                      child: InkWell(
                        onTap: (type == 'match_request' && homeId != null) 
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => HouseDetailPage(homeId: homeId),
                                  fullscreenDialog: true,
                                ),
                              );
                            }
                          : null,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isRead ? Colors.white : const Color(0xFFFDE5DA).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _getNotificationColor(type).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      _getNotificationIcon(type),
                                      color: _getNotificationColor(type),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          message,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _formatTimestamp(timestamp),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              // Action buttons for match requests
                              if (type == 'match_request')
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Column(
                                    children: [
                                      if (homeId != null)
                                        Padding( // View Details Button
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: OutlinedButton.icon(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => HouseDetailPage(
                                                      homeId: homeId,
                                                    ),
                                                    fullscreenDialog: true,
                                                  ),
                                                );
                                              },
                                              icon: const Icon(Icons.home_outlined, size: 18),
                                              label: const Text('View Home Details'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: const Color(0xFFF28C64),
                                                side: const BorderSide(color: Color(0xFFF28C64)),
                                              ),
                                            ),
                                          ),
                                        ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton(
                                            onPressed: () => _handleMatchRequest(
                                              notification['id'] as int,
                                              matchId, 
                                              false,
                                            ),
                                            child: const Text('Reject', style: TextStyle(color: Colors.red)),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: () => _handleMatchRequest(
                                              notification['id'] as int,
                                              matchId,
                                              true,
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFFF28C64),
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('Accept'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              if (type == 'match_accepted')
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        // Navigate to messages
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const MatchesMessagesPage(),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFF28C64),
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Open Messages'),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

