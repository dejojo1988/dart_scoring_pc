import 'dart:math';

import 'package:flutter/material.dart';

import '../models/game_settings.dart';
import '../models/player.dart';
import 'match_page.dart';
import 'round_the_clock_match_page.dart';

class StartingPlayerPage extends StatefulWidget {
  final GameSettings settings;
  final List<Player> players;

  const StartingPlayerPage({
    super.key,
    required this.settings,
    required this.players,
  });

  @override
  State<StartingPlayerPage> createState() => _StartingPlayerPageState();
}

class _StartingPlayerPageState extends State<StartingPlayerPage> {
  Player? selectedPlayer;
  bool hasRolled = false;

  void _rollStartingPlayer() {
    if (widget.players.isEmpty) {
      return;
    }

    final random = Random();
    final index = random.nextInt(widget.players.length);

    setState(() {
      selectedPlayer = widget.players[index];
      hasRolled = true;
    });
  }

  void _continueToMatch() {
    final Player? player = selectedPlayer;

    if (player == null) {
      return;
    }

    if (widget.settings.gameType == GameType.roundTheClock) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => RoundTheClockMatchPage(
            settings: widget.settings,
            players: widget.players,
            startingPlayer: player,
          ),
        ),
      );

      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MatchPage(
          settings: widget.settings,
          players: widget.players,
          startingPlayer: player,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Player? player = selectedPlayer;
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.1,
            colors: [
              accentColor.withOpacity(0.20),
              const Color(0xFF0B0F14),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 30),
            child: Column(
              children: [
                _buildHeader(context),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 720,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: const Color(0xFF101720),
                            borderRadius: BorderRadius.circular(34),
                            border: Border.all(
                              color: const Color(0xFF243040),
                              width: 1.3,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.casino_rounded,
                                color: accentColor,
                                size: 64,
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'Wer beginnt?',
                                style: TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${widget.settings.gameTitle} · ${widget.settings.matchFormatLabel}',
                                style: const TextStyle(
                                  color: Color(0xFF9DA8B7),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 28),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                child: player == null
                                    ? _buildWaitingBox()
                                    : _buildSelectedPlayerBox(player),
                              ),
                              const SizedBox(height: 28),
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 66,
                                      child: ElevatedButton(
                                        onPressed: _rollStartingPlayer,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF141A22),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(22),
                                            side: const BorderSide(
                                              color: Color(0xFF2A3545),
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          hasRolled
                                              ? 'Neu auslosen'
                                              : 'Startspieler auslosen',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    child: SizedBox(
                                      height: 66,
                                      child: ElevatedButton(
                                        onPressed: player == null
                                            ? null
                                            : _continueToMatch,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: accentColor,
                                          disabledBackgroundColor:
                                              const Color(0xFF243040),
                                          foregroundColor:
                                              const Color(0xFF06100B),
                                          disabledForegroundColor:
                                              const Color(0xFF6F7A89),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(22),
                                          ),
                                        ),
                                        child: const Text(
                                          'Weiter zum Match',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _buildPlayerList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final bool isRoundTheClock =
        widget.settings.gameType == GameType.roundTheClock;
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
            color: accentColor.withOpacity(0.13),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accentColor.withOpacity(0.25),
            ),
          ),
          child: Icon(
            isRoundTheClock
                ? Icons.access_time_filled_rounded
                : Icons.casino_rounded,
            color: accentColor,
            size: 34,
          ),
        ),
        const SizedBox(width: 18),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isRoundTheClock ? 'Round the Clock Start' : 'Startspieler',
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Zufällig entscheiden, wer das Match beginnt',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF9DA8B7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWaitingBox() {
    return Container(
      key: const ValueKey('waiting'),
      height: 130,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF141A22),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFF2A3545),
        ),
      ),
      child: const Center(
        child: Text(
          'Noch kein Spieler ausgelost',
          style: TextStyle(
            color: Color(0xFF9DA8B7),
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedPlayerBox(Player player) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      key: ValueKey(player.id),
      height: 130,
      width: double.infinity,
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: accentColor,
          width: 1.5,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Beginnt:',
              style: TextStyle(
                color: Color(0xFF9DA8B7),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              player.name,
              style: const TextStyle(
                color: Color(0xFFEAF1F8),
                fontSize: 38,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerList() {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 18),
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
            Icons.groups_rounded,
            color: accentColor,
          ),
          const SizedBox(width: 14),
          const Text(
            'Teilnehmer:',
            style: TextStyle(
              color: Color(0xFF9DA8B7),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: widget.players.map((player) {
                  final bool isSelected = selectedPlayer?.id == player.id;

                  return Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accentColor
                          : const Color(0xFF141A22),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isSelected
                            ? accentColor
                            : const Color(0xFF2A3545),
                      ),
                    ),
                    child: Text(
                      player.name,
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFF06100B)
                            : const Color(0xFFEAF1F8),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}