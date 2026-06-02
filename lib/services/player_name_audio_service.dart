import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

import '../data/app_database.dart';
import '../models/player.dart';

class PlayerNameAudioService {
  PlayerNameAudioService._();

  static final PlayerNameAudioService instance = PlayerNameAudioService._();

  static const String _folderName = 'player_audio';

  Future<String?> pickAndStoreNameAudioForPlayer(Player player) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['wav', 'mp3'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return null;

    final String? selectedPath = result.files.single.path;
    if (selectedPath == null || selectedPath.trim().isEmpty) return null;

    return storeNameAudioForPlayer(
      player: player,
      sourceFilePath: selectedPath,
    );
  }

  Future<String> storeNameAudioForPlayer({
    required Player player,
    required String sourceFilePath,
  }) async {
    final String cleanSourcePath = sourceFilePath.trim();

    if (!_isSupportedAudioPath(cleanSourcePath)) {
      throw const FileSystemException(
        'Nur .wav und .mp3 Dateien sind als Name-Ansage erlaubt.',
      );
    }

    final File sourceFile = File(cleanSourcePath);
    if (!await sourceFile.exists()) {
      throw FileSystemException('Audio-Datei wurde nicht gefunden.', cleanSourcePath);
    }

    final Directory audioDirectory = await _playerAudioDirectory();
    await audioDirectory.create(recursive: true);

    final String extension = path.extension(sourceFile.path).toLowerCase();
    final String safePlayerId = _safeFilePart(player.id);
    final String safePlayerName = _safeFilePart(player.name);
    final String targetFileName = '${safePlayerId}_${safePlayerName}_name$extension';
    final String targetPath = path.join(audioDirectory.path, targetFileName);

    final File copiedFile = await sourceFile.copy(targetPath);
    return copiedFile.path;
  }

  Future<bool> playNameAudioForPlayer(
    Player player, {
    bool waitForCompletion = true,
  }) async {
    final String? audioPath = player.customNameAudioPath?.trim();
    if (audioPath == null || audioPath.isEmpty) return false;

    return playNameAudioPath(audioPath, waitForCompletion: waitForCompletion);
  }

  Future<bool> playNameAudioPath(
    String audioPath, {
    bool waitForCompletion = true,
  }) async {
    final String cleanPath = audioPath.trim();
    if (!_isSupportedAudioPath(cleanPath)) return false;

    final File audioFile = File(cleanPath);
    if (!await audioFile.exists()) return false;

    final AudioPlayer player = AudioPlayer();

    try {
      await player.setReleaseMode(ReleaseMode.stop);
      await player.play(DeviceFileSource(cleanPath));

      if (waitForCompletion) {
        await _waitForCompletion(player);
        await player.dispose();
      } else {
        unawaited(_disposePlayerLater(player));
      }

      return true;
    } catch (_) {
      await player.dispose();
      return false;
    }
  }

  Future<void> deleteStoredNameAudioForPlayer(Player player) async {
    final String? audioPath = player.customNameAudioPath?.trim();
    if (audioPath == null || audioPath.isEmpty) return;

    final File audioFile = File(audioPath);
    try {
      if (await audioFile.exists()) await audioFile.delete();
    } catch (_) {
      // Eine nicht löschbare Datei darf die Profilfunktion nicht blockieren.
    }
  }

  bool hasUsableNameAudio(Player player) {
    final String? audioPath = player.customNameAudioPath?.trim();
    if (audioPath == null || audioPath.isEmpty) return false;
    if (!_isSupportedAudioPath(audioPath)) return false;
    return File(audioPath).existsSync();
  }

  Future<Directory> _playerAudioDirectory() async {
    final Directory appDirectory = await AppDatabase.instance.getApplicationDataDirectory();
    return Directory(path.join(appDirectory.path, _folderName));
  }

  bool _isSupportedAudioPath(String audioPath) {
    final String normalized = audioPath.trim().toLowerCase();
    return normalized.endsWith('.wav') || normalized.endsWith('.mp3');
  }

  String _safeFilePart(String value) {
    final String cleaned = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    return cleaned.isEmpty ? 'player' : cleaned;
  }

  Future<void> _waitForCompletion(AudioPlayer player) async {
    try {
      await player.onPlayerComplete.first.timeout(const Duration(seconds: 8));
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 1600));
    }
  }

  Future<void> _disposePlayerLater(AudioPlayer player) async {
    await Future<void>.delayed(const Duration(seconds: 10));
    try {
      await player.dispose();
    } catch (_) {
      // Dispose darf nichts blockieren.
    }
  }
}