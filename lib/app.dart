import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app_version.dart';
import 'pages/audio_settings_page.dart';
import 'pages/home_page.dart';
import 'services/appearance_service.dart';

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
              overlayColor: accentColor.withOpacity(0.18),
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
                  return accentColor.withOpacity(0.35);
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

class _HomeWithTopButtons extends StatelessWidget {
  const _HomeWithTopButtons();

  Future<void> _closeApp() async {
    await windowManager.close();
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
            color: const Color(0xFF101720).withOpacity(0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFF243040),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
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