import 'package:flutter/material.dart';

import '../models/game_settings.dart';
import '../widgets/app_button.dart';
import 'match_setup_page.dart';

class GameSelectionPage extends StatelessWidget {
  const GameSelectionPage({super.key});

  void _openX01Setup(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MatchSetupPage(
          initialSettings: GameSettings.defaultX01(),
        ),
      ),
    );
  }

  void _openRoundTheClockSetup(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MatchSetupPage(
          initialSettings: GameSettings.defaultRoundTheClock(),
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
              accentColor.withOpacity(0.20),
              const Color(0xFF0B0F14),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 34),
            child: Column(
              children: [
                _buildHeader(context),
                const SizedBox(height: 56),
                Expanded(
                  child: Center(
                    child: Wrap(
                      spacing: 28,
                      runSpacing: 28,
                      alignment: WrapAlignment.center,
                      children: [
                        AppButton(
                          title: 'x01',
                          subtitle: '301, 501 und klassische Dart-Legs',
                          icon: Icons.looks_one_rounded,
                          onPressed: () {
                            _openX01Setup(context);
                          },
                        ),
                        AppButton(
                          title: 'Round the Clock',
                          subtitle: 'Treffe die Zahlen der Reihe nach',
                          icon: Icons.access_time_filled_rounded,
                          onPressed: () {
                            _openRoundTheClockSetup(context);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Play for Fun — Game Selection',
                  style: TextStyle(
                    color: Color(0xFF6F7A89),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
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
        IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.arrow_back_rounded),
          color: Colors.white,
          iconSize: 32,
          tooltip: 'Zurück',
        ),
        const SizedBox(width: 14),
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.13),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accentColor.withOpacity(0.25),
            ),
          ),
          child: Icon(
            Icons.sports_score_rounded,
            color: accentColor,
            size: 34,
          ),
        ),
        const SizedBox(width: 18),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Play for Fun',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Wähle einen Spielmodus',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF9DA8B7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}