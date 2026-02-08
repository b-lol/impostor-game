import 'package:flutter/material.dart';
import 'join_game_screen.dart';
import 'create_game_screen.dart';

class MenuScreen extends StatelessWidget {
  final String playerId;
  final String playerName;

  const MenuScreen({
    super.key,
    required this.playerId,
    required this.playerName,
  });

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
            const Spacer(flex: 2),

            // Greeting
            Text(
              'Hey, $playerName!',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Color(0xFF08C8E9),
              ),
            ),

            const Spacer(flex: 2),

            // Join a Game — Primary button
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => JoinGameScreen(
                      playerId: playerId,
                      playerName: playerName,
                    ),
                  ),
                );
              },
              child: const Text('Join a Game'),
            ),
            const SizedBox(height: 16),

            // Create a Game — Secondary button
            OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateGameScreen(
                      playerId: playerId,
                      playerName: playerName,
                    ),
                  ),
                );
              },
              child: const Text('Create a Game'),
            ),

            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}