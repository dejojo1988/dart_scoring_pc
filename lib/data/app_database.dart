import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/player.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const String _databaseFileName = 'dart_scoring_pc.db';
  static const String _appDataFolderName = 'DartScoringPC';
  static const String _backupFolderName = 'backups';

  Database? _database;

  Future<Database> get database async {
    final Database? existingDatabase = _database;

    if (existingDatabase != null) {
      return existingDatabase;
    }

    final Database newDatabase = await _openDatabase();
    _database = newDatabase;
    return newDatabase;
  }

  Future<Directory> getApplicationDataDirectory() async {
    return _getDatabaseDirectory();
  }

  Future<Directory> getBackupDirectory() async {
    final Directory databaseDirectory = await _getDatabaseDirectory();
    final Directory backupDirectory = Directory(
      path.join(
        databaseDirectory.path,
        _backupFolderName,
      ),
    );

    await backupDirectory.create(recursive: true);
    return backupDirectory;
  }

  Future<File> getDatabaseFile() async {
    final Directory databaseDirectory = await _getDatabaseDirectory();

    return File(
      path.join(
        databaseDirectory.path,
        _databaseFileName,
      ),
    );
  }

  Future<List<DatabaseBackupInfo>> getDatabaseBackups() async {
    final Directory backupDirectory = await getBackupDirectory();
    final List<FileSystemEntity> entries =
        await backupDirectory.list().toList();

    final List<DatabaseBackupInfo> backups = [];

    for (final File file in entries.whereType<File>()) {
      if (!path.basename(file.path).toLowerCase().endsWith('.db')) {
        continue;
      }

      final FileStat stat = await file.stat();

      backups.add(
        DatabaseBackupInfo(
          fileName: path.basename(file.path),
          path: file.path,
          sizeBytes: stat.size,
          modifiedAt: stat.modified,
        ),
      );
    }

    backups.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return backups;
  }

  Future<File> exportDatabaseBackup(
      {required String targetDirectoryPath}) async {
    final Database db = await database;
    await _checkpointDatabaseIfPossible(db);

    final File databaseFile = File(db.path);

    if (!await databaseFile.exists()) {
      throw FileSystemException(
        'Datenbankdatei wurde nicht gefunden. Export wurde abgebrochen.',
        db.path,
      );
    }

    final Directory targetDirectory = Directory(targetDirectoryPath);

    if (!await targetDirectory.exists()) {
      throw FileSystemException(
        'Zielordner wurde nicht gefunden. Export wurde abgebrochen.',
        targetDirectoryPath,
      );
    }

    final String exportPath = path.join(
      targetDirectory.path,
      'dart_scoring_pc_export_${_backupTimestamp()}.db',
    );

    return databaseFile.copy(exportPath);
  }

  Future<void> restoreDatabaseFromBackup(
      {required String backupFilePath}) async {
    final File backupFile = File(backupFilePath);

    if (!await backupFile.exists()) {
      throw FileSystemException(
        'Backup-Datei wurde nicht gefunden. Wiederherstellung abgebrochen.',
        backupFilePath,
      );
    }

    if (!path.basename(backupFile.path).toLowerCase().endsWith('.db')) {
      throw FileSystemException(
        'Ungültige Backup-Datei. Es werden nur .db-Dateien akzeptiert.',
        backupFilePath,
      );
    }

    final File databaseFile = await getDatabaseFile();
    final Database? openDatabase = _database;

    if (openDatabase != null) {
      await _checkpointDatabaseIfPossible(openDatabase);
      await openDatabase.close();
      _database = null;
    }

    if (await databaseFile.exists()) {
      await _createDatabaseBackup(
        databasePath: databaseFile.path,
        reason: 'before_restore',
        shouldCleanup: true,
      );
    }

    await _deleteSQLiteSidecarFiles(databaseFile.path);
    await backupFile.copy(databaseFile.path);

    _database = null;
  }

  Future<Database> _openDatabase() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final Directory databaseDirectory = await _getDatabaseDirectory();

    final String fullPath = path.join(
      databaseDirectory.path,
      _databaseFileName,
    );

    await _createDatabaseBackupIfPossible(fullPath);

    return databaseFactory.openDatabase(
      fullPath,
      options: OpenDatabaseOptions(
        version: 5,
        onConfigure: (Database database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _createDatabase,
        onUpgrade: _upgradeDatabase,
      ),
    );
  }

  Future<Directory> _getDatabaseDirectory() async {
    final String basePath = Platform.environment['APPDATA'] ??
        Platform.environment['LOCALAPPDATA'] ??
        Directory.current.path;

    final Directory directory = Directory(
      path.join(basePath, _appDataFolderName),
    );

    await directory.create(recursive: true);

    return directory;
  }

  Future<File> createManualBackup({required String reason}) async {
    final Database db = await database;

    await _checkpointDatabaseIfPossible(db);

    return _createDatabaseBackup(
      databasePath: db.path,
      reason: reason,
      shouldCleanup: true,
    );
  }

  Future<void> _createDatabaseBackupIfPossible(String databasePath) async {
    try {
      await _createDatabaseBackup(
        databasePath: databasePath,
        reason: 'app_start',
        shouldCleanup: true,
      );
    } catch (_) {
      // Backup darf den App-Start niemals verhindern.
    }
  }

  Future<File> _createDatabaseBackup({
    required String databasePath,
    required String reason,
    required bool shouldCleanup,
  }) async {
    final File databaseFile = File(databasePath);

    if (!await databaseFile.exists()) {
      throw FileSystemException(
        'Datenbankdatei wurde nicht gefunden. Backup wurde abgebrochen.',
        databasePath,
      );
    }

    final Directory backupDirectory = Directory(
      path.join(
        path.dirname(databasePath),
        _backupFolderName,
      ),
    );

    await backupDirectory.create(recursive: true);

    final String timestamp = _backupTimestamp();
    final String safeReason = _safeBackupReason(reason);

    final String backupPath = path.join(
      backupDirectory.path,
      'dart_scoring_pc_${safeReason}_$timestamp.db',
    );

    final File backupFile = await databaseFile.copy(backupPath);

    if (shouldCleanup) {
      await _cleanupOldBackups(backupDirectory);
    }

    return backupFile;
  }

  Future<void> _checkpointDatabaseIfPossible(Database database) async {
    try {
      await database.rawQuery('PRAGMA wal_checkpoint(FULL)');
    } catch (_) {
      // Falls SQLite ohne WAL läuft oder der Checkpoint nicht möglich ist,
      // darf das Backup nicht daran scheitern.
    }
  }

  String _backupTimestamp() {
    final DateTime now = DateTime.now();

    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}-'
        '${now.minute.toString().padLeft(2, '0')}-'
        '${now.second.toString().padLeft(2, '0')}';
  }

  String _safeBackupReason(String reason) {
    final String normalizedReason = reason
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_\$'), '');

    if (normalizedReason.isEmpty) {
      return 'manual';
    }

    return normalizedReason;
  }

  Future<void> _deleteSQLiteSidecarFiles(String databasePath) async {
    final List<String> sidecarPaths = [
      '$databasePath-wal',
      '$databasePath-shm',
      '$databasePath-journal',
    ];

    for (final String sidecarPath in sidecarPaths) {
      final File sidecarFile = File(sidecarPath);

      if (!await sidecarFile.exists()) {
        continue;
      }

      try {
        await sidecarFile.delete();
      } catch (_) {
        // Wenn eine Neben-Datei nicht existiert oder schon weg ist,
        // darf die Wiederherstellung nicht daran scheitern.
      }
    }
  }

  Future<void> _cleanupOldBackups(Directory backupDirectory) async {
    try {
      final List<FileSystemEntity> entries =
          await backupDirectory.list().toList();

      final List<File> backups = entries.whereType<File>().where((file) {
        return path.basename(file.path).toLowerCase().endsWith('.db');
      }).toList();

      backups.sort((a, b) {
        return b.lastModifiedSync().compareTo(a.lastModifiedSync());
      });

      const int maxBackups = 20;

      if (backups.length <= maxBackups) {
        return;
      }

      for (final File oldBackup in backups.skip(maxBackups)) {
        try {
          await oldBackup.delete();
        } catch (_) {
          // Einzelnes Backup darf Cleanup nicht blockieren.
        }
      }
    } catch (_) {
      // Cleanup darf nichts blockieren.
    }
  }

  Future<void> _createDatabase(
    Database database,
    int version,
  ) async {
    await _createPlayersTable(database);
    await _createPlayerStatsTable(database);
    await _createMatchDartsTable(database);
    await _createX01DartsTable(database);
    await _createTrainingTables(database);
  }

  Future<void> _upgradeDatabase(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _createPlayerStatsTable(database);
      await _createMissingStatsRows(database);
    }

    if (oldVersion < 3) {
      await _createMatchDartsTable(database);
    }

    if (oldVersion < 4) {
      await _createX01DartsTable(database);
    }

    if (oldVersion < 5) {
      await _createTrainingTables(database);
    }
  }

  Future<void> _createPlayersTable(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS players (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createPlayerStatsTable(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS player_stats (
        player_id TEXT PRIMARY KEY,
        games_played INTEGER NOT NULL DEFAULT 0,
        wins INTEGER NOT NULL DEFAULT 0,
        losses INTEGER NOT NULL DEFAULT 0,
        legs_won INTEGER NOT NULL DEFAULT 0,
        sets_won INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (player_id) REFERENCES players (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createMatchDartsTable(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS match_darts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        player_id TEXT NOT NULL,
        game_type TEXT NOT NULL,
        turn_score INTEGER NOT NULL,
        dart_count INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (player_id) REFERENCES players (id) ON DELETE CASCADE
      )
    ''');

    await database.execute('''
      CREATE INDEX IF NOT EXISTS idx_match_darts_player_id
      ON match_darts (player_id)
    ''');

    await database.execute('''
      CREATE INDEX IF NOT EXISTS idx_match_darts_created_at
      ON match_darts (created_at)
    ''');

    await database.execute('''
      CREATE INDEX IF NOT EXISTS idx_match_darts_game_type
      ON match_darts (game_type)
    ''');
  }

  Future<void> _createX01DartsTable(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS x01_darts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        match_id TEXT NOT NULL,
        leg_number INTEGER NOT NULL,
        turn_number INTEGER NOT NULL,
        dart_index INTEGER NOT NULL,
        player_id TEXT NOT NULL,
        dart_label TEXT NOT NULL,
        dart_score INTEGER NOT NULL,
        remaining_before INTEGER NOT NULL,
        remaining_after INTEGER NOT NULL,
        is_bust INTEGER NOT NULL,
        is_checkout_dart INTEGER NOT NULL,
        checkout_score INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (player_id) REFERENCES players (id) ON DELETE CASCADE
      )
    ''');

    await database.execute('''
      CREATE INDEX IF NOT EXISTS idx_x01_darts_player_id
      ON x01_darts (player_id)
    ''');

    await database.execute('''
      CREATE INDEX IF NOT EXISTS idx_x01_darts_match_leg
      ON x01_darts (match_id, leg_number)
    ''');

    await database.execute('''
      CREATE INDEX IF NOT EXISTS idx_x01_darts_checkout
      ON x01_darts (player_id, is_checkout_dart)
    ''');
  }

  Future<void> _createTrainingTables(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS training_sessions (
        id TEXT PRIMARY KEY,
        player_id TEXT NOT NULL,
        training_type TEXT NOT NULL,
        target_label TEXT NOT NULL,
        target_segment INTEGER NOT NULL,
        target_ring TEXT NOT NULL,
        planned_darts INTEGER NOT NULL,
        darts_thrown INTEGER NOT NULL DEFAULT 0,
        started_at TEXT NOT NULL,
        finished_at TEXT,
        accuracy_score REAL NOT NULL DEFAULT 0,
        grouping_score REAL NOT NULL DEFAULT 0,
        consistency_score REAL NOT NULL DEFAULT 0,
        main_error_direction TEXT NOT NULL DEFAULT '',
        analysis_text TEXT NOT NULL DEFAULT '',
        tips_text TEXT NOT NULL DEFAULT '',
        metadata_json TEXT NOT NULL DEFAULT '{}',
        FOREIGN KEY (player_id) REFERENCES players (id) ON DELETE CASCADE
      )
    ''');

    await database.execute('''
      CREATE INDEX IF NOT EXISTS idx_training_sessions_player_id
      ON training_sessions (player_id)
    ''');

    await database.execute('''
      CREATE INDEX IF NOT EXISTS idx_training_sessions_type
      ON training_sessions (training_type)
    ''');

    await database.execute('''
      CREATE INDEX IF NOT EXISTS idx_training_sessions_started_at
      ON training_sessions (started_at)
    ''');

    await database.execute('''
      CREATE TABLE IF NOT EXISTS training_dart_placements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        dart_index INTEGER NOT NULL,
        target_label TEXT NOT NULL,
        target_segment INTEGER NOT NULL,
        target_ring TEXT NOT NULL,
        hit_segment INTEGER NOT NULL,
        hit_ring TEXT NOT NULL,
        hit_label TEXT NOT NULL,
        score INTEGER NOT NULL,
        x REAL,
        y REAL,
        distance_from_target REAL NOT NULL DEFAULT 0,
        horizontal_error REAL NOT NULL DEFAULT 0,
        vertical_error REAL NOT NULL DEFAULT 0,
        is_target_hit INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES training_sessions (id) ON DELETE CASCADE
      )
    ''');

    await database.execute('''
      CREATE INDEX IF NOT EXISTS idx_training_dart_placements_session_id
      ON training_dart_placements (session_id)
    ''');

    await database.execute('''
      CREATE INDEX IF NOT EXISTS idx_training_dart_placements_target
      ON training_dart_placements (target_label)
    ''');

    await database.execute('''
      CREATE INDEX IF NOT EXISTS idx_training_dart_placements_hit
      ON training_dart_placements (hit_label)
    ''');
  }

  Future<void> _createMissingStatsRows(Database database) async {
    final List<Map<String, Object?>> rows = await database.query('players');

    for (final row in rows) {
      final String playerId = row['id'] as String;

      await database.insert(
        'player_stats',
        {
          'player_id': playerId,
          'games_played': 0,
          'wins': 0,
          'losses': 0,
          'legs_won': 0,
          'sets_won': 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<List<Player>> getPlayers() async {
    final Database db = await database;

    final List<Map<String, Object?>> rows = await db.query(
      'players',
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows.map((row) {
      return Player(
        id: row['id'] as String,
        name: row['name'] as String,
      );
    }).toList();
  }

  Future<void> insertPlayer(Player player) async {
    final Database db = await database;

    await db.transaction((transaction) async {
      await transaction.insert(
        'players',
        {
          'id': player.id,
          'name': player.name,
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      await transaction.insert(
        'player_stats',
        {
          'player_id': player.id,
          'games_played': 0,
          'wins': 0,
          'losses': 0,
          'legs_won': 0,
          'sets_won': 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    });
  }

  Future<void> updatePlayerName({
    required String playerId,
    required String newName,
  }) async {
    final Database db = await database;

    await db.update(
      'players',
      {
        'name': newName,
      },
      where: 'id = ?',
      whereArgs: [playerId],
    );
  }

  Future<void> deletePlayer(String playerId) async {
    final Database db = await database;

    await db.transaction((transaction) async {
      await transaction.delete(
        'x01_darts',
        where: 'player_id = ?',
        whereArgs: [playerId],
      );

      await transaction.delete(
        'match_darts',
        where: 'player_id = ?',
        whereArgs: [playerId],
      );

      await transaction.delete(
        'training_sessions',
        where: 'player_id = ?',
        whereArgs: [playerId],
      );

      await transaction.delete(
        'player_stats',
        where: 'player_id = ?',
        whereArgs: [playerId],
      );

      await transaction.delete(
        'players',
        where: 'id = ?',
        whereArgs: [playerId],
      );
    });
  }

  Future<bool> playerNameExists(String name) async {
    final Database db = await database;

    final List<Map<String, Object?>> rows = await db.query(
      'players',
      where: 'LOWER(name) = ?',
      whereArgs: [name.toLowerCase()],
      limit: 1,
    );

    return rows.isNotEmpty;
  }

  Future<bool> playerNameExistsForOtherPlayer({
    required String name,
    required String currentPlayerId,
  }) async {
    final Database db = await database;

    final List<Map<String, Object?>> rows = await db.query(
      'players',
      where: 'LOWER(name) = ? AND id != ?',
      whereArgs: [
        name.toLowerCase(),
        currentPlayerId,
      ],
      limit: 1,
    );

    return rows.isNotEmpty;
  }

  Future<Map<String, int>> getPlayerStats(String playerId) async {
    final Database db = await database;

    await _ensurePlayerStatsRow(playerId);

    final List<Map<String, Object?>> rows = await db.query(
      'player_stats',
      where: 'player_id = ?',
      whereArgs: [playerId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return _emptyStats();
    }

    final Map<String, Object?> row = rows.first;

    return {
      'games_played': row['games_played'] as int,
      'wins': row['wins'] as int,
      'losses': row['losses'] as int,
      'legs_won': row['legs_won'] as int,
      'sets_won': row['sets_won'] as int,
    };
  }

  Future<Map<String, Map<String, int>>> getAllPlayerStats() async {
    final Database db = await database;

    final List<Map<String, Object?>> rows = await db.query('player_stats');

    final Map<String, Map<String, int>> result = {};

    for (final row in rows) {
      final String playerId = row['player_id'] as String;

      result[playerId] = {
        'games_played': row['games_played'] as int,
        'wins': row['wins'] as int,
        'losses': row['losses'] as int,
        'legs_won': row['legs_won'] as int,
        'sets_won': row['sets_won'] as int,
      };
    }

    return result;
  }

  Future<Map<String, num>> getPlayerDartStats(String playerId) async {
    final Database db = await database;

    final List<Map<String, Object?>> rows = await db.rawQuery(
      '''
      SELECT
        COUNT(*) AS turn_count,
        COALESCE(SUM(turn_score), 0) AS total_score,
        COALESCE(SUM(dart_count), 0) AS total_darts,
        COALESCE(MAX(turn_score), 0) AS highest_score,
        COALESCE(SUM(CASE WHEN turn_score = 180 THEN 1 ELSE 0 END), 0) AS score_180_count,
        COALESCE(SUM(CASE WHEN turn_score >= 140 THEN 1 ELSE 0 END), 0) AS score_140_plus_count,
        COALESCE(SUM(CASE WHEN turn_score >= 100 THEN 1 ELSE 0 END), 0) AS score_100_plus_count
      FROM match_darts
      WHERE player_id = ?
      AND game_type = ?
      ''',
      [
        playerId,
        'x01',
      ],
    );

    if (rows.isEmpty) {
      return _emptyDartStats();
    }

    final Map<String, Object?> row = rows.first;
    final int totalScore = (row['total_score'] as num).toInt();
    final int totalDarts = (row['total_darts'] as num).toInt();

    final double average = totalDarts == 0 ? 0 : (totalScore / totalDarts) * 3;

    final Map<String, num> formStats = await _getPlayerFormDartStats(
      playerId: playerId,
      gameType: 'x01',
      targetDarts: 100,
    );

    return {
      'turn_count': (row['turn_count'] as num).toInt(),
      'total_score': totalScore,
      'total_darts': totalDarts,
      'average': average,
      'form_average': formStats['form_average'] ?? 0,
      'form_score': formStats['form_score'] ?? 0,
      'form_darts': formStats['form_darts'] ?? 0,
      'highest_score': (row['highest_score'] as num).toInt(),
      'score_180_count': (row['score_180_count'] as num).toInt(),
      'score_140_plus_count': (row['score_140_plus_count'] as num).toInt(),
      'score_100_plus_count': (row['score_100_plus_count'] as num).toInt(),
    };
  }

  Future<Map<String, Map<String, num>>> getAllPlayerDartStats() async {
    final Database db = await database;

    final List<Map<String, Object?>> rows = await db.rawQuery(
      '''
      SELECT
        player_id,
        COUNT(*) AS turn_count,
        COALESCE(SUM(turn_score), 0) AS total_score,
        COALESCE(SUM(dart_count), 0) AS total_darts,
        COALESCE(MAX(turn_score), 0) AS highest_score,
        COALESCE(SUM(CASE WHEN turn_score = 180 THEN 1 ELSE 0 END), 0) AS score_180_count,
        COALESCE(SUM(CASE WHEN turn_score >= 140 THEN 1 ELSE 0 END), 0) AS score_140_plus_count,
        COALESCE(SUM(CASE WHEN turn_score >= 100 THEN 1 ELSE 0 END), 0) AS score_100_plus_count
      FROM match_darts
      WHERE game_type = ?
      GROUP BY player_id
      ''',
      [
        'x01',
      ],
    );

    final Map<String, Map<String, num>> formStatsByPlayerId =
        await _getAllPlayerFormDartStats(
      gameType: 'x01',
      targetDarts: 100,
    );

    final Map<String, Map<String, num>> result = {};

    for (final row in rows) {
      final String playerId = row['player_id'] as String;
      final int totalScore = (row['total_score'] as num).toInt();
      final int totalDarts = (row['total_darts'] as num).toInt();
      final double average =
          totalDarts == 0 ? 0 : (totalScore / totalDarts) * 3;
      final Map<String, num> formStats =
          formStatsByPlayerId[playerId] ?? _emptyFormDartStats();

      result[playerId] = {
        'turn_count': (row['turn_count'] as num).toInt(),
        'total_score': totalScore,
        'total_darts': totalDarts,
        'average': average,
        'form_average': formStats['form_average'] ?? 0,
        'form_score': formStats['form_score'] ?? 0,
        'form_darts': formStats['form_darts'] ?? 0,
        'highest_score': (row['highest_score'] as num).toInt(),
        'score_180_count': (row['score_180_count'] as num).toInt(),
        'score_140_plus_count': (row['score_140_plus_count'] as num).toInt(),
        'score_100_plus_count': (row['score_100_plus_count'] as num).toInt(),
      };
    }

    return result;
  }

  Future<Map<String, num>> _getPlayerFormDartStats({
    required String playerId,
    required String gameType,
    required int targetDarts,
  }) async {
    final Database db = await database;

    final List<Map<String, Object?>> rows = await db.rawQuery(
      '''
      SELECT
        turn_score,
        dart_count
      FROM match_darts
      WHERE player_id = ?
      AND game_type = ?
      ORDER BY created_at DESC, id DESC
      ''',
      [
        playerId,
        gameType,
      ],
    );

    int formScore = 0;
    int formDarts = 0;

    for (final row in rows) {
      if (formDarts >= targetDarts) {
        break;
      }

      formScore += (row['turn_score'] as num).toInt();
      formDarts += (row['dart_count'] as num).toInt();
    }

    final double formAverage = formDarts == 0 ? 0 : (formScore / formDarts) * 3;

    return {
      'form_average': formAverage,
      'form_score': formScore,
      'form_darts': formDarts,
    };
  }

  Future<Map<String, Map<String, num>>> _getAllPlayerFormDartStats({
    required String gameType,
    required int targetDarts,
  }) async {
    final Database db = await database;

    final List<Map<String, Object?>> rows = await db.rawQuery(
      '''
      SELECT
        player_id,
        turn_score,
        dart_count
      FROM match_darts
      WHERE game_type = ?
      ORDER BY player_id ASC, created_at DESC, id DESC
      ''',
      [
        gameType,
      ],
    );

    final Map<String, int> scoreByPlayerId = {};
    final Map<String, int> dartsByPlayerId = {};

    for (final row in rows) {
      final String playerId = row['player_id'] as String;
      final int currentDarts = dartsByPlayerId[playerId] ?? 0;

      if (currentDarts >= targetDarts) {
        continue;
      }

      scoreByPlayerId[playerId] =
          (scoreByPlayerId[playerId] ?? 0) + (row['turn_score'] as num).toInt();
      dartsByPlayerId[playerId] =
          currentDarts + (row['dart_count'] as num).toInt();
    }

    final Map<String, Map<String, num>> result = {};

    for (final playerId in dartsByPlayerId.keys) {
      final int formScore = scoreByPlayerId[playerId] ?? 0;
      final int formDarts = dartsByPlayerId[playerId] ?? 0;
      final double formAverage =
          formDarts == 0 ? 0 : (formScore / formDarts) * 3;

      result[playerId] = {
        'form_average': formAverage,
        'form_score': formScore,
        'form_darts': formDarts,
      };
    }

    return result;
  }

  Future<Map<String, num>> getPlayerX01AdvancedStats(String playerId) async {
    final Map<String, Map<String, num>> allStats =
        await getAllPlayerX01AdvancedStats();

    return allStats[playerId] ?? _emptyAdvancedX01Stats();
  }

  Future<Map<String, Map<String, num>>> getAllPlayerX01AdvancedStats() async {
    final Database db = await database;

    final List<Map<String, Object?>> rows = await db.rawQuery(
      '''
      SELECT
        player_id,
        match_id,
        leg_number,
        turn_number,
        dart_index,
        dart_label,
        dart_score,
        remaining_before,
        is_bust,
        is_checkout_dart,
        checkout_score
      FROM x01_darts
      ORDER BY player_id ASC, match_id ASC, leg_number ASC, turn_number ASC, dart_index ASC
      ''',
    );

    final Map<String, int> bestRtcLegDartsByPlayer =
        await _getBestRtcLegDartsByPlayer(db);

    final Map<String, Map<String, num>> result = {};
    final Map<String, int> first9DartsByLeg = {};
    final Map<String, int> totalFirst9ScoreByPlayer = {};
    final Map<String, int> totalFirst9DartsByPlayer = {};
    final Map<String, int> highestFinishByPlayer = {};
    final Map<String, int> dartsThrownByLeg = {};
    final Map<String, int> legStartScoreByLeg = {};
    final Map<String, int> bestLegDartsByPlayer = {};
    final Map<String, int> bestLeg301DartsByPlayer = {};
    final Map<String, int> bestLeg501DartsByPlayer = {};
    final Map<String, int> checkoutAttemptsByPlayer = {};
    final Map<String, int> checkoutSuccessesByPlayer = {};
    final Map<String, int> doubleAttemptsByPlayer = {};
    final Map<String, int> doubleHitsByPlayer = {};
    final Map<String, int> bustsByPlayer = {};
    final Map<String, List<String>> classicLabelsByTurn = {};
    final Map<String, String> classicPlayerByTurn = {};
    final Set<String> classicBustTurns = {};
    final Set<String> countedBustTurns = {};
    final Set<String> countedDirectFinishBustTurns = {};

    for (final row in rows) {
      final String playerId = row['player_id'] as String;
      final String matchId = row['match_id'] as String;
      final int legNumber = (row['leg_number'] as num).toInt();
      final int turnNumber = (row['turn_number'] as num).toInt();
      final String dartLabel = row['dart_label'] as String;
      final int dartScore = (row['dart_score'] as num).toInt();
      final int remainingBefore = (row['remaining_before'] as num).toInt();
      final int isBust = (row['is_bust'] as num).toInt();
      final int isCheckoutDart = (row['is_checkout_dart'] as num).toInt();
      final int checkoutScore = (row['checkout_score'] as num).toInt();

      final String legKey = '$playerId|$matchId|$legNumber';
      final int usedDartsInLeg = first9DartsByLeg[legKey] ?? 0;

      if (usedDartsInLeg < 9) {
        first9DartsByLeg[legKey] = usedDartsInLeg + 1;

        totalFirst9DartsByPlayer[playerId] =
            (totalFirst9DartsByPlayer[playerId] ?? 0) + 1;
        totalFirst9ScoreByPlayer[playerId] =
            (totalFirst9ScoreByPlayer[playerId] ?? 0) + dartScore;
      }

      final int dartsInLeg = (dartsThrownByLeg[legKey] ?? 0) + 1;
      dartsThrownByLeg[legKey] = dartsInLeg;

      final int currentLegStartScore = legStartScoreByLeg[legKey] ?? 0;

      if (remainingBefore > currentLegStartScore) {
        legStartScoreByLeg[legKey] = remainingBefore;
      }

      final String bustTurnKey = '$playerId|$matchId|$legNumber|$turnNumber';

      classicLabelsByTurn
          .putIfAbsent(bustTurnKey, () => <String>[])
          .add(dartLabel);
      classicPlayerByTurn[bustTurnKey] = playerId;

      if (isBust == 1) {
        classicBustTurns.add(bustTurnKey);
      }

      if (isBust == 1 && !countedBustTurns.contains(bustTurnKey)) {
        countedBustTurns.add(bustTurnKey);
        bustsByPlayer[playerId] = (bustsByPlayer[playerId] ?? 0) + 1;
      }

      final bool isDoubleHit = dartLabel.startsWith('D') || dartLabel == 'Bull';
      final bool isDirectDoubleFinish = _isDirectDoubleFinish(remainingBefore);

      if (isBust == 1 && isDirectDoubleFinish) {
        if (!countedDirectFinishBustTurns.contains(bustTurnKey)) {
          countedDirectFinishBustTurns.add(bustTurnKey);
          checkoutAttemptsByPlayer[playerId] =
              (checkoutAttemptsByPlayer[playerId] ?? 0) + 1;
          doubleAttemptsByPlayer[playerId] =
              (doubleAttemptsByPlayer[playerId] ?? 0) + 1;
        }
      } else {
        final bool countsAsCheckoutAttempt =
            isCheckoutDart == 1 || isDirectDoubleFinish;

        if (countsAsCheckoutAttempt) {
          checkoutAttemptsByPlayer[playerId] =
              (checkoutAttemptsByPlayer[playerId] ?? 0) + 1;
          doubleAttemptsByPlayer[playerId] =
              (doubleAttemptsByPlayer[playerId] ?? 0) + 1;
        } else if (isDoubleHit) {
          doubleAttemptsByPlayer[playerId] =
              (doubleAttemptsByPlayer[playerId] ?? 0) + 1;
        }
      }

      if (isDoubleHit) {
        doubleHitsByPlayer[playerId] = (doubleHitsByPlayer[playerId] ?? 0) + 1;
      }

      if (isCheckoutDart == 1 && checkoutScore > 0) {
        checkoutSuccessesByPlayer[playerId] =
            (checkoutSuccessesByPlayer[playerId] ?? 0) + 1;

        final int currentHighestFinish = highestFinishByPlayer[playerId] ?? 0;

        if (checkoutScore > currentHighestFinish) {
          highestFinishByPlayer[playerId] = checkoutScore;
        }

        final int currentBestLeg = bestLegDartsByPlayer[playerId] ?? 0;

        if (currentBestLeg == 0 || dartsInLeg < currentBestLeg) {
          bestLegDartsByPlayer[playerId] = dartsInLeg;
        }

        final int legStartScore = legStartScoreByLeg[legKey] ?? 0;

        if (legStartScore == 301) {
          final int currentBest301 = bestLeg301DartsByPlayer[playerId] ?? 0;

          if (currentBest301 == 0 || dartsInLeg < currentBest301) {
            bestLeg301DartsByPlayer[playerId] = dartsInLeg;
          }
        }

        if (legStartScore == 501) {
          final int currentBest501 = bestLeg501DartsByPlayer[playerId] ?? 0;

          if (currentBest501 == 0 || dartsInLeg < currentBest501) {
            bestLeg501DartsByPlayer[playerId] = dartsInLeg;
          }
        }
      }
    }

    final Map<String, int> classicCountByPlayer = {};

    for (final entry in classicLabelsByTurn.entries) {
      if (classicBustTurns.contains(entry.key)) {
        continue;
      }

      final List<String> labels = List<String>.from(entry.value)..sort();

      final bool isClassic = labels.length == 3 &&
          labels[0] == 'S1' &&
          labels[1] == 'S20' &&
          labels[2] == 'S5';

      if (!isClassic) {
        continue;
      }

      final String? playerId = classicPlayerByTurn[entry.key];

      if (playerId == null) {
        continue;
      }

      classicCountByPlayer[playerId] =
          (classicCountByPlayer[playerId] ?? 0) + 1;
    }

    final Set<String> playerIds = {
      ...totalFirst9DartsByPlayer.keys,
      ...highestFinishByPlayer.keys,
      ...bestLegDartsByPlayer.keys,
      ...bestLeg301DartsByPlayer.keys,
      ...bestLeg501DartsByPlayer.keys,
      ...bestRtcLegDartsByPlayer.keys,
      ...checkoutAttemptsByPlayer.keys,
      ...checkoutSuccessesByPlayer.keys,
      ...doubleAttemptsByPlayer.keys,
      ...doubleHitsByPlayer.keys,
      ...bustsByPlayer.keys,
      ...classicCountByPlayer.keys,
    };

    for (final playerId in playerIds) {
      final int first9Score = totalFirst9ScoreByPlayer[playerId] ?? 0;
      final int first9Darts = totalFirst9DartsByPlayer[playerId] ?? 0;
      final double first9Average =
          first9Darts == 0 ? 0 : (first9Score / first9Darts) * 3;

      final int checkoutAttempts = checkoutAttemptsByPlayer[playerId] ?? 0;
      final int checkoutSuccesses = checkoutSuccessesByPlayer[playerId] ?? 0;
      final double checkoutPercentage = checkoutAttempts == 0
          ? 0
          : (checkoutSuccesses / checkoutAttempts) * 100;

      final int doubleAttempts = doubleAttemptsByPlayer[playerId] ?? 0;
      final int doubleHits = doubleHitsByPlayer[playerId] ?? 0;
      final double doublePercentage =
          doubleAttempts == 0 ? 0 : (doubleHits / doubleAttempts) * 100;

      result[playerId] = {
        'highest_finish': highestFinishByPlayer[playerId] ?? 0,
        'first_9_average': first9Average,
        'first_9_score': first9Score,
        'first_9_darts': first9Darts,
        'best_leg_darts': bestLegDartsByPlayer[playerId] ?? 0,
        'best_leg_301_darts': bestLeg301DartsByPlayer[playerId] ?? 0,
        'best_leg_501_darts': bestLeg501DartsByPlayer[playerId] ?? 0,
        'best_leg_rtc_darts': bestRtcLegDartsByPlayer[playerId] ?? 0,
        'checkout_attempts': checkoutAttempts,
        'checkout_successes': checkoutSuccesses,
        'checkout_percentage': checkoutPercentage,
        'double_attempts': doubleAttempts,
        'double_hits': doubleHits,
        'double_percentage': doublePercentage,
        'bust_count': bustsByPlayer[playerId] ?? 0,
        'classic_count': classicCountByPlayer[playerId] ?? 0,
      };
    }

    return result;
  }

  Future<Map<String, int>> _getBestRtcLegDartsByPlayer(Database db) async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      '''
      SELECT
        player_id,
        MIN(dart_count) AS best_leg_rtc_darts
      FROM match_darts
      WHERE game_type = ?
      AND dart_count > 0
      GROUP BY player_id
      ''',
      [
        'rtc',
      ],
    );

    final Map<String, int> result = {};

    for (final row in rows) {
      final String playerId = row['player_id'] as String;
      result[playerId] = (row['best_leg_rtc_darts'] as num).toInt();
    }

    return result;
  }

  bool _isDirectDoubleFinish(int remainingScore) {
    if (remainingScore == 50) {
      return true;
    }

    if (remainingScore < 2 || remainingScore > 40) {
      return false;
    }

    return remainingScore.isEven;
  }

  Future<void> insertX01DartRecords({
    required List<Map<String, Object>> darts,
  }) async {
    if (darts.isEmpty) {
      return;
    }

    final Database db = await database;

    await db.transaction((transaction) async {
      for (final dart in darts) {
        final String playerId = dart['player_id'] as String;

        if (!playerId.startsWith('profile_')) {
          continue;
        }

        await transaction.insert(
          'x01_darts',
          {
            'match_id': dart['match_id'],
            'leg_number': dart['leg_number'],
            'turn_number': dart['turn_number'],
            'dart_index': dart['dart_index'],
            'player_id': dart['player_id'],
            'dart_label': dart['dart_label'],
            'dart_score': dart['dart_score'],
            'remaining_before': dart['remaining_before'],
            'remaining_after': dart['remaining_after'],
            'is_bust': dart['is_bust'],
            'is_checkout_dart': dart['is_checkout_dart'],
            'checkout_score': dart['checkout_score'],
            'created_at': dart['created_at'],
          },
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    });
  }

  Future<void> insertMatchDartTurn({
    required String playerId,
    required String gameType,
    required int turnScore,
    required int dartCount,
  }) async {
    if (!playerId.startsWith('profile_')) {
      return;
    }

    final Database db = await database;

    await db.insert(
      'match_darts',
      {
        'player_id': playerId,
        'game_type': gameType,
        'turn_score': turnScore,
        'dart_count': dartCount,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> insertMatchDartTurns({
    required List<Map<String, Object>> turns,
  }) async {
    if (turns.isEmpty) {
      return;
    }

    final Database db = await database;

    await db.transaction((transaction) async {
      for (final turn in turns) {
        final String playerId = turn['player_id'] as String;

        if (!playerId.startsWith('profile_')) {
          continue;
        }

        await transaction.insert(
          'match_darts',
          {
            'player_id': turn['player_id'],
            'game_type': turn['game_type'],
            'turn_score': turn['turn_score'],
            'dart_count': turn['dart_count'],
            'created_at': turn['created_at'],
          },
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    });
  }

  Future<void> saveMatchResult({
    required List<Player> players,
    required String winnerPlayerId,
    required Map<String, int> legsWonByPlayerId,
    required Map<String, int> setsWonByPlayerId,
  }) async {
    final Database db = await database;

    await db.transaction((transaction) async {
      for (final player in players) {
        if (!player.id.startsWith('profile_')) {
          continue;
        }

        await _ensurePlayerStatsRowInTransaction(
          transaction: transaction,
          playerId: player.id,
        );

        final bool isWinner = player.id == winnerPlayerId;
        final int legsWon = legsWonByPlayerId[player.id] ?? 0;
        final int setsWon = setsWonByPlayerId[player.id] ?? 0;

        await transaction.rawUpdate(
          '''
          UPDATE player_stats
          SET
            games_played = games_played + 1,
            wins = wins + ?,
            losses = losses + ?,
            legs_won = legs_won + ?,
            sets_won = sets_won + ?,
            updated_at = ?
          WHERE player_id = ?
          ''',
          [
            isWinner ? 1 : 0,
            isWinner ? 0 : 1,
            legsWon,
            setsWon,
            DateTime.now().toIso8601String(),
            player.id,
          ],
        );
      }
    });
  }

  Future<TrainingStatsSummary> getTrainingStatsSummary(String playerId) async {
    final Database db = await database;

    final List<Map<String, Object?>> rows = await db.query(
      'training_sessions',
      where: 'player_id = ?',
      whereArgs: [playerId],
      orderBy: 'finished_at DESC, started_at DESC',
    );

    return TrainingStatsSummary.fromRows(
      playerId: playerId,
      rows: rows,
    );
  }

  Future<List<TrainingSessionListItem>> getRecentTrainingSessions({
    required String playerId,
    int limit = 10,
  }) async {
    final Database db = await database;

    final List<Map<String, Object?>> rows = await db.query(
      'training_sessions',
      where: 'player_id = ?',
      whereArgs: [playerId],
      orderBy: 'finished_at DESC, started_at DESC',
      limit: limit,
    );

    return rows.map(TrainingSessionListItem.fromRow).toList();
  }

  Future<TrainingSessionDetail?> getTrainingSessionDetail({
    required String sessionId,
  }) async {
    final Database db = await database;

    final List<Map<String, Object?>> sessionRows = await db.query(
      'training_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );

    if (sessionRows.isEmpty) {
      return null;
    }

    final List<Map<String, Object?>> placementRows = await db.query(
      'training_dart_placements',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'dart_index ASC',
    );

    return TrainingSessionDetail.fromRows(
      sessionRow: sessionRows.first,
      placementRows: placementRows,
    );
  }

  Future<void> _ensurePlayerStatsRow(String playerId) async {
    final Database db = await database;

    await db.insert(
      'player_stats',
      {
        'player_id': playerId,
        'games_played': 0,
        'wins': 0,
        'losses': 0,
        'legs_won': 0,
        'sets_won': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> _ensurePlayerStatsRowInTransaction({
    required Transaction transaction,
    required String playerId,
  }) async {
    await transaction.insert(
      'player_stats',
      {
        'player_id': playerId,
        'games_played': 0,
        'wins': 0,
        'losses': 0,
        'legs_won': 0,
        'sets_won': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Map<String, int> _emptyStats() {
    return {
      'games_played': 0,
      'wins': 0,
      'losses': 0,
      'legs_won': 0,
      'sets_won': 0,
    };
  }

  Map<String, num> _emptyAdvancedX01Stats() {
    return {
      'highest_finish': 0,
      'first_9_average': 0,
      'first_9_score': 0,
      'first_9_darts': 0,
      'best_leg_darts': 0,
      'best_leg_301_darts': 0,
      'best_leg_501_darts': 0,
      'best_leg_rtc_darts': 0,
      'checkout_attempts': 0,
      'checkout_successes': 0,
      'checkout_percentage': 0,
      'double_attempts': 0,
      'double_hits': 0,
      'double_percentage': 0,
      'bust_count': 0,
      'classic_count': 0,
    };
  }

  Map<String, num> _emptyDartStats() {
    return {
      'turn_count': 0,
      'total_score': 0,
      'total_darts': 0,
      'average': 0,
      'form_average': 0,
      'form_score': 0,
      'form_darts': 0,
      'highest_score': 0,
      'score_180_count': 0,
      'score_140_plus_count': 0,
      'score_100_plus_count': 0,
    };
  }

  Map<String, num> _emptyFormDartStats() {
    return {
      'form_average': 0,
      'form_score': 0,
      'form_darts': 0,
    };
  }
}

class TrainingStatsSummary {
  final String playerId;
  final int sessionCount;
  final int totalDarts;
  final double averageDartsPerSession;
  final double averageAccuracyScore;
  final double averageGroupingScore;
  final double averageConsistencyScore;
  final double bestAccuracyScore;
  final double bestGroupingScore;
  final double bestConsistencyScore;
  final String favoriteTargetLabel;
  final String lastTargetLabel;
  final String lastMainErrorDirection;
  final String lastAnalysisText;
  final String lastTipsText;
  final DateTime? lastFinishedAt;
  final List<TrainingSessionListItem> recentSessions;

  const TrainingStatsSummary({
    required this.playerId,
    required this.sessionCount,
    required this.totalDarts,
    required this.averageDartsPerSession,
    required this.averageAccuracyScore,
    required this.averageGroupingScore,
    required this.averageConsistencyScore,
    required this.bestAccuracyScore,
    required this.bestGroupingScore,
    required this.bestConsistencyScore,
    required this.favoriteTargetLabel,
    required this.lastTargetLabel,
    required this.lastMainErrorDirection,
    required this.lastAnalysisText,
    required this.lastTipsText,
    required this.lastFinishedAt,
    required this.recentSessions,
  });

  bool get hasSessions => sessionCount > 0;

  factory TrainingStatsSummary.empty({required String playerId}) {
    return TrainingStatsSummary(
      playerId: playerId,
      sessionCount: 0,
      totalDarts: 0,
      averageDartsPerSession: 0,
      averageAccuracyScore: 0,
      averageGroupingScore: 0,
      averageConsistencyScore: 0,
      bestAccuracyScore: 0,
      bestGroupingScore: 0,
      bestConsistencyScore: 0,
      favoriteTargetLabel: '-',
      lastTargetLabel: '-',
      lastMainErrorDirection: '-',
      lastAnalysisText: '',
      lastTipsText: '',
      lastFinishedAt: null,
      recentSessions: const [],
    );
  }

  factory TrainingStatsSummary.fromRows({
    required String playerId,
    required List<Map<String, Object?>> rows,
  }) {
    if (rows.isEmpty) {
      return TrainingStatsSummary.empty(playerId: playerId);
    }

    final List<TrainingSessionListItem> sessions =
        rows.map(TrainingSessionListItem.fromRow).toList(growable: false);

    final Map<String, int> targetCounts = {};
    int totalDarts = 0;
    double totalAccuracy = 0;
    double totalGrouping = 0;
    double totalConsistency = 0;
    double bestAccuracy = 0;
    double bestGrouping = 0;
    double bestConsistency = 0;

    for (final TrainingSessionListItem session in sessions) {
      totalDarts += session.dartsThrown;
      totalAccuracy += session.accuracyScore;
      totalGrouping += session.groupingScore;
      totalConsistency += session.consistencyScore;

      if (session.accuracyScore > bestAccuracy) {
        bestAccuracy = session.accuracyScore;
      }

      if (session.groupingScore > bestGrouping) {
        bestGrouping = session.groupingScore;
      }

      if (session.consistencyScore > bestConsistency) {
        bestConsistency = session.consistencyScore;
      }

      targetCounts[session.targetLabel] =
          (targetCounts[session.targetLabel] ?? 0) + 1;
    }

    final List<MapEntry<String, int>> sortedTargets =
        targetCounts.entries.toList()
          ..sort((a, b) {
            final int countCompare = b.value.compareTo(a.value);

            if (countCompare != 0) {
              return countCompare;
            }

            return a.key.compareTo(b.key);
          });

    final TrainingSessionListItem lastSession = sessions.first;
    final int sessionCount = sessions.length;

    return TrainingStatsSummary(
      playerId: playerId,
      sessionCount: sessionCount,
      totalDarts: totalDarts,
      averageDartsPerSession: totalDarts / sessionCount,
      averageAccuracyScore: totalAccuracy / sessionCount,
      averageGroupingScore: totalGrouping / sessionCount,
      averageConsistencyScore: totalConsistency / sessionCount,
      bestAccuracyScore: bestAccuracy,
      bestGroupingScore: bestGrouping,
      bestConsistencyScore: bestConsistency,
      favoriteTargetLabel:
          sortedTargets.isEmpty ? '-' : sortedTargets.first.key,
      lastTargetLabel: lastSession.targetLabel,
      lastMainErrorDirection: lastSession.mainErrorDirection.isEmpty
          ? '-'
          : lastSession.mainErrorDirection,
      lastAnalysisText: lastSession.analysisText,
      lastTipsText: lastSession.tipsText,
      lastFinishedAt: lastSession.finishedAt,
      recentSessions: sessions.take(8).toList(growable: false),
    );
  }
}

class TrainingSessionListItem {
  final String id;
  final String trainingType;
  final String targetLabel;
  final int plannedDarts;
  final int dartsThrown;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final double accuracyScore;
  final double groupingScore;
  final double consistencyScore;
  final String mainErrorDirection;
  final String analysisText;
  final String tipsText;

  const TrainingSessionListItem({
    required this.id,
    required this.trainingType,
    required this.targetLabel,
    required this.plannedDarts,
    required this.dartsThrown,
    required this.startedAt,
    required this.finishedAt,
    required this.accuracyScore,
    required this.groupingScore,
    required this.consistencyScore,
    required this.mainErrorDirection,
    required this.analysisText,
    required this.tipsText,
  });

  factory TrainingSessionListItem.fromRow(Map<String, Object?> row) {
    return TrainingSessionListItem(
      id: (row['id'] ?? '').toString(),
      trainingType: (row['training_type'] ?? '').toString(),
      targetLabel: (row['target_label'] ?? '').toString(),
      plannedDarts: _intFromRow(row['planned_darts']),
      dartsThrown: _intFromRow(row['darts_thrown']),
      startedAt: _dateFromRow(row['started_at']),
      finishedAt: _dateFromRow(row['finished_at']),
      accuracyScore: _doubleFromRow(row['accuracy_score']),
      groupingScore: _doubleFromRow(row['grouping_score']),
      consistencyScore: _doubleFromRow(row['consistency_score']),
      mainErrorDirection: (row['main_error_direction'] ?? '').toString(),
      analysisText: (row['analysis_text'] ?? '').toString(),
      tipsText: (row['tips_text'] ?? '').toString(),
    );
  }

  String get displayTrainingType {
    if (trainingType == 'spread_analysis') {
      return 'Streuungsanalyse';
    }

    return trainingType.isEmpty ? 'Training' : trainingType;
  }

  static int _intFromRow(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _doubleFromRow(Object? value) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _dateFromRow(Object? value) {
    final String? text = value?.toString();

    if (text == null || text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }
}

class TrainingSessionDetail {
  final String id;
  final String playerId;
  final String trainingType;
  final String targetLabel;
  final int targetSegment;
  final String targetRing;
  final int plannedDarts;
  final int dartsThrown;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final double accuracyScore;
  final double groupingScore;
  final double consistencyScore;
  final String mainErrorDirection;
  final String analysisText;
  final String tipsText;
  final String metadataJson;
  final Map<String, Object?> metadata;
  final List<TrainingDartPlacementItem> placements;

  const TrainingSessionDetail({
    required this.id,
    required this.playerId,
    required this.trainingType,
    required this.targetLabel,
    required this.targetSegment,
    required this.targetRing,
    required this.plannedDarts,
    required this.dartsThrown,
    required this.startedAt,
    required this.finishedAt,
    required this.accuracyScore,
    required this.groupingScore,
    required this.consistencyScore,
    required this.mainErrorDirection,
    required this.analysisText,
    required this.tipsText,
    required this.metadataJson,
    required this.metadata,
    required this.placements,
  });

  factory TrainingSessionDetail.fromRows({
    required Map<String, Object?> sessionRow,
    required List<Map<String, Object?>> placementRows,
  }) {
    final String rawMetadata = (sessionRow['metadata_json'] ?? '{}').toString();

    return TrainingSessionDetail(
      id: (sessionRow['id'] ?? '').toString(),
      playerId: (sessionRow['player_id'] ?? '').toString(),
      trainingType: (sessionRow['training_type'] ?? '').toString(),
      targetLabel: (sessionRow['target_label'] ?? '').toString(),
      targetSegment: _intFromRow(sessionRow['target_segment']),
      targetRing: (sessionRow['target_ring'] ?? '').toString(),
      plannedDarts: _intFromRow(sessionRow['planned_darts']),
      dartsThrown: _intFromRow(sessionRow['darts_thrown']),
      startedAt: _dateFromRow(sessionRow['started_at']),
      finishedAt: _dateFromRow(sessionRow['finished_at']),
      accuracyScore: _doubleFromRow(sessionRow['accuracy_score']),
      groupingScore: _doubleFromRow(sessionRow['grouping_score']),
      consistencyScore: _doubleFromRow(sessionRow['consistency_score']),
      mainErrorDirection: (sessionRow['main_error_direction'] ?? '').toString(),
      analysisText: (sessionRow['analysis_text'] ?? '').toString(),
      tipsText: (sessionRow['tips_text'] ?? '').toString(),
      metadataJson: rawMetadata,
      metadata: _decodeMetadata(rawMetadata),
      placements: placementRows
          .map(TrainingDartPlacementItem.fromRow)
          .toList(growable: false),
    );
  }

  String get displayTrainingType {
    if (trainingType == 'spread_analysis') {
      return 'Streuungsanalyse';
    }

    return trainingType.isEmpty ? 'Training' : trainingType;
  }

  String get patternHeadline {
    final String value = _stringFromMetadata('pattern_headline');
    return value.isEmpty ? 'Kein Muster gespeichert.' : value;
  }

  String get nextDrillText {
    final String value = _stringFromMetadata('next_drill_text');
    return value.isEmpty ? 'Keine nächste Übung gespeichert.' : value;
  }

  int get targetHitCount => _intFromMetadata('target_hit_count');
  int get segmentHitCount => _intFromMetadata('segment_hit_count');
  int get ringHitCount => _intFromMetadata('ring_hit_count');
  int get leftMisses => _intFromMetadata('left_misses');
  int get rightMisses => _intFromMetadata('right_misses');
  int get highMisses => _intFromMetadata('high_misses');
  int get lowMisses => _intFromMetadata('low_misses');

  double get targetRate => _doubleFromMetadata('target_rate');
  double get segmentRate => _doubleFromMetadata('segment_rate');
  double get ringRate => _doubleFromMetadata('ring_rate');
  double get averageDistance => _doubleFromMetadata('average_distance');
  double get averageGroupingDistance =>
      _doubleFromMetadata('average_grouping_distance');
  double get averageHorizontalError =>
      _doubleFromMetadata('average_horizontal_error');
  double get averageVerticalError =>
      _doubleFromMetadata('average_vertical_error');

  String _stringFromMetadata(String key) {
    return metadata[key]?.toString() ?? '';
  }

  int _intFromMetadata(String key) {
    final Object? value = metadata[key];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _doubleFromMetadata(String key) {
    final Object? value = metadata[key];

    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Map<String, Object?> _decodeMetadata(String rawMetadata) {
    try {
      final Object? decoded = jsonDecode(rawMetadata);

      if (decoded is Map<String, Object?>) {
        return decoded;
      }

      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {
      // Kaputte oder alte Metadaten dürfen die Statistikseite nicht sprengen.
    }

    return <String, Object?>{};
  }

  static int _intFromRow(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _doubleFromRow(Object? value) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _dateFromRow(Object? value) {
    final String? text = value?.toString();

    if (text == null || text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }
}

class TrainingDartPlacementItem {
  final int id;
  final String sessionId;
  final int dartIndex;
  final String targetLabel;
  final int targetSegment;
  final String targetRing;
  final int hitSegment;
  final String hitRing;
  final String hitLabel;
  final int score;
  final double normalizedX;
  final double normalizedY;
  final double distanceFromTarget;
  final double horizontalError;
  final double verticalError;
  final bool isTargetHit;
  final DateTime? createdAt;

  const TrainingDartPlacementItem({
    required this.id,
    required this.sessionId,
    required this.dartIndex,
    required this.targetLabel,
    required this.targetSegment,
    required this.targetRing,
    required this.hitSegment,
    required this.hitRing,
    required this.hitLabel,
    required this.score,
    required this.normalizedX,
    required this.normalizedY,
    required this.distanceFromTarget,
    required this.horizontalError,
    required this.verticalError,
    required this.isTargetHit,
    required this.createdAt,
  });

  factory TrainingDartPlacementItem.fromRow(Map<String, Object?> row) {
    return TrainingDartPlacementItem(
      id: _intFromRow(row['id']),
      sessionId: (row['session_id'] ?? '').toString(),
      dartIndex: _intFromRow(row['dart_index']),
      targetLabel: (row['target_label'] ?? '').toString(),
      targetSegment: _intFromRow(row['target_segment']),
      targetRing: (row['target_ring'] ?? '').toString(),
      hitSegment: _intFromRow(row['hit_segment']),
      hitRing: (row['hit_ring'] ?? '').toString(),
      hitLabel: (row['hit_label'] ?? '').toString(),
      score: _intFromRow(row['score']),
      normalizedX: _doubleFromRow(row['x']),
      normalizedY: _doubleFromRow(row['y']),
      distanceFromTarget: _doubleFromRow(row['distance_from_target']),
      horizontalError: _doubleFromRow(row['horizontal_error']),
      verticalError: _doubleFromRow(row['vertical_error']),
      isTargetHit: _intFromRow(row['is_target_hit']) == 1,
      createdAt: _dateFromRow(row['created_at']),
    );
  }

  static int _intFromRow(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _doubleFromRow(Object? value) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _dateFromRow(Object? value) {
    final String? text = value?.toString();

    if (text == null || text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }
}

class DatabaseBackupInfo {
  final String fileName;
  final String path;
  final int sizeBytes;
  final DateTime modifiedAt;

  const DatabaseBackupInfo({
    required this.fileName,
    required this.path,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  String get displaySize {
    if (sizeBytes >= 1024 * 1024) {
      final double megabytes = sizeBytes / (1024 * 1024);
      return '${megabytes.toStringAsFixed(1)} MB';
    }

    if (sizeBytes >= 1024) {
      final double kilobytes = sizeBytes / 1024;
      return '${kilobytes.toStringAsFixed(1)} KB';
    }

    return '$sizeBytes B';
  }

  String get displayDate {
    return '${modifiedAt.day.toString().padLeft(2, '0')}.${modifiedAt.month.toString().padLeft(2, '0')}.${modifiedAt.year.toString().padLeft(4, '0')} '
        '${modifiedAt.hour.toString().padLeft(2, '0')}:${modifiedAt.minute.toString().padLeft(2, '0')}:${modifiedAt.second.toString().padLeft(2, '0')}';
  }
}
