import 'package:flutter/material.dart';

import '../app_version.dart';
import '../widgets/app_button.dart';
import 'game_selection_page.dart';
import 'profiles_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _openGameSelection(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const GameSelectionPage(),
      ),
    );
  }

  void _openProfiles(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ProfilesPage(),
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
                          title: 'Play for Fun',
                          subtitle: 'Schnelles Spiel ohne Turnierbaum',
                          icon: Icons.sports_score_rounded,
                          onPressed: () {
                            _openGameSelection(context);
                          },
                        ),
                        AppButton(
                          title: 'Play Tournament',
                          subtitle: 'Turniere, Teilnehmer und KO-System',
                          icon: Icons.emoji_events_rounded,
                          enabled: false,
                          onPressed: () {},
                        ),
                        AppButton(
                          title: 'Profiles',
                          subtitle: 'Spieler, Statistiken und Entwicklung',
                          icon: Icons.groups_rounded,
                          onPressed: () {
                            _openProfiles(context);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  AppVersion.homeFooterLabel,
                  style: TextStyle(
                    color: Color(0xFF6F7A89),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
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
            Icons.track_changes_rounded,
            color: accentColor,
            size: 34,
          ),
        ),
        const SizedBox(width: 18),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dart Scoring PC',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Modernes Dart-Scoring für Windows Desktop',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF9DA8B7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 10),
              _VersionBadge(),
            ],
          ),
        ),
      ],
    );
  }
}

class _VersionBadge extends StatelessWidget {
  const _VersionBadge();

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: accentColor.withOpacity(0.45),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified_rounded,
              color: accentColor,
              size: 17,
            ),
            const SizedBox(width: 8),
            Text(
              AppVersion.visibleLabel,
              style: TextStyle(
                color: accentColor,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}