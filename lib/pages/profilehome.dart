import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../widgets/amenity.dart';
import '../services/user_service.dart';
import '../services/home_service.dart';
import '../services/auth_service.dart';
import '../services/token_storage.dart';
import 'notifications.dart';
import 'matches_messages.dart';
import 'login.dart';
import 'map_location_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/api_client.dart';

class ProfileHomeListingPage extends StatefulWidget {
  const ProfileHomeListingPage({super.key});

  @override
  State<ProfileHomeListingPage> createState() => _ProfileHomeListingPageState();
}

class _ProfileHomeListingPageState extends State<ProfileHomeListingPage> {
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isInitialLoading = true;
  
  // Profile data
  String _name = '';
  String _location = '';
  String _email = '';
  String _phone = '';
  String _bio = '';
  
  // Homes list
  List<Map<String, dynamic>> _homes = [];
  
  // Controllers for editing
  late TextEditingController _nameController;
  late TextEditingController _locationController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _locationController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _bioController = TextEditingController();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isInitialLoading = true);
    try {
      // Load user profile
      final profile = await UserService.getMyProfile();
      setState(() {
        _name = profile['name'] ?? '';
        _email = profile['email'] ?? '';
        final city = profile['city'] ?? '';
        final country = profile['country'] ?? '';
        _location = city.isNotEmpty && country.isNotEmpty 
            ? '$city, $country'
            : city.isNotEmpty ? city : country;
        _phone = ''; // Phone not in API yet
        _bio = profile['bio'] ?? '';
        
        _nameController.text = _name;
        _locationController.text = _location;
        _emailController.text = _email;
        _phoneController.text = _phone;
        _bioController.text = _bio;
      });

      // Load user's homes
      final homes = await HomeService.getMyHomes();
      setState(() {
        _homes = homes.map((h) => h as Map<String, dynamic>).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _nameController.text = _name;
      _locationController.text = _location;
      _emailController.text = _email;
      _phoneController.text = _phone;
      _bioController.text = _bio;
    });
  }

  Future<void> _saveProfileChanges() async {
    setState(() => _isLoading = true);
    
    try {
      // Parse location
      final locationParts = _locationController.text.split(',');
      final city = locationParts.isNotEmpty ? locationParts[0].trim() : '';
      final country = locationParts.length > 1 ? locationParts[1].trim() : '';

      await UserService.updateMyProfile(
        name: _nameController.text.trim(),
        city: city,
        country: country,
        bio: _bioController.text.trim(),
      );

      // Reload data
      await _loadData();

      if (!mounted) return;
      
      setState(() => _isEditing = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated!'),
          backgroundColor: Color(0xFFF28C64),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: ${e.toString()}'),
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

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _nameController.text = _name;
      _locationController.text = _location;
      _emailController.text = _email;
      _phoneController.text = _phone;
      _bioController.text = _bio;
    });
  }

  void _addNewHome() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _AddEditHomePage(
          onSave: () => _loadData(),
        ),
      ),
    );
  }

  void _editHome(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _AddEditHomePage(
          home: _homes[index],
          onSave: () => _loadData(),
        ),
      ),
    );
  }

  Future<void> _deleteHome(int homeId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Home'),
        content: const Text('Are you sure you want to delete this home listing?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await HomeService.deleteHome(homeId);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Home deleted'),
              backgroundColor: Color(0xFFF28C64),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardRadius = BorderRadius.circular(18);

    if (_isInitialLoading) {
      return Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          centerTitle: true,
          title: const Text(
            'Profile & Home Listing',
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
        centerTitle: true,
        title: const Text(
          'Profile & Home Listing',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.message_outlined, color: Colors.black87),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const MatchesMessagesPage(),
                ),
              );
            },
            tooltip: 'Messages',
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: Colors.black87),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const NotificationsPage(),
                ),
              );
            },
            tooltip: 'Notifications',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onSelected: (value) async {
              if (value == 'logout') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );
                
                if (confirmed == true) {
                  await AuthService.logout();
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                      (_) => false,
                    );
                  }
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.black87),
              onPressed: _startEditing,
              tooltip: 'Edit Profile',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    // Profile Section
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: cardRadius,
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Your Profile',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              if (_isEditing)
                                IconButton(
                                  icon: const Icon(Icons.close, size: 20),
                                  color: Colors.black54,
                                  onPressed: _cancelEditing,
                                  tooltip: 'Cancel',
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          
                          if (!_isEditing)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _name.isNotEmpty ? _name : 'No name set',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                if (_location.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    _location,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                                if (_bio.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _bio,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ],
                            )
                          else
                            Column(
                              children: [
                                TextField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                    labelText: 'Full Name',
                                    prefixIcon: const Icon(Icons.person_outline),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFFE2E2E2)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFFF28C64), width: 2),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _locationController,
                                  decoration: InputDecoration(
                                    labelText: 'Location (City, Country)',
                                    prefixIcon: const Icon(Icons.location_on_outlined),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFFE2E2E2)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFFF28C64), width: 2),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _bioController,
                                  maxLines: 4,
                                  decoration: InputDecoration(
                                    labelText: 'About Me (Bio)',
                                    alignLabelWithHint: true,
                                    prefixIcon: const Padding(
                                      padding: EdgeInsets.only(bottom: 50.0), // visual adjustment
                                      child: Icon(Icons.edit_note),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFFE2E2E2)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFFF28C64), width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          
                          const SizedBox(height: 16),
                          const Text(
                            'Email Address',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (!_isEditing)
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E2E2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.email_outlined, size: 20, color: Colors.grey),
                                  const SizedBox(width: 12),
                                  Text(
                                    _email,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              enabled: false,
                              decoration: InputDecoration(
                                hintText: 'Email cannot be changed',
                                prefixIcon: const Icon(Icons.email_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE2E2E2)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFF28C64), width: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Home Listings Section
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: cardRadius,
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Your Home Listings',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: Color(0xFFF28C64)),
                                onPressed: _addNewHome,
                                tooltip: 'Add Home',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_homes.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    Icon(Icons.home_outlined, size: 48, color: Colors.grey[400]),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No homes listed yet',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton.icon(
                                      onPressed: _addNewHome,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add Your First Home'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFF28C64),
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ..._homes.asMap().entries.map((entry) {
                              final index = entry.key;
                              final home = entry.value;
                              return _buildHomeCard(home, index);
                            }),
                        ],
                      ),
                    ),

                    SizedBox(height: _isEditing ? 90 : 20),
                  ],
                ),
              ),
            ),

            // Save Changes Button (only shown in edit mode)
            if (_isEditing)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16)
                    .copyWith(bottom: 16, top: 8),
                color: Colors.white,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfileChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF28C64),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeCard(Map<String, dynamic> home, int index) {
    final title = home['title'] ?? 'Home';
    final description = home['description'] ?? '';
    final city = home['city'] ?? '';
    final country = home['country'] ?? '';
    final location = country.isNotEmpty ? '$city, $country' : city;
    final capacity = home['capacity'] ?? 0;
    final amenitiesStr = home['amenities'] as String? ?? '';
    final amenities = amenitiesStr.isNotEmpty
        ? amenitiesStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
        : <String>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E2E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: Color(0xFFF28C64)),
                        const SizedBox(width: 4),
                        Text(
                          location,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => _editHome(index),
                tooltip: 'Edit',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                onPressed: () => _deleteHome(home['id'] as int),
                tooltip: 'Delete',
              ),
            ],
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
          Row(
            children: [
              Chip(
                label: Text('$capacity guests'),
                backgroundColor: Colors.white,
                labelStyle: const TextStyle(fontSize: 12),
              ),
              if (amenities.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: amenities.take(3).map((a) => AmenityChip(label: a)).toList(),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// Add/Edit Home Page
class _AddEditHomePage extends StatefulWidget {
  final Map<String, dynamic>? home;
  final VoidCallback onSave;

  const _AddEditHomePage({
    this.home,
    required this.onSave,
  });

  @override
  State<_AddEditHomePage> createState() => _AddEditHomePageState();
}

class _AddEditHomePageState extends State<_AddEditHomePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _capacityController = TextEditingController();
  final _availableFromController = TextEditingController();
  final _availableToController = TextEditingController();
  
  String? _selectedEnvironment;
  String? _selectedPropertyType;
  final Set<String> _selectedAmenities = {};
  bool _isHidden = false;
  bool _isLoading = false;
  bool _isDetectingAmenities = false;
  double? _latitude;
  double? _longitude;
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  final List<String> _environmentOptions = ['Beach', 'City', 'Mountain', 'Countryside', 'Lakeside'];
  final List<String> _propertyTypeOptions = ['Apartment', 'House', 'Villa', 'Cottage', 'Cabin'];
  final List<String> _amenityOptions = [
    'Wi-Fi', 'Parking', 'Kitchen', 'Washer', 'Dryer', 'Air Conditioning', 
    'Heating', 'TV', 'Fireplace', 'Pool', 'Hot Tub', 'Garden', 'Balcony', 
    'Pet-Friendly', 'Smoking Allowed', 'Wheelchair Accessible', 'Gym', 
    'Workspace', 'Dishwasher', 'Microwave', 'Coffee Maker', 'Blender',
    'Outdoor Grill', 'Beach Access', 'Mountain View', 'City View'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.home != null) {
      _titleController.text = widget.home!['title'] ?? '';
      _descriptionController.text = widget.home!['description'] ?? '';
      _cityController.text = widget.home!['city'] ?? '';
      _countryController.text = widget.home!['country'] ?? '';
      _capacityController.text = (widget.home!['capacity'] ?? 0).toString();
      _selectedEnvironment = widget.home!['environment'] as String?;
      _selectedPropertyType = widget.home!['property_type'] as String?;
      _isHidden = widget.home!['is_hidden'] ?? false;
      final amenitiesStr = widget.home!['amenities'] as String? ?? '';
      if (amenitiesStr.isNotEmpty) {
        _selectedAmenities.addAll(amenitiesStr.split(',').map((e) => e.trim()));
      }
      _availableFromController.text = widget.home!['available_from'] ?? '';
      _availableToController.text = widget.home!['available_to'] ?? '';
      
      _latitude = widget.home!['latitude'] as double?;
      _longitude = widget.home!['longitude'] as double?;

      // Ensure selected values exist in options
      if (_selectedEnvironment != null && !_environmentOptions.contains(_selectedEnvironment)) {
        _environmentOptions.add(_selectedEnvironment!);
      }
      if (_selectedPropertyType != null && !_propertyTypeOptions.contains(_selectedPropertyType)) {
        _propertyTypeOptions.add(_selectedPropertyType!);
      }
    } else {
      final now = DateTime.now();
      _availableFromController.text = now.toIso8601String().split('T')[0];
      _availableToController.text = now.add(const Duration(days: 365)).toIso8601String().split('T')[0];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _capacityController.dispose();
    _availableFromController.dispose();
    _availableToController.dispose();
    super.dispose();
  }

  Future<void> _detectAmenitiesFromImage() async {
    if (_selectedImage == null) return;
    setState(() => _isDetectingAmenities = true);
    try {
      final token = await TokenStorage.getToken();
      final request = http.MultipartRequest('POST', Uri.parse('${ApiClient.baseUrl}/homes/detect-amenities'));
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('image', _selectedImage!.path));
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> detected = data['amenities'] ?? [];
        if (detected.isNotEmpty) {
           setState(() {
              for (var amenity in detected) {
                 final String amStr = amenity.toString();
                 if (!_amenityOptions.contains(amStr)) {
                    _amenityOptions.insert(0, amStr);
                 }
                 _selectedAmenities.add(amStr);
              }
           });
           if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Detected ${detected.length} amenities via Gemini AI!'), backgroundColor: Colors.green));
           }
        } else {
           if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No amenities visibly detected by AI.')));
           }
        }
      } else {
        throw Exception(jsonDecode(response.body)['detail'] ?? 'Failed to detect');
      }
    } catch (e) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to detect: $e'), backgroundColor: Colors.red));
       }
    } finally {
      if (mounted) {
         setState(() => _isDetectingAmenities = false);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _selectAvailableDateRange() async {
    FocusScope.of(context).unfocus();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFF28C64),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _availableFromController.text = picked.start.toString().split(' ')[0];
        _availableToController.text = picked.end.toString().split(' ')[0];
      });
    }
  }

  Future<void> _saveHome() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validate required fields
    if (_selectedEnvironment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an environment')),
      );
      return;
    }
    if (_selectedPropertyType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a property type')),
      );
      return;
    }
    if (_selectedAmenities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one amenity')),
      );
      return;
    }
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please drop a pin on the map')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final capacity = int.tryParse(_capacityController.text) ?? 0;
      final amenitiesStr = _selectedAmenities.join(', ');
      
      Map<String, dynamic> result;
      if (widget.home != null) {
        result = await HomeService.updateHome(
          homeId: widget.home!['id'] as int,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          city: _cityController.text.trim(),
          country: _countryController.text.trim(),
          capacity: capacity,
          amenities: amenitiesStr,
          environment: _selectedEnvironment,
          propertyType: _selectedPropertyType,
          availableFrom: _availableFromController.text.trim(),
          availableTo: _availableToController.text.trim(),
          isHidden: _isHidden,
        );
      } else {
        result = await HomeService.createHome(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          city: _cityController.text.trim(),
          country: _countryController.text.trim(),
          capacity: capacity,
          amenities: amenitiesStr,
          environment: _selectedEnvironment!,
          propertyType: _selectedPropertyType!,
          availableFrom: _availableFromController.text.trim(),
          availableTo: _availableToController.text.trim(),
          latitude: _latitude,
          longitude: _longitude,
        );
      }
      
      if (_selectedImage != null) {
        final homeId = result['id'] as int;
        await HomeService.uploadHomeImage(homeId, _selectedImage!.path);
      }

      if (!mounted) return;
      widget.onSave();
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: ${e.toString()}'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.home != null ? 'Edit Home' : 'Add Home'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Picker Section
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: _selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(_selectedImage!.path),
                              fit: BoxFit.cover,
                            ),
                          )
                        : (widget.home != null && widget.home!['images'] != null && (widget.home!['images'] as List).isNotEmpty)
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  ApiClient.getFullImageUrl(widget.home!['images'][0]),
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo, size: 48, color: Colors.grey[600]),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Add Home Photo',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'City *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _countryController,
                      decoration: const InputDecoration(
                        labelText: 'Country *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Guest Capacity *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Required';
                  if (int.tryParse(value!) == null) return 'Invalid number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Location Map Picker
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MapLocationPickerPage(
                          initialLocation: _latitude != null && _longitude != null 
                              ? LatLng(_latitude!, _longitude!) 
                              : null,
                          addressQuery: "${_cityController.text.trim()}, ${_countryController.text.trim()}",
                        ),
                      ),
                    );
                    if (result != null) {
                      setState(() {
                        _latitude = (result as LatLng).latitude;
                        _longitude = result.longitude;
                      });
                    }
                  },
                  icon: const Icon(Icons.map),
                  label: Text(_latitude == null ? 'Drop Location Pin on Map *' : 'Location Pin Set!'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _latitude == null ? Colors.grey[200] : const Color(0xFFF28C64),
                    foregroundColor: _latitude == null ? Colors.black87 : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    side: _latitude == null ? BorderSide(color: Colors.grey[400]!) : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Environment Selection
              DropdownButtonFormField<String>(
                initialValue: _selectedEnvironment,
                decoration: const InputDecoration(
                  labelText: 'Environment *',
                  border: OutlineInputBorder(),
                ),
                items: _environmentOptions.map((env) {
                  return DropdownMenuItem(value: env, child: Text(env));
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedEnvironment = value);
                },
                validator: (value) => value == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              
              // Property Type Selection
              DropdownButtonFormField<String>(
                initialValue: _selectedPropertyType,
                decoration: const InputDecoration(
                  labelText: 'Property Type *',
                  border: OutlineInputBorder(),
                ),
                items: _propertyTypeOptions.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedPropertyType = value);
                },
                validator: (value) => value == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              
              // Amenities Selection
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Amenities * (Select at least one)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (_selectedImage != null)
                    TextButton.icon(
                      onPressed: _isDetectingAmenities ? null : _detectAmenitiesFromImage,
                      icon: _isDetectingAmenities 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.auto_awesome, color: Colors.blue),
                      label: const Text('Auto-Detect', style: TextStyle(color: Colors.blue)),
                    )
                ],
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _amenityOptions.map((amenity) {
                      final isSelected = _selectedAmenities.contains(amenity);
                      return FilterChip(
                        label: Text(amenity),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedAmenities.add(amenity);
                            } else {
                              _selectedAmenities.remove(amenity);
                            }
                          });
                        },
                        selectedColor: const Color(0xFFFDE5DA),
                        checkmarkColor: const Color(0xFFF28C64),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Hide/Show Toggle
              Row(
                children: [
                  const Text(
                    'Hide this listing',
                    style: TextStyle(fontSize: 16),
                  ),
                  const Spacer(),
                  Switch(
                    value: _isHidden,
                    onChanged: (value) {
                      setState(() => _isHidden = value);
                    },
                    activeThumbColor: const Color(0xFFF28C64),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _isHidden 
                    ? 'This home will be hidden from search results'
                    : 'This home will be visible in search results',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _availableFromController,
                readOnly: true,
                onTap: _selectAvailableDateRange,
                decoration: const InputDecoration(
                  labelText: 'Available From *',
                  hintText: 'YYYY-MM-DD',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _availableToController,
                readOnly: true,
                onTap: _selectAvailableDateRange,
                decoration: const InputDecoration(
                  labelText: 'Available To *',
                  hintText: 'YYYY-MM-DD',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveHome,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF28C64),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(widget.home != null ? 'Update Home' : 'Create Home'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
