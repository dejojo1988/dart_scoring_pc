import 'package:flutter/material.dart';

import '../models/player.dart';

class PlayerScoreCard extends StatelessWidget {
  final Player player;
  final int remainingScore;
  final bool isActive;
  final int legsWon;
  final int setsWon;
  final String? checkoutText;

  const PlayerScoreCard({
    super.key,
    required this.player,
    required this.remainingScore,
    required this.isActive,
    required this.legsWon,
    required this.setsWon,
    this.checkoutText,
  });

  @override
  Widget build(BuildContext context) {
    final String? checkout = checkoutText;
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      height: checkout == null ? 132 : 154,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isActive
            ? accentColor.withOpacity(0.12)
            : const Color(0xFF101720),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActive ? accentColor : const Color(0xFF243040),
          width: isActive ? 1.8 : 1.1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: isActive ? accentColor : const Color(0xFF141A22),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.person_rounded,
              color: isActive ? const Color(0xFF06100B) : accentColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: isActive ? const Color(0xFFEAF1F8) : Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '',
                  style: TextStyle(fontSize: 0),
                ),
                Text(
                  'Legs $legsWon · Sets $setsWon',
                  style: const TextStyle(
                    color: Color(0xFF9DA8B7),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (checkout != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'CO:',
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          checkout,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFEAF1F8),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '$remainingScore',
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: isActive ? accentColor : const Color(0xFFEAF1F8),
            ),
          ),
        ],
      ),
    );
  }
}
