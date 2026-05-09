import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/navigation_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home/home_screen.dart';
import 'screens/knowledge/knowledge_screen.dart';
import 'screens/notes/notes_screen.dart';
import 'screens/exam/exam_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/search/search_screen.dart';
import 'screens/mind_map/mind_map_screen.dart';
import 'screens/analysis/analysis_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/must_remember/must_remember_screen.dart';
import 'screens/wrong_questions/wrong_questions_screen.dart';
import 'screens/mother_questions/mother_questions_screen.dart';
import 'screens/web_knowledge/web_knowledge_screen.dart';
import 'screens/settings/settings_screen.dart';

/// 主应用内容 Widget，包含隐藏式底部导航栏和各页面路由
class AppContent extends StatefulWidget {
  const AppContent({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppContentState extends State<AppContent> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  double _startY = 0;
  double _currentY = 0;

  final List<Widget> _pages = const [
    HomeScreen(),
    KnowledgeScreen(),
    NotesScreen(),
    ExamScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 1),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleVerticalDragStart(DragStartDetails details) {
    _startY = details.globalPosition.dy;
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    _currentY = details.globalPosition.dy;
    final delta = _currentY - _startY;
    final navProvider = context.read<NavigationProvider>();
    if (delta > 30 && !navProvider.isNavVisible) {
      navProvider.showNavigation();
      _animationController.reverse();
    } else if (delta < -30 && navProvider.isNavVisible) {
      navProvider.hideNavigation();
      _animationController.forward();
    }
  }

  void _onTabTapped(int index) {
    final navProvider = context.read<NavigationProvider>();
    navProvider.setIndex(index);
    if (!navProvider.isNavVisible) {
      navProvider.showNavigation();
      _animationController.reverse();
    }
  }

  void _navigateToSubPage(BuildContext context, String route) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          switch (route) {
            case '/search':
              return const SearchScreen();
            case '/mind_map':
              return const MindMapScreen();
            case '/analysis':
              return const AnalysisScreen();
            case '/history':
              return const HistoryScreen();
            case '/must_remember':
              return const MustRememberScreen();
            case '/wrong_questions':
              return const WrongQuestionsScreen();
            case '/mother_questions':
              return const MotherQuestionsScreen();
            case '/web_knowledge':
              return const WebKnowledgeScreen();
            case '/settings':
              return const SettingsScreen();
            default:
              return const HomeScreen();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final navProvider = context.watch<NavigationProvider>();
    final isDark = themeProvider.themeMode == ThemeMode.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      body: GestureDetector(
        onVerticalDragStart: _handleVerticalDragStart,
        onVerticalDragUpdate: _handleVerticalDragUpdate,
        child: IndexedStack(
          index: navProvider.currentIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: SafeArea(
                  child: BottomNavigationBar(
                    currentIndex: navProvider.currentIndex,
                    onTap: _onTabTapped,
                    type: BottomNavigationBarType.fixed,
                    showSelectedLabels: true,
                    showUnselectedLabels: true,
                    selectedItemColor: isDark
                        ? const Color(0xFF6DB3F8)
                        : const Color(0xFF4A90D9),
                    unselectedItemColor: isDark
                        ? const Color(0xFF777777)
                        : const Color(0xFF999999),
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    selectedFontSize: isTablet ? 14 : 12,
                    unselectedFontSize: isTablet ? 12 : 10,
                    items: const [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.home_outlined),
                        activeIcon: Icon(Icons.home),
                        label: '首页',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.library_books_outlined),
                        activeIcon: Icon(Icons.library_books),
                        label: '知识库',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.note_outlined),
                        activeIcon: Icon(Icons.note),
                        label: '笔记',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.quiz_outlined),
                        activeIcon: Icon(Icons.quiz),
                        label: '考试',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.person_outline),
                        activeIcon: Icon(Icons.person),
                        label: '我的',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: navProvider.currentIndex == 0
          ? FloatingActionButton(
              onPressed: () => _navigateToSubPage(context, '/search'),
              backgroundColor: const Color(0xFF4A90D9),
              child: const Icon(Icons.search, color: Colors.white),
            )
          : null,
    );
  }
}
