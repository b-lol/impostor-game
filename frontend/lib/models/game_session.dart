class PlayerInfo {
  final String id;
  final String name;

  PlayerInfo({required this.id, required this.name});

  factory PlayerInfo.fromJson(Map<String, dynamic> json) {
    return PlayerInfo(
      id: json['id'],
      name: json['name'],
    );
  }
}

class GameSession {
  final String visitorRole;
  final String? secretWord;
  final List<PlayerInfo> turnOrder;
  String currentTurn;
  String currentTurnId;
  int clueTimer;

  GameSession({
    required this.visitorRole,
    this.secretWord,
    required this.turnOrder,
    required this.currentTurn,
    required this.currentTurnId,
    required this.clueTimer,
  });

  factory GameSession.fromJson(Map<String, dynamic> json) {
    return GameSession(
      visitorRole: json['role'],
      secretWord: json['word'],
      turnOrder: (json['turn_order'] as List)
          .map((p) => PlayerInfo.fromJson(p))
          .toList(),
      currentTurn: json['current_turn'],
      currentTurnId: json['current_turn_id'],
      clueTimer: json['clue_timer'],
    );
  }

  bool get isImpostor => visitorRole == 'impostor';
}