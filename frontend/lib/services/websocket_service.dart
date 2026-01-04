import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  static const String baseUrl = 'ws://127.0.0.1:8000';
  
  WebSocketChannel? _channel;
  Function(Map<String, dynamic>)? onMessageReceived;

  void connect(String gameId, String playerId) {
    final uri = Uri.parse('$baseUrl/ws/$gameId/$playerId');
    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      (data) {
        final message = jsonDecode(data);
        if (onMessageReceived != null) {
          onMessageReceived!(message);
        }
      },
      onError: (error) {
        print('WebSocket error: $error');
      },
      onDone: () {
        print('WebSocket connection closed');
      },
    );
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  void disconnect() {
    _channel?.sink.close();
  }
}