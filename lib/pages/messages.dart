import 'package:flutter/material.dart';
import '../services/message_service.dart';

class MessagesPage extends StatefulWidget {
  final int? otherUserId;

  const MessagesPage({super.key, this.otherUserId});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final TextEditingController _messageController = TextEditingController();
  bool _isLoading = true;
  List<dynamic> _conversations = [];
  List<dynamic>? _currentMessages;
  int? _selectedUserId;

  @override
  void initState() {
    super.initState();
    if (widget.otherUserId != null) {
      _selectedUserId = widget.otherUserId;
    }
    _loadInbox();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadInbox() async {
    setState(() => _isLoading = true);
    try {
      final inbox = await MessageService.getInbox();
      setState(() {
        _conversations = inbox;
        if (_selectedUserId != null) {
          _loadConversation(_selectedUserId!);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load messages: ${e.toString()}'),
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

  Future<void> _loadConversation(int userId) async {
    try {
      final messages = await MessageService.getConversation(userId);
      setState(() {
        _currentMessages = messages;
        _selectedUserId = userId;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load conversation: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _selectedUserId == null) return;

    final content = _messageController.text.trim();
    _messageController.clear();

    try {
      await MessageService.sendMessage(
        receiverId: _selectedUserId!,
        content: content,
      );
      await _loadConversation(_selectedUserId!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Messages',
          style: TextStyle(color: Colors.black87),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF28C64)),
              ),
            )
          : _conversations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.message_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No messages yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : Row(
                  children: [
                    // Conversations list
                    Container(
                      width: 300,
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: ListView.builder(
                        itemCount: _conversations.length,
                        itemBuilder: (context, index) {
                          final conv = _conversations[index] as Map<String, dynamic>;
                          final userId = conv['user_id'] as int;
                          final isSelected = _selectedUserId == userId;
                          
                          return ListTile(
                            selected: isSelected,
                            selectedTileColor: const Color(0xFFFDE5DA),
                            title: Text('User $userId'),
                            subtitle: Text(
                              conv['last_message']?.toString() ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _loadConversation(userId),
                          );
                        },
                      ),
                    ),
                    
                    // Messages view
                    Expanded(
                      child: _selectedUserId == null || _currentMessages == null
                          ? Center(
                              child: Text(
                                'Select a conversation',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            )
                          : Column(
                              children: [
                                Expanded(
                                  child: ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _currentMessages!.length,
                                    itemBuilder: (context, index) {
                                      final msg = _currentMessages![index] as Map<String, dynamic>;
                                      final isSent = msg['sender_id'] != _selectedUserId;
                                      
                                      return Align(
                                        alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
                                        child: Container(
                                          margin: const EdgeInsets.only(bottom: 12),
                                          padding: const EdgeInsets.all(12),
                                          constraints: BoxConstraints(
                                            maxWidth: MediaQuery.of(context).size.width * 0.6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSent
                                                ? const Color(0xFFF28C64)
                                                : Colors.grey[200],
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Text(
                                            msg['content']?.toString() ?? '',
                                            style: TextStyle(
                                              color: isSent ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                
                                // Message input
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border(
                                      top: BorderSide(color: Colors.grey[300]!),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _messageController,
                                          decoration: InputDecoration(
                                            hintText: 'Type a message...',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(24),
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.send, color: Color(0xFFF28C64)),
                                        onPressed: _sendMessage,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
    );
  }
}

