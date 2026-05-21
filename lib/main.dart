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
import 'services/usage_time_service.dart';
import 'screens/search/search_screen.dart';
import 'screens/wrong_questions/wrong_questions_screen.dart';
import 'screens/habits/habits_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/knowledge/knowledge_screen.dart';
import 'screens/notes/notes_screen.dart';
import 'screens/exam/exam_screen.dart';
import 'screens/mind_map/mind_map_screen.dart';
import 'screens/analysis/analysis_screen.dart';
import 'screens/must_remember/must_remember_screen.dart';
import 'screens/mother_questions/mother_questions_screen.dart';
import 'screens/web_knowledge/web_knowledge_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/exam_papers/exam_papers_screen.dart';
import 'screens/ai/ai_service_screen.dart';
import 'screens/ai/ai_settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 桌面端初始化 SQLite FFI
  if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
    if (Platform.isLinux) {
      try {
        final candidates = [
          // x86_64 架构
          '/usr/lib/x86_64-linux-gnu/libsqlite3.so.0',
          '/usr/lib/x86_64-linux-gnu/libsqlite3.so',
          // aarch64 架构
          '/usr/lib/aarch64-linux-gnu/libsqlite3.so.0',
          '/usr/lib/aarch64-linux-gnu/libsqlite3.so',
          // 通用路径
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

  // 初始化主题
  final themeProvider = ThemeProvider();
  await themeProvider.initialize();

  // 初始化使用时间记录服务
  final usageTimeService = UsageTimeService();
  try {
    await usageTimeService.initialize();
  } catch (e) {
    debugPrint('使用时间记录初始化失败: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => themeProvider),
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
      // 使用系统默认字体，不依赖打包字体，确保中文正常显示
      theme: themeProvider.lightTheme.copyWith(
        textTheme: themeProvider.lightTheme.textTheme,
        appBarTheme: const AppBarTheme(
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
      darkTheme: themeProvider.darkTheme.copyWith(
        textTheme: themeProvider.darkTheme.textTheme,
        appBarTheme: AppBarTheme(
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      // 设置全局默认字体
      themeAnimationDuration: const Duration(milliseconds: 300),
      home: const AppContent(),
      onGenerateRoute: (settings) {
        // 命名路由支持，供 pushNamed 使用
        final uri = Uri.parse(settings.name ?? '/');
        final path = uri.path;
        switch (path) {
          case '/search':
            return MaterialPageRoute(builder: (_) => const SearchScreen());
          case '/wrong_questions':
            return MaterialPageRoute(builder: (_) => const WrongQuestionsScreen());
          case '/habits':
            return MaterialPageRoute(builder: (_) => const HabitsScreen());
          case '/history':
            return MaterialPageRoute(builder: (_) => const HistoryScreen());
          case '/knowledge':
            return MaterialPageRoute(builder: (_) => const KnowledgeScreen());
          case '/notes':
            return MaterialPageRoute(builder: (_) => const NotesScreen());
          case '/exam':
            return MaterialPageRoute(builder: (_) => const ExamScreen());
          case '/mind_map':
            return MaterialPageRoute(builder: (_) => const MindMapScreen());
          case '/analysis':
            return MaterialPageRoute(builder: (_) => const AnalysisScreen());
          case '/must_remember':
            return MaterialPageRoute(builder: (_) => const MustRememberScreen());
          case '/mother_questions':
            return MaterialPageRoute(builder: (_) => const MotherQuestionsScreen());
          case '/web_knowledge':
            return MaterialPageRoute(builder: (_) => const WebKnowledgeScreen());
          case '/settings':
            return MaterialPageRoute(builder: (_) => const SettingsScreen());
          case '/exam_papers':
            return MaterialPageRoute(builder: (_) => const ExamPapersScreen());
          case '/ai/service':
            return MaterialPageRoute(builder: (_) => const AIServiceScreen());
          case '/ai/settings':
            return MaterialPageRoute(builder: (_) => const AISettingsScreen());
          default:
            return MaterialPageRoute(builder: (_) => const AppContent());
        }
      },
    );
  }
}
