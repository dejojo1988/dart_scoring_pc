import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../models/player.dart';
import 'training_session_detail_page.dart';

class TrainingStatsPage extends StatefulWidget {
  const TrainingStatsPage({super.key});

  @override
  State<TrainingStatsPage> createState() => _TrainingStatsPageState();
}

class _TrainingStatsPageState extends State<TrainingStatsPage> {
  late Future<List<Player>> _playersFuture;
  Player? _selectedPlayer;

  @override
  void initState() {
    super.initState();
    _playersFuture = AppDatabase.instance.getPlayers();
  }

  void _reload() {
    setState(() {
      _playersFuture = AppDatabase.instance.getPlayers();
    });
  }

  void _openSessionDetail({
    required Player player,
    required TrainingSessionListItem session,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TrainingSessionDetailPage(
          player: player,
          sessionId: session.id,
        ),
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
            padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 22),
                Expanded(
                  child: FutureBuilder<List<Player>>(
                    future: _playersFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: _LoadingBox(
                              label: 'Trainingsdaten werden geladen ...'),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: _InfoBox(
                            icon: Icons.error_outline_rounded,
                            title: 'Profile konnten nicht geladen werden.',
                            text: snapshot.error.toString(),
                          ),
                        );
                      }

                      final List<Player> players = snapshot.data ?? [];

                      if (players.isEmpty) {
                        return const Center(
                          child: _InfoBox(
                            icon: Icons.person_add_alt_1_rounded,
                            title: 'Noch keine Profile vorhanden.',
                            text:
                                'Lege zuerst ein Profil an, damit Trainingsstatistiken einem Spieler zugeordnet werden können.',
                          ),
                        );
                      }

                      if (_selectedPlayer == null ||
                          !players.any(
                              (player) => player.id == _selectedPlayer!.id)) {
                        _selectedPlayer = players.first;
                      }

                      final Player selectedPlayer = _selectedPlayer!;

                      return SingleChildScrollView(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1180),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildPlayerCard(
                                  context: context,
                                  players: players,
                                  selectedPlayer: selectedPlayer,
                                ),
                                const SizedBox(height: 22),
                                _buildStatsArea(selectedPlayer),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
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
            Icons.query_stats_rounded,
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
                'Trainingsstatistik',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Separate Auswertung für Training, ohne Match-Averages zu verfälschen',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF9DA8B7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: _reload,
          tooltip: 'Neu laden',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  Widget _buildPlayerCard({
    required BuildContext context,
    required List<Player> players,
    required Player selectedPlayer,
  }) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_search_rounded,
                color: accentColor,
                size: 26,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profil auswählen',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Die Training-Statistik ist bewusst getrennt von der Match-Statistik.',
                      style: TextStyle(
                        color: Color(0xFF8D99AA),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: players.map((player) {
              final bool isSelected = selectedPlayer.id == player.id;

              return ChoiceChip(
                selected: isSelected,
                showCheckmark: false,
                label: Text(player.name),
                avatar: Icon(
                  Icons.person_rounded,
                  size: 18,
                  color: isSelected ? Colors.white : const Color(0xFF8D99AA),
                ),
                selectedColor: accentColor.withValues(alpha: 0.78),
                backgroundColor: const Color(0xFF182231),
                side: BorderSide(
                  color: isSelected
                      ? accentColor.withValues(alpha: 0.95)
                      : const Color(0xFF2A3748),
                ),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFFDCE5F2),
                  fontWeight: FontWeight.w800,
                ),
                onSelected: (_) {
                  setState(() {
                    _selectedPlayer = player;
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsArea(Player selectedPlayer) {
    return FutureBuilder<TrainingStatsSummary>(
      future: AppDatabase.instance.getTrainingStatsSummary(selectedPlayer.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingBox(label: 'Statistik wird berechnet ...');
        }

        if (snapshot.hasError) {
          return _InfoBox(
            icon: Icons.error_outline_rounded,
            title: 'Trainingsstatistik konnte nicht geladen werden.',
            text: snapshot.error.toString(),
          );
        }

        final TrainingStatsSummary summary = snapshot.data ??
            TrainingStatsSummary.empty(playerId: selectedPlayer.id);

        if (!summary.hasSessions) {
          return _EmptyTrainingStats(playerName: selectedPlayer.name);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildOverviewGrid(summary),
            const SizedBox(height: 22),
            _buildLastAnalysisCard(summary),
            const SizedBox(height: 22),
            _buildRecentSessionsCard(summary, selectedPlayer),
          ],
        );
      },
    );
  }

  Widget _buildOverviewGrid(TrainingStatsSummary summary) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        _StatCard(
          title: 'Sessions',
          value: summary.sessionCount.toString(),
          subtitle: 'gespeichert',
          icon: Icons.folder_copy_rounded,
        ),
        _StatCard(
          title: 'Trainingsdarts',
          value: summary.totalDarts.toString(),
          subtitle: 'gesamt',
          icon: Icons.sports_martial_arts_rounded,
        ),
        _StatCard(
          title: 'Ø Darts',
          value: _formatNumber(summary.averageDartsPerSession),
          subtitle: 'pro Session',
          icon: Icons.av_timer_rounded,
        ),
        _StatCard(
          title: 'Häufigstes Ziel',
          value: summary.favoriteTargetLabel,
          subtitle: 'Training-Fokus',
          icon: Icons.my_location_rounded,
        ),
        _StatCard(
          title: 'Ø Accuracy',
          value: _formatScore(summary.averageAccuracyScore),
          subtitle: 'Schnitt',
          icon: Icons.center_focus_strong_rounded,
        ),
        _StatCard(
          title: 'Ø Grouping',
          value: _formatScore(summary.averageGroupingScore),
          subtitle: 'Schnitt',
          icon: Icons.blur_circular_rounded,
        ),
        _StatCard(
          title: 'Best Accuracy',
          value: _formatScore(summary.bestAccuracyScore),
          subtitle: 'bester Wert',
          icon: Icons.emoji_events_rounded,
        ),
        _StatCard(
          title: 'Best Grouping',
          value: _formatScore(summary.bestGroupingScore),
          subtitle: 'bester Wert',
          icon: Icons.workspace_premium_rounded,
        ),
      ],
    );
  }

  Widget _buildLastAnalysisCard(TrainingStatsSummary summary) {
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
                Icons.psychology_alt_rounded,
                color: accentColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Letzte Analyse',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _SmallPill(
                label: summary.lastTargetLabel,
                icon: Icons.track_changes_rounded,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MiniInfo(
                label: 'Letzte Session',
                value: _formatDate(summary.lastFinishedAt),
              ),
              _MiniInfo(
                label: 'Hauptfehler',
                value: summary.lastMainErrorDirection,
              ),
              _MiniInfo(
                label: 'Ø Konstanz',
                value: _formatScore(summary.averageConsistencyScore),
              ),
              _MiniInfo(
                label: 'Best Konstanz',
                value: _formatScore(summary.bestConsistencyScore),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _TextBlock(
            title: 'Analyse',
            text: summary.lastAnalysisText.isEmpty
                ? 'Noch keine Analyse gespeichert.'
                : summary.lastAnalysisText,
          ),
          const SizedBox(height: 14),
          _TextBlock(
            title: 'Tipp',
            text: summary.lastTipsText.isEmpty
                ? 'Noch kein Tipp gespeichert.'
                : summary.lastTipsText,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSessionsCard(
      TrainingStatsSummary summary, Player selectedPlayer) {
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
                Icons.history_rounded,
                color: accentColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Letzte Sessions',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${summary.recentSessions.length} angezeigt',
                style: const TextStyle(
                  color: Color(0xFF8D99AA),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...summary.recentSessions.map((session) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SessionTile(
                session: session,
                formatScore: _formatScore,
                formatDate: _formatDate,
                onTap: () => _openSessionDetail(
                  player: selectedPlayer,
                  session: session,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatScore(double score) {
    return score.toStringAsFixed(1);
  }

  String _formatNumber(double value) {
    return value.toStringAsFixed(1);
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) {
      return '-';
    }

    final DateTime localDateTime = dateTime.toLocal();

    return '${localDateTime.day.toString().padLeft(2, '0')}.${localDateTime.month.toString().padLeft(2, '0')}.${localDateTime.year.toString().padLeft(4, '0')} '
        '${localDateTime.hour.toString().padLeft(2, '0')}:${localDateTime.minute.toString().padLeft(2, '0')}';
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      width: 276,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111821).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF243244),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              icon,
              color: accentColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8D99AA),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF657386),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

class _MiniInfo extends StatelessWidget {
  final String label;
  final String value;

  const _MiniInfo({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 170),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151E29),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF263445),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8D99AA),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TextBlock extends StatelessWidget {
  final String title;
  final String text;

  const _TextBlock({
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151E29),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF263445),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF8D99AA),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFFDCE5F2),
              fontSize: 14,
              height: 1.42,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final TrainingSessionListItem session;
  final String Function(double value) formatScore;
  final String Function(DateTime? value) formatDate;
  final VoidCallback onTap;

  const _SessionTile({
    required this.session,
    required this.formatScore,
    required this.formatDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF151E29),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFF263445),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.track_changes_rounded,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${session.displayTrainingType} · ${session.targetLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${session.dartsThrown}/${session.plannedDarts} Darts · ${formatDate(session.finishedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8D99AA),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _ScoreChip(
                label: 'ACC',
                value: formatScore(session.accuracyScore),
              ),
              const SizedBox(width: 8),
              _ScoreChip(
                label: 'GRP',
                value: formatScore(session.groupingScore),
              ),
              const SizedBox(width: 8),
              _ScoreChip(
                label: 'KON',
                value: formatScore(session.consistencyScore),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF8D99AA),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final String label;
  final String value;

  const _ScoreChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F151D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF2A3748),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8D99AA),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  final String label;
  final IconData icon;

  const _SmallPill({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.38),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: accentColor,
            size: 16,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: accentColor,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTrainingStats extends StatelessWidget {
  final String playerName;

  const _EmptyTrainingStats({required this.playerName});

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF0F151D).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFF243244),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.insights_rounded,
            color: accentColor,
            size: 46,
          ),
          const SizedBox(height: 16),
          Text(
            'Noch keine Trainingsdaten für $playerName',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Starte zuerst eine Streuungsanalyse und speichere sie. Danach erscheinen hier Sessions, Scores und Empfehlungen.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF9DA8B7),
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
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
      constraints: const BoxConstraints(maxWidth: 720),
      padding: const EdgeInsets.all(18),
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
        mainAxisSize: MainAxisSize.min,
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
