/// 习惯打卡记录模型
class HabitCheckIn {
  final String id;
  final DateTime checkInTime;
  final String? note;
  final int? mood; // 1-5 心情评分

  HabitCheckIn({
    required this.id,
    required this.checkInTime,
    this.note,
    this.mood,
  });

  factory HabitCheckIn.fromJson(Map<String, dynamic> json) {
    return HabitCheckIn(
      id: json['id'] as String,
      checkInTime: DateTime.parse(json['checkInTime'] as String),
      note: json['note'] as String?,
      mood: json['mood'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'checkInTime': checkInTime.toIso8601String(),
      'note': note,
      'mood': mood,
    };
  }

  HabitCheckIn copyWith({
    String? id,
    DateTime? checkInTime,
    String? note,
    int? mood,
  }) {
    return HabitCheckIn(
      id: id ?? this.id,
      checkInTime: checkInTime ?? this.checkInTime,
      note: note ?? this.note,
      mood: mood ?? this.mood,
    );
  }
}

/// 习惯模型
class Habit {
  final String id;
  final String name;
  final String? description;
  final int targetDays; // 目标天数
  final int currentStreak; // 当前连续打卡天数
  final int totalCompletedDays; // 总完成天数
  final DateTime createdAt;
  final DateTime? completedAt; // 完成时间（达到目标后）
  final bool isActive; // 是否进行中
  final String? icon; // 图标名称
  final int? color; // 主题颜色
  final int? reminderHour; // 提醒时间（小时）
  final int? reminderMinute; // 提醒时间（分钟）
  final bool reminderEnabled; // 是否开启提醒
  final List<HabitCheckIn> checkIns; // 打卡记录列表

  Habit({
    required this.id,
    required this.name,
    this.description,
    required this.targetDays,
    this.currentStreak = 0,
    this.totalCompletedDays = 0,
    required this.createdAt,
    this.completedAt,
    this.isActive = true,
    this.icon,
    this.color,
    this.reminderHour,
    this.reminderMinute,
    this.reminderEnabled = false,
    this.checkIns = const [],
  });

