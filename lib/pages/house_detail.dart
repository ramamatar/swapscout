import 'package:flutter/material.dart';
import '../services/home_service.dart';
import '../services/match_service.dart';
import '../services/swap_request_service.dart';
import '../widgets/amenity.dart';
import 'messages.dart';
import '../services/api_client.dart';
import '../services/review_service.dart';

class HouseDetailPage extends StatefulWidget {
  final int homeId;

  const HouseDetailPage({super.key, required this.homeId});

  @override
  State<HouseDetailPage> createState() => _HouseDetailPageState();
}

class _HouseDetailPageState extends State<HouseDetailPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _home;
  Map<String, dynamic>? _owner;
  bool _hasMatchRequest = false;
  String? _matchStatus;
  List<dynamic> _reviews = [];

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
      
      try {
        final reviews = await ReviewService.getHomeReviews(widget.homeId);
        if (mounted) setState(() => _reviews = reviews);
      } catch (e) {
        // Continue silently if reviews fail
      }
      
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

  Future<void> _showSwapRequestSheet(BuildContext context) async {
    final TextEditingController datesController = TextEditingController();
    final TextEditingController introController = TextEditingController();
    bool isSubmitting = false;
    List<dynamic> myHomes = [];
    int? selectedHomeId;
    bool isLoadingHomes = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            
            // Load homes once natively inside the builder bounds
            if (isLoadingHomes && myHomes.isEmpty) {
              HomeService.getMyHomes().then((homes) {
                if (mounted) {
                  setSheetState(() {
                    myHomes = homes;
                    if (myHomes.isNotEmpty) {
                      selectedHomeId = myHomes[0]['id'];
                    }
                    isLoadingHomes = false;
                  });
                }
              }).catchError((e) {
                 setSheetState(() {
                    isLoadingHomes = false;
                 });
              });
            }

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Request Swap',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      if (isLoadingHomes)
                        const Center(child: CircularProgressIndicator())
                      else if (myHomes.isEmpty)
                        const Text('You must physically list a home natively on SwapScout before requesting an exchange!')
                      else ...[
                        DropdownButtonFormField<int>(
                          value: selectedHomeId,
                          decoration: const InputDecoration(
                            labelText: 'Which home are you offering?',
                            border: OutlineInputBorder(),
                          ),
                          items: myHomes.map<DropdownMenuItem<int>>((home) {
                            return DropdownMenuItem<int>(
                              value: home['id'],
                              child: Text(home['title'].length > 30 ? home['title'].substring(0, 30) + '...' : home['title']),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setSheetState(() => selectedHomeId = val);
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: datesController,
                          readOnly: true,
                          onTap: () async {
                            final DateTimeRange? picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                            );
                            if (picked != null) {
                              setSheetState(() {
                                datesController.text = "${picked.start.toString().split(' ')[0]} to ${picked.end.toString().split(' ')[0]}";
                              });
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Proposed Travel Dates',
                            hintText: 'Select your exact availability frame',
                            prefixIcon: const Icon(Icons.calendar_today),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: introController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Message to Host',
                            hintText: "Hi! We'd love to swap homes with you...",
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isSubmitting ? null : () async {
                              if (datesController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select valid swap dates')));
                                return;
                              }
                              final dates = datesController.text.split(' to ');
                              if (dates.length != 2) return;

                              setSheetState(() => isSubmitting = true);
                              try {
                                await SwapRequestService.createSwapRequest(
                                  hostId: _owner!['id'],
                                  requesterHomeId: selectedHomeId!,
                                  hostHomeId: widget.homeId,
                                  startDate: dates[0],
                                  endDate: dates[1],
                                  introMessage: introController.text.trim(),
                                );
                                if (mounted) {
                                  Navigator.pop(context); // close sheet natively cleanly
                                  setState(() {
                                    _hasMatchRequest = true; 
                                    _matchStatus = 'pending';
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Swap Request submitted efficiently!'), backgroundColor: Colors.green),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                                  );
                                }
                                setSheetState(() => isSubmitting = false);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF28C64),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: isSubmitting
                                ? const SizedBox(height:20, width:20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Send Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
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
    final bookings = _home!['bookings'] as List? ?? [];
    
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
            // Image
            if (_home!['images'] != null && (_home!['images'] as List).isNotEmpty)
              Container(
                height: 250,
                width: double.infinity,
                child: Image.network(
                  ApiClient.getFullImageUrl(_home!['images'][0]),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
                    ),
                  ),
                ),
              )
            else
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 20, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        '${_home!['average_rating'] != null && _home!['average_rating'] > 0 ? _home!['average_rating'] : 'New'} (${_home!['total_reviews'] ?? 0} reviews)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // AI Compatibility FutureBuilder
                  FutureBuilder<Map<String, dynamic>>(
                    future: MatchService.getAICompatibility(widget.homeId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade100),
                          ),
                          child: const Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Gemini AI is analyzing your compatibility...',
                                  style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      if (snapshot.hasError || !snapshot.hasData) {
                        return const SizedBox.shrink(); // Hide silently if it fails
                      }

                      final aiData = snapshot.data!;
                      final scoreNum = aiData['compatibility_score'];
                      final score = scoreNum != null ? (scoreNum as num).toDouble() : 0.0;
                      final explanation = aiData['match_explanation'] as String?;
                      
                      if (explanation == null || explanation.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      // Determine color based on score
                      Color badgeColor = Colors.grey;
                      if (score >= 90) {
                        badgeColor = Colors.green;
                      } else if (score >= 70) {
                        badgeColor = Colors.orange;
                      } else {
                        badgeColor = Colors.red;
                      }

                      return InkWell(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => Container(
                              padding: const EdgeInsets.all(24),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Center(
                                    child: Container(
                                      width: 40,
                                      height: 4,
                                      margin: const EdgeInsets.only(bottom: 24),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Icon(Icons.auto_awesome, color: badgeColor, size: 28),
                                      const SizedBox(width: 12),
                                      Text(
                                        '${score.toInt()}% AI Match',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: badgeColor,
                                          fontSize: 24,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    'Gemini Compatibility Analysis',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    explanation,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Colors.black87,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () => Navigator.pop(context),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFF28C64),
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: const Text('Close', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [badgeColor.withOpacity(0.1), Colors.white],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: badgeColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.auto_awesome, color: badgeColor, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${score.toInt()}% AI Match',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: badgeColor,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    'Tap for explanation',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey[600]),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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
                      'General Availability: $availableFrom to $availableTo',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                  if (bookings.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Unavailable Dates:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...bookings.map((b) => Text(
                          '• ${b['start_date']} to ${b['end_date']}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        )),
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
                        onPressed: () => _showSwapRequestSheet(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF28C64),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text(
                          'Request Swap',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  
                  // Reviews Section
                  if (_reviews.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    const Text('Reviews', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _reviews.length,
                      itemBuilder: (context, index) {
                        final rev = _reviews[index];
                        final rating = rev['rating'] ?? 5;
                        final String dateStr = rev['created_at'] ?? '';
                        final formattedDate = dateStr.length > 10 ? dateStr.substring(0, 10) : dateStr;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!)
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: const Color(0xFFF28C64),
                                    child: Text(
                                      (rev['reviewer_name'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(rev['reviewer_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Text(formattedDate, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: List.generate(5, (starIndex) => Icon(
                                      starIndex < rating ? Icons.star : Icons.star_border,
                                      size: 16, color: Colors.amber,
                                    )),
                                  )
                                ],
                              ),
                              if (rev['comment'] != null && rev['comment'].toString().isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(rev['comment'], style: const TextStyle(color: Colors.black87)),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ],

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

