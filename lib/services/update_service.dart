import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../app_version.dart';

class UpdateSettings {
  static const String defaultManifestLocation =
      'https://raw.githubusercontent.com/dejojo1988/dart_scoring_pc/main/updates/beta/update.json';

  final String manifestLocation;

  const UpdateSettings({
    required this.manifestLocation,
  });

  factory UpdateSettings.defaults() {
    return const UpdateSettings(
      manifestLocation: defaultManifestLocation,
    );
  }

  UpdateSettings copyWith({
    String? manifestLocation,
  }) {
    return UpdateSettings(
      manifestLocation: manifestLocation ?? this.manifestLocation,
    );
  }

  Map<String, Object> toJson() {
    return {
      'manifestLocation': manifestLocation,
    };
  }

  factory UpdateSettings.fromJson(Map<String, Object?> json) {
    final Object? rawManifestLocation = json['manifestLocation'];

    final String manifestLocation =
        rawManifestLocation is String ? rawManifestLocation.trim() : '';

    return UpdateSettings(
      manifestLocation: manifestLocation.isEmpty
          ? defaultManifestLocation
          : manifestLocation,
    );
  }
}

class UpdateManifest {
  final String version;
  final String channel;
  final String installerUrl;
  final String notes;

  const UpdateManifest({
    required this.version,
    required this.channel,
    required this.installerUrl,
    required this.notes,
  });

  factory UpdateManifest.fromJson(Map<String, Object?> json) {
    final Object? rawVersion = json['version'];
    final Object? rawInstallerUrl = json['installerUrl'];

    if (rawVersion is! String || rawVersion.trim().isEmpty) {
      throw const FormatException('update.json enthält keine gültige version.');
    }

    if (rawInstallerUrl is! String || rawInstallerUrl.trim().isEmpty) {
      throw const FormatException(
        'update.json enthält keine gültige installerUrl.',
      );
    }

    final Object? rawChannel = json['channel'];
    final Object? rawNotes = json['notes'];

    return UpdateManifest(
      version: rawVersion.trim(),
      channel: rawChannel is String && rawChannel.trim().isNotEmpty
          ? rawChannel.trim()
          : 'beta',
      installerUrl: rawInstallerUrl.trim(),
      notes: rawNotes is String ? rawNotes.trim() : '',
    );
  }

  UpdateManifest copyWith({
    String? version,
    String? channel,
    String? installerUrl,
    String? notes,
  }) {
    return UpdateManifest(
      version: version ?? this.version,
      channel: channel ?? this.channel,
      installerUrl: installerUrl ?? this.installerUrl,
      notes: notes ?? this.notes,
    );
  }
}

class UpdateCheckResult {
  final String localVersion;
  final UpdateManifest manifest;
  final bool hasUpdate;

  const UpdateCheckResult({
    required this.localVersion,
    required this.manifest,
    required this.hasUpdate,
  });
}

class UpdateDownloadResult {
  final File installerFile;

  const UpdateDownloadResult({
    required this.installerFile,
  });
}

class UpdateService {
  UpdateService._();

  static final UpdateService instance = UpdateService._();

  UpdateSettings _settings = UpdateSettings.defaults();
  bool _loaded = false;

  UpdateSettings get settings => _settings;

