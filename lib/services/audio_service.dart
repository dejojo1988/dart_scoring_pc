import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

enum AudioEventType {
  dartHit,
  dartMiss,
  gameStart,
  playerTurn,
  turnScore,
  bust,
  legWin,
  setWin,
  matchWin,
  undo,
}

enum _AudioPlaybackSource {
  none,
  customFile,
  defaultAsset,
}

extension AudioEventTypeMeta on AudioEventType {
  String get key {
    switch (this) {
      case AudioEventType.dartHit:
        return 'dart_hit';
      case AudioEventType.dartMiss:
        return 'dart_miss';
      case AudioEventType.gameStart:
        return 'game_start';
      case AudioEventType.playerTurn:
        return 'player_turn';
      case AudioEventType.turnScore:
        return 'turn_score';
      case AudioEventType.bust:
        return 'bust';
      case AudioEventType.legWin:
        return 'leg_win';
      case AudioEventType.setWin:
        return 'set_win';
      case AudioEventType.matchWin:
        return 'match_win';
      case AudioEventType.undo:
        return 'undo';
    }
  }

  String get title {
    switch (this) {
      case AudioEventType.dartHit:
        return 'Dart trifft Board';
      case AudioEventType.dartMiss:
        return 'Dart verfehlt / Miss';
      case AudioEventType.gameStart:
        return 'Spiel beginnt';
      case AudioEventType.playerTurn:
        return 'Spieler ist dran';
      case AudioEventType.turnScore:
        return '3-Dart-Summe';
      case AudioEventType.bust:
        return 'Überworfen / Bust';
      case AudioEventType.legWin:
        return 'Leg gewonnen';
      case AudioEventType.setWin:
        return 'Set gewonnen';
      case AudioEventType.matchWin:
        return 'Match gewonnen';
      case AudioEventType.undo:
        return 'Undo';
    }
  }

  String get description {
    switch (this) {
      case AudioEventType.dartHit:
        return 'Kurzer Treffer-Sound direkt beim eingegebenen oder simulierten Dart.';
      case AudioEventType.dartMiss:
        return 'Kurzer Miss-Sound, wenn ein Spieler oder Bot MISS wirft.';
      case AudioEventType.gameStart:
        return 'Standard: assets/audio/default_pack/gameon.mp3. Optional überschreibbar.';
      case AudioEventType.playerTurn:
        return 'Sound bevor der Ansager den nächsten Spieler nennt.';
      case AudioEventType.turnScore:
        return 'Optionaler Sound vor der 3-Dart-Summe. Standard-Zahlen kommen aus assets/audio/default_pack/0.wav bis 180.wav.';
      case AudioEventType.bust:
        return 'Jingle bei Überwurf.';
      case AudioEventType.legWin:
        return 'Standard: assets/audio/default_pack/gewonnen.mp3. Optional überschreibbar.';
      case AudioEventType.setWin:
        return 'Standard: assets/audio/default_pack/gewonnen.mp3. Optional überschreibbar.';
      case AudioEventType.matchWin:
        return 'Standard: assets/audio/default_pack/gewonnen.mp3. Optional überschreibbar.';
      case AudioEventType.undo:
        return 'Kurzer Sound beim Zurücknehmen.';
    }
  }
}

class AudioSettings {
  final bool audioEnabled;
  final bool voiceEnabled;
  final double volume;
  final Map<String, String> filePathsByEventKey;

  const AudioSettings({
    required this.audioEnabled,
    required this.voiceEnabled,
    required this.volume,
    required this.filePathsByEventKey,
  });

  factory AudioSettings.defaults() {
    return const AudioSettings(
      audioEnabled: true,
      voiceEnabled: true,
      volume: 0.85,
      filePathsByEventKey: {},
    );
  }

  AudioSettings copyWith({
    bool? audioEnabled,
    bool? voiceEnabled,
    double? volume,
    Map<String, String>? filePathsByEventKey,
  }) {
    return AudioSettings(
      audioEnabled: audioEnabled ?? this.audioEnabled,
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      volume: volume ?? this.volume,
      filePathsByEventKey: filePathsByEventKey ?? this.filePathsByEventKey,
    );
  }

