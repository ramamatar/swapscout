import 'package:flutter/material.dart';
import '../widgets/selectable_chip.dart';
import '../services/home_service.dart';
import 'house_detail.dart';

class ManualSearchPage extends StatefulWidget {
  const ManualSearchPage({super.key});

  @override
  State<ManualSearchPage> createState() => _ManualSearchPageState();
}

class _ManualSearchPageState extends State<ManualSearchPage> {
  final Set<String> selectedEnvironments = {};
  final Set<String> selectedAmenities = {};
  final Set<String> selectedTypes = {};

  String _sortBy = 'Relevance';
  bool _isSearching = false;
  List<dynamic> _searchResults = [];
  bool _hasSearched = false;

  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _checkInController = TextEditingController();
  final TextEditingController _checkOutController = TextEditingController();
  final TextEditingController _guestsController = TextEditingController();

  @override
  void dispose() {
    _cityController.dispose();
    _countryController.dispose();
    _checkInController.dispose();
    _checkOutController.dispose();
    _guestsController.dispose();
    super.dispose();
  }

  void _toggleSelection(Set<String> set, String value) {
    setState(() {
      if (set.contains(value)) {
        set.remove(value);
      } else {
        set.add(value);
      }
    });
  }

  void _clearFilters() {
    setState(() {
      selectedEnvironments.clear();
      selectedAmenities.clear();
      selectedTypes.clear();
      _sortBy = 'Relevance';
      _cityController.clear();
      _countryController.clear();
      _checkInController.clear();
      _checkOutController.clear();
      _guestsController.clear();
      _searchResults.clear();
      _hasSearched = false;
    });
  }

