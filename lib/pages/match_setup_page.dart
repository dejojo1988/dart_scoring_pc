import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../models/game_settings.dart';
import '../models/player.dart';
import 'starting_player_page.dart';

class MatchSetupPage extends StatefulWidget {
  final GameSettings initialSettings;

  const MatchSetupPage({
    super.key,
    required this.initialSettings,
  });

  @override
  State<MatchSetupPage> createState() => _MatchSetupPageState();
}

class _MatchSetupPageState extends State<MatchSetupPage> {
  late GameSettings settings;

  final List<Player> availableGuestPlayers = List.generate(
    16,
    (index) => Player.guest(index + 1),
  );

  final List<Player> storedProfilePlayers = [];
  final List<Player> selectedPlayers = [];

  bool isLoadingProfiles = true;
  bool botOpponentEnabled = false;

  bool get isX01 => settings.gameType == GameType.x01;
  bool get isRoundTheClock => settings.gameType == GameType.roundTheClock;

  Player get adaptiveBotPlayer {
    return const Player(
      id: 'bot_adaptive',
      name: 'Bot Gegner',
    );
  }

  bool get canUseBotOpponent {
    return isX01;
  }

  String get playersSubtitle {
    if (selectedPlayers.isEmpty && !botOpponentEnabled) {
      return 'Keine Spieler ausgewählt';
    }

    if (botOpponentEnabled) {
      return '${selectedPlayers.length} Spieler + Bot';
    }

    return '${selectedPlayers.length} von 16 ausgewählt';
  }

  @override
  void initState() {
    super.initState();
    settings = widget.initialSettings;

    if (!isX01) {
      botOpponentEnabled = false;
    }

    _loadStoredProfilePlayers();
  }

  Future<void> _loadStoredProfilePlayers() async {
    setState(() {
      isLoadingProfiles = true;
    });

    final List<Player> loadedProfiles = await AppDatabase.instance.getPlayers();

    if (!mounted) {
      return;
    }

    setState(() {
      storedProfilePlayers
        ..clear()
        ..addAll(loadedProfiles);

      isLoadingProfiles = false;
    });
  }

  void _toggleBotOpponent(bool value) {
    if (value && !canUseBotOpponent) {
      _showMessage('Bot-Gegner ist aktuell nur für x01 verfügbar.');
      return;
    }

    if (value && selectedPlayers.length > 1) {
      _showMessage(
        'Bot-Gegner ist für Solo-Spiel gedacht. Wähle maximal einen menschlichen Spieler.',
      );
      return;
    }

    setState(() {
      botOpponentEnabled = value;
    });
  }