  Map<String, Object> toJson() {
    return {
      'audioEnabled': audioEnabled,
      'voiceEnabled': voiceEnabled,
      'volume': volume,
      'filePathsByEventKey': filePathsByEventKey,
    };
  }

  factory AudioSettings.fromJson(Map<String, Object?> json) {
    final Object? rawMap = json['filePathsByEventKey'];
    final Map<String, String> paths = {};

    if (rawMap is Map) {
      for (final entry in rawMap.entries) {
        final Object? key = entry.key;
        final Object? value = entry.value;

        if (key is String && value is String && value.trim().isNotEmpty) {
          paths[key] = value;
        }
      }
    }

    final Object? rawVolume = json['volume'];
    double volume = 0.85;

    if (rawVolume is num) {
      volume = rawVolume.toDouble().clamp(0.0, 1.0).toDouble();
    }

    return AudioSettings(
      audioEnabled: json['audioEnabled'] is bool
          ? json['audioEnabled'] as bool
          : true,
      voiceEnabled: json['voiceEnabled'] is bool
          ? json['voiceEnabled'] as bool
          : true,
      volume: volume,
      filePathsByEventKey: paths,
    );
  }
}

class AudioService {
  AudioService._();

  static final AudioService instance = AudioService._();

  static const String _defaultPackAssetBasePath = 'audio/default_pack';

  AudioSettings _settings = AudioSettings.defaults();
  bool _loaded = false;
  Future<void> _speechQueue = Future<void>.value();
  Future<void> _voicePackQueue = Future<void>.value();
  final Map<String, Duration> _wavDurationCache = <String, Duration>{};

  AudioSettings get settings => _settings;

  Future<void> load() async {
    if (_loaded) {
      return;
    }

    final File file = await _settingsFile();

    if (!await file.exists()) {
      _settings = AudioSettings.defaults();
      _loaded = true;
      await save();
      return;
    }

    try {
      final String content = await file.readAsString();
      final Object? decoded = jsonDecode(content);

      if (decoded is Map<String, Object?>) {
        _settings = AudioSettings.fromJson(decoded);
      } else {
        _settings = AudioSettings.defaults();
      }
    } catch (_) {
      _settings = AudioSettings.defaults();
    }

    _loaded = true;
  }

  Future<void> save() async {
    final File file = await _settingsFile();
    await file.parent.create(recursive: true);

    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(
      encoder.convert(_settings.toJson()),
      flush: true,
    );

    _loaded = true;
  }

  Future<void> updateSettings(AudioSettings settings) async {
    _settings = settings;
    await save();
  }

  Future<void> setAudioFile({
    required AudioEventType eventType,
    required String filePath,
  }) async {
    await load();

    final Map<String, String> nextPaths =
        Map<String, String>.from(_settings.filePathsByEventKey);

    nextPaths[eventType.key] = filePath;

    await updateSettings(
      _settings.copyWith(filePathsByEventKey: nextPaths),
    );
  }

  Future<void> clearAudioFile(AudioEventType eventType) async {
    await load();

    final Map<String, String> nextPaths =
        Map<String, String>.from(_settings.filePathsByEventKey);

    nextPaths.remove(eventType.key);

    await updateSettings(
      _settings.copyWith(filePathsByEventKey: nextPaths),
    );
  }

  String? filePathFor(AudioEventType eventType) {
    final String? path = _settings.filePathsByEventKey[eventType.key];

    if (path == null || path.trim().isEmpty) {
      return null;
    }

    return path;
  }

  Future<void> playEvent(
    AudioEventType eventType, {
    bool waitForCompletion = false,
  }) async {
    await _playEventSound(
      eventType,
      waitForCompletion: waitForCompletion,
    );
  }

  Future<void> testEvent(AudioEventType eventType) async {
    if (eventType == AudioEventType.turnScore) {
      await announceTurnScore(
        playerName: 'Spieler 1',
        turnScore: 60,
      );
      return;
    }

    await playEvent(
      eventType,
      waitForCompletion: true,
    );
  }

