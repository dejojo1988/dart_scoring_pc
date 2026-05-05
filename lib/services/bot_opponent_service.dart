import 'dart:math';

import '../models/dart_throw.dart';
import '../models/game_settings.dart';

class BotSkillProfile {
  final double targetAverage;
  final double consistency;
  final double checkoutChance;
  final double missChance;
  final String levelLabel;

  const BotSkillProfile({
    required this.targetAverage,
    required this.consistency,
    required this.checkoutChance,
    required this.missChance,
    required this.levelLabel,
  });

  factory BotSkillProfile.fromPlayerAverage({
    required double? playerAverage,
  }) {
    final double rawAverage = playerAverage ?? 0;

    final bool hasUsefulAverage = rawAverage >= 15;
    final double average = hasUsefulAverage
        ? rawAverage.clamp(25.0, 85.0).toDouble()
        : 45.0;

    final double normalized = ((average - 25.0) / 60.0)
        .clamp(0.0, 1.0)
        .toDouble();

    String label;

    if (average < 35) {
      label = 'Einsteiger';
    } else if (average < 50) {
      label = 'Locker';
    } else if (average < 65) {
      label = 'Stark';
    } else {
      label = 'Brutal';
    }

    return BotSkillProfile(
      targetAverage: average,
      consistency: 0.38 + normalized * 0.42,
      checkoutChance: 0.10 + normalized * 0.48,
      missChance: 0.16 - normalized * 0.13,
      levelLabel: label,
    );
  }
}

/// Alte Kompatibilität, falls irgendwo noch BotOpponentProfile benutzt wird.
/// Intern läuft ab jetzt alles über BotSkillProfile.
class BotOpponentProfile extends BotSkillProfile {
  const BotOpponentProfile({
    required super.targetAverage,
    required super.consistency,
    required super.checkoutChance,
    required super.missChance,
    required String label,
  }) : super(levelLabel: label);

  String get label => levelLabel;

  factory BotOpponentProfile.fromHumanStats(Map<String, num>? stats) {
    final double rawAverage = (stats?['average'] ?? 0).toDouble();
    final int turnCount = (stats?['turn_count'] ?? 0).toInt();

    final bool hasUsefulStats = turnCount >= 5 && rawAverage >= 15;
    final double average = hasUsefulStats
        ? rawAverage.clamp(25.0, 85.0).toDouble()
        : 45.0;

    final BotSkillProfile profile = BotSkillProfile.fromPlayerAverage(
      playerAverage: average,
    );

    return BotOpponentProfile(
      targetAverage: profile.targetAverage,
      consistency: profile.consistency,
      checkoutChance: profile.checkoutChance,
      missChance: profile.missChance,
      label: profile.levelLabel,
    );
  }
}

class BotOpponentService {
  final Random _random = Random();

  BotSkillProfile _skillProfile = BotSkillProfile.fromPlayerAverage(
    playerAverage: null,
  );

  BotOpponentService();

  BotSkillProfile get skillProfile => _skillProfile;

  void updateSkill(BotSkillProfile nextProfile) {
    _skillProfile = nextProfile;
  }

  static bool isBotPlayerId(String playerId) {
    return playerId.startsWith('bot_');
  }

  DartThrow generateX01Throw({
    required int remainingScore,
    required bool doubleOut,
    required bool doubleIn,
    required bool playerIsIn,
  }) {
    if (remainingScore <= 0) {
      return const DartThrow(type: DartThrowType.miss);
    }

    if (_random.nextDouble() < _skillProfile.missChance) {
      return const DartThrow(type: DartThrowType.miss);
    }

    if (doubleIn && !playerIsIn) {
      return _generateDoubleInAttempt(
        profile: _skillProfile,
        random: _random,
      );
    }

    final DartThrow? finishDart = _tryGenerateFinishDart(
      profile: _skillProfile,
      remainingScore: remainingScore,
      doubleOut: doubleOut,
      random: _random,
    );

    if (finishDart != null) {
      return finishDart;
    }

    final double perDartTarget = _skillProfile.targetAverage / 3.0;
    final double variance = (1.0 - _skillProfile.consistency) * 22.0 + 5.0;

    final double noise =
        (_random.nextDouble() - 0.5 + _random.nextDouble() - 0.5) * variance;

    final int wantedScore = (perDartTarget + noise)
        .round()
        .clamp(1, 60)
        .toInt();

    return _pickClosestSafeDart(
      wantedScore: wantedScore,
      remainingScore: remainingScore,
      doubleOut: doubleOut,
      random: _random,
    );
  }

