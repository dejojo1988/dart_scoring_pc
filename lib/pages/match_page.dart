import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../models/checkout_advisor.dart';
import '../models/dart_throw.dart';
import '../models/game_settings.dart';
import '../models/player.dart';
import '../services/audio_service.dart';
import '../services/bot_opponent_service.dart';
import '../widgets/dart_input_grid.dart';
import '../widgets/player_score_card.dart';

class MatchPage extends StatefulWidget {
  final GameSettings settings;
  final List<Player> players;
  final Player startingPlayer;

  const MatchPage({
    super.key,
    required this.settings,
    required this.players,
    required this.startingPlayer,
  });

  @override
  State<MatchPage> createState() => _MatchPageState();
}

class _DartTurnRecord {
  final String playerId;
  final String gameType;
  final int turnScore;
  final int dartCount;
  final String createdAt;

  const _DartTurnRecord({
    required this.playerId,
    required this.gameType,
    required this.turnScore,
    required this.dartCount,
    required this.createdAt,
  });

  Map<String, Object> toMap() {
    return {
      'player_id': playerId,
      'game_type': gameType,
      'turn_score': turnScore,
      'dart_count': dartCount,
      'created_at': createdAt,
    };
  }
}

class _X01DartRecord {
  final String matchId;
  final int legNumber;
  final int turnNumber;
  final int dartIndex;
  final String playerId;
  final String dartLabel;
  final int dartScore;
  final int remainingBefore;
  final int remainingAfter;
  final bool isBust;
  final bool isCheckoutDart;
  final int checkoutScore;
  final String createdAt;

  const _X01DartRecord({
    required this.matchId,
    required this.legNumber,
    required this.turnNumber,
    required this.dartIndex,
    required this.playerId,
    required this.dartLabel,
    required this.dartScore,
    required this.remainingBefore,
    required this.remainingAfter,
    required this.isBust,
    required this.isCheckoutDart,
    required this.checkoutScore,
    required this.createdAt,
  });

  Map<String, Object> toMap() {
    return {
      'match_id': matchId,
      'leg_number': legNumber,
      'turn_number': turnNumber,
      'dart_index': dartIndex,
      'player_id': playerId,
      'dart_label': dartLabel,
      'dart_score': dartScore,
      'remaining_before': remainingBefore,
      'remaining_after': remainingAfter,
      'is_bust': isBust ? 1 : 0,
      'is_checkout_dart': isCheckoutDart ? 1 : 0,
      'checkout_score': checkoutScore,
      'created_at': createdAt,
    };
  }
}

class _MatchSnapshot {
  final int activePlayerIndex;
  final Map<String, int> remainingScores;
  final Map<String, int> legsWon;
  final Map<String, int> matchLegsWon;
  final Map<String, int> setsWon;
  final Map<String, bool> playerIsIn;
  final List<DartThrow> currentTurnDarts;
  final List<_DartTurnRecord> recordedTurns;
  final List<_X01DartRecord> recordedX01Darts;
  final int turnStartScore;
  final int currentLegNumber;
  final int currentTurnNumber;
  final bool turnStartedPlayerIsIn;
  final int currentLegStartingPlayerIndex;
  final Map<String, int> matchPointsScored;
  final Map<String, int> matchDartsThrown;
  final Map<String, int> legPointsScored;
  final Map<String, int> legDartsThrown;
  final Map<String, int> matchClassicCounts;
  final Map<String, int> legClassicCounts;
  final Map<String, int> lastTurnScore;
  final Map<String, String> lastTurnText;
  final String message;
  final bool matchFinished;
  final Player? matchWinner;

  const _MatchSnapshot({
    required this.activePlayerIndex,
    required this.remainingScores,
    required this.legsWon,
    required this.matchLegsWon,
    required this.setsWon,
    required this.playerIsIn,
    required this.currentTurnDarts,
    required this.recordedTurns,
    required this.recordedX01Darts,
    required this.turnStartScore,
    required this.currentLegNumber,
    required this.currentTurnNumber,
    required this.turnStartedPlayerIsIn,
    required this.currentLegStartingPlayerIndex,
    required this.matchPointsScored,
    required this.matchDartsThrown,
    required this.legPointsScored,
    required this.legDartsThrown,
    required this.matchClassicCounts,
    required this.legClassicCounts,
    required this.lastTurnScore,
    required this.lastTurnText,
    required this.message,
    required this.matchFinished,
    required this.matchWinner,
  });
}

class _MatchPageState extends State<MatchPage> {
  static const int legsNeededToWinSet = 2;

  late int activePlayerIndex;
  late Map<String, int> remainingScores;
  late Map<String, int> legsWon;
  late Map<String, int> matchLegsWon;
  late Map<String, int> setsWon;
  late Map<String, bool> playerIsIn;
  late int turnStartScore;
  late String matchId;
  late int currentLegNumber;
  late int currentTurnNumber;
  late int currentLegStartingPlayerIndex;
  late bool turnStartedPlayerIsIn;
  late Map<String, int> matchPointsScored;
  late Map<String, int> matchDartsThrown;
  late Map<String, int> legPointsScored;
  late Map<String, int> legDartsThrown;
  late Map<String, int> matchClassicCounts;
  late Map<String, int> legClassicCounts;
  late Map<String, int> lastTurnScore;
  late Map<String, String> lastTurnText;

  final List<DartThrow> currentTurnDarts = [];
  final List<_DartTurnRecord> recordedTurns = [];
  final List<_X01DartRecord> recordedX01Darts = [];
  final List<_MatchSnapshot> history = [];

  final BotOpponentService botOpponentService = BotOpponentService();

  String message = 'Match gestartet.';
  bool matchFinished = false;
  bool matchResultSaved = false;
  bool botSkillLoaded = false;
  bool gameStartAnnouncementFinished = false;
  bool botTurnRunning = false;
  bool turnIntroAnnouncementRunning = false;
  bool turnSummaryRunning = false;
  bool turnSummaryIsBust = false;
  int botSequenceToken = 0;
  int turnIntroAnnouncementToken = 0;
  int activeBotDisplayIndex = -1;
  int turnSummaryScore = 0;
  String botDisplayStatus = 'Bot bereitet den Wurf vor.';
  String turnSummaryPlayerName = '';
  String turnSummaryTitle = 'AUFNAHME';
  String turnSummarySubtitle = '';
  final List<DartThrow?> botDisplayDarts = List<DartThrow?>.filled(3, null);
  List<DartThrow> turnSummaryDarts = [];
  Player? matchWinner;

