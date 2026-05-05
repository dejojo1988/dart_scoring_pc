import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

enum AppWindowMode {
  windowed,
  fullscreen,
}

class WindowModeService {
  static const String _storageKey = 'app_window_mode';

  static String label(AppWindowMode mode) {
    switch (mode) {
      case AppWindowMode.windowed:
        return 'Fenstermodus';
      case AppWindowMode.fullscreen:
        return 'Vollbild';
    }
  }

  static Future<AppWindowMode> loadMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_storageKey);

    switch (value) {
      case 'fullscreen':
        return AppWindowMode.fullscreen;
      case 'windowed':
      default:
        return AppWindowMode.windowed;
    }
  }

  static Future<void> saveMode(AppWindowMode mode) async {
    final prefs = await SharedPreferences.getInstance();

    switch (mode) {
      case AppWindowMode.windowed:
        await prefs.setString(_storageKey, 'windowed');
        break;
      case AppWindowMode.fullscreen:
        await prefs.setString(_storageKey, 'fullscreen');
        break;
    }
  }

  static Future<void> applyMode(AppWindowMode mode) async {
    switch (mode) {
      case AppWindowMode.windowed:
        await windowManager.setFullScreen(false);
        await windowManager.setResizable(true);
        await windowManager.setMinimizable(true);
        await windowManager.setMaximizable(true);
        break;

      case AppWindowMode.fullscreen:
        await windowManager.setFullScreen(true);
        break;
    }
  }

  static Future<void> setMode(AppWindowMode mode) async {
    await saveMode(mode);
    await applyMode(mode);
  }

  static Future<void> initWindowBeforeAppStart() async {
    WidgetsFlutterBinding.ensureInitialized();

    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1280, 720),
      minimumSize: Size(1000, 650),
      center: true,
      title: 'Dart Scoring PC',
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
    );

    final savedMode = await loadMode();

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      await applyMode(savedMode);
    });
  }
}