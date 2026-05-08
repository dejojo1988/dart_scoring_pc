import 'dart:math' as math;

import 'package:flutter/material.dart';

class DartboardHit {
  final int segment;
  final String ring;
  final String label;
  final int score;
  final double normalizedX;
  final double normalizedY;

  const DartboardHit({
    required this.segment,
    required this.ring,
    required this.label,
    required this.score,
    required this.normalizedX,
    required this.normalizedY,
  });
}

class DartboardTargetPoint {
  final double x;
  final double y;

  const DartboardTargetPoint({
    required this.x,
    required this.y,
  });
}

class DartboardTapWidget extends StatelessWidget {
  final String targetLabel;
  final int targetSegment;
  final String targetRing;
  final List<DartboardHit> hits;
  final bool enabled;
  final ValueChanged<DartboardHit> onHit;

  const DartboardTapWidget({
    super.key,
    required this.targetLabel,
    required this.targetSegment,
    required this.targetRing,
    required this.hits,
    required this.enabled,
    required this.onHit,
  });

  static const List<int> segmentOrder = [
    20,
    1,
    18,
    4,
    13,
    6,
    10,
    15,
    2,
    17,
    3,
    19,
    7,
    16,
    8,
    11,
    14,
    9,
    12,
    5,
  ];

  static DartboardTargetPoint targetPoint({
    required int targetSegment,
    required String targetRing,
  }) {
    if (targetSegment == 25 || targetRing == 'Bull') {
      return const DartboardTargetPoint(x: 0, y: 0);
    }

    final int index = segmentOrder.indexOf(targetSegment);
    if (index < 0) {
      return const DartboardTargetPoint(x: 0, y: 0);
    }

    final double radius = switch (targetRing) {
      'Double' => 0.95,
      'Triple' => 0.565,
      'Single' => 0.36,
      _ => 0.36,
    };

    final double angle = index * _DartboardMath.segmentAngle;

    return DartboardTargetPoint(
      x: math.sin(angle) * radius,
      y: -math.cos(angle) * radius,
    );
  }

  static double distanceFromTarget({
    required DartboardHit hit,
    required int targetSegment,
    required String targetRing,
  }) {
    final DartboardTargetPoint target = targetPoint(
      targetSegment: targetSegment,
      targetRing: targetRing,
    );

    final double dx = hit.normalizedX - target.x;
    final double dy = hit.normalizedY - target.y;

    return math.sqrt((dx * dx) + (dy * dy));
  }

  static double horizontalError({
    required DartboardHit hit,
    required int targetSegment,
    required String targetRing,
  }) {
    final DartboardTargetPoint target = targetPoint(
      targetSegment: targetSegment,
      targetRing: targetRing,
    );

    return hit.normalizedX - target.x;
  }

  static double verticalError({
    required DartboardHit hit,
    required int targetSegment,
    required String targetRing,
  }) {
    final DartboardTargetPoint target = targetPoint(
      targetSegment: targetSegment,
      targetRing: targetRing,
    );

    return hit.normalizedY - target.y;
  }

  static bool isTargetHit({
    required DartboardHit hit,
    required int targetSegment,
    required String targetRing,
  }) {
    if (targetRing == 'Bull') {
      return hit.segment == 25 && hit.ring == 'Bull';
    }

    return hit.segment == targetSegment && hit.ring == targetRing;
  }

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final Size boardSize =
              Size(constraints.maxWidth, constraints.maxHeight);