  void _openAddPlayerDialog() {
    final List<Player> tempSelected = List<Player>.from(selectedPlayers);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            final Color accentColor = Theme.of(context).colorScheme.primary;

            bool canAddAnotherPlayer() {
              if (botOpponentEnabled && tempSelected.isNotEmpty) {
                _showMessage(
                  'Bot-Gegner ist nur mit genau einem menschlichen Spieler möglich.',
                );
                return false;
              }

              if (tempSelected.length >= 16) {
                _showMessage('Maximal 16 Spieler möglich.');
                return false;
              }

              return true;
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(28),
              child: Container(
                width: 920,
                constraints: const BoxConstraints(
                  maxHeight: 720,
                ),
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: const Color(0xFF101720),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: const Color(0xFF243040),
                    width: 1.3,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha:0.13),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: accentColor.withValues(alpha:0.25),
                            ),
                          ),
                          child: Icon(
                            Icons.person_add_alt_1_rounded,
                            color: accentColor,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add Player',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Gespeicherte Profile oder Gastspieler auswählen',
                                style: TextStyle(
                                  color: Color(0xFF9DA8B7),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            await _loadStoredProfilePlayers();
                            dialogSetState(() {});
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          color: accentColor,
                          iconSize: 28,
                          tooltip: 'Profile neu laden',
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                          },
                          icon: const Icon(Icons.close_rounded),
                          color: const Color(0xFF9DA8B7),
                          iconSize: 30,
                        ),
                      ],
                    ),
                    if (botOpponentEnabled) ...[
                      const SizedBox(height: 16),
                      _DialogBotInfoBox(
                        accentColor: accentColor,
                      ),
                    ],
                    const SizedBox(height: 22),
                    Expanded(
                      child: ListView(
                        children: [
                          _DialogSectionHeader(
                            title: 'Gespeicherte Profile',
                            subtitle: isLoadingProfiles
                                ? 'Lade Profile...'
                                : '${storedProfilePlayers.length} Profile',
                          ),
                          const SizedBox(height: 12),
                          if (isLoadingProfiles)
                            SizedBox(
                              height: 120,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: accentColor,
                                ),
                              ),
                            )
                          else if (storedProfilePlayers.isEmpty)
                            const _EmptyDialogInfo(
                              icon: Icons.person_off_rounded,
                              title: 'Noch keine Profile gespeichert',
                              subtitle:
                                  'Lege unter Profiles zuerst Spieler an. Gastspieler kannst du unten trotzdem auswählen.',
                            )
                          else
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: storedProfilePlayers.length,
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 190,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 1.35,
                              ),
                              itemBuilder: (context, index) {
                                final Player player =
                                    storedProfilePlayers[index];
                                final bool isSelected = tempSelected.any(
                                  (item) => item.id == player.id,
                                );

                                return _AvailablePlayerCard(
                                  player: player,
                                  isSelected: isSelected,
                                  badgeText: 'Profil',
                                  onTap: () {
                                    dialogSetState(() {
                                      if (isSelected) {
                                        tempSelected.removeWhere(
                                          (item) => item.id == player.id,
                                        );
                                      } else {
                                        if (!canAddAnotherPlayer()) {
                                          return;
                                        }

                                        tempSelected.add(player);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                          const SizedBox(height: 26),
                          const _DialogSectionHeader(
                            title: 'Gastspieler',
                            subtitle: 'temporär für dieses Match',
                          ),
                          const SizedBox(height: 12),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: availableGuestPlayers.length,
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 190,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 1.35,
                            ),
                            itemBuilder: (context, index) {
                              final Player player =
                                  availableGuestPlayers[index];
                              final bool isSelected = tempSelected.any(
                                (item) => item.id == player.id,
                              );

                              return _AvailablePlayerCard(
                                player: player,
                                isSelected: isSelected,
                                badgeText: 'Gast',
                                onTap: () {
                                  dialogSetState(() {
                                    if (isSelected) {
                                      tempSelected.removeWhere(
                                        (item) => item.id == player.id,
                                      );
                                    } else {
                                      if (!canAddAnotherPlayer()) {
                                        return;
                                      }

                                      tempSelected.add(player);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 64,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0B1118),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF243040),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  botOpponentEnabled
                                      ? Icons.smart_toy_rounded
                                      : Icons.groups_rounded,
                                  color: accentColor,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    botOpponentEnabled
                                        ? '${tempSelected.length} von 1 menschlichem Spieler ausgewählt · Bot kommt automatisch dazu'
                                        : '${tempSelected.length} von 16 Spielern ausgewählt',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF9DA8B7),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        SizedBox(
                          width: 190,
                          height: 64,
                          child: ElevatedButton(
                            onPressed: () {
                              if (botOpponentEnabled &&
                                  tempSelected.length > 1) {
                                _showMessage(
                                  'Bot-Gegner braucht genau einen menschlichen Spieler.',
                                );
                                return;
                              }

                              setState(() {
                                selectedPlayers
                                  ..clear()
                                  ..addAll(tempSelected);
                              });

                              Navigator.of(dialogContext).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: const Color(0xFF06100B),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text(
                              'Übernehmen',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _removePlayer(Player player) {
    setState(() {
      selectedPlayers.removeWhere((item) => item.id == player.id);
    });
  }

  void _setMatchMode(MatchMode mode) {
    int target = settings.matchTarget;

    if (mode == MatchMode.bestOf && target % 2 == 0) {
      target = target + 1;
    }

    setState(() {
      settings = settings.copyWith(
        matchMode: mode,
        matchTarget: target,
      );
    });
  }

  void _changeMatchTarget(int value) {
    int newValue = value;

    if (settings.matchMode == MatchMode.bestOf && newValue % 2 == 0) {
      newValue = newValue + 1;
    }

    setState(() {
      settings = settings.copyWith(matchTarget: newValue);
    });
  }

  void _startGame() {
    if (selectedPlayers.isEmpty) {
      _showMessage('Wähle mindestens 1 Spieler aus.');
      return;
    }

    if (botOpponentEnabled) {
      if (!canUseBotOpponent) {
        _showMessage('Bot-Gegner ist aktuell nur für x01 verfügbar.');
        return;
      }

      if (selectedPlayers.length != 1) {
        _showMessage(
          'Bot-Gegner ist für Solo-Spiel gedacht. Wähle genau einen menschlichen Spieler.',
        );
        return;
      }
    }

    final List<Player> playersForMatch = List<Player>.from(selectedPlayers);

    if (botOpponentEnabled) {
      playersForMatch.add(adaptiveBotPlayer);
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StartingPlayerPage(
          settings: settings,
          players: playersForMatch,
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
              accentColor.withValues(alpha:0.20),
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
                const SizedBox(height: 26),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 11,
                        child: _buildPlayersPanel(),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 10,
                        child: _buildSettingsPanel(),
                      ),
                    ],
                  ),
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
            color: accentColor.withValues(alpha:0.13),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accentColor.withValues(alpha:0.25),
            ),
          ),
          child: Icon(
            isX01 ? Icons.tune_rounded : Icons.access_time_filled_rounded,
            color: accentColor,
            size: 34,
          ),
        ),
        const SizedBox(width: 18),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${settings.gameTitle} Setup',
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isX01
                  ? 'Spieler auswählen und Match-Regeln einstellen'
                  : 'Spieler auswählen und Round-the-Clock-Regeln einstellen',
              style: const TextStyle(
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

  Widget _buildPlayersPanel() {
    final int extraBotCards = botOpponentEnabled ? 1 : 0;

    return _Panel(
      title: 'Spieler',
      subtitle: playersSubtitle,
      child: selectedPlayers.isEmpty && !botOpponentEnabled
          ? Center(
              child: _EmptyPlayerSelection(
                onTap: _openAddPlayerDialog,
              ),
            )
          : GridView.builder(
              itemCount: selectedPlayers.length + extraBotCards + 1,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 210,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.45,
              ),
              itemBuilder: (context, index) {
                if (index < selectedPlayers.length) {
                  final player = selectedPlayers[index];

                  return _PlayerCard(
                    player: player,
                    onRemove: () {
                      _removePlayer(player);
                    },
                    isProfile: player.id.startsWith('profile_'),
                    isBot: false,
                  );
                }

                if (botOpponentEnabled && index == selectedPlayers.length) {
                  return _PlayerCard(
                    player: adaptiveBotPlayer,
                    onRemove: () {
                      _toggleBotOpponent(false);
                    },
                    isProfile: false,
                    isBot: true,
                  );
                }

                return _AddPlayerCard(onTap: _openAddPlayerDialog);
              },
            ),
    );
  }

  Widget _buildSettingsPanel() {
    return _Panel(
      title: 'Game Settings',
      subtitle: settings.matchFormatLabel,
      child: ListView(
        children: [
          if (isX01) ...[
            const _SectionTitle('Startscore'),
            const SizedBox(height: 12),
            _ChoiceRow(
              children: [
                _ChoiceButton(
                  label: '301',
                  selected: settings.x01StartScore == X01StartScore.score301,
                  onTap: () {
                    setState(() {
                      settings = settings.copyWith(
                        x01StartScore: X01StartScore.score301,
                      );
                    });
                  },
                ),
                _ChoiceButton(
                  label: '501',
                  selected: settings.x01StartScore == X01StartScore.score501,
                  onTap: () {
                    setState(() {
                      settings = settings.copyWith(
                        x01StartScore: X01StartScore.score501,
                      );
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 26),
            const _SectionTitle('Bot-Gegner'),
            const SizedBox(height: 12),
            _BotOpponentCard(
              enabled: botOpponentEnabled,
              selectedHumanPlayers: selectedPlayers.length,
              onChanged: _toggleBotOpponent,
            ),
            const SizedBox(height: 26),
          ],
          if (isRoundTheClock) ...[
            const _InfoBox(
              text:
                  'Round the Clock braucht keine 301/501-Auswahl, keine In-Regel und keine Out-Regel. Ziel: Zahlen der Reihe nach treffen.',
            ),
            const SizedBox(height: 26),
            const _InfoBox(
              text:
                  'Bot-Gegner ist in dieser Beta zuerst nur für x01 aktiviert. Round the Clock bekommt den Bot später separat.',
            ),
            const SizedBox(height: 26),
          ],
          const _SectionTitle('Match-Modus'),
          const SizedBox(height: 12),
          _ChoiceRow(
            children: [
              _ChoiceButton(
                label: 'Best of',
                selected: settings.matchMode == MatchMode.bestOf,
                onTap: () {
                  _setMatchMode(MatchMode.bestOf);
                },
              ),
              _ChoiceButton(
                label: 'First to',
                selected: settings.matchMode == MatchMode.firstTo,
                onTap: () {
                  _setMatchMode(MatchMode.firstTo);
                },
              ),
            ],
          ),
          const SizedBox(height: 26),
          const _SectionTitle('Zählart'),
          const SizedBox(height: 12),
          _ChoiceRow(
            children: [
              _ChoiceButton(
                label: 'Legs',
                selected: settings.matchUnit == MatchUnit.legs,
                onTap: () {
                  setState(() {
                    settings = settings.copyWith(matchUnit: MatchUnit.legs);
                  });
                },
              ),
              _ChoiceButton(
                label: 'Sets',
                selected: settings.matchUnit == MatchUnit.sets,
                onTap: () {
                  setState(() {
                    settings = settings.copyWith(matchUnit: MatchUnit.sets);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 26),
          const _SectionTitle('Anzahl'),
          const SizedBox(height: 12),
          _NumberSelector(
            label: settings.matchMode == MatchMode.bestOf
                ? 'Best of ${settings.matchUnitLabel}'
                : 'First to ${settings.matchUnitLabel}',
            value: settings.matchTarget,
            min: 1,
            max: 19,
            step: settings.matchMode == MatchMode.bestOf ? 2 : 1,
            onChanged: _changeMatchTarget,
          ),
          const SizedBox(height: 14),
          _InfoBox(
            text:
                '${settings.matchFormatLabel} bedeutet: Zum Sieg benötigt man ${settings.neededToWin} ${settings.matchUnit == MatchUnit.legs ? 'gewonnene Legs' : 'gewonnene Sets'}.',
          ),
          if (isX01) ...[
            const SizedBox(height: 26),
            const _SectionTitle('In-Regel'),
            const SizedBox(height: 12),
            _ChoiceRow(
              children: [
                _ChoiceButton(
                  label: 'Straight In',
                  selected: settings.inMode == InMode.straightIn,
                  onTap: () {
                    setState(() {
                      settings = settings.copyWith(inMode: InMode.straightIn);
                    });
                  },
                ),
                _ChoiceButton(
                  label: 'Double In',
                  selected: settings.inMode == InMode.doubleIn,
                  onTap: () {
                    setState(() {
                      settings = settings.copyWith(inMode: InMode.doubleIn);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 26),
            const _SectionTitle('Out-Regel'),
            const SizedBox(height: 12),
            _ChoiceRow(
              children: [
                _ChoiceButton(
                  label: 'Straight Out',
                  selected: settings.outMode == OutMode.straightOut,
                  onTap: () {
                    setState(() {
                      settings =
                          settings.copyWith(outMode: OutMode.straightOut);
                    });
                  },
                ),
                _ChoiceButton(
                  label: 'Double Out',
                  selected: settings.outMode == OutMode.doubleOut,
                  onTap: () {
                    setState(() {
                      settings = settings.copyWith(outMode: OutMode.doubleOut);
                    });
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final String botText = botOpponentEnabled ? ' · Bot aktiv' : '';

    final String rulesText = isX01
        ? '${settings.gameTitle} · ${settings.matchFormatLabel} · ${settings.inModeLabel} · ${settings.outModeLabel} · Spieler: ${selectedPlayers.length}$botText'
        : '${settings.gameTitle} · ${settings.matchFormatLabel} · Spieler: ${selectedPlayers.length}';

    final Color accentColor = Theme.of(context).colorScheme.primary;

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
                  botOpponentEnabled
                      ? Icons.smart_toy_rounded
                      : Icons.info_outline_rounded,
                  color: botOpponentEnabled
                      ? accentColor
                      : const Color(0xFF9DA8B7),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    rulesText,
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
          width: 260,
          child: ElevatedButton(
            onPressed: _startGame,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  selectedPlayers.isEmpty ? const Color(0xFF243040) : accentColor,
              foregroundColor: selectedPlayers.isEmpty
                  ? const Color(0xFF6F7A89)
                  : const Color(0xFF06100B),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text(
              'Start Game',
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
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

class _DialogSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _DialogSectionHeader({
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
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFEAF1F8),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF9DA8B7),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DialogBotInfoBox extends StatelessWidget {
  final Color accentColor;

  const _DialogBotInfoBox({
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha:0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accentColor.withValues(alpha:0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.smart_toy_rounded,
            color: accentColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Bot aktiv: Wähle genau einen menschlichen Spieler. Der Bot wird beim Start automatisch als Gegner hinzugefügt.',
              style: TextStyle(
                color: Color(0xFFEAF1F8),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDialogInfo extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyDialogInfo({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 128,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141A22),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF2A3545),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFF566172),
            size: 46,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF9DA8B7),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPlayerSelection extends StatelessWidget {
  final VoidCallback onTap;

  const _EmptyPlayerSelection({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: const Color(0xFF141A22),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: accentColor,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.add_rounded,
                color: accentColor,
                size: 78,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Spieler hinzufügen',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Klicke auf das Plus und wähle Profile oder Gäste aus.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF9DA8B7),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final Player player;
  final VoidCallback onRemove;
  final bool isProfile;
  final bool isBot;

  const _PlayerCard({
    required this.player,
    required this.onRemove,
    required this.isProfile,
    required this.isBot,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    final String badgeLabel = isBot
        ? 'Bot'
        : isProfile
            ? 'Profil'
            : 'Gast';

    final IconData icon = isBot
        ? Icons.smart_toy_rounded
        : isProfile
            ? Icons.person_pin_rounded
            : Icons.person_rounded;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = constraints.maxHeight < 112;
        final double iconSize = compact ? 26 : 34;
        final double nameSize = compact ? 14 : 18;
        final double badgeFontSize = compact ? 9 : 11;
        final double badgeHorizontalPadding = compact ? 6 : 8;
        final double badgeVerticalPadding = compact ? 3 : 4;

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141A22),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isProfile || isBot ? accentColor : const Color(0xFF2A3545),
              width: isProfile || isBot ? 1.4 : 1,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: compact ? 7 : 10,
                top: compact ? 7 : 10,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: badgeHorizontalPadding,
                    vertical: badgeVerticalPadding,
                  ),
                  decoration: BoxDecoration(
                    color: isProfile || isBot
                        ? accentColor.withValues(alpha: 0.14)
                        : const Color(0xFF243040),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badgeLabel,
                    style: TextStyle(
                      color: isProfile || isBot
                          ? accentColor
                          : const Color(0xFF9DA8B7),
                      fontSize: badgeFontSize,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: compact ? 3 : 6,
                top: compact ? 3 : 6,
                child: IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded),
                  color: const Color(0xFF9DA8B7),
                  tooltip: 'Entfernen',
                  iconSize: compact ? 18 : 22,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints.tightFor(
                    width: compact ? 30 : 36,
                    height: compact ? 30 : 36,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              Center(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 8 : 12,
                    compact ? 26 : 34,
                    compact ? 8 : 12,
                    compact ? 7 : 12,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icon,
                          color: accentColor,
                          size: iconSize,
                        ),
                        SizedBox(height: compact ? 4 : 8),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth - (compact ? 20 : 28),
                          ),
                          child: Text(
                            player.name,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: nameSize,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (isBot && !compact) ...[
                          const SizedBox(height: 5),
                          const Text(
                            'Adaptive KI',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFF9DA8B7),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AddPlayerCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddPlayerCard({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Material(
      color: const Color(0xFF141A22),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: accentColor.withValues(alpha:0.45),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.add_circle_outline_rounded,
              color: accentColor,
              size: 52,
            ),
          ),
        ),
      ),
    );
  }
}

class _AvailablePlayerCard extends StatelessWidget {
  final Player player;
  final bool isSelected;
  final String badgeText;
  final VoidCallback onTap;

  const _AvailablePlayerCard({
    required this.player,
    required this.isSelected,
    required this.badgeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isProfile = badgeText == 'Profil';
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = constraints.maxHeight < 112;
        final double iconSize = compact ? 26 : 34;
        final double nameSize = compact ? 14 : 17;
        final double badgeFontSize = compact ? 9 : 10;

        return Material(
          color: isSelected ? accentColor : const Color(0xFF141A22),
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              padding: EdgeInsets.all(compact ? 8 : 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isSelected
                      ? accentColor
                      : isProfile
                          ? accentColor.withValues(alpha: 0.55)
                          : const Color(0xFF2A3545),
                  width: 1.4,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 6 : 8,
                        vertical: compact ? 3 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF06100B).withValues(alpha: 0.14)
                            : isProfile
                                ? accentColor.withValues(alpha: 0.14)
                                : const Color(0xFF243040),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFF06100B)
                              : isProfile
                                  ? accentColor
                                  : const Color(0xFF9DA8B7),
                          fontSize: badgeFontSize,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 4 : 6,
                        compact ? 22 : 28,
                        compact ? 4 : 6,
                        compact ? 4 : 6,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : isProfile
                                      ? Icons.person_pin_rounded
                                      : Icons.person_rounded,
                              color: isSelected
                                  ? const Color(0xFF06100B)
                                  : accentColor,
                              size: iconSize,
                            ),
                            SizedBox(height: compact ? 4 : 8),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth:
                                    constraints.maxWidth - (compact ? 20 : 28),
                              ),
                              child: Text(
                                player.name,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFF06100B)
                                      : const Color(0xFFEAF1F8),
                                  fontSize: nameSize,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
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
}

class _BotOpponentCard extends StatelessWidget {
  final bool enabled;
  final int selectedHumanPlayers;
  final ValueChanged<bool> onChanged;

  const _BotOpponentCard({
    required this.enabled,
    required this.selectedHumanPlayers,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;
    final bool hasTooManyPlayers = selectedHumanPlayers > 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: enabled ? accentColor.withValues(alpha:0.11) : const Color(0xFF141A22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: enabled ? accentColor : const Color(0xFF2A3545),
          width: enabled ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: enabled ? accentColor : const Color(0xFF101720),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              Icons.smart_toy_rounded,
              color: enabled ? const Color(0xFF06100B) : accentColor,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Adaptive Bot-Gegner',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  hasTooManyPlayers
                      ? 'Nur für Solo-Spiel: maximal ein menschlicher Spieler.'
                      : 'Fügt beim Start einen Bot hinzu. Schwierigkeit orientiert sich am x01 Average des ausgewählten Profils.',
                  style: TextStyle(
                    color:
                        hasTooManyPlayers ? const Color(0xFFFFB020) : const Color(0xFF9DA8B7),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.32,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: enabled,
            activeThumbColor: accentColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFEAF1F8),
        fontSize: 17,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  final List<Widget> children;

  const _ChoiceRow({
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(children.length, (index) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index == children.length - 1 ? 0 : 12,
            ),
            child: children[index],
          ),
        );
      }),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return SizedBox(
      height: 58,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: selected ? accentColor : const Color(0xFF141A22),
          foregroundColor:
              selected ? const Color(0xFF06100B) : const Color(0xFFEAF1F8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: selected ? accentColor : const Color(0xFF2A3545),
            ),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _NumberSelector extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  const _NumberSelector({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  void _decrease() {
    final nextValue = value - step;
    if (nextValue >= min) {
      onChanged(nextValue);
    }
  }

  void _increase() {
    final nextValue = value + step;
    if (nextValue <= max) {
      onChanged(nextValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF141A22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF2A3545),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF9DA8B7),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: value <= min ? null : _decrease,
            icon: const Icon(Icons.remove_circle_outline_rounded),
            color: accentColor,
            disabledColor: const Color(0xFF3A4554),
            iconSize: 32,
          ),
          SizedBox(
            width: 58,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            onPressed: value >= max ? null : _increase,
            icon: const Icon(Icons.add_circle_outline_rounded),
            color: accentColor,
            disabledColor: const Color(0xFF3A4554),
            iconSize: 32,
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String text;

  const _InfoBox({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1118),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF243040),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: accentColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF9DA8B7),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}