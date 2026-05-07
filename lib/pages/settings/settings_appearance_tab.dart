part of 'app_settings_page.dart';

extension _SettingsAppearanceTab on _AppSettingsPageState {
Widget _buildAppearanceTab(Color accentColor) {
    return Row(
      children: [
        Expanded(
          flex: 8,
          child: _Panel(
            title: 'Farbe',
            subtitle: 'global',
            accentColor: accentColor,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141A22),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF2A3545),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.palette_rounded,
                            color: accentColor,
                            size: 30,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Akzentfarbe',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${appearanceSettings.hue.round()}°',
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Slider(
                        value: appearanceSettings.hue,
                        min: 0,
                        max: 360,
                        divisions: 360,
                        activeColor: accentColor,
                        inactiveColor: const Color(0xFF2A3545),
                        onChanged: _updateHue,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Der Slider ändert die zentrale App-Farbe. Bereits umgestellte Bereiche reagieren sofort. Alte hart codierte grüne Bereiche ziehen wir danach Schritt für Schritt nach.',
                        style: TextStyle(
                          color: Color(0xFF9DA8B7),
                          fontSize: 14,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 58,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _resetAppearance,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Standard-Grün wiederherstellen'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF141A22),
                      foregroundColor: accentColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(
                          color: Color(0xFF2A3545),
                        ),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 12,
          child: _Panel(
            title: 'Vorschau',
            subtitle: 'live',
            accentColor: accentColor,
            child: _AppearancePreview(
              accentColor: accentColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _AppearancePreview extends StatelessWidget {
  final Color accentColor;

  const _AppearancePreview({
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 128,
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: accentColor,
              width: 1.6,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.sports_score_rounded,
                  color: Color(0xFF06100B),
                  size: 38,
                ),
              ),
              const SizedBox(width: 18),
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vorschau',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'So wirkt die neue Akzentfarbe in aktiven Elementen.',
                      style: TextStyle(
                        color: Color(0xFF9DA8B7),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 2.7,
            children: [
              _PreviewTile(
                label: 'Aktiver Spieler',
                value: '301',
                accentColor: accentColor,
                active: true,
              ),
              _PreviewTile(
                label: 'Checkout',
                value: 'T20 · D20',
                accentColor: accentColor,
                active: false,
              ),
              _PreviewTile(
                label: 'Button',
                value: 'Start',
                accentColor: accentColor,
                active: true,
              ),
              _PreviewTile(
                label: 'Status',
                value: 'Bereit',
                accentColor: accentColor,
                active: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewTile extends StatelessWidget {
  final String label;
  final String value;
  final Color accentColor;
  final bool active;

  const _PreviewTile({
    required this.label,
    required this.value,
    required this.accentColor,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: active
            ? accentColor.withValues(alpha: 0.14)
            : const Color(0xFF141A22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? accentColor : const Color(0xFF2A3545),
          width: active ? 1.5 : 1.1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF9DA8B7),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              color: accentColor,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}