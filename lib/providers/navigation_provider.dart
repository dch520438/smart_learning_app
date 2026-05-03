import 'package:flutter/material.dart';

/// 导航状态管理 Provider
class NavigationProvider extends ChangeNotifier {
  int _currentIndex = 0;
  bool _isNavVisible = true;

  int get currentIndex => _currentIndex;

  bool get isNavVisible => _isNavVisible;

  /// 设置当前选中的页面索引
  void setIndex(int index) {
    if (_currentIndex == index) return;
    _currentIndex = index;
    notifyListeners();
  }

  /// 显示底部导航栏
  void showNavigation() {
    if (_isNavVisible) return;
    _isNavVisible = true;
    notifyListeners();
  }

  /// 隐藏底部导航栏
  void hideNavigation() {
    if (!_isNavVisible) return;
    _isNavVisible = false;
    notifyListeners();
  }

  /// 切换导航栏显示状态
  void toggleNavigation() {
    _isNavVisible = !_isNavVisible;
    notifyListeners();
  }
}
