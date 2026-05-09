import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/usage_record.dart';
import 'database_service.dart';

/// APP使用时间记录服务
/// 
/// 功能：
/// 1. 自动记录用户打开APP的时间
/// 2. 自动计算每次使用时长
/// 3. 按天统计总学习时间
/// 4. 提供今日、本周、本月学习时间查询
/// 5. 学习时间趋势分析
class UsageTimeService extends WidgetsBindingObserver {
  static final UsageTimeService _instance = UsageTimeService._internal();
  factory UsageTimeService() => _instance;
  UsageTimeService._internal();

  final DatabaseService _db = DatabaseService();

  // 当前会话记录
  UsageRecord? _currentSession;

  // 会话超时时间（毫秒）- 如果APP在后台超过这个时间，视为新会话
  static const int _sessionTimeout = 5 * 60 * 1000; // 5分钟

  // 上次进入前台的时间
  int? _lastForegroundTime;

  // 是否已初始化
  bool _isInitialized = false;

  // 流控制器，用于通知学习时间变化
  final _studyTimeController = StreamController<void>.broadcast();
  Stream<void> get onStudyTimeUpdated => _studyTimeController.stream;

  /// 初始化服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 添加应用生命周期监听
    WidgetsBinding.instance.addObserver(this);

    // 恢复上次的会话（如果有）
    await _restoreLastSession();

    // 开始新会话
    await _startNewSession();

