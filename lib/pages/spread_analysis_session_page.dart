import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../models/player.dart';
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
  _SpreadAnalysisSummary? _summary;

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
      final _SpreadAnalysisSummary summary = _buildSummary();
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

  Future<void> _saveSession(_SpreadAnalysisSummary summary) async {
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
            'average_distance': summary.averageDistance,
            'average_horizontal_error': summary.averageHorizontalError,
            'average_vertical_error': summary.averageVerticalError,
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

  _SpreadAnalysisSummary _buildSummary() {
    final int dartsThrown = _hits.length;
    final int targetHits = _hits.where((hit) {
      return DartboardTapWidget.isTargetHit(
        hit: hit,
        targetSegment: widget.targetSegment,
        targetRing: widget.targetRing,
      );
    }).length;

    final int segmentHits = _hits.where((hit) {
      return hit.segment == widget.targetSegment;
    }).length;

    final List<double> distances = _hits.map((hit) {
      return DartboardTapWidget.distanceFromTarget(
        hit: hit,
        targetSegment: widget.targetSegment,
        targetRing: widget.targetRing,
      );
    }).toList();

    final List<double> horizontalErrors = _hits.map((hit) {
      return DartboardTapWidget.horizontalError(
        hit: hit,
        targetSegment: widget.targetSegment,
        targetRing: widget.targetRing,
      );
    }).toList();

    final List<double> verticalErrors = _hits.map((hit) {
      return DartboardTapWidget.verticalError(
        hit: hit,
        targetSegment: widget.targetSegment,
        targetRing: widget.targetRing,
      );
    }).toList();

    final double averageDistance =
        distances.reduce((a, b) => a + b) / dartsThrown;
    final double averageHorizontalError =
        horizontalErrors.reduce((a, b) => a + b) / dartsThrown;
    final double averageVerticalError =
        verticalErrors.reduce((a, b) => a + b) / dartsThrown;

    final double centroidX =
        _hits.map((hit) => hit.normalizedX).reduce((a, b) => a + b) /
            dartsThrown;
    final double centroidY =
        _hits.map((hit) => hit.normalizedY).reduce((a, b) => a + b) /
            dartsThrown;
    final double averageGroupingDistance = _hits.map((hit) {
          final double dx = hit.normalizedX - centroidX;
          final double dy = hit.normalizedY - centroidY;
          return math.sqrt((dx * dx) + (dy * dy));
        }).reduce((a, b) => a + b) /
        dartsThrown;

    final double accuracyScore =
        (targetHits / dartsThrown * 100).clamp(0, 100).toDouble();
    final double groupingScore =
        (100 - (averageGroupingDistance * 130)).clamp(0, 100).toDouble();
    final double consistencyScore =
        ((accuracyScore * 0.35) + (groupingScore * 0.65))
            .clamp(0, 100)
            .toDouble();

    final String mainErrorDirection = _mainErrorDirection(
      horizontalError: averageHorizontalError,
      verticalError: averageVerticalError,
    );

    final String analysisText = _analysisText(
      accuracyScore: accuracyScore,
      groupingScore: groupingScore,
      segmentHits: segmentHits,
      dartsThrown: dartsThrown,
      mainErrorDirection: mainErrorDirection,
    );

    final String tipsText = _tipsText(
      mainErrorDirection: mainErrorDirection,
      groupingScore: groupingScore,
      accuracyScore: accuracyScore,
    );

    return _SpreadAnalysisSummary(
      dartsThrown: dartsThrown,
      targetHits: targetHits,
      segmentHits: segmentHits,
      accuracyScore: accuracyScore,
      groupingScore: groupingScore,
      consistencyScore: consistencyScore,
      averageDistance: averageDistance,
      averageHorizontalError: averageHorizontalError,
      averageVerticalError: averageVerticalError,
      mainErrorDirection: mainErrorDirection,
      analysisText: analysisText,
      tipsText: tipsText,
    );
  }

  String _mainErrorDirection({
    required double horizontalError,
    required double verticalError,
  }) {
    const double threshold = 0.08;

    final String horizontal = horizontalError > threshold
        ? 'rechts'
        : horizontalError < -threshold
            ? 'links'
            : '';

    final String vertical = verticalError > threshold
        ? 'tief'
        : verticalError < -threshold
            ? 'hoch'
            : '';

    if (horizontal.isEmpty && vertical.isEmpty) {
      return 'zentriert';
    }

    if (horizontal.isNotEmpty && vertical.isNotEmpty) {
      return '$horizontal $vertical';
    }

    return horizontal.isNotEmpty ? horizontal : vertical;
  }

  String _analysisText({
    required double accuracyScore,
    required double groupingScore,
    required int segmentHits,
    required int dartsThrown,
    required String mainErrorDirection,
  }) {
    final double segmentRate = segmentHits / dartsThrown * 100;

    if (groupingScore >= 70 && accuracyScore < 35) {
      return 'Deine Gruppe ist relativ eng, aber sie liegt noch nicht sauber im Ziel. Das ist kein kompletter Technik-Crash, sondern eher ein Ausrichtungsproblem.';
    }

    if (groupingScore < 45) {
      return 'Die Darts streuen noch deutlich. Aktuell ist nicht nur das Zielproblem sichtbar, sondern vor allem fehlende Wiederholbarkeit im Wurf.';
    }

    if (segmentRate >= 55 && accuracyScore < 35) {
      return 'Du triffst das richtige Segment schon brauchbar oft, aber der Ring passt noch nicht stabil. Die Linie stimmt besser als die Höhe beziehungsweise Tiefe.';
    }

    if (accuracyScore >= 50) {
      return 'Die Zieltreffer sind für diese Session ordentlich. Entscheidend ist jetzt, ob du diese Genauigkeit über mehrere Sessions halten kannst.';
    }

    return 'Die Session zeigt eine erkennbare Hauptabweichung nach $mainErrorDirection. Das Ziel ist noch nicht stabil genug, aber die Richtung der Schwäche ist verwertbar.';
  }

  String _tipsText({
    required String mainErrorDirection,
    required double groupingScore,
    required double accuracyScore,
  }) {
    if (groupingScore >= 70 && accuracyScore < 35) {
      return 'Nicht wild am ganzen Wurf schrauben. Prüfe zuerst Stand, Schulterlinie und Zielpunkt. Eine enge Gruppe neben dem Ziel ist besser als Treffer, die komplett zufällig verteilt sind.';
    }

    if (groupingScore < 45) {
      return 'Fokus für die nächste Einheit: gleicher Stand, gleicher Griff, gleicher Rhythmus. Erst Wiederholbarkeit stabilisieren, dann Zielkorrektur machen.';
    }

    if (mainErrorDirection.contains('rechts')) {
      return 'Achte darauf, ob dein Arm nach dem Release nach rechts wegzieht. Follow-through bewusst gerade Richtung Ziel halten.';
    }

    if (mainErrorDirection.contains('links')) {
      return 'Prüfe, ob du quer über den Körper ziehst oder das Handgelenk beim Release einklappt. Wurfarm gerade durch die Linie führen.';
    }

    if (mainErrorDirection.contains('hoch')) {
      return 'Viele hohe Darts sprechen oft für zu frühen Release oder zu viel Kraft. Ruhiger werfen und den Abwurfpunkt kontrollieren.';
    }

    if (mainErrorDirection.contains('tief')) {
      return 'Viele tiefe Darts können auf zu spätes Loslassen oder abbrechenden Follow-through hindeuten. Arm nach dem Wurf nicht sofort fallen lassen.';
    }

    return 'Die Abweichung ist nicht stark richtungsgebunden. Nächster Fokus: gleiche Routine vor jedem Wurf und bewusstes Tempo halten.';
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
    final _SpreadAnalysisSummary? summary = _summary;

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
          _buildStatsOverview(),
          const SizedBox(height: 18),
          _buildLastHitsList(),
          const SizedBox(height: 18),
          if (summary == null) _buildActionButtons() else _buildResult(summary),
        ],
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

  Widget _buildResult(_SpreadAnalysisSummary summary) {
    return Container(
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
            'Analyse',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ScoreChip(label: 'Accuracy', value: summary.accuracyScore),
              _ScoreChip(label: 'Grouping', value: summary.groupingScore),
              _ScoreChip(label: 'Konstanz', value: summary.consistencyScore),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Hauptfehler: ${summary.mainErrorDirection}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFFDCE5F2),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            summary.analysisText,
            style: const TextStyle(
              color: Color(0xFFB8C3D3),
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            summary.tipsText,
            style: const TextStyle(
              color: Color(0xFF9DA8B7),
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
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

class _SpreadAnalysisSummary {
  final int dartsThrown;
  final int targetHits;
  final int segmentHits;
  final double accuracyScore;
  final double groupingScore;
  final double consistencyScore;
  final double averageDistance;
  final double averageHorizontalError;
  final double averageVerticalError;
  final String mainErrorDirection;
  final String analysisText;
  final String tipsText;

  const _SpreadAnalysisSummary({
    required this.dartsThrown,
    required this.targetHits,
    required this.segmentHits,
    required this.accuracyScore,
    required this.groupingScore,
    required this.consistencyScore,
    required this.averageDistance,
    required this.averageHorizontalError,
    required this.averageVerticalError,
    required this.mainErrorDirection,
    required this.analysisText,
    required this.tipsText,
  });
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
