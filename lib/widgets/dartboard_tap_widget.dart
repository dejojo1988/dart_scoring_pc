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
          return GestureDetector(
            onTapDown: enabled
                ? (details) {
                    final DartboardHit hit = _hitFromPosition(
                      details.localPosition,
                      Size(constraints.maxWidth, constraints.maxHeight),
                    );
                    onHit(hit);
                  }
                : null,
            child: CustomPaint(
              painter: _DartboardPainter(
                accentColor: accentColor,
                targetSegment: targetSegment,
                targetRing: targetRing,
                hits: hits,
                enabled: enabled,
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
  final int targetSegment;
  final String targetRing;
  final List<DartboardHit> hits;
  final bool enabled;

  const _DartboardPainter({
    required this.accentColor,
    required this.targetSegment,
    required this.targetRing,
    required this.hits,
    required this.enabled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width, size.height) / 2;

    final Paint backgroundPaint = Paint()..color = const Color(0xFF081018);
    canvas.drawCircle(center, radius, backgroundPaint);

    _drawSegments(canvas, center, radius);
    _drawBull(canvas, center, radius);
    _drawNumbers(canvas, center, radius);
    _drawTarget(canvas, center, radius);
    _drawHits(canvas, center, radius);
    _drawBorder(canvas, center, radius);

    if (!enabled) {
      final Paint overlayPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.25);
      canvas.drawCircle(center, radius, overlayPaint);
    }
  }

  void _drawSegments(Canvas canvas, Offset center, double radius) {
    for (int i = 0; i < DartboardTapWidget.segmentOrder.length; i++) {
      final double startAngle = -math.pi / 2 -
          (_DartboardMath.segmentAngle / 2) +
          (i * _DartboardMath.segmentAngle);

      final Color darkSingle =
          i.isEven ? const Color(0xFF222A35) : const Color(0xFFE7D8B4);
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
  }

  void _drawNumbers(Canvas canvas, Offset center, double radius) {
    for (int i = 0; i < DartboardTapWidget.segmentOrder.length; i++) {
      final int segment = DartboardTapWidget.segmentOrder[i];
      final double angle = -math.pi / 2 + (i * _DartboardMath.segmentAngle);
      final Offset position = Offset(
        center.dx + math.cos(angle) * radius * 0.78,
        center.dy + math.sin(angle) * radius * 0.78,
      );

      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: segment.toString(),
          style: const TextStyle(
            color: Color(0xFFEAF1FA),
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        position - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  void _drawTarget(Canvas canvas, Offset center, double radius) {
    final DartboardTargetPoint target = DartboardTapWidget.targetPoint(
      targetSegment: targetSegment,
      targetRing: targetRing,
    );

    final Offset targetOffset = Offset(
      center.dx + target.x * radius,
      center.dy + target.y * radius,
    );

    final Paint targetPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.90)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(targetOffset, radius * 0.045, targetPaint);
    canvas.drawCircle(targetOffset, radius * 0.025, targetPaint);

    final Paint crossPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.75)
      ..strokeWidth = 2;

    canvas.drawLine(
      targetOffset.translate(-radius * 0.07, 0),
      targetOffset.translate(radius * 0.07, 0),
      crossPaint,
    );
    canvas.drawLine(
      targetOffset.translate(0, -radius * 0.07),
      targetOffset.translate(0, radius * 0.07),
      crossPaint,
    );
  }

  void _drawHits(Canvas canvas, Offset center, double radius) {
    for (int i = 0; i < hits.length; i++) {
      final DartboardHit hit = hits[i];
      final Offset position = Offset(
        center.dx + hit.normalizedX * radius,
        center.dy + hit.normalizedY * radius,
      );

      final bool isLatest = i == hits.length - 1;

      final Paint fillPaint = Paint()
        ..color = isLatest ? Colors.white : accentColor.withValues(alpha: 0.82);
      final Paint strokePaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(
          position, isLatest ? radius * 0.018 : radius * 0.014, fillPaint);
      canvas.drawCircle(
          position, isLatest ? radius * 0.018 : radius * 0.014, strokePaint);
    }
  }

  void _drawBorder(Canvas canvas, Offset center, double radius) {
    final Paint borderPaint = Paint()
      ..color = const Color(0xFFEAF1FA).withValues(alpha: 0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius - 1, borderPaint);
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
    final double innerRadius = radius * innerRadiusFactor;
    final double outerRadius = radius * outerRadiusFactor;

    final Path path = Path()
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

    canvas.drawPath(path, Paint()..color = color);

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );
  }

  @override
  bool shouldRepaint(covariant _DartboardPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor ||
        oldDelegate.targetSegment != targetSegment ||
        oldDelegate.targetRing != targetRing ||
        oldDelegate.hits != hits ||
        oldDelegate.enabled != enabled;
  }
}
