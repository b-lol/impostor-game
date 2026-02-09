import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'lobby_screen.dart';

class CreateGameScreen extends StatefulWidget {
  final String playerId;
  final String playerName;

  const CreateGameScreen({
    super.key,
    required this.playerId,
    required this.playerName,
  });

  @override
  State<CreateGameScreen> createState() => _CreateGameScreenState();
}

class _CreateGameScreenState extends State<CreateGameScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _roundsController = TextEditingController(text: '3');
  final TextEditingController _timerController = TextEditingController(text: '30');
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _passcodeController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _categoryController.addListener(() => setState(() {}));
  }

  Future<void> _createGame() async {
    setState(() => _isLoading = true);

    final gameId = await _apiService.createGame(
      hostId: widget.playerId,
      maxRound: int.tryParse(_roundsController.text) ?? 3,
      clueTime: int.tryParse(_timerController.text) ?? 30,
      secretCategory: _categoryController.text.trim(),
      passcode: _passcodeController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (gameId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LobbyScreen(
            playerId: widget.playerId,
            playerName: widget.playerName,
            gameId: gameId,
            isHost: true,
            existingPlayers: [widget.playerName],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create game. Check your passcode if using a category.')),
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
              'Create a Game',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Color(0xFF08C8E9),
              ),
            ),
            const SizedBox(height: 24),

            // Rounds and Timer side by side
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _roundsController,
                    decoration: InputDecoration(
                      labelText: 'Rounds',
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
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _timerController,
                    decoration: InputDecoration(
                      labelText: 'Timer (sec)',
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
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Category input (optional)
            TextField(
              controller: _categoryController,
              decoration: InputDecoration(
                labelText: 'Category (Optional)',
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
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),

            // Passcode (only shows when category is entered)
            if (_categoryController.text.trim().isNotEmpty)
              TextField(
                controller: _passcodeController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Passcode',
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
                style: const TextStyle(color: Colors.white),
              ),
            const SizedBox(height: 24),

            // Create button
            ElevatedButton(
              onPressed: _isLoading ? null : _createGame,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Create'),
            ),

            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}