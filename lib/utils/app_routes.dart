import 'package:flutter/material.dart';
import '../widgets/common_widgets.dart';
import '../widgets/knowledge_widgets.dart';
import '../widgets/question_widgets.dart';
import '../widgets/note_widgets.dart';

/// 路由常量定义
class AppRoutes {
  AppRoutes._();

  // 启动页
  static const String splash = '/splash';

  // 登录/注册
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgotPassword';

  // 首页
  static const String home = '/home';

  // 知识点相关
  static const String knowledgeList = '/knowledge/list';
  static const String knowledgeDetail = '/knowledge/detail';
  static const String knowledgeAdd = '/knowledge/add';
  static const String knowledgeEdit = '/knowledge/edit';
  static const String knowledgeFilter = '/knowledge/filter';

  // 题目相关
  static const String questionList = '/question/list';
  static const String questionDetail = '/question/detail';
  static const String questionAdd = '/question/add';
  static const String questionEdit = '/question/edit';
  static const String questionPractice = '/question/practice';
  static const String examMode = '/question/exam';

  // 笔记相关
  static const String noteList = '/note/list';
  static const String noteDetail = '/note/detail';
  static const String noteEdit = '/note/edit';
  static const String noteAdd = '/note/add';

  // 错题本
  static const String errorBook = '/errorBook';
  static const String errorBookDetail = '/errorBook/detail';

  // 统计
  static const String statistics = '/statistics';
  static const String studyReport = '/statistics/report';

  // 设置
  static const String settings = '/settings';
  static const String about = '/settings/about';
  static const String themeSettings = '/settings/theme';

  // 搜索
  static const String search = '/search';
}

/// 路由生成器
Route<dynamic> generateRoute(RouteSettings settings) {
  switch (settings.name) {
    // 启动页
    case AppRoutes.splash:
      return _buildPageRoute(const SizedBox()); // 占位，实际替换为SplashPage

    // 登录/注册
    case AppRoutes.login:
      return _buildPageRoute(const SizedBox()); // 占位，实际替换为LoginPage
    case AppRoutes.register:
      return _buildPageRoute(const SizedBox()); // 占位，实际替换为RegisterPage
    case AppRoutes.forgotPassword:
      return _buildPageRoute(const SizedBox()); // 占位

    // 首页
    case AppRoutes.home:
      return _buildPageRoute(const SizedBox()); // 占位，实际替换为HomePage

    // 知识点相关
    case AppRoutes.knowledgeList:
      return _buildPageRoute(const SizedBox()); // 占位
    case AppRoutes.knowledgeDetail:
      final args = settings.arguments as Map<String, dynamic>?;
      return _buildPageRoute(KnowledgeDetailPage(
        knowledgeId: args?['id'] ?? '',
        title: args?['title'] ?? '',
      ));
    case AppRoutes.knowledgeAdd:
      return _buildPageRoute(const SizedBox()); // 占位
    case AppRoutes.knowledgeEdit:
      return _buildPageRoute(const SizedBox()); // 占位

    // 题目相关
    case AppRoutes.questionList:
      return _buildPageRoute(const SizedBox()); // 占位
    case AppRoutes.questionDetail:
      return _buildPageRoute(const SizedBox()); // 占位
    case AppRoutes.questionAdd:
      return _buildPageRoute(const SizedBox()); // 占位
    case AppRoutes.questionEdit:
      return _buildPageRoute(const SizedBox()); // 占位
    case AppRoutes.questionPractice:
      return _buildPageRoute(const SizedBox()); // 占位

    // 笔记相关
    case AppRoutes.noteList:
      return _buildPageRoute(const SizedBox()); // 占位
    case AppRoutes.noteDetail:
      return _buildPageRoute(const SizedBox()); // 占位
    case AppRoutes.noteEdit:
      return _buildPageRoute(const SizedBox()); // 占位

    // 错题本
    case AppRoutes.errorBook:
      return _buildPageRoute(const SizedBox()); // 占位
    case AppRoutes.errorBookDetail:
      return _buildPageRoute(const SizedBox()); // 占位

    // 统计
    case AppRoutes.statistics:
      return _buildPageRoute(const SizedBox()); // 占位
    case AppRoutes.studyReport:
      return _buildPageRoute(const SizedBox()); // 占位

    // 设置
    case AppRoutes.settings:
      return _buildPageRoute(const SizedBox()); // 占位
    case AppRoutes.about:
      return _buildPageRoute(const SizedBox()); // 占位

    // 搜索
    case AppRoutes.search:
      return _buildPageRoute(const SizedBox()); // 占位

    default:
      return _buildPageRoute(
        const Scaffold(
          body: Center(
            child: Text('页面不存在'),
          ),
        ),
      );
  }
}

/// 构建页面路由（带过渡动画）
PageRouteBuilder _buildPageRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeInOut;
      final tween = Tween(begin: begin, end: end).chain(
        CurveTween(curve: curve),
      );
      final offsetAnimation = animation.drive(tween);
      return SlideTransition(position: offsetAnimation, child: child);
    },
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 300),
  );
}
