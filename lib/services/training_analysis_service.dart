import 'dart:math' as math;

import '../widgets/dartboard_tap_widget.dart';

class TrainingAnalysisService {
  const TrainingAnalysisService._();

  static SpreadAnalysisResult analyze({
    required List<DartboardHit> hits,
    required String targetLabel,
    required int targetSegment,
    required String targetRing,
  }) {
    if (hits.isEmpty) {
      return SpreadAnalysisResult.empty(
        targetLabel: targetLabel,
        targetSegment: targetSegment,
        targetRing: targetRing,
      );
    }

    final int dartsThrown = hits.length;

    final int targetHits = hits.where((hit) {
      return DartboardTapWidget.isTargetHit(
        hit: hit,
        targetSegment: targetSegment,
        targetRing: targetRing,
      );
    }).length;

    final int segmentHits =
        hits.where((hit) => hit.segment == targetSegment).length;
    final int ringHits = hits.where((hit) {
      if (targetRing == 'Bull') {
        return hit.segment == 25;
      }

      return hit.ring == targetRing;
    }).length;

    final List<double> distances = hits.map((hit) {
      return DartboardTapWidget.distanceFromTarget(
        hit: hit,
        targetSegment: targetSegment,
        targetRing: targetRing,
      );
    }).toList();

    final List<double> horizontalErrors = hits.map((hit) {
      return DartboardTapWidget.horizontalError(
        hit: hit,
        targetSegment: targetSegment,
        targetRing: targetRing,
      );
    }).toList();

    final List<double> verticalErrors = hits.map((hit) {
      return DartboardTapWidget.verticalError(
        hit: hit,
        targetSegment: targetSegment,
        targetRing: targetRing,
      );
    }).toList();

    final double averageDistance = _average(distances);
    final double averageHorizontalError = _average(horizontalErrors);
    final double averageVerticalError = _average(verticalErrors);

    final double centroidX =
        _average(hits.map((hit) => hit.normalizedX).toList());
    final double centroidY =
        _average(hits.map((hit) => hit.normalizedY).toList());
    final List<double> groupingDistances = hits.map((hit) {
      final double dx = hit.normalizedX - centroidX;
      final double dy = hit.normalizedY - centroidY;
      return math.sqrt((dx * dx) + (dy * dy));
    }).toList();
    final double averageGroupingDistance = _average(groupingDistances);

    const double directionThreshold = 0.075;
    final int rightMisses =
        horizontalErrors.where((error) => error > directionThreshold).length;
    final int leftMisses =
        horizontalErrors.where((error) => error < -directionThreshold).length;
    final int lowMisses =
        verticalErrors.where((error) => error > directionThreshold).length;
    final int highMisses =
        verticalErrors.where((error) => error < -directionThreshold).length;

    final double targetRate = targetHits / dartsThrown * 100;
    final double segmentRate = segmentHits / dartsThrown * 100;
    final double ringRate = ringHits / dartsThrown * 100;
    final double distanceScore = _scoreFromDistance(averageDistance);

    final double accuracyScore = _clampScore(
      (targetRate * 0.58) +
          (segmentRate * 0.18) +
          (ringRate * 0.09) +
          (distanceScore * 0.15),
    );
    final double groupingScore =
        _clampScore(100 - (averageGroupingDistance * 135));
    final double consistencyScore = _clampScore(
      (accuracyScore * 0.42) + (groupingScore * 0.58),
    );

    final String mainErrorDirection = _mainErrorDirection(
      averageHorizontalError: averageHorizontalError,
      averageVerticalError: averageVerticalError,
      leftMisses: leftMisses,
      rightMisses: rightMisses,
      highMisses: highMisses,
      lowMisses: lowMisses,
      dartsThrown: dartsThrown,
    );

    final String patternHeadline = _patternHeadline(
      targetLabel: targetLabel,
      targetHits: targetHits,
      dartsThrown: dartsThrown,
      accuracyScore: accuracyScore,
      groupingScore: groupingScore,
      mainErrorDirection: mainErrorDirection,
    );

    final String analysisText = _analysisText(
      targetLabel: targetLabel,
      targetRing: targetRing,
      targetHits: targetHits,
      segmentHits: segmentHits,
      ringHits: ringHits,
      dartsThrown: dartsThrown,
      accuracyScore: accuracyScore,
      groupingScore: groupingScore,
      consistencyScore: consistencyScore,
      mainErrorDirection: mainErrorDirection,
    );

    final String tipsText = _tipsText(
      mainErrorDirection: mainErrorDirection,
      targetRing: targetRing,
      accuracyScore: accuracyScore,
      groupingScore: groupingScore,
      consistencyScore: consistencyScore,
    );

    final String nextDrillText = _nextDrillText(
      targetLabel: targetLabel,
      mainErrorDirection: mainErrorDirection,
      accuracyScore: accuracyScore,
      groupingScore: groupingScore,
    );

    return SpreadAnalysisResult(
      targetLabel: targetLabel,
      targetSegment: targetSegment,
      targetRing: targetRing,
      dartsThrown: dartsThrown,
      targetHits: targetHits,
      segmentHits: segmentHits,
      ringHits: ringHits,
      targetRate: targetRate,
      segmentRate: segmentRate,
      ringRate: ringRate,
      accuracyScore: accuracyScore,
      groupingScore: groupingScore,
      consistencyScore: consistencyScore,
      averageDistance: averageDistance,
      averageGroupingDistance: averageGroupingDistance,
      averageHorizontalError: averageHorizontalError,
      averageVerticalError: averageVerticalError,
      leftMisses: leftMisses,
      rightMisses: rightMisses,
      highMisses: highMisses,
      lowMisses: lowMisses,
      mainErrorDirection: mainErrorDirection,
      accuracyLabel: _scoreLabel(accuracyScore),
      groupingLabel: _scoreLabel(groupingScore),
      consistencyLabel: _scoreLabel(consistencyScore),
      patternHeadline: patternHeadline,
      analysisText: analysisText,
      tipsText: tipsText,
      nextDrillText: nextDrillText,
    );
  }

