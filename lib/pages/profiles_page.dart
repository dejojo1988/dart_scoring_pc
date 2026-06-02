import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../data/app_database.dart';
import '../models/player.dart';
import '../services/player_name_audio_service.dart';

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
  bool audioActionRunning = false;

  @override
  void initState() {
    super.initState();
    _loadPlayersAndStats();
  }

  Future<void> _loadPlayersAndStats() async {
    setState(() => isLoading = true);

    final loadedPlayers = await AppDatabase.instance.getPlayers();
    final loadedStats = await AppDatabase.instance.getAllPlayerStats();
    final loadedDartStats = await AppDatabase.instance.getAllPlayerDartStats();
    final loadedAdvancedX01Stats =
        await AppDatabase.instance.getAllPlayerX01AdvancedStats();

    if (!mounted) return;

    setState(() {
      final selectedId = selectedPlayer?.id;
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
        selectedPlayer = players.firstWhere(
          (player) => player.id == selectedId,
          orElse: () => players.first,
        );
      }

      isLoading = false;
    });
  }

  Future<void> _createPlayer(String name, BuildContext dialogContext) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      _showMessage('Bitte gib einen Spielernamen ein.');
      return;
    }

    final exists = await AppDatabase.instance.playerNameExists(cleanName);
    if (!mounted) return;

    if (exists) {
      _showMessage('Ein Spieler mit diesem Namen existiert bereits.');
      return;
    }

    final player = Player(
      id: 'profile_${DateTime.now().millisecondsSinceEpoch}',
      name: cleanName,
    );

    await AppDatabase.instance.insertPlayer(player);
    selectedPlayer = player;
    await _loadPlayersAndStats();

    if (!mounted || !dialogContext.mounted) return;
    Navigator.of(dialogContext).pop();
    _showMessage('Profil "$cleanName" wurde gespeichert.');
  }

  Future<void> _renamePlayer(
    Player player,
    String newName,
    BuildContext dialogContext,
  ) async {
    final cleanName = newName.trim();
    if (cleanName.isEmpty) {
      _showMessage('Bitte gib einen Spielernamen ein.');
      return;
    }

    if (cleanName == player.name) {
      Navigator.of(dialogContext).pop();
      return;
    }

    final exists = await AppDatabase.instance.playerNameExistsForOtherPlayer(
      name: cleanName,
      currentPlayerId: player.id,
    );

    if (!mounted) return;

    if (exists) {
      _showMessage('Ein anderer Spieler nutzt diesen Namen bereits.');
      return;
    }

    await AppDatabase.instance.updatePlayerName(
      playerId: player.id,
      newName: cleanName,
    );

    selectedPlayer = player.copyWith(name: cleanName);
    await _loadPlayersAndStats();

    if (!mounted || !dialogContext.mounted) return;
    Navigator.of(dialogContext).pop();
    _showMessage('Profil wurde umbenannt in "$cleanName".');
  }

  Future<void> _deletePlayer(Player player) async {
    await PlayerNameAudioService.instance.deleteStoredNameAudioForPlayer(player);
    await AppDatabase.instance.deletePlayer(player.id);
    if (!mounted) return;
    selectedPlayer = null;
    await _loadPlayersAndStats();
    if (!mounted) return;
    _showMessage('${player.name} wurde gelöscht.');
  }

  Future<void> _loadNameAudio(Player player) async {
    if (audioActionRunning) return;
    setState(() => audioActionRunning = true);

    try {
      final storedPath =
          await PlayerNameAudioService.instance.pickAndStoreNameAudioForPlayer(player);
      if (storedPath == null) return;

      await AppDatabase.instance.updatePlayerCustomNameAudioPath(
        playerId: player.id,
        customNameAudioPath: storedPath,
      );

      selectedPlayer = player.copyWith(customNameAudioPath: storedPath);
      await _loadPlayersAndStats();
      if (!mounted) return;
      _showMessage('Name-Ansage für ${player.name} wurde gespeichert.');
    } catch (_) {
      if (mounted) _showMessage('Name-Ansage konnte nicht geladen werden.');
    } finally {
      if (mounted) setState(() => audioActionRunning = false);
    }
  }

  Future<void> _testNameAudio(Player player) async {
    final played = await PlayerNameAudioService.instance.playNameAudioForPlayer(
      player,
      waitForCompletion: true,
    );
    if (!played) _showMessage('Keine gültige Name-Ansage gefunden.');
  }

  Future<void> _removeNameAudio(Player player) async {
    if (audioActionRunning) return;
    setState(() => audioActionRunning = true);
    try {
      await PlayerNameAudioService.instance.deleteStoredNameAudioForPlayer(player);
      await AppDatabase.instance.updatePlayerCustomNameAudioPath(
        playerId: player.id,
        customNameAudioPath: null,
      );
      selectedPlayer = player.copyWith(clearCustomNameAudioPath: true);
      await _loadPlayersAndStats();
      if (!mounted) return;
      _showMessage('Name-Ansage für ${player.name} wurde entfernt.');
    } finally {
      if (mounted) setState(() => audioActionRunning = false);
    }
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
          'average': 0,
          'form_average': 0,
          'form_darts': 0,
          'score_180_count': 0,
          'score_140_plus_count': 0,
          'score_100_plus_count': 0,
        };
  }

  Map<String, num> _advancedStatsForPlayer(Player player) {
    return playerAdvancedX01StatsById[player.id] ??
        {
          'best_leg_301_darts': 0,
          'best_leg_501_darts': 0,
          'best_leg_rtc_darts': 0,
          'checkout_percentage': 0,
          'double_percentage': 0,
          'highest_finish': 0,
          'bust_count': 0,
          'classic_count': 0,
        };
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1B2430),
      ),
    );
  }

  void _openCreateProfileDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => _NameDialog(
        title: 'Profil anlegen',
        subtitle: 'Erstelle einen neuen Spieler',
        icon: Icons.person_add_alt_1_rounded,
        controller: controller,
        primaryLabel: 'Profil speichern',
        onSubmit: () => _createPlayer(controller.text, dialogContext),
      ),
    );
  }

  void _openEditProfileDialog(Player player) {
    final controller = TextEditingController(text: player.name);
    showDialog(
      context: context,
      builder: (dialogContext) => _NameDialog(
        title: 'Profil bearbeiten',
        subtitle: 'Spielernamen ändern',
        icon: Icons.edit_rounded,
        controller: controller,
        primaryLabel: 'Änderung speichern',
        onSubmit: () => _renamePlayer(player, controller.text, dialogContext),
      ),
    );
  }

  void _openDeleteProfileDialog(Player player) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF101720),
        title: const Text('Profil wirklich löschen?'),
        content: Text('${player.name} und alle zugehörigen Daten werden gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _deletePlayer(player);
            },
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;

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
                _buildHeader(),
                const SizedBox(height: 34),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(flex: 9, child: _buildProfilePanel()),
                      const SizedBox(width: 24),
                      Expanded(flex: 11, child: _buildStatsPanel()),
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

  Widget _buildHeader() {
    final accentColor = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          color: Colors.white,
          iconSize: 32,
        ),
        const SizedBox(width: 14),
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accentColor.withValues(alpha: 0.25)),
          ),
          child: Icon(Icons.groups_rounded, color: accentColor, size: 34),
        ),
        const SizedBox(width: 18),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profiles',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 4),
            Text(
              'Spieler verwalten, Namensansagen speichern und Fortschritt sehen',
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
                    ? const Center(child: Text('Noch keine Profile'))
                    : ListView.separated(
                        itemCount: players.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final player = players[index];
                          final stats = _statsForPlayer(player);
                          final selected = selectedPlayer?.id == player.id;
                          final hasAudio = PlayerNameAudioService.instance
                              .hasUsableNameAudio(player);

                          return _PlayerProfileCard(
                            player: player,
                            selected: selected,
                            gamesPlayed: stats['games_played'] ?? 0,
                            wins: stats['wins'] ?? 0,
                            hasAudio: hasAudio,
                            onTap: () => setState(() => selectedPlayer = player),
                            onDelete: () => _openDeleteProfileDialog(player),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsPanel() {
    final player = selectedPlayer;
    return _Panel(
      title: player == null ? 'Statistiken' : player.name,
      subtitle: player == null ? 'Kein Spieler ausgewählt' : 'Live-Profilwerte',
      child: player == null
          ? const Center(child: Text('Lege ein Profil an oder wähle links einen Spieler aus.'))
          : _buildPlayerStats(player),
    );
  }

  Widget _buildPlayerStats(Player player) {
    final stats = _statsForPlayer(player);
    final dartStats = _dartStatsForPlayer(player);
    final advanced = _advancedStatsForPlayer(player);
    final hasAudio = PlayerNameAudioService.instance.hasUsableNameAudio(player);
    final audioPath = player.customNameAudioPath;
    final audioLabel = audioPath == null || audioPath.trim().isEmpty
        ? 'Keine Name-Ansage geladen'
        : path.basename(audioPath);

    return Column(
      children: [
        Container(
          height: 150,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF141A22),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF2A3545)),
          ),
          child: Row(
            children: [
              Icon(
                hasAudio ? Icons.record_voice_over_rounded : Icons.person_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 42,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      player.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      audioLabel,
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MiniButton(
                    label: 'Bearbeiten',
                    icon: Icons.edit_rounded,
                    onPressed: () => _openEditProfileDialog(player),
                  ),
                  _MiniButton(
                    label: 'Name laden',
                    icon: Icons.upload_file_rounded,
                    onPressed: audioActionRunning ? null : () => _loadNameAudio(player),
                  ),
                  _MiniButton(
                    label: 'Testen',
                    icon: Icons.play_arrow_rounded,
                    onPressed: hasAudio && !audioActionRunning
                        ? () => _testNameAudio(player)
                        : null,
                  ),
                  _MiniButton(
                    label: 'Entfernen',
                    icon: Icons.delete_outline_rounded,
                    danger: true,
                    onPressed: hasAudio && !audioActionRunning
                        ? () => _removeNameAudio(player)
                        : null,
                  ),
                ],
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
              _StatPreviewCard(label: 'Gesamt Ø', value: _averageValue((dartStats['average'] ?? 0).toDouble())),
              _StatPreviewCard(label: 'Form Ø', value: _averageValue((dartStats['form_average'] ?? 0).toDouble())),
              _StatPreviewCard(label: 'Best Leg 301', value: _bestLegValue((advanced['best_leg_301_darts'] ?? 0).toInt())),
              _StatPreviewCard(label: 'Best Leg 501', value: _bestLegValue((advanced['best_leg_501_darts'] ?? 0).toInt())),
              _StatPreviewCard(label: 'Best Leg RTC', value: _bestLegValue((advanced['best_leg_rtc_darts'] ?? 0).toInt())),
              _StatPreviewCard(label: 'Checkout %', value: '${(advanced['checkout_percentage'] ?? 0).toDouble().toStringAsFixed(1)}%'),
              _StatPreviewCard(label: 'Doppel %', value: '${(advanced['double_percentage'] ?? 0).toDouble().toStringAsFixed(1)}%'),
              _StatPreviewCard(label: 'High Checkout', value: ((advanced['highest_finish'] ?? 0).toInt()) <= 0 ? '-' : '${(advanced['highest_finish'] ?? 0).toInt()}'),
              _StatPreviewCard(label: 'Busts', value: '${(advanced['bust_count'] ?? 0).toInt()}'),
              _StatPreviewCard(label: 'Classics', value: '${(advanced['classic_count'] ?? 0).toInt()}'),
              _StatPreviewCard(label: 'Matches won', value: '${stats['wins'] ?? 0}'),
              _StatPreviewCard(label: 'Legs won', value: '${stats['legs_won'] ?? 0}'),
              _StatPreviewCard(label: '180s', value: '${(dartStats['score_180_count'] ?? 0).toInt()}'),
              _StatPreviewCard(label: '100+', value: '${(dartStats['score_100_plus_count'] ?? 0).toInt()}'),
              _StatPreviewCard(label: '140+', value: '${(dartStats['score_140_plus_count'] ?? 0).toInt()}'),
            ],
          ),
        ),
      ],
    );
  }
}

