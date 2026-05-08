import 'package:flutter/material.dart';

import '../models/player.dart';
import '../services/training_analysis_service.dart';
import '../widgets/dartboard_tap_widget.dart';
import 'training_stats_page.dart';

class SpreadAnalysisResultPage extends StatelessWidget {
  final Player player;
  final int plannedDarts;
  final String targetLabel;
  final int targetSegment;
  final String targetRing;
  final List<DartboardHit> hits;
  final SpreadAnalysisResult summary;
  final Widget Function() buildNewSessionPage;

  const SpreadAnalysisResultPage({
    super.key,
    required this.player,
    required this.plannedDarts,
    required this.targetLabel,
    required this.targetSegment,
    required this.targetRing,
    required this.hits,
    required this.summary,
    required this.buildNewSessionPage,
  });

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
              children: [
                _buildHeader(context),
                const SizedBox(height: 22),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final bool compact = constraints.maxWidth < 1060;

                      if (compact) {
                        return SingleChildScrollView(
                          child: Column(
                            children: [
                              _buildResultPanel(context),
                              const SizedBox(height: 18),
                              SizedBox(
                                height: 560,
                                child: _buildBoardPanel(context),
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                height: 520,
                                child: _buildHitsPanel(context),
                              ),
                            ],
                          ),
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 5,
                            child: _buildResultPanel(context),
                          ),
                          const SizedBox(width: 22),
                          Expanded(
                            flex: 4,
                            child: Column(
                              children: [
                                Expanded(child: _buildBoardPanel(context)),
                                const SizedBox(height: 18),
                                Expanded(child: _buildHitsPanel(context)),
                              ],
                            ),
                          ),
                        ],
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
            border: Border.all(color: accentColor.withValues(alpha: 0.25)),
          ),
          child: Icon(
            Icons.analytics_rounded,
            color: accentColor,
            size: 32,
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Trainingsergebnis',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${player.name} · Ziel $targetLabel · ${hits.length}/$plannedDarts Darts gespeichert',
                style: const TextStyle(
                  color: Color(0xFF9DA8B7),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        _ScoreChip(
          label: 'Konstanz',
          value: summary.consistencyScore,
        ),
      ],
    );
  }

  Widget _buildResultPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF111821).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF243244)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeadlineCard(context),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ResultMetricBox(
                    title: 'Accuracy',
                    value: summary.accuracyScore.toStringAsFixed(0),
                    subtitle: summary.accuracyLabel,
                    icon: Icons.gps_fixed_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ResultMetricBox(
                    title: 'Grouping',
                    value: summary.groupingScore.toStringAsFixed(0),
                    subtitle: summary.groupingLabel,
                    icon: Icons.blur_on_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ResultMetricBox(
                    title: 'Konstanz',
                    value: summary.consistencyScore.toStringAsFixed(0),
                    subtitle: summary.consistencyLabel,
                    icon: Icons.repeat_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ResultMetricBox(
                    title: 'Zieltreffer',
                    value: '${summary.targetHits}/${summary.dartsThrown}',
                    subtitle: '${summary.targetRate.toStringAsFixed(1)} %',
                    icon: Icons.my_location_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ResultMetricBox(
                    title: 'Segment',
                    value: '${summary.segmentHits}/${summary.dartsThrown}',
                    subtitle: '${summary.segmentRate.toStringAsFixed(1)} %',
                    icon: Icons.track_changes_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ResultMetricBox(
                    title: 'Ring',
                    value: '${summary.ringHits}/${summary.dartsThrown}',
                    subtitle: '${summary.ringRate.toStringAsFixed(1)} %',
                    icon: Icons.adjust_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _ResultTextBlock(
              title: 'Was die Session zeigt',
              text: summary.analysisText,
              icon: Icons.analytics_rounded,
            ),
            const SizedBox(height: 10),
            _ResultTextBlock(
              title: 'Tipp für den nächsten Durchgang',
              text: summary.tipsText,
              icon: Icons.tips_and_updates_rounded,
            ),
            const SizedBox(height: 10),
            _ResultTextBlock(
              title: 'Nächste Übung',
              text: summary.nextDrillText,
              icon: Icons.fitness_center_rounded,
            ),
            const SizedBox(height: 16),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeadlineCard(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF151E29),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF2A3748)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.insights_rounded, color: accentColor, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.patternHeadline,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                    color: Color(0xFFE7EEF8),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hauptabweichung: ${summary.mainErrorDirection}',
                  style: const TextStyle(
                    color: Color(0xFF9DA8B7),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardPanel(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0F151D).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF243244)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.map_rounded, color: accentColor),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Trefferbild',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFDCE5F2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Center(
              child: DartboardTapWidget(
                targetLabel: targetLabel,
                targetSegment: targetSegment,
                targetRing: targetRing,
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

  Widget _buildHitsPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111821).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF243244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Eingetragene Darts',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: hits.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final DartboardHit hit = hits[index];
                final bool targetHit = DartboardTapWidget.isTargetHit(
                  hit: hit,
                  targetSegment: targetSegment,
                  targetRing: targetRing,
                );

                return _HitRow(
                  dartNumber: index + 1,
                  hit: hit,
                  targetHit: targetHit,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => buildNewSessionPage(),
                ),
              );
            },
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Neue Session mit gleichem Ziel'),
            style: FilledButton.styleFrom(
              textStyle: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const TrainingStatsPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.query_stats_rounded),
                label: const Text('Zur Statistik'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.check_rounded),
                label: const Text('Fertig'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ResultMetricBox extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _ResultMetricBox({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151E29),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2A3748)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 21),
          const SizedBox(height: 9),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF8D99AA),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFB8C3D3),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultTextBlock extends StatelessWidget {
  final String title;
  final String text;
  final IconData icon;

  const _ResultTextBlock({
    required this.title,
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151E29),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2A3748)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 21),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFE7EEF8),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFFB8C3D3),
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
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

class _HitRow extends StatelessWidget {
  final int dartNumber;
  final DartboardHit hit;
  final bool targetHit;

  const _HitRow({
    required this.dartNumber,
    required this.hit,
    required this.targetHit,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: targetHit
            ? accentColor.withValues(alpha: 0.16)
            : const Color(0xFF151E29),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: targetHit
              ? accentColor.withValues(alpha: 0.45)
              : const Color(0xFF263445),
        ),
      ),
      child: Row(
        children: [
          Text(
            '#$dartNumber',
            style: const TextStyle(
              color: Color(0xFF8D99AA),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hit.label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Icon(
            targetHit
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: targetHit ? accentColor : const Color(0xFF6F7C8D),
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            '${hit.score}',
            style: const TextStyle(
              color: Color(0xFFDCE5F2),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final String label;
  final double value;

  const _ScoreChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accentColor.withValues(alpha: 0.36)),
      ),
      child: Text(
        '$label ${value.toStringAsFixed(0)}',
        style: TextStyle(
          color: accentColor,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}
