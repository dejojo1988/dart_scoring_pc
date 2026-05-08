import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../models/player.dart';
import 'spread_analysis_session_page.dart';
import 'training_stats_page.dart';

class TrainingPage extends StatefulWidget {
  const TrainingPage({super.key});

  @override
  State<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage> {
  static const List<int> _dartCountOptions = [30, 60, 100];
  static const List<_TrainingTarget> _targetOptions = [
    _TrainingTarget(label: 'T20', segment: 20, ring: 'Triple'),
    _TrainingTarget(label: 'T19', segment: 19, ring: 'Triple'),
    _TrainingTarget(label: 'T18', segment: 18, ring: 'Triple'),
    _TrainingTarget(label: 'D20', segment: 20, ring: 'Double'),
    _TrainingTarget(label: 'D16', segment: 16, ring: 'Double'),
    _TrainingTarget(label: 'Bull', segment: 25, ring: 'Bull'),
    _TrainingTarget(label: 'S20', segment: 20, ring: 'Single'),
  ];

  late final Future<List<Player>> _playersFuture;

  Player? _selectedPlayer;
  int _selectedDartCount = 30;
  _TrainingTarget _selectedTarget = _targetOptions.first;

  @override
  void initState() {
    super.initState();
    _playersFuture = AppDatabase.instance.getPlayers();
  }

  void _startSpreadAnalysisSession() {
    final Player? selectedPlayer = _selectedPlayer;

    if (selectedPlayer == null) {
      _showMessage('Bitte zuerst ein Profil auswählen.');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SpreadAnalysisSessionPage(
          player: selectedPlayer,
          plannedDarts: _selectedDartCount,
          targetLabel: _selectedTarget.label,
          targetSegment: _selectedTarget.segment,
          targetRing: _selectedTarget.ring,
        ),
      ),
    );
  }

