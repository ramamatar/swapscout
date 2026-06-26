import 'package:flutter/material.dart';
import '../services/insights_service.dart';
import '../state/app_state.dart';
import 'trips_dashboard.dart';

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  bool _isLoading = true;
  Map<String, dynamic> _insights = {};
  String _aiTip = 'Loading your personalized tip...';

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final insights = await InsightsService.getInsights();
      final tip = 'Keep your calendar updated to receive more relevant swap matches!';
      
      setState(() {
        _insights = insights;
        _aiTip = tip;
        AppSharedState.pendingRequestsCount.value = insights['pending_requests'] ?? 0;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load insights: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(elevation: 0, backgroundColor: Colors.white, centerTitle: true, title: const Text('Insights', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 18))),
        body: const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF28C64)))),
      );
    }

    final totalSwaps = _insights['total_swaps'] ?? 0;
    final favoritesCount = _insights['favorites_count'] ?? 0;
    final matchSuccessRate = _insights['match_success_rate'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text('Insights', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 18)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        color: const Color(0xFFF28C64),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overview Stats Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF28C64), Color(0xFFFF6B9D)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      const Text('Your Swap Activity', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(totalSwaps.toString(), 'Total Swaps', Icons.swap_horiz),
                          ValueListenableBuilder<int>(
                            valueListenable: AppSharedState.pendingRequestsCount,
                            builder: (context, value, child) {
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const TripsDashboardPage()));
                                },
                                child: _buildStatItem(value.toString(), 'Pending', Icons.pending),
                              );
                            },
                          ),
                          _buildStatItem('$matchSuccessRate%', 'Success', Icons.check_circle),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Quick Stats
                const Text('Quick Stats', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black87)),
                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMetricRow('Favorites', favoritesCount.toString(), Icons.favorite, Colors.pink),
                      const Divider(height: 32),
                      InkWell(
                        onTap: () {
                          // Could route to messages here if desired
                        },
                        child: _buildMetricRow('Messages', 'View Inbox', Icons.message, Colors.blue),
                      ),
                      const Divider(height: 32),
                      _buildMetricRow('Match Success Rate', '$matchSuccessRate%', Icons.trending_up, const Color(0xFFF28C64)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Dynamic AI Tips Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.orange.shade200)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: Color(0xFFF28C64), size: 24),
                          const SizedBox(width: 8),
                          const Text('AI Daily Tip', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(_aiTip, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  Widget _buildMetricRow(String label, String value, IconData icon, Color iconColor) {
    return Row(
      children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: iconColor, size: 20)),
        const SizedBox(width: 16),
        Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }
}
