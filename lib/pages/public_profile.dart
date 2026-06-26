import 'package:flutter/material.dart';
import '../services/user_service.dart';
import '../services/api_client.dart';
import 'house_detail.dart';

class PublicProfilePage extends StatefulWidget {
  final int userId;

  const PublicProfilePage({super.key, required this.userId});

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  bool _isLoading = true;
  Map<String, dynamic>? _user;
  List<dynamic> _homes = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await UserService.getPublicProfile(widget.userId);
      setState(() {
        _user = data['user'];
        _homes = data['homes'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(elevation: 0, backgroundColor: Colors.white, iconTheme: const IconThemeData(color: Colors.black)),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFFF28C64))),
      );
    }

    final String name = _user?['name'] ?? 'Unknown User';
    final String location = (_user?['city'] != null && _user?['country'] != null)
        ? '${_user!['city']}, ${_user!['country']}'
        : 'Unknown Location';
    final String bio = _user?['bio'] ?? 'No bio provided.';
    final String tagsStr = _user?['lifestyle_tags'] ?? '';
    final List<String> tags = tagsStr.isNotEmpty ? tagsStr.split(',').map((e) => e.trim()).toList() : [];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(name, style: const TextStyle(color: Colors.black87)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFFF28C64),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(child: Text(location, style: const TextStyle(fontSize: 14, color: Colors.grey))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Bio
            const Text('About', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(bio, style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
            const SizedBox(height: 24),

            // Lifestyle Tags
            if (tags.isNotEmpty) ...[
              const Text('Lifestyle & Interests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags.map((t) => Chip(
                  label: Text(t, style: const TextStyle(color: Colors.black87)),
                  backgroundColor: Colors.orange.shade50,
                  side: BorderSide(color: Colors.orange.shade200),
                )).toList(),
              ),
              const SizedBox(height: 32),
            ],

            // Homes
            if (_homes.isNotEmpty) ...[
              const Text('Listed Homes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ..._homes.map((h) => _buildHomeCard(context, h)),
            ] else ...[
               Container(
                 width: double.infinity,
                 padding: const EdgeInsets.all(24),
                 decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
                 child: const Text('No public homes listed yet.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
               ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildHomeCard(BuildContext context, Map<String, dynamic> home) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => HouseDetailPage(homeId: home['id'])));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (home['images'] != null && home['images'].isNotEmpty)
              Image.network(
                ApiClient.getFullImageUrl(home['images'][0]),
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 160, color: Colors.grey[300], child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              )
            else
              Container(height: 160, color: Colors.grey[300], child: const Icon(Icons.home, size: 48, color: Colors.grey)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(home['title'] ?? 'Home', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('${home['city'] ?? ''}, ${home['country'] ?? ''}', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
