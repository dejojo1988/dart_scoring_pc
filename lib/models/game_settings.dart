enum GameType {
  x01,
  roundTheClock,
}

enum X01StartScore {
  score301,
  score501,
}

enum InMode {
  straightIn,
  doubleIn,
}

enum OutMode {
  straightOut,
  doubleOut,
}

enum MatchMode {
  bestOf,
  firstTo,
}

enum MatchUnit {
  legs,
  sets,
}

class GameSettings {
  final GameType gameType;
  final X01StartScore x01StartScore;
  final InMode inMode;
  final OutMode outMode;

  final MatchMode matchMode;
  final MatchUnit matchUnit;
  final int matchTarget;

  const GameSettings({
    required this.gameType,
    required this.x01StartScore,
    required this.inMode,
    required this.outMode,
    required this.matchMode,
    required this.matchUnit,
    required this.matchTarget,
  });

  int get startScore {
    switch (x01StartScore) {
      case X01StartScore.score301:
        return 301;
      case X01StartScore.score501:
        return 501;
    }
  }

  String get gameTitle {
    switch (gameType) {
      case GameType.x01:
        return '$startScore x01';
      case GameType.roundTheClock:
        return 'Round the Clock';
    }
  }

  String get inModeLabel {
    switch (inMode) {
      case InMode.straightIn:
        return 'Straight In';
      case InMode.doubleIn:
        return 'Double In';
    }
  }

  String get outModeLabel {
    switch (outMode) {
      case OutMode.straightOut:
        return 'Straight Out';
      case OutMode.doubleOut:
        return 'Double Out';
    }
  }

  String get matchModeLabel {
    switch (matchMode) {
      case MatchMode.bestOf:
        return 'Best of';
      case MatchMode.firstTo:
        return 'First to';
    }
  }

  String get matchUnitLabel {
    switch (matchUnit) {
      case MatchUnit.legs:
        return 'Legs';
      case MatchUnit.sets:
        return 'Sets';
    }
  }

  String get matchFormatLabel {
    return '$matchModeLabel $matchTarget $matchUnitLabel';
  }

  int get neededToWin {
    switch (matchMode) {
      case MatchMode.firstTo:
        return matchTarget;
      case MatchMode.bestOf:
        return (matchTarget ~/ 2) + 1;
    }
  }

  GameSettings copyWith({
    GameType? gameType,
    X01StartScore? x01StartScore,
    InMode? inMode,
    OutMode? outMode,
    MatchMode? matchMode,
    MatchUnit? matchUnit,
    int? matchTarget,
  }) {
    return GameSettings(
      gameType: gameType ?? this.gameType,
      x01StartScore: x01StartScore ?? this.x01StartScore,
      inMode: inMode ?? this.inMode,
      outMode: outMode ?? this.outMode,
      matchMode: matchMode ?? this.matchMode,
      matchUnit: matchUnit ?? this.matchUnit,
      matchTarget: matchTarget ?? this.matchTarget,
    );
  }

  factory GameSettings.defaultX01() {
    return const GameSettings(
      gameType: GameType.x01,
      x01StartScore: X01StartScore.score501,
      inMode: InMode.straightIn,
      outMode: OutMode.doubleOut,
      matchMode: MatchMode.bestOf,
      matchUnit: MatchUnit.legs,
      matchTarget: 3,
    );
  }

  factory GameSettings.defaultRoundTheClock() {
    return const GameSettings(
      gameType: GameType.roundTheClock,
      x01StartScore: X01StartScore.score501,
      inMode: InMode.straightIn,
      outMode: OutMode.straightOut,
      matchMode: MatchMode.bestOf,
      matchUnit: MatchUnit.legs,
      matchTarget: 1,
    );
  }
}