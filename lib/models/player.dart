class Player {
  final String id;
  final String name;

  const Player({
    required this.id,
    required this.name,
  });

  Player copyWith({
    String? id,
    String? name,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  factory Player.guest(int number) {
    return Player(
      id: 'guest_$number',
      name: 'Gast $number',
    );
  }
}