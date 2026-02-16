import 'package:flutter/material.dart';
import '../services/match_service.dart';
import 'chat_page.dart';

class MatchesMessagesPage extends StatefulWidget {
  const MatchesMessagesPage({super.key});

  @override
  State<MatchesMessagesPage> createState() => _MatchesMessagesPageState();
}

class _MatchesMessagesPageState extends State<MatchesMessagesPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _matches = [];

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    try {
      final matches = await MatchService.getAcceptedMatches(); 
      
      if (mounted) {
        setState(() {
          _matches = matches.map((m) => m as Map<String, dynamic>).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load matches: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _matches.isEmpty
              ? const Center(
                  child: Text(
                    'No matched users yet.\nOnce you accept a match, they will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.separated(
                  itemCount: _matches.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final match = _matches[index];
                    final otherUser = match['other_user'] as Map<String, dynamic>;
                    final otherUserName = otherUser['name'] ?? 'User ${otherUser['id'] ?? ''}';
                    final otherUserId = otherUser['id'] as int;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFF28C64),
                        child: Text(
                          otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(otherUserName),
                      subtitle: const Text('Tap to chat'),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPage(
                              otherUserId: otherUserId,
                              otherUserName: otherUserName,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
