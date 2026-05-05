import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app_version.dart';
import 'data/app_database.dart';
import 'pages/audio_settings_page.dart';
import 'pages/home_page.dart';
import 'services/appearance_service.dart';
import 'services/update_service.dart';

class DartScoringApp extends StatelessWidget {
  const DartScoringApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppearanceSettings>(
      valueListenable: AppearanceService.instance.notifier,
      builder: (context, appearanceSettings, child) {
        final Color accentColor = appearanceSettings.accentColor;

        return MaterialApp(
          title: AppVersion.windowTitle,
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(useMaterial3: true).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: accentColor,
              brightness: Brightness.dark,
            ),
            sliderTheme: SliderThemeData(
              activeTrackColor: accentColor,
              thumbColor: accentColor,
              overlayColor: accentColor.withValues(alpha: 0.18),
              inactiveTrackColor: const Color(0xFF2A3545),
            ),
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return accentColor;
                }

                return const Color(0xFF9DA8B7);
              }),
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return accentColor.withValues(alpha: 0.35);
                }

                return const Color(0xFF2A3545);
              }),
            ),
          ),
          home: const _HomeWithTopButtons(),
        );
      },
    );
  }
}

class _HomeWithTopButtons extends StatefulWidget {
  const _HomeWithTopButtons();

  @override
  State<_HomeWithTopButtons> createState() => _HomeWithTopButtonsState();
}

class _HomeWithTopButtonsState extends State<_HomeWithTopButtons> {
  bool updateCheckStarted = false;

  @override
  void initState() {
    super.initState();

    _initializeDatabase();
    _scheduleAutomaticUpdateCheck();
  }

  Future<void> _initializeDatabase() async {
    try {
      await AppDatabase.instance.database;
    } catch (_) {
      // Datenbankfehler darf den App-Start nicht komplett verhindern.
    }
  }

  Future<void> _closeApp() async {
    await windowManager.close();
  }

  void _scheduleAutomaticUpdateCheck() {
    if (updateCheckStarted) {
      return;
    }

    updateCheckStarted = true;

    Future<void>.delayed(const Duration(seconds: 2), () async {
      if (!mounted) {
        return;
      }

      await _checkForUpdatesSilently();
    });
  }

  Future<void> _checkForUpdatesSilently() async {
    try {
      await UpdateService.instance.load();

      final UpdateCheckResult result =
          await UpdateService.instance.checkForUpdate();

      if (!mounted || !result.hasUpdate) {
        return;
      }

      _showUpdateAvailableDialog(result);
    } catch (_) {
      // Beim App-Start soll ein fehlgeschlagener Online-Check nicht nerven.
      // Manuell prüfen kann man weiterhin im Update-Tab.
    }
  }

  void _showUpdateAvailableDialog(UpdateCheckResult result) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final Color accentColor = Theme.of(dialogContext).colorScheme.primary;

        return AlertDialog(
          backgroundColor: const Color(0xFF101720),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
            side: const BorderSide(
              color: Color(0xFF243040),
              width: 1.2,
            ),
          ),
          title: Row(
            children: [
              Icon(
                Icons.system_update_alt_rounded,
                color: accentColor,
                size: 30,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Update ${result.manifest.version} verfügbar',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            result.manifest.notes.trim().isEmpty
                ? 'Es gibt eine neue Version von Dart Scoring PC.'
                : result.manifest.notes,
            style: const TextStyle(
              color: Color(0xFFCFD7E3),
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Später'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();

                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AudioSettingsPage(),
                  ),
                );
              },
              icon: const Icon(Icons.download_for_offline_rounded),
              label: const Text('Update öffnen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: const Color(0xFF06100B),
                elevation: 0,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Stack(
      children: [
        const HomePage(),
        Positioned(
          top: 24,
          right: 24,
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TopIconButton(
                    tooltip: 'Einstellungen',
                    icon: Icons.settings_rounded,
                    color: accentColor,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AudioSettingsPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  _TopIconButton(
                    tooltip: 'Software beenden',
                    icon: Icons.power_settings_new_rounded,
                    color: const Color(0xFFFF5C77),
                    onTap: _closeApp,
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

class _TopIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TopIconButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: const Color(0xFF101720).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFF243040),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: color,
            size: 31,
          ),
        ),
      ),
    );
  }
}