  Future<void> speak(String text) async {
    await load();

    final String cleanedText = text.trim();

    if (cleanedText.isEmpty) {
      return;
    }

    if (!_settings.audioEnabled || !_settings.voiceEnabled) {
      return;
    }

    if (!Platform.isWindows) {
      return;
    }

    _speechQueue = _speechQueue.then((_) => _speakNow(cleanedText));
    await _speechQueue;
  }

  Future<void> playDartHit() async {
    await playEvent(AudioEventType.dartHit);
  }

  Future<void> playDartMiss() async {
    await playEvent(AudioEventType.dartMiss);
  }

  Future<void> announceGameStart({
    required String startingPlayerName,
    required int startScore,
  }) async {
    await _playEventSound(
      AudioEventType.gameStart,
      waitForCompletion: true,
    );

    final bool playedPlayerAsset =
        await _playDefaultPlayerTurnAsset(startingPlayerName);

    if (playedPlayerAsset) {
      return;
    }

    await speak(
      'Spiel beginnt. $startingPlayerName startet mit $startScore Punkten.',
    );
  }

  Future<void> announcePlayerTurn({
    required String playerName,
    required int remainingScore,
  }) async {
    final bool playedPlayerAsset = await _playDefaultPlayerTurnAsset(playerName);

    if (!playedPlayerAsset) {
      await playEvent(
        AudioEventType.playerTurn,
        waitForCompletion: true,
      );

      await speak(
        '$playerName ist dran und braucht $remainingScore Punkte.',
      );
    }
  }


  Future<void> announceCheckoutRequirement({
    required String playerName,
    required int remainingScore,
  }) async {
    await load();

    if (!_settings.audioEnabled) {
      return;
    }

    if (remainingScore <= 0 || remainingScore > 180) {
      return;
    }

    final int safeRemainingScore = remainingScore.clamp(0, 180).toInt();

    final bool playedPlayerAsset = await _playDefaultPlayerTurnAsset(playerName);

    if (!playedPlayerAsset) {
      await speak(playerName);
    }

    final bool playedRequireAsset = await _playDefaultYouRequireAsset();
    final bool playedNumberAsset = await _playDefaultNumberAsset(safeRemainingScore);

    if (playedPlayerAsset || playedRequireAsset || playedNumberAsset) {
      return;
    }

    await speak('$playerName benötigt $safeRemainingScore Punkte.');
  }

  Future<bool> _playDefaultPlayerTurnAsset(String playerName) async {
    await load();

    if (!_settings.audioEnabled) {
      return false;
    }

    final RegExp playerRegex = RegExp(
      r'Spieler\s+(\d+)',
      caseSensitive: false,
    );

    final RegExpMatch? match = playerRegex.firstMatch(playerName);

    if (match == null) {
      return false;
    }

    final int? playerNumber = int.tryParse(match.group(1) ?? '');

    if (playerNumber == null || playerNumber < 1 || playerNumber > 8) {
      return false;
    }

    return _playAssetFile(
      '$_defaultPackAssetBasePath/player-$playerNumber.mp3',
      waitForCompletion: true,
    );
  }

  Future<void> announceTurnScore({
    required String playerName,
    required int turnScore,
  }) async {
    await playEvent(
      AudioEventType.turnScore,
      waitForCompletion: true,
    );

    final bool playedNumber = await _playDefaultNumberAsset(turnScore);

    if (playedNumber) {
      return;
    }

    await speak(
      '$playerName wirft $turnScore Punkte.',
    );
  }

  Future<void> announceBust({
    required String playerName,
  }) async {
    await playEvent(
      AudioEventType.bust,
      waitForCompletion: true,
    );

    await speak(
      '$playerName hat sich überworfen. Bust.',
    );
  }

  Future<void> announceLegWin({
    required String playerName,
  }) async {
    final _AudioPlaybackSource source = await _playEventSound(
      AudioEventType.legWin,
      waitForCompletion: true,
    );

    if (source == _AudioPlaybackSource.defaultAsset) {
      return;
    }

    await speak(
      '$playerName gewinnt das Leg.',
    );
  }