          return MouseRegion(
            cursor:
                enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: enabled
                  ? (details) {
                      final DartboardHit hit = _hitFromPosition(
                        details.localPosition,
                        boardSize,
                      );
                      onHit(hit);
                    }
                  : null,
              child: CustomPaint(
                painter: _DartboardPainter(
                  accentColor: accentColor,
                  targetLabel: targetLabel,
                  targetSegment: targetSegment,
                  targetRing: targetRing,
                  hits: List<DartboardHit>.unmodifiable(hits),
                  enabled: enabled,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  DartboardHit _hitFromPosition(Offset localPosition, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double outerRadius = math.min(size.width, size.height) / 2;
    final double dx = localPosition.dx - center.dx;
    final double dy = localPosition.dy - center.dy;
    final double normalizedX = dx / outerRadius;
    final double normalizedY = dy / outerRadius;
    final double radius = math.sqrt(
      (normalizedX * normalizedX) + (normalizedY * normalizedY),
    );

    if (radius > 1.0) {
      return DartboardHit(
        segment: 0,
        ring: 'Miss',
        label: 'Miss',
        score: 0,
        normalizedX: normalizedX,
        normalizedY: normalizedY,
      );
    }

    if (radius <= _DartboardMath.innerBullRadius) {
      return DartboardHit(
        segment: 25,
        ring: 'Bull',
        label: 'Bull',
        score: 50,
        normalizedX: normalizedX,
        normalizedY: normalizedY,
      );
    }

    if (radius <= _DartboardMath.outerBullRadius) {
      return DartboardHit(
        segment: 25,
        ring: 'Outer Bull',
        label: '25',
        score: 25,
        normalizedX: normalizedX,
        normalizedY: normalizedY,
      );
    }

    final int segment = _segmentFromNormalizedPoint(
      normalizedX: normalizedX,
      normalizedY: normalizedY,
    );

    if (radius >= _DartboardMath.doubleInnerRadius) {
      return DartboardHit(
        segment: segment,
        ring: 'Double',
        label: 'D$segment',
        score: segment * 2,
        normalizedX: normalizedX,
        normalizedY: normalizedY,
      );
    }

    if (radius >= _DartboardMath.tripleInnerRadius &&
        radius <= _DartboardMath.tripleOuterRadius) {
      return DartboardHit(
        segment: segment,
        ring: 'Triple',
        label: 'T$segment',
        score: segment * 3,
        normalizedX: normalizedX,
        normalizedY: normalizedY,
      );
    }

    return DartboardHit(
      segment: segment,
      ring: 'Single',
      label: 'S$segment',
      score: segment,
      normalizedX: normalizedX,
      normalizedY: normalizedY,
    );
  }

  int _segmentFromNormalizedPoint({
    required double normalizedX,
    required double normalizedY,
  }) {
    double angle = math.atan2(normalizedX, -normalizedY);
    if (angle < 0) {
      angle += math.pi * 2;
    }

    final int index = ((angle + (_DartboardMath.segmentAngle / 2)) /
                _DartboardMath.segmentAngle)
            .floor() %
        20;

    return segmentOrder[index];
  }
}

class _DartboardMath {
  static const double segmentAngle = (math.pi * 2) / 20;
  static const double innerBullRadius = 0.075;
  static const double outerBullRadius = 0.16;
  static const double tripleInnerRadius = 0.525;
  static const double tripleOuterRadius = 0.605;
  static const double doubleInnerRadius = 0.90;
  static const double outerRadius = 1.0;
}

class _DartboardPainter extends CustomPainter {
  final Color accentColor;
  final String targetLabel;
  final int targetSegment;
  final String targetRing;
  final List<DartboardHit> hits;
  final bool enabled;

  const _DartboardPainter({
    required this.accentColor,
    required this.targetLabel,
    required this.targetSegment,
    required this.targetRing,
    required this.hits,
    required this.enabled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width, size.height) / 2;

    _drawBoardShadow(canvas, center, radius);
    _drawSegments(canvas, center, radius);
    _drawTargetZone(canvas, center, radius);
    _drawBull(canvas, center, radius);
    _drawWireLines(canvas, center, radius);
    _drawNumbers(canvas, center, radius);
    _drawTargetMarker(canvas, center, radius);
    _drawHits(canvas, center, radius);
    _drawCenterGuide(canvas, center, radius);
    _drawInfoChips(canvas, size, radius);
    _drawBorder(canvas, center, radius);

    if (!enabled) {
      final Paint overlayPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.16);
      canvas.drawCircle(center, radius, overlayPaint);
    }
  }

  void _drawBoardShadow(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center.translate(0, radius * 0.025),
      radius * 1.01,
      Paint()..color = Colors.black.withValues(alpha: 0.38),
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color(0xFF081018),
    );
  }

  void _drawSegments(Canvas canvas, Offset center, double radius) {
    for (int i = 0; i < DartboardTapWidget.segmentOrder.length; i++) {
      final double startAngle = _startAngleForIndex(i);

      final Color darkSingle =
          i.isEven ? const Color(0xFF202936) : const Color(0xFFE7D8B4);
      final Color brightSingle =
          i.isEven ? const Color(0xFF111821) : const Color(0xFFD8C895);
      final Color ringColor =
          i.isEven ? const Color(0xFFB32D32) : const Color(0xFF1E8D55);

      _drawRingSegment(
        canvas: canvas,
        center: center,
        radius: radius,
        innerRadiusFactor: _DartboardMath.outerBullRadius,
        outerRadiusFactor: _DartboardMath.tripleInnerRadius,
        startAngle: startAngle,
        sweepAngle: _DartboardMath.segmentAngle,
        color: darkSingle,
      );

      _drawRingSegment(
        canvas: canvas,
        center: center,
        radius: radius,
        innerRadiusFactor: _DartboardMath.tripleOuterRadius,
        outerRadiusFactor: _DartboardMath.doubleInnerRadius,
        startAngle: startAngle,
        sweepAngle: _DartboardMath.segmentAngle,
        color: brightSingle,
      );

      _drawRingSegment(
        canvas: canvas,
        center: center,
        radius: radius,
        innerRadiusFactor: _DartboardMath.tripleInnerRadius,
        outerRadiusFactor: _DartboardMath.tripleOuterRadius,
        startAngle: startAngle,
        sweepAngle: _DartboardMath.segmentAngle,
        color: ringColor,
      );

      _drawRingSegment(
        canvas: canvas,
        center: center,
        radius: radius,
        innerRadiusFactor: _DartboardMath.doubleInnerRadius,
        outerRadiusFactor: _DartboardMath.outerRadius,
        startAngle: startAngle,
        sweepAngle: _DartboardMath.segmentAngle,
        color: ringColor,
      );
    }
  }

  void _drawTargetZone(Canvas canvas, Offset center, double radius) {
    final Paint targetFillPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.30)
      ..style = PaintingStyle.fill;

    final Paint targetStrokePaint = Paint()
      ..color = accentColor.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.008;

    if (targetRing == 'Bull' || targetSegment == 25) {
      canvas.drawCircle(
          center, radius * _DartboardMath.innerBullRadius, targetFillPaint);
      canvas.drawCircle(
          center, radius * _DartboardMath.innerBullRadius, targetStrokePaint);
      canvas.drawCircle(
        center,
        radius * _DartboardMath.outerBullRadius,
        Paint()
          ..color = accentColor.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.006,
      );
      return;
    }

    final int index = DartboardTapWidget.segmentOrder.indexOf(targetSegment);
    if (index < 0) {
      return;
    }

    final ({double inner, double outer}) ringBounds =
        _ringBoundsForTarget(targetRing);
    final double startAngle = _startAngleForIndex(index);

    _drawRingSegment(
      canvas: canvas,
      center: center,
      radius: radius,
      innerRadiusFactor: ringBounds.inner,
      outerRadiusFactor: ringBounds.outer,
      startAngle: startAngle,
      sweepAngle: _DartboardMath.segmentAngle,
      color: targetFillPaint.color,
    );

    _strokeRingSegment(
      canvas: canvas,
      center: center,
      radius: radius,
      innerRadiusFactor: ringBounds.inner,
      outerRadiusFactor: ringBounds.outer,
      startAngle: startAngle,
      sweepAngle: _DartboardMath.segmentAngle,
      paint: targetStrokePaint,
    );
  }