  /// Kompatibilität für ältere Stellen, falls noch ganze Bot-Turns generiert werden.
  static List<DartThrow> generateTurn({
    required BotOpponentProfile profile,
    required GameSettings settings,
    required int remainingScore,
    required bool playerIsIn,
    required Random random,
  }) {
    final List<DartThrow> darts = [];
    int simulatedRemaining = remainingScore;
    bool simulatedPlayerIsIn = playerIsIn;

    for (int dartIndex = 0; dartIndex < 3; dartIndex++) {
      if (simulatedRemaining <= 0) {
        break;
      }

      final DartThrow dartThrow = _generateSingleDart(
        profile: profile,
        settings: settings,
        remainingScore: simulatedRemaining,
        playerIsIn: simulatedPlayerIsIn,
        random: random,
      );

      darts.add(dartThrow);

      if (settings.inMode == InMode.doubleIn && !simulatedPlayerIsIn) {
        if (dartThrow.isDouble) {
          simulatedPlayerIsIn = true;
          simulatedRemaining -= dartThrow.score;
        }
      } else {
        simulatedRemaining -= dartThrow.score;
      }

      if (_isFinishingThrow(
        settings: settings,
        remainingAfterThrow: simulatedRemaining,
        dartThrow: dartThrow,
      )) {
        break;
      }

      if (_isBust(
        settings: settings,
        remainingAfterThrow: simulatedRemaining,
        dartThrow: dartThrow,
      )) {
        break;
      }
    }

    return darts;
  }

  static DartThrow _generateSingleDart({
    required BotSkillProfile profile,
    required GameSettings settings,
    required int remainingScore,
    required bool playerIsIn,
    required Random random,
  }) {
    if (random.nextDouble() < profile.missChance) {
      return const DartThrow(type: DartThrowType.miss);
    }

    if (settings.inMode == InMode.doubleIn && !playerIsIn) {
      return _generateDoubleInAttempt(
        profile: profile,
        random: random,
      );
    }

    final DartThrow? finishDart = _tryGenerateFinishDart(
      profile: profile,
      remainingScore: remainingScore,
      doubleOut: settings.outMode == OutMode.doubleOut,
      random: random,
    );

    if (finishDart != null) {
      return finishDart;
    }

    final double perDartTarget = profile.targetAverage / 3.0;
    final double variance = (1.0 - profile.consistency) * 22.0 + 5.0;

    final double noise =
        (random.nextDouble() - 0.5 + random.nextDouble() - 0.5) * variance;

    final int wantedScore = (perDartTarget + noise)
        .round()
        .clamp(1, 60)
        .toInt();

    return _pickClosestSafeDart(
      wantedScore: wantedScore,
      remainingScore: remainingScore,
      doubleOut: settings.outMode == OutMode.doubleOut,
      random: random,
    );
  }

  static DartThrow _generateDoubleInAttempt({
    required BotSkillProfile profile,
    required Random random,
  }) {
    final double chanceToHitDouble = 0.20 + profile.consistency * 0.45;

    if (random.nextDouble() > chanceToHitDouble) {
      if (random.nextBool()) {
        return const DartThrow(type: DartThrowType.miss);
      }

      return DartThrow(
        type: DartThrowType.single,
        number: 1 + random.nextInt(20),
      );
    }

    final List<int> preferredDoubles = [
      20,
      16,
      18,
      12,
      10,
      8,
      6,
      4,
      2,
      1,
    ];

    return DartThrow(
      type: DartThrowType.double,
      number: preferredDoubles[random.nextInt(preferredDoubles.length)],
    );
  }

