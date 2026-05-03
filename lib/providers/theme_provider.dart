import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题状态管理 Provider
class ThemeProvider extends ChangeNotifier {
  final SharedPreferences _prefs;

  static const String _themeKey = 'theme_mode';

  ThemeMode _themeMode;

  ThemeProvider(this._prefs)
      : _themeMode = _loadThemeMode(_prefs);

  static ThemeMode _loadThemeMode(SharedPreferences prefs) {
    final value = prefs.getString(_themeKey);
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode =>
      _themeMode == ThemeMode.dark ||
      (_themeMode == ThemeMode.system &&
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark);

  /// 设置主题模式
  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    _prefs.setString(_themeKey, mode.name);
    notifyListeners();
  }

  /// 切换亮色/暗色模式
  void toggleTheme() {
    if (_themeMode == ThemeMode.dark) {
      setThemeMode(ThemeMode.light);
    } else {
      setThemeMode(ThemeMode.dark);
    }
  }

  /// 循环切换主题模式：系统 -> 亮色 -> 暗色 -> 系统
  void cycleTheme() {
    switch (_themeMode) {
      case ThemeMode.system:
        setThemeMode(ThemeMode.light);
        break;
      case ThemeMode.light:
        setThemeMode(ThemeMode.dark);
        break;
      case ThemeMode.dark:
        setThemeMode(ThemeMode.system);
        break;
    }
  }
}
