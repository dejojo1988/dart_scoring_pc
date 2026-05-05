import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

class AppearanceSettings {
  final double hue;

  const AppearanceSettings({
    required this.hue,
  });

  factory AppearanceSettings.defaults() {
    return const AppearanceSettings(
      hue: 145,
    );
  }

  Color get accentColor {
    return HSLColor.fromAHSL(
      1,
      hue,
      0.86,
      0.55,
    ).toColor();
  }

  AppearanceSettings copyWith({
    double? hue,
  }) {
    return AppearanceSettings(
      hue: hue ?? this.hue,
    );
  }

  Map<String, Object> toJson() {
    return {
      'hue': hue,
    };
  }

  factory AppearanceSettings.fromJson(Map<String, Object?> json) {
    final Object? rawHue = json['hue'];

    double hue = 145;

    if (rawHue is num) {
      hue = rawHue.toDouble().clamp(0.0, 360.0).toDouble();
    }

    return AppearanceSettings(
      hue: hue,
    );
  }
}

class AppearanceService {
  AppearanceService._();

  static final AppearanceService instance = AppearanceService._();

  final ValueNotifier<AppearanceSettings> notifier =
      ValueNotifier<AppearanceSettings>(
    AppearanceSettings.defaults(),
  );

  bool _loaded = false;

  AppearanceSettings get settings => notifier.value;

  Color get accentColor => notifier.value.accentColor;

  Future<void> load() async {
    if (_loaded) {
      return;
    }

    final File file = await _settingsFile();

    if (!await file.exists()) {
      notifier.value = AppearanceSettings.defaults();
      _loaded = true;
      await save();
      return;
    }

    try {
      final String content = await file.readAsString();
      final Object? decoded = jsonDecode(content);

      if (decoded is Map<String, Object?>) {
        notifier.value = AppearanceSettings.fromJson(decoded);
      } else {
        notifier.value = AppearanceSettings.defaults();
      }
    } catch (_) {
      notifier.value = AppearanceSettings.defaults();
    }

    _loaded = true;
  }

  Future<void> save() async {
    final File file = await _settingsFile();
    await file.parent.create(recursive: true);

    const JsonEncoder encoder = JsonEncoder.withIndent('  ');

    await file.writeAsString(
      encoder.convert(notifier.value.toJson()),
      flush: true,
    );

    _loaded = true;
  }

  Future<void> updateHue(double hue) async {
    notifier.value = notifier.value.copyWith(
      hue: hue.clamp(0.0, 360.0).toDouble(),
    );

    await save();
  }

  Future<void> reset() async {
    notifier.value = AppearanceSettings.defaults();
    await save();
  }

  Future<File> _settingsFile() async {
    final String basePath =
        Platform.environment['APPDATA'] ??
        Platform.environment['LOCALAPPDATA'] ??
        Directory.current.path;

    return File(
      '$basePath${Platform.pathSeparator}DartScoringPC${Platform.pathSeparator}appearance_settings.json',
    );
  }
}
