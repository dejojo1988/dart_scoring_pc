import 'dart:async';
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
  Player? selectedStartingPlayer;

  bool isRollingStartingPlayer = false;
  int? rollingHighlightedIndex;
  int rollToken = 0;

  @override
  void initState() {
    super.initState();

    if (widget.players.isNotEmpty) {
      selectedStartingPlayer = widget.players.first;
      rollingHighlightedIndex = 0;
    }
  }

  @override
  void dispose() {
    rollToken++;
    super.dispose();
  }

  Future<void> _selectRandomStartingPlayer() async {
    if (widget.players.isEmpty || isRollingStartingPlayer) {
      return;
    }

    final Random random = Random();
    final int playerCount = widget.players.length;

    final int selectedIndex = selectedStartingPlayer == null
        ? -1
        : widget.players.indexWhere(
            (player) => player.id == selectedStartingPlayer!.id,
          );

    int currentIndex = rollingHighlightedIndex ??
        (selectedIndex >= 0 ? selectedIndex : 0);

    final int winnerIndex = random.nextInt(playerCount);

    final int rawStepsToWinner = (winnerIndex - currentIndex) % playerCount;
    final int stepsToWinner =
        rawStepsToWinner == 0 ? playerCount : rawStepsToWinner;

    final int totalTicks = (playerCount * 3) + stepsToWinner;
    final int currentRollToken = ++rollToken;

    setState(() {
      isRollingStartingPlayer = true;
      rollingHighlightedIndex = currentIndex;
    });

    await Future<void>.delayed(const Duration(milliseconds: 140));

    for (int tick = 0; tick < totalTicks; tick++) {
      final double progress = tick / totalTicks;

      final int delayMs = progress < 0.55
          ? 70
          : progress < 0.82
              ? 115
              : 175;

      await Future<void>.delayed(Duration(milliseconds: delayMs));

      if (!mounted || currentRollToken != rollToken) {
        return;
      }

      currentIndex = (currentIndex + 1) % playerCount;

      setState(() {
        rollingHighlightedIndex = currentIndex;
        selectedStartingPlayer = widget.players[currentIndex];
      });
    }

    await Future<void>.delayed(const Duration(milliseconds: 260));

    if (!mounted || currentRollToken != rollToken) {
      return;
    }

    setState(() {
      selectedStartingPlayer = widget.players[winnerIndex];
      rollingHighlightedIndex = winnerIndex;
      isRollingStartingPlayer = false;
    });
  }

  void _startMatch() {
    if (isRollingStartingPlayer) {
      _showMessage('Der Zufallsgenerator läuft gerade.');
      return;
    }

    final Player? startingPlayer = selectedStartingPlayer;

    if (startingPlayer == null) {
      _showMessage('Wähle einen Startspieler aus.');
      return;
    }

    if (widget.settings.gameType == GameType.roundTheClock) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => RoundTheClockMatchPage(
            settings: widget.settings,
            players: widget.players,
            startingPlayer: startingPlayer,
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
          startingPlayer: startingPlayer,
        ),
      ),
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
                const SizedBox(height: 28),
                Expanded(
                  child: _buildPlayerSelectionPanel(),
                ),
                const SizedBox(height: 22),
                _buildBottomBar(),
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
          onPressed: isRollingStartingPlayer
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          icon: const Icon(Icons.arrow_back_rounded),
          color: Colors.white,
          disabledColor: const Color(0xFF566172),
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
            Icons.shuffle_rounded,
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
                'Startspieler',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.settings.gameTitle} · ${widget.settings.matchFormatLabel}',
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

  Widget _buildPlayerSelectionPanel() {
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
        children: [
          Row(
            children: [
              Icon(
                isRollingStartingPlayer
                    ? Icons.casino_rounded
                    : Icons.radio_button_checked,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Text(
                isRollingStartingPlayer ? 'Zufall läuft...' : 'Wer beginnt?',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '${widget.players.length} Spieler',
                style: const TextStyle(
                  color: Color(0xFF9DA8B7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Expanded(
            child: GridView.builder(
              itemCount: widget.players.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 250,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.75,
              ),
              itemBuilder: (context, index) {
                final Player player = widget.players[index];

                final bool isSelected =
                    !isRollingStartingPlayer &&
                    selectedStartingPlayer?.id == player.id;

                final bool isRollingHighlight =
                    isRollingStartingPlayer &&
                    rollingHighlightedIndex == index;

                return _StartingPlayerCard(
                  player: player,
                  isSelected: isSelected,
                  isRollingHighlight: isRollingHighlight,
                  isInteractionLocked: isRollingStartingPlayer,
                  onTap: () {
                    setState(() {
                      selectedStartingPlayer = player;
                      rollingHighlightedIndex = index;
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final Color accentColor = Theme.of(context).colorScheme.primary;
    final Player? startingPlayer = selectedStartingPlayer;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 78,
            padding: const EdgeInsets.symmetric(horizontal: 24),
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
                  isRollingStartingPlayer
                      ? Icons.casino_rounded
                      : Icons.info_outline_rounded,
                  color: accentColor,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    isRollingStartingPlayer
                        ? 'Der Zufallsgenerator wählt den Startspieler...'
                        : startingPlayer == null
                            ? 'Noch kein Startspieler ausgewählt.'
                            : '${startingPlayer.name} beginnt das Match.',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF9DA8B7),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 18),
        SizedBox(
          height: 78,
          width: 240,
          child: ElevatedButton.icon(
            onPressed:
                isRollingStartingPlayer ? null : _selectRandomStartingPlayer,
            icon: Icon(
              isRollingStartingPlayer
                  ? Icons.hourglass_top_rounded
                  : Icons.casino_rounded,
            ),
            label: Text(isRollingStartingPlayer ? 'Läuft...' : 'Zufällig'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF141A22),
              foregroundColor: accentColor,
              disabledBackgroundColor: const Color(0xFF243040),
              disabledForegroundColor: const Color(0xFF6F7A89),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(
                  color: Color(0xFF243040),
                ),
              ),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        SizedBox(
          height: 78,
          width: 260,
          child: ElevatedButton(
            onPressed: isRollingStartingPlayer ? null : _startMatch,
            style: ElevatedButton.styleFrom(
              backgroundColor: startingPlayer == null || isRollingStartingPlayer
                  ? const Color(0xFF243040)
                  : accentColor,
              foregroundColor: startingPlayer == null || isRollingStartingPlayer
                  ? const Color(0xFF6F7A89)
                  : const Color(0xFF06100B),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text(
              'Match starten',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StartingPlayerCard extends StatelessWidget {
  final Player player;
  final bool isSelected;
  final bool isRollingHighlight;
  final bool isInteractionLocked;
  final VoidCallback onTap;

  const _StartingPlayerCard({
    required this.player,
    required this.isSelected,
    required this.isRollingHighlight,
    required this.isInteractionLocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;
    final bool isActive = isSelected || isRollingHighlight;

    final Color backgroundColor = isSelected
        ? accentColor
        : isRollingHighlight
            ? accentColor.withValues(alpha: 0.28)
            : const Color(0xFF141A22);

    final Color foregroundColor = isSelected
        ? const Color(0xFF06100B)
        : isRollingHighlight
            ? const Color(0xFFEAF1F8)
            : Colors.white;

    final Color iconColor = isSelected
        ? const Color(0xFF06100B)
        : isRollingHighlight
            ? accentColor
            : accentColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 115),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActive ? accentColor : const Color(0xFF2A3545),
          width: isActive ? 2.0 : 1.1,
        ),
        boxShadow: [
          if (isRollingHighlight)
            BoxShadow(
              color: accentColor.withValues(alpha: 0.45),
              blurRadius: 28,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          if (isSelected)
            BoxShadow(
              color: accentColor.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: isInteractionLocked ? null : onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 115),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF06100B).withValues(alpha: 0.14)
                        : isRollingHighlight
                            ? accentColor.withValues(alpha: 0.22)
                            : accentColor.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isRollingHighlight
                          ? accentColor
                          : Colors.transparent,
                    ),
                  ),
                  child: Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : isRollingHighlight
                            ? Icons.flash_on_rounded
                            : Icons.person_rounded,
                    color: iconColor,
                    size: 31,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    player.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foregroundColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}