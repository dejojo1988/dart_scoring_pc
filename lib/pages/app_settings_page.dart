import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app_version.dart';
import '../data/app_database.dart';
import '../services/appearance_service.dart';
import '../services/audio_service.dart';
import '../services/update_service.dart';

class AppSettingsPage extends StatefulWidget {
  const AppSettingsPage({super.key});

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage>
    with SingleTickerProviderStateMixin {
  late TabController tabController;

  AudioSettings audioSettings = AudioSettings.defaults();
  AppearanceSettings appearanceSettings = AppearanceSettings.defaults();
  UpdateSettings updateSettings = UpdateSettings.defaults();
  UpdateCheckResult? updateCheckResult;

  final TextEditingController updateManifestController =
      TextEditingController();

  String updateStatusText = 'Noch keine Update-Prüfung durchgeführt.';
  String backupStatusText = 'Backups noch nicht geladen.';
  String databasePathText = '';
  String backupFolderPathText = '';

  List<DatabaseBackupInfo> databaseBackups = const [];

  bool isLoading = true;
  bool isCheckingForUpdate = false;
  bool isDownloadingUpdate = false;
  bool isCreatingDataBackup = false;
  bool isExportingDataBackup = false;
  bool isRestoringDataBackup = false;
  bool isOpeningBackupFolder = false;
  double updateDownloadProgress = 0;

  @override
  void initState() {
    super.initState();

    tabController = TabController(
      length: 4,
      vsync: this,
    );

    _loadSettings();
  }

  @override
  void dispose() {
    updateManifestController.dispose();
    tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    await AudioService.instance.load();
    await AppearanceService.instance.load();
    await UpdateService.instance.load();

    final File databaseFile = await AppDatabase.instance.getDatabaseFile();
    final Directory backupDirectory =
        await AppDatabase.instance.getBackupDirectory();
    final List<DatabaseBackupInfo> backups =
        await AppDatabase.instance.getDatabaseBackups();

    if (!mounted) {
      return;
    }

    setState(() {
      audioSettings = AudioService.instance.settings;
      appearanceSettings = AppearanceService.instance.settings;
      updateSettings = UpdateService.instance.settings;
      updateManifestController.text = updateSettings.manifestLocation;
      databasePathText = databaseFile.path;
      backupFolderPathText = backupDirectory.path;
      databaseBackups = backups;
      backupStatusText = backups.isEmpty
          ? 'Noch keine Backups vorhanden.'
          : '${backups.length} Backup(s) gefunden.';
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
      allowedExtensions: ['wav'],
      allowMultiple: false,
      dialogTitle: 'WAV-Audio für "${eventType.title}" auswählen',
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final String? filePath = result.files.single.path;

    if (filePath == null || filePath.trim().isEmpty) {
      _showMessage('Die Datei konnte nicht gelesen werden.');
      return;
    }

    if (!filePath.trim().toLowerCase().endsWith('.wav')) {
      _showMessage('Bitte eine WAV-Datei auswählen.');
      return;
    }

    await AudioService.instance.setAudioFile(
      eventType: eventType,
      filePath: filePath,
    );

    await _loadSettings();
    _showMessage('WAV-Audio für "${eventType.title}" gespeichert.');
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

  bool get _isDataBackupBusy {
    return isCreatingDataBackup ||
        isExportingDataBackup ||
        isRestoringDataBackup ||
        isOpeningBackupFolder ||
        isDownloadingUpdate ||
        isCheckingForUpdate;
  }

  Future<void> _refreshDatabaseBackups() async {
    final File databaseFile = await AppDatabase.instance.getDatabaseFile();
    final Directory backupDirectory =
        await AppDatabase.instance.getBackupDirectory();
    final List<DatabaseBackupInfo> backups =
        await AppDatabase.instance.getDatabaseBackups();

    if (!mounted) {
      return;
    }

    setState(() {
      databasePathText = databaseFile.path;
      backupFolderPathText = backupDirectory.path;
      databaseBackups = backups;
      backupStatusText = backups.isEmpty
          ? 'Noch keine Backups vorhanden.'
          : '${backups.length} Backup(s) gefunden.';
    });
  }

  Future<void> _createDataBackupNow() async {
    if (_isDataBackupBusy) {
      return;
    }

    setState(() {
      isCreatingDataBackup = true;
      backupStatusText = 'Erstelle manuelles Backup...';
    });

    try {
      final File backupFile = await AppDatabase.instance.createManualBackup(
        reason: 'manual_settings',
      );

      await _refreshDatabaseBackups();

      if (!mounted) {
        return;
      }

      setState(() {
        backupStatusText = 'Backup erstellt: ${_displayPath(backupFile.path)}';
      });

      _showMessage('Backup erstellt: ${_displayPath(backupFile.path)}');
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        backupStatusText = 'Backup fehlgeschlagen: $error';
      });

      _showMessage('Backup fehlgeschlagen: $error');
    } finally {
      if (mounted) {
        setState(() {
          isCreatingDataBackup = false;
        });
      }
    }
  }

  Future<void> _openBackupFolder() async {
    if (_isDataBackupBusy) {
      return;
    }

    setState(() {
      isOpeningBackupFolder = true;
      backupStatusText = 'Öffne Backup-Ordner...';
    });

    try {
      final Directory backupDirectory =
          await AppDatabase.instance.getBackupDirectory();

      if (Platform.isWindows) {
        await Process.run('explorer', [backupDirectory.path]);
      } else {
        throw UnsupportedError(
          'Ordner öffnen wird aktuell nur unter Windows unterstützt.',
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        backupFolderPathText = backupDirectory.path;
        backupStatusText = 'Backup-Ordner geöffnet.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        backupStatusText = 'Backup-Ordner konnte nicht geöffnet werden: $error';
      });

      _showMessage('Backup-Ordner konnte nicht geöffnet werden: $error');
    } finally {
      if (mounted) {
        setState(() {
          isOpeningBackupFolder = false;
        });
      }
    }
  }

  Future<void> _exportDatabaseBackup() async {
    if (_isDataBackupBusy) {
      return;
    }

    final String? targetDirectoryPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Export-Ziel für Datenbank auswählen',
    );

    if (targetDirectoryPath == null || targetDirectoryPath.trim().isEmpty) {
      return;
    }

    setState(() {
      isExportingDataBackup = true;
      backupStatusText = 'Exportiere Datenbank...';
    });

    try {
      final File exportFile = await AppDatabase.instance.exportDatabaseBackup(
        targetDirectoryPath: targetDirectoryPath,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        backupStatusText = 'Datenbank exportiert: ${exportFile.path}';
      });

      _showMessage('Datenbank exportiert: ${_displayPath(exportFile.path)}');
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        backupStatusText = 'Export fehlgeschlagen: $error';
      });

