import 'dart:convert';
import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../models/player.dart';
import '../services/training_analysis_service.dart';
import '../widgets/dartboard_tap_widget.dart';

class SpreadAnalysisSessionPage extends StatefulWidget {
  final Player player;
  final int plannedDarts;
  final String targetLabel;
  final int targetSegment;
  final String targetRing;

  const SpreadAnalysisSessionPage({
    super.key,
    required this.player,
    required this.plannedDarts,
    required this.targetLabel,
    required this.targetSegment,
    required this.targetRing,
  });

  @override
  State<SpreadAnalysisSessionPage> createState() =>
      _SpreadAnalysisSessionPageState();
}

class _SpreadAnalysisSessionPageState extends State<SpreadAnalysisSessionPage> {
  final List<DartboardHit> _hits = [];
  final DateTime _startedAt = DateTime.now();

  bool _isSaving = false;
  SpreadAnalysisResult? _summary;

  bool get _isComplete => _hits.length >= widget.plannedDarts;

  void _addHit(DartboardHit hit) {
    if (_isComplete || _summary != null) {
      return;
    }

    setState(() {
      _hits.add(hit);
    });

    if (_hits.length == widget.plannedDarts) {
      _showMessage(
          'Alle ${widget.plannedDarts} Darts eingetragen. Du kannst die Session jetzt speichern.');
    }
  }

  void _undoLastHit() {
    if (_hits.isEmpty || _summary != null || _isSaving) {
      return;
    }

    setState(() {
      _hits.removeLast();
    });
  }

  void _resetHits() {
    if (_hits.isEmpty || _summary != null || _isSaving) {
      return;
    }

    setState(() {
      _hits.clear();
    });
  }

