import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../models/dart_throw.dart';
import '../models/game_settings.dart';
import '../models/player.dart';
import '../widgets/dart_input_grid.dart';

class RoundTheClockMatchPage extends StatefulWidget {
  final GameSettings settings;
  final List<Player> players;
  final Player startingPlayer;

  const RoundTheClockMatchPage({
    super.key,
    required this.settings,
    required this.players,
    required this.startingPlayer,
  });

  @override
  State<RoundTheClockMatchPage> createState() => _RoundTheClockMatchPageState();
}

class _RoundSnapshot {
  final int activePlayerIndex;
  final Map<String, int> playerTargets;
  final Map<String, int> legsWon;
  final Map<String, int> matchLegsWon;
  final Map<String, int> setsWon;
  final List<DartThrow> currentTurnDarts;
  final String message;
  final bool matchFinished;
  final Player? matchWinner;

  const _RoundSnapshot({
    required this.activePlayerIndex,
    required this.playerTargets,
    required this.legsWon,
    required this.matchLegsWon,
    required this.setsWon,
    required this.currentTurnDarts,
    required this.message,
    required this.matchFinished,
    required this.matchWinner,
  });
}

class _RoundTheClockMatchPageState extends State<RoundTheClockMatchPage> {
  static const int legsNeededToWinSet = 2;

  late int activePlayerIndex;
  late Map<String, int> playerTargets;
  late Map<String, int> legsWon;
  late Map<String, int> matchLegsWon;
  late Map<String, int> setsWon;

  final List<DartThrow> currentTurnDarts = [];
  final List<_RoundSnapshot> history = [];

  String message = 'Round the Clock gestartet.';
  bool matchFinished = false;
  bool matchResultSaved = false;
  Player? matchWinner;

  @override
  void initState() {
    super.initState();

    final int startIndex = widget.players.indexWhere(
      (player) => player.id == widget.startingPlayer.id,
    );

    activePlayerIndex = startIndex >= 0 ? startIndex : 0;

    playerTargets = {
      for (final player in widget.players) player.id: 1,
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

    message = '${activePlayer.name} beginnt bei Ziel 1.';
  }

  Player get activePlayer {
    return widget.players[activePlayerIndex];
  }

  int get activeTarget {
    return playerTargets[activePlayer.id] ?? 1;
  }

  String get activeTargetLabel {
    return _targetLabel(activeTarget);
  }

  String get matchProgressLabel {
    if (widget.settings.matchUnit == MatchUnit.legs) {
      return widget.settings.matchFormatLabel;
    }

    return '${widget.settings.matchFormatLabel} · $legsNeededToWinSet Legs pro Set';
  }

  void _saveSnapshot() {
    history.add(
      _RoundSnapshot(
        activePlayerIndex: activePlayerIndex,
        playerTargets: Map<String, int>.from(playerTargets),
        legsWon: Map<String, int>.from(legsWon),
        matchLegsWon: Map<String, int>.from(matchLegsWon),
        setsWon: Map<String, int>.from(setsWon),
        currentTurnDarts: List<DartThrow>.from(currentTurnDarts),
        message: message,
        matchFinished: matchFinished,
        matchWinner: matchWinner,
      ),
    );
  }

  void _handleThrow(DartThrow dartThrow) {
    if (matchFinished) {
      _showMessage('Das Match ist bereits beendet.');
      return;
    }

    _saveSnapshot();

    final Player throwingPlayer = activePlayer;
    final int targetBeforeThrow = playerTargets[throwingPlayer.id] ?? 1;
    final bool isHit = _isCorrectHit(dartThrow, targetBeforeThrow);

    currentTurnDarts.add(dartThrow);

    if (isHit) {
      if (targetBeforeThrow >= 21) {
        setState(() {
          _handleLegWin(throwingPlayer);
        });

        return;
      }

      final int nextTarget = targetBeforeThrow + 1;

      setState(() {
        playerTargets[throwingPlayer.id] = nextTarget;
        message =
            '${throwingPlayer.name} trifft ${_targetLabel(targetBeforeThrow)}. Neues Ziel: ${_targetLabel(nextTarget)}.';

        if (currentTurnDarts.length >= 3) {
          currentTurnDarts.clear();
          _moveToNextPlayer();
        }
      });

      return;
    }

    setState(() {
      message =
          '${throwingPlayer.name}: ${dartThrow.label} trifft nicht Ziel ${_targetLabel(targetBeforeThrow)}.';

      if (currentTurnDarts.length >= 3) {
        currentTurnDarts.clear();
        _moveToNextPlayer();
      }
    });
  }

  bool _isCorrectHit(DartThrow dartThrow, int target) {
    if (target >= 21) {
      return dartThrow.type == DartThrowType.bull;
    }

    switch (dartThrow.type) {
      case DartThrowType.single:
      case DartThrowType.double:
      case DartThrowType.triple:
        return dartThrow.number == target;

      case DartThrowType.outer:
      case DartThrowType.bull:
      case DartThrowType.miss:
        return false;
    }
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
      message = '${winner.name} trifft Bull und gewinnt das Match.';
      currentTurnDarts.clear();
      _showMessage('${winner.name} gewinnt das Match.');
      return;
    }

    message = '${winner.name} trifft Bull und gewinnt das Leg.';
    currentTurnDarts.clear();
    _resetTargetsForNextLeg(winner);
  }

