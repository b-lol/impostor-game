import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Change this to your server's IP if testing on a real phone
  static const String baseUrl = 'https://impostor-game-production-b1a9.up.railway.app';

  // Register a new player
  Future<String?> registerPlayer(String name) async {
    final response = await http.post(
      Uri.parse('$baseUrl/player/register?name=$name'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['player_id'];
    }
    return null;
  }

  // Create a new game
  Future<String?> createGame({
    required String hostId,
    required int maxRound,
    required int clueTime,
    required String secretCategory,
  }) async {
    final response = await http.post(
      Uri.parse(
        '$baseUrl/game/create?host_id=$hostId&max_round=$maxRound&clue_time=$clueTime&secret_category=$secretCategory',
      ),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['game_id'];
    }
    return null;
  }

  // Join a game
  Future<List<String>?> joinGame(String playerId, String gameId) async {
  final response = await http.post(
    Uri.parse('$baseUrl/game/join?player_id=$playerId&game_id=$gameId'),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    if (data['players'] != null) {
      return List<String>.from(
        (data['players'] as List).map((p) => p['name'])
      );
    }
    return [];
  }
  return null;  // null means failed
}

  // Start the game
  Future<bool> startGame(String gameId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/game/start?game_id=$gameId'),
    );

    return response.statusCode == 200;
  }

  // Start a session
  Future<bool> startSession(String gameId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/session/start?game_id=$gameId'),
    );

    return response.statusCode == 200;
  }
}