      _showMessage('Export fehlgeschlagen: $error');
    } finally {
      if (mounted) {
        setState(() {
          isExportingDataBackup = false;
        });
      }
    }
  }

  Future<void> _pickAndRestoreDatabaseBackup() async {
    if (_isDataBackupBusy) {
      return;
    }

    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['db'],
      allowMultiple: false,
      dialogTitle: 'Datenbank-Backup wiederherstellen',
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final String? backupFilePath = result.files.single.path;

    if (backupFilePath == null || backupFilePath.trim().isEmpty) {
      _showMessage('Die Backup-Datei konnte nicht gelesen werden.');
      return;
    }

    await _restoreDatabaseBackup(backupFilePath);
  }

  Future<void> _restoreDatabaseBackup(String backupFilePath) async {
    if (_isDataBackupBusy) {
      return;
    }

    final bool confirmed = await _showConfirmDialog(
      title: 'Backup wiederherstellen?',
      message:
          'Die aktuelle Datenbank wird vorher automatisch gesichert. Danach wird dieses Backup als aktive Datenbank eingesetzt. Die App sollte danach neu gestartet werden.',
      confirmLabel: 'Wiederherstellen',
      danger: true,
    );

    if (!confirmed) {
      return;
    }

    setState(() {
      isRestoringDataBackup = true;
      backupStatusText = 'Stelle Backup wieder her...';
    });

    try {
      await AppDatabase.instance.restoreDatabaseFromBackup(
        backupFilePath: backupFilePath,
      );

      await _refreshDatabaseBackups();

      if (!mounted) {
        return;
      }

      setState(() {
        backupStatusText =
            'Backup wiederhergestellt. Bitte App neu starten, damit alle Ansichten die Daten neu laden.';
      });

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF101720),
            title: const Text('Backup wiederhergestellt'),
            content: const Text(
              'Die Datenbank wurde wiederhergestellt. Starte die App jetzt neu, damit Profile und Statistiken überall sauber neu geladen werden.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        backupStatusText = 'Wiederherstellung fehlgeschlagen: $error';
      });

      _showMessage('Wiederherstellung fehlgeschlagen: $error');
    } finally {
      if (mounted) {
        setState(() {
          isRestoringDataBackup = false;
        });
      }
    }
  }

  Future<void> _saveUpdateSettings() async {
    final UpdateSettings nextSettings = updateSettings.copyWith(
      manifestLocation: updateManifestController.text.trim(),
    );

    setState(() {
      updateSettings = nextSettings;
      updateCheckResult = null;
      updateStatusText = 'Update-Quelle gespeichert.';
    });

    await UpdateService.instance.updateSettings(nextSettings);
    _showMessage('Update-Quelle gespeichert.');
  }

  Future<void> _checkForUpdate() async {
    if (isCheckingForUpdate || isDownloadingUpdate) {
      return;
    }

    await _saveUpdateSettings();

    setState(() {
      isCheckingForUpdate = true;
      updateStatusText = 'Prüfe auf Updates...';
      updateCheckResult = null;
      updateDownloadProgress = 0;
    });

    try {
      final UpdateCheckResult result =
          await UpdateService.instance.checkForUpdate();

      if (!mounted) {
        return;
      }

      setState(() {
        updateCheckResult = result;
        updateStatusText = result.hasUpdate
            ? 'Update ${result.manifest.version} verfügbar. Vor der Installation wird automatisch ein Backup erstellt.'
            : 'Keine neue Version verfügbar.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        updateStatusText = 'Update-Prüfung fehlgeschlagen: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          isCheckingForUpdate = false;
        });
      }
    }
  }

  Future<void> _downloadAndInstallUpdate() async {
    final UpdateCheckResult? result = updateCheckResult;

    if (result == null || !result.hasUpdate) {
      _showMessage('Es ist kein Update ausgewählt.');
      return;
    }

    if (isDownloadingUpdate || isCheckingForUpdate) {
      return;
    }

    setState(() {
      isDownloadingUpdate = true;
      updateDownloadProgress = 0;
      updateStatusText = 'Erstelle Sicherheits-Backup vor dem Update...';
    });

    try {
      final File backupFile = await AppDatabase.instance.createManualBackup(
        reason: 'before_update_${result.manifest.version}',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        updateStatusText =
            'Backup erstellt: ${_displayPath(backupFile.path)}\nUpdate wird heruntergeladen...';
      });

      final UpdateDownloadResult downloadResult =
          await UpdateService.instance.downloadInstaller(
        manifest: result.manifest,
        onProgress: (progress) {
          if (!mounted) {
            return;
          }

          setState(() {
            updateDownloadProgress = progress.clamp(0.0, 1.0).toDouble();
          });
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        updateDownloadProgress = 1;
        updateStatusText =
            'Backup erstellt: ${_displayPath(backupFile.path)}\nInstaller heruntergeladen. Die App wird jetzt geschlossen.';
      });

      await Future<void>.delayed(const Duration(milliseconds: 500));

      await UpdateService.instance.launchInstallerAndExit(
        downloadResult.installerFile,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        updateStatusText =
            'Update abgebrochen. Backup oder Installation fehlgeschlagen: $error';
        isDownloadingUpdate = false;
      });
    }
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    bool danger = false,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101720),
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    danger ? const Color(0xFFFF5C77) : accentColor,
                foregroundColor: const Color(0xFF06100B),
              ),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    return result ?? false;
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
              liveAccentColor.withValues(alpha: 0.20),
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
                            _buildUpdateTab(liveAccentColor),
                            _buildDataBackupTab(liveAccentColor),
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
            color: accentColor.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.25),
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
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.system_update_alt_rounded, size: 22),
                SizedBox(width: 8),
                Text('Update'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.backup_rounded, size: 22),
                SizedBox(width: 8),
                Text('Backup'),
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

  Widget _buildUpdateTab(Color accentColor) {
    final UpdateCheckResult? result = updateCheckResult;
    final bool hasUpdate = result != null && result.hasUpdate;

    return Row(
      children: [
        Expanded(
          flex: 10,
          child: _Panel(
            title: 'Update-Quelle',
            subtitle: 'Manifest',
            accentColor: accentColor,
            child: ListView(
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
                            Icons.verified_rounded,
                            color: accentColor,
                            size: 30,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Aktuelle Version',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            AppVersion.visibleLabel,
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Update-Manifest URL oder Netzwerkpfad',
                        style: TextStyle(
                          color: Color(0xFF9DA8B7),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: updateManifestController,
                        enabled: !isCheckingForUpdate && !isDownloadingUpdate,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              r'https://deine-domain.de/dartscoring/update.json oder \\PC\Share\update.json',
                          hintStyle: const TextStyle(
                            color: Color(0xFF566172),
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF101720),
                          prefixIcon: Icon(
                            Icons.link_rounded,
                            color: accentColor,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Color(0xFF2A3545),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(
                              color: accentColor,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Die App liest eine update.json. Vor jeder Installation wird automatisch ein Backup deiner Profile und Statistiken erstellt. Erst danach wird der Installer heruntergeladen und gestartet.',
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
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 58,
                        child: ElevatedButton.icon(
                          onPressed: isCheckingForUpdate || isDownloadingUpdate
                              ? null
                              : _saveUpdateSettings,
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('Quelle speichern'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF141A22),
                            foregroundColor: accentColor,
                            disabledBackgroundColor: const Color(0xFF101720),
                            disabledForegroundColor: const Color(0xFF566172),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: const BorderSide(
                                color: Color(0xFF2A3545),
                              ),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: SizedBox(
                        height: 58,
                        child: ElevatedButton.icon(
                          onPressed: isCheckingForUpdate || isDownloadingUpdate
                              ? null
                              : _checkForUpdate,
                          icon: isCheckingForUpdate
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                  ),
                                )
                              : const Icon(Icons.search_rounded),
                          label: Text(
                            isCheckingForUpdate
                                ? 'Prüfe...'
                                : 'Update prüfen',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: const Color(0xFF06100B),
                            disabledBackgroundColor: const Color(0xFF243040),
                            disabledForegroundColor: const Color(0xFF9DA8B7),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 10,
          child: _Panel(
            title: 'Update-Status',
            subtitle: hasUpdate ? 'verfügbar' : 'Status',
            accentColor: accentColor,
            child: ListView(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: hasUpdate
                        ? accentColor.withValues(alpha: 0.11)
                        : const Color(0xFF141A22),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: hasUpdate ? accentColor : const Color(0xFF2A3545),
                      width: hasUpdate ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            hasUpdate
                                ? Icons.system_update_alt_rounded
                                : Icons.info_outline_rounded,
                            color: hasUpdate
                                ? accentColor
                                : const Color(0xFF9DA8B7),
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              updateStatusText,
                              style: TextStyle(
                                color: hasUpdate
                                    ? accentColor
                                    : const Color(0xFFEAF1F8),
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (result != null) ...[
                        const SizedBox(height: 18),
                        _UpdateDataLine(
                          label: 'Installiert',
                          value: result.localVersion,
                        ),
                        _UpdateDataLine(
                          label: 'Online',
                          value: result.manifest.version,
                        ),
                        _UpdateDataLine(
                          label: 'Kanal',
                          value: result.manifest.channel,
                        ),
                        if (result.manifest.notes.trim().isNotEmpty)
                          _UpdateDataLine(
                            label: 'Notizen',
                            value: result.manifest.notes,
                          ),
                      ],
                      if (isDownloadingUpdate) ...[
                        const SizedBox(height: 22),
                        LinearProgressIndicator(
                          value: updateDownloadProgress <= 0
                              ? null
                              : updateDownloadProgress,
                          color: accentColor,
                          backgroundColor: const Color(0xFF2A3545),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          updateDownloadProgress <= 0
                              ? 'Download läuft...'
                              : '${(updateDownloadProgress * 100).round()}%',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 62,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        hasUpdate && !isDownloadingUpdate && !isCheckingForUpdate
                            ? _downloadAndInstallUpdate
                            : null,
                    icon: const Icon(Icons.download_for_offline_rounded),
                    label: Text(
                      isDownloadingUpdate
                          ? 'Backup / Update läuft...'
                          : 'Backup erstellen und Update installieren',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: const Color(0xFF06100B),
                      disabledBackgroundColor: const Color(0xFF243040),
                      disabledForegroundColor: const Color(0xFF6F7A89),
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
                const SizedBox(height: 16),
                const Text(
                  'Wichtig: Die App kann sich nicht selbst überschreiben. Deshalb wird zuerst ein Backup erstellt, danach der Installer gestartet und die App beendet sich automatisch.',
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
      ],
    );
  }

  Widget _buildDataBackupTab(Color accentColor) {
    return Row(
      children: [
        Expanded(
          flex: 9,
          child: _Panel(
            title: 'Daten & Backup',
            subtitle: 'Profile / Statistiken',
            accentColor: accentColor,
            child: ListView(
              children: [
                _DataActionCard(
                  title: 'Backup jetzt erstellen',
                  subtitle:
                      'Erstellt sofort eine Sicherheitskopie deiner Profile, Statistiken und Matchdaten.',
                  icon: Icons.save_alt_rounded,
                  accentColor: accentColor,
                  isLoading: isCreatingDataBackup,
                  onTap: _isDataBackupBusy ? null : _createDataBackupNow,
                ),
                const SizedBox(height: 14),
                _DataActionCard(
                  title: 'Backup-Ordner öffnen',
                  subtitle:
                      'Öffnet den Ordner, in dem automatische und manuelle Backups liegen.',
                  icon: Icons.folder_open_rounded,
                  accentColor: accentColor,
                  isLoading: isOpeningBackupFolder,
                  onTap: _isDataBackupBusy ? null : _openBackupFolder,
                ),
                const SizedBox(height: 14),
                _DataActionCard(
                  title: 'Datenbank exportieren',
                  subtitle:
                      'Kopiert die aktuelle Datenbank an einen Ort deiner Wahl, z. B. USB-Stick oder Cloud-Ordner.',
                  icon: Icons.ios_share_rounded,
                  accentColor: accentColor,
                  isLoading: isExportingDataBackup,
                  onTap: _isDataBackupBusy ? null : _exportDatabaseBackup,
                ),
                const SizedBox(height: 14),
                _DataActionCard(
                  title: 'Backup wiederherstellen',
                  subtitle:
                      'Wählt eine .db-Datei aus und setzt sie als aktive Datenbank ein. Vorher wird automatisch ein Sicherheitsbackup erstellt.',
                  icon: Icons.restore_rounded,
                  accentColor: const Color(0xFFFFC857),
                  isLoading: isRestoringDataBackup,
                  onTap:
                      _isDataBackupBusy ? null : _pickAndRestoreDatabaseBackup,
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141A22),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFF2A3545)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        backupStatusText,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _UpdateDataLine(
                        label: 'Datenbank',
                        value: databasePathText.isEmpty
                            ? 'nicht geladen'
                            : databasePathText,
                      ),
                      _UpdateDataLine(
                        label: 'Backups',
                        value: backupFolderPathText.isEmpty
                            ? 'nicht geladen'
                            : backupFolderPathText,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Wichtig: Beim Wiederherstellen wird die aktuelle Datenbank vorher automatisch als before_restore-Backup gesichert. Trotzdem gilt: Wenn dir ein Stand extrem wichtig ist, exportiere ihn zusätzlich außerhalb des AppData-Ordners.',
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
          flex: 11,
          child: _Panel(
            title: 'Vorhandene Backups',
            subtitle: '${databaseBackups.length}',
            accentColor: accentColor,
            child: databaseBackups.isEmpty
                ? const Center(
                    child: Text(
                      'Noch keine Backups vorhanden.',
                      style: TextStyle(
                        color: Color(0xFF9DA8B7),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: databaseBackups.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final DatabaseBackupInfo backup = databaseBackups[index];

                      return _DatabaseBackupCard(
                        backup: backup,
                        accentColor: accentColor,
                        restoreEnabled: !_isDataBackupBusy,
                        onRestore: () => _restoreDatabaseBackup(backup.path),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _DataActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final bool isLoading;
  final VoidCallback? onTap;

  const _DataActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF141A22),
          foregroundColor: accentColor,
          disabledBackgroundColor: const Color(0xFF101720),
          disabledForegroundColor: const Color(0xFF566172),
          elevation: 0,
          padding: const EdgeInsets.all(18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFF2A3545)),
          ),
        ),
        child: Row(
          children: [
            isLoading
                ? SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: accentColor,
                    ),
                  )
                : Icon(icon, size: 30),
            const SizedBox(width: 16),
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
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF9DA8B7),
                      fontSize: 13,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DatabaseBackupCard extends StatelessWidget {
  final DatabaseBackupInfo backup;
  final Color accentColor;
  final bool restoreEnabled;
  final VoidCallback onRestore;

  const _DatabaseBackupCard({
    required this.backup,
    required this.accentColor,
    required this.restoreEnabled,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141A22),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF2A3545)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.storage_rounded,
            color: accentColor,
            size: 30,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  backup.fileName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${backup.displayDate} · ${backup.displaySize}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF9DA8B7),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  backup.path,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6F7A89),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          _SmallButton(
            icon: Icons.restore_rounded,
            label: 'Restore',
            color: const Color(0xFFFFC857),
            onTap: restoreEnabled ? onRestore : null,
          ),
        ],
      ),
    );
  }
}

class _UpdateDataLine extends StatelessWidget {
  final String label;
  final String value;

  const _UpdateDataLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF9DA8B7),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFFEAF1F8),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
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
            activeThumbColor: accentColor,
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
              color: accentColor.withValues(alpha: 0.13),
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
            onTap: onTest,
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