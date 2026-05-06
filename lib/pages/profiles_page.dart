import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../models/player.dart';

class ProfilesPage extends StatefulWidget {
  const ProfilesPage({super.key});

  @override
  State<ProfilesPage> createState() => _ProfilesPageState();
}

class _ProfilesPageState extends State<ProfilesPage> {
  final List<Player> players = [];
  final Map<String, Map<String, int>> playerStatsById = {};
  final Map<String, Map<String, num>> playerDartStatsById = {};
  final Map<String, Map<String, num>> playerAdvancedX01StatsById = {};

  Player? selectedPlayer;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlayersAndStats();
  }

  Future<void> _loadPlayersAndStats() async {
    setState(() {
      isLoading = true;
    });

    final List<Player> loadedPlayers = await AppDatabase.instance.getPlayers();
    final Map<String, Map<String, int>> loadedStats =
        await AppDatabase.instance.getAllPlayerStats();
    final Map<String, Map<String, num>> loadedDartStats =
        await AppDatabase.instance.getAllPlayerDartStats();
    final Map<String, Map<String, num>> loadedAdvancedX01Stats =
        await AppDatabase.instance.getAllPlayerX01AdvancedStats();

    if (!mounted) {
      return;
    }

    setState(() {
      final String? selectedId = selectedPlayer?.id;

      players
        ..clear()
        ..addAll(loadedPlayers);

      playerStatsById
        ..clear()
        ..addAll(loadedStats);

      playerDartStatsById
        ..clear()
        ..addAll(loadedDartStats);

      playerAdvancedX01StatsById
        ..clear()
        ..addAll(loadedAdvancedX01Stats);

      if (players.isEmpty) {
        selectedPlayer = null;
      } else if (selectedId == null) {
        selectedPlayer = players.first;
      } else {
        final List<Player> matchingPlayers = players.where(
          (player) => player.id == selectedId,
        ).toList();

        selectedPlayer =
            matchingPlayers.isEmpty ? players.first : matchingPlayers.first;
      }

      isLoading = false;
    });
  }

  void _openCreateProfileDialog() {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        final Color accentColor = Theme.of(context).colorScheme.primary;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(28),
          child: Container(
            width: 620,
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
              mainAxisSize: MainAxisSize.min,
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
                            'Profil anlegen',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Erstelle einen neuen Spieler',
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
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                      },
                      icon: const Icon(Icons.close_rounded),
                      color: const Color(0xFF9DA8B7),
                      iconSize: 30,
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: _inputDecoration(
                    label: 'Spielername',
                    hint: 'Dein Name',
                  ),
                  onSubmitted: (_) async {
                    await _createProfileFromDialog(
                      dialogContext: dialogContext,
                      name: nameController.text,
                    );
                  },
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: _DialogButton(
                        label: 'Abbrechen',
                        isPrimary: false,
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _DialogButton(
                        label: 'Profil speichern',
                        isPrimary: true,
                        onPressed: () async {
                          await _createProfileFromDialog(
                            dialogContext: dialogContext,
                            name: nameController.text,
                          );
                        },
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
  }

  void _openEditProfileDialog(Player player) {
    final TextEditingController nameController = TextEditingController(
      text: player.name,
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        final Color accentColor = Theme.of(context).colorScheme.primary;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(28),
          child: Container(
            width: 620,
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
              mainAxisSize: MainAxisSize.min,
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
                        Icons.edit_rounded,
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
                            'Profil bearbeiten',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Spielernamen ändern',
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
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                      },
                      icon: const Icon(Icons.close_rounded),
                      color: const Color(0xFF9DA8B7),
                      iconSize: 30,
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: _inputDecoration(
                    label: 'Neuer Spielername',
                    hint: 'z. B. Jochen',
                  ),
                  onSubmitted: (_) async {
                    await _updateProfileFromDialog(
                      dialogContext: dialogContext,
                      player: player,
                      newName: nameController.text,
                    );
                  },
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: _DialogButton(
                        label: 'Abbrechen',
                        isPrimary: false,
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _DialogButton(
                        label: 'Änderung speichern',
                        isPrimary: true,
                        onPressed: () async {
                          await _updateProfileFromDialog(
                            dialogContext: dialogContext,
                            player: player,
                            newName: nameController.text,
                          );
                        },
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
  }

  void _openDeleteProfileDialog(Player player) {
    final Map<String, int> stats = _statsForPlayer(player);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(28),
          child: Container(
            width: 660,
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: const Color(0xFF101720),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: const Color(0xFF3A2430),
                width: 1.3,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5C77).withValues(alpha:0.13),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFFF5C77).withValues(alpha:0.35),
                        ),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFFF5C77),
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Profil wirklich löschen?',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            player.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF9DA8B7),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141A22),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: const Color(0xFF2A3545),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Das wird dauerhaft gelöscht:',
                        style: TextStyle(
                          color: Color(0xFFEAF1F8),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DeleteInfoLine(
                        label: 'Profil',
                        value: player.name,
                      ),
                      _DeleteInfoLine(
                        label: 'Gespielte Spiele',
                        value: '${stats['games_played'] ?? 0}',
                      ),
                      _DeleteInfoLine(
                        label: 'Siege',
                        value: '${stats['wins'] ?? 0}',
                      ),
                      _DeleteInfoLine(
                        label: 'Niederlagen',
                        value: '${stats['losses'] ?? 0}',
                      ),
                      _DeleteInfoLine(
                        label: 'Legs gewonnen',
                        value: '${stats['legs_won'] ?? 0}',
                      ),
                      _DeleteInfoLine(
                        label: 'Sets gewonnen',
                        value: '${stats['sets_won'] ?? 0}',
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Dieser Schritt kann nicht rückgängig gemacht werden.',
                        style: TextStyle(
                          color: Color(0xFFFF5C77),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: _DialogButton(
                        label: 'Abbrechen',
                        isPrimary: false,
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _DialogButton(
                        label: 'Profil löschen',
                        isPrimary: false,
                        isDanger: true,
                        onPressed: () async {
                          Navigator.of(dialogContext).pop();
                          await _deletePlayer(player);
                        },
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
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(
        color: Color(0xFF9DA8B7),
        fontWeight: FontWeight.w700,
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF566172),
      ),
      filled: true,
      fillColor: const Color(0xFF141A22),
      prefixIcon: Icon(
        Icons.person_rounded,
        color: Theme.of(context).colorScheme.primary,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(
          color: Color(0xFF2A3545),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.5,
        ),
      ),
    );
  }

  Future<void> _createProfileFromDialog({
  required BuildContext dialogContext,
  required String name,
}) async {
  final String cleanedName = name.trim();

  if (cleanedName.isEmpty) {
    _showMessage('Bitte gib einen Spielernamen ein.');
    return;
  }

  final bool nameAlreadyExists =
      await AppDatabase.instance.playerNameExists(cleanedName);

  if (!mounted) {
    return;
  }

  if (nameAlreadyExists) {
    _showMessage('Ein Spieler mit diesem Namen existiert bereits.');
    return;
  }

  final Player newPlayer = Player(
    id: 'profile_${DateTime.now().millisecondsSinceEpoch}',
    name: cleanedName,
  );

  await AppDatabase.instance.insertPlayer(newPlayer);

  if (!mounted) {
    return;
  }

  setState(() {
    selectedPlayer = newPlayer;
  });

  await _loadPlayersAndStats();

  if (!mounted || !dialogContext.mounted) {
    return;
  }

  Navigator.of(dialogContext).pop();
  _showMessage('Profil "$cleanedName" wurde gespeichert.');
}

  Future<void> _updateProfileFromDialog({
  required BuildContext dialogContext,
  required Player player,
  required String newName,
}) async {
  final String cleanedName = newName.trim();

  if (cleanedName.isEmpty) {
    _showMessage('Bitte gib einen Spielernamen ein.');
    return;
  }

  if (cleanedName == player.name) {
    if (dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }

    return;
  }

  final bool nameAlreadyExists =
      await AppDatabase.instance.playerNameExistsForOtherPlayer(
    name: cleanedName,
    currentPlayerId: player.id,
  );

  if (!mounted) {
    return;
  }

  if (nameAlreadyExists) {
    _showMessage('Ein anderer Spieler nutzt diesen Namen bereits.');
    return;
  }

  await AppDatabase.instance.updatePlayerName(
    playerId: player.id,
    newName: cleanedName,
  );

  if (!mounted) {
    return;
  }

  setState(() {
    selectedPlayer = Player(
      id: player.id,
      name: cleanedName,
    );
  });

  await _loadPlayersAndStats();

  if (!mounted || !dialogContext.mounted) {
    return;
  }

  Navigator.of(dialogContext).pop();
  _showMessage('Profil wurde umbenannt in "$cleanedName".');
}

  void _selectPlayer(Player player) {
    setState(() {
      selectedPlayer = player;
    });
  }

  Future<void> _deletePlayer(Player player) async {
    await AppDatabase.instance.deletePlayer(player.id);

    if (!mounted) {
      return;
    }

    if (selectedPlayer?.id == player.id) {
      selectedPlayer = null;
    }

    await _loadPlayersAndStats();

    if (!mounted) {
      return;
    }

    _showMessage('${player.name} wurde gelöscht.');
  }

  Map<String, int> _statsForPlayer(Player player) {
    return playerStatsById[player.id] ??
        {
          'games_played': 0,
          'wins': 0,
          'losses': 0,
          'legs_won': 0,
          'sets_won': 0,
        };
  }

  Map<String, num> _dartStatsForPlayer(Player player) {
    return playerDartStatsById[player.id] ??
        {
          'turn_count': 0,
          'total_score': 0,
          'total_darts': 0,
          'average': 0,
          'highest_score': 0,
          'score_180_count': 0,
          'score_140_plus_count': 0,
          'score_100_plus_count': 0,
        };
  }

  Map<String, num> _advancedX01StatsForPlayer(Player player) {
    return playerAdvancedX01StatsById[player.id] ??
        {
          'highest_finish': 0,
          'first_9_average': 0,
          'first_9_score': 0,
          'first_9_darts': 0,
          'best_leg_darts': 0,
          'checkout_attempts': 0,
          'checkout_successes': 0,
          'checkout_percentage': 0,
          'double_attempts': 0,
          'double_hits': 0,
          'double_percentage': 0,
          'bust_count': 0,
        };
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
                const SizedBox(height: 34),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 9,
                        child: _buildProfilePanel(),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 11,
                        child: _buildStatsPanel(player),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Profiles — ${players.length} Spieler dauerhaft gespeichert',
                  style: const TextStyle(
                    color: Color(0xFF6F7A89),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
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
            color: accentColor.withValues(alpha:0.13),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accentColor.withValues(alpha:0.25),
            ),
          ),
          child: Icon(
            Icons.groups_rounded,
            color: accentColor,
            size: 34,
          ),
        ),
        const SizedBox(width: 18),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profiles',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Spieler verwalten, Statistiken speichern und Fortschritt sehen',
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

  Widget _buildProfilePanel() {
    return _Panel(
      title: 'Spieler verwalten',
      subtitle: isLoading ? 'Lade...' : '${players.length} Profile',
      child: Column(
        children: [
          _BigActionButton(
            title: 'Profil anlegen',
            subtitle: 'Neuen Spieler dauerhaft speichern',
            icon: Icons.person_add_alt_1_rounded,
            onTap: _openCreateProfileDialog,
          ),
          const SizedBox(height: 18),
          Expanded(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                : players.isEmpty
                    ? _buildEmptyPlayersList()
                    : _buildPlayersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPlayersList() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: const Color(0xFF141A22),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF2A3545),
        ),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off_rounded,
            color: Color(0xFF566172),
            size: 62,
          ),
          SizedBox(height: 18),
          Text(
            'Noch keine Profile',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Klicke auf „Profil anlegen“, um den ersten Spieler zu speichern.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF9DA8B7),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersList() {
    return ListView.separated(
      itemCount: players.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final Player player = players[index];
        final bool isSelected = selectedPlayer?.id == player.id;
        final Map<String, int> stats = _statsForPlayer(player);

        return _PlayerProfileCard(
          player: player,
          isSelected: isSelected,
          gamesPlayed: stats['games_played'] ?? 0,
          wins: stats['wins'] ?? 0,
          onTap: () {
            _selectPlayer(player);
          },
          onDelete: () {
            _openDeleteProfileDialog(player);
          },
        );
      },
    );
  }

  Widget _buildStatsPanel(Player? player) {
    return _Panel(
      title: player == null ? 'Statistiken' : player.name,
      subtitle: player == null ? 'Kein Spieler ausgewählt' : 'Echte Basiswerte',
      child: player == null
          ? _buildNoPlayerSelected()
          : _buildPlayerStatsPreview(player),
    );
  }

  Widget _buildNoPlayerSelected() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: const Color(0xFF141A22),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF2A3545),
        ),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_rounded,
            color: Color(0xFF566172),
            size: 70,
          ),
          SizedBox(height: 18),
          Text(
            'Kein Spieler ausgewählt',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Lege ein Profil an oder wähle links einen Spieler aus.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF9DA8B7),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerStatsPreview(Player player) {
    final Map<String, int> stats = _statsForPlayer(player);

    final int wins = stats['wins'] ?? 0;
    final int legsWon = stats['legs_won'] ?? 0;

    final Map<String, num> dartStats = _dartStatsForPlayer(player);
    final double average = (dartStats['average'] ?? 0).toDouble();
    final int score180Count = (dartStats['score_180_count'] ?? 0).toInt();
    final int score140PlusCount =
        (dartStats['score_140_plus_count'] ?? 0).toInt();
    final int score100PlusCount =
        (dartStats['score_100_plus_count'] ?? 0).toInt();

    final Map<String, num> advancedX01Stats =
        _advancedX01StatsForPlayer(player);
    final int bestLegDarts =
        (advancedX01Stats['best_leg_darts'] ?? 0).toInt();
    final double checkoutPercentage =
        (advancedX01Stats['checkout_percentage'] ?? 0).toDouble();
    final double doublePercentage =
        (advancedX01Stats['double_percentage'] ?? 0).toDouble();
    final int highestFinish =
        (advancedX01Stats['highest_finish'] ?? 0).toInt();
    final int bustCount = (advancedX01Stats['bust_count'] ?? 0).toInt();

    final String bestLegValue = bestLegDarts <= 0 ? '-' : '$bestLegDarts Darts';

    return Column(
      children: [
        Container(
          height: 104,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            color: const Color(0xFF141A22),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF2A3545),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha:0.13),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: Theme.of(context).colorScheme.primary,
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
                      player.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Profilstatistiken',
                      style: TextStyle(
                        color: Color(0xFF9DA8B7),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _openEditProfileDialog(player);
                  },
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Bearbeiten'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF101720),
                    foregroundColor: const Color(0xFFEAF1F8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(
                        color: Color(0xFF2A3545),
                      ),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 2.6,
            children: [
              _StatPreviewCard(
                label: 'Average',
                value: average.toStringAsFixed(2),
              ),
              _StatPreviewCard(
                label: 'Best Leg',
                value: bestLegValue,
              ),
              _StatPreviewCard(
                label: 'Checkout %',
                value: '${checkoutPercentage.toStringAsFixed(1)}%',
              ),
              _StatPreviewCard(
                label: 'Doppel %',
                value: '${doublePercentage.toStringAsFixed(1)}%',
              ),
              _StatPreviewCard(
                label: 'High Checkout',
                value: '$highestFinish',
              ),
              _StatPreviewCard(
                label: 'Busts',
                value: '$bustCount',
              ),
              _StatPreviewCard(
                label: 'Matches won',
                value: '$wins',
              ),
              _StatPreviewCard(
                label: 'Legs won',
                value: '$legsWon',
              ),
              _StatPreviewCard(
                label: '180s',
                value: '$score180Count',
              ),
              _StatPreviewCard(
                label: '100+',
                value: '$score100PlusCount',
              ),
              _StatPreviewCard(
                label: '140+',
                value: '$score140PlusCount',
              ),
            ],
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
                Icons.radio_button_checked,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Text(
                title,
                overflow: TextOverflow.ellipsis,
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

class _DialogButton extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final bool isDanger;
  final VoidCallback onPressed;

  const _DialogButton({
    required this.label,
    required this.isPrimary,
    required this.onPressed,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color foregroundColor;
    Color borderColor;

    if (isDanger) {
      backgroundColor = const Color(0xFFFF5C77);
      foregroundColor = Colors.white;
      borderColor = const Color(0xFFFF5C77);
    } else if (isPrimary) {
      backgroundColor = Theme.of(context).colorScheme.primary;
      foregroundColor = const Color(0xFF06100B);
      borderColor = Theme.of(context).colorScheme.primary;
    } else {
      backgroundColor = const Color(0xFF141A22);
      foregroundColor = const Color(0xFFEAF1F8);
      borderColor = const Color(0xFF2A3545);
    }

    return SizedBox(
      height: 62,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: borderColor),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _DeleteInfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _DeleteInfoLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF9DA8B7),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFEAF1F8),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _BigActionButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _BigActionButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return SizedBox(
      height: 116,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF141A22),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(
              color: Color(0xFF243040),
              width: 1.2,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha:0.13),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                icon,
                color: accentColor,
                size: 31,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF9DA8B7),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF9DA8B7),
              size: 32,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerProfileCard extends StatelessWidget {
  final Player player;
  final bool isSelected;
  final int gamesPlayed;
  final int wins;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PlayerProfileCard({
    required this.player,
    required this.isSelected,
    required this.gamesPlayed,
    required this.wins,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Material(
      color: isSelected ? accentColor.withValues(alpha:0.12) : const Color(0xFF141A22),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 104,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected ? accentColor : const Color(0xFF2A3545),
              width: isSelected ? 1.6 : 1.1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isSelected ? accentColor : const Color(0xFF101720),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: isSelected ? const Color(0xFF06100B) : accentColor,
                  size: 31,
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
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$gamesPlayed Spiele · $wins Siege',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF9DA8B7),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                color: const Color(0xFFFF5C77),
                tooltip: 'Profil löschen',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatPreviewCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatPreviewCard({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPlaceholder = value == 'später';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF9DA8B7),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              color: isPlaceholder
                  ? const Color(0xFF6F7A89)
                  : Theme.of(context).colorScheme.primary,
              fontSize: isPlaceholder ? 16 : 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}