class _NameDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final TextEditingController controller;
  final String primaryLabel;
  final Future<void> Function() onSubmit;

  const _NameDialog({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.controller,
    required this.primaryLabel,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 620,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: const Color(0xFF101720),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFF243040)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: accent, size: 34),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                      Text(subtitle, style: const TextStyle(color: Color(0xFF9DA8B7))),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: 'Spielername',
                filled: true,
                fillColor: const Color(0xFF141A22),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onSubmitted: (_) => onSubmit(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Abbrechen'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onSubmit,
                    child: Text(primaryLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _Panel({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF101720),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF243040), width: 1.2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.radio_button_checked, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
              const Spacer(),
              Text(subtitle, style: const TextStyle(color: Color(0xFF9DA8B7), fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 22),
          Expanded(child: child),
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

  const _BigActionButton({required this.title, required this.subtitle, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 116,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF141A22),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFF243040)),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: accent, size: 34),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(subtitle, style: const TextStyle(color: Color(0xFF9DA8B7), fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _PlayerProfileCard extends StatelessWidget {
  final Player player;
  final bool selected;
  final int gamesPlayed;
  final int wins;
  final bool hasAudio;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PlayerProfileCard({
    required this.player,
    required this.selected,
    required this.gamesPlayed,
    required this.wins,
    required this.hasAudio,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Material(
      color: selected ? accent.withValues(alpha: 0.12) : const Color(0xFF141A22),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 104,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: selected ? accent : const Color(0xFF2A3545)),
          ),
          child: Row(
            children: [
              Icon(hasAudio ? Icons.record_voice_over_rounded : Icons.person_rounded, color: accent, size: 34),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(player.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(
                      hasAudio ? '$gamesPlayed Spiele · $wins Siege · Name-Audio' : '$gamesPlayed Spiele · $wins Siege',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF9DA8B7), fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded), color: const Color(0xFFFF5C77)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool danger;

  const _MiniButton({required this.label, required this.icon, required this.onPressed, this.danger = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF101720),
          foregroundColor: danger ? const Color(0xFFFF5C77) : const Color(0xFFEAF1F8),
          disabledBackgroundColor: const Color(0xFF101720),
          disabledForegroundColor: const Color(0xFF566172),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: danger ? const Color(0xFF3A2430) : const Color(0xFF2A3545)),
          ),
        ),
      ),
    );
  }
}

class _StatPreviewCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatPreviewCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final placeholder = value == '-';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF141A22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A3545)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF9DA8B7), fontWeight: FontWeight.w700))),
          const SizedBox(width: 12),
          Text(value, style: TextStyle(color: placeholder ? const Color(0xFF6F7A89) : Theme.of(context).colorScheme.primary, fontSize: placeholder ? 20 : 24, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

String _averageValue(double value) {
  if (value <= 0 || value.isNaN || value.isInfinite) return '-';
  return value.toStringAsFixed(2);
}

String _bestLegValue(int darts) {
  if (darts <= 0) return '-';
  return '$darts Darts';
}