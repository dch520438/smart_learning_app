import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

// ============================================================
// ThemeProvider - 主题状态管理
// ============================================================

/// 主题色选项
enum AppThemeColor {
  blue,    // 蓝色
  green,   // 绿色
  purple,  // 紫色
  orange,  // 橙色
  pink,    // 粉色
  dark,    // 深色
}

/// 字体大小选项
enum AppFontSizeOption {
  small,   // 小
  medium,  // 中
  large,   // 大
  extraLarge, // 特大
}

/// 字体风格选项
enum AppFontFamily {
  system,   // 系统默认
  songti,   // 宋体
  heiti,    // 黑体
  kaiti,    // 楷体
}

/// 圆角风格选项
enum AppRadiusStyle {
  sharp,     // 直角
  small,     // 小圆角
  large,     // 大圆角
}

class ThemeProvider extends ChangeNotifier {
  // 单例模式
  static final ThemeProvider _instance = ThemeProvider._internal();
  factory ThemeProvider() => _instance;
  ThemeProvider._internal();

  // SharedPreferences 实例
  SharedPreferences? _prefs;

  // 当前主题设置
  ThemeMode _themeMode = ThemeMode.light;
  AppThemeColor _themeColor = AppThemeColor.blue;
  AppFontSizeOption _fontSize = AppFontSizeOption.medium;
  AppFontFamily _fontFamily = AppFontFamily.system;
  AppRadiusStyle _radiusStyle = AppRadiusStyle.small;

