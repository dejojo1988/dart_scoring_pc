part of 'app_settings_page.dart'; 

extension _SettingsBackupTab on _AppSettingsPageState {
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