import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'lobby_screen.dart';

class JoinGameScreen extends StatefulWidget {
  final String playerId;
  final String playerName;

  const JoinGameScreen({
    super.key,
    required this.playerId,
    required this.playerName,
  });

  @override
  State<JoinGameScreen> createState() => _JoinGameScreenState();
}

class _JoinGameScreenState extends State<JoinGameScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _gameCodeController = TextEditingController();
  bool _isLoading = false;

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
      // Save game_id for rejoin
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('game_id', _gameCodeController.text.trim().toUpperCase());

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LobbyScreen(
            playerId: widget.playerId,
            playerName: widget.playerName,
            gameId: _gameCodeController.text.trim().toUpperCase(),
            isHost: false,
            existingPlayers: players,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Game not found')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const SizedBox.shrink(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Spacer(flex: 1),

            // Title
            const Text(
              'Join a Game',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Color(0xFF08C8E9),
              ),
            ),
            const SizedBox(height: 24),

            // Game code input
            TextField(
              controller: _gameCodeController,
              decoration: InputDecoration(
                labelText: 'Game Code',
                labelStyle: const TextStyle(color: Color(0xFFB0B0B0)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF08C8E9)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFB0B0B0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF08C8E9), width: 2),
                ),
                filled: false,
              ),
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 24),

            // Join button
            ElevatedButton(
              onPressed: _isLoading ? null : _joinGame,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Join'),
            ),

            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}