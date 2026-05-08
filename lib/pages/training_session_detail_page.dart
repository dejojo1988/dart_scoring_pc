import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../models/player.dart';
import '../widgets/dartboard_tap_widget.dart';
import 'spread_analysis_session_page.dart';

class TrainingSessionDetailPage extends StatefulWidget {
  final Player player;
  final String sessionId;

  const TrainingSessionDetailPage({
    super.key,
    required this.player,
    required this.sessionId,
  });

  @override
  State<TrainingSessionDetailPage> createState() =>
      _TrainingSessionDetailPageState();
}

class _TrainingSessionDetailPageState extends State<TrainingSessionDetailPage> {
  late Future<TrainingSessionDetail?> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = _loadDetail();
  }

  Future<TrainingSessionDetail?> _loadDetail() {
    return AppDatabase.instance.getTrainingSessionDetail(
      sessionId: widget.sessionId,
    );
  }

  void _reload() {
    setState(() {
      _detailFuture = _loadDetail();
    });
  }

  void _startRepeatSession(TrainingSessionDetail detail) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SpreadAnalysisSessionPage(
          player: widget.player,
          plannedDarts: detail.plannedDarts,
          targetLabel: detail.targetLabel,
          targetSegment: detail.targetSegment,
          targetRing: detail.targetRing,
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
                  child: FutureBuilder<TrainingSessionDetail?>(
                    future: _detailFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: _LoadingBox(label: 'Session wird geladen ...'),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: _InfoBox(
                            icon: Icons.error_outline_rounded,
                            title: 'Session konnte nicht geladen werden.',
                            text: snapshot.error.toString(),
                          ),
                        );
                      }

                      final TrainingSessionDetail? detail = snapshot.data;

                      if (detail == null) {
                        return const Center(
                          child: _InfoBox(
                            icon: Icons.search_off_rounded,
                            title: 'Session nicht gefunden.',
                            text:
                                'Diese Trainingssession existiert nicht mehr oder konnte nicht aus der Datenbank gelesen werden.',
                          ),
                        );
                      }

                      return _buildContent(context, detail);
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
            Icons.fact_check_rounded,
            color: accentColor,
            size: 31,
          ),
        ),
        const SizedBox(width: 18),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trainingssession',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Gespeicherte Streuungsanalyse im Detail ansehen',
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

  Widget _buildContent(BuildContext context, TrainingSessionDetail detail) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSessionHeaderCard(context, detail),
              const SizedBox(height: 18),
              _buildScoreGrid(detail),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool wide = constraints.maxWidth >= 980;

                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 11,
                          child: _buildBoardCard(detail),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          flex: 10,
                          child: _buildAnalysisCard(detail),
                        ),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildBoardCard(detail),
                      const SizedBox(height: 18),
                      _buildAnalysisCard(detail),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              _buildDartListCard(detail),
              const SizedBox(height: 18),
              _buildActions(detail),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionHeaderCard(
    BuildContext context,
    TrainingSessionDetail detail,
  ) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0F151D).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFF243244)),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.track_changes_rounded,
              color: accentColor,
              size: 33,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${detail.displayTrainingType} · ${detail.targetLabel}',
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${widget.player.name} · ${detail.dartsThrown}/${detail.plannedDarts} Darts · ${_formatDate(detail.finishedAt)}',
                  style: const TextStyle(
                    color: Color(0xFF9DA8B7),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _Pill(
            icon: Icons.my_location_rounded,
            label: 'Ziel ${detail.targetLabel}',
          ),
        ],
      ),
    );
  }

  Widget _buildScoreGrid(TrainingSessionDetail detail) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        _MetricCard(
          title: 'Accuracy',
          value: _formatScore(detail.accuracyScore),
          subtitle: 'Zielnähe',
          icon: Icons.center_focus_strong_rounded,
        ),
        _MetricCard(
          title: 'Grouping',
          value: _formatScore(detail.groupingScore),
          subtitle: 'Gruppierung',
          icon: Icons.blur_circular_rounded,
        ),
        _MetricCard(
          title: 'Konstanz',
          value: _formatScore(detail.consistencyScore),
          subtitle: 'Wiederholbarkeit',
          icon: Icons.repeat_rounded,
        ),
        _MetricCard(
          title: 'Zieltreffer',
          value: '${detail.targetHitCount}',
          subtitle: '${_formatPercent(detail.targetRate)} %',
          icon: Icons.gps_fixed_rounded,
        ),
        _MetricCard(
          title: 'Segment',
          value: '${detail.segmentHitCount}',
          subtitle: '${_formatPercent(detail.segmentRate)} %',
          icon: Icons.stacked_line_chart_rounded,
        ),
        _MetricCard(
          title: 'Hauptfehler',
          value: detail.mainErrorDirection.isEmpty
              ? '-'
              : detail.mainErrorDirection,
          subtitle: 'Richtung',
          icon: Icons.near_me_rounded,
        ),
      ],
    );
  }

  Widget _buildBoardCard(TrainingSessionDetail detail) {
    final List<DartboardHit> hits = _hitsFromDetail(detail);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0F151D).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF243244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(
                Icons.radar_rounded,
                color: Color(0xFFDCE5F2),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Trefferbild',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: DartboardTapWidget(
                targetLabel: detail.targetLabel,
                targetSegment: detail.targetSegment,
                targetRing: detail.targetRing,
                hits: hits,
                enabled: false,
                onHit: (_) {},
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisCard(TrainingSessionDetail detail) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF111821).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF243244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  'Analyse & Empfehlung',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MiniInfo(
                label: 'Links',
                value: '${detail.leftMisses}',
              ),
              _MiniInfo(
                label: 'Rechts',
                value: '${detail.rightMisses}',
              ),
              _MiniInfo(
                label: 'Hoch',
                value: '${detail.highMisses}',
              ),
              _MiniInfo(
                label: 'Tief',
                value: '${detail.lowMisses}',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _TextBlock(
            title: 'Muster',
            text: detail.patternHeadline,
          ),
          const SizedBox(height: 14),
          _TextBlock(
            title: 'Analyse',
            text: detail.analysisText.isEmpty
                ? 'Keine Analyse gespeichert.'
                : detail.analysisText,
          ),
          const SizedBox(height: 14),
          _TextBlock(
            title: 'Tipp',
            text: detail.tipsText.isEmpty
                ? 'Kein Tipp gespeichert.'
                : detail.tipsText,
          ),
          const SizedBox(height: 14),
          _TextBlock(
            title: 'Nächste Übung',
            text: detail.nextDrillText,
          ),
        ],
      ),
    );
  }

  Widget _buildDartListCard(TrainingSessionDetail detail) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0F151D).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF243244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Eingetragene Darts',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${detail.placements.length} Darts',
                style: const TextStyle(
                  color: Color(0xFF8D99AA),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (detail.placements.isEmpty)
            const _InfoBox(
              icon: Icons.info_outline_rounded,
              title: 'Keine Dartdaten vorhanden.',
              text:
                  'Die Session wurde gefunden, aber es sind keine einzelnen Dartplacements gespeichert.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final bool compact = constraints.maxWidth < 760;

                if (compact) {
                  return Column(
                    children: detail.placements.map((placement) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CompactDartRow(placement: placement),
                      );
                    }).toList(),
                  );
                }

                return Column(
                  children: [
                    const _DartTableHeader(),
                    const SizedBox(height: 8),
                    ...detail.placements.map((placement) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _DartTableRow(placement: placement),
                      );
                    }),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActions(TrainingSessionDetail detail) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _startRepeatSession(detail),
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Session wiederholen'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.query_stats_rounded),
            label: const Text('Zurück zur Statistik'),
          ),
        ),
      ],
    );
  }

  List<DartboardHit> _hitsFromDetail(TrainingSessionDetail detail) {
    return detail.placements.map((placement) {
      return DartboardHit(
        segment: placement.hitSegment,
        ring: placement.hitRing,
        label: placement.hitLabel,
        score: placement.score,
        normalizedX: placement.normalizedX,
        normalizedY: placement.normalizedY,
      );
    }).toList(growable: false);
  }

  String _formatScore(double score) {
    return score.toStringAsFixed(1);
  }

  String _formatPercent(double value) {
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

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      width: 186,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111821),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF263445)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 25),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF9DA8B7),
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
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF8D99AA),
              fontSize: 11,
              fontWeight: FontWeight.w700,
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
      width: 110,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F151D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A3748)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8D99AA),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
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
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF0F151D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2A3748)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF9DA8B7),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFFDCE5F2),
              fontSize: 14,
              height: 1.38,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DartTableHeader extends StatelessWidget {
  const _DartTableHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox(width: 62, child: _TableHeaderText('Dart')),
        Expanded(child: _TableHeaderText('Treffer')),
        SizedBox(width: 82, child: _TableHeaderText('Score')),
        SizedBox(width: 104, child: _TableHeaderText('Zieltreffer')),
        SizedBox(width: 92, child: _TableHeaderText('Distanz')),
        SizedBox(width: 92, child: _TableHeaderText('Horizontal')),
        SizedBox(width: 92, child: _TableHeaderText('Vertikal')),
      ],
    );
  }
}

