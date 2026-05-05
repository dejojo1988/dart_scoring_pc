import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app.dart';
import 'services/appearance_service.dart';
import 'services/window_mode_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  await AppearanceService.instance.load();

  await WindowModeService.initWindowBeforeAppStart();

  runApp(const DartScoringApp());
}