  void _drawBull(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius * _DartboardMath.outerBullRadius,
      Paint()..color = const Color(0xFF1E8D55),
    );
    canvas.drawCircle(
      center,
      radius * _DartboardMath.innerBullRadius,
      Paint()..color = const Color(0xFFB32D32),
    );

    if (targetRing == 'Bull' || targetSegment == 25) {
      canvas.drawCircle(
        center,
        radius * _DartboardMath.innerBullRadius,
        Paint()..color = accentColor.withValues(alpha: 0.40),
      );
    }
  }

  void _drawWireLines(Canvas canvas, Offset center, double radius) {
    final Paint wirePaint = Paint()
      ..color = const Color(0xFFEAF1FA).withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.75, radius * 0.0025);

    for (int i = 0; i < DartboardTapWidget.segmentOrder.length; i++) {
      final double angle = -math.pi / 2 -
          (_DartboardMath.segmentAngle / 2) +
          (i * _DartboardMath.segmentAngle);
      final Offset inner = Offset(
        center.dx + math.cos(angle) * radius * _DartboardMath.outerBullRadius,
        center.dy + math.sin(angle) * radius * _DartboardMath.outerBullRadius,
      );
      final Offset outer = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      canvas.drawLine(inner, outer, wirePaint);
    }

    for (final double ring in [
      _DartboardMath.innerBullRadius,
      _DartboardMath.outerBullRadius,
      _DartboardMath.tripleInnerRadius,
      _DartboardMath.tripleOuterRadius,
      _DartboardMath.doubleInnerRadius,
      _DartboardMath.outerRadius,
    ]) {
      canvas.drawCircle(center, radius * ring, wirePaint);
    }
  }

  void _drawNumbers(Canvas canvas, Offset center, double radius) {
    for (int i = 0; i < DartboardTapWidget.segmentOrder.length; i++) {
      final int segment = DartboardTapWidget.segmentOrder[i];
      final double angle = -math.pi / 2 + (i * _DartboardMath.segmentAngle);
      final Offset position = Offset(
        center.dx + math.cos(angle) * radius * 0.80,
        center.dy + math.sin(angle) * radius * 0.80,
      );

      final bool isTargetSegment =
          segment == targetSegment && targetRing != 'Bull';

      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: segment.toString(),
          style: TextStyle(
            color: isTargetSegment ? accentColor : const Color(0xFFEAF1FA),
            fontSize: isTargetSegment ? 17 : 13,
            fontWeight: FontWeight.w900,
            shadows: const [
              Shadow(
                color: Colors.black,
                blurRadius: 8,
              ),
            ],
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      if (isTargetSegment) {
        canvas.drawCircle(
          position,
          radius * 0.035,
          Paint()..color = accentColor.withValues(alpha: 0.18),
        );
      }

      textPainter.paint(
        canvas,
        position - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  void _drawTargetMarker(Canvas canvas, Offset center, double radius) {
    final DartboardTargetPoint target = DartboardTapWidget.targetPoint(
      targetSegment: targetSegment,
      targetRing: targetRing,
    );

    final Offset targetOffset = Offset(
      center.dx + target.x * radius,
      center.dy + target.y * radius,
    );

    final Paint haloPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final Paint targetPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.98)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.008;

    canvas.drawCircle(targetOffset, radius * 0.070, haloPaint);
    canvas.drawCircle(targetOffset, radius * 0.047, targetPaint);
    canvas.drawCircle(targetOffset, radius * 0.024, targetPaint);

    final Paint crossPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.88)
      ..strokeWidth = radius * 0.005
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      targetOffset.translate(-radius * 0.080, 0),
      targetOffset.translate(radius * 0.080, 0),
      crossPaint,
    );
    canvas.drawLine(
      targetOffset.translate(0, -radius * 0.080),
      targetOffset.translate(0, radius * 0.080),
      crossPaint,
    );
  }

  void _drawHits(Canvas canvas, Offset center, double radius) {
    if (hits.isEmpty) {
      return;
    }

    for (int i = 0; i < hits.length; i++) {
      final DartboardHit hit = hits[i];
      final Offset position = Offset(
        center.dx + hit.normalizedX * radius,
        center.dy + hit.normalizedY * radius,
      );

      final bool isLatest = i == hits.length - 1;
      final bool targetHit = DartboardTapWidget.isTargetHit(
        hit: hit,
        targetSegment: targetSegment,
        targetRing: targetRing,
      );
      final bool miss = hit.ring == 'Miss';

      if (!isLatest) {
        _drawSmallHitDot(
          canvas: canvas,
          position: position,
          radius: radius,
          targetHit: targetHit,
          miss: miss,
        );
      }
    }

    final DartboardHit latest = hits.last;
    final Offset latestPosition = Offset(
      center.dx + latest.normalizedX * radius,
      center.dy + latest.normalizedY * radius,
    );

    _drawLatestHitBadge(
      canvas: canvas,
      position: latestPosition,
      radius: radius,
      hit: latest,
      dartNumber: hits.length,
    );
  }

  void _drawSmallHitDot({
    required Canvas canvas,
    required Offset position,
    required double radius,
    required bool targetHit,
    required bool miss,
  }) {
    final Color fillColor = targetHit
        ? accentColor.withValues(alpha: 0.92)
        : miss
            ? const Color(0xFF8D99AA).withValues(alpha: 0.72)
            : const Color(0xFFEAF1FA).withValues(alpha: 0.82);

    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.48);
    final Paint fillPaint = Paint()..color = fillColor;
    final Paint strokePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, radius * 0.004);

    final double dotRadius = radius * 0.017;

    canvas.drawCircle(
        position.translate(0, radius * 0.004), dotRadius * 1.08, shadowPaint);
    canvas.drawCircle(position, dotRadius, fillPaint);
    canvas.drawCircle(position, dotRadius, strokePaint);
  }

  void _drawLatestHitBadge({
    required Canvas canvas,
    required Offset position,
    required double radius,
    required DartboardHit hit,
    required int dartNumber,
  }) {
    final bool targetHit = DartboardTapWidget.isTargetHit(
      hit: hit,
      targetSegment: targetSegment,
      targetRing: targetRing,
    );

    final Color fillColor = targetHit ? accentColor : const Color(0xFFFFFFFF);
    final Color textColor =
        targetHit ? const Color(0xFF061018) : const Color(0xFF0B0F14);
    final double badgeRadius = radius * 0.031;

    canvas.drawCircle(
      position.translate(0, radius * 0.006),
      badgeRadius * 1.16,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    canvas.drawCircle(position, badgeRadius, Paint()..color = fillColor);
    canvas.drawCircle(
      position,
      badgeRadius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.6, radius * 0.005),
    );

    final TextPainter numberPainter = TextPainter(
      text: TextSpan(
        text: dartNumber.toString(),
        style: TextStyle(
          color: textColor,
          fontSize: math.max(10, radius * 0.031),
          fontWeight: FontWeight.w900,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    numberPainter.paint(
      canvas,
      position - Offset(numberPainter.width / 2, numberPainter.height / 2),
    );
  }

  void _drawCenterGuide(Canvas canvas, Offset center, double radius) {
    if (hits.isEmpty) {
      return;
    }

    final DartboardTargetPoint target = DartboardTapWidget.targetPoint(
      targetSegment: targetSegment,
      targetRing: targetRing,
    );
    final Offset targetOffset = Offset(
      center.dx + target.x * radius,
      center.dy + target.y * radius,
    );

    final DartboardHit latest = hits.last;
    final Offset latestOffset = Offset(
      center.dx + latest.normalizedX * radius,
      center.dy + latest.normalizedY * radius,
    );

    final Paint linePaint = Paint()
      ..color = accentColor.withValues(alpha: 0.26)
      ..strokeWidth = math.max(1.0, radius * 0.003)
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(targetOffset, latestOffset, linePaint);
  }

  void _drawInfoChips(Canvas canvas, Size size, double radius) {
    final String leftText = 'Ziel: $targetLabel';
    final String rightText =
        hits.isEmpty ? 'Dart 1' : 'Dart ${hits.length + (enabled ? 1 : 0)}';

    _drawChip(
      canvas: canvas,
      text: leftText,
      position: Offset(radius * 0.070, radius * 0.060),
      fillColor: accentColor.withValues(alpha: 0.20),
      borderColor: accentColor.withValues(alpha: 0.48),
      textColor: const Color(0xFFEAF1FA),
    );

    _drawChip(
      canvas: canvas,
      text: rightText,
      position: Offset(size.width - radius * 0.070, radius * 0.060),
      fillColor: Colors.black.withValues(alpha: 0.36),
      borderColor: const Color(0xFFEAF1FA).withValues(alpha: 0.20),
      textColor: const Color(0xFFEAF1FA),
      alignRight: true,
    );
  }

  void _drawChip({
    required Canvas canvas,
    required String text,
    required Offset position,
    required Color fillColor,
    required Color borderColor,
    required Color textColor,
    bool alignRight = false,
  }) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const double horizontalPadding = 10;
    const double verticalPadding = 6;
    final Size chipSize = Size(
      textPainter.width + horizontalPadding * 2,
      textPainter.height + verticalPadding * 2,
    );

    final Offset topLeft = alignRight
        ? Offset(position.dx - chipSize.width, position.dy)
        : position;

    final Rect rect = topLeft & chipSize;
    final RRect rrect =
        RRect.fromRectAndRadius(rect, const Radius.circular(999));

    canvas.drawRRect(rrect, Paint()..color = fillColor);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    textPainter.paint(
      canvas,
      topLeft + const Offset(horizontalPadding, verticalPadding),
    );
  }

  void _drawBorder(Canvas canvas, Offset center, double radius) {
    final Paint borderPaint = Paint()
      ..color = const Color(0xFFEAF1FA).withValues(alpha: 0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius - 1, borderPaint);
  }

  ({double inner, double outer}) _ringBoundsForTarget(String ring) {
    return switch (ring) {
      'Double' => (
          inner: _DartboardMath.doubleInnerRadius,
          outer: _DartboardMath.outerRadius,
        ),
      'Triple' => (
          inner: _DartboardMath.tripleInnerRadius,
          outer: _DartboardMath.tripleOuterRadius,
        ),
      'Single' => (
          inner: _DartboardMath.outerBullRadius,
          outer: _DartboardMath.tripleInnerRadius,
        ),
      _ => (
          inner: _DartboardMath.outerBullRadius,
          outer: _DartboardMath.tripleInnerRadius,
        ),
    };
  }

  double _startAngleForIndex(int index) {
    return -math.pi / 2 -
        (_DartboardMath.segmentAngle / 2) +
        (index * _DartboardMath.segmentAngle);
  }

  void _drawRingSegment({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double innerRadiusFactor,
    required double outerRadiusFactor,
    required double startAngle,
    required double sweepAngle,
    required Color color,
  }) {
    final Path path = _ringSegmentPath(
      center: center,
      radius: radius,
      innerRadiusFactor: innerRadiusFactor,
      outerRadiusFactor: outerRadiusFactor,
      startAngle: startAngle,
      sweepAngle: sweepAngle,
    );

    canvas.drawPath(path, Paint()..color = color);

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );
  }

  void _strokeRingSegment({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double innerRadiusFactor,
    required double outerRadiusFactor,
    required double startAngle,
    required double sweepAngle,
    required Paint paint,
  }) {
    final Path path = _ringSegmentPath(
      center: center,
      radius: radius,
      innerRadiusFactor: innerRadiusFactor,
      outerRadiusFactor: outerRadiusFactor,
      startAngle: startAngle,
      sweepAngle: sweepAngle,
    );

    canvas.drawPath(path, paint);
  }

  Path _ringSegmentPath({
    required Offset center,
    required double radius,
    required double innerRadiusFactor,
    required double outerRadiusFactor,
    required double startAngle,
    required double sweepAngle,
  }) {
    final double innerRadius = radius * innerRadiusFactor;
    final double outerRadius = radius * outerRadiusFactor;

    return Path()
      ..moveTo(
        center.dx + math.cos(startAngle) * outerRadius,
        center.dy + math.sin(startAngle) * outerRadius,
      )
      ..arcTo(
        Rect.fromCircle(center: center, radius: outerRadius),
        startAngle,
        sweepAngle,
        false,
      )
      ..lineTo(
        center.dx + math.cos(startAngle + sweepAngle) * innerRadius,
        center.dy + math.sin(startAngle + sweepAngle) * innerRadius,
      )
      ..arcTo(
        Rect.fromCircle(center: center, radius: innerRadius),
        startAngle + sweepAngle,
        -sweepAngle,
        false,
      )
      ..close();
  }

  @override
  bool shouldRepaint(covariant _DartboardPainter oldDelegate) {
    return true;
  }
}
