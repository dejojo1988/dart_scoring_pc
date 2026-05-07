part of 'app_settings_page.dart';

extension _SettingsUpdateTab on _AppSettingsPageState {
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
}