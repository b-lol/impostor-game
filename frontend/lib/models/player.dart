class Player {
  final String id;
  final String name;
  int points;

  Player({
    required this.id,
    required this.name,
    this.points = 0,
  });

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'],
      name: json['name'],
      points: json['points'] ?? 0,
    );
  }
}