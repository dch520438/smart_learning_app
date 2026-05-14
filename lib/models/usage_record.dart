import 'package:uuid/uuid.dart';

/// APP使用记录模型
/// 用于记录用户每次使用APP的开始时间、结束时间和使用时长
class UsageRecord {
  final String id;
  final int startTime; // 开始时间戳（毫秒）
  final int? endTime; // 结束时间戳（毫秒）
  final int? duration; // 使用时长（秒）
  final String? date; // 日期字符串，格式：yyyy-MM-dd
  final String? deviceInfo; // 设备信息（可选）
  final String? appVersion; // APP版本（可选）

  UsageRecord({
    String? id,
    required this.startTime,
    this.endTime,
    this.duration,
    this.date,
    this.deviceInfo,
    this.appVersion,
  }) : id = id ?? const Uuid().v4();

  /// 从JSON创建
  factory UsageRecord.fromJson(Map<String, dynamic> json) {
    return UsageRecord(
      id: json['uuid'] as String? ?? json['id'] as String?,
      startTime: json['start_time'] as int,
      endTime: json['end_time'] as int?,
      duration: json['duration'] as int?,
      date: json['date'] as String?,
      deviceInfo: json['device_info'] as String?,
      appVersion: json['app_version'] as String?,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'uuid': id,
      'start_time': startTime,
      'end_time': endTime,
      'duration': duration,
      'date': date,
      'device_info': deviceInfo,
      'app_version': appVersion,
    };
  }

  /// 复制并修改部分字段
  UsageRecord copyWith({
    String? id,
    int? startTime,
    int? endTime,
    int? duration,
    String? date,
    String? deviceInfo,
    String? appVersion,
  }) {
    return UsageRecord(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      date: date ?? this.date,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      appVersion: appVersion ?? this.appVersion,
    );
  }

  @override
  String toString() {
    return 'UsageRecord(id: $id, startTime: $startTime, endTime: $endTime, duration: $duration, date: $date)';
  }
}

/// 学习时间统计模型
/// 用于按天、周、月统计学习时间
class StudyTimeStatistics {
  final String period; // 周期标识，如：2024-01-01（日）、2024-W01（周）、2024-01（月）
  final int totalDuration; // 总学习时长（秒）
  final int sessionCount; // 学习次数
  final double averageDuration; // 平均每次学习时长（秒）
  final int? longestSession; // 最长单次学习时长（秒）
  final List<DailyStudyData>? dailyData; // 每日详细数据（用于周/月统计）

  StudyTimeStatistics({
    required this.period,
    required this.totalDuration,
    required this.sessionCount,
    required this.averageDuration,
    this.longestSession,
    this.dailyData,
  });

  /// 获取格式化的总时长
  String get formattedTotalDuration {
    final hours = totalDuration ~/ 3600;
    final minutes = (totalDuration % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours小时${minutes > 0 ? '$minutes分钟' : ''}';
    }
    return '$minutes分钟';
  }

  /// 获取格式化的平均时长
  String get formattedAverageDuration {
    final hours = averageDuration ~/ 3600;
    final minutes = (averageDuration % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours小时${minutes > 0 ? '$minutes分钟' : ''}';
    }
    return '$minutes分钟';
  }
}

/// 每日学习数据
class DailyStudyData {
  final String date; // 日期，格式：yyyy-MM-dd
  final int duration; // 学习时长（秒）
  final int sessionCount; // 学习次数
  final String? weekday; // 星期几

  DailyStudyData({
    required this.date,
    required this.duration,
    required this.sessionCount,
    this.weekday,
  });

  /// 获取格式化的时长
  String get formattedDuration {
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h${minutes > 0 ? '${minutes}m' : ''}';
    }
    return '${minutes}m';
  }
}
