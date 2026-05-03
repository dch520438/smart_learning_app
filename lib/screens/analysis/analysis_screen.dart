import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../services/database_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

/// 学习分析与建议页面
class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  late TabController _tabController;

  bool _isLoading = true;

  // ========== Tab1: 学习概览数据 ==========
  // 各学科掌握度（学科名 -> 掌握度 0-100）
  Map<String, double> _subjectMastery = {};
  // 知识点统计
  int _totalKnowledgePoints = 0;
  int _masteredCount = 0;
  int _learningCount = 0;
  int _notStartedCount = 0;
  // 本周/本月学习时长
  int _weekStudyMinutes = 0;
  int _monthStudyMinutes = 0;
  // 学习效率
  double _efficiencyScore = 0.0;

  // ========== Tab2: 薄弱环节数据 ==========
  List<Map<String, dynamic>> _weakPoints = [];

  // ========== Tab3: 学习建议数据 ==========
  List<Map<String, dynamic>> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadOverviewData(),
        _loadWeakPoints(),
        _loadSuggestions(),
      ]);
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // ==================== 加载概览数据 ====================
  Future<void> _loadOverviewData() async {
    final now = DateTime.now();
    final weekStart = now.subtract(const Duration(days: 7)).toIso8601String();
    final monthStart = now.subtract(const Duration(days: 30)).toIso8601String();

    // 1. 知识点统计
    final allKP = await _db.queryAllKnowledgePoints();
    _totalKnowledgePoints = allKP.length;
    _masteredCount = allKP.where((k) => (k['mastery_level'] as int? ?? 0) >= 80).length;
    _learningCount = allKP.where((k) {
      final m = k['mastery_level'] as int? ?? 0;
      return m > 0 && m < 80;
    }).length;
    _notStartedCount = allKP.where((k) => (k['mastery_level'] as int? ?? 0) == 0).length;

    // 2. 按学科计算掌握度
    final subjectKP = <String, List<Map<String, dynamic>>>{};
    for (final kp in allKP) {
      final subject = (kp['subject'] as String?) ?? '其他';
      subjectKP.putIfAbsent(subject, () => []);
      subjectKP[subject]!.add(kp);
    }
    _subjectMastery = subjectKP.map((subject, kps) {
      if (kps.isEmpty) return MapEntry(subject, 0.0);
      final avg = kps.map((k) => (k['mastery_level'] as int? ?? 0)).reduce((a, b) => a + b) / kps.length;
      return MapEntry(subject, avg.toDouble());
    });

    // 3. 学习时长
    final weekRecords = await _db.queryStudyRecordsByDateRange(weekStart, now.toIso8601String());
    final monthRecords = await _db.queryStudyRecordsByDateRange(monthStart, now.toIso8601String());
    _weekStudyMinutes = weekRecords.fold<int>(0, (sum, r) => sum + ((r['duration'] as int?) ?? 0)) ~/ 60;
    _monthStudyMinutes = monthRecords.fold<int>(0, (sum, r) => sum + ((r['duration'] as int?) ?? 0)) ~/ 60;

    // 4. 学习效率（掌握知识点数 / 总学习小时数）
    final totalHours = _monthStudyMinutes / 60.0;
    if (totalHours > 0) {
      _efficiencyScore = (_masteredCount / totalHours).clamp(0.0, 10.0);
    } else {
      _efficiencyScore = 0.0;
    }
  }

  // ==================== 加载薄弱环节 ====================
  Future<void> _loadWeakPoints() async {
    // 查询错题，按知识点/学科聚合
    final wrongQuestions = await _db.queryAllWrongQuestions();

    // 按学科和知识点聚合
    final subjectErrorMap = <String, List<Map<String, dynamic>>>{};
    for (final wq in wrongQuestions) {
      final subject = (wq['subject'] as String?) ?? '其他';
      subjectErrorMap.putIfAbsent(subject, () => []);
      subjectErrorMap[subject]!.add(wq);
    }

    // 查询知识点掌握度
    final allKP = await _db.queryAllKnowledgePoints();
    final kpMastery = <int, int>{};
    for (final kp in allKP) {
      kpMastery[kp['id'] as int] = kp['mastery_level'] as int? ?? 0;
    }

    final weakList = <Map<String, dynamic>>[];

    for (final entry in subjectErrorMap.entries) {
      final subject = entry.key;
      final questions = entry.value;

      // 按知识点分组
      final kpGroup = <int?, List<Map<String, dynamic>>>{};
      for (final q in questions) {
        final kpId = q['knowledge_point_id'] as int?;
        kpGroup.putIfAbsent(kpId, () => []);
        kpGroup[kpId]!.add(q);
      }

      for (final kpEntry in kpGroup.entries) {
        final kpId = kpEntry.key;
        final qs = kpEntry.value;
        final totalErrors = qs.fold<int>(0, (sum, q) => sum + ((q['error_count'] as int?) ?? 1));
        final mastery = kpId != null ? (kpMastery[kpId] ?? 0) : 0;

        // 根据知识点ID查询知识点名称
        String kpName = '综合薄弱点';
        if (kpId != null) {
          final kp = await _db.queryKnowledgePointById(kpId);
          if (kp != null) {
            kpName = kp['title'] as String? ?? '未命名知识点';
          }
        }

        // 生成建议
        String suggestion;
        if (totalErrors >= 5) {
          suggestion = '该知识点已多次出错，建议做更多练习题';
        } else if (mastery < 30) {
          suggestion = '该知识点掌握度较低，建议制作思维导图梳理';
        } else {
          suggestion = '该知识点错误率较高，建议重新学习基础概念';
        }

        weakList.add({
          'name': kpName,
          'subject': subject,
          'errorCount': totalErrors,
          'mastery': mastery,
          'suggestion': suggestion,
        });
      }
    }

    // 按错误次数降序排序
    weakList.sort((a, b) => (b['errorCount'] as int).compareTo(a['errorCount'] as int));
    _weakPoints = weakList;
  }

  // ==================== 加载学习建议 ====================
  Future<void> _loadSuggestions() async {
    final suggestions = <Map<String, dynamic>>[];
    final now = DateTime.now();

    // 1. 今日待复习内容
    final reviewItems = await _db.queryMustRemembersForReview();
    if (reviewItems.isNotEmpty) {
      suggestions.add({
        'icon': Icons.refresh_rounded,
        'title': '今日待复习',
        'description': '您有${reviewItems.length}个知识点需要复习，建议优先复习即将到期的高重要性内容。',
        'priority': '高',
        'priorityColor': AppColors.error,
        'action': '开始复习',
      });
    } else {
      suggestions.add({
        'icon': Icons.check_circle_outline_rounded,
        'title': '今日复习已完成',
        'description': '当前没有待复习的内容，继续保持！可以学习新的知识点。',
        'priority': '低',
        'priorityColor': AppColors.success,
        'action': null,
      });
    }

    // 2. 薄弱学科优先学习建议
    final allKP = await _db.queryAllKnowledgePoints();
    final subjectAvg = <String, double>{};
    final subjectCount = <String, int>{};
    for (final kp in allKP) {
      final subject = (kp['subject'] as String?) ?? '其他';
      subjectAvg[subject] = (subjectAvg[subject] ?? 0) + ((kp['mastery_level'] as int?) ?? 0);
      subjectCount[subject] = (subjectCount[subject] ?? 0) + 1;
    }
    final subjectMasteryMap = subjectAvg.map((k, v) => subjectCount[k]! > 0 ? MapEntry(k, v / subjectCount[k]!) : MapEntry(k, 0.0));
    final sortedSubjects = subjectMasteryMap.entries.toList()..sort((a, b) => a.value.compareTo(b.value));

    if (sortedSubjects.isNotEmpty && sortedSubjects.first.value < 60) {
      final weakSubject = sortedSubjects.first.key;
      final weakMastery = sortedSubjects.first.value;
      suggestions.add({
        'icon': Icons.priority_high_rounded,
        'title': '薄弱学科提醒',
        'description': '$weakSubject平均掌握度仅${weakMastery.toStringAsFixed(0)}%，建议增加该学科的学习时间，重点攻克低掌握度知识点。',
        'priority': '高',
        'priorityColor': AppColors.error,
        'action': '查看详情',
      });
    }

    // 3. 学习计划建议
    final weekRecords = await _db.queryStudyRecordsByDateRange(
      now.subtract(const Duration(days: 7)).toIso8601String(),
      now.toIso8601String(),
    );
    final weekMinutes = weekRecords.fold<int>(0, (sum, r) => sum + ((r['duration'] as int?) ?? 0)) ~/ 60;
    final dailyAvg = weekMinutes / 7;

    if (dailyAvg < 30) {
      suggestions.add({
        'icon': Icons.schedule_rounded,
        'title': '增加学习时间',
        'description': '本周日均学习${dailyAvg.toStringAsFixed(0)}分钟，建议每天至少学习30分钟以上，保持学习节奏。',
        'priority': '中',
        'priorityColor': AppColors.warning,
        'action': '制定计划',
      });
    } else if (dailyAvg >= 60) {
      suggestions.add({
        'icon': Icons.emoji_events_rounded,
        'title': '学习状态良好',
        'description': '本周日均学习${dailyAvg.toStringAsFixed(0)}分钟，保持这个节奏！注意劳逸结合，避免过度疲劳。',
        'priority': '低',
        'priorityColor': AppColors.success,
        'action': null,
      });
    }

    // 4. 艾宾浩斯复习建议
    final unmasteredWQ = await _db.queryUnmasteredWrongQuestions();
    if (unmasteredWQ.isNotEmpty) {
      // 找出超过7天未复习的错题
      final weekAgo = now.subtract(const Duration(days: 7)).millisecondsSinceEpoch;
      final oldWQ = unmasteredWQ.where((q) {
        final lastError = q['last_error_time'] as String?;
        if (lastError == null) return true;
        try {
          return DateTime.parse(lastError).millisecondsSinceEpoch < weekAgo;
        } catch (_) {
          return true;
        }
      }).length;

      if (oldWQ > 0) {
        suggestions.add({
          'icon': Icons.autorenew_rounded,
          'title': '艾宾浩斯复习提醒',
          'description': '有$oldWQ道错题已超过7天未复习，根据遗忘曲线，建议尽快重新练习以巩固记忆。',
          'priority': '高',
          'priorityColor': AppColors.error,
          'action': '去复习',
        });
      }
    }

    // 5. 知识点学习建议
    final notStarted = allKP.where((k) => (k['mastery_level'] as int? ?? 0) == 0).length;
    if (notStarted > 0) {
      suggestions.add({
        'icon': Icons.lightbulb_outline_rounded,
        'title': '开始新知识点',
        'description': '您有$notStarted个知识点尚未开始学习，建议每天学习1-2个新知识点，循序渐进。',
        'priority': '中',
        'priorityColor': AppColors.warning,
        'action': '查看列表',
      });
    }

    // 6. 已掌握知识点巩固
    final mastered = allKP.where((k) => (k['mastery_level'] as int? ?? 0) >= 80).length;
    if (mastered >= 5) {
      suggestions.add({
        'icon': Icons.workspace_premium_rounded,
        'title': '巩固已掌握知识',
        'description': '您已掌握$mastered个知识点，建议定期回顾，通过综合练习检验掌握程度。',
        'priority': '低',
        'priorityColor': AppColors.info,
        'action': '综合练习',
      });
    }

    _suggestions = suggestions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('学习分析'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '学习概览'),
            Tab(text: '薄弱环节'),
            Tab(text: '学习建议'),
          ],
        ),
      ),
      body: _isLoading
          ? const AppLoading(message: '分析中...')
          : RefreshIndicator(
              onRefresh: _loadData,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildWeakPointsTab(),
                  _buildSuggestionsTab(),
                ],
              ),
            ),
    );
  }

  // ====================================================================
  // Tab1: 学习概览
  // ====================================================================
  Widget _buildOverviewTab() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 雷达图
          Text('各学科掌握度', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _subjectMastery.isEmpty
                  ? const AppEmptyState(message: '暂无学科数据', icon: Icons.radar_rounded)
                  : _buildRadarChart(),
            ),
          ),
          const SizedBox(height: 20),

          // 知识点统计
          Text('知识点统计', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _buildKnowledgeStats(theme),
          const SizedBox(height: 20),

          // 学习时长对比
          Text('学习时长对比', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _buildStudyTimeComparison(theme),
          const SizedBox(height: 20),

          // 学习效率
          Text('学习效率指标', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _buildEfficiencyCard(theme),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ==================== 六边形雷达图 ====================
  Widget _buildRadarChart() {
    final entries = _subjectMastery.entries.toList();
    if (entries.isEmpty) return const SizedBox(height: 200);

    const chartSize = 240.0;
    final sides = entries.length < 3 ? 3 : entries.length;

    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          SizedBox(
            width: chartSize,
            height: chartSize,
            child: CustomPaint(
              painter: _RadarChartPainter(
                data: entries.map((e) => e.value).toList(),
                labels: entries.map((e) => e.key).toList(),
                sides: sides,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 图例
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: entries.map((e) {
              final color = getSubjectColor(e.key);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('${e.key} ${e.value.toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ==================== 知识点统计 ====================
  Widget _buildKnowledgeStats(ThemeData theme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildKPStatItem(Icons.library_books_rounded, '知识点总数', _totalKnowledgePoints, AppColors.info),
                _buildKPStatItem(Icons.check_circle_rounded, '已掌握', _masteredCount, AppColors.success),
                _buildKPStatItem(Icons.school_rounded, '学习中', _learningCount, AppColors.warning),
                _buildKPStatItem(Icons.not_started_rounded, '未开始', _notStartedCount, AppColors.textSecondary),
              ],
            ),
            const SizedBox(height: 16),
            // 进度条
            if (_totalKnowledgePoints > 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('总体掌握进度', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text('${(_masteredCount / _totalKnowledgePoints * 100).toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _masteredCount / _totalKnowledgePoints,
                      minHeight: 8,
                      backgroundColor: AppColors.divider,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildKPStatItem(IconData icon, String label, int value, Color color) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 6),
        Text('$value', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  // ==================== 学习时长对比 ====================
  Widget _buildStudyTimeComparison(ThemeData theme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _buildTimeBlock('本周', _weekStudyMinutes, AppColors.primary, Icons.date_range_rounded),
            ),
            Container(width: 1, height: 60, color: AppColors.divider),
            Expanded(
              child: _buildTimeBlock('本月', _monthStudyMinutes, AppColors.secondary, Icons.calendar_month_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeBlock(String label, int minutes, Color color, IconData icon) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final display = hours > 0 ? '$hours小时${mins > 0 ? '$mins分' : ''}' : '$mins分钟';

    return Column(
      children: [
        Icon(icon, size: 28, color: color),
        const SizedBox(height: 8),
        Text(display, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  // ==================== 学习效率 ====================
  Widget _buildEfficiencyCard(ThemeData theme) {
    final effColor = _efficiencyScore >= 3
        ? AppColors.success
        : _efficiencyScore >= 1
            ? AppColors.warning
            : AppColors.error;
    final effLabel = _efficiencyScore >= 3
        ? '优秀'
        : _efficiencyScore >= 1
            ? '良好'
            : _efficiencyScore > 0
                ? '需提升'
                : '暂无数据';

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 效率仪表盘
            SizedBox(
              width: 80,
              height: 80,
              child: CustomPaint(
                painter: _GaugePainter(
                  value: _efficiencyScore,
                  maxValue: 10,
                  color: effColor,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('学习效率指数', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    '${_efficiencyScore.toStringAsFixed(1)}/10',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: effColor),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: effColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(effLabel, style: TextStyle(fontSize: 11, color: effColor, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ====================================================================
  // Tab2: 薄弱环节
  // ====================================================================
  Widget _buildWeakPointsTab() {
    final theme = Theme.of(context);

    if (_weakPoints.isEmpty) {
      return const AppEmptyState(
        message: '暂无薄弱环节，继续保持！',
        icon: Icons.verified_rounded,
      );
    }

    // 按学科分组
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final wp in _weakPoints) {
      final subject = wp['subject'] as String;
      grouped.putIfAbsent(subject, () => []);
      grouped[subject]!.add(wp);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 汇总信息
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('发现${_weakPoints.length}个薄弱知识点', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      Text('涉及${grouped.length}个学科', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 按学科展示
        ...grouped.entries.expand((entry) {
          final subject = entry.key;
          final points = entry.value;
          final color = getSubjectColor(subject);

          return [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SubjectIcon(subjectName: subject, size: 24),
                  const SizedBox(width: 8),
                  Text(subject, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${points.length}个薄弱点', style: const TextStyle(fontSize: 10, color: AppColors.error)),
                  ),
                ],
              ),
            ),
            ...points.map((wp) => _buildWeakPointCard(wp, color)),
            const SizedBox(height: 12),
          ];
        }),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildWeakPointCard(Map<String, dynamic> wp, Color accentColor) {
    final name = wp['name'] as String;
    final subject = wp['subject'] as String;
    final errorCount = wp['errorCount'] as int;
    final mastery = wp['mastery'] as int;
    final suggestion = wp['suggestion'] as String;
    final masteryColor = getMasteryColor(mastery);

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                Expanded(
                  child: Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('错误${errorCount}次', style: const TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 掌握度进度条
            Row(
              children: [
                Text('掌握度', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: mastery / 100.0,
                      minHeight: 6,
                      backgroundColor: AppColors.divider,
                      valueColor: AlwaysStoppedAnimation<Color>(masteryColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('$mastery%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: masteryColor)),
              ],
            ),
            const SizedBox(height: 10),
            // 建议区域
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accentColor.withOpacity(0.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded, size: 16, color: accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(suggestion, style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ====================================================================
  // Tab3: 学习建议
  // ====================================================================
  Widget _buildSuggestionsTab() {
    if (_suggestions.isEmpty) {
      return const AppEmptyState(
        message: '暂无学习建议',
        icon: Icons.tips_and_updates_rounded,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 顶部提示
        Card(
          elevation: 2,
          color: AppColors.primary.withOpacity(0.08),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '以下建议基于您的学习数据智能生成，帮助您更高效地学习。',
                    style: TextStyle(fontSize: 13, color: AppColors.primary, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 建议卡片列表
        ..._suggestions.map((s) => _buildSuggestionCard(s)),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSuggestionCard(Map<String, dynamic> suggestion) {
    final icon = suggestion['icon'] as IconData;
    final title = suggestion['title'] as String;
    final description = suggestion['description'] as String;
    final priority = suggestion['priority'] as String;
    final priorityColor = suggestion['priorityColor'] as Color;
    final action = suggestion['action'] as String?;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 20, color: priorityColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                // 优先级标签
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(priority, style: TextStyle(fontSize: 10, color: priorityColor, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 描述
            Text(description, style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
            // 操作按钮
            if (action != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () {
                    showSnackBar(context, '已记录，即将跳转...');
                  },
                  icon: Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primary),
                  label: Text(action, style: const TextStyle(fontSize: 12, color: AppColors.primary)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==================== 雷达图绘制器 ====================
class _RadarChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;
  final int sides;

  _RadarChartPainter({
    required this.data,
    required this.labels,
    required this.sides,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 30;

    // 绘制背景网格（3层）
    for (int level = 1; level <= 3; level++) {
      final r = radius * level / 3;
      final path = Path();
      for (int i = 0; i < sides; i++) {
        final angle = (2 * pi * i / sides) - pi / 2;
        final x = center.dx + r * cos(angle);
        final y = center.dy + r * sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFE0E0E0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }

    // 绘制从中心到各顶点的线
    for (int i = 0; i < sides; i++) {
      final angle = (2 * pi * i / sides) - pi / 2;
      canvas.drawLine(
        center,
        Offset(center.dx + radius * cos(angle), center.dy + radius * sin(angle)),
        Paint()..color = const Color(0xFFEEEEEE)..strokeWidth = 0.5,
      );
    }

    // 绘制数据区域
    if (data.isNotEmpty) {
      final dataPath = Path();
      for (int i = 0; i < sides && i < data.length; i++) {
        final angle = (2 * pi * i / sides) - pi / 2;
        final value = (data[i] / 100.0).clamp(0.0, 1.0);
        final r = radius * value;
        final x = center.dx + r * cos(angle);
        final y = center.dy + r * sin(angle);
        if (i == 0) {
          dataPath.moveTo(x, y);
        } else {
          dataPath.lineTo(x, y);
        }
      }
      dataPath.close();

      // 填充区域
      canvas.drawPath(
        dataPath,
        Paint()..color = AppColors.primary.withOpacity(0.2),
      );
      // 边框
      canvas.drawPath(
        dataPath,
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      // 绘制数据点
      for (int i = 0; i < sides && i < data.length; i++) {
        final angle = (2 * pi * i / sides) - pi / 2;
        final value = (data[i] / 100.0).clamp(0.0, 1.0);
        final r = radius * value;
        final x = center.dx + r * cos(angle);
        final y = center.dy + r * sin(angle);
        canvas.drawCircle(Offset(x, y), 4, Paint()..color = AppColors.primary);
        canvas.drawCircle(Offset(x, y), 2, Paint()..color = Colors.white);
      }
    }

    // 绘制标签
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < sides && i < labels.length; i++) {
      final angle = (2 * pi * i / sides) - pi / 2;
      final labelRadius = radius + 18;
      final x = center.dx + labelRadius * cos(angle);
      final y = center.dy + labelRadius * sin(angle);

      textPainter.text = TextSpan(
        text: labels[i],
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      );
      textPainter.layout();

      // 根据角度调整对齐方式
      double dx = x;
      double dy = y;
      if (cos(angle).abs() < 0.1) {
        dx -= textPainter.width / 2;
      } else if (cos(angle) > 0) {
        // 右侧
      } else {
        dx -= textPainter.width;
      }
      if (sin(angle) < -0.1) {
        dy -= textPainter.height;
      }

      textPainter.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.sides != sides;
  }
}

// ==================== 仪表盘绘制器 ====================
class _GaugePainter extends CustomPainter {
  final double value;
  final double maxValue;
  final Color color;

  _GaugePainter({
    required this.value,
    required this.maxValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const strokeWidth = 8.0;

    // 背景弧
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi * 0.75,
      pi * 1.5,
      false,
      Paint()
        ..color = AppColors.divider
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // 数值弧
    final fraction = (value / maxValue).clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi * 0.75,
      pi * 1.5 * fraction,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // 中心文字
    final textPainter = TextPainter(
      text: TextSpan(
        text: value.toStringAsFixed(1),
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2 - 2));
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.value != value;
  }
}
