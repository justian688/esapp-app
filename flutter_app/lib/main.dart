import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'models.dart';
import 'screens/home.dart';
import 'settings.dart';
import 'theme.dart';
import 'upload_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_TW');
  if (Platform.isAndroid) await VideoUploadService.initialize();
  await RecordingSettings.instance.load();
  await AppStore.instance.load();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const EsApp());
}

class EsApp extends StatelessWidget {
  const EsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'es省電王',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomeScreen(),
    );
  }
}
