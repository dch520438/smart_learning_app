import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/navigation_provider.dart';
import '../../services/database_service.dart';
import '../../services/usage_time_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import '../knowledge/knowledge_screen.dart';
import '../notes/notes_screen.dart';
import '../exam_papers/exam_papers_screen.dart';
import '../exam/exam_screen.dart';
import '../mind_map/mind_map_screen.dart';
import '../analysis/analysis_screen.dart';
import '../must_remember/must_remember_screen.dart';
import '../wrong_questions/wrong_questions_screen.dart';
import '../mother_questions/mother_questions_screen.dart';
import '../history/history_screen.dart';
import '../print/print_combination_screen.dart';

/// 首页 - 学习仪表盘
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _db = DatabaseService();
  final UsageTimeService _usageTimeService = UsageTimeService();

  // 用户信息
  String _userName = '同学';
  int _dailyStudyGoal = 60; // 每日目标（分钟）
  int _studyStreak = 0;

  // 今日统计数据
  int _todayStudyMinutes = 0;
  int _todayQuestionCount = 0;
  int _todayKnowledgeCount = 0;
  int _todayNoteCount = 0;

  // 待办提醒
  int _pendingReviewCount = 0;
  int _pendingWrongQuestions = 0;

  // 最近学习活动
  List<Map<String, dynamic>> _recentActivities = [];

  // 最近7天学习时长数据
  List<Map<String, dynamic>> _weeklyStudyData = [];

  // 本周和本月学习时间
  int _weekStudyMinutes = 0;
  int _monthStudyMinutes = 0;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();

    // 监听学习时间更新
    _usageTimeService.onStudyTimeUpdated.listen((_) {
      if (mounted) {
        _refreshStudyTime();
      }
    });
  }

  /// 刷新学习时间显示
  Future<void> _refreshStudyTime() async {
    final todaySeconds = await _usageTimeService.getTodayStudyTime();
    final weekSeconds = await _usageTimeService.getWeekStudyTime();
    final monthSeconds = await _usageTimeService.getMonthStudyTime();

    if (mounted) {
      setState(() {
        _todayStudyMinutes = todaySeconds ~/ 60;
        _weekStudyMinutes = weekSeconds ~/ 60;
        _monthStudyMinutes = monthSeconds ~/ 60;
      });
    }
  }

  /// 加载仪表盘所有数据
  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      // 并行加载所有数据
      final results = await Future.wait([
        _loadUserProfile(),
        _loadTodayStats(),
        _loadPendingReminders(),
        _loadRecentActivities(),
        _loadWeeklyStudyData(),
      ]);

      // 用户信息
      final profile = results[0] as Map<String, dynamic>?;
      if (profile != null) {
        _userName = (profile['nickname'] as String?) ?? '同学';
        _dailyStudyGoal = (profile['daily_study_goal'] as int?) ?? 60;
        _studyStreak = (profile['study_streak'] as int?) ?? 0;
      }

      // 今日统计
      final todayStats = results[1] as Map<String, int>;
      _todayStudyMinutes = todayStats['studyMinutes'] ?? 0;
      _todayQuestionCount = todayStats['questionCount'] ?? 0;
      _todayKnowledgeCount = todayStats['knowledgeCount'] ?? 0;
      _todayNoteCount = todayStats['noteCount'] ?? 0;

      // 待办提醒
      final reminders = results[2] as Map<String, int>;
      _pendingReviewCount = reminders['reviewCount'] ?? 0;
      _pendingWrongQuestions = reminders['wrongQuestionCount'] ?? 0;

      // 最近活动
      _recentActivities = results[3] as List<Map<String, dynamic>>;

      // 每周数据
      _weeklyStudyData = results[4] as List<Map<String, dynamic>>;

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 加载用户信息
  Future<Map<String, dynamic>?> _loadUserProfile() async {
    return await _db.getCurrentUserProfile();
  }

  /// 加载今日统计数据
  Future<Map<String, int>> _loadTodayStats() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    // 从使用时间服务获取今日学习时长（更精确）
    final todaySeconds = await _usageTimeService.getTodayStudyTime();
    int studyMinutes = todaySeconds ~/ 60;

    int questionCount = 0;
    int knowledgeCount = 0;
    int noteCount = 0;

    // 从学习记录表获取其他统计
    final todayRecords = await _db.queryStudyRecordsByDateRange(todayStart, todayEnd);
    for (final record in todayRecords) {
      final recordType = record['record_type'] as String? ?? '';
      if (recordType == 'exam' || recordType == 'practice') {
        questionCount++;
      }
      if (recordType == 'knowledge' || recordType == 'web_knowledge') {
        knowledgeCount++;
      }
      if (recordType == 'note') {
        noteCount++;
      }
    }

    // 从知识点和笔记表获取今日新增数量（更精确）
    final allKnowledge = await _db.queryAllKnowledgePoints(limit: 100);
    for (final kp in allKnowledge) {
      final createdAt = kp['created_at'] as String? ?? '';
      if (createdAt.startsWith(todayStart.substring(0, 10))) {
        knowledgeCount++;
      }
    }

    final allNotes = await _db.queryAllNotes(limit: 100);
    for (final note in allNotes) {
      final createdAt = note['created_at'] as String? ?? '';
      if (createdAt.startsWith(todayStart.substring(0, 10))) {
        noteCount++;
      }
    }

    // 同时获取本周和本月数据
    final weekSeconds = await _usageTimeService.getWeekStudyTime();
    final monthSeconds = await _usageTimeService.getMonthStudyTime();
    _weekStudyMinutes = weekSeconds ~/ 60;
    _monthStudyMinutes = monthSeconds ~/ 60;

    return {
      'studyMinutes': studyMinutes,
      'questionCount': questionCount,
      'knowledgeCount': knowledgeCount,
      'noteCount': noteCount,
    };
  }

  /// 加载待办提醒数据
  Future<Map<String, int>> _loadPendingReminders() async {
    // 待复习的必记必背
    final reviewItems = await _db.queryMustRemembersForReview();
    final reviewCount = reviewItems.length;

    // 未掌握的错题
    final unmasteredWrong = await _db.queryUnmasteredWrongQuestions();
    final wrongQuestionCount = unmasteredWrong.length;

    return {
      'reviewCount': reviewCount,
      'wrongQuestionCount': wrongQuestionCount,
    };
  }

  /// 加载最近学习活动
  Future<List<Map<String, dynamic>>> _loadRecentActivities() async {
    final records = await _db.queryAllStudyRecords(limit: 10);
    return records;
  }

  /// 加载最近7天学习时长数据
  Future<List<Map<String, dynamic>>> _loadWeeklyStudyData() async {
    // 从使用时间服务获取最近7天的学习数据
    final dailyData = await _usageTimeService.getRecentDailyStudyData(7);
    final weeklyData = <Map<String, dynamic>>[];

    for (int i = 0; i < dailyData.length; i++) {
      final dayData = dailyData[i];
      final dateParts = dayData.date.split('-');
      final date = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
      );

      weeklyData.add({
        'date': date,
        'label': dayData.weekday ?? '周${['日', '一', '二', '三', '四', '五', '六'][date.weekday % 7]}',
        'minutes': dayData.duration ~/ 60,
        'isToday': i == dailyData.length - 1,
      });
    }

    return weeklyData;
  }

  /// 获取问候语
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '夜深了';
    if (hour < 12) return '早上好';
    if (hour < 14) return '中午好';
    if (hour < 18) return '下午好';
    return '晚上好';
  }

  /// 获取活动类型标签
  String _getActivityTypeLabel(String? recordType) {
    switch (recordType) {
      case 'knowledge':
        return '知识点';
      case 'note':
        return '笔记';
      case 'exam':
        return '测试';
      case 'practice':
        return '练习';
      case 'web_knowledge':
        return '网络知识';
      case 'review':
        return '复习';
      default:
        return '学习';
    }
  }

  /// 获取活动类型颜色
  Color _getActivityTypeColor(String? recordType) {
    switch (recordType) {
      case 'knowledge':
        return Colors.blue;
      case 'note':
        return Colors.green;
      case 'exam':
      case 'practice':
        return Colors.orange;
      case 'web_knowledge':
        return Colors.teal;
      case 'review':
        return Colors.purple;
      default:
        return AppColors.primary;
    }
  }

  /// 获取活动类型图标
  IconData _getActivityTypeIcon(String? recordType) {
    switch (recordType) {
      case 'knowledge':
        return Icons.auto_stories;
      case 'note':
        return Icons.edit_note;
      case 'exam':
      case 'practice':
        return Icons.quiz;
      case 'web_knowledge':
        return Icons.public;
      case 'review':
        return Icons.replay;
      default:
        return Icons.book;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('智慧学习'),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => Navigator.of(context).pushNamed('/search'),
            ),
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {},
            ),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // 计算今日学习进度
    final studyProgress = _dailyStudyGoal > 0
        ? (_todayStudyMinutes / _dailyStudyGoal).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('智慧学习'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).pushNamed('/search'),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==================== 顶部问候语 ====================
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_getGreeting()}，$_userName',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _studyStreak > 0
                                  ? '已连续学习 $_studyStreak 天，继续加油！'
                                  : '今天也要加油学习哦',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Icon(
                          Icons.emoji_events_outlined,
                          color: theme.colorScheme.primary,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ==================== 今日学习概览卡片 ====================
              Text(
                '今日学习概览',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // 环形进度条 - 今日学习时长
                  Expanded(
                    flex: 2,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // 环形进度条
                            SizedBox(
                              width: 100,
                              height: 100,
                              child: CustomPaint(
                                painter: _CircularProgressPainter(
                                  progress: studyProgress,
                                  backgroundColor: isDark
                                      ? Colors.grey[800]!
                                      : Colors.grey[200]!,
                                  progressColor: studyProgress >= 1.0
                                      ? AppColors.success
                                      : theme.colorScheme.primary,
                                  strokeWidth: 8,
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${_todayStudyMinutes}',
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      const Text(
                                        '分钟',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '目标 ${_dailyStudyGoal} 分钟',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 右侧三个小卡片
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        _StatCard(
                          icon: Icons.quiz_outlined,
                          iconColor: Colors.orange,
                          label: '今日做题',
                          value: '$_todayQuestionCount',
                          onTap: () => Navigator.of(context).pushNamed('/wrong_questions'),
                        ),
                        const SizedBox(height: 8),
                        _StatCard(
                          icon: Icons.auto_stories_outlined,
                          iconColor: Colors.blue,
                          label: '新增知识点',
                          value: '$_todayKnowledgeCount',
                          onTap: () {},
                        ),
                        const SizedBox(height: 8),
                        _StatCard(
                          icon: Icons.edit_note_outlined,
                          iconColor: Colors.green,
                          label: '新增笔记',
                          value: '$_todayNoteCount',
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ==================== 待办提醒区域 ====================
              Text(
                '待办提醒',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Card(
                      child: InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MustRememberScreen()),
                        ),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: const Icon(
                                  Icons.alarm,
                                  color: Colors.orange,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$_pendingReviewCount',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '待复习',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Card(
                      child: InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const WrongQuestionsScreen()),
                        ),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: const Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$_pendingWrongQuestions',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '待重做错题',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: (studyProgress >= 1.0
                                        ? AppColors.success
                                        : theme.colorScheme.primary)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Icon(
                                studyProgress >= 1.0
                                    ? Icons.check_circle
                                    : Icons.flag_outlined,
                                color: studyProgress >= 1.0
                                    ? AppColors.success
                                    : theme.colorScheme.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${(studyProgress * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: studyProgress >= 1.0
                                    ? AppColors.success
                                    : theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '目标进度',
                              style: TextStyle(
                                fontSize: 18,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ==================== 快捷入口网格（4x3） ====================
              Text(
                '快捷入口',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
                children: [
                  _QuickEntry(
                    icon: Icons.auto_stories,
                    label: '知识点',
                    color: Colors.blue,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const KnowledgeScreen()),
                    ),
                  ),
                  _QuickEntry(
                    icon: Icons.edit_note,
                    label: '学习笔记',
                    color: Colors.green,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const NotesScreen()),
                    ),
                  ),
                  _QuickEntry(
                    icon: Icons.error_outline,
                    label: '错题本',
                    color: Colors.red,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WrongQuestionsScreen()),
                    ),
                  ),
                  _QuickEntry(
                    icon: Icons.star_outline,
                    label: '必记本',
                    color: Colors.orange,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MustRememberScreen()),
                    ),
                  ),
                  _QuickEntry(
                    icon: Icons.description,
                    label: '试卷集',
                    color: Colors.amber,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ExamPapersScreen()),
                    ),
                  ),
                  _QuickEntry(
                    icon: Icons.psychology,
                    label: '母题本',
                    color: Colors.purple,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MotherQuestionsScreen()),
                    ),
                  ),
                  _QuickEntry(
                    icon: Icons.quiz_outlined,
                    label: '模拟测试',
                    color: Colors.teal,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ExamScreen()),
                    ),
                  ),
                  _QuickEntry(
                    icon: Icons.account_tree_outlined,
                    label: '思维导图',
                    color: Colors.indigo,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MindMapScreen()),
                    ),
                  ),
                  _QuickEntry(
                    icon: Icons.bar_chart,
                    label: '学情分析',
                    color: Colors.cyan,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AnalysisScreen()),
                    ),
                  ),
                  _QuickEntry(
                    icon: Icons.history,
                    label: '历史分数',
                    color: Colors.pink,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HistoryScreen()),
                    ),
                  ),
                  _QuickEntry(
                    icon: Icons.local_fire_department_outlined,
                    label: '习惯打卡',
                    color: Colors.deepOrange,
                    onTap: () => Navigator.of(context).pushNamed('/habits'),
                  ),
                  _QuickEntry(
                    icon: Icons.post_add,
                    label: '组合打印',
                    color: Colors.amber,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PrintCombinationScreen()),
                    ),
                  ),
                  _QuickEntry(
                    icon: Icons.assignment_outlined,
                    label: '智能组卷',
                    color: Colors.deepPurple,
                    onTap: () => Navigator.of(context).pushNamed('/exam'),
                  ),
                  _QuickEntry(
                    icon: Icons.smart_toy,
                    label: 'AI助手',
                    color: Colors.blueAccent,
                    onTap: () => Navigator.of(context).pushNamed('/ai-service'),
                  ),
                  _QuickEntry(
                    icon: Icons.apps,
                    label: '更多功能',
                    color: Colors.grey,
                    onTap: () {
                      // 切换到"我的"页面
                      final navProvider = context.read<NavigationProvider>();
                      navProvider.setIndex(4);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ==================== 学习趋势小图表（最近7天） ====================
              Text(
                '学习趋势',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '最近7天学习时长',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          Text(
                            '单位: 分钟',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.grey[500] : Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 160,
                        child: _weeklyStudyData.isEmpty
                            ? Center(
                                child: Text(
                                  '暂无学习数据',
                                  style: TextStyle(
                                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                                  ),
                                ),
                              )
                            : _buildWeeklyChart(context),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ==================== 最近学习活动列表 ====================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '最近学习活动',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pushNamed('/history'),
                    child: const Text('查看全部'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_recentActivities.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        '暂无学习记录，开始你的第一次学习吧！',
                        style: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                )
              else
                ..._recentActivities.take(5).map((activity) {
                  final title = activity['title'] as String? ?? '无标题';
                  final recordType = activity['record_type'] as String? ?? '';
                  final createdAt = activity['created_at'] as String? ?? '';
                  final typeLabel = _getActivityTypeLabel(recordType);
                  final typeColor = _getActivityTypeColor(recordType);
                  final typeIcon = _getActivityTypeIcon(recordType);

                  DateTime? activityTime;
                  try {
                    activityTime = DateTime.parse(createdAt);
                  } catch (_) {}

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {},
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: typeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(typeIcon, color: typeColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  if (activityTime != null)
                                    Text(
                                      formatFriendlyTime(activityTime),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.grey[500] : Colors.grey[400],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: typeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                typeLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: typeColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建每周学习时长柱状图（使用Container绘制）
  Widget _buildWeeklyChart(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_weeklyStudyData.isEmpty) return const SizedBox.shrink();

    // 计算最大值用于归一化
    final maxMinutes = _weeklyStudyData
        .map((d) => d['minutes'] as int)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    final chartMax = maxMinutes > 0 ? maxMinutes : 1.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: _weeklyStudyData.map((dayData) {
        final minutes = dayData['minutes'] as int;
        final label = dayData['label'] as String;
        final isToday = dayData['isToday'] as bool;
        final barHeight = maxMinutes > 0 ? (minutes / chartMax) : 0.0;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 数值标签
                if (minutes > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '$minutes',
                      style: TextStyle(
                        fontSize: 10,
                        color: isToday
                            ? theme.colorScheme.primary
                            : (isDark ? Colors.grey[400] : Colors.grey[600]),
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 14),
                // 柱状条
                Container(
                  width: double.infinity,
                  height: (barHeight * 100).clamp(4.0, 120.0),
                  decoration: BoxDecoration(
                    color: isToday
                        ? theme.colorScheme.primary
                        : (isDark ? Colors.grey[700] : Colors.grey[300]),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                // 日期标签
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isToday
                        ? theme.colorScheme.primary
                        : (isDark ? Colors.grey[500] : Colors.grey[500]),
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ==================== 自定义绘制：环形进度条 ====================

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;
  final double strokeWidth;

  _CircularProgressPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth * 2) / 2;

    // 背景圆环
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, backgroundPaint);

    // 进度圆环
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      final sweepAngle = 2 * 3.141592653589793 * progress.clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -3.141592653589793 / 2, // 从顶部开始
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.progressColor != progressColor;
  }
}

// ==================== 统计小卡片 ====================

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== 快捷入口 ====================

class _QuickEntry extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickEntry({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
