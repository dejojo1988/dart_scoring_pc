import 'dart:async';

import 'package:flutter/material.dart';

import '../models/dart_throw.dart';
import '../models/game_settings.dart';
import '../models/player.dart';
import '../services/audio_service.dart';
import '../services/player_name_audio_service.dart';
import '../widgets/dart_input_grid.dart';

class ChaseTheHitMatchPage extends StatefulWidget {
  final GameSettings settings;
  final List<Player> players;
  final Player startingPlayer;

  const ChaseTheHitMatchPage({
    super.key,
    required this.settings,
    required this.players,
    required this.startingPlayer,
  });

  @override
  State<ChaseTheHitMatchPage> createState() => _ChaseTheHitMatchPageState();
}

class _ChaseTheHitMatchPageState extends State<ChaseTheHitMatchPage> {
  final Map<String, int> points = <String, int>{};
  final Set<String> eliminatedPlayerIds = <String>{};
  final List<DartThrow> currentTurnDarts = <DartThrow>[];
  final List<String> eventLog = <String>[];

  late int currentPlayerIndex;

  _ChaseTarget? currentTarget;
  Player? currentTargetSetter;
  bool matchFinished = false;
  Player? matchWinner;
  int roundNumber = 1;
  bool _audioBusy = false;
  Future<void> _audioQueue = Future<void>.value();

  bool get isSegmentMode =>
      widget.settings.chaseTheHitMode == ChaseTheHitMode.segment;

  Player get currentPlayer => widget.players[currentPlayerIndex];

