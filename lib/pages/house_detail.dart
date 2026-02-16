import 'package:flutter/material.dart';
import '../services/home_service.dart';
import '../services/match_service.dart';
import '../widgets/amenity.dart';
import 'messages.dart';

class HouseDetailPage extends StatefulWidget {
  final int homeId;

  const HouseDetailPage({super.key, required this.homeId});

  @override
  State<HouseDetailPage> createState() => _HouseDetailPageState();
}

class _HouseDetailPageState extends State<HouseDetailPage> {
  bool _isLoading = true;
  bool _isRequestingMatch = false;
  Map<String, dynamic>? _home;
  Map<String, dynamic>? _owner;
  bool _hasMatchRequest = false;
  String? _matchStatus;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final home = await HomeService.getHome(widget.homeId);
      final owner = await HomeService.getHomeOwner(widget.homeId);
      
      setState(() {
        _home = home;
        _owner = owner;
      });
      
      // Check if match request exists (simplified - in real app, check match status)
      // This would require additional API endpoint to check match status between users
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load home details: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _requestMatch() async {
    setState(() => _isRequestingMatch = true);
    try {
      await MatchService.createMatchRequest(widget.homeId);
      if (mounted) {
        setState(() {
          _hasMatchRequest = true;
          _matchStatus = 'pending';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Match request sent! The owner will be notified.'),
            backgroundColor: Color(0xFFF28C64),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRequestingMatch = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _home == null || _owner == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF28C64)),
          ),
        ),
      );
    }

    final title = _home!['title'] ?? 'Home';
    final description = _home!['description'] ?? '';
    final city = _home!['city'] ?? '';
    final country = _home!['country'] ?? '';
    final location = country.isNotEmpty ? '$city, $country' : city;
    final capacity = _home!['capacity'] ?? 0;
    final amenitiesStr = _home!['amenities'] as String? ?? '';
    final amenities = amenitiesStr.isNotEmpty
        ? amenitiesStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
        : <String>[];
    final environment = _home!['environment'] as String? ?? '';
    final propertyType = _home!['property_type'] as String? ?? '';
    final availableFrom = _home!['available_from'] ?? '';
    final availableTo = _home!['available_to'] ?? '';
    
    final ownerName = _owner!['name'] ?? 'Unknown';
    final ownerCity = _owner!['city'] ?? '';
    final ownerCountry = _owner!['country'] ?? '';
    final ownerLocation = ownerCountry.isNotEmpty && ownerCity.isNotEmpty
        ? '$ownerCity, $ownerCountry'
        : ownerCity.isNotEmpty ? ownerCity : ownerCountry;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Home Details',
          style: TextStyle(color: Colors.black87),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder
            Container(
              height: 250,
              width: double.infinity,
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.home, size: 64, color: Colors.grey),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 20, color: Color(0xFFF28C64)),
                      const SizedBox(width: 4),
                      Text(
                        location,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Property Info
                  if (environment.isNotEmpty || propertyType.isNotEmpty) ...[
                    Row(
                      children: [
                        if (propertyType.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDE5DA),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              propertyType,
                              style: const TextStyle(
                                color: Color(0xFFF28C64),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (propertyType.isNotEmpty && environment.isNotEmpty)
                          const SizedBox(width: 8),
                        if (environment.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              environment,
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Description
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Key Details
                  const Text(
                    'Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildDetailChip(Icons.people_outline, '$capacity guests'),
                      const SizedBox(width: 12),
                      _buildDetailChip(Icons.calendar_today, 'Available'),
                    ],
                  ),
                  if (availableFrom.isNotEmpty && availableTo.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '$availableFrom to $availableTo',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Amenities
                  if (amenities.isNotEmpty) ...[
                    const Text(
                      'Amenities',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: amenities
                          .map((amenity) => AmenityChip(label: amenity))
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Owner Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E2E2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Owner',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFFF28C64),
                              child: Text(
                                ownerName.isNotEmpty ? ownerName[0].toUpperCase() : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ownerName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  if (ownerLocation.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      ownerLocation,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  if (_matchStatus == 'accepted')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Navigate to messages with owner
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MessagesPage(otherUserId: _owner!['id'] as int),
                            ),
                          );
                        },
                        icon: const Icon(Icons.message),
                        label: const Text('Message Owner'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF28C64),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    )
                  else if (_hasMatchRequest || _matchStatus == 'pending')
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: const Text(
                        'Match request pending',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isRequestingMatch ? null : _requestMatch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF28C64),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: _isRequestingMatch
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Request Match',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