  Future<void> _performSearch() async {
    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      // Parse city and country
      String? city = _cityController.text.trim();
      String? country = _countryController.text.trim();
      
      if (city.isEmpty) city = null;
      if (country.isEmpty) country = null;

      // Parse guests
      int? minCapacity;
      if (_guestsController.text.isNotEmpty) {
        minCapacity = int.tryParse(_guestsController.text);
      }

      // Get selected environment and property type
      String? environment;
      String? propertyType;
      if (selectedEnvironments.isNotEmpty) {
        environment = selectedEnvironments.first; // Use first selected
      }
      if (selectedTypes.isNotEmpty) {
        propertyType = selectedTypes.first; // Use first selected
      }

      // Combine selected amenities
      String? amenitiesFilter;
      if (selectedAmenities.isNotEmpty) {
        amenitiesFilter = selectedAmenities.join(',');
      }

      final results = await HomeService.searchHomes(
        country: country,
        city: city,
        minCapacity: minCapacity,
        environment: environment,
        propertyType: propertyType,
        amenities: amenitiesFilter,
        dateFrom: _checkInController.text.trim().isNotEmpty
            ? _checkInController.text.trim()
            : null,
        dateTo: _checkOutController.text.trim().isNotEmpty
            ? _checkOutController.text.trim()
            : null,
      );

      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Search',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          if (selectedEnvironments.isNotEmpty ||
              selectedAmenities.isNotEmpty ||
              selectedTypes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all, color: Colors.black87),
              onPressed: _clearFilters,
              tooltip: 'Clear filters',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Header Section
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _cityController,
                          decoration: InputDecoration(
                            hintText: 'City',
                            prefixIcon: const Icon(Icons.location_city_outlined),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E2E2)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E2E2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFF28C64),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _countryController,
                          decoration: InputDecoration(
                            hintText: 'Country',
                            prefixIcon: const Icon(Icons.flag_outlined),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E2E2)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E2E2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFF28C64),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _checkInController,
                          decoration: InputDecoration(
                            hintText: 'Check-in (YYYY-MM-DD)',
                            prefixIcon: const Icon(Icons.calendar_today_outlined),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E2E2)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E2E2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFF28C64),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _checkOutController,
                          decoration: InputDecoration(
                            hintText: 'Check-out (YYYY-MM-DD)',
                            prefixIcon: const Icon(Icons.calendar_today_outlined),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E2E2)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E2E2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFF28C64),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _guestsController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Number of guests',
                      prefixIcon: const Icon(Icons.people_outline),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E2E2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E2E2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFF28C64),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSearching ? null : _performSearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF28C64),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 0,
                      ),
                      child: _isSearching
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Search',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),

            // Filter and Sort Section
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: PopupMenuButton<String>(
                      icon: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune, size: 18, color: Colors.black87),
                          SizedBox(width: 4),
                          Text(
                            'Filters',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      onSelected: (value) {
                        // Handle filter menu items
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'more',
                          child: Text('More Filters'),
                        ),
                      ],
                      offset: const Offset(0, 40),
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
                        value: 'Relevance',
                        child: Text('Relevance'),
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
                        value: 'Price',
                        child: Text('Price'),
                      ),
                    ],
                    offset: const Offset(0, 40),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Filters Chips Row
            if (selectedEnvironments.isNotEmpty ||
                selectedAmenities.isNotEmpty ||
                selectedTypes.isNotEmpty)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                height: 50,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...selectedEnvironments.map((env) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Chip(
                              label: Text(env),
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: () {
                                setState(() {
                                  selectedEnvironments.remove(env);
                                });
                              },
                              backgroundColor: const Color(0xFFFDE5DA),
                              labelStyle: const TextStyle(
                                color: Color(0xFFF28C64),
                                fontSize: 12,
                              ),
                            ),
                          )),
                      ...selectedAmenities.map((amenity) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Chip(
                              label: Text(amenity),
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: () {
                                setState(() {
                                  selectedAmenities.remove(amenity);
                                });
                              },
                              backgroundColor: const Color(0xFFFDE5DA),
                              labelStyle: const TextStyle(
                                color: Color(0xFFF28C64),
                                fontSize: 12,
                              ),
                            ),
                          )),
                      ...selectedTypes.map((type) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Chip(
                              label: Text(type),
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: () {
                                setState(() {
                                  selectedTypes.remove(type);
                                });
                              },
                              backgroundColor: const Color(0xFFFDE5DA),
                              labelStyle: const TextStyle(
                                color: Color(0xFFF28C64),
                                fontSize: 12,
                              ),
                            ),
                          )),
                    ],
                  ),
                ),
              ),

            // Filter Options Section
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Environment',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        'Beach',
                        'City',
                        'Mountain',
                        'Countryside',
                        'Lakeside',
                      ].map((env) {
                        return SelectableChip(
                          label: env,
                          isSelected: selectedEnvironments.contains(env),
                          onTap: () => _toggleSelection(selectedEnvironments, env),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),

                    const Text(
                      'Property Type',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        'Apartment',
                        'House',
                        'Villa',
                        'Cottage',
                        'Cabin',
                      ].map((type) {
                        return SelectableChip(
                          label: type,
                          isSelected: selectedTypes.contains(type),
                          onTap: () => _toggleSelection(selectedTypes, type),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),

                    const Text(
                      'Amenities',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        'Wi-Fi',
                        'Pet-Friendly',
                        'Pool',
                        'Parking',
                        'Kitchen',
                        'Washer',
                        'Fireplace',
                        'Garden',
                      ].map((amenity) {
                        return SelectableChip(
                          label: amenity,
                          isSelected: selectedAmenities.contains(amenity),
                          onTap: () => _toggleSelection(selectedAmenities, amenity),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),

                    // Search Results
                    if (_hasSearched)
                      _searchResults.isEmpty
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No results found',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Try adjusting your search criteria',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_searchResults.length} results found',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ..._searchResults.map((home) => _buildHomeCard(home)),
                              ],
                            )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.search,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Search results will appear here',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Use the filters above to find your perfect swap',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeCard(Map<String, dynamic> home) {
    final city = home['city'] ?? 'Unknown';
    final country = home['country'] ?? '';
    final location = country.isNotEmpty ? '$city, $country' : city;
    final title = home['title'] ?? 'Home';
    final description = home['description'] ?? 'No description';
    final capacity = home['capacity'] ?? 0;
    final homeId = home['id'] as int;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HouseDetailPage(homeId: homeId),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E2E2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Color(0xFFF28C64)),
                const SizedBox(width: 4),
                Text(
                  location,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
            Row(
              children: [
                Chip(
                  label: Text('$capacity guests'),
                  backgroundColor: Colors.grey[100],
                  labelStyle: const TextStyle(fontSize: 12),
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