  @override
  void initState() {
    super.initState();

    final int startIndex = widget.players.indexWhere(
      (player) => player.id == widget.startingPlayer.id,
    );

    activePlayerIndex = startIndex >= 0 ? startIndex : 0;
    currentLegStartingPlayerIndex = activePlayerIndex;
    matchId = 'match_${DateTime.now().millisecondsSinceEpoch}';
    currentLegNumber = 1;
    currentTurnNumber = 1;

    remainingScores = {
      for (final player in widget.players) player.id: widget.settings.startScore,
    };

    legsWon = {
      for (final player in widget.players) player.id: 0,
    };

    matchLegsWon = {
      for (final player in widget.players) player.id: 0,
    };

    setsWon = {
      for (final player in widget.players) player.id: 0,
    };

    playerIsIn = {
      for (final player in widget.players)
        player.id: widget.settings.inMode == InMode.straightIn,
    };

    matchPointsScored = {
      for (final player in widget.players) player.id: 0,
    };

    matchDartsThrown = {
      for (final player in widget.players) player.id: 0,
    };

    legPointsScored = {
      for (final player in widget.players) player.id: 0,
    };

    legDartsThrown = {
      for (final player in widget.players) player.id: 0,
    };

    matchClassicCounts = {
      for (final player in widget.players) player.id: 0,
    };

    legClassicCounts = {
      for (final player in widget.players) player.id: 0,
    };

    lastTurnScore = {
      for (final player in widget.players) player.id: 0,
    };

    lastTurnText = {
      for (final player in widget.players) player.id: '-',
    };

    turnStartScore =
        remainingScores[activePlayer.id] ?? widget.settings.startScore;
    turnStartedPlayerIsIn = activePlayerIsIn;

    message = '${activePlayer.name} beginnt.';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runMatchStartSequence());
    });
  }

  @override
  void dispose() {
    botSequenceToken++;
    turnIntroAnnouncementToken++;
    super.dispose();
  }

  Player get activePlayer {
    return widget.players[activePlayerIndex];
  }

  Color get accentColor => Theme.of(context).colorScheme.primary;

  bool get activePlayerIsBot {
    return _isBotPlayer(activePlayer);
  }

  bool get hasBotOpponent {
    return widget.players.any(_isBotPlayer);
  }

  int get activeRemainingScore {
    return remainingScores[activePlayer.id] ?? widget.settings.startScore;
  }

  List<Player> get scorePanelPlayers {
    if (widget.players.isEmpty) {
      return [];
    }

    return [
      for (int index = 0; index < widget.players.length; index++)
        widget.players[(activePlayerIndex + index) % widget.players.length],
    ];
  }

  String _audioLabelForPlayer(Player player) {
    if (_isBotPlayer(player)) {
      return 'Bot Gegner';
    }

    final List<Player> playersInAudioOrder = _playersInAudioOrder();

    final int playerIndex = playersInAudioOrder.indexWhere(
      (currentPlayer) => currentPlayer.id == player.id,
    );

    final int playerNumber = playerIndex >= 0 ? playerIndex + 1 : 1;

    return 'Spieler $playerNumber';
  }

  List<Player> _playersInAudioOrder() {
    if (widget.players.isEmpty) {
      return [];
    }

    final int startIndex = widget.players.indexWhere(
      (player) => player.id == widget.startingPlayer.id,
    );

    final int safeStartIndex = startIndex >= 0 ? startIndex : 0;

    final List<Player> orderedPlayers = [
      for (int index = 0; index < widget.players.length; index++)
        widget.players[(safeStartIndex + index) % widget.players.length],
    ];

    return orderedPlayers.where((player) {
      return !_isBotPlayer(player);
    }).toList();
  }

  bool _isBotPlayer(Player player) {
    return player.id.startsWith('bot_');
  }

  Player? get _mainHumanPlayer {
    for (final Player player in widget.players) {
      if (!_isBotPlayer(player) && player.id.startsWith('profile_')) {
        return player;
      }
    }

    for (final Player player in widget.players) {
      if (!_isBotPlayer(player)) {
        return player;
      }
    }

    return null;
  }


  Future<void> _runMatchStartSequence() async {
    await _loadBotSkillFromCurrentPlayerStats();

    if (!mounted) {
      return;
    }

    await AudioService.instance.announceGameStart(
      startingPlayerName: _audioLabelForPlayer(activePlayer),
      startScore: widget.settings.startScore,
    );

    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (!mounted) {
      return;
    }

    setState(() {
      gameStartAnnouncementFinished = true;
    });

    _maybeStartBotTurn();
  }

  int get currentTurnScore {
    return currentTurnDarts.fold<int>(
      0,
      (sum, dartThrow) => sum + dartThrow.score,
    );
  }

  bool get usesDoubleOut {
    return widget.settings.outMode == OutMode.doubleOut;
  }

  bool get usesDoubleIn {
    return widget.settings.inMode == InMode.doubleIn;
  }

  bool get activePlayerIsIn {
    return playerIsIn[activePlayer.id] ?? false;
  }

  String get matchProgressLabel {
    if (widget.settings.matchUnit == MatchUnit.legs) {
      return widget.settings.matchFormatLabel;
    }

    return '${widget.settings.matchFormatLabel} · $legsNeededToWinSet Legs pro Set';
  }

  Future<void> _loadBotSkillFromCurrentPlayerStats() async {
    if (!hasBotOpponent || botSkillLoaded) {
      return;
    }

    final Player? humanPlayer = _mainHumanPlayer;
    double? playerAverage;

    if (humanPlayer != null && humanPlayer.id.startsWith('profile_')) {
      try {
        final Map<String, Map<String, num>> allDartStats =
            await AppDatabase.instance.getAllPlayerDartStats();

        final Map<String, num>? playerStats = allDartStats[humanPlayer.id];
        final num? rawAverage = playerStats == null ? null : playerStats['average'];

        if (rawAverage != null && rawAverage > 0) {
          playerAverage = rawAverage.toDouble();
        }
      } catch (_) {
        playerAverage = null;
      }
    }

    final BotSkillProfile nextSkillProfile =
        BotSkillProfile.fromPlayerAverage(playerAverage: playerAverage);

    botOpponentService.updateSkill(nextSkillProfile);

    if (!mounted) {
      return;
    }

    setState(() {
      botSkillLoaded = true;

      if (hasBotOpponent) {
        message =
            'Bot aktiv: ${nextSkillProfile.levelLabel} · Ø ${nextSkillProfile.targetAverage.toStringAsFixed(1)}.';
      }
    });
  }

  void _saveSnapshot() {
    history.add(
      _MatchSnapshot(
        activePlayerIndex: activePlayerIndex,
        remainingScores: Map<String, int>.from(remainingScores),
        legsWon: Map<String, int>.from(legsWon),
        matchLegsWon: Map<String, int>.from(matchLegsWon),
        setsWon: Map<String, int>.from(setsWon),
        playerIsIn: Map<String, bool>.from(playerIsIn),
        currentTurnDarts: List<DartThrow>.from(currentTurnDarts),
        recordedTurns: List<_DartTurnRecord>.from(recordedTurns),
        recordedX01Darts: List<_X01DartRecord>.from(recordedX01Darts),
        turnStartScore: turnStartScore,
        currentLegNumber: currentLegNumber,
        currentTurnNumber: currentTurnNumber,
        turnStartedPlayerIsIn: turnStartedPlayerIsIn,
        currentLegStartingPlayerIndex: currentLegStartingPlayerIndex,
        matchPointsScored: Map<String, int>.from(matchPointsScored),
        matchDartsThrown: Map<String, int>.from(matchDartsThrown),
        legPointsScored: Map<String, int>.from(legPointsScored),
        legDartsThrown: Map<String, int>.from(legDartsThrown),
        matchClassicCounts: Map<String, int>.from(matchClassicCounts),
        legClassicCounts: Map<String, int>.from(legClassicCounts),
        lastTurnScore: Map<String, int>.from(lastTurnScore),
        lastTurnText: Map<String, String>.from(lastTurnText),
        message: message,
        matchFinished: matchFinished,
        matchWinner: matchWinner,
      ),
    );
  }

  void _maybeStartBotTurn() {
    if (!mounted ||
        !gameStartAnnouncementFinished ||
        matchFinished ||
        turnIntroAnnouncementRunning ||
        turnSummaryRunning ||
        !activePlayerIsBot ||
        botTurnRunning) {
      return;
    }

    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (!mounted ||
          !gameStartAnnouncementFinished ||
          matchFinished ||
          turnIntroAnnouncementRunning ||
          turnSummaryRunning ||
          !activePlayerIsBot ||
          botTurnRunning) {
        return;
      }

      unawaited(_runBotTurn());
    });
  }

  void _resetBotDisplay() {
    for (int index = 0; index < botDisplayDarts.length; index++) {
      botDisplayDarts[index] = null;
    }

    activeBotDisplayIndex = -1;
    botDisplayStatus = 'Bot bereitet den Wurf vor.';
  }

  Future<void> _runBotTurn() async {
    if (botTurnRunning ||
        turnIntroAnnouncementRunning ||
        turnSummaryRunning ||
        matchFinished ||
        !activePlayerIsBot) {
      return;
    }

    botTurnRunning = true;
    final int sequenceToken = ++botSequenceToken;

    if (mounted) {
      setState(() {
        _resetBotDisplay();
        message =
            '${activePlayer.name} bereitet seinen Wurf vor · Bot-Level ${botOpponentService.skillProfile.levelLabel}.';
      });
    }

    await Future<void>.delayed(const Duration(milliseconds: 1300));

    for (int dartIndex = 0; dartIndex < 3; dartIndex++) {
      if (!mounted ||
          sequenceToken != botSequenceToken ||
          matchFinished ||
          turnSummaryRunning ||
          !activePlayerIsBot) {
        break;
      }

      setState(() {
        activeBotDisplayIndex = dartIndex;
        botDisplayStatus = 'Bot zielt auf Wurf ${dartIndex + 1}.';
      });

      await Future<void>.delayed(const Duration(milliseconds: 1150));

      if (!mounted ||
          sequenceToken != botSequenceToken ||
          matchFinished ||
          turnSummaryRunning ||
          !activePlayerIsBot) {
        break;
      }

      final DartThrow botThrow = botOpponentService.generateX01Throw(
        remainingScore: activeRemainingScore,
        doubleOut: usesDoubleOut,
        doubleIn: usesDoubleIn,
        playerIsIn: activePlayerIsIn,
      );

      setState(() {
        botDisplayDarts[dartIndex] = botThrow;
        botDisplayStatus =
            'Wurf ${dartIndex + 1}: ${botThrow.label} · ${botThrow.score} Punkte';
        message = '${activePlayer.name} wirft ${botThrow.label}.';
      });

      _playDartHitSound(botThrow);

      await Future<void>.delayed(const Duration(milliseconds: 1050));

      if (!mounted ||
          sequenceToken != botSequenceToken ||
          matchFinished ||
          turnSummaryRunning ||
          !activePlayerIsBot) {
        break;
      }

      _handleThrow(
        botThrow,
        triggeredByBot: true,
        playHitSound: false,
      );

      if (turnSummaryRunning || matchFinished || !activePlayerIsBot) {
        break;
      }

      await Future<void>.delayed(const Duration(milliseconds: 650));
    }

    if (mounted &&
        sequenceToken == botSequenceToken &&
        !turnSummaryRunning &&
        !matchFinished) {
      setState(() {
        activeBotDisplayIndex = -1;
        botDisplayStatus = 'Bot-Wurf beendet.';
      });

      await Future<void>.delayed(const Duration(milliseconds: 900));
    }

    botTurnRunning = false;

    if (!mounted || sequenceToken != botSequenceToken) {
      return;
    }

    setState(() {});

    if (!turnSummaryRunning) {
      _maybeStartBotTurn();
    }
  }

  void _playDartHitSound(DartThrow dartThrow) {
    if (dartThrow.type == DartThrowType.miss) {
      unawaited(AudioService.instance.playEvent(AudioEventType.dartMiss));
      return;
    }

    unawaited(AudioService.instance.playEvent(AudioEventType.dartHit));
  }

  void _handleThrow(
    DartThrow dartThrow, {
    bool triggeredByBot = false,
    bool playHitSound = true,
  }) {
    if (matchFinished) {
      _showMessage('Das Match ist bereits beendet.');
      return;
    }

    if (turnSummaryRunning) {
      _showMessage('Die Aufnahme wird gerade abgeschlossen.');
      return;
    }

    if (turnIntroAnnouncementRunning) {
      _showMessage('Warte, bis die Checkout-Ansage fertig ist.');
      return;
    }

    if (activePlayerIsBot && !triggeredByBot) {
      _showMessage('Der Bot ist gerade dran.');
      return;
    }

    if (playHitSound) {
      _playDartHitSound(dartThrow);
    }

    _saveSnapshot();

    final Player throwingPlayer = activePlayer;
    final bool wasPlayerIn = playerIsIn[throwingPlayer.id] ?? false;
    final bool throwOpensDoubleIn = usesDoubleIn && dartThrow.isDouble;

    currentTurnDarts.add(dartThrow);

    if (usesDoubleIn && !wasPlayerIn && !throwOpensDoubleIn) {
      setState(() {
        message =
            '${throwingPlayer.name} ist noch nicht drin. ${dartThrow.label} zählt nicht.';
      });

      if (currentTurnDarts.length >= 3) {
        _recordX01DartsForCurrentTurn(
          player: throwingPlayer,
          isBustTurn: false,
          isCheckoutTurn: false,
          checkoutScore: 0,
        );

        _recordTurnForStats(
          player: throwingPlayer,
          turnScore: 0,
          dartCount: currentTurnDarts.length,
        );

        final List<DartThrow> completedDarts = List<DartThrow>.from(currentTurnDarts);
        currentTurnDarts.clear();

        _startTurnSummaryAndMove(
          player: throwingPlayer,
          turnScore: 0,
          darts: completedDarts,
        );
      }

      return;
    }

    if (usesDoubleIn && !wasPlayerIn && throwOpensDoubleIn) {
      playerIsIn[throwingPlayer.id] = true;
    }

    final int scoreBeforeThrow = activeRemainingScore;
    final int scoreAfterThrow = scoreBeforeThrow - dartThrow.score;

    final bool isBust = _isBust(scoreAfterThrow, dartThrow);

    if (isBust) {
      setState(() {
        remainingScores[throwingPlayer.id] = turnStartScore;
        message = '${throwingPlayer.name} hat sich überworfen. Bust.';
      });

      _recordX01DartsForCurrentTurn(
        player: throwingPlayer,
        isBustTurn: true,
        isCheckoutTurn: false,
        checkoutScore: 0,
      );

      _recordTurnForStats(
        player: throwingPlayer,
        turnScore: 0,
        dartCount: currentTurnDarts.length,
      );

      final List<DartThrow> completedDarts = List<DartThrow>.from(currentTurnDarts);
      currentTurnDarts.clear();

      _startTurnSummaryAndMove(
        player: throwingPlayer,
        turnScore: 0,
        darts: completedDarts,
        isBust: true,
        customMessage: '${throwingPlayer.name} hat sich überworfen. Bust.',
      );

      return;
    }

    if (scoreAfterThrow == 0) {
      setState(() {
        remainingScores[throwingPlayer.id] = 0;
        message = '${throwingPlayer.name} checkt $turnStartScore aus.';
      });

      _recordX01DartsForCurrentTurn(
        player: throwingPlayer,
        isBustTurn: false,
        isCheckoutTurn: true,
        checkoutScore: turnStartScore,
      );

      _recordTurnForStats(
        player: throwingPlayer,
        turnScore: turnStartScore,
        dartCount: currentTurnDarts.length,
      );

      final List<DartThrow> completedDarts = List<DartThrow>.from(currentTurnDarts);
      currentTurnDarts.clear();

      _startTurnSummaryAndHandleLegWin(
        player: throwingPlayer,
        turnScore: turnStartScore,
        darts: completedDarts,
      );

      return;
    }

    setState(() {
      remainingScores[throwingPlayer.id] = scoreAfterThrow;

      if (usesDoubleIn && !wasPlayerIn && throwOpensDoubleIn) {
        message = '${throwingPlayer.name} ist drin. ${dartThrow.label} zählt.';
      } else {
        message = '${throwingPlayer.name}: ${dartThrow.label} eingegeben.';
      }
    });

    if (currentTurnDarts.length >= 3) {
      final int countedScoreThisTurn = turnStartScore - scoreAfterThrow;

      _recordX01DartsForCurrentTurn(
        player: throwingPlayer,
        isBustTurn: false,
        isCheckoutTurn: false,
        checkoutScore: 0,
      );

      _recordTurnForStats(
        player: throwingPlayer,
        turnScore: countedScoreThisTurn,
        dartCount: currentTurnDarts.length,
      );

      final List<DartThrow> completedDarts = List<DartThrow>.from(currentTurnDarts);
      currentTurnDarts.clear();

      _startTurnSummaryAndMove(
        player: throwingPlayer,
        turnScore: countedScoreThisTurn,
        darts: completedDarts,
      );
    }
  }

  void _startTurnSummaryAndMove({
    required Player player,
    required int turnScore,
    required List<DartThrow> darts,
    bool isBust = false,
    String? customMessage,
  }) {
    _showTurnSummary(
      player: player,
      turnScore: turnScore,
      darts: darts,
      isBust: isBust,
    );

    unawaited(
      _runTurnSummarySequence(
        player: player,
        turnScore: turnScore,
        isBust: isBust,
        isClassicTurn: _isClassicTurn(darts),
        onFinished: () {
          _moveToNextPlayer(customMessage: customMessage);
        },
      ),
    );
  }

  void _startTurnSummaryAndHandleLegWin({
    required Player player,
    required int turnScore,
    required List<DartThrow> darts,
  }) {
    _showTurnSummary(
      player: player,
      turnScore: turnScore,
      darts: darts,
    );

    unawaited(
      _runTurnSummarySequence(
        player: player,
        turnScore: turnScore,
        isBust: false,
        isClassicTurn: _isClassicTurn(darts),
        onFinished: () {
          _handleLegWin(player);
        },
      ),
    );
  }

  void _applyLiveTurnStats({
    required Player player,
    required int turnScore,
    required List<DartThrow> darts,
    required bool isBust,
  }) {
    final int dartCount = darts.length;

    if (dartCount <= 0) {
      return;
    }

    final int safeScore = turnScore < 0
        ? 0
        : turnScore > 180
            ? 180
            : turnScore;

    matchPointsScored[player.id] =
        (matchPointsScored[player.id] ?? 0) + safeScore;
    matchDartsThrown[player.id] =
        (matchDartsThrown[player.id] ?? 0) + dartCount;
    legPointsScored[player.id] = (legPointsScored[player.id] ?? 0) + safeScore;
    legDartsThrown[player.id] = (legDartsThrown[player.id] ?? 0) + dartCount;
    lastTurnScore[player.id] = safeScore;

    final String dartLabels = darts.map((dartThrow) => dartThrow.label).join(' · ');
    final bool isClassic = !isBust && _isClassicTurn(darts);

    if (isClassic) {
      matchClassicCounts[player.id] = (matchClassicCounts[player.id] ?? 0) + 1;
      legClassicCounts[player.id] = (legClassicCounts[player.id] ?? 0) + 1;
    }

    if (isBust) {
      lastTurnText[player.id] = 'Bust · $dartLabels';
    } else if (isClassic) {
      lastTurnText[player.id] = 'Classic · $dartLabels';
    } else {
      lastTurnText[player.id] = '$safeScore · $dartLabels';
    }
  }

  bool _isClassicTurn(List<DartThrow> darts) {
    if (darts.length != 3) {
      return false;
    }

    final List<int> classicNumbers = [];

    for (final DartThrow dartThrow in darts) {
      if (dartThrow.type != DartThrowType.single || dartThrow.number == null) {
        return false;
      }

      classicNumbers.add(dartThrow.number!);
    }

    classicNumbers.sort();

    return classicNumbers[0] == 1 &&
        classicNumbers[1] == 5 &&
        classicNumbers[2] == 20;
  }

  double _averageForPlayer({
    required Player player,
    required Map<String, int> points,
    required Map<String, int> darts,
  }) {
    final int pointCount = points[player.id] ?? 0;
    final int dartCount = darts[player.id] ?? 0;

    if (dartCount <= 0) {
      return 0;
    }

    return pointCount / dartCount * 3;
  }

  double _matchAverageForPlayer(Player player) {
    return _averageForPlayer(
      player: player,
      points: matchPointsScored,
      darts: matchDartsThrown,
    );
  }

  double _legAverageForPlayer(Player player) {
    return _averageForPlayer(
      player: player,
      points: legPointsScored,
      darts: legDartsThrown,
    );
  }

  String _lastTurnTextForPlayer(Player player) {
    final String text = lastTurnText[player.id] ?? '-';
    return text.trim().isEmpty ? '-' : text;
  }

  int _classicCountForPlayer(Player player) {
    return matchClassicCounts[player.id] ?? 0;
  }

  String? _statusTextForPlayer(Player player) {
    if (player.id != activePlayer.id || matchFinished) {
      return null;
    }

    if (turnIntroAnnouncementRunning) {
      return 'Ansage läuft · Wurf gesperrt';
    }

    if (turnSummaryRunning) {
      return 'Aufnahme wird abgeschlossen';
    }

    if (activePlayerIsBot || botTurnRunning) {
      return botDisplayStatus;
    }

    return message;
  }

  String? _botInfoForPlayer(Player player) {
    if (!_isBotPlayer(player)) {
      return null;
    }

    return '${botOpponentService.skillProfile.levelLabel} · Ziel-Ø ${botOpponentService.skillProfile.targetAverage.toStringAsFixed(1)}';
  }

  void _showTurnSummary({
    required Player player,
    required int turnScore,
    required List<DartThrow> darts,
    bool isBust = false,
  }) {
    if (!mounted) {
      return;
    }

    setState(() {
      _applyLiveTurnStats(
        player: player,
        turnScore: turnScore,
        darts: darts,
        isBust: isBust,
      );

      turnSummaryRunning = true;
      turnSummaryIsBust = isBust;
      turnSummaryPlayerName = player.name;
      turnSummaryScore = turnScore.clamp(0, 180).toInt();
      turnSummaryDarts = List<DartThrow>.from(darts);
      final bool isClassic = !isBust && _isClassicTurn(darts);
      turnSummaryTitle = isBust
          ? 'BUST'
          : isClassic
              ? 'CLASSIC'
              : _isBotPlayer(player)
                  ? 'BOT-AUFNAHME'
                  : 'AUFNAHME';
      turnSummarySubtitle = isBust
          ? '${player.name} hat sich überworfen.'
          : isClassic
              ? '${player.name} wirft Classic.'
              : '${player.name} wirft $turnScore Punkte.';
      message = turnSummarySubtitle;
    });
  }

  Future<void> _runTurnSummarySequence({
    required Player player,
    required int turnScore,
    required bool isBust,
    required bool isClassicTurn,
    required VoidCallback onFinished,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));

    if (!mounted) {
      return;
    }

    if (isBust) {
      await AudioService.instance.announceBust(
        playerName: _audioLabelForPlayer(player),
      );
    } else {
      await AudioService.instance.announceTurnScore(
        playerName: _audioLabelForPlayer(player),
        turnScore: turnScore,
        isClassic: isClassicTurn,
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 250));

    if (!mounted) {
      return;
    }

    setState(() {
      turnIntroAnnouncementRunning = false;
      turnSummaryRunning = false;
      turnSummaryIsBust = false;
      turnSummaryPlayerName = '';
      turnSummaryScore = 0;
      turnSummaryTitle = 'AUFNAHME';
      turnSummarySubtitle = '';
      turnSummaryDarts = [];
      onFinished();
    });
  }

  bool _shouldPlayCheckoutRequirementAnnouncement(int remainingScore) {
    return remainingScore > 0 && remainingScore <= 160 && !matchFinished;
  }

  Future<void> _announceCurrentPlayerThenMaybeStartBot() async {
    final Player playerToAnnounce = activePlayer;
    final int scoreToAnnounce = activeRemainingScore;
    final bool shouldAnnounceCheckoutRequirement =
        _shouldPlayCheckoutRequirementAnnouncement(scoreToAnnounce);
    final int announcementToken = ++turnIntroAnnouncementToken;

    if (shouldAnnounceCheckoutRequirement && mounted) {
      setState(() {
        turnIntroAnnouncementRunning = true;
        message = '${playerToAnnounce.name} braucht $scoreToAnnounce Punkte.';
      });
    }

    if (shouldAnnounceCheckoutRequirement) {
      await AudioService.instance.announceCheckoutRequirement(
        playerName: _audioLabelForPlayer(playerToAnnounce),
        remainingScore: scoreToAnnounce,
      );
    } else {
      await AudioService.instance.announcePlayerTurn(
        playerName: _audioLabelForPlayer(playerToAnnounce),
        remainingScore: scoreToAnnounce,
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 550));

    if (!mounted || announcementToken != turnIntroAnnouncementToken) {
      return;
    }

    if (turnIntroAnnouncementRunning) {
      setState(() {
        turnIntroAnnouncementRunning = false;
      });
    }

    _maybeStartBotTurn();
  }

  bool _isBust(int scoreAfterThrow, DartThrow dartThrow) {
    if (scoreAfterThrow < 0) {
      return true;
    }

    if (usesDoubleOut) {
      if (scoreAfterThrow == 1) {
        return true;
      }

      if (scoreAfterThrow == 0 && !dartThrow.isDouble) {
        return true;
      }
    }

    return false;
  }

  void _recordX01DartsForCurrentTurn({
    required Player player,
    required bool isBustTurn,
    required bool isCheckoutTurn,
    required int checkoutScore,
  }) {
    if (!player.id.startsWith('profile_')) {
      return;
    }

    if (currentTurnDarts.isEmpty) {
      return;
    }

    final String createdAt = DateTime.now().toIso8601String();

    if (isBustTurn) {
      for (int index = 0; index < currentTurnDarts.length; index++) {
        final DartThrow dartThrow = currentTurnDarts[index];

        recordedX01Darts.add(
          _X01DartRecord(
            matchId: matchId,
            legNumber: currentLegNumber,
            turnNumber: currentTurnNumber,
            dartIndex: index + 1,
            playerId: player.id,
            dartLabel: dartThrow.label,
            dartScore: 0,
            remainingBefore: turnStartScore,
            remainingAfter: turnStartScore,
            isBust: true,
            isCheckoutDart: false,
            checkoutScore: 0,
            createdAt: createdAt,
          ),
        );
      }

      return;
    }

    int simulatedRemaining = turnStartScore;
    bool simulatedPlayerIsIn = turnStartedPlayerIsIn;

    for (int index = 0; index < currentTurnDarts.length; index++) {
      final DartThrow dartThrow = currentTurnDarts[index];
      final int remainingBefore = simulatedRemaining;

      int countedScore = 0;

      if (usesDoubleIn && !simulatedPlayerIsIn) {
        if (dartThrow.isDouble) {
          simulatedPlayerIsIn = true;
          countedScore = dartThrow.score;
          simulatedRemaining -= countedScore;
        }
      } else {
        countedScore = dartThrow.score;
        simulatedRemaining -= countedScore;
      }

      final bool isLastDartOfCheckout =
          isCheckoutTurn && index == currentTurnDarts.length - 1;

      recordedX01Darts.add(
        _X01DartRecord(
          matchId: matchId,
          legNumber: currentLegNumber,
          turnNumber: currentTurnNumber,
          dartIndex: index + 1,
          playerId: player.id,
          dartLabel: dartThrow.label,
          dartScore: countedScore,
          remainingBefore: remainingBefore,
          remainingAfter: isLastDartOfCheckout ? 0 : simulatedRemaining,
          isBust: false,
          isCheckoutDart: isLastDartOfCheckout,
          checkoutScore: isLastDartOfCheckout ? checkoutScore : 0,
          createdAt: createdAt,
        ),
      );
    }
  }

  void _recordTurnForStats({
    required Player player,
    required int turnScore,
    required int dartCount,
  }) {
    if (!player.id.startsWith('profile_')) {
      return;
    }

    if (dartCount <= 0) {
      return;
    }

    final int safeScore = turnScore < 0
        ? 0
        : turnScore > 180
            ? 180
            : turnScore;

    recordedTurns.add(
      _DartTurnRecord(
        playerId: player.id,
        gameType: 'x01',
        turnScore: safeScore,
        dartCount: dartCount,
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
  }

  void _handleLegWin(Player winner) {
    final int newCurrentSetLegsWon = (legsWon[winner.id] ?? 0) + 1;
    final int newTotalMatchLegsWon = (matchLegsWon[winner.id] ?? 0) + 1;

    legsWon[winner.id] = newCurrentSetLegsWon;
    matchLegsWon[winner.id] = newTotalMatchLegsWon;

    if (widget.settings.matchUnit == MatchUnit.legs) {
      _handleLegBasedMatchProgress(winner, newCurrentSetLegsWon);
      return;
    }

    _handleSetBasedMatchProgress(winner, newCurrentSetLegsWon);
  }

  void _handleLegBasedMatchProgress(Player winner, int newLegsWon) {
    if (newLegsWon >= widget.settings.neededToWin) {
      matchFinished = true;
      matchWinner = winner;
      message = '${winner.name} gewinnt das Match.';
      currentTurnDarts.clear();
      _showMessage('${winner.name} gewinnt das Match.');

      unawaited(_announceMatchWinAfterCheckout(winner));
      return;
    }

    message = '${winner.name} gewinnt das Leg.';
    currentTurnDarts.clear();

    unawaited(_announceLegWinThenStartNextLeg(winner));
  }

  void _handleSetBasedMatchProgress(Player winner, int newLegsWon) {
    if (newLegsWon >= legsNeededToWinSet) {
      final int newSetsWon = (setsWon[winner.id] ?? 0) + 1;
      setsWon[winner.id] = newSetsWon;

      if (newSetsWon >= widget.settings.neededToWin) {
        matchFinished = true;
        matchWinner = winner;
        message = '${winner.name} gewinnt das Match.';
        currentTurnDarts.clear();
        _showMessage('${winner.name} gewinnt das Match.');

        unawaited(_announceMatchWinAfterCheckout(winner));
        return;
      }

      message = '${winner.name} gewinnt das Set.';
      currentTurnDarts.clear();

      unawaited(_announceSetWinThenStartNextLeg(winner));
      return;
    }

    message =
        '${winner.name} gewinnt das Leg. Noch ${legsNeededToWinSet - newLegsWon} Leg bis zum Set.';
    currentTurnDarts.clear();

    unawaited(_announceLegWinThenStartNextLeg(winner));
  }

  Future<void> _announceMatchWinAfterCheckout(Player winner) async {
    await AudioService.instance.announceMatchWin(
      playerName: _audioLabelForPlayer(winner),
    );
  }

  Future<void> _announceLegWinThenStartNextLeg(Player winner) async {
    await AudioService.instance.announceLegWin(
      playerName: _audioLabelForPlayer(winner),
    );

    if (!mounted || matchFinished) {
      return;
    }

    _resetScoresForNextLeg();
  }

  Future<void> _announceSetWinThenStartNextLeg(Player winner) async {
    await AudioService.instance.announceSetWin(
      playerName: _audioLabelForPlayer(winner),
    );

    if (!mounted || matchFinished) {
      return;
    }

    _resetLegsForNextSet();
    _resetScoresForNextLeg();
  }

  void _resetScoresForNextLeg() {
    if (!mounted) {
      return;
    }

    setState(() {
      currentLegNumber += 1;
      currentTurnNumber = 1;
      currentTurnDarts.clear();
      turnSummaryDarts = [];
      turnIntroAnnouncementRunning = false;
      turnSummaryRunning = false;
      turnSummaryIsBust = false;
      turnSummaryPlayerName = '';
      turnSummaryScore = 0;
      turnSummaryTitle = 'AUFNAHME';
      turnSummarySubtitle = '';
      botSequenceToken++;
      turnIntroAnnouncementToken++;
      botTurnRunning = false;
      _resetBotDisplay();

      for (final player in widget.players) {
        remainingScores[player.id] = widget.settings.startScore;
        playerIsIn[player.id] = widget.settings.inMode == InMode.straightIn;
        legPointsScored[player.id] = 0;
        legDartsThrown[player.id] = 0;
        legClassicCounts[player.id] = 0;
        lastTurnScore[player.id] = 0;
        lastTurnText[player.id] = '-';
      }

      if (widget.players.isNotEmpty) {
        currentLegStartingPlayerIndex =
            (currentLegStartingPlayerIndex + 1) % widget.players.length;
        activePlayerIndex = currentLegStartingPlayerIndex;
      }

      turnStartScore =
          remainingScores[activePlayer.id] ?? widget.settings.startScore;
      turnStartedPlayerIsIn = activePlayerIsIn;
      message = 'Neues Leg. ${activePlayer.name} beginnt.';
    });

    unawaited(_announceCurrentPlayerThenMaybeStartBot());
  }

  void _resetLegsForNextSet() {
    for (final player in widget.players) {
      legsWon[player.id] = 0;
    }
  }

  void _moveToNextPlayer({
    String? customMessage,
  }) {
    if (widget.players.isEmpty) {
      return;
    }

    activePlayerIndex = (activePlayerIndex + 1) % widget.players.length;
    currentTurnNumber += 1;
    turnStartScore =
        remainingScores[activePlayer.id] ?? widget.settings.startScore;
    turnStartedPlayerIsIn = activePlayerIsIn;

    if (customMessage == null) {
      message = '${activePlayer.name} ist dran.';
    } else {
      message = '$customMessage ${activePlayer.name} ist dran.';
    }

    unawaited(_announceCurrentPlayerThenMaybeStartBot());
  }

  void _undoLastThrow() {
    if (botTurnRunning || turnIntroAnnouncementRunning || turnSummaryRunning) {
      _showMessage('Während einer laufenden Aufnahme oder Ansage ist Undo gesperrt.');
      return;
    }

    if (history.isEmpty) {
      _showMessage('Es gibt keinen Wurf zum Zurücknehmen.');
      return;
    }

    if (matchResultSaved) {
      _showMessage('Das Ergebnis wurde bereits gespeichert.');
      return;
    }

    botSequenceToken++;

    final _MatchSnapshot snapshot = history.removeLast();

    setState(() {
      activePlayerIndex = snapshot.activePlayerIndex;
      remainingScores = Map<String, int>.from(snapshot.remainingScores);
      legsWon = Map<String, int>.from(snapshot.legsWon);
      matchLegsWon = Map<String, int>.from(snapshot.matchLegsWon);
      setsWon = Map<String, int>.from(snapshot.setsWon);
      playerIsIn = Map<String, bool>.from(snapshot.playerIsIn);
      currentTurnDarts
        ..clear()
        ..addAll(snapshot.currentTurnDarts);
      recordedTurns
        ..clear()
        ..addAll(snapshot.recordedTurns);
      recordedX01Darts
        ..clear()
        ..addAll(snapshot.recordedX01Darts);
      turnStartScore = snapshot.turnStartScore;
      currentLegNumber = snapshot.currentLegNumber;
      currentTurnNumber = snapshot.currentTurnNumber;
      turnStartedPlayerIsIn = snapshot.turnStartedPlayerIsIn;
      currentLegStartingPlayerIndex = snapshot.currentLegStartingPlayerIndex;
      matchPointsScored = Map<String, int>.from(snapshot.matchPointsScored);
      matchDartsThrown = Map<String, int>.from(snapshot.matchDartsThrown);
      legPointsScored = Map<String, int>.from(snapshot.legPointsScored);
      legDartsThrown = Map<String, int>.from(snapshot.legDartsThrown);
      matchClassicCounts = Map<String, int>.from(snapshot.matchClassicCounts);
      legClassicCounts = Map<String, int>.from(snapshot.legClassicCounts);
      lastTurnScore = Map<String, int>.from(snapshot.lastTurnScore);
      lastTurnText = Map<String, String>.from(snapshot.lastTurnText);
      message = snapshot.message;
      matchFinished = snapshot.matchFinished;
      matchWinner = snapshot.matchWinner;
    });

    AudioService.instance.announceUndo();
    _maybeStartBotTurn();
  }

  Future<void> _saveMatchResultIfNeeded() async {
    final Player? winner = matchWinner;

    if (!matchFinished || winner == null || matchResultSaved) {
      return;
    }

    await AppDatabase.instance.insertMatchDartTurns(
      turns: recordedTurns.map((turn) => turn.toMap()).toList(),
    );

    await AppDatabase.instance.insertX01DartRecords(
      darts: recordedX01Darts.map((dart) => dart.toMap()).toList(),
    );

    await AppDatabase.instance.saveMatchResult(
      players: widget.players.where((player) => !_isBotPlayer(player)).toList(),
      winnerPlayerId: _isBotPlayer(winner) ? '' : winner.id,
      legsWonByPlayerId: Map<String, int>.from(matchLegsWon)
        ..removeWhere((playerId, _) => playerId.startsWith('bot_')),
      setsWonByPlayerId: Map<String, int>.from(setsWon)
        ..removeWhere((playerId, _) => playerId.startsWith('bot_')),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      matchResultSaved = true;
    });
  }

  Future<void> _goBackToSetup() async {
    await _saveMatchResultIfNeeded();

    if (!mounted) {
      return;
    }

    final NavigatorState navigator = Navigator.of(context);

    if (navigator.canPop()) {
      navigator.pop();
    }

    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  String _checkoutTextForScore({
    required int score,
    required bool playerIsAlreadyIn,
  }) {
    return CheckoutAdvisor.getCheckoutText(
      score: score,
      doubleOut: usesDoubleOut,
      doubleIn: usesDoubleIn,
      playerIsIn: playerIsAlreadyIn,
      matchFinished: matchFinished,
    );
  }

  String? _checkoutTextForPlayer(Player player) {
    if (matchFinished) {
      return null;
    }

    final int score = remainingScores[player.id] ?? widget.settings.startScore;
    final bool isIn = playerIsIn[player.id] ?? false;

    return _checkoutTextForScore(
      score: score,
      playerIsAlreadyIn: isIn,
    );
  }

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1B2430),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Player? winner = matchWinner;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.1,
            colors: [
              accentColor.withValues(alpha:0.20),
              const Color(0xFF0B0F14),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 26),
            child: Column(
              children: [
                _buildHeader(context),
                const SizedBox(height: 18),
                if (winner != null) _buildWinnerBanner(winner),
                if (winner != null) const SizedBox(height: 18),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 9,
                        child: _buildScorePanel(),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 10,
                        child: _buildInputPanel(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _buildBottomInfoBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () async {
            if (matchFinished) {
              await _goBackToSetup();
              return;
            }

            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.arrow_back_rounded),
          color: Colors.white,
          iconSize: 32,
          tooltip: 'Zurück',
        ),
        const SizedBox(width: 14),
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha:0.13),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accentColor.withValues(alpha:0.25),
            ),
          ),
          child: Icon(
            Icons.sports_score_rounded,
            color: accentColor,
            size: 34,
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Match',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.settings.gameTitle} · $matchProgressLabel · ${widget.settings.inModeLabel} · ${widget.settings.outModeLabel}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF9DA8B7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (hasBotOpponent) ...[
                const SizedBox(height: 7),
                Text(
                  'Bot-Gegner aktiv · ${botOpponentService.skillProfile.levelLabel} · Ziel-Ø ${botOpponentService.skillProfile.targetAverage.toStringAsFixed(1)}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: accentColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWinnerBanner(Player winner) {
    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: Color(0xFF06100B),
            size: 38,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              matchResultSaved
                  ? '${winner.name} gewinnt · gespeichert'
                  : '${winner.name} gewinnt das Match',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF06100B),
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            height: 58,
            child: ElevatedButton.icon(
              onPressed: _goBackToSetup,
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Zurück zum Setup'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06100B),
                foregroundColor: accentColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScorePanel() {
    final List<Player> visiblePlayers = scorePanelPlayers;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF101720),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFF243040),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelTitle(
            title: 'Spielstand',
            subtitle: hasBotOpponent
                ? '${widget.players.length} Spieler · Bot aktiv'
                : '${widget.players.length} Spieler',
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: visiblePlayers.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final Player player = visiblePlayers[index];

                final bool isActiveCard = index == 0 && !matchFinished;

                return PlayerScoreCard(
                  player: player,
                  remainingScore:
                      remainingScores[player.id] ?? widget.settings.startScore,
                  isActive: isActiveCard,
                  legsWon: legsWon[player.id] ?? 0,
                  setsWon: setsWon[player.id] ?? 0,
                  checkoutText: isActiveCard ? _checkoutTextForPlayer(player) : null,
                  matchAverage: _matchAverageForPlayer(player),
                  legAverage: _legAverageForPlayer(player),
                  classicCount: _classicCountForPlayer(player),
                  lastTurnText: _lastTurnTextForPlayer(player),
                  botInfoText: _botInfoForPlayer(player),
                  statusText: _statusTextForPlayer(player),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputPanel() {
    return Column(
      children: [
        _buildActivePlayerBox(),
        const SizedBox(height: 14),
        _buildCheckoutBox(),
        const SizedBox(height: 14),
        Expanded(
          child: turnIntroAnnouncementRunning
              ? _buildTurnIntroAnnouncementBlocker()
              : turnSummaryRunning
                  ? _buildTurnSummaryBlocker()
                  : (activePlayerIsBot || botTurnRunning) && !matchFinished
                      ? _buildBotInputBlocker()
                      : DartInputGrid(
                          onThrowSelected: _handleThrow,
                          onUndo: _undoLastThrow,
                        ),
        ),
      ],
    );
  }

  Widget _buildTurnIntroAnnouncementBlocker() {
    final int scoreToAnnounce = activeRemainingScore;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = constraints.maxHeight < 520;
        final double iconSize = compact ? 68 : 92;
        final double titleSize = compact ? 26 : 34;
        final double scoreSize = compact ? 58 : 82;
        final double padding = compact ? 18 : 26;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: double.infinity,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: accentColor,
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.16),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(compact ? 24 : 30),
                    ),
                    child: Icon(
                      Icons.campaign_rounded,
                      color: const Color(0xFF06100B),
                      size: compact ? 40 : 52,
                    ),
                  ),
                  SizedBox(height: compact ? 14 : 20),
                  Text(
                    'CHECKOUT-ANSAGE',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${activePlayer.name} benötigt $scoreToAnnounce Punkte.',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: compact ? 17 : 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: compact ? 12 : 18),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$scoreToAnnounce',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: scoreSize,
                        height: 0.95,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'WURF WIRD NACH DER ANSAGE FREIGEGEBEN',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFFEAF1F8),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTurnSummaryBlocker() {
    final Color summaryColor = turnSummaryIsBust
        ? const Color(0xFFFF5C77)
        : const Color(0xFFFFB020);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = constraints.maxHeight < 560;
        final double iconSize = compact ? 64 : 92;
        final double titleSize = compact ? 28 : 38;
        final double scoreSize = compact ? 58 : 82;
        final double padding = compact ? 18 : 26;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: double.infinity,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: summaryColor.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: summaryColor,
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: summaryColor.withValues(alpha: 0.18),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      color: summaryColor,
                      borderRadius: BorderRadius.circular(compact ? 22 : 30),
                    ),
                    child: Icon(
                      turnSummaryIsBust
                          ? Icons.warning_rounded
                          : Icons.campaign_rounded,
                      color: const Color(0xFF06100B),
                      size: compact ? 38 : 52,
                    ),
                  ),
                  SizedBox(height: compact ? 12 : 20),
                  Text(
                    turnSummaryTitle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    turnSummarySubtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: summaryColor,
                      fontSize: compact ? 17 : 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: compact ? 12 : 18),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$turnSummaryScore',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: TextStyle(
                        color: summaryColor,
                        fontSize: scoreSize,
                        height: 0.95,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'PUNKTE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFEAF1F8),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.8,
                    ),
                  ),
                  SizedBox(height: compact ? 16 : 26),
                  Row(
                    children: List.generate(3, (index) {
                      final DartThrow? dartThrow = index < turnSummaryDarts.length
                          ? turnSummaryDarts[index]
                          : null;

                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: index == 2 ? 0 : 10,
                          ),
                          child: _TurnSummaryDartCard(
                            dartThrow: dartThrow,
                            throwIndex: index + 1,
                            summaryColor: summaryColor,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBotInputBlocker() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = constraints.maxHeight < 560;
        final double iconSize = compact ? 64 : 92;
        final double titleSize = compact ? 28 : 38;
        final double padding = compact ? 18 : 26;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: const Color(0xFF101720),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFF243040),
              width: 1.2,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(compact ? 22 : 30),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(
                      Icons.smart_toy_rounded,
                      color: accentColor,
                      size: compact ? 38 : 52,
                    ),
                  ),
                  SizedBox(height: compact ? 12 : 20),
                  Text(
                    'BOT WIRFT',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    botDisplayStatus,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: compact ? 17 : 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Level ${botOpponentService.skillProfile.levelLabel} · simuliert nach Spieler-Statistik',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF9DA8B7),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: compact ? 16 : 26),
                  Row(
                    children: List.generate(3, (index) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: index == 2 ? 0 : 10,
                          ),
                          child: _BotThrowDisplayCard(
                            dartThrow: botDisplayDarts[index],
                            throwIndex: index + 1,
                            isActive: activeBotDisplayIndex == index && botTurnRunning,
                            accentColor: accentColor,
                          ),
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: compact ? 16 : 24),
                  SizedBox(
                    width: 320,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: botTurnRunning ? null : _maybeStartBotTurn,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(botTurnRunning ? 'Bot wirft...' : 'Botwurf starten'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: const Color(0xFF06100B),
                        disabledBackgroundColor: const Color(0xFF243040),
                        disabledForegroundColor: const Color(0xFF9DA8B7),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActivePlayerBox() {
    return Container(
      height: 118,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: const Color(0xFF101720),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFF243040),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: matchFinished ? const Color(0xFF243040) : accentColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              matchFinished
                  ? Icons.flag_circle_rounded
                  : activePlayerIsBot
                      ? Icons.smart_toy_rounded
                      : Icons.person_rounded,
              color: matchFinished
                  ? const Color(0xFF9DA8B7)
                  : const Color(0xFF06100B),
              size: 34,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  matchFinished
                      ? 'Match beendet'
                      : '${activePlayer.name} ist dran',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF9DA8B7),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (usesDoubleIn && !matchFinished) ...[
                  const SizedBox(height: 6),
                  Text(
                    activePlayerIsIn
                        ? 'Double In: ${activePlayer.name} ist drin.'
                        : 'Double In: ${activePlayer.name} braucht ein Double oder Bull.',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: activePlayerIsIn
                          ? accentColor
                          : const Color(0xFFFFB020),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 18),
          _buildCurrentDartsBox(),
        ],
      ),
    );
  }

  Widget _buildCheckoutBox() {
    final String checkoutText = _checkoutTextForScore(
      score: activeRemainingScore,
      playerIsAlreadyIn: activePlayerIsIn,
    );

    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: const Color(0xFF101720),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF243040),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha:0.13),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.route_rounded,
              color: accentColor,
              size: 27,
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Checkout:',
            style: TextStyle(
              color: Color(0xFF9DA8B7),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              checkoutText,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFEAF1F8),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentDartsBox() {
    final List<Widget> dartWidgets = [];

    for (int i = 0; i < 3; i++) {
      final DartThrow? dartThrow =
          i < currentTurnDarts.length ? currentTurnDarts[i] : null;

      dartWidgets.add(
        Container(
          width: 72,
          height: 58,
          margin: EdgeInsets.only(left: i == 0 ? 0 : 10),
          decoration: BoxDecoration(
            color: dartThrow == null
                ? const Color(0xFF141A22)
                : accentColor.withValues(alpha:0.14),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: dartThrow == null ? const Color(0xFF2A3545) : accentColor,
            ),
          ),
          child: Center(
            child: Text(
              dartThrow?.label ?? '-',
              style: TextStyle(
                color: dartThrow == null
                    ? const Color(0xFF6F7A89)
                    : const Color(0xFFEAF1F8),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      );
    }

    return Row(children: dartWidgets);
  }

  Widget _buildBottomInfoBar() {
    final String botInfo = hasBotOpponent
        ? ' · Bot ${botOpponentService.skillProfile.levelLabel} Ø ${botOpponentService.skillProfile.targetAverage.toStringAsFixed(1)}'
        : '';

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: const Color(0xFF101720),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF243040),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: accentColor,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              matchFinished
                  ? matchResultSaved
                      ? 'Match beendet · Ergebnis gespeichert'
                      : 'Match beendet · Ergebnis wird beim Zurückgehen gespeichert'
                  : 'Aktueller Turn: $currentTurnScore Punkte · Rest für ${activePlayer.name}: $activeRemainingScore$botInfo',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF9DA8B7),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Undo verfügbar: ${history.isEmpty || matchResultSaved || botTurnRunning || turnSummaryRunning ? 'Nein' : 'Ja'}',
            style: const TextStyle(
              color: Color(0xFF6F7A89),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TurnSummaryDartCard extends StatelessWidget {
  final DartThrow? dartThrow;
  final int throwIndex;
  final Color summaryColor;

  const _TurnSummaryDartCard({
    required this.dartThrow,
    required this.throwIndex,
    required this.summaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final DartThrow? currentDartThrow = dartThrow;
    final bool hasThrow = currentDartThrow != null;

    return Container(
      height: 138,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF101720).withValues(alpha:0.78),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: summaryColor.withValues(alpha:0.75),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Wurf $throwIndex',
            style: TextStyle(
              color: summaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hasThrow ? currentDartThrow.label : '-',
            style: TextStyle(
              color: hasThrow
                  ? const Color(0xFFEAF1F8)
                  : const Color(0xFF6F7A89),
              fontSize: hasThrow ? 36 : 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            hasThrow ? '${currentDartThrow.score} Punkte' : 'kein Wurf',
            style: TextStyle(
              color: hasThrow ? summaryColor : const Color(0xFF9DA8B7),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BotThrowDisplayCard extends StatelessWidget {
  final DartThrow? dartThrow;
  final int throwIndex;
  final bool isActive;
  final Color accentColor;

  const _BotThrowDisplayCard({
    required this.dartThrow,
    required this.throwIndex,
    required this.isActive,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final DartThrow? currentDartThrow = dartThrow;
    final bool hasThrow = currentDartThrow != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: 156,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasThrow || isActive
            ? accentColor.withValues(alpha:0.13)
            : const Color(0xFF141A22),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: hasThrow || isActive ? accentColor : const Color(0xFF2A3545),
          width: isActive ? 2.2 : 1.2,
        ),
        boxShadow: [
          if (isActive)
            BoxShadow(
              color: accentColor.withValues(alpha:0.22),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Wurf $throwIndex',
            style: TextStyle(
              color: hasThrow || isActive ? accentColor : const Color(0xFF6F7A89),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hasThrow ? currentDartThrow.label : '-',
            style: TextStyle(
              color: hasThrow ? const Color(0xFFEAF1F8) : const Color(0xFF6F7A89),
              fontSize: hasThrow ? 42 : 38,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasThrow ? '${currentDartThrow.score} Punkte' : isActive ? 'zielt...' : 'wartet',
            style: TextStyle(
              color: hasThrow ? accentColor : const Color(0xFF9DA8B7),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PanelTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        Icon(
          Icons.radio_button_checked,
          color: accentColor,
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF9DA8B7),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}