  void _openTrainingStats() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const TrainingStatsPage(),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
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
              accentColor.withValues(alpha: 0.18),
              const Color(0xFF0B0F14),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 34),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 28),
                Expanded(
                  child: SingleChildScrollView(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildIntroCard(context),
                            const SizedBox(height: 22),
                            _buildStatsShortcutCard(context),
                            const SizedBox(height: 22),
                            _buildSpreadAnalysisCard(context),
                          ],
                        ),
                      ),
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

  Widget _buildHeader(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 16),
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.25),
            ),
          ),
          child: Icon(
            Icons.track_changes_rounded,
            color: accentColor,
            size: 32,
          ),
        ),
        const SizedBox(width: 18),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Training',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Trainingsspiele, Streuungsanalyse und spätere Profil-Auswertung',
                style: TextStyle(
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

  Widget _buildIntroCard(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF111821).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              Icons.analytics_rounded,
              color: accentColor,
              size: 30,
            ),
          ),
          const SizedBox(width: 18),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Streuungsanalyse',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Wähle Profil, Ziel und Dartanzahl. Danach tippst du jeden Dart direkt auf dem Board an. '
                  'Die App speichert die Session getrennt von Match-Statistiken und erstellt eine erste Analyse.',
                  style: TextStyle(
                    color: Color(0xFFB8C3D3),
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsShortcutCard(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0F151D).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF243244),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.query_stats_rounded,
              color: accentColor,
              size: 29,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trainingsstatistik',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Sieh dir gespeicherte Sessions, beste Scores, häufige Ziele und die letzten Empfehlungen an.',
                  style: TextStyle(
                    color: Color(0xFF9DA8B7),
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _openTrainingStats,
              icon: const Icon(Icons.bar_chart_rounded),
              label: const Text('Statistik anzeigen'),
              style: OutlinedButton.styleFrom(
                foregroundColor: accentColor,
                side: BorderSide(
                  color: accentColor.withValues(alpha: 0.55),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpreadAnalysisCard(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F151D).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFF243244),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.adjust_rounded,
                color: accentColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Streuungsanalyse starten',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Wähle Profil, Ziel und Trainingsumfang.',
                      style: TextStyle(
                        color: Color(0xFF8D99AA),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(
                label: 'Board-Tap aktiv',
                icon: Icons.touch_app_rounded,
                color: accentColor,
              ),
            ],
          ),
          const SizedBox(height: 28),
          _buildSectionTitle('Profil'),
          const SizedBox(height: 12),
          FutureBuilder<List<Player>>(
            future: _playersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _LoadingBox(label: 'Profile werden geladen ...');
              }

              if (snapshot.hasError) {
                return _InfoBox(
                  icon: Icons.error_outline_rounded,
                  title: 'Profile konnten nicht geladen werden.',
                  text: snapshot.error.toString(),
                );
              }

              final List<Player> players = snapshot.data ?? [];

              if (players.isEmpty) {
                return const _InfoBox(
                  icon: Icons.person_add_alt_1_rounded,
                  title: 'Noch keine Profile vorhanden.',
                  text:
                      'Lege zuerst im Profilbereich einen Spieler an, damit Trainingsdaten sauber gespeichert werden können.',
                );
              }

              _selectedPlayer ??= players.first;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: players.map((player) {
                  final bool isSelected = _selectedPlayer?.id == player.id;

                  return ChoiceChip(
                    selected: isSelected,
                    showCheckmark: false,
                    label: Text(player.name),
                    avatar: Icon(
                      Icons.person_rounded,
                      size: 18,
                      color:
                          isSelected ? Colors.white : const Color(0xFF8D99AA),
                    ),
                    selectedColor: accentColor.withValues(alpha: 0.78),
                    backgroundColor: const Color(0xFF182231),
                    side: BorderSide(
                      color: isSelected
                          ? accentColor.withValues(alpha: 0.95)
                          : const Color(0xFF2A3748),
                    ),
                    labelStyle: TextStyle(
                      color:
                          isSelected ? Colors.white : const Color(0xFFDCE5F2),
                      fontWeight: FontWeight.w800,
                    ),
                    onSelected: (_) {
                      setState(() {
                        _selectedPlayer = player;
                      });
                    },
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 26),
          _buildSectionTitle('Dartanzahl'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _dartCountOptions.map((dartCount) {
              final bool isSelected = _selectedDartCount == dartCount;

              return _SelectionTile(
                title: '$dartCount Darts',
                subtitle: dartCount == 30
                    ? 'Kurzer Test'
                    : dartCount == 60
                        ? 'Normales Training'
                        : 'Ausführliche Analyse',
                selected: isSelected,
                icon: Icons.sports_martial_arts_rounded,
                onTap: () {
                  setState(() {
                    _selectedDartCount = dartCount;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 26),
          _buildSectionTitle('Zielfeld'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _targetOptions.map((target) {
              final bool isSelected = _selectedTarget == target;

              return _SelectionTile(
                title: target.label,
                subtitle: '${target.ring} · Segment ${target.segment}',
                selected: isSelected,
                icon: Icons.my_location_rounded,
                onTap: () {
                  setState(() {
                    _selectedTarget = target;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: _SummaryBox(
                  title: 'Auswahl',
                  value: '${_selectedTarget.label} · $_selectedDartCount Darts',
                  icon: Icons.fact_check_rounded,
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                height: 58,
                child: FilledButton.icon(
                  onPressed: _startSpreadAnalysisSession,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Session starten'),
                  style: FilledButton.styleFrom(
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFFE7EEF8),
        fontSize: 15,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _TrainingTarget {
  final String label;
  final int segment;
  final String ring;

  const _TrainingTarget({
    required this.label,
    required this.segment,
    required this.ring,
  });
}

class _SelectionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SelectionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 178,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? accentColor.withValues(alpha: 0.18)
              : const Color(0xFF151E29),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? accentColor.withValues(alpha: 0.88)
                : const Color(0xFF263445),
            width: selected ? 1.8 : 1.1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: selected ? accentColor : const Color(0xFF8D99AA),
              size: 26,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFF8D99AA),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryBox({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF151E29),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF263445),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: accentColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF8D99AA),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _StatusPill({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.38),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _InfoBox({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151E29),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF2A3748),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: const Color(0xFF9DA8B7),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFF9DA8B7),
                    height: 1.35,
                    fontWeight: FontWeight.w500,
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

class _LoadingBox extends StatelessWidget {
  final String label;

  const _LoadingBox({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151E29),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF2A3748),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9DA8B7),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
