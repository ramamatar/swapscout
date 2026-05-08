import 'package:flutter/material.dart';

// ignore: unused_import
import 'dreamtrip.dart';
import 'profilehome.dart';
import 'manual_search.dart';
import 'insights.dart';
import 'trips_dashboard.dart';
import '../services/notification_service.dart';
import '../services/websocket_service.dart';
import '../state/app_state.dart';
import 'dart:async';

class MainNavigationPage extends StatefulWidget {
  final int initialIndex;
  
  const MainNavigationPage({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  late int _currentIndex;
  bool _hasUnreadNotifications = false;
  late StreamSubscription _wsSubscription;
  
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _checkNotifications();
    
    _initWebSockets();
  }

  void _initWebSockets() {
    WebSocketService().init();
    _wsSubscription = WebSocketService().messageStream.listen(_onWebSocketMessage);
  }

  void _onWebSocketMessage(Map<String, dynamic> data) {
    if (data['type'] == 'new_request') {
      if (mounted) {
        AppSharedState.pendingRequestsCount.value++;
        setState(() {
          _hasUnreadNotifications = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data['message'] ?? 'You have a new swap request!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFF28C64),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.only(bottom: 20, left: 10, right: 10),
            action: SnackBarAction(
              label: 'REVIEW',
              textColor: Colors.white,
              onPressed: () {
                setState(() {
                  _currentIndex = 2; // Jump to Trips Tab!
                });
              },
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _wsSubscription.cancel();
    super.dispose();
  }

  Future<void> _checkNotifications() async {
    try {
      final notifications = await NotificationService.getNotifications();
      if (mounted) {
        setState(() {
          _hasUnreadNotifications = notifications.any((n) => n['read'] == false);
        });
      }
    } catch (e) {
      // Ignore errors for badge check
    }
  }

  final List<Widget> _pages = [
    const DreamTripPage(), 
    const ManualSearchPage(), // Search tab
    const TripsDashboardPage(), // Trips tab
    const ProfileHomeListingPage(), // Profile tab
    const InsightsPage(), // Insights tab
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        selectedItemColor: const Color(0xFFF28C64),
        unselectedItemColor: Colors.black45,
        elevation: 8,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: 'Discover',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.airplanemode_active),
                if (_hasUnreadNotifications)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 8,
                        minHeight: 8,
                      ),
                    ),
                  ),
              ],
            ),
            activeIcon: Stack(
              children: [
                const Icon(Icons.airplanemode_active),
                if (_hasUnreadNotifications)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 8,
                        minHeight: 8,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Trips',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.insights_outlined),
            activeIcon: Icon(Icons.insights),
            label: 'Insights',
          ),
        ],
      ),
    );
  }
}