  Future<void> announceSetWin({
    required String playerName,
  }) async {
    final _AudioPlaybackSource source = await _playEventSound(
      AudioEventType.setWin,
      waitForCompletion: true,
    );

    if (source == _AudioPlaybackSource.defaultAsset) {
      return;
    }

    await speak(
      '$playerName gewinnt das Set.',
    );
  }

  Future<void> announceMatchWin({
    required String playerName,
  }) async {
    final _AudioPlaybackSource source = await _playEventSound(
      AudioEventType.matchWin,
      waitForCompletion: true,
    );

    if (source == _AudioPlaybackSource.defaultAsset) {
      return;
    }

    await speak(
      '$playerName gewinnt das Match.',
    );
  }

  Future<void> announceUndo() async {
    await playEvent(AudioEventType.undo);
  }

  Future<_AudioPlaybackSource> _playEventSound(
    AudioEventType eventType, {
    bool waitForCompletion = false,
  }) async {
    await load();

    if (!_settings.audioEnabled) {
      return _AudioPlaybackSource.none;
    }

    final String? customFilePath = filePathFor(eventType);

    if (customFilePath != null) {
      final File customFile = File(customFilePath);

      if (await customFile.exists()) {
        final bool playedCustom = await _playDeviceFile(
          customFilePath,
          waitForCompletion: waitForCompletion,
        );

        if (playedCustom) {
          return _AudioPlaybackSource.customFile;
        }
      }
    }

    final String? defaultAssetPath = _defaultAssetPathForEvent(eventType);

    if (defaultAssetPath == null) {
      return _AudioPlaybackSource.none;
    }

    final bool playedDefault = await _playAssetFile(
      defaultAssetPath,
      waitForCompletion: waitForCompletion,
    );

    return playedDefault
        ? _AudioPlaybackSource.defaultAsset
        : _AudioPlaybackSource.none;
  }

  String? _defaultAssetPathForEvent(AudioEventType eventType) {
    switch (eventType) {
      case AudioEventType.dartHit:
        return '$_defaultPackAssetBasePath/dart_hit.mp3';

      case AudioEventType.dartMiss:
        return '$_defaultPackAssetBasePath/miss.mp3';

      case AudioEventType.gameStart:
        return '$_defaultPackAssetBasePath/gameon.mp3';

      case AudioEventType.bust:
        return '$_defaultPackAssetBasePath/you-bust.mp3';

      case AudioEventType.legWin:
      case AudioEventType.setWin:
        return '$_defaultPackAssetBasePath/gewonnen.mp3';

      case AudioEventType.matchWin:
        return '$_defaultPackAssetBasePath/win.mp3';

      case AudioEventType.undo:
        return null;

      case AudioEventType.playerTurn:
      case AudioEventType.turnScore:
        return null;
    }
  }

  Future<bool> _playDefaultYouRequireAsset() async {
    await load();

    if (!_settings.audioEnabled) {
      return false;
    }

    bool playedRequire = false;

    _voicePackQueue = _voicePackQueue.then((_) async {
      playedRequire = await _playAssetFile(
        '$_defaultPackAssetBasePath/you-require.mp3',
        waitForCompletion: true,
      );
    });

    await _voicePackQueue;

    return playedRequire;
  }

  Future<bool> _playDefaultNumberAsset(int number) async {
    await load();

    if (!_settings.audioEnabled) {
      return false;
    }

    if (number < 0 || number > 180) {
      return false;
    }

    final int safeNumber = number.round();
    bool playedNumber = false;

    _voicePackQueue = _voicePackQueue.then((_) async {
      playedNumber = await _playAssetFile(
        '$_defaultPackAssetBasePath/$safeNumber.wav',
        waitForCompletion: true,
      );
    });

    await _voicePackQueue;

    return playedNumber;
  }