    _isInitialized = true;
  }

  /// 释放资源
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _studyTimeController.close();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final now = DateTime.now().millisecondsSinceEpoch;

    switch (state) {
      case AppLifecycleState.resumed:
        // APP进入前台
        _lastForegroundTime = now;

        // 检查是否需要开始新会话（如果上次离开超过5分钟）
        if (_currentSession != null && _currentSession!.endTime != null) {
          final timeAway = now - _currentSession!.endTime!;
          if (timeAway > _sessionTimeout) {
            // 结束旧会话
            _completeCurrentSession();
            // 开始新会话
            _startNewSession();
          } else {
            // 恢复会话，清除结束时间
            _currentSession = _currentSession!.copyWith(endTime: null);
          }
        } else if (_currentSession == null) {
          _startNewSession();
        }
        break;

      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // APP进入后台或失去焦点
        if (_currentSession != null) {
          _currentSession = _currentSession!.copyWith(
            endTime: now,
          );
          // 更新数据库中的记录
          _updateSessionInDatabase();
        }
        break;

      case AppLifecycleState.detached:
        // APP被销毁
        _completeCurrentSession();
        break;

      case AppLifecycleState.hidden:
        // APP被隐藏（iOS）
        if (_currentSession != null) {
          _currentSession = _currentSession!.copyWith(endTime: now);
          _updateSessionInDatabase();
        }
        break;
    }
  }

  /// 开始新会话
  Future<void> _startNewSession() async {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    _currentSession = UsageRecord(
      startTime: now.millisecondsSinceEpoch,
      date: dateStr,
    );

    // 保存到数据库
    await _insertSessionToDatabase();

    // 保存会话ID到SharedPreferences，用于恢复
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_usage_session_id', _currentSession!.id);
  }

  /// 完成当前会话
  Future<void> _completeCurrentSession() async {
    if (_currentSession == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final duration = ((now - _currentSession!.startTime) / 1000).round();

    _currentSession = _currentSession!.copyWith(
      endTime: now,
      duration: duration,
    );

    await _updateSessionInDatabase();

    // 清除当前会话
    _currentSession = null;

    // 清除SharedPreferences中的会话ID
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_usage_session_id');

    // 通知学习时间更新
    _studyTimeController.add(null);
  }

  /// 恢复上次会话
  Future<void> _restoreLastSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('current_usage_session_id');

    if (sessionId != null) {
      // 从数据库查询未完成的会话
      final session = await _db.queryUsageRecordById(sessionId);
      if (session != null && session['end_time'] == null) {
        // 恢复会话
        _currentSession = UsageRecord.fromJson(session);
      } else {
        // 会话已完成，清除记录
        await prefs.remove('current_usage_session_id');
      }
    }
  }

  /// 插入会话到数据库
  Future<void> _insertSessionToDatabase() async {
    if (_currentSession == null) return;
    await _db.insertUsageRecord(_currentSession!.toJson());
  }

  /// 更新会话到数据库
  Future<void> _updateSessionInDatabase() async {
    if (_currentSession == null) return;
    await _db.updateUsageRecord(
      _currentSession!.id,
      _currentSession!.toJson(),
    );
  }

  // ==================== 查询方法 ====================

  /// 获取今日学习时长（秒）
  Future<int> getTodayStudyTime() async {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final records = await _db.queryUsageRecordsByDate(dateStr);
    int totalSeconds = 0;

    for (final record in records) {
      final duration = record['duration'] as int?;
      if (duration != null) {
        totalSeconds += duration;
      } else {
        // 如果会话未完成，计算从开始到现在的时长
        final startTime = record['start_time'] as int;
        final elapsed = ((DateTime.now().millisecondsSinceEpoch - startTime) / 1000).round();
        totalSeconds += elapsed;
      }
    }

    // 加上当前会话的时长（如果有）
    if (_currentSession != null && _currentSession!.date == dateStr) {
      final elapsed = ((DateTime.now().millisecondsSinceEpoch - _currentSession!.startTime) / 1000).round();
      totalSeconds += elapsed;
    }

    return totalSeconds;
  }

  /// 获取本周学习时长（秒）
  Future<int> getWeekStudyTime() async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final startDate = '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
    final endDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return await _getStudyTimeByDateRange(startDate, endDate);
  }

  /// 获取本月学习时长（秒）
  Future<int> getMonthStudyTime() async {
    final now = DateTime.now();
    final startDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    final endDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return await _getStudyTimeByDateRange(startDate, endDate);
  }

  /// 获取指定日期范围的学习时长
  Future<int> _getStudyTimeByDateRange(String startDate, String endDate) async {
    final records = await _db.queryUsageRecordsByDateRange(startDate, endDate);
    int totalSeconds = 0;

    for (final record in records) {
      final duration = record['duration'] as int?;
      if (duration != null) {
        totalSeconds += duration;
      }
    }

    return totalSeconds;
  }

  /// 获取最近N天的学习数据
  Future<List<DailyStudyData>> getRecentDailyStudyData(int days) async {
    final result = <DailyStudyData>[];
    final now = DateTime.now();

    for (int i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final records = await _db.queryUsageRecordsByDate(dateStr);
      int totalSeconds = 0;
      int sessionCount = 0;

      for (final record in records) {
        final duration = record['duration'] as int?;
        if (duration != null) {
          totalSeconds += duration;
          sessionCount++;
        }
      }

      // 如果是今天，加上当前会话
      if (i == 0 && _currentSession != null) {
        final elapsed = ((DateTime.now().millisecondsSinceEpoch - _currentSession!.startTime) / 1000).round();
        totalSeconds += elapsed;
        if (elapsed > 0) sessionCount++;
      }

      final weekdays = ['日', '一', '二', '三', '四', '五', '六'];

      result.add(DailyStudyData(
        date: dateStr,
        duration: totalSeconds,
        sessionCount: sessionCount,
        weekday: '周${weekdays[date.weekday % 7]}',
      ));
    }

    return result;
  }

  /// 获取学习时间统计
  Future<StudyTimeStatistics> getStudyTimeStatistics({
    required String period, // 'day', 'week', 'month'
    String? specificDate,
  }) async {
    final now = DateTime.now();
    String periodKey;
    int totalDuration = 0;
    int sessionCount = 0;
    int? longestSession;
    List<DailyStudyData>? dailyData;

    switch (period) {
      case 'day':
        final date = specificDate ?? '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        periodKey = date;

        final records = await _db.queryUsageRecordsByDate(date);
        for (final record in records) {
          final duration = record['duration'] as int? ?? 0;
          totalDuration += duration;
          sessionCount++;
          if (longestSession == null || duration > longestSession) {
            longestSession = duration;
          }
        }
        break;

      case 'week':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        periodKey = '${now.year}-W${now.weekday}';

        dailyData = await getRecentDailyStudyData(7);
        for (final day in dailyData) {
          totalDuration += day.duration;
          sessionCount += day.sessionCount;
          if (longestSession == null || day.duration > longestSession) {
            longestSession = day.duration;
          }
        }
        break;

      case 'month':
        periodKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

        // 获取当月所有日期
        final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
        dailyData = [];

        for (int day = 1; day <= daysInMonth; day++) {
          final date = DateTime(now.year, now.month, day);
          if (date.isAfter(now)) break;

          final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          final records = await _db.queryUsageRecordsByDate(dateStr);

          int dayDuration = 0;
          int daySessions = 0;

          for (final record in records) {
            final duration = record['duration'] as int? ?? 0;
            dayDuration += duration;
            if (duration > 0) daySessions++;
          }

          totalDuration += dayDuration;
          sessionCount += daySessions;

          if (longestSession == null || dayDuration > longestSession) {
            longestSession = dayDuration;
          }

          dailyData.add(DailyStudyData(
            date: dateStr,
            duration: dayDuration,
            sessionCount: daySessions,
          ));
        }
        break;

      default:
        periodKey = '';
    }

    final averageDuration = sessionCount > 0 ? totalDuration / sessionCount : 0.0;

    return StudyTimeStatistics(
      period: periodKey,
      totalDuration: totalDuration,
      sessionCount: sessionCount,
      averageDuration: averageDuration,
      longestSession: longestSession,
      dailyData: dailyData,
    );
  }

  /// 格式化时长为可读字符串
  static String formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0) {
      return '$hours小时${minutes > 0 ? '$minutes分钟' : ''}';
    } else if (minutes > 0) {
      return '$minutes分钟';
    } else {
      return '$seconds秒';
    }
  }

  /// 格式化时长为短字符串（用于图表显示）
  static String formatDurationShort(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}h${minutes > 0 ? '${minutes}m' : ''}';
    } else {
      return '${minutes}m';
    }
  }
}
