import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'providers/theme_provider.dart';
import 'providers/navigation_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 设置系统UI样式
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // 限制屏幕方向
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 初始化 SharedPreferences
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(prefs),
        ),
        ChangeNotifierProvider<NavigationProvider>(
          create: (_) => NavigationProvider(),
        ),
      ],
      child: const SmartLearningApp(),
    ),
  );
}

/// 应用根组件，负责主题和国际化配置
class SmartLearningApp extends StatelessWidget {
  const SmartLearningApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: '智慧学习',
          debugShowCheckedModeBanner: false,

          // 主题配置
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: const Color(0xFF4A90D9),
            brightness: Brightness.light,
            fontFamily: 'NotoSansSC',
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
              scrolledUnderElevation: 1,
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF333333),
              titleTextStyle: TextStyle(
                color: Color(0xFF333333),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            scaffoldBackgroundColor: const Color(0xFFF5F5F5),
            cardTheme: CardThemeData(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Color(0xFF4A90D9),
              unselectedItemColor: Color(0xFF999999),
              backgroundColor: Colors.white,
              elevation: 8,
            ),
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: Color(0xFF4A90D9),
              foregroundColor: Colors.white,
              elevation: 4,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              hintStyle: TextStyle(color: Colors.grey[400]),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90D9),
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF4A90D9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          // 暗色主题
          darkTheme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: const Color(0xFF4A90D9),
            brightness: Brightness.dark,
            fontFamily: 'NotoSansSC',
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
              scrolledUnderElevation: 1,
              backgroundColor: Color(0xFF1E1E1E),
              foregroundColor: Color(0xFFE0E0E0),
              titleTextStyle: TextStyle(
                color: Color(0xFFE0E0E0),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
            cardTheme: CardThemeData(
              elevation: 2,
              color: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Color(0xFF6DB3F8),
              unselectedItemColor: Color(0xFF777777),
              backgroundColor: Color(0xFF1E1E1E),
              elevation: 8,
            ),
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: Color(0xFF4A90D9),
              foregroundColor: Colors.white,
              elevation: 4,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF2A2A2A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              hintStyle: TextStyle(color: Colors.grey[600]),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90D9),
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6DB3F8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          // 主题模式
          themeMode: themeProvider.themeMode,

          // 路由配置
          initialRoute: '/',
          routes: {
            '/': (context) => const App(),
          },

          // 过渡动画
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              builder: (context) => const App(),
              settings: settings,
            );
          },
        );
      },
    );
  }
}