class _DartTableRow extends StatelessWidget {
  final TrainingDartPlacementItem placement;

  const _DartTableRow({required this.placement});

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF151E29),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF263445)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              '#${placement.dartIndex}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: placement.isTargetHit
                        ? accentColor
                        : const Color(0xFF8D99AA),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    placement.hitLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 82, child: Text('${placement.score}')),
          SizedBox(
            width: 104,
            child: Text(placement.isTargetHit ? 'Ja' : 'Nein'),
          ),
          SizedBox(
            width: 92,
            child: Text(placement.distanceFromTarget.toStringAsFixed(3)),
          ),
          SizedBox(
            width: 92,
            child: Text(placement.horizontalError.toStringAsFixed(3)),
          ),
          SizedBox(
            width: 92,
            child: Text(placement.verticalError.toStringAsFixed(3)),
          ),
        ],
      ),
    );
  }
}

class _CompactDartRow extends StatelessWidget {
  final TrainingDartPlacementItem placement;

  const _CompactDartRow({required this.placement});

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151E29),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF263445)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: placement.isTargetHit
                  ? accentColor.withValues(alpha: 0.20)
                  : const Color(0xFF0F151D),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: placement.isTargetHit
                    ? accentColor.withValues(alpha: 0.50)
                    : const Color(0xFF2A3748),
              ),
            ),
            child: Text(
              '${placement.dartIndex}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${placement.hitLabel} · ${placement.score} Punkte',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Distanz ${placement.distanceFromTarget.toStringAsFixed(3)} · H ${placement.horizontalError.toStringAsFixed(3)} · V ${placement.verticalError.toStringAsFixed(3)}',
                  style: const TextStyle(
                    color: Color(0xFF8D99AA),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            placement.isTargetHit
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color:
                placement.isTargetHit ? accentColor : const Color(0xFF8D99AA),
          ),
        ],
      ),
    );
  }
}

class _TableHeaderText extends StatelessWidget {
  final String text;

  const _TableHeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF8D99AA),
        fontSize: 11,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Pill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accentColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: accentColor),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
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
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F151D).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFF243244)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accentColor, size: 30),
          const SizedBox(width: 14),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFF9DA8B7),
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
        border: Border.all(color: const Color(0xFF2A3748)),
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