  Future<bool> _playDeviceFile(
    String filePath, {
    required bool waitForCompletion,
  }) async {
    final AudioPlayer player = AudioPlayer();

    try {
      await player.setReleaseMode(ReleaseMode.stop);
      await player.play(
        DeviceFileSource(filePath),
        volume: _settings.volume,
      );

      final Duration fallbackDuration =
          await _playbackDurationForDeviceFile(filePath);

      if (waitForCompletion) {
        await _waitForPlayerCompletion(
          player: player,
          fallbackDuration: fallbackDuration,
        );
        await player.dispose();
      } else {
        unawaited(
          _disposePlayerAfterDelay(
            player,
            fallbackDuration + const Duration(seconds: 3),
          ),
        );
      }

      return true;
    } catch (_) {
      await player.dispose();
      return false;
    }
  }

  Future<bool> _playAssetFile(
    String assetPath, {
    required bool waitForCompletion,
  }) async {
    final AudioPlayer player = AudioPlayer();

    try {
      await player.setReleaseMode(ReleaseMode.stop);
      await player.play(
        AssetSource(assetPath),
        volume: _settings.volume,
      );

      final Duration fallbackDuration = await _playbackDurationForAsset(assetPath);

      if (waitForCompletion) {
        await _waitForPlayerCompletion(
          player: player,
          fallbackDuration: fallbackDuration,
        );
        await player.dispose();
      } else {
        unawaited(
          _disposePlayerAfterDelay(
            player,
            fallbackDuration + const Duration(seconds: 3),
          ),
        );
      }

      return true;
    } catch (_) {
      await player.dispose();
      return false;
    }
  }

  Future<Duration> _playbackDurationForAsset(String assetPath) async {
    final String normalizedPath = assetPath.toLowerCase();

    if (normalizedPath.endsWith('.wav')) {
      final Duration? wavDuration = await _readAssetWavDuration(assetPath);

      if (wavDuration != null) {
        return wavDuration + const Duration(milliseconds: 220);
      }
    }

    if (normalizedPath.endsWith('/gameon.mp3')) {
      return const Duration(milliseconds: 2600);
    }

    if (normalizedPath.endsWith('/gewonnen.mp3')) {
      return const Duration(milliseconds: 2800);
    }

    if (normalizedPath.endsWith('/win.mp3')) {
      return const Duration(milliseconds: 4200);
    }

    if (normalizedPath.endsWith('/you-require.mp3')) {
      return const Duration(milliseconds: 1800);
    }

    if (normalizedPath.endsWith('/you-bust.mp3')) {
      return const Duration(milliseconds: 2400);
    }

    if (normalizedPath.endsWith('/dart_hit.mp3')) {
      return const Duration(milliseconds: 900);
    }

    if (normalizedPath.endsWith('/miss.mp3')) {
      return const Duration(milliseconds: 1100);
    }

    if (RegExp(r'/player-\d+\.mp3$').hasMatch(normalizedPath)) {
      return const Duration(milliseconds: 2400);
    }

    return const Duration(milliseconds: 1800);
  }

  Future<Duration> _playbackDurationForDeviceFile(String filePath) async {
    final String normalizedPath = filePath.toLowerCase();

    if (normalizedPath.endsWith('.wav')) {
      final Duration? wavDuration = await _readDeviceWavDuration(filePath);

      if (wavDuration != null) {
        return wavDuration + const Duration(milliseconds: 180);
      }
    }

    if (normalizedPath.contains('hit') ||
        normalizedPath.contains('dart') ||
        normalizedPath.contains('treffer')) {
      return const Duration(milliseconds: 350);
    }

    return const Duration(milliseconds: 1500);
  }

  Future<Duration?> _readAssetWavDuration(String assetPath) async {
    final String cacheKey = 'asset:$assetPath';
    final Duration? cachedDuration = _wavDurationCache[cacheKey];

    if (cachedDuration != null) {
      return cachedDuration;
    }

    try {
      ByteData byteData;

      try {
        byteData = await rootBundle.load(assetPath);
      } catch (_) {
        byteData = await rootBundle.load('assets/$assetPath');
      }

      final Duration? duration = _parseWavDuration(byteData);

      if (duration != null) {
        _wavDurationCache[cacheKey] = duration;
      }

      return duration;
    } catch (_) {
      return null;
    }
  }

