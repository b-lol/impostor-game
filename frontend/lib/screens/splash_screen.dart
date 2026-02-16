import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'lobby_screen.dart';
import '../services/websocket_service.dart';
import '../models/game_session.dart';
import 'game_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _savedPlayerId;
  String? _savedPlayerName;
  String? _savedGameId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkSavedSession();
  }

  Future<void> _checkSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedPlayerId = prefs.getString('player_id');
      _savedPlayerName = prefs.getString('player_name');
      _savedGameId = prefs.getString('game_id');
      _isLoading = false;
    });
  }

  bool get _canRejoin =>
      _savedPlayerId != null &&
      _savedPlayerName != null &&
      _savedGameId != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Spacer(flex: 2),

            // Logo
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
              child: Image.asset(
                'assets/AppIconTransparent',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),

            // Title
            const Text(
              'Impostor',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF08C8E9),
              ),
            ),
            const SizedBox(height: 8),

            // Tagline
            const Text(
              'Can you blend in?',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFFB0B0B0),
              ),
            ),

            const Spacer(flex: 3),

            if (_isLoading)
              const CircularProgressIndicator(color: Color(0xFF08C8E9))
            else ...[
              // Rejoin button (only shows if saved session exists)
              if (_canRejoin) ...[
                ElevatedButton(
                  onPressed: () async {
                    final apiService = ApiService();
                    final result = await apiService.rejoinGame(
                      _savedPlayerId!,
                      _savedGameId!,
                    );

                    if (result != null) {
                      final phase = result['phase'] as String;

                      if (phase == 'lobby') {
                        // Lobby: let LobbyScreen handle its own WebSocket
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LobbyScreen(
                              playerId: _savedPlayerId!,
                              playerName: _savedPlayerName!,
                              gameId: _savedGameId!,
                              isHost: result['is_host'],
                              existingPlayers: List<String>.from(
                                (result['players'] as List).map((p) => p['name']),
                              ),
                            ),
                          ),
                        );
                      } else {
                        // Mid-game: create WebSocket and go to GameScreen
                        final wsService = WebSocketService();
                        wsService.connect(_savedGameId!, _savedPlayerId!);

                        // Build GameSession from rejoin data
                        final sessionData = result['session'];
                        GameSession? rejoinSession;
                        if (sessionData != null) {
                          rejoinSession = GameSession.fromJson(sessionData);
                        }

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GameScreen(
                              playerId: _savedPlayerId!,
                              playerName: _savedPlayerName!,
                              gameId: _savedGameId!,
                              isHost: result['is_host'],
                              webSocketService: wsService,
                              rejoinSession: rejoinSession,
                              rejoinPhase: phase,
                            ),
                          ),
                        );
                      }
                    } else {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('game_id');
                      setState(() {
                        _savedGameId = null;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Game no longer exists')),
                      );
                    }
                  },
                  child: Text('Rejoin Game ($_savedGameId)'),
                ),
                const SizedBox(height: 16),
              ],

              // Normal start button
              if (_canRejoin)
                OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(),
                      ),
                    );
                  },
                  child: const Text('New Game'),
                )
              else
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(),
                      ),
                    );
                  },
                  child: const Text('Start'),
                ),
            ],

            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}