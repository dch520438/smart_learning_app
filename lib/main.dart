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
    // 在 Linux ARM64 上，使用系统 SQLite 库避免 GLIBC 版本不兼容
    if (Platform.isLinux) {
      final arch = Platform.executable;
      try {
        // 尝试加载系统 SQLite 库
        final candidates = [
          '/usr/lib/aarch64-linux-gnu/libsqlite3.so.0',
          '/usr/lib/aarch64-linux-gnu/libsqlite3.so',
          '/usr/lib/libsqlite3.so.0',
          '/usr/lib/libsqlite3.so',
          '/usr/lib64/libsqlite3.so.0',
          '/usr/lib64/libsqlite3.so',
        ];
        bool loaded = false;
        for (final libPath in candidates) {
          if (File(libPath).existsSync()) {
            try {
              open.overrideFor(OperatingSystem.linux, () {
                return DynamicLibrary.open(libPath);
              });
              loaded = true;
              break;
            } catch (_) {
              continue;
            }
          }
        }
        if (!loaded) {
          // 回退到默认
          sqfliteFfiInit();
        }
      } catch (_) {
        sqfliteFfiInit();
      }
    }
    // 初始化 sqflite FFI
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  }

  // 设置系统UI样式
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // 屏幕方向限制
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 初始化 SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // 运行应用
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
