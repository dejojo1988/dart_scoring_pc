class Player {
  final String id;
  final String name;
  final String? customNameAudioPath;

  const Player({
    required this.id,
    required this.name,
    this.customNameAudioPath,
  });

  Player copyWith({
    String? id,
    String? name,
    String? customNameAudioPath,
    bool clearCustomNameAudioPath = false,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      customNameAudioPath: clearCustomNameAudioPath
          ? null
          : customNameAudioPath ?? this.customNameAudioPath,
    );
  }

  factory Player.guest(int number) {
    return Player(
      id: 'guest_$number',
      name: 'Gast $number',
    );
  }
}