  static double _average(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }

    return values.reduce((a, b) => a + b) / values.length;
  }

  static double _scoreFromDistance(double distance) {
    return _clampScore(100 - (distance * 115));
  }

  static double _clampScore(double value) {
    return value.clamp(0, 100).toDouble();
  }

  static String _scoreLabel(double score) {
    if (score >= 80) {
      return 'stark';
    }

    if (score >= 65) {
      return 'solide';
    }

    if (score >= 45) {
      return 'aufbaufähig';
    }

    return 'schwach';
  }

  static String _mainErrorDirection({
    required double averageHorizontalError,
    required double averageVerticalError,
    required int leftMisses,
    required int rightMisses,
    required int highMisses,
    required int lowMisses,
    required int dartsThrown,
  }) {
    const double averageThreshold = 0.055;
    final int directionCountThreshold =
        math.max(3, (dartsThrown * 0.28).round());

    final bool pullsRight = averageHorizontalError > averageThreshold ||
        rightMisses >= directionCountThreshold;
    final bool pullsLeft = averageHorizontalError < -averageThreshold ||
        leftMisses >= directionCountThreshold;
    final bool pullsLow = averageVerticalError > averageThreshold ||
        lowMisses >= directionCountThreshold;
    final bool pullsHigh = averageVerticalError < -averageThreshold ||
        highMisses >= directionCountThreshold;

    final String horizontal = pullsRight && !pullsLeft
        ? 'rechts'
        : pullsLeft && !pullsRight
            ? 'links'
            : '';

    final String vertical = pullsLow && !pullsHigh
        ? 'tief'
        : pullsHigh && !pullsLow
            ? 'hoch'
            : '';

    if (horizontal.isEmpty && vertical.isEmpty) {
      return 'zentriert / gemischt';
    }

    if (horizontal.isNotEmpty && vertical.isNotEmpty) {
      return '$horizontal $vertical';
    }

    return horizontal.isNotEmpty ? horizontal : vertical;
  }

  static String _patternHeadline({
    required String targetLabel,
    required int targetHits,
    required int dartsThrown,
    required double accuracyScore,
    required double groupingScore,
    required String mainErrorDirection,
  }) {
    if (targetHits == dartsThrown) {
      return 'Sehr starke Session: alle Darts lagen direkt auf $targetLabel.';
    }

    if (groupingScore >= 72 && accuracyScore < 38) {
      return 'Gute Gruppe, aber noch neben dem Ziel.';
    }

    if (groupingScore < 42) {
      return 'Die Streuung ist noch zu groß.';
    }

    if (accuracyScore >= 65) {
      return 'Saubere Zielarbeit mit brauchbarer Wiederholbarkeit.';
    }

    if (mainErrorDirection != 'zentriert / gemischt') {
      return 'Erkennbare Tendenz: deine Darts ziehen nach $mainErrorDirection.';
    }

    return 'Die Treffer sind noch gemischt, aber auswertbar.';
  }

  static String _analysisText({
    required String targetLabel,
    required String targetRing,
    required int targetHits,
    required int segmentHits,
    required int ringHits,
    required int dartsThrown,
    required double accuracyScore,
    required double groupingScore,
    required double consistencyScore,
    required String mainErrorDirection,
  }) {
    final String base =
        'Du hast $targetHits von $dartsThrown Darts direkt auf $targetLabel getroffen. '
        'Das Segment lag bei $segmentHits Treffern, der passende Ring bei $ringHits Treffern.';

    if (groupingScore >= 72 && accuracyScore < 38) {
      return '$base Deine Gruppe ist relativ eng, aber sie sitzt noch nicht sauber im Ziel. Das ist kein kompletter Technik-Crash, sondern eher ein Thema bei Ausrichtung, Zielpunkt oder Release-Linie.';
    }

    if (groupingScore < 42) {
      return '$base Die Darts streuen aktuell zu breit. Das Problem ist damit weniger ein einzelner falscher Zielpunkt, sondern fehlende Wiederholbarkeit in Stand, Griff, Rhythmus oder Follow-through.';
    }

    if (targetRing != 'Bull' &&
        segmentHits >= (dartsThrown * 0.45).round() &&
        targetHits < (dartsThrown * 0.25).round()) {
      return '$base Die Linie auf das Segment ist schon erkennbar, aber der Ring passt noch nicht stabil. Heißt: du bist grundsätzlich in der Nähe, verlierst aber Höhe/Tiefe oder Druckpunkt im Release.';
    }

    if (accuracyScore >= 65 && consistencyScore >= 62) {
      return '$base Das ist eine brauchbare bis starke Session. Wichtig ist jetzt, ob du diesen Wert in den nächsten Einheiten wiederholen kannst und ob er im Match ebenfalls ankommt.';
    }

    if (mainErrorDirection != 'zentriert / gemischt') {
      return '$base Die wichtigste sichtbare Abweichung liegt bei $mainErrorDirection. Das ist gut, weil ein wiederkehrender Fehler deutlich leichter zu korrigieren ist als komplett zufällige Streuung.';
    }

    return '$base Die Abweichung ist nicht eindeutig in eine Richtung verschoben. Für die nächste Einheit zählt vor allem ein gleicher Ablauf vor jedem Dart.';
  }

  static String _tipsText({
    required String mainErrorDirection,
    required String targetRing,
    required double accuracyScore,
    required double groupingScore,
    required double consistencyScore,
  }) {
    if (groupingScore >= 72 && accuracyScore < 38) {
      return 'Nicht wild am ganzen Wurf schrauben. Prüfe zuerst Standposition, Schulterlinie und Zielpunkt. Eine enge Gruppe neben dem Ziel ist ein gutes Zeichen: der Wurf ist wiederholbar, aber falsch ausgerichtet.';
    }

    if (groupingScore < 42) {
      return 'Fokus für die nächste Einheit: gleicher Stand, gleicher Griff, gleicher Rhythmus. Reduziere bewusst Kraft und Tempo. Erst Wiederholbarkeit stabilisieren, danach Zielkorrektur machen.';
    }

    if (mainErrorDirection.contains('rechts')) {
      return 'Achte darauf, ob dein Arm nach dem Release nach rechts wegzieht. Halte den Follow-through bewusst gerade durch die Ziellinie und bleib nach dem Loslassen kurz stehen.';
    }

    if (mainErrorDirection.contains('links')) {
      return 'Prüfe, ob du quer über den Körper ziehst oder das Handgelenk beim Release einklappt. Wurfarm gerade durch die Linie führen, nicht seitlich abkürzen.';
    }

    if (mainErrorDirection.contains('hoch')) {
      return 'Viele hohe Darts sprechen oft für zu frühen Release, zu viel Kraft oder eine zu steile Flugkurve. Wirf ruhiger und achte darauf, den Arm nicht hochzureißen.';
    }

    if (mainErrorDirection.contains('tief')) {
      return 'Viele tiefe Darts deuten oft auf spätes Loslassen, zu wenig Zug oder einen abbrechenden Follow-through hin. Arm nach dem Wurf nicht sofort fallen lassen.';
    }

    if (targetRing == 'Double') {
      return 'Beim Doppeltraining nicht nur Treffer zählen. Merke dir, ob du öfter innen oder außen landest. Genau diese Information entscheidet später über Checkout-Sicherheit.';
    }

    return 'Die Abweichung ist nicht stark richtungsgebunden. Nächster Fokus: gleiche Routine vor jedem Wurf, ruhiger Stand und bewusstes Tempo statt hektischem Nachkorrigieren.';
  }

  static String _nextDrillText({
    required String targetLabel,
    required String mainErrorDirection,
    required double accuracyScore,
    required double groupingScore,
  }) {
    if (groupingScore < 42) {
      return 'Noch einmal 30 Darts auf $targetLabel, aber ohne Ergebnisdruck. Nach jedem dritten Dart kurz resetten: Stand prüfen, Griff prüfen, erst dann weiterwerfen.';
    }

    if (accuracyScore < 40 && groupingScore >= 70) {
      return '30 Darts auf $targetLabel mit bewusst minimal korrigiertem Stand. Ziel: Gruppe behalten, aber näher an das Ziel schieben.';
    }

    if (mainErrorDirection.contains('rechts') ||
        mainErrorDirection.contains('links')) {
      return '3 Serien à 10 Darts auf $targetLabel. Nach jeder Serie nur prüfen: zieht der Arm seitlich weg oder bleibt er gerade in der Linie?';
    }

    if (mainErrorDirection.contains('hoch') ||
        mainErrorDirection.contains('tief')) {
      return '3 Serien à 10 Darts auf $targetLabel. Fokus nur auf Release-Zeitpunkt und vollständigen Follow-through, nicht auf Maximalscore.';
    }

    return 'Noch eine 30-Dart-Session auf $targetLabel. Ziel ist nicht ein einzelner guter Dart, sondern ein ähnliches Trefferbild über alle 30 Darts.';
  }
}

