import 'package:flutter/material.dart';

import '../models/player.dart';

class PlayerScoreCard extends StatelessWidget {
  final Player player;
  final int remainingScore;
  final bool isActive;
  final int legsWon;
  final int setsWon;
  final String? checkoutText;
  final double matchAverage;
  final double legAverage;
  final int classicCount;
  final int lastTurnScore;
  final String lastTurnText;
  final int legDartsThrown;
  final String? botInfoText;
  final String? statusText;

  const PlayerScoreCard({
    super.key,
    required this.player,
    required this.remainingScore,
    required this.isActive,
    required this.legsWon,
    required this.setsWon,
    this.checkoutText,
    required this.matchAverage,
    required this.legAverage,
    required this.classicCount,
    required this.lastTurnScore,
    required this.lastTurnText,
    required this.legDartsThrown,
    this.botInfoText,
    this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      height: isActive ? 248 : 92,
      padding: EdgeInsets.all(isActive ? 16 : 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isActive
            ? accentColor.withValues(alpha: 0.15)
            : const Color(0xFF101720),
        borderRadius: BorderRadius.circular(isActive ? 28 : 22),
        border: Border.all(
          color: isActive ? accentColor : const Color(0xFF243040),
          width: isActive ? 2.2 : 1.1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.18),
                  blurRadius: 24,
                  spreadRadius: 1,
                ),
              ]
            : const [],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: isActive
            ? _ActivePlayerCardContent(
                key: ValueKey<String>('active_${player.id}'),
                player: player,
                remainingScore: remainingScore,
                legsWon: legsWon,
                setsWon: setsWon,
                matchAverage: matchAverage,
                legAverage: legAverage,
                lastTurnScore: lastTurnScore,
                lastTurnText: lastTurnText,
                legDartsThrown: legDartsThrown,
                botInfoText: botInfoText,
                statusText: statusText,
                accentColor: accentColor,
              )
            : _CompactPlayerCardContent(
                key: ValueKey<String>('compact_${player.id}'),
                player: player,
                remainingScore: remainingScore,
                legsWon: legsWon,
                setsWon: setsWon,
                matchAverage: matchAverage,
                classicCount: classicCount,
                accentColor: accentColor,
              ),
      ),
    );
  }
}

class _ActivePlayerCardContent extends StatelessWidget {
  final Player player;
  final int remainingScore;
  final int legsWon;
  final int setsWon;
  final double matchAverage;
  final double legAverage;
  final int lastTurnScore;
  final String lastTurnText;
  final int legDartsThrown;
  final String? botInfoText;
  final String? statusText;
  final Color accentColor;

  const _ActivePlayerCardContent({
    super.key,
    required this.player,
    required this.remainingScore,
    required this.legsWon,
    required this.setsWon,
    required this.matchAverage,
    required this.legAverage,
    required this.lastTurnScore,
    required this.lastTurnText,
    required this.legDartsThrown,
    required this.botInfoText,
    required this.statusText,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: Color(0xFF06100B),
                size: 32,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 23,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFEAF1F8),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Aktiver Spieler · Legs $legsWon · Sets $setsWon',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFB8C3D1),
                      fontSize: 12,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 112,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '$remainingScore',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 56,
                    height: 0.95,
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ClipRect(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoPill(
                    label: 'MATCH Ø',
                    value: _averageText(matchAverage),
                    accentColor: accentColor,
                  ),
                  _InfoPill(
                    label: 'LEG Ø',
                    value: _averageText(legAverage),
                    accentColor: accentColor,
                  ),
                  _InfoPill(
                    label: 'LETZTER WURF',
                    value: _lastTurnScoreText(
                      lastTurnScore: lastTurnScore,
                      lastTurnText: lastTurnText,
                    ),
                    accentColor: accentColor,
                  ),
                  _InfoPill(
                    label: 'DARTS IM LEG',
                    value: '$legDartsThrown',
                    accentColor: accentColor,
                  ),
                  if (botInfoText != null && botInfoText!.trim().isNotEmpty)
                    _InfoPill(
                      label: 'BOT',
                      value: botInfoText!,
                      accentColor: accentColor,
                      wide: true,
                    ),
                  if (statusText != null && statusText!.trim().isNotEmpty)
                    _InfoPill(
                      label: 'STATUS',
                      value: statusText!,
                      accentColor: accentColor,
                      wide: true,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactPlayerCardContent extends StatelessWidget {
  final Player player;
  final int remainingScore;
  final int legsWon;
  final int setsWon;
  final double matchAverage;
  final int classicCount;
  final Color accentColor;

  const _CompactPlayerCardContent({
    super.key,
    required this.player,
    required this.remainingScore,
    required this.legsWon,
    required this.setsWon,
    required this.matchAverage,
    required this.classicCount,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF141A22),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.26),
            ),
          ),
          child: Icon(
            Icons.person_rounded,
            color: accentColor,
            size: 25,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                player.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFEAF1F8),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Legs $legsWon · Sets $setsWon · Ø ${_averageText(matchAverage)} · Classic $classicCount',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF9DA8B7),
                  fontSize: 12,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 72,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              '$remainingScore',
              maxLines: 1,
              style: const TextStyle(
                fontSize: 34,
                height: 0.95,
                fontWeight: FontWeight.w900,
                color: Color(0xFFEAF1F8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final String value;
  final Color accentColor;
  final bool wide;

  const _InfoPill({
    required this.label,
    required this.value,
    required this.accentColor,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: wide ? 246 : 116,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF081018).withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.22),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accentColor,
                fontSize: 10,
                height: 1.0,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: wide ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFEAF1F8),
                fontSize: 13,
                height: 1.08,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _averageText(double value) {
  if (value <= 0 || value.isNaN || value.isInfinite) {
    return '-';
  }

  return value.toStringAsFixed(1);
}

String _lastTurnScoreText({
  required int lastTurnScore,
  required String lastTurnText,
}) {
  if (lastTurnText.trim().isEmpty || lastTurnText.trim() == '-') {
    return '-';
  }

  return '$lastTurnScore';
}