  Future<Duration?> _readDeviceWavDuration(String filePath) async {
    final String cacheKey = 'file:$filePath';
    final Duration? cachedDuration = _wavDurationCache[cacheKey];

    if (cachedDuration != null) {
      return cachedDuration;
    }

    try {
      final Uint8List bytes = await File(filePath).readAsBytes();
      final ByteData byteData = ByteData.sublistView(bytes);
      final Duration? duration = _parseWavDuration(byteData);

      if (duration != null) {
        _wavDurationCache[cacheKey] = duration;
      }

      return duration;
    } catch (_) {
      return null;
    }
  }

  Duration? _parseWavDuration(ByteData byteData) {
    if (byteData.lengthInBytes < 44) {
      return null;
    }

    final String riff = String.fromCharCodes([
      byteData.getUint8(0),
      byteData.getUint8(1),
      byteData.getUint8(2),
      byteData.getUint8(3),
    ]);

    final String wave = String.fromCharCodes([
      byteData.getUint8(8),
      byteData.getUint8(9),
      byteData.getUint8(10),
      byteData.getUint8(11),
    ]);

    if (riff != 'RIFF' || wave != 'WAVE') {
      return null;
    }

    int offset = 12;
    int? byteRate;
    int? dataSize;

    while (offset + 8 <= byteData.lengthInBytes) {
      final String chunkId = String.fromCharCodes([
        byteData.getUint8(offset),
        byteData.getUint8(offset + 1),
        byteData.getUint8(offset + 2),
        byteData.getUint8(offset + 3),
      ]);

      final int chunkSize = byteData.getUint32(
        offset + 4,
        Endian.little,
      );

      final int chunkDataOffset = offset + 8;

      if (chunkId == 'fmt ' && chunkDataOffset + 16 <= byteData.lengthInBytes) {
        byteRate = byteData.getUint32(
          chunkDataOffset + 8,
          Endian.little,
        );
      } else if (chunkId == 'data') {
        dataSize = chunkSize;
      }

      offset = chunkDataOffset + chunkSize;

      if (chunkSize.isOdd) {
        offset += 1;
      }

      if (byteRate != null && dataSize != null) {
        break;
      }
    }

    if (byteRate == null || byteRate <= 0 || dataSize == null || dataSize <= 0) {
      return null;
    }

    final double seconds = dataSize / byteRate;
    final int milliseconds = (seconds * 1000).round();

    if (milliseconds <= 0) {
      return null;
    }

    return Duration(milliseconds: milliseconds);
  }

  Future<void> _waitForPlayerCompletion({
    required AudioPlayer player,
    required Duration fallbackDuration,
  }) async {
    final Duration safeTimeout = fallbackDuration + const Duration(seconds: 3);

    try {
      await player.onPlayerComplete.first.timeout(safeTimeout);
    } catch (_) {
      await Future<void>.delayed(fallbackDuration);
    }
  }

  Future<void> _disposePlayerAfterDelay(
    AudioPlayer player,
    Duration delay,
  ) async {
    await Future<void>.delayed(delay);

    try {
      await player.dispose();
    } catch (_) {
      // Dispose darf keinen Match-Ablauf stören.
    }
  }

  Future<void> _speakNow(String text) async {
    final String escaped = text.replaceAll("'", "''");
    final int volume = (_settings.volume * 100).round().clamp(0, 100).toInt();

    final String command = '''
Add-Type -AssemblyName System.Speech;
\$speaker = New-Object System.Speech.Synthesis.SpeechSynthesizer;
\$speaker.Volume = $volume;
\$speaker.Rate = 0;
\$speaker.Speak('$escaped');
\$speaker.Dispose();
''';

    try {
      await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          command,
        ],
        runInShell: false,
      );
    } catch (_) {
      // Audio darf niemals das Match blockieren.
    }
  }

  Future<File> _settingsFile() async {
    final String basePath =
        Platform.environment['APPDATA'] ??
        Platform.environment['LOCALAPPDATA'] ??
        Directory.current.path;

    return File(
      '$basePath${Platform.pathSeparator}DartScoringPC${Platform.pathSeparator}audio_settings.json',
    );
  }
}