  factory Habit.fromJson(Map<String, dynamic> json) {
    List<HabitCheckIn> checkIns = [];
    if (json['checkIns'] != null) {
      checkIns = (json['checkIns'] as List)
          .map((e) => HabitCheckIn.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return Habit(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      targetDays: json['targetDays'] as int,
      currentStreak: json['currentStreak'] as int? ?? 0,
      totalCompletedDays: json['totalCompletedDays'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      isActive: json['isActive'] as bool? ?? true,
      icon: json['icon'] as String?,
      color: json['color'] as int?,
      reminderHour: json['reminderHour'] as int?,
      reminderMinute: json['reminderMinute'] as int?,
      reminderEnabled: json['reminderEnabled'] as bool? ?? false,
      checkIns: checkIns,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'targetDays': targetDays,
      'currentStreak': currentStreak,
      'totalCompletedDays': totalCompletedDays,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'isActive': isActive,
      'icon': icon,
      'color': color,
      'reminderHour': reminderHour,
      'reminderMinute': reminderMinute,
      'reminderEnabled': reminderEnabled,
      'checkIns': checkIns.map((e) => e.toJson()).toList(),
    };
  }

  Habit copyWith({
    String? id,
    String? name,
    String? description,
    int? targetDays,
    int? currentStreak,
    int? totalCompletedDays,
    DateTime? createdAt,
    DateTime? completedAt,
    bool? isActive,
    String? icon,
    int? color,
    int? reminderHour,
    int? reminderMinute,
    bool? reminderEnabled,
    List<HabitCheckIn>? checkIns,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      targetDays: targetDays ?? this.targetDays,
      currentStreak: currentStreak ?? this.currentStreak,
      totalCompletedDays: totalCompletedDays ?? this.totalCompletedDays,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      isActive: isActive ?? this.isActive,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      checkIns: checkIns ?? this.checkIns,
    );
  }

  /// 检查今天是否已打卡
  bool get isCheckedInToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return checkIns.any((checkIn) {
      final checkInDate = DateTime(
        checkIn.checkInTime.year,
        checkIn.checkInTime.month,
        checkIn.checkInTime.day,
      );
      return checkInDate.isAtSameMomentAs(today);
    });
  }

  /// 检查指定日期是否已打卡
  bool isCheckedInOn(DateTime date) {
    final targetDate = DateTime(date.year, date.month, date.day);
    return checkIns.any((checkIn) {
      final checkInDate = DateTime(
        checkIn.checkInTime.year,
        checkIn.checkInTime.month,
        checkIn.checkInTime.day,
      );
      return checkInDate.isAtSameMomentAs(targetDate);
    });
  }

  /// 获取指定日期的打卡记录
  HabitCheckIn? getCheckInOn(DateTime date) {
    final targetDate = DateTime(date.year, date.month, date.day);
    try {
      return checkIns.firstWhere((checkIn) {
        final checkInDate = DateTime(
          checkIn.checkInTime.year,
          checkIn.checkInTime.month,
          checkIn.checkInTime.day,
        );
        return checkInDate.isAtSameMomentAs(targetDate);
      });
    } catch (e) {
      return null;
    }
  }

  /// 获取完成进度百分比
  double get progressPercent {
    if (targetDays <= 0) return 0.0;
    return (totalCompletedDays / targetDays).clamp(0.0, 1.0);
  }

  /// 获取剩余天数
  int get remainingDays {
    return (targetDays - totalCompletedDays).clamp(0, targetDays);
  }

  /// 是否已完成目标
  bool get isCompleted => totalCompletedDays >= targetDays;

  /// 获取提醒时间字符串
  String? get reminderTimeString {
    if (!reminderEnabled || reminderHour == null || reminderMinute == null) {
      return null;
    }
    return '${reminderHour.toString().padLeft(2, '0')}:${reminderMinute.toString().padLeft(2, '0')}';
  }

  /// 计算连续打卡天数
  static int calculateStreak(List<HabitCheckIn> checkIns) {
    if (checkIns.isEmpty) return 0;

    // 按日期排序（降序）
    final sortedDates = checkIns
        .map((c) => DateTime(
              c.checkInTime.year,
              c.checkInTime.month,
              c.checkInTime.day,
            ))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    if (sortedDates.isEmpty) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // 检查今天或昨天是否有打卡
    if (!sortedDates.first.isAtSameMomentAs(today) &&
        !sortedDates.first.isAtSameMomentAs(yesterday)) {
      return 0;
    }

    int streak = 1;
    for (int i = 1; i < sortedDates.length; i++) {
      final prevDate = sortedDates[i - 1];
      final currDate = sortedDates[i];
      final difference = prevDate.difference(currDate).inDays;

      if (difference == 1) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }
}

/// 习惯目标天数选项
class HabitTargetDays {
  static const List<int> presetOptions = [7, 21, 30, 100];

  static String getLabel(int days) {
    switch (days) {
      case 7:
        return '7天 - 一周挑战';
      case 21:
        return '21天 - 习惯养成';
      case 30:
        return '30天 - 月度计划';
      case 100:
        return '100天 - 百日攻坚';
      default:
        return '$days天 - 自定义';
    }
  }
}

/// 习惯图标选项
class HabitIcons {
  static const List<String> options = [
    'book',
    'school',
    'calculate',
    'language',
    'science',
    'history',
    'translate',
    'edit',
    'create',
    'lightbulb',
    'star',
    'favorite',
    'fitness_center',
    'directions_run',
    'self_improvement',
    'timer',
    'alarm',
    'schedule',
    'check_circle',
    'emoji_events',
  ];

  static String getLabel(String icon) {
    final Map<String, String> labels = {
      'book': '阅读',
      'school': '学习',
      'calculate': '数学',
      'language': '语言',
      'science': '科学',
      'history': '历史',
      'translate': '翻译',
      'edit': '写作',
      'create': '创作',
      'lightbulb': '思考',
      'star': '收藏',
      'favorite': '喜爱',
      'fitness_center': '健身',
      'directions_run': '跑步',
      'self_improvement': '提升',
      'timer': '计时',
      'alarm': '提醒',
      'schedule': '计划',
      'check_circle': '完成',
      'emoji_events': '成就',
    };
    return labels[icon] ?? '其他';
  }
}

/// 习惯颜色选项
class HabitColors {
  static const List<int> options = [
    0xFFE53935, // 红色
    0xFFFF7043, // 橙色
    0xFFFFCA28, // 黄色
    0xFF66BB6A, // 绿色
    0xFF42A5F5, // 蓝色
    0xFF5C6BC0, // 靛蓝
    0xFFAB47BC, // 紫色
    0xFFEC407A, // 粉色
    0xFF26A69A, // 青色
    0xFF8D6E63, // 棕色
  ];
}
