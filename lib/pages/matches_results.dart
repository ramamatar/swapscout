import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../widgets/amenity.dart';
import '../services/match_service.dart';
import '../services/favorite_service.dart';
import '../services/home_service.dart';
import 'house_detail.dart';

class MatchesResultsPage extends StatefulWidget {
  final List<Map<String, dynamic>>? aiSuggestions;
  final String? userDates;
  
  const MatchesResultsPage({
    super.key,
    this.aiSuggestions,
    this.userDates,
  });

  @override
  State<MatchesResultsPage> createState() => _MatchesResultsPageState();
}

class _MatchesResultsPageState extends State<MatchesResultsPage> {
  String _sortBy = 'Match Score';
  bool _isLoading = true;
  bool _showMap = false;
  List<dynamic> _matches = [];
  final Set<int> _favoriteHomeIds = {};
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _loadMatches();
    _loadFavorites();
  }

  Future<void> _loadMatches() async {
    setState(() => _isLoading = true);
    try {
      final matches = await MatchService.getMatches();
      
      // Load home details for each match
      final enrichedMatches = <Map<String, dynamic>>[];
      for (var match in matches) {
        try {
          final homeId = match['home_id'] as int;
          final homeData = await HomeService.getHome(homeId);
          enrichedMatches.add({
            ...match as Map<String, dynamic>,
            ...homeData,
          });
        } catch (e) {
          // If home fetch fails, use match data only
          enrichedMatches.add(match as Map<String, dynamic>);
        }
      }

      // Filter matches based on AI suggestions and dates
      var filteredMatches = List<Map<String, dynamic>>.from(enrichedMatches);

      if (widget.aiSuggestions != null && widget.aiSuggestions!.isNotEmpty) {
        final suggestedCities = widget.aiSuggestions!
            .map((s) => s['city'].toString().toLowerCase())
            .toSet();
        
        if (suggestedCities.isNotEmpty) {
          filteredMatches = filteredMatches.where((m) {
            final city = m['city']?.toString().toLowerCase();
            return city != null && suggestedCities.contains(city);
          }).toList();
        }
      }

      // TODO: Implement date filtering if needed based on widget.userDates
      
      setState(() {
        _matches = filteredMatches;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load matches: ${e.toString()}'),
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

  Future<void> _loadFavorites() async {
    try {
      final favorites = await FavoriteService.getFavorites();
      setState(() {
        _favoriteHomeIds.clear();
        for (var fav in favorites) {
          _favoriteHomeIds.add(fav['home_id'] as int);
        }
      });
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _toggleFavorite(int homeId) async {
    try {
      if (_favoriteHomeIds.contains(homeId)) {
        await FavoriteService.removeFavorite(homeId);
        setState(() => _favoriteHomeIds.remove(homeId));
      } else {
        await FavoriteService.addFavorite(homeId);
        setState(() => _favoriteHomeIds.add(homeId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update favorite: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _calculateBounds() {
    if (_mapController == null || _matches.isEmpty) return;

    // Filter matches that strictly have valid latitude and longitude mapped
    final validMatches = _matches.where((m) => m['latitude'] != null && m['longitude'] != null).toList();
    if (validMatches.isEmpty) return;

    double minLat = validMatches[0]['latitude'];
    double minLng = validMatches[0]['longitude'];
    double maxLat = minLat;
    double maxLng = minLng;

    for (var match in validMatches) {
      final lat = match['latitude'] as double;
      final lng = match['longitude'] as double;

      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    // Padding ensures properties don't stick to the absolute edges
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50.0));
  }

  Set<Marker> _buildMapMarkers() {
    final markers = <Marker>{};

    for (var i = 0; i < _matches.length; i++) {
      final match = _matches[i];
      if (match['latitude'] != null && match['longitude'] != null) {
        markers.add(
          Marker(
            markerId: MarkerId('match_$i'),
            position: LatLng(match['latitude'] as double, match['longitude'] as double),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            // Important: We intentionally omit InfoWindow. 
            // Instead we natively intercept the tap vector to trigger our gorgeous modal bottom sheet widget.
            onTap: () {
              _showBottomSheetPreview(match, context);
            },
          ),
        );
      }
    }
    return markers;
  }

  void _showBottomSheetPreview(Map<String, dynamic> match, BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          margin: const EdgeInsets.all(12),
          child: _buildMatchCard(match, context),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Your Matches',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF28C64)),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Your Matches',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.black87),
            onPressed: () => _showFilterDialog(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // AI Suggestion Card
            if (widget.aiSuggestions != null && widget.aiSuggestions!.isNotEmpty)
              Container(
                height: 160,
                margin: const EdgeInsets.only(top: 16, bottom: 8),
                child: PageView.builder(
                  controller: PageController(viewportFraction: 0.9),
                  itemCount: widget.aiSuggestions!.length,
                  itemBuilder: (context, index) {
                    final suggestion = widget.aiSuggestions![index];
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF28C64), Color(0xFFFF6B9D)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF28C64).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'AI Top Pick #${index + 1} For You',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${suggestion['city']}, ${suggestion['country']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18, // Slightly smaller to fit
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: Text(
                              suggestion['matchReason'] ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                height: 1.3,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            // Results Summary
            if (widget.aiSuggestions == null || widget.aiSuggestions!.isEmpty) const Divider(height: 1), 
            // Only show divider if no AI card to avoid double spacing look
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_matches.length} matches found',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _sortBy,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down,
                            size: 18, color: Colors.black87),
                      ],
                    ),
                    onSelected: (value) {
                      setState(() {
                        _sortBy = value;
                      });
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'Match Score',
                        child: Text('Match Score'),
                      ),
                      const PopupMenuItem(
                        value: 'Distance',
                        child: Text('Distance'),
                      ),
                      const PopupMenuItem(
                        value: 'Rating',
                        child: Text('Rating'),
                      ),
                      const PopupMenuItem(
                        value: 'Date',
                        child: Text('Date Available'),
                      ),
                    ],
                    offset: const Offset(0, 40),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Matches List or interactive Map Frame
            Expanded(
              child: _matches.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No matches found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try adjusting your preferences',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : _showMap
                      ? GoogleMap(
                          onMapCreated: (controller) {
                            _mapController = controller;
                            // Dynamically jump precisely to encase returned matches perfectly.
                            Future.delayed(const Duration(milliseconds: 300), () {
                               _calculateBounds();
                            });
                          },
                          initialCameraPosition: const CameraPosition(
                            target: LatLng(20.0, 0.0), // Arbitrary center, bounded via _calculateBounds natively once initialized
                            zoom: 2.0,
                          ),
                          markers: _buildMapMarkers(),
                          myLocationEnabled: true,
                          myLocationButtonEnabled: true,
                          zoomControlsEnabled: false, // Cleaner UI
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _matches.length,
                          itemBuilder: (context, index) {
                            final match = _matches[index];
                            return _buildMatchCard(match, context);
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          setState(() {
            _showMap = !_showMap;
          });
        },
        backgroundColor: Colors.black87,
        icon: Icon(
          _showMap ? Icons.list : Icons.map,
          color: Colors.white,
        ),
        label: Text(
          _showMap ? 'List' : 'Map',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> match, BuildContext context) {
    final homeId = match['home_id'] as int? ?? match['id'] as int? ?? 0;
    final score = (match['compatibility_score'] as num?)?.toDouble() ?? (match['score'] as num?)?.toDouble() ?? 0.0;
    final explanation = match['match_explanation'] as String?;
    final city = match['city'] ?? 'Unknown';
    final country = match['country'] ?? '';
    final location = country.isNotEmpty ? '$city, $country' : city;
    final title = match['title'] ?? 'Home';
    final description = match['description'] ?? 'No description available';
    final capacity = match['capacity'] ?? 0;
    final amenitiesStr = match['amenities'] as String? ?? '';
    final amenities = amenitiesStr.isNotEmpty
        ? amenitiesStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
        : <String>[];
    final isFavorite = _favoriteHomeIds.contains(homeId);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Section
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(Icons.home, size: 48, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              // Match Score Badge
              Positioned(
                top: 12,
                right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: score >= 90
                            ? [Colors.green.shade400, Colors.green.shade600]
                            : score >= 70
                                ? [Colors.orange.shade400, Colors.orange.shade600]
                                : [const Color(0xFFF28C64), const Color(0xFFFF6B9D)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${score.toInt()}% Match',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Match Explanation Text
              if (explanation != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.amber, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            explanation,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Favorite Button
              Positioned(
                top: 12,
                left: 12,
                child: GestureDetector(
                  onTap: () => _toggleFavorite(homeId),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : Colors.black87,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Content Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location and Host
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 16,
                                color: Color(0xFFF28C64),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  location,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDE5DA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star,
                            size: 14,
                            color: Color(0xFFF28C64),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            score.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFF28C64),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Description
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 12),

                // Key Features
                Row(
                  children: [
                    _buildFeatureChip(
                      Icons.people_outline,
                      '$capacity guests',
                    ),
                    if (amenities.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _buildFeatureChip(
                        Icons.home_outlined,
                        amenities[0],
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 12),

                // Amenities
                if (amenities.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: amenities
                        .take(4)
                        .map((amenity) => AmenityChip(label: amenity))
                        .toList(),
                  ),

                const SizedBox(height: 16),

                // Availability and Actions
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Available',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Available',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final homeId = match['home_id'] as int? ?? match['id'] as int? ?? 0;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HouseDetailPage(homeId: homeId),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF28C64),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'View Details',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black54),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Matches'),
        content: const Text('Filter options will be available here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

}

