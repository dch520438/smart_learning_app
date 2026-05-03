import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'constants.dart';

/// 日期格式化
String formatDate(DateTime date, {String pattern = 'yyyy-MM-dd'}) {
  return DateFormat(pattern).format(date);
}

/// 日期时间格式化
String formatDateTime(DateTime date, {String pattern = 'yyyy-MM-dd HH:mm'}) {
  return DateFormat(pattern).format(date);
}

/// 友好时间显示（如：刚刚、5分钟前、1小时前等）
String formatFriendlyTime(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date);

  if (difference.inSeconds < 60) {
    return '刚刚';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes}分钟前';
  } else if (difference.inHours < 24) {
    return '${difference.inHours}小时前';
  } else if (difference.inDays < 7) {
    return '${difference.inDays}天前';
  } else if (difference.inDays < 30) {
    return '${(difference.inDays / 7).floor()}周前';
  } else if (difference.inDays < 365) {
    return '${(difference.inDays / 30).floor()}个月前';
  } else {
    return formatDate(date);
  }
}

/// 时长格式化（秒转为可读格式）
String formatDuration(int seconds) {
  if (seconds < 60) {
    return '$seconds秒';
  } else if (seconds < 3600) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return secs > 0 ? '$minutes分${secs}秒' : '$minutes分钟';
  } else {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return minutes > 0 ? '$hours小时${minutes}分' : '$hours小时';
  }
}

/// 时长格式化为考试计时器格式（HH:MM:SS）
String formatTimerDuration(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

/// 生成唯一ID
String generateId() {
  return DateTime.now().millisecondsSinceEpoch.toString() +
      (DateTime.now().microsecond % 1000).toString().padLeft(3, '0');
}

/// 获取学科颜色
Color getSubjectColor(String subjectName) {
  return kSubjectColors[subjectName] ?? kSubjectColors['其他']!;
}

/// 获取学科图标
String getSubjectIcon(String subjectName) {
  return kSubjectIcons[subjectName] ?? kSubjectIcons['其他']!;
}

/// 计算掌握度（基于正确率和练习次数）
/// correctCount: 正确次数, totalCount: 总练习次数
int calculateMastery({required int correctCount, required int totalCount}) {
  if (totalCount == 0) return 0;
  final accuracy = correctCount / totalCount;
  // 综合考虑正确率和练习次数
  // 练习次数越多，掌握度评估越准确
  final frequencyFactor = totalCount >= 10 ? 1.0 : totalCount / 10;
  final mastery = (accuracy * 100 * frequencyFactor).round();
  return mastery.clamp(0, 100);
}

/// 获取掌握度对应的颜色
Color getMasteryColor(int mastery) {
  if (mastery < 25) return const Color(0xFFE53935);
  if (mastery < 50) return const Color(0xFFFB8C00);
  if (mastery < 75) return const Color(0xFFFDD835);
  if (mastery < 100) return const Color(0xFF43A047);
  return const Color(0xFF1565C0);
}

/// 获取掌握度对应的文字描述
String getMasteryLabel(int mastery) {
  if (mastery == 0) return '未掌握';
  if (mastery < 25) return '初步了解';
  if (mastery < 50) return '基本掌握';
  if (mastery < 75) return '较好掌握';
  if (mastery < 100) return '熟练掌握';
  return '完全掌握';
}

/// 获取难度对应的颜色
Color getDifficultyColor(int difficulty) {
  switch (difficulty) {
    case 1:
      return const Color(0xFF43A047);
    case 2:
      return const Color(0xFFFB8C00);
    case 3:
      return const Color(0xFFE53935);
    default:
      return const Color(0xFF757575);
  }
}

/// 获取难度对应的文字
String getDifficultyLabel(int difficulty) {
  switch (difficulty) {
    case 1:
      return '简单';
    case 2:
      return '中等';
    case 3:
      return '困难';
    default:
      return '未知';
  }
}

/// 防抖函数
Timer? _debounceTimer;

void debounce(Duration duration, VoidCallback callback) {
  _debounceTimer?.cancel();
  _debounceTimer = Timer(duration, callback);
}

/// 验证邮箱格式
bool isValidEmail(String email) {
  final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  return regex.hasMatch(email);
}

/// 验证手机号格式（中国大陆）
bool isValidPhone(String phone) {
  final regex = RegExp(r'^1[3-9]\d{9}$');
  return regex.hasMatch(phone);
}

/// 截断文本
String truncateText(String text, int maxLength) {
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength)}...';
}

/// 显示SnackBar
void showSnackBar(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}

/// 解析十六进制颜色字符串
Color parseColor(String hexString) {
  final hexCode = hexString.replaceAll('#', '');
  if (hexCode.length == 6) {
    return Color(int.parse('FF$hexCode', radix: 16));
  } else if (hexCode.length == 8) {
    return Color(int.parse(hexCode, radix: 16));
  }
  return const Color(0xFF757575);
}

/// 将颜色转为十六进制字符串
String colorToHex(Color color) {
  return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
}