  Future<void> _finishAndSaveSession() async {
    if (_hits.isEmpty) {
      _showMessage('Noch keine Darts eingetragen.');
      return;
    }

    if (_isSaving || _summary != null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final SpreadAnalysisResult summary = _buildSummary();
      await _saveSession(summary);

      if (!mounted) {
        return;
      }

      setState(() {
        _summary = summary;
        _isSaving = false;
      });

      _showMessage('Training gespeichert.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      _showMessage('Training konnte nicht gespeichert werden: $error');
    }
  }

  Future<void> _saveSession(SpreadAnalysisResult summary) async {
    final database = await AppDatabase.instance.database;
    final DateTime finishedAt = DateTime.now();
    final String sessionId =
        'spread_${widget.player.id}_${finishedAt.microsecondsSinceEpoch}';

    await database.transaction((transaction) async {
      await transaction.insert(
        'training_sessions',
        {
          'id': sessionId,
          'player_id': widget.player.id,
          'training_type': 'spread_analysis',
          'target_label': widget.targetLabel,
          'target_segment': widget.targetSegment,
          'target_ring': widget.targetRing,
          'planned_darts': widget.plannedDarts,
          'darts_thrown': _hits.length,
          'started_at': _startedAt.toIso8601String(),
          'finished_at': finishedAt.toIso8601String(),
          'accuracy_score': summary.accuracyScore,
          'grouping_score': summary.groupingScore,
          'consistency_score': summary.consistencyScore,
          'main_error_direction': summary.mainErrorDirection,
          'analysis_text': summary.analysisText,
          'tips_text': summary.tipsText,
          'metadata_json': jsonEncode({
            'target_hit_count': summary.targetHits,
            'segment_hit_count': summary.segmentHits,
            'ring_hit_count': summary.ringHits,
            'target_rate': summary.targetRate,
            'segment_rate': summary.segmentRate,
            'ring_rate': summary.ringRate,
            'average_distance': summary.averageDistance,
            'average_grouping_distance': summary.averageGroupingDistance,
            'average_horizontal_error': summary.averageHorizontalError,
            'average_vertical_error': summary.averageVerticalError,
            'left_misses': summary.leftMisses,
            'right_misses': summary.rightMisses,
            'high_misses': summary.highMisses,
            'low_misses': summary.lowMisses,
            'pattern_headline': summary.patternHeadline,
            'next_drill_text': summary.nextDrillText,
            'hit_labels': _hits.map((hit) => hit.label).toList(),
          }),
        },
      );

      for (int index = 0; index < _hits.length; index++) {
        final DartboardHit hit = _hits[index];
        final double distance = DartboardTapWidget.distanceFromTarget(
          hit: hit,
          targetSegment: widget.targetSegment,
          targetRing: widget.targetRing,
        );
        final double horizontalError = DartboardTapWidget.horizontalError(
          hit: hit,
          targetSegment: widget.targetSegment,
          targetRing: widget.targetRing,
        );
        final double verticalError = DartboardTapWidget.verticalError(
          hit: hit,
          targetSegment: widget.targetSegment,
          targetRing: widget.targetRing,
        );
        final bool targetHit = DartboardTapWidget.isTargetHit(
          hit: hit,
          targetSegment: widget.targetSegment,
          targetRing: widget.targetRing,
        );

        await transaction.insert(
          'training_dart_placements',
          {
            'session_id': sessionId,
            'dart_index': index + 1,
            'target_label': widget.targetLabel,
            'target_segment': widget.targetSegment,
            'target_ring': widget.targetRing,
            'hit_segment': hit.segment,
            'hit_ring': hit.ring,
            'hit_label': hit.label,
            'score': hit.score,
            'x': hit.normalizedX,
            'y': hit.normalizedY,
            'distance_from_target': distance,
            'horizontal_error': horizontalError,
            'vertical_error': verticalError,
            'is_target_hit': targetHit ? 1 : 0,
            'created_at': DateTime.now().toIso8601String(),
          },
        );
      }
    });
  }

  SpreadAnalysisResult _buildSummary() {
    return TrainingAnalysisService.analyze(
      hits: _hits,
      targetLabel: widget.targetLabel,
      targetSegment: widget.targetSegment,
      targetRing: widget.targetRing,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(message)),
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
              children: [
                _buildHeader(context),
                const SizedBox(height: 22),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final bool compact = constraints.maxWidth < 980;

                      if (compact) {
                        return SingleChildScrollView(
                          child: Column(
                            children: [
                              SizedBox(
                                height: 660,
                                child: _buildBoardCard(context),
                              ),
                              const SizedBox(height: 18),
                              _buildSidePanel(context),
                            ],
                          ),
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 6,
                            child: _buildBoardCard(context),
                          ),
                          const SizedBox(width: 22),
                          Expanded(
                            flex: 4,
                            child: _buildSidePanel(context),
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
          onPressed: _isSaving
              ? null
              : () {
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
            Icons.touch_app_rounded,
            color: accentColor,
            size: 32,
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Streuungsanalyse · ${widget.targetLabel}',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.player.name} · ${_hits.length}/${widget.plannedDarts} Darts eingetragen',
                style: const TextStyle(
                  color: Color(0xFF9DA8B7),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        _ProgressPill(
          current: _hits.length,
          total: widget.plannedDarts,
        ),
      ],
    );
  }

  Widget _buildBoardCard(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0F151D).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF243244)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.my_location_rounded, color: accentColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _summary == null
                      ? 'Tippe jeden Dart dort an, wo er im Board steckt.'
                      : 'Session gespeichert. Ergebnis unten rechts auswerten.',
                  style: const TextStyle(
                    color: Color(0xFFDCE5F2),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: DartboardTapWidget(
                  targetLabel: widget.targetLabel,
                  targetSegment: widget.targetSegment,
                  targetRing: widget.targetRing,
                  hits: _hits,
                  enabled: !_isComplete && _summary == null && !_isSaving,
                  onHit: _addHit,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidePanel(BuildContext context) {
    final SpreadAnalysisResult? summary = _summary;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF111821).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF243244)),
      ),
      child: summary == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatsOverview(),
                const SizedBox(height: 18),
                _buildLastHitsList(),
                const SizedBox(height: 18),
                _buildActionButtons(),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStatsOverview(),
                  const SizedBox(height: 18),
                  _buildResult(summary),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsOverview() {
    final int targetHits = _hits.where((hit) {
      return DartboardTapWidget.isTargetHit(
        hit: hit,
        targetSegment: widget.targetSegment,
        targetRing: widget.targetRing,
      );
    }).length;

    final int segmentHits =
        _hits.where((hit) => hit.segment == widget.targetSegment).length;
    final double targetRate =
        _hits.isEmpty ? 0 : targetHits / _hits.length * 100;
    final double segmentRate =
        _hits.isEmpty ? 0 : segmentHits / _hits.length * 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Live-Werte',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricBox(
                label: 'Zieltreffer',
                value: '$targetHits',
                subValue: '${targetRate.toStringAsFixed(1)} %',
                icon: Icons.gps_fixed_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricBox(
                label: 'Segment',
                value: '$segmentHits',
                subValue: '${segmentRate.toStringAsFixed(1)} %',
                icon: Icons.track_changes_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLastHitsList() {
    final List<DartboardHit> visibleHits = _hits.reversed.take(9).toList();

    return SizedBox(
      height: 300,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F151D),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF263445)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Letzte Darts',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            if (visibleHits.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'Noch kein Dart eingetragen.',
                    style: TextStyle(
                      color: Color(0xFF8D99AA),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: visibleHits.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final DartboardHit hit = visibleHits[index];
                    final int dartNumber = _hits.length - index;
                    final bool targetHit = DartboardTapWidget.isTargetHit(
                      hit: hit,
                      targetSegment: widget.targetSegment,
                      targetRing: widget.targetRing,
                    );

                    return _HitRow(
                      dartNumber: dartNumber,
                      hit: hit,
                      targetHit: targetHit,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _hits.isEmpty || _isSaving ? null : _undoLastHit,
                icon: const Icon(Icons.undo_rounded),
                label: const Text('Letzten löschen'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _hits.isEmpty || _isSaving ? null : _resetHits,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Reset'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed:
                _hits.isEmpty || _isSaving ? null : _finishAndSaveSession,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(_isSaving ? 'Speichert ...' : 'Session speichern'),
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
      ],
    );
  }

  Widget _buildResult(SpreadAnalysisResult summary) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F151D),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF263445)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Analyse',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _ScoreChip(
                label: 'Konstanz',
                value: summary.consistencyScore,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF151E29),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF2A3748)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.patternHeadline,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFE7EEF8),
                    height: 1.25,
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
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.check_rounded),
            label: const Text('Fertig'),
          ),
        ],
      ),
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

class _ProgressPill extends StatelessWidget {
  final int current;
  final int total;

  const _ProgressPill({
    required this.current,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accentColor.withValues(alpha: 0.36)),
      ),
      child: Text(
        '$current / $total',
        style: TextStyle(
          color: accentColor,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  final String label;
  final String value;
  final String subValue;
  final IconData icon;

  const _MetricBox({
    required this.label,
    required this.value,
    required this.subValue,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F151D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF263445)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8D99AA),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subValue,
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
