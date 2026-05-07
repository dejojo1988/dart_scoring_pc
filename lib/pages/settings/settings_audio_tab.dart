part of 'app_settings_page.dart';

extension _SettingsAudioTab on _AppSettingsPageState {
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
                  'Wichtig: WAV-Dateien werden nicht kopiert, sondern über den gespeicherten Dateipfad abgespielt. Lege deine Sounds am besten in einen festen Ordner, den du nicht verschiebst.',
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
            subtitle: 'WAV',
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
}