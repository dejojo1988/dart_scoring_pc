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
        version: 4,
        onConfigure: (Database database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _createDatabase,
        onUpgrade: _upgradeDatabase,
      ),
    );
  }

  Future<Directory> _getDatabaseDirectory() async {
    final String basePath =
        Platform.environment['APPDATA'] ??
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

  Future<void> _cleanupOldBackups(Directory backupDirectory) async {
    try {
      final List<FileSystemEntity> entries = await backupDirectory.list().toList();

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

    return {
      'turn_count': (row['turn_count'] as num).toInt(),
      'total_score': totalScore,
      'total_darts': totalDarts,
      'average': average,
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

    final Map<String, Map<String, num>> result = {};

    for (final row in rows) {
      final String playerId = row['player_id'] as String;
      final int totalScore = (row['total_score'] as num).toInt();
      final int totalDarts = (row['total_darts'] as num).toInt();
      final double average = totalDarts == 0 ? 0 : (totalScore / totalDarts) * 3;

      result[playerId] = {
        'turn_count': (row['turn_count'] as num).toInt(),
        'total_score': totalScore,
        'total_darts': totalDarts,
        'average': average,
        'highest_score': (row['highest_score'] as num).toInt(),
        'score_180_count': (row['score_180_count'] as num).toInt(),
        'score_140_plus_count': (row['score_140_plus_count'] as num).toInt(),
        'score_100_plus_count': (row['score_100_plus_count'] as num).toInt(),
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

    final Map<String, Map<String, num>> result = {};
    final Map<String, int> first9DartsByLeg = {};
    final Map<String, int> totalFirst9ScoreByPlayer = {};
    final Map<String, int> totalFirst9DartsByPlayer = {};
    final Map<String, int> highestFinishByPlayer = {};
    final Map<String, int> dartsThrownByLeg = {};
    final Map<String, int> bestLegDartsByPlayer = {};
    final Map<String, int> checkoutAttemptsByPlayer = {};
    final Map<String, int> checkoutSuccessesByPlayer = {};
    final Map<String, int> doubleAttemptsByPlayer = {};
    final Map<String, int> doubleHitsByPlayer = {};
    final Map<String, int> bustsByPlayer = {};
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

      final String bustTurnKey = '$playerId|$matchId|$legNumber|$turnNumber';

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
      }
    }

    final Set<String> playerIds = {
      ...totalFirst9DartsByPlayer.keys,
      ...highestFinishByPlayer.keys,
      ...bestLegDartsByPlayer.keys,
      ...checkoutAttemptsByPlayer.keys,
      ...checkoutSuccessesByPlayer.keys,
      ...doubleAttemptsByPlayer.keys,
      ...doubleHitsByPlayer.keys,
      ...bustsByPlayer.keys,
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
        'checkout_attempts': checkoutAttempts,
        'checkout_successes': checkoutSuccesses,
        'checkout_percentage': checkoutPercentage,
        'double_attempts': doubleAttempts,
        'double_hits': doubleHits,
        'double_percentage': doublePercentage,
        'bust_count': bustsByPlayer[playerId] ?? 0,
      };
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
      'checkout_attempts': 0,
      'checkout_successes': 0,
      'checkout_percentage': 0,
      'double_attempts': 0,
      'double_hits': 0,
      'double_percentage': 0,
      'bust_count': 0,
    };
  }

  Map<String, num> _emptyDartStats() {
    return {
      'turn_count': 0,
      'total_score': 0,
      'total_darts': 0,
      'average': 0,
      'highest_score': 0,
      'score_180_count': 0,
      'score_140_plus_count': 0,
      'score_100_plus_count': 0,
    };
  }
}