  // Getters
  ThemeMode get themeMode => _themeMode;
  AppThemeColor get themeColor => _themeColor;
  AppFontSizeOption get fontSize => _fontSize;
  AppFontFamily get fontFamily => _fontFamily;
  AppRadiusStyle get radiusStyle => _radiusStyle;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  // 初始化
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadSettings();
  }

  // 加载设置
  Future<void> _loadSettings() async {
    // 加载主题模式
    final themeModeIndex = _prefs?.getInt('theme_mode') ?? 0;
    _themeMode = ThemeMode.values[themeModeIndex.clamp(0, ThemeMode.values.length - 1)];

    // 加载主题色
    final themeColorIndex = _prefs?.getInt('theme_color') ?? 0;
    _themeColor = AppThemeColor.values[themeColorIndex.clamp(0, AppThemeColor.values.length - 1)];

    // 加载字体大小
    final fontSizeIndex = _prefs?.getInt('font_size') ?? 1;
    _fontSize = AppFontSizeOption.values[fontSizeIndex.clamp(0, AppFontSizeOption.values.length - 1)];

    // 加载字体风格
    final fontFamilyIndex = _prefs?.getInt('font_family') ?? 0;
    _fontFamily = AppFontFamily.values[fontFamilyIndex.clamp(0, AppFontFamily.values.length - 1)];

    // 加载圆角风格
    final radiusStyleIndex = _prefs?.getInt('radius_style') ?? 1;
    _radiusStyle = AppRadiusStyle.values[radiusStyleIndex.clamp(0, AppRadiusStyle.values.length - 1)];

    notifyListeners();
  }

  // 保存设置
  Future<void> _saveSettings() async {
    await _prefs?.setInt('theme_mode', _themeMode.index);
    await _prefs?.setInt('theme_color', _themeColor.index);
    await _prefs?.setInt('font_size', _fontSize.index);
    await _prefs?.setInt('font_family', _fontFamily.index);
    await _prefs?.setInt('radius_style', _radiusStyle.index);
  }

  // 切换主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    await _saveSettings();
    notifyListeners();
  }

  // 切换主题色
  Future<void> setThemeColor(AppThemeColor color) async {
    if (_themeColor == color) return;
    _themeColor = color;
    await _saveSettings();
    notifyListeners();
  }

  // 切换字体大小
  Future<void> setFontSize(AppFontSizeOption size) async {
    if (_fontSize == size) return;
    _fontSize = size;
    await _saveSettings();
    notifyListeners();
  }

  // 切换字体风格
  Future<void> setFontFamily(AppFontFamily family) async {
    if (_fontFamily == family) return;
    _fontFamily = family;
    await _saveSettings();
    notifyListeners();
  }

  // 切换圆角风格
  Future<void> setRadiusStyle(AppRadiusStyle style) async {
    if (_radiusStyle == style) return;
    _radiusStyle = style;
    await _saveSettings();
    notifyListeners();
  }

  // 获取当前主题色
  Color get primaryColor {
    switch (_themeColor) {
      case AppThemeColor.blue:
        return const Color(0xFF1E88E5);
      case AppThemeColor.green:
        return const Color(0xFF43A047);
      case AppThemeColor.purple:
        return const Color(0xFF8E24AA);
      case AppThemeColor.orange:
        return const Color(0xFFFB8C00);
      case AppThemeColor.pink:
        return const Color(0xFFE91E63);
      case AppThemeColor.dark:
        return const Color(0xFF37474F);
    }
  }

  // 获取字体大小缩放比例
  double get fontScale {
    switch (_fontSize) {
      case AppFontSizeOption.small:
        return 0.875;
      case AppFontSizeOption.medium:
        return 1.0;
      case AppFontSizeOption.large:
        return 1.125;
      case AppFontSizeOption.extraLarge:
        return 1.25;
    }
  }

  // 获取字体族名称
  String? get fontFamilyName {
    switch (_fontFamily) {
      case AppFontFamily.system:
        return null;
      case AppFontFamily.songti:
        return 'Songti';
      case AppFontFamily.heiti:
        return 'Heiti';
      case AppFontFamily.kaiti:
        return 'Kaiti';
    }
  }

  // 获取圆角值
  double get radiusValue {
    switch (_radiusStyle) {
      case AppRadiusStyle.sharp:
        return 0;
      case AppRadiusStyle.small:
        return 8;
      case AppRadiusStyle.large:
        return 16;
    }
  }

  // 获取主题数据
  ThemeData get lightTheme {
    final color = primaryColor;
    final scale = fontScale;
    final radius = radiusValue;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: color,
        onPrimary: Colors.white,
        primaryContainer: color.withOpacity(0.1),
        onPrimaryContainer: color,
        secondary: color.withOpacity(0.8),
        onSecondary: Colors.white,
        secondaryContainer: color.withOpacity(0.08),
        onSecondaryContainer: color,
        surface: Colors.white,
        onSurface: const Color(0xFF1A1A1A),
        surfaceContainerHighest: const Color(0xFFF5F5F5),
        onSurfaceVariant: const Color(0xFF666666),
        outline: const Color(0xFFE0E0E0),
        error: const Color(0xFFE53935),
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      fontFamily: fontFamilyName,
      textTheme: TextTheme(
        displayLarge: TextStyle(fontSize: 57 * scale, fontWeight: FontWeight.w400),
        displayMedium: TextStyle(fontSize: 45 * scale, fontWeight: FontWeight.w400),
        displaySmall: TextStyle(fontSize: 36 * scale, fontWeight: FontWeight.w400),
        headlineLarge: TextStyle(fontSize: 32 * scale, fontWeight: FontWeight.w600),
        headlineMedium: TextStyle(fontSize: 28 * scale, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(fontSize: 24 * scale, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(fontSize: 22 * scale, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.w400),
        bodyMedium: TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.w400),
        bodySmall: TextStyle(fontSize: 12 * scale, fontWeight: FontWeight.w400),
        labelLarge: TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(fontSize: 12 * scale, fontWeight: FontWeight.w600),
        labelSmall: TextStyle(fontSize: 11 * scale, fontWeight: FontWeight.w600),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: color, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: Color(0xFFE53935), width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF5F5F5),
        selectedColor: color.withOpacity(0.1),
        labelStyle: const TextStyle(fontSize: 14),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontSize: 18 * scale,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1A1A1A),
        ),
      ),
      tabBarTheme: TabBarTheme(
        labelColor: color,
        unselectedLabelColor: const Color(0xFF666666),
        indicatorColor: color,
        labelStyle: TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.w400),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: color,
        unselectedItemColor: const Color(0xFF999999),
        selectedLabelStyle: TextStyle(fontSize: 12 * scale),
        unselectedLabelStyle: TextStyle(fontSize: 12 * scale),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: const Color(0xFFE0E0E0),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  ThemeData get darkTheme {
    final color = primaryColor;
    final scale = fontScale;
    final radius = radiusValue;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: color,
        onPrimary: Colors.white,
        primaryContainer: color.withOpacity(0.2),
        onPrimaryContainer: Colors.white,
        secondary: color.withOpacity(0.8),
        onSecondary: Colors.white,
        secondaryContainer: color.withOpacity(0.15),
        onSecondaryContainer: Colors.white,
        surface: const Color(0xFF1E1E1E),
        onSurface: Colors.white,
        surfaceContainerHighest: const Color(0xFF2A2A2A),
        onSurfaceVariant: const Color(0xFFB0B0B0),
        outline: const Color(0xFF404040),
        error: const Color(0xFFEF5350),
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      fontFamily: fontFamilyName,
      textTheme: TextTheme(
        displayLarge: TextStyle(fontSize: 57 * scale, fontWeight: FontWeight.w400, color: Colors.white),
        displayMedium: TextStyle(fontSize: 45 * scale, fontWeight: FontWeight.w400, color: Colors.white),
        displaySmall: TextStyle(fontSize: 36 * scale, fontWeight: FontWeight.w400, color: Colors.white),
        headlineLarge: TextStyle(fontSize: 32 * scale, fontWeight: FontWeight.w600, color: Colors.white),
        headlineMedium: TextStyle(fontSize: 28 * scale, fontWeight: FontWeight.w600, color: Colors.white),
        headlineSmall: TextStyle(fontSize: 24 * scale, fontWeight: FontWeight.w600, color: Colors.white),
        titleLarge: TextStyle(fontSize: 22 * scale, fontWeight: FontWeight.w600, color: Colors.white),
        titleMedium: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.w600, color: Colors.white),
        titleSmall: TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.w600, color: Colors.white),
        bodyLarge: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.w400, color: Colors.white),
        bodyMedium: TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.w400, color: Colors.white),
        bodySmall: TextStyle(fontSize: 12 * scale, fontWeight: FontWeight.w400, color: Colors.white70),
        labelLarge: TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.w600, color: Colors.white),
        labelMedium: TextStyle(fontSize: 12 * scale, fontWeight: FontWeight.w600, color: Colors.white),
        labelSmall: TextStyle(fontSize: 11 * scale, fontWeight: FontWeight.w600, color: Colors.white70),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: color, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: Color(0xFFEF5350), width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF2A2A2A),
        selectedColor: color.withOpacity(0.2),
        labelStyle: const TextStyle(fontSize: 14, color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontSize: 18 * scale,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      tabBarTheme: TabBarTheme(
        labelColor: color,
        unselectedLabelColor: const Color(0xFFB0B0B0),
        indicatorColor: color,
        labelStyle: TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.w400),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF1E1E1E),
        selectedItemColor: color,
        unselectedItemColor: const Color(0xFF808080),
        selectedLabelStyle: TextStyle(fontSize: 12 * scale),
        unselectedLabelStyle: TextStyle(fontSize: 12 * scale),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: const Color(0xFF404040),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  // 获取主题色名称
  static String getThemeColorName(AppThemeColor color) {
    switch (color) {
      case AppThemeColor.blue:
        return '蓝色';
      case AppThemeColor.green:
        return '绿色';
      case AppThemeColor.purple:
        return '紫色';
      case AppThemeColor.orange:
        return '橙色';
      case AppThemeColor.pink:
        return '粉色';
      case AppThemeColor.dark:
        return '深色';
    }
  }

  // 获取字体大小名称
  static String getFontSizeName(AppFontSizeOption size) {
    switch (size) {
      case AppFontSizeOption.small:
        return '小';
      case AppFontSizeOption.medium:
        return '中';
      case AppFontSizeOption.large:
        return '大';
      case AppFontSizeOption.extraLarge:
        return '特大';
    }
  }

  // 获取字体风格名称
  static String getFontFamilyName(AppFontFamily family) {
    switch (family) {
      case AppFontFamily.system:
        return '系统默认';
      case AppFontFamily.songti:
        return '宋体';
      case AppFontFamily.heiti:
        return '黑体';
      case AppFontFamily.kaiti:
        return '楷体';
    }
  }

  // 获取圆角风格名称
  static String getRadiusStyleName(AppRadiusStyle style) {
    switch (style) {
      case AppRadiusStyle.sharp:
        return '直角';
      case AppRadiusStyle.small:
        return '小圆角';
      case AppRadiusStyle.large:
        return '大圆角';
    }
  }
}