  void _handleSetBasedMatchProgress(Player winner, int newLegsWon) {
    if (newLegsWon >= legsNeededToWinSet) {
      final int newSetsWon = (setsWon[winner.id] ?? 0) + 1;
      setsWon[winner.id] = newSetsWon;

      if (newSetsWon >= widget.settings.neededToWin) {
        matchFinished = true;
        matchWinner = winner;
        message = '${winner.name} trifft Bull und gewinnt das Match.';
        currentTurnDarts.clear();
        _showMessage('${winner.name} gewinnt das Match.');
        return;
      }

      message = '${winner.name} gewinnt das Set.';
      currentTurnDarts.clear();
      _resetLegsForNextSet();
      _resetTargetsForNextLeg(winner);
      return;
    }

    message =
        '${winner.name} gewinnt das Leg. Noch ${legsNeededToWinSet - newLegsWon} Leg bis zum Set.';
    currentTurnDarts.clear();
    _resetTargetsForNextLeg(winner);
  }

  void _resetTargetsForNextLeg(Player startingPlayer) {
    for (final player in widget.players) {
      playerTargets[player.id] = 1;
    }

    final int winnerIndex = widget.players.indexWhere(
      (player) => player.id == startingPlayer.id,
    );

    if (winnerIndex >= 0) {
      activePlayerIndex = winnerIndex;
    }

    message = '${activePlayer.name} beginnt das nächste Leg bei Ziel 1.';
  }

  void _resetLegsForNextSet() {
    for (final player in widget.players) {
      legsWon[player.id] = 0;
    }
  }

  void _moveToNextPlayer() {
    if (widget.players.isEmpty) {
      return;
    }

    activePlayerIndex = (activePlayerIndex + 1) % widget.players.length;
    message = '${activePlayer.name} ist dran. Ziel: $activeTargetLabel.';
  }

  void _undoLastThrow() {
    if (history.isEmpty) {
      _showMessage('Es gibt keinen Wurf zum Zurücknehmen.');
      return;
    }

    if (matchResultSaved) {
      _showMessage('Das Ergebnis wurde bereits gespeichert.');
      return;
    }

    final _RoundSnapshot snapshot = history.removeLast();

    setState(() {
      activePlayerIndex = snapshot.activePlayerIndex;
      playerTargets = Map<String, int>.from(snapshot.playerTargets);
      legsWon = Map<String, int>.from(snapshot.legsWon);
      matchLegsWon = Map<String, int>.from(snapshot.matchLegsWon);
      setsWon = Map<String, int>.from(snapshot.setsWon);
      currentTurnDarts
        ..clear()
        ..addAll(snapshot.currentTurnDarts);
      message = snapshot.message;
      matchFinished = snapshot.matchFinished;
      matchWinner = snapshot.matchWinner;
    });
  }