  Future<void> load() async {
    if (_loaded) {
      return;
    }

    final File file = await _settingsFile();

    if (!await file.exists()) {
      _settings = UpdateSettings.defaults();
      _loaded = true;
      await save();
      return;
    }

    try {
      final String content = await file.readAsString();
      final Object? decoded = jsonDecode(content);

      if (decoded is Map<String, Object?>) {
        _settings = _normalizeSettings(
          UpdateSettings.fromJson(decoded),
        );
      } else {
        _settings = UpdateSettings.defaults();
      }
    } catch (_) {
      _settings = UpdateSettings.defaults();
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

  Future<void> updateSettings(UpdateSettings settings) async {
    _settings = _normalizeSettings(settings);
    await save();
  }

  UpdateSettings _normalizeSettings(UpdateSettings settings) {
    final String manifestLocation = settings.manifestLocation.trim();

    if (manifestLocation.isEmpty || _isOldOfficialReleaseManifestUrl(manifestLocation)) {
      return UpdateSettings.defaults();
    }

    return settings.copyWith(
      manifestLocation: manifestLocation,
    );
  }

  bool _isOldOfficialReleaseManifestUrl(String manifestLocation) {
    final String normalized = manifestLocation.trim().toLowerCase();

    return normalized.startsWith(
          'https://github.com/dejojo1988/dart_scoring_pc/releases/download/v',
        ) &&
        normalized.endsWith('/update.json');
  }

  Future<UpdateCheckResult> checkForUpdate() async {
    await load();

    final String manifestLocation = _settings.manifestLocation.trim();

    if (manifestLocation.isEmpty) {
      throw StateError('Keine Update-Quelle eingetragen.');
    }

    final String manifestContent = await _readTextFromLocation(manifestLocation);
    final Object? decoded = jsonDecode(manifestContent);

    if (decoded is! Map<String, Object?>) {
      throw const FormatException('update.json ist kein gültiges JSON-Objekt.');
    }

    final UpdateManifest rawManifest = UpdateManifest.fromJson(decoded);

    final UpdateManifest manifest = rawManifest.copyWith(
      installerUrl: _resolveInstallerLocation(
        manifestLocation: manifestLocation,
        installerLocation: rawManifest.installerUrl,
      ),
    );

    final bool hasUpdate = _isVersionNewer(
      remoteVersion: manifest.version,
      localVersion: AppVersion.number,
    );

    return UpdateCheckResult(
      localVersion: AppVersion.number,
      manifest: manifest,
      hasUpdate: hasUpdate,
    );
  }

  Future<UpdateDownloadResult> downloadInstaller({
    required UpdateManifest manifest,
    required void Function(double progress) onProgress,
  }) async {
    final String installerLocation = manifest.installerUrl.trim();

    if (installerLocation.isEmpty) {
      throw StateError('Keine installerUrl im Update-Manifest.');
    }

    final Directory updateDirectory = await _updateDirectory();
    await updateDirectory.create(recursive: true);

    final String fileName = _fileNameFromLocation(
      installerLocation,
      fallbackVersion: manifest.version,
    );

    final File targetFile = File(
      '${updateDirectory.path}${Platform.pathSeparator}$fileName',
    );

    if (_isHttpLocation(installerLocation)) {
      try {
        await _downloadHttpFile(
          url: installerLocation,
          targetFile: targetFile,
          onProgress: onProgress,
        );
      } catch (_) {
        await _downloadHttpFileWithWindowsCurl(
          url: installerLocation,
          targetFile: targetFile,
          onProgress: onProgress,
        );
      }

      return UpdateDownloadResult(installerFile: targetFile);
    }

    final File sourceFile = File(_filePathFromLocation(installerLocation));

    if (!await sourceFile.exists()) {
      throw FileSystemException(
        'Installer-Datei wurde nicht gefunden.',
        sourceFile.path,
      );
    }

    await sourceFile.copy(targetFile.path);
    onProgress(1);

    return UpdateDownloadResult(installerFile: targetFile);
  }

  Future<void> launchInstallerAndExit(File installerFile) async {
    if (!await installerFile.exists()) {
      throw FileSystemException(
        'Installer-Datei wurde nicht gefunden.',
        installerFile.path,
      );
    }

    await Process.start(
      installerFile.path,
      const [],
      mode: ProcessStartMode.detached,
      runInShell: true,
    );

    await Future<void>.delayed(const Duration(milliseconds: 350));
    exit(0);
  }

  Future<void> _downloadHttpFile({
    required String url,
    required File targetFile,
    required void Function(double progress) onProgress,
  }) async {
    final HttpClient client = HttpClient();

    try {
      final Uri uri = Uri.parse(url);
      final HttpClientRequest request = await client.getUrl(uri);
      final HttpClientResponse response = await request.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Download fehlgeschlagen. HTTP ${response.statusCode}.',
          uri: uri,
        );
      }

      await targetFile.parent.create(recursive: true);

      final IOSink sink = targetFile.openWrite();
      int receivedBytes = 0;
      final int totalBytes = response.contentLength;

      try {
        await for (final List<int> chunk in response) {
          receivedBytes += chunk.length;
          sink.add(chunk);

          if (totalBytes > 0) {
            onProgress(receivedBytes / totalBytes);
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      onProgress(1);
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _downloadHttpFileWithWindowsCurl({
    required String url,
    required File targetFile,
    required void Function(double progress) onProgress,
  }) async {
    await targetFile.parent.create(recursive: true);

    final ProcessResult result = await Process.run(
      'curl.exe',
      [
        '-L',
        '--fail',
        '--silent',
        '--show-error',
        '--output',
        targetFile.path,
        url,
      ],
      runInShell: true,
    );

    if (result.exitCode != 0) {
      final String errorText = result.stderr.toString().trim();

      throw StateError(
        errorText.isEmpty
            ? 'Installer konnte nicht heruntergeladen werden.'
            : errorText,
      );
    }

    if (!await targetFile.exists() || await targetFile.length() == 0) {
      throw FileSystemException(
        'Installer-Download ist leer oder fehlgeschlagen.',
        targetFile.path,
      );
    }

    onProgress(1);
  }

  Future<String> _readTextFromLocation(String location) async {
    if (_isHttpLocation(location)) {
      try {
        return await _readTextWithDartHttp(location);
      } catch (_) {
        return _readTextWithWindowsCurl(location);
      }
    }

    final File file = File(_filePathFromLocation(location));

    if (!await file.exists()) {
      throw FileSystemException(
        'Update-Manifest wurde nicht gefunden.',
        file.path,
      );
    }

    return file.readAsString();
  }

  Future<String> _readTextWithDartHttp(String location) async {
    final HttpClient client = HttpClient();

    try {
      final Uri uri = Uri.parse(location);
      final HttpClientRequest request = await client.getUrl(uri);
      final HttpClientResponse response = await request.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Manifest konnte nicht geladen werden. HTTP ${response.statusCode}.',
          uri: uri,
        );
      }

      return await response.transform(utf8.decoder).join();
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _readTextWithWindowsCurl(String location) async {
    final ProcessResult result = await Process.run(
      'curl.exe',
      [
        '-L',
        '--fail',
        '--silent',
        '--show-error',
        location,
      ],
      runInShell: true,
    );

    if (result.exitCode != 0) {
      final String errorText = result.stderr.toString().trim();

      throw StateError(
        errorText.isEmpty
            ? 'Update-Manifest konnte nicht geladen werden.'
            : errorText,
      );
    }

    return result.stdout.toString();
  }

  String _resolveInstallerLocation({
    required String manifestLocation,
    required String installerLocation,
  }) {
    final String cleanedInstallerLocation = installerLocation.trim();

    if (_isHttpLocation(cleanedInstallerLocation) ||
        cleanedInstallerLocation.startsWith('file://') ||
        _isAbsoluteWindowsPath(cleanedInstallerLocation) ||
        cleanedInstallerLocation.startsWith(r'\\')) {
      return cleanedInstallerLocation;
    }

    if (_isHttpLocation(manifestLocation)) {
      return Uri.parse(manifestLocation)
          .resolve(cleanedInstallerLocation)
          .toString();
    }

    final File manifestFile = File(_filePathFromLocation(manifestLocation));

    return '${manifestFile.parent.path}${Platform.pathSeparator}$cleanedInstallerLocation';
  }

  String _filePathFromLocation(String location) {
    final String cleanedLocation = location.trim();

    if (cleanedLocation.startsWith('file://')) {
      return File.fromUri(Uri.parse(cleanedLocation)).path;
    }

    return cleanedLocation;
  }

  bool _isHttpLocation(String location) {
    final String cleanedLocation = location.trim().toLowerCase();

    return cleanedLocation.startsWith('http://') ||
        cleanedLocation.startsWith('https://');
  }

  bool _isAbsoluteWindowsPath(String value) {
    return RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(value);
  }

  String _fileNameFromLocation(
    String location, {
    required String fallbackVersion,
  }) {
    String fileName = '';

    if (_isHttpLocation(location)) {
      final Uri uri = Uri.parse(location);

      if (uri.pathSegments.isNotEmpty) {
        fileName = uri.pathSegments.last;
      }
    } else {
      final String normalized = location.replaceAll('\\', '/');
      final List<String> parts = normalized.split('/');

      if (parts.isNotEmpty) {
        fileName = parts.last;
      }
    }

    if (!fileName.toLowerCase().endsWith('.exe')) {
      return 'DartScoringPC_Setup_$fallbackVersion.exe';
    }

    return fileName;
  }

  bool _isVersionNewer({
    required String remoteVersion,
    required String localVersion,
  }) {
    final List<int> remoteParts = _versionParts(remoteVersion);
    final List<int> localParts = _versionParts(localVersion);
    final int maxLength = remoteParts.length > localParts.length
        ? remoteParts.length
        : localParts.length;

    for (int index = 0; index < maxLength; index++) {
      final int remotePart =
          index < remoteParts.length ? remoteParts[index] : 0;
      final int localPart = index < localParts.length ? localParts[index] : 0;

      if (remotePart > localPart) {
        return true;
      }

      if (remotePart < localPart) {
        return false;
      }
    }

    return false;
  }

  List<int> _versionParts(String version) {
    final String cleaned = version
        .split('-')
        .first
        .split('+')
        .first
        .replaceAll(RegExp(r'[^0-9.]'), '');

    return cleaned
        .split('.')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
  }

  Future<File> _settingsFile() async {
    final String basePath =
        Platform.environment['APPDATA'] ??
        Platform.environment['LOCALAPPDATA'] ??
        Directory.current.path;

    return File(
      '$basePath${Platform.pathSeparator}DartScoringPC${Platform.pathSeparator}update_settings.json',
    );
  }

  Future<Directory> _updateDirectory() async {
    final String basePath =
        Platform.environment['APPDATA'] ??
        Platform.environment['LOCALAPPDATA'] ??
        Directory.current.path;

    return Directory(
      '$basePath${Platform.pathSeparator}DartScoringPC${Platform.pathSeparator}updates',
    );
  }
}