  @override
  void initState() {
    super.initState();

    for (final Player player in widget.players) {
      points[player.id] = 0;
    }

    final int startIndex = widget.players.indexWhere(
      (player) => player.id == widget.startingPlayer.id,
    );

    currentPlayerIndex = startIndex >= 0 ? startIndex : 0;

    eventLog.add(
      'Runde 1: ${currentPlayer.name} eröffnet Chase the Hit.',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runAudioSequence(_announceMatchStart));
    });
  }

  Future<void> _announceMatchStart() async {
    await AudioService.instance.playEvent(
      AudioEventType.gameStart,
      waitForCompletion: true,
    );

    await _announcePlayerIdentity(currentPlayer);
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

  int _audioNumberForPlayer(Player player) {
    if (_isBotPlayer(player)) {
      return 0;
    }

    final List<Player> playersInAudioOrder = _playersInAudioOrder();
    final int playerIndex = playersInAudioOrder.indexWhere(
      (currentPlayer) => currentPlayer.id == player.id,
    );

    return playerIndex >= 0 ? playerIndex + 1 : 1;
  }

  List<Player> _playersInAudioOrder() {
    if (widget.players.isEmpty) {
      return <Player>[];
    }

    final int startIndex = widget.players.indexWhere(
      (player) => player.id == widget.startingPlayer.id,
    );
    final int safeStartIndex = startIndex >= 0 ? startIndex : 0;

    final List<Player> orderedPlayers = <Player>[
      for (int index = 0; index < widget.players.length; index++)
        widget.players[(safeStartIndex + index) % widget.players.length],
    ];

    return orderedPlayers.where((player) => !_isBotPlayer(player)).toList();
  }

  bool _isBotPlayer(Player player) {
    return player.id.startsWith('bot_');
  }

  Future<bool> _playCustomPlayerNameIfAvailable(Player player) async {
    if (_isBotPlayer(player)) {
      return false;
    }

    try {
      return PlayerNameAudioService.instance.playNameAudioForPlayer(
        player,
        waitForCompletion: true,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> _announcePlayerIdentity(Player player) async {
    final bool customNamePlayed = await _playCustomPlayerNameIfAvailable(player);

    if (customNamePlayed) {
      return;
    }

    final int playerNumber = _audioNumberForPlayer(player);
    final bool playerAssetPlayed = playerNumber > 0 &&
        await AudioService.instance.playDefaultPlayerNumber(
          playerNumber,
          waitForCompletion: true,
        );

    if (playerAssetPlayed) {
      return;
    }

    await AudioService.instance.speak(_audioLabelForPlayer(player));
  }

  Future<void> _announceCurrentPlayer() async {
    final Player player = currentPlayer;

    await _announcePlayerIdentity(player);

    final _ChaseTarget? target = currentTarget;
    if (target == null) {
      return;
    }

    final bool targetIntroPlayed = await AudioService.instance.playDefaultPackFile(
      'your-target-is.wav',
      waitForCompletion: true,
    );

    if (!targetIntroPlayed) {
      await AudioService.instance.speak('Dein Ziel ist');
    }

    await _announceTarget(target);
  }

  Future<void> _announceTarget(_ChaseTarget target) async {
    if (isSegmentMode) {
      if (target.segmentBull) {
        final bool bullPlayed = await AudioService.instance.playDefaultPackFile(
          'bull.wav',
          waitForCompletion: true,
        );

        if (!bullPlayed) {
          await AudioService.instance.speak('Bull');
        }

        return;
      }

      final int targetNumber = target.number ?? 25;
      final bool numberPlayed = await AudioService.instance.playDefaultNumber(
        targetNumber,
        waitForCompletion: true,
      );

      if (!numberPlayed) {
        await AudioService.instance.speak(targetNumber.toString());
      }

      return;
    }

    await AudioService.instance.speak(target.label);
  }

  Future<void> _announceTargetHitAndNewTarget(_ChaseTarget newTarget) async {
    final bool targetHitPlayed = await AudioService.instance.playDefaultPackFile(
      'target-hit.wav',
      waitForCompletion: true,
    );

    if (!targetHitPlayed) {
      await AudioService.instance.speak('Target hit.');
    }

    final bool newTargetPlayed = await AudioService.instance.playDefaultPackFile(
      'new-target.wav',
      waitForCompletion: true,
    );

    if (!newTargetPlayed) {
      await AudioService.instance.speak('Neues Ziel');
    }

    // Wichtig: Die neue Zielzahl wird hier bewusst NICHT angesagt.
    // Sonst kommt nach jedem Zug doppelt: "20" und direkt danach
    // "Player Two - Your target is - 20".
    // Die vollständige Zielansage gehört nur zum nächsten Spieler.
  }

  Future<void> _announceRoundPoint() async {
    final bool jinglePlayed = await AudioService.instance.playDefaultPackFile(
      'jingle.wav',
      waitForCompletion: true,
    );

    if (!jinglePlayed) {
      await AudioService.instance.speak('Punkt.');
    }
  }

  Future<void> _announceMatchWin(Player winner) async {
    await AudioService.instance.announceMatchWin(
      playerName: _audioLabelForPlayer(winner),
    );
  }

  Future<void> _runAudioSequence(Future<void> Function() action) {
    _audioQueue = _audioQueue.then((_) async {
      if (!mounted) {
        return;
      }

      setState(() {
        _audioBusy = true;
      });

      try {
        await action();
      } finally {
        if (mounted) {
          setState(() {
            _audioBusy = false;
          });
        }
      }
    });

    return _audioQueue;
  }

  void _playDartHitSound(DartThrow dartThrow) {
    if (dartThrow.type == DartThrowType.miss) {
      unawaited(
        AudioService.instance.playEvent(
          AudioEventType.dartMiss,
          waitForCompletion: false,
        ),
      );
      return;
    }

    unawaited(
      AudioService.instance.playEvent(
        AudioEventType.dartHit,
        waitForCompletion: false,
      ),
    );
  }

  void _handleThrow(DartThrow dartThrow) {
    unawaited(_handleThrowAsync(dartThrow));
  }

  Future<void> _handleThrowAsync(DartThrow dartThrow) async {
    if (_audioBusy) {
      return;
    }

    if (matchFinished) {
      _showMessage('Das Match ist bereits beendet.');
      return;
    }

    if (currentTurnDarts.length >= 3) {
      _showMessage('Der Zug ist bereits voll.');
      return;
    }

    setState(() {
      currentTurnDarts.add(dartThrow);
    });

    _playDartHitSound(dartThrow);

    if (currentTurnDarts.length == 3) {
      unawaited(_finishTurn());
    }
  }

  void _undoLastThrow() {
    if (_audioBusy || matchFinished || currentTurnDarts.isEmpty) {
      return;
    }

    setState(() {
      currentTurnDarts.removeLast();
    });
  }

  Future<void> _finishTurn() async {
    if (_audioBusy) {
      return;
    }

    final Player player = currentPlayer;
    final List<DartThrow> throws = List<DartThrow>.from(currentTurnDarts);

    if (currentTarget == null) {
      final _ChaseTarget? openingTarget = _highestTargetFromThrows(throws);

      if (openingTarget == null) {
        setState(() {
          currentTurnDarts.clear();
          eventLog.insert(
            0,
            '${player.name} konnte kein Ziel setzen. ${player.name} eröffnet erneut.',
          );
        });
        return;
      }

      setState(() {
        currentTarget = openingTarget;
        currentTargetSetter = player;
        currentTurnDarts.clear();
        eventLog.insert(
          0,
          _buildOpeningLog(
            player: player,
            throws: throws,
            openingTarget: openingTarget,
          ),
        );
      });

      await _runAudioSequence(() async {
        await _announceTargetHitAndNewTarget(openingTarget);
      });

      if (!mounted || matchFinished) {
        return;
      }

      setState(() {
        _moveToNextEligiblePlayer();
      });

      await _runAudioSequence(_announceCurrentPlayer);
      return;
    }

    final _ChaseTarget previousTarget = currentTarget!;

    final int hitIndex = throws.indexWhere(
      (dartThrow) => previousTarget.matches(
        dartThrow,
        segmentMode: isSegmentMode,
      ),
    );

    if (hitIndex < 0) {
      setState(() {
        eliminatedPlayerIds.add(player.id);
        currentTurnDarts.clear();
        eventLog.insert(
          0,
          _buildMissLog(
            player: player,
            target: previousTarget,
            throws: throws,
          ),
        );
      });

      final bool roundIsOver = _activeChallengers().isEmpty &&
          currentTargetSetter != null;

      await _runAudioSequence(() async {
        final bool outPlayed = await AudioService.instance.playDefaultPackFile(
          'out.wav',
          waitForCompletion: true,
        );

        if (!outPlayed) {
          await AudioService.instance.speak('Out.');
        }
      });

      if (!mounted || matchFinished) {
        return;
      }

      if (roundIsOver) {
        await _awardRoundTo(currentTargetSetter!);
        return;
      }

      setState(() {
        _moveToNextEligiblePlayer();
      });

      await _runAudioSequence(_announceCurrentPlayer);
      return;
    }

    final List<DartThrow> targetCandidateThrows = <DartThrow>[];
    for (int index = 0; index < throws.length; index++) {
      if (index != hitIndex) {
        targetCandidateThrows.add(throws[index]);
      }
    }

    final _ChaseTarget? newTarget =
        _highestTargetFromThrows(targetCandidateThrows);

    if (newTarget == null) {
      setState(() {
        eliminatedPlayerIds.add(player.id);
        currentTurnDarts.clear();
        eventLog.insert(
          0,
          _buildHitWithoutNewTargetLog(
            player: player,
            previousTarget: previousTarget,
            hitDart: throws[hitIndex],
            candidateThrows: targetCandidateThrows,
            throws: throws,
          ),
        );
      });

      final bool roundIsOver = _activeChallengers().isEmpty &&
          currentTargetSetter != null;

      await _runAudioSequence(() async {
        final bool outPlayed = await AudioService.instance.playDefaultPackFile(
          'out.wav',
          waitForCompletion: true,
        );

        if (!outPlayed) {
          await AudioService.instance.speak('Out.');
        }
      });

      if (!mounted || matchFinished) {
        return;
      }

      if (roundIsOver) {
        await _awardRoundTo(currentTargetSetter!);
        return;
      }

      setState(() {
        _moveToNextEligiblePlayer();
      });

      await _runAudioSequence(_announceCurrentPlayer);
      return;
    }

    setState(() {
      currentTarget = newTarget;
      currentTargetSetter = player;
      currentTurnDarts.clear();
      eventLog.insert(
        0,
        _buildHitLog(
          player: player,
          previousTarget: previousTarget,
          hitDart: throws[hitIndex],
          candidateThrows: targetCandidateThrows,
          newTarget: newTarget,
          throws: throws,
        ),
      );
    });

    await _runAudioSequence(() async {
      await _announceTargetHitAndNewTarget(newTarget);
    });

    if (!mounted || matchFinished) {
      return;
    }

    final bool roundIsOver = _activeChallengers().isEmpty &&
        currentTargetSetter != null;

    if (roundIsOver) {
      await _awardRoundTo(currentTargetSetter!);
      return;
    }

    setState(() {
      _moveToNextEligiblePlayer();
    });

    await _runAudioSequence(_announceCurrentPlayer);
  }

  List<Player> _activeChallengers() {
    return widget.players.where((player) {
      if (eliminatedPlayerIds.contains(player.id)) {
        return false;
      }

      if (currentTargetSetter != null && player.id == currentTargetSetter!.id) {
        return false;
      }

      return true;
    }).toList();
  }

  void _moveToNextEligiblePlayer() {
    if (matchFinished) {
      return;
    }

    for (int step = 1; step <= widget.players.length; step++) {
      final int nextIndex = (currentPlayerIndex + step) % widget.players.length;
      final Player candidate = widget.players[nextIndex];

      if (eliminatedPlayerIds.contains(candidate.id)) {
        continue;
      }

      if (currentTargetSetter != null && candidate.id == currentTargetSetter!.id) {
        continue;
      }

      currentPlayerIndex = nextIndex;
      return;
    }
  }


  Future<void> _awardRoundTo(Player winner) async {
    final int newPoints = (points[winner.id] ?? 0) + 1;

    setState(() {
      points[winner.id] = newPoints;
      currentTurnDarts.clear();
      eventLog.insert(
        0,
        '🏆 ${winner.name} gewinnt Runde $roundNumber und bekommt 1 Punkt.',
      );
    });

    if (newPoints >= widget.settings.chaseTheHitPointsToWin) {
      setState(() {
        matchFinished = true;
        matchWinner = winner;
      });

      await _runAudioSequence(() async {
        await _announceMatchWin(winner);
      });
      return;
    }

    await _runAudioSequence(_announceRoundPoint);

    if (!mounted || matchFinished) {
      return;
    }

    setState(() {
      roundNumber++;
      eliminatedPlayerIds.clear();
      currentTarget = null;
      currentTargetSetter = null;
      currentTurnDarts.clear();

      final int winnerIndex = widget.players.indexWhere(
        (player) => player.id == winner.id,
      );
      currentPlayerIndex = winnerIndex >= 0 ? winnerIndex : 0;

      eventLog.insert(
        0,
        'Runde $roundNumber: ${winner.name} eröffnet die nächste Runde.',
      );
    });

    await _runAudioSequence(_announceCurrentPlayer);
  }

  _ChaseTarget? _highestTargetFromThrows(List<DartThrow> throws) {
    _ChaseTarget? bestTarget;

    for (final DartThrow dartThrow in throws) {
      final _ChaseTarget? target = _ChaseTarget.fromThrow(
        dartThrow,
        segmentMode: isSegmentMode,
      );

      if (target == null) {
        continue;
      }

      if (bestTarget == null || target.rank > bestTarget.rank) {
        bestTarget = target;
      }
    }

    return bestTarget;
  }

  String _throwsLabel(List<DartThrow> throws) {
    return throws.map((dartThrow) => dartThrow.label).join(' · ');
  }


  String _buildOpeningLog({
    required Player player,
    required List<DartThrow> throws,
    required _ChaseTarget openingTarget,
  }) {
    return '${player.name} eröffnet die Runde. Würfe: ${_throwsLabel(throws)} → '
        'höchster einzelner Dart: ${openingTarget.label} → Ziel gesetzt: ${openingTarget.label}.';
  }

  String _buildMissLog({
    required Player player,
    required _ChaseTarget target,
    required List<DartThrow> throws,
  }) {
    return '${player.name} muss ${target.label} treffen. Würfe: ${_throwsLabel(throws)} → '
        'kein gültiger Treffer → ❌ ${player.name} ist aus dieser Runde raus.';
  }

  String _buildHitWithoutNewTargetLog({
    required Player player,
    required _ChaseTarget previousTarget,
    required DartThrow hitDart,
    required List<DartThrow> candidateThrows,
    required List<DartThrow> throws,
  }) {
    final String candidateLabel = candidateThrows.isEmpty
        ? 'keine übrigen Darts'
        : _throwsLabel(candidateThrows);

    return '${player.name} muss ${previousTarget.label} treffen. Würfe: ${_throwsLabel(throws)} → '
        '${hitDart.label} checkt zwar das Ziel, aber die anderen Darts sind $candidateLabel. '
        'Es entsteht kein gültiges neues Ziel → ❌ ${player.name} ist aus dieser Runde raus. '
        'Das alte Ziel ${previousTarget.label} bleibt bestehen.';
  }

  String _buildHitLog({
    required Player player,
    required _ChaseTarget previousTarget,
    required DartThrow hitDart,
    required List<DartThrow> candidateThrows,
    required _ChaseTarget newTarget,
    required List<DartThrow> throws,
  }) {
    final String modeRule = isSegmentMode
        ? 'Segment Mode: ${_segmentRuleLabel(previousTarget)}'
        : 'Exact Mode: exakt ${previousTarget.label} gefordert';

    final String candidateLabel = candidateThrows.isEmpty
        ? 'keine übrigen Darts'
        : _throwsLabel(candidateThrows);

    return '${player.name} muss ${previousTarget.label} treffen. Würfe: ${_throwsLabel(throws)} → '
        '${hitDart.label} checkt das Ziel. $modeRule. '
        'Für das neue Ziel zählen die anderen Darts: $candidateLabel → '
        'höchster einzelner Dart: ${newTarget.label} → neues Ziel: ${newTarget.label}.';
  }

  String _segmentRuleLabel(_ChaseTarget target) {
    if (target.segmentBull) {
      return 'Outer und Bull zählen als Bull-Segment';
    }

    return 'S${target.number}, D${target.number} und T${target.number} zählen als ${target.number}';
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
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.1,
            colors: [
              accentColor.withValues(alpha: 0.20),
              const Color(0xFF0B0F14),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 34),
            child: Column(
              children: [
                _buildHeader(context),
                const SizedBox(height: 24),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 11,
                        child: _buildMatchPanel(),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 9,
                        child: _buildInputPanel(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        IconButton(
          onPressed: () {
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
            color: accentColor.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.25),
            ),
          ),
          child: Icon(
            Icons.center_focus_strong_rounded,
            color: accentColor,
            size: 34,
          ),
        ),
        const SizedBox(width: 18),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chase the Hit',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.settings.chaseTheHitModeLabel} · First to ${widget.settings.chaseTheHitPointsToWin} Points',
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF9DA8B7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const Spacer(),
        if (matchFinished && matchWinner != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accentColor.withValues(alpha: 0.35)),
            ),
            child: Text(
              '${matchWinner!.name} wins!',
              style: TextStyle(
                color: accentColor,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMatchPanel() {
    return _Panel(
      title: 'Match',
      subtitle: 'Runde $roundNumber',
      child: Column(
        children: [
          _buildTargetBox(),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildScoreboard()),
                const SizedBox(width: 16),
                Expanded(child: _buildEventLog()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetBox() {
    final Color accentColor = Theme.of(context).colorScheme.primary;
    final String targetLabel = currentTarget?.label ?? 'OPEN';
    final String helperText = currentTarget == null
        ? '${currentPlayer.name} setzt mit 3 Darts das erste Ziel.'
        : '${currentPlayer.name} muss $targetLabel treffen.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1118),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.38),
          width: 1.4,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CURRENT TARGET',
                  style: TextStyle(
                    color: Color(0xFF9DA8B7),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  targetLabel,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 72,
                    fontWeight: FontWeight.w900,
                    height: 0.95,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  helperText,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Color(0xFFEAF1F8),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  currentTargetSetter == null
                      ? 'Noch kein Zielgeber'
                      : 'Ziel gesetzt von ${currentTargetSetter!.name}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Color(0xFF9DA8B7),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreboard() {
    final List<Player> sortedPlayers = List<Player>.from(widget.players)
      ..sort((a, b) => (points[b.id] ?? 0).compareTo(points[a.id] ?? 0));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1118),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF243040)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Scoreboard',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              itemCount: sortedPlayers.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final Player player = sortedPlayers[index];
                final bool isCurrent = player.id == currentPlayer.id;
                final bool isOut = eliminatedPlayerIds.contains(player.id);
                final bool isSetter = currentTargetSetter?.id == player.id;

                return _PlayerScoreRow(
                  player: player,
                  points: points[player.id] ?? 0,
                  isCurrent: isCurrent,
                  isOut: isOut,
                  isSetter: isSetter,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventLog() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1118),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF243040)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Round Log',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              itemCount: eventLog.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return Text(
                  eventLog[index],
                  style: const TextStyle(
                    color: Color(0xFF9DA8B7),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputPanel() {
    return _Panel(
      title: currentPlayer.name,
      subtitle: _audioBusy ? 'Audio läuft...' : '${currentTurnDarts.length} / 3 Darts',
      child: Column(
        children: [
          _buildCurrentDartsBox(),
          const SizedBox(height: 14),
          Expanded(
            child: matchFinished
                ? _buildMatchFinishedBox()
                : AbsorbPointer(
                    absorbing: _audioBusy,
                    child: Opacity(
                      opacity: _audioBusy ? 0.62 : 1.0,
                      child: DartInputGrid(
                        onThrowSelected: _handleThrow,
                        onUndo: _undoLastThrow,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentDartsBox() {
    final List<String> labels = List<String>.generate(3, (index) {
      if (index < currentTurnDarts.length) {
        return currentTurnDarts[index].label;
      }

      return '-';
    });

    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1118),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF243040)),
      ),
      child: Row(
        children: [
          for (int index = 0; index < labels.length; index++) ...[
            Expanded(
              child: Center(
                child: Text(
                  labels[index],
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            if (index < labels.length - 1)
              Container(
                width: 1,
                height: 38,
                color: const Color(0xFF243040),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildMatchFinishedBox() {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accentColor.withValues(alpha: 0.35)),
      ),
      child: Center(
        child: Text(
          matchWinner == null ? 'Match beendet' : '${matchWinner!.name} gewinnt!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: accentColor,
            fontSize: 34,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ChaseTarget {
  final int? number;
  final DartThrowType type;
  final bool segmentBull;
  final int rank;
  final String label;

  const _ChaseTarget({
    required this.number,
    required this.type,
    required this.segmentBull,
    required this.rank,
    required this.label,
  });

  bool matches(DartThrow dartThrow, {required bool segmentMode}) {
    if (segmentMode) {
      if (segmentBull) {
        return dartThrow.type == DartThrowType.outer ||
            dartThrow.type == DartThrowType.bull;
      }

      if (dartThrow.type == DartThrowType.miss) {
        return false;
      }

      return dartThrow.number == number;
    }

    return dartThrow.type == type && dartThrow.number == number;
  }

  static _ChaseTarget? fromThrow(
    DartThrow dartThrow, {
    required bool segmentMode,
  }) {
    if (dartThrow.type == DartThrowType.miss) {
      return null;
    }

    if (segmentMode) {
      if (dartThrow.type == DartThrowType.outer ||
          dartThrow.type == DartThrowType.bull) {
        return const _ChaseTarget(
          number: null,
          type: DartThrowType.outer,
          segmentBull: true,
          rank: 25,
          label: 'Bull',
        );
      }

      final int number = dartThrow.number ?? 0;

      return _ChaseTarget(
        number: number,
        type: DartThrowType.single,
        segmentBull: false,
        rank: number,
        label: '$number',
      );
    }

    return _ChaseTarget(
      number: dartThrow.number,
      type: dartThrow.type,
      segmentBull: false,
      rank: dartThrow.score,
      label: dartThrow.label,
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(22),
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
          Row(
            children: [
              Icon(Icons.radio_button_checked, color: accentColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Color(0xFF9DA8B7),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _PlayerScoreRow extends StatelessWidget {
  final Player player;
  final int points;
  final bool isCurrent;
  final bool isOut;
  final bool isSetter;

  const _PlayerScoreRow({
    required this.player,
    required this.points,
    required this.isCurrent,
    required this.isOut,
    required this.isSetter,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    Color borderColor = const Color(0xFF243040);
    Color backgroundColor = const Color(0xFF101720);
    String status = 'Active';

    if (isCurrent) {
      borderColor = accentColor;
      backgroundColor = accentColor.withValues(alpha: 0.10);
      status = 'Throwing';
    } else if (isSetter) {
      borderColor = accentColor.withValues(alpha: 0.45);
      status = 'Target Setter';
    } else if (isOut) {
      borderColor = const Color(0xFF3A2020);
      backgroundColor = const Color(0xFF161111);
      status = 'Out';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isOut ? const Color(0xFF6F7A89) : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: const TextStyle(
                    color: Color(0xFF9DA8B7),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$points',
            style: TextStyle(
              color: isCurrent ? accentColor : Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}