  Future<void> _saveMatchResultIfNeeded() async {
    final Player? winner = matchWinner;

    if (!matchFinished || winner == null || matchResultSaved) {
      return;
    }

    await AppDatabase.instance.saveMatchResult(
      players: widget.players,
      winnerPlayerId: winner.id,
      legsWonByPlayerId: Map<String, int>.from(matchLegsWon),
      setsWonByPlayerId: Map<String, int>.from(setsWon),
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

  String _targetLabel(int target) {
    if (target >= 21) {
      return 'Bull';
    }

    return '$target';
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
    final Color accentColor = Theme.of(context).colorScheme.primary;

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
                        child: _buildPlayerTargetsPanel(),
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
    final Color accentColor = Theme.of(context).colorScheme.primary;

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
            Icons.access_time_filled_rounded,
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
                'Round the Clock',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$matchProgressLabel · Ziel 1 bis 20 · Finale: Bull',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF9DA8B7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWinnerBanner(Player winner) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

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
              onPressed: () async {
                await _goBackToSetup();
              },
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

  Widget _buildPlayerTargetsPanel() {
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
            subtitle: '${widget.players.length} Spieler',
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: widget.players.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final Player player = widget.players[index];
                final int target = playerTargets[player.id] ?? 1;

                return _RoundPlayerCard(
                  player: player,
                  targetLabel: _targetLabel(target),
                  progressValue: target,
                  isActive: index == activePlayerIndex && !matchFinished,
                  legsWon: legsWon[player.id] ?? 0,
                  setsWon: setsWon[player.id] ?? 0,
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
        const SizedBox(height: 16),
        Expanded(
          child: DartInputGrid(
            onThrowSelected: _handleThrow,
            onUndo: _undoLastThrow,
          ),
        ),
      ],
    );
  }

  Widget _buildActivePlayerBox() {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      height: 126,
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
              matchFinished ? Icons.flag_circle_rounded : Icons.person_rounded,
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
                if (!matchFinished) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Aktuelles Ziel: $activeTargetLabel',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
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

  Widget _buildCurrentDartsBox() {
    final Color accentColor = Theme.of(context).colorScheme.primary;
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
    final Color accentColor = Theme.of(context).colorScheme.primary;

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
                  : '${activePlayer.name} braucht Ziel $activeTargetLabel',
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
            'Undo verfügbar: ${history.isEmpty || matchResultSaved ? 'Nein' : 'Ja'}',
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

class _RoundPlayerCard extends StatelessWidget {
  final Player player;
  final String targetLabel;
  final int progressValue;
  final bool isActive;
  final int legsWon;
  final int setsWon;

  const _RoundPlayerCard({
    required this.player,
    required this.targetLabel,
    required this.progressValue,
    required this.isActive,
    required this.legsWon,
    required this.setsWon,
  });

  double get progress {
    final int clamped = progressValue.clamp(1, 21);
    return clamped / 21;
  }

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      height: 132,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isActive ? accentColor.withValues(alpha:0.12) : const Color(0xFF101720),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActive ? accentColor : const Color(0xFF243040),
          width: isActive ? 1.8 : 1.1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: isActive ? accentColor : const Color(0xFF141A22),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.person_rounded,
              color: isActive ? const Color(0xFF06100B) : accentColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Legs $legsWon · Sets $setsWon',
                  style: const TextStyle(
                    color: Color(0xFF9DA8B7),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: const Color(0xFF243040),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isActive ? accentColor : const Color(0xFF6F7A89),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Ziel',
                style: TextStyle(
                  color: Color(0xFF9DA8B7),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                targetLabel,
                style: TextStyle(
                  fontSize: targetLabel == 'Bull' ? 28 : 42,
                  fontWeight: FontWeight.w900,
                  color: isActive ? accentColor : const Color(0xFFEAF1F8),
                ),
              ),
            ],
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