  static DartThrow? _tryGenerateFinishDart({
    required BotSkillProfile profile,
    required int remainingScore,
    required bool doubleOut,
    required Random random,
  }) {
    final List<DartThrow> exactDarts = _legalDarts().where((dartThrow) {
      if (dartThrow.score != remainingScore) {
        return false;
      }

      if (doubleOut) {
        return dartThrow.isDouble;
      }

      return true;
    }).toList();

    if (exactDarts.isEmpty) {
      return null;
    }

    if (random.nextDouble() > profile.checkoutChance) {
      return null;
    }

    exactDarts.sort(
      (a, b) => _finishPreferenceScore(b).compareTo(
        _finishPreferenceScore(a),
      ),
    );

    return exactDarts.first;
  }

  static int _finishPreferenceScore(DartThrow dartThrow) {
    if (dartThrow.type == DartThrowType.bull) {
      return 100;
    }

    if (dartThrow.type == DartThrowType.double) {
      final int number = dartThrow.number ?? 0;

      if (number == 20) {
        return 90;
      }

      if (number == 16) {
        return 85;
      }

      if (number == 8) {
        return 80;
      }

      return 60 + number;
    }

    return dartThrow.score;
  }

  static DartThrow _pickClosestSafeDart({
    required int wantedScore,
    required int remainingScore,
    required bool doubleOut,
    required Random random,
  }) {
    final List<DartThrow> candidates = _legalDarts().where((dartThrow) {
      if (dartThrow.type == DartThrowType.miss) {
        return false;
      }

      final int remainingAfterThrow = remainingScore - dartThrow.score;

      if (remainingAfterThrow < 0) {
        return false;
      }

      if (doubleOut) {
        if (remainingAfterThrow == 1) {
          return false;
        }

        if (remainingAfterThrow == 0 && !dartThrow.isDouble) {
          return false;
        }
      }

      return true;
    }).toList();

    if (candidates.isEmpty) {
      return const DartThrow(type: DartThrowType.miss);
    }

    candidates.sort((a, b) {
      final int distanceA = (a.score - wantedScore).abs();
      final int distanceB = (b.score - wantedScore).abs();

      if (distanceA != distanceB) {
        return distanceA.compareTo(distanceB);
      }

      return b.score.compareTo(a.score);
    });

    final int pickRange = min(5, candidates.length);
    return candidates[random.nextInt(pickRange)];
  }

  static bool _isFinishingThrow({
    required GameSettings settings,
    required int remainingAfterThrow,
    required DartThrow dartThrow,
  }) {
    if (remainingAfterThrow != 0) {
      return false;
    }

    if (settings.outMode == OutMode.doubleOut) {
      return dartThrow.isDouble;
    }

    return true;
  }

  static bool _isBust({
    required GameSettings settings,
    required int remainingAfterThrow,
    required DartThrow dartThrow,
  }) {
    if (remainingAfterThrow < 0) {
      return true;
    }

    if (settings.outMode == OutMode.doubleOut) {
      if (remainingAfterThrow == 1) {
        return true;
      }

      if (remainingAfterThrow == 0 && !dartThrow.isDouble) {
        return true;
      }
    }

    return false;
  }

  static List<DartThrow> _legalDarts() {
    return [
      const DartThrow(type: DartThrowType.miss),
      const DartThrow(type: DartThrowType.outer),
      const DartThrow(type: DartThrowType.bull),
      for (int number = 1; number <= 20; number++)
        DartThrow(
          type: DartThrowType.single,
          number: number,
        ),
      for (int number = 1; number <= 20; number++)
        DartThrow(
          type: DartThrowType.double,
          number: number,
        ),
      for (int number = 1; number <= 20; number++)
        DartThrow(
          type: DartThrowType.triple,
          number: number,
        ),
    ];
  }
}