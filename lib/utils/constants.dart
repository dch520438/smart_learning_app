import 'package:flutter/material.dart';

/// 学科信息模型
class SubjectInfo {
  final String name;
  final String icon;
  final Color color;

  const SubjectInfo({
    required this.name,
    required this.icon,
    required this.color,
  });
}

/// 学科列表
const List<SubjectInfo> kSubjects = [
  SubjectInfo(name: '语文', icon: 'book', color: Color(0xFFE53935)),
  SubjectInfo(name: '数学', icon: 'calculate', color: Color(0xFF1E88E5)),
  SubjectInfo(name: '英语', icon: 'translate', color: Color(0xFF43A047)),
  SubjectInfo(name: '物理', icon: 'science', color: Color(0xFFFB8C00)),
  SubjectInfo(name: '化学', icon: 'biotech', color: Color(0xFF8E24AA)),
  SubjectInfo(name: '生物', icon: 'eco', color: Color(0xFF00ACC1)),
  SubjectInfo(name: '历史', icon: 'history_edu', color: Color(0xFF6D4C41)),
  SubjectInfo(name: '地理', icon: 'public', color: Color(0xFF3949AB)),
  SubjectInfo(name: '政治', icon: 'gavel', color: Color(0xFFD81B60)),
  SubjectInfo(name: '其他', icon: 'category', color: Color(0xFF757575)),
];

/// 学科名称列表
const List<String> kSubjectNames = [
  '语文', '数学', '英语', '物理', '化学', '生物', '历史', '地理', '政治', '其他',
];

/// 学科颜色映射
const Map<String, Color> kSubjectColors = {
  '语文': Color(0xFFE53935),
  '数学': Color(0xFF1E88E5),
  '英语': Color(0xFF43A047),
  '物理': Color(0xFFFB8C00),
  '化学': Color(0xFF8E24AA),
  '生物': Color(0xFF00ACC1),
  '历史': Color(0xFF6D4C41),
  '地理': Color(0xFF3949AB),
  '政治': Color(0xFFD81B60),
  '其他': Color(0xFF757575),
};

/// 学科图标映射
const Map<String, String> kSubjectIcons = {
  '语文': 'book',
  '数学': 'calculate',
  '英语': 'translate',
  '物理': 'science',
  '化学': 'biotech',
  '生物': 'eco',
  '历史': 'history_edu',
  '地理': 'public',
  '政治': 'gavel',
  '其他': 'category',
};

/// 难度等级
enum DifficultyLevel {
  easy('简单', 1),
  medium('中等', 2),
  hard('困难', 3);

  const DifficultyLevel(this.label, this.value);
  final String label;
  final int value;
}

/// 难度等级列表
const List<Map<String, dynamic>> kDifficultyLevels = [
  {'label': '简单', 'value': 1, 'color': Color(0xFF43A047)},
  {'label': '中等', 'value': 2, 'color': Color(0xFFFB8C00)},
  {'label': '困难', 'value': 3, 'color': Color(0xFFE53935)},
];

/// 错题类型
enum ErrorType {
  concept('概念错误'),
  calculation('计算错误'),
  careless('粗心大意'),
  method('方法错误'),
  incomplete('未完成'),
  unknown('未知');

  const ErrorType(this.label);
  final String label;
}

/// 错题类型列表
const List<Map<String, String>> kErrorTypes = [
  {'label': '概念错误', 'value': 'concept'},
  {'label': '计算错误', 'value': 'calculation'},
  {'label': '粗心大意', 'value': 'careless'},
  {'label': '方法错误', 'value': 'method'},
  {'label': '未完成', 'value': 'incomplete'},
  {'label': '未知', 'value': 'unknown'},
];

/// 记忆分类（艾宾浩斯遗忘曲线）
enum MemoryCategory {
  newLearn('新学', Color(0xFFE53935)),
  review1('1天后复习', Color(0xFFFB8C00)),
  review2('2天后复习', Color(0xFFFDD835)),
  review3('4天后复习', Color(0xFF43A047)),
  review4('7天后复习', Color(0xFF1E88E5)),
  review5('15天后复习', Color(0xFF8E24AA)),
  mastered('已掌握', Color(0xFF78909C));

  const MemoryCategory(this.label, this.color);
  final String label;
  final Color color;
}

/// 记忆分类列表
const List<Map<String, dynamic>> kMemoryCategories = [
  {'label': '新学', 'value': 'new', 'color': Color(0xFFE53935)},
  {'label': '1天后复习', 'value': 'review1', 'color': Color(0xFFFB8C00)},
  {'label': '2天后复习', 'value': 'review2', 'color': Color(0xFFFDD835)},
  {'label': '4天后复习', 'value': 'review3', 'color': Color(0xFF43A047)},
  {'label': '7天后复习', 'value': 'review4', 'color': Color(0xFF1E88E5)},
  {'label': '15天后复习', 'value': 'review5', 'color': Color(0xFF8E24AA)},
  {'label': '已掌握', 'value': 'mastered', 'color': Color(0xFF78909C)},
];

/// 应用主题色
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF1565C0);
  static const Color primaryLight = Color(0xFF5E92F3);
  static const Color primaryDark = Color(0xFF003C8F);
  static const Color secondary = Color(0xFF00897B);
  static const Color secondaryLight = Color(0xFF4EBAAA);
  static const Color secondaryDark = Color(0xFF005B4F);
  static const Color surface = Color(0xFFF8F9FA);
  static const Color background = Color(0xFFF5F5F5);
  static const Color error = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFF57C00);
  static const Color success = Color(0xFF388E3C);
  static const Color info = Color(0xFF1976D2);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color shadow = Color(0x1A000000);
}

/// 应用间距
class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

/// 应用圆角
class AppRadius {
  AppRadius._();

  static const double sm = 4.0;
  static const double md = 8.0;
  static const double lg = 12.0;
  static const double xl = 16.0;
  static const double xxl = 24.0;
  static const double circular = 100.0;
}

/// 应用字体大小
class AppFontSize {
  AppFontSize._();

  static const double xs = 10.0;
  static const double sm = 12.0;
  static const double md = 14.0;
  static const double lg = 16.0;
  static const double xl = 18.0;
  static const double xxl = 22.0;
  static const double title = 24.0;
  static const double headline = 28.0;
}

/// 掌握度等级
enum MasteryLevel {
  none('未掌握', 0, Color(0xFFE53935)),
  low('初步了解', 25, Color(0xFFFB8C00)),
  medium('基本掌握', 50, Color(0xFFFDD835)),
  good('较好掌握', 75, Color(0xFF43A047)),
  excellent('完全掌握', 100, Color(0xFF1565C0));

  const MasteryLevel(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
}

/// 题目类型
enum QuestionType {
  singleChoice('单选题'),
  multipleChoice('多选题'),
  fillBlank('填空题'),
  shortAnswer('简答题'),
  trueFalse('判断题'),
  proof('证明题'),
  essay('论述题');

  const QuestionType(this.label);
  final String label;
}
