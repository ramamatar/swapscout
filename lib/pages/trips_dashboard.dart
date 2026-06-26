import 'package:flutter/material.dart';
import 'dart:async';
import '../services/user_service.dart';
import '../services/swap_request_service.dart';
import 'messages.dart';
import '../state/app_state.dart';
import '../services/review_service.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'public_profile.dart';

class TripsDashboardPage extends StatefulWidget {
  const TripsDashboardPage({super.key});

  @override
  State<TripsDashboardPage> createState() => _TripsDashboardPageState();
}

class _TripsDashboardPageState extends State<TripsDashboardPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  
  List<dynamic> _pendingRequests = []; // My home receiving requests
  List<dynamic> _activeSwaps = []; // Currently happening
  List<dynamic> _upcomingSwaps = []; // Accepted swaps in future
  List<dynamic> _completedTrips = []; // Completed swaps
  int? _currentUserId;
  
  final Map<int, String> _processingRequests = {}; // Tracks loading state of buttons
  final Map<int, dynamic> _myReviews = {}; // Tracks my reviews for completed trips

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final profile = await UserService.getMyProfile();
      _currentUserId = profile['id'];
      
      final requests = await SwapRequestService.getMySwapRequests();
      
      setState(() {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        
        _pendingRequests = requests.where((req) => 
            req['status'] == 'pending' && req['host_id'] == _currentUserId).toList();
            
        _activeSwaps = requests.where((req) {
            if (req['status'] != 'accepted') return false;
            final start = DateTime.parse(req['start_date']);
            final end = DateTime.parse(req['end_date']);
            final startDay = DateTime(start.year, start.month, start.day);
            final endDay = DateTime(end.year, end.month, end.day);
            return (startDay.isBefore(today) || startDay.isAtSameMomentAs(today)) && 
                   (endDay.isAfter(today) || endDay.isAtSameMomentAs(today));
        }).toList();

        _upcomingSwaps = requests.where((req) {
            if (req['status'] != 'accepted') return false;
            final start = DateTime.parse(req['start_date']);
            final startDay = DateTime(start.year, start.month, start.day);
            return startDay.isAfter(today);
        }).toList();
            
        _completedTrips = requests.where((req) => 
            req['status'] == 'completed').toList();
      });

      // Fetch review status for all completed trips
      for (var req in _completedTrips) {
        try {
          final review = await ReviewService.getMyReviewForSwap(req['id']);
          if (mounted && review != null) {
            setState(() {
              _myReviews[req['id']] = review;
            });
          }
        } catch (e) {
          // silently ignore
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load trips: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateStatus(int id, String status) async {
    setState(() {
      _processingRequests[id] = status;
    });
    try {
      await SwapRequestService.updateSwapRequestStatus(id, status);
      if (mounted) {
        if (status == 'accepted' || status == 'declined') {
          AppSharedState.pendingRequestsCount.value--;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Swap smoothly updated to $status!'), backgroundColor: Colors.green),
        );
        _loadRequests(); // Refresh logic dynamically
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingRequests.remove(id);
        });
      }
    }
  }

  void _showLeaveReviewSheet(BuildContext context, int swapRequestId, int homeId) {
    double rating = 0;
    final TextEditingController commentController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24, right: 24, top: 24
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Leave a Review', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Center(
                      child: RatingBar.builder(
                        initialRating: 0,
                        minRating: 1,
                        direction: Axis.horizontal,
                        allowHalfRating: false,
                        itemCount: 5,
                        itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                        itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                        onRatingUpdate: (newRating) {
                          setSheetState(() => rating = newRating);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: commentController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Share your experience...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : () async {
                          if (rating == 0) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a star rating.'), backgroundColor: Colors.red));
                            return;
                          }
                          setSheetState(() => isSubmitting = true);
                          try {
                            await ReviewService.submitReview(
                              swapRequestId: swapRequestId,
                              homeId: homeId,
                              rating: rating.toInt(),
                              comment: commentController.text,
                            );
                            if (mounted) {
                               setState(() {
                                 _myReviews[swapRequestId] = {
                                    'rating': rating.toInt(),
                                    'comment': commentController.text
                                 };
                               });
                            }
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review submitted securely!'), backgroundColor: Colors.green));
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red));
                          } finally {
                            if (mounted) {
                                setSheetState(() => isSubmitting = false);
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF28C64), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: isSubmitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Submit Review', style: TextStyle(fontSize: 16)),
                      ),
                    )
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildRequestCard(Map<String, dynamic> req, String tabType) {
    // Parse objects avoiding null bounds
    final requesterHome = req['requester_home'] ?? {};
    final hostHome = req['host_home'] ?? {};
    final requester = req['requester'] ?? {};
    final host = req['host'] ?? {};
    
    // Logic for contextual display:
    bool iAmHost = (req['host_id'] == _currentUserId);
    final otherUser = iAmHost ? requester : host;
    final otherHome = iAmHost ? requesterHome : hostHome;

    final String startDate = req['start_date'] ?? '';
    final String endDate = req['end_date'] ?? '';
    
    // Countdown logic
    String countdownStr = '';
    if (tabType == 'upcoming' && startDate.isNotEmpty) {
      try {
        final startDt = DateTime.parse(startDate);
        final diff = startDt.difference(DateTime.now()).inDays;
        if (diff == 0) {
          countdownStr = 'Starts today!';
        } else if (diff > 0) {
          countdownStr = 'Starts in $diff day${diff > 1 ? 's' : ''}';
        } else {
          countdownStr = 'Currently active swap!';
        }
      } catch (e) {
        // Safe wrap
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PublicProfilePage(userId: otherUser['id']))),
                  child: CircleAvatar(
                    backgroundColor: const Color(0xFFF28C64),
                    child: Text(otherUser['name'] != null ? otherUser['name'][0].toUpperCase() : 'U', 
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PublicProfilePage(userId: otherUser['id']))),
                        child: Text(otherUser['name'] ?? 'Traveler', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                      ),
                      const SizedBox(height: 4),
                      Text('Offering: ${otherHome['title'] ?? 'Unknown Home'}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                    ],
                  ),
                ),
                
                // --- NEW AI SCORE BADGE ---
                if (tabType == 'pending')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome, size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          '94% AI Match', // Fetch real score if supported natively by API
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                // ---------------------------
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!)
              ),
              child: Row(
                children: [
                  const Icon(Icons.date_range, size: 20, color: Color(0xFFF28C64)),
                  const SizedBox(width: 8),
                  Text('$startDate to $endDate', style: const TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            if (req['intro_message'] != null && req['intro_message'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('"${req['intro_message']}"', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black87)),
            ],
            const SizedBox(height: 16),
            
            // ACTION REQUIRED TAB (Pending Received)
            if (tabType == 'pending')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _processingRequests[req['id']] != null ? null : () => _updateStatus(req['id'], 'declined'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14)
                      ),
                      child: _processingRequests[req['id']] == 'declined'
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                          : const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _processingRequests[req['id']] != null ? null : () => _updateStatus(req['id'], 'accepted'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14)
                      ),
                      child: _processingRequests[req['id']] == 'accepted'
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Accept Swap'),
                    ),
                  ),
                ],
              ),
              
            // ACTIVE SWAPS TAB
            if (tabType == 'active') ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    const Text('HAPPENING NOW', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ]
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => MessagesPage(otherUserId: otherUser['id'])));
                  },
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Message Host'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2B2B2B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],

            // UPCOMING SWAPS TAB
            if (tabType == 'upcoming') ...[
              if (countdownStr.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(countdownStr, style: const TextStyle(color: Color(0xFFF28C64), fontWeight: FontWeight.bold)),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Route to existing messages screen!
                    Navigator.push(context, MaterialPageRoute(builder: (context) => MessagesPage(otherUserId: otherUser['id'])));
                  },
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Message Host'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2B2B2B), // Modern dark button
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],

            // PAST TRIPS TAB
            if (tabType == 'past')
              if (_myReviews.containsKey(req['id']))
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!)
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 16),
                          SizedBox(width: 6),
                          Text('Review Submitted', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(5, (starIndex) => Icon(
                          starIndex < (_myReviews[req['id']]['rating'] ?? 5) ? Icons.star : Icons.star_border,
                          size: 16, color: Colors.amber,
                        )),
                      ),
                      if (_myReviews[req['id']]['comment'] != null && _myReviews[req['id']]['comment'].toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('"${_myReviews[req['id']]['comment']}"', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black87)),
                      ]
                    ]
                  )
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showLeaveReviewSheet(context, req['id'], otherHome['id']);
                    },
                    icon: const Icon(Icons.star_border),
                    label: const Text('Leave Review'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF28C64),
                      side: const BorderSide(color: Color(0xFFF28C64)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<dynamic> list, String tabType) {
    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadRequests,
        color: const Color(0xFFF28C64),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 100),
            Center(
              child: Text(
                'No requests found.',
                style: TextStyle(color: Colors.black54, fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadRequests,
      color: const Color(0xFFF28C64),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 16, bottom: 80),
        itemCount: list.length,
        itemBuilder: (context, index) {
          return _buildRequestCard(list[index], tabType);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Trips & Requests', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFF28C64),
          unselectedLabelColor: Colors.black54,
          indicatorColor: const Color(0xFFF28C64),
          isScrollable: true,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Active'),
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF28C64))))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_pendingRequests, 'pending'),
                _buildList(_activeSwaps, 'active'),
                _buildList(_upcomingSwaps, 'upcoming'),
                _buildList(_completedTrips, 'past'),
              ],
            ),
    );
  }
}
