import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';

import 'app.dart';
import 'providers/theme_provider.dart';
import 'providers/navigation_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 桌面端初始化 SQLite FFI
  if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
    if (Platform.isLinux) {
      try {
        final candidates = [
          '/usr/lib/aarch64-linux-gnu/libsqlite3.so.0',
          '/usr/lib/aarch64-linux-gnu/libsqlite3.so',
          '/usr/lib/libsqlite3.so.0',
          '/usr/lib/libsqlite3.so',
          '/usr/lib64/libsqlite3.so.0',
          '/usr/lib64/libsqlite3.so',
        ];
        for (final libPath in candidates) {
          if (File(libPath).existsSync()) {
            try {
              open.overrideFor(OperatingSystem.linux, () {
                return DynamicLibrary.open(libPath);
              });
              break;
            } catch (_) {
              continue;
            }
          }
        }
      } catch (_) {}
    }
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ],
      child: const SmartLearningApp(),
    ),
  );
}

class SmartLearningApp extends StatelessWidget {
  const SmartLearningApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: '智慧学习',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF4A90D9),
        brightness: Brightness.light,
        fontFamily: 'Noto Sans CJK SC',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF4A90D9),
        brightness: Brightness.dark,
        fontFamily: 'Noto Sans CJK SC',
      ),
      home: const AppContent(),
    );
  }
}
