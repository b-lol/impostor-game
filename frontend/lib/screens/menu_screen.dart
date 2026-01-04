import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'lobby_screen.dart';

class MenuScreen extends StatefulWidget {
  final String playerId;
  final String playerName;

  const MenuScreen({
    super.key,
    required this.playerId,
    required this.playerName,
  });

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final ApiService _apiService = ApiService();

  // Create game form controllers
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _roundsController = TextEditingController(text: '3');
  final TextEditingController _timerController = TextEditingController(text: '30');

  // Join game controller
  final TextEditingController _gameCodeController = TextEditingController();

  bool _isLoading = false;

  Future<void> _createGame() async {
    if (_categoryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a category')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final gameId = await _apiService.createGame(
      hostId: widget.playerId,
      maxRound: int.tryParse(_roundsController.text) ?? 3,
      clueTime: int.tryParse(_timerController.text) ?? 30,
      secretCategory: _categoryController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (gameId != null) {
      _navigateToLobby(gameId, isHost: true, existingPlayers: [widget.playerName]);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create game')),
      );
    }
  }

  Future<void> _joinGame() async {
  if (_gameCodeController.text.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter a game code')),
    );
    return;
  }

  setState(() => _isLoading = true);

  final players = await _apiService.joinGame(
    widget.playerId,
    _gameCodeController.text.trim().toUpperCase(),
  );

  setState(() => _isLoading = false);

  if (players != null) {
    _navigateToLobby(
      _gameCodeController.text.trim().toUpperCase(),
      isHost: false,
      existingPlayers: players,
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Game not found')),
    );
  }
}

  void _navigateToLobby(String gameId, {required bool isHost, List<String>? existingPlayers}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => LobbyScreen(
        playerId: widget.playerId,
        playerName: widget.playerName,
        gameId: gameId,
        isHost: isHost,
        existingPlayers: existingPlayers ?? [widget.playerName],
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${widget.playerName}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // CREATE GAME SECTION
            const Text(
              'Create Game',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Category (e.g., Movies, Food, Animals)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _roundsController,
                    decoration: const InputDecoration(
                      labelText: 'Rounds',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _timerController,
                    decoration: const InputDecoration(
                      labelText: 'Timer (seconds)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _createGame,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Create Game', style: TextStyle(fontSize: 18)),
            ),

            const SizedBox(height: 48),
            const Divider(),
            const SizedBox(height: 24),

            // JOIN GAME SECTION
            const Text(
              'Join Game',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _gameCodeController,
              decoration: const InputDecoration(
                labelText: 'Game Code',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _joinGame,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Join Game', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}