class SpreadAnalysisResult {
  final String targetLabel;
  final int targetSegment;
  final String targetRing;
  final int dartsThrown;
  final int targetHits;
  final int segmentHits;
  final int ringHits;
  final double targetRate;
  final double segmentRate;
  final double ringRate;
  final double accuracyScore;
  final double groupingScore;
  final double consistencyScore;
  final double averageDistance;
  final double averageGroupingDistance;
  final double averageHorizontalError;
  final double averageVerticalError;
  final int leftMisses;
  final int rightMisses;
  final int highMisses;
  final int lowMisses;
  final String mainErrorDirection;
  final String accuracyLabel;
  final String groupingLabel;
  final String consistencyLabel;
  final String patternHeadline;
  final String analysisText;
  final String tipsText;
  final String nextDrillText;

  const SpreadAnalysisResult({
    required this.targetLabel,
    required this.targetSegment,
    required this.targetRing,
    required this.dartsThrown,
    required this.targetHits,
    required this.segmentHits,
    required this.ringHits,
    required this.targetRate,
    required this.segmentRate,
    required this.ringRate,
    required this.accuracyScore,
    required this.groupingScore,
    required this.consistencyScore,
    required this.averageDistance,
    required this.averageGroupingDistance,
    required this.averageHorizontalError,
    required this.averageVerticalError,
    required this.leftMisses,
    required this.rightMisses,
    required this.highMisses,
    required this.lowMisses,
    required this.mainErrorDirection,
    required this.accuracyLabel,
    required this.groupingLabel,
    required this.consistencyLabel,
    required this.patternHeadline,
    required this.analysisText,
    required this.tipsText,
    required this.nextDrillText,
  });

  factory SpreadAnalysisResult.empty({
    required String targetLabel,
    required int targetSegment,
    required String targetRing,
  }) {
    return SpreadAnalysisResult(
      targetLabel: targetLabel,
      targetSegment: targetSegment,
      targetRing: targetRing,
      dartsThrown: 0,
      targetHits: 0,
      segmentHits: 0,
      ringHits: 0,
      targetRate: 0,
      segmentRate: 0,
      ringRate: 0,
      accuracyScore: 0,
      groupingScore: 0,
      consistencyScore: 0,
      averageDistance: 0,
      averageGroupingDistance: 0,
      averageHorizontalError: 0,
      averageVerticalError: 0,
      leftMisses: 0,
      rightMisses: 0,
      highMisses: 0,
      lowMisses: 0,
      mainErrorDirection: 'keine Daten',
      accuracyLabel: 'keine Daten',
      groupingLabel: 'keine Daten',
      consistencyLabel: 'keine Daten',
      patternHeadline: 'Noch keine Darts eingetragen.',
      analysisText:
          'Für eine Analyse müssen zuerst Darts auf dem Board eingetragen werden.',
      tipsText: 'Starte eine Session und trage jeden Dart per Board-Tap ein.',
      nextDrillText: 'Keine Übung verfügbar.',
    );
  }
}
