import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/appearance_service.dart';
import '../services/audio_service.dart';

class AudioSettingsPage extends StatefulWidget {
  const AudioSettingsPage({super.key});

  @override
  State<AudioSettingsPage> createState() => _AudioSettingsPageState();
}

class _AudioSettingsPageState extends State<AudioSettingsPage>
    with SingleTickerProviderStateMixin {
  late TabController tabController;

  AudioSettings audioSettings = AudioSettings.defaults();
  AppearanceSettings appearanceSettings = AppearanceSettings.defaults();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    tabController = TabController(
      length: 2,
      vsync: this,
    );

    _loadSettings();
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    await AudioService.instance.load();
    await AppearanceService.instance.load();

    if (!mounted) {
      return;
    }

    setState(() {
      audioSettings = AudioService.instance.settings;
      appearanceSettings = AppearanceService.instance.settings;
      isLoading = false;
    });
  }

  Future<void> _updateAudioSettings(AudioSettings nextSettings) async {
    setState(() {
      audioSettings = nextSettings;
    });

    await AudioService.instance.updateSettings(nextSettings);
  }

  Future<void> _updateHue(double hue) async {
    final AppearanceSettings nextSettings = appearanceSettings.copyWith(
      hue: hue,
    );

    setState(() {
      appearanceSettings = nextSettings;
    });

    await AppearanceService.instance.updateHue(hue);
  }

  Future<void> _resetAppearance() async {
    await AppearanceService.instance.reset();
    await _loadSettings();
    _showMessage('Aussehen wurde zurückgesetzt.');
  }

  Future<void> _pickFile(AudioEventType eventType) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav'],
      allowMultiple: false,
      dialogTitle: 'Audio für "${eventType.title}" auswählen',
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final String? filePath = result.files.single.path;

    if (filePath == null || filePath.trim().isEmpty) {
      _showMessage('Die Datei konnte nicht gelesen werden.');
      return;
    }

    await AudioService.instance.setAudioFile(
      eventType: eventType,
      filePath: filePath,
    );

    await _loadSettings();
    _showMessage('Audio für "${eventType.title}" gespeichert.');
  }

  Future<void> _clearFile(AudioEventType eventType) async {
    await AudioService.instance.clearAudioFile(eventType);
    await _loadSettings();
    _showMessage('Audio für "${eventType.title}" entfernt.');
  }

  Future<void> _testFile(AudioEventType eventType) async {
    await AudioService.instance.testEvent(eventType);
  }

  Future<void> _testVoice() async {
    await AudioService.instance.speak(
      'Ansager-Test. Spieler 1 ist dran und braucht 170 Punkte. Spieler 1 wirft 60 Punkte.',
    );
  }

  String _displayPath(String? path) {
    if (path == null || path.trim().isEmpty) {
      return 'Keine Datei ausgewählt';
    }

    final List<String> parts = path.split(RegExp(r'[\\/]'));
    return parts.isEmpty ? path : parts.last;
  }

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1B2430),
      ),
    );
  }

  Color get accentColor {
    return appearanceSettings.accentColor;
  }

  @override
  Widget build(BuildContext context) {
    final Color liveAccentColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.1,
            colors: [
              liveAccentColor.withOpacity(0.20),
              const Color(0xFF0B0F14),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 34),
            child: Column(
              children: [
                _buildHeader(context, liveAccentColor),
                const SizedBox(height: 22),
                _buildTabs(liveAccentColor),
                const SizedBox(height: 22),
                Expanded(
                  child: isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: liveAccentColor,
                          ),
                        )
                      : TabBarView(
                          controller: tabController,
                          children: [
                            _buildAudioTab(liveAccentColor),
                            _buildAppearanceTab(liveAccentColor),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color accentColor) {
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
            Icons.tune_rounded,
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
                'Einstellungen',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Audio und Aussehen verwalten',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF9DA8B7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabs(Color accentColor) {
    return Container(
      height: 58,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF101720),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF243040),
        ),
      ),
      child: TabBar(
        controller: tabController,
        indicator: BoxDecoration(
          color: accentColor,
          borderRadius: BorderRadius.circular(17),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: const Color(0xFF06100B),
        unselectedLabelColor: const Color(0xFF9DA8B7),
        labelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.volume_up_rounded, size: 22),
                SizedBox(width: 8),
                Text('Audio'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.palette_rounded, size: 22),
                SizedBox(width: 8),
                Text('Aussehen'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioTab(Color accentColor) {
    return Row(
      children: [
        Expanded(
          flex: 8,
          child: _Panel(
            title: 'Grundlagen',
            subtitle: 'global',
            accentColor: accentColor,
            child: Column(
              children: [
                _SwitchCard(
                  title: 'Audio aktiv',
                  subtitle: 'Schaltet alle Jingles und Ansagen ein oder aus.',
                  value: audioSettings.audioEnabled,
                  icon: Icons.power_settings_new_rounded,
                  accentColor: accentColor,
                  onChanged: (value) {
                    _updateAudioSettings(
                      audioSettings.copyWith(audioEnabled: value),
                    );
                  },
                ),
                const SizedBox(height: 14),
                _SwitchCard(
                  title: 'Windows-Ansager aktiv',
                  subtitle:
                      'Spricht dynamische Texte wie Spieler-Nummer und Restpunkte.',
                  value: audioSettings.voiceEnabled,
                  icon: Icons.record_voice_over_rounded,
                  accentColor: accentColor,
                  onChanged: (value) {
                    _updateAudioSettings(
                      audioSettings.copyWith(voiceEnabled: value),
                    );
                  },
                ),
                const SizedBox(height: 14),
                _VolumeCard(
                  volume: audioSettings.volume,
                  accentColor: accentColor,
                  onChanged: (value) {
                    _updateAudioSettings(
                      audioSettings.copyWith(volume: value),
                    );
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 58,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _testVoice,
                    icon: const Icon(Icons.record_voice_over_rounded),
                    label: const Text('Ansager testen'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: const Color(0xFF06100B),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Wichtig: MP3/WAV-Dateien werden nicht kopiert, sondern über den gespeicherten Dateipfad abgespielt. Lege deine Sounds am besten in einen festen Ordner, den du nicht verschiebst.',
                  style: TextStyle(
                    color: Color(0xFF9DA8B7),
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
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
            title: 'Events',
            subtitle: 'MP3 / WAV',
            accentColor: accentColor,
            child: ListView.separated(
              itemCount: AudioEventType.values.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final AudioEventType eventType = AudioEventType.values[index];
                final String? path =
                    audioSettings.filePathsByEventKey[eventType.key];

                return _AudioEventCard(
                  title: eventType.title,
                  subtitle: eventType.description,
                  fileName: _displayPath(path),
                  hasFile: path != null && path.trim().isNotEmpty,
                  accentColor: accentColor,
                  onPick: () {
                    _pickFile(eventType);
                  },
                  onClear: () {
                    _clearFile(eventType);
                  },
                  onTest: () {
                    _testFile(eventType);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

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

class _Panel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accentColor;
  final Widget child;

  const _Panel({
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF101720),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFF243040),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.radio_button_checked,
                color: accentColor,
              ),
              const SizedBox(width: 10),
              Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF9DA8B7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SwitchCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final IconData icon;
  final Color accentColor;
  final ValueChanged<bool> onChanged;

  const _SwitchCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141A22),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF2A3545),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: accentColor,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF9DA8B7),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: accentColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _VolumeCard extends StatelessWidget {
  final double volume;
  final Color accentColor;
  final ValueChanged<double> onChanged;

  const _VolumeCard({
    required this.volume,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
                Icons.volume_down_rounded,
                color: accentColor,
              ),
              const SizedBox(width: 10),
              const Text(
                'Lautstärke',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '${(volume * 100).round()}%',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Slider(
            value: volume,
            min: 0,
            max: 1,
            divisions: 20,
            activeColor: accentColor,
            inactiveColor: const Color(0xFF2A3545),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _AudioEventCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String fileName;
  final bool hasFile;
  final Color accentColor;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final VoidCallback onTest;

  const _AudioEventCard({
    required this.title,
    required this.subtitle,
    required this.fileName,
    required this.hasFile,
    required this.accentColor,
    required this.onPick,
    required this.onClear,
    required this.onTest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 122,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF141A22),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF2A3545),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.13),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              Icons.music_note_rounded,
              color: accentColor,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF9DA8B7),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  fileName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hasFile ? accentColor : const Color(0xFF6F7A89),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _SmallButton(
            icon: Icons.folder_open_rounded,
            label: 'Import',
            color: accentColor,
            onTap: onPick,
          ),
          const SizedBox(width: 8),
          _SmallButton(
            icon: Icons.play_arrow_rounded,
            label: 'Test',
            color: accentColor,
            onTap: hasFile ? onTest : null,
          ),
          const SizedBox(width: 8),
          _SmallButton(
            icon: Icons.delete_outline_rounded,
            label: 'Raus',
            color: const Color(0xFFFF5C77),
            onTap: hasFile ? onClear : null,
          ),
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _SmallButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 58,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF101720),
          foregroundColor: color,
          disabledBackgroundColor: const Color(0xFF101720),
          disabledForegroundColor: const Color(0xFF566172),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(
              color: Color(0xFF2A3545),
            ),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
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
            color: accentColor.withOpacity(0.12),
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
        color:
            active ? accentColor.withOpacity(0.14) : const Color(0xFF141A22),
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