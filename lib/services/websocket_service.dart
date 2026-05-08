import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_client.dart';
import 'user_service.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  bool _isConnected = false;
  
  // A broadcast stream for UI listeners
  final StreamController<Map<String, dynamic>> _messageController = 
      StreamController<Map<String, dynamic>>.broadcast();
      
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  Future<void> init() async {
    if (_isConnected) return;
    
    try {
      final profile = await UserService.getMyProfile();
      final userId = profile['id'];
      if (userId == null) return;
      
      final host = Uri.parse(ApiClient.baseUrl).host;
      final port = Uri.parse(ApiClient.baseUrl).port;
      final wsUrl = Uri.parse('ws://$host:$port/ws/notifications/$userId');
      
      _connect(wsUrl);
    } catch (e) {
      debugPrint('WS Init error: $e');
    }
  }

  void _connect(Uri uri) {
    try {
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;
      
      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            _messageController.add(data);
          } catch (e) {
            debugPrint('WS decode error: $e');
          }
        },
        onDone: () {
          _isConnected = false;
          // Reconnect gracefully after delay
          Future.delayed(const Duration(seconds: 5), () => _connect(uri));
        },
        onError: (error) {
          _isConnected = false;
          // Note: cancelOnError is true, so onDone generally triggers too.
        },
        cancelOnError: true,
      );
    } catch (e) {
      _isConnected = false;
      Future.delayed(const Duration(seconds: 5), () => _connect(uri));
    }
  }

  void dispose() {
    _isConnected = false;
    _channel?.sink.close();
    _messageController.close();
  }
}
