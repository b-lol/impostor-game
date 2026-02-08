import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import 'game_screen.dart';

class LobbyScreen extends StatefulWidget {
  final String playerId;
  final String playerName;
  final String gameId;
  final bool isHost;
  final List<String> existingPlayers;

  const LobbyScreen({
    super.key,
    required this.playerId,
    required this.playerName,
    required this.gameId,
    required this.isHost,
    required this.existingPlayers,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final ApiService _apiService = ApiService();
  final WebSocketService _webSocketService = WebSocketService();
  
  List<String> _players = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
    _players = List.from(widget.existingPlayers);
  }

  void _connectWebSocket() {
    _webSocketService.onMessageReceived = _handleMessage;
    _webSocketService.connect(widget.gameId, widget.playerId);
  }

  void _handleMessage(Map<String, dynamic> message) {
    final type = message['type'];

    if (type == 'player_joined') {
      setState(() {
        final playerName = message['data']?['name'] ?? 'Unknown';
        if (!_players.contains(playerName)) {
          _players.add(playerName);
        }
      });
    } else if (type == 'player_disconnected') {
      setState(() {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A player disconnected')),
        );
      });
    } else if (type == 'game_started') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GameScreen(
            playerId: widget.playerId,
            playerName: widget.playerName,
            gameId: widget.gameId,
            isHost: widget.isHost,
            webSocketService: _webSocketService,
          ),
        ),
      );
    }
  }

  Future<void> _startGame() async {
    setState(() => _isLoading = true);

    final success = await _apiService.startGame(widget.gameId);

    setState(() => _isLoading = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start game')),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Lobby'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Game Code Display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A3E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'Game Code',
                    style: TextStyle(fontSize: 16, color: Color(0xFFB0B0B0)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.gameId,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      color: Color(0xFF08C8E9),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Share this code with friends!',
                    style: TextStyle(color: Color(0xFFB0B0B0)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Players List
            const Text(
              'Players',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _players.length,
                itemBuilder: (context, index) {
                  return Card(
                    color: const Color(0xFF2A2A3E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.person, color: Color(0xFF08C8E9)),
                      title: Text(_players[index]),
                      trailing: index == 0
                          ? Chip(
                              label: const Text(
                                'Host',
                                style: TextStyle(color: Color(0xFF1A1A2E)),
                              ),
                              backgroundColor: const Color(0xFF08C8E9),
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            if (widget.isHost)
              ElevatedButton(
                onPressed: _isLoading || _players.length < 2 ? null : _startGame,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _players.length < 2
                            ? 'Waiting for players...'
                            : 'Start Game',
                      ),
              ),

            if (!widget.isHost)
              const Text(
                'Waiting for host to start the game...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Color(0xFFB0B0B0)),
              ),
          ],
        ),
      ),
    );
  }
}