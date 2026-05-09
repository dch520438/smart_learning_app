import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/database_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

/// 时间范围枚举
enum _TimeRange { week, month, all }

/// 学习历史页面
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseService _db = DatabaseService();
  _TimeRange _selectedRange = _TimeRange.week;

  // 统计数据
  int _totalStudyMinutes = 0;
  int _totalQuestionCount = 0;
  double _averageAccuracy = 0.0;
  int _continuousDays = 0;

  // 考试记录列表（含关联的考试信息）
  List<Map<String, dynamic>> _examRecords = [];

  // 按学科的学习时长
  Map<String, int> _subjectStudyTime = {};

  // 每日学习时长（最近7天）
  Map<String, int> _dailyStudyTime = {};

  // 成绩趋势数据（最近7天）
  List<Map<String, dynamic>> _scoreTrend = [];

  // 展开的记录索引
  final Set<int> _expandedIndices = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      String startDate;
      switch (_selectedRange) {
        case _TimeRange.week:
          startDate = now.subtract(const Duration(days: 7)).toIso8601String();
          break;
        case _TimeRange.month:
          startDate = now.subtract(const Duration(days: 30)).toIso8601String();
          break;
        case _TimeRange.all:
          startDate = '2000-01-01T00:00:00.000';
          break;
      }

      // 1. 查询学习记录
      final studyRecords = await _db.queryStudyRecordsByDateRange(
        startDate,
        now.toIso8601String(),
      );

      // 计算总学习时长（秒转分钟）
      int totalSeconds = 0;
      final subjectTime = <String, int>{};
      final dailyTime = <String, int>{};

      for (final record in studyRecords) {
        final dur = (record['duration'] as int?) ?? 0;
        totalSeconds += dur;
        final subject = (record['subject'] as String?) ?? '其他';
        subjectTime[subject] = (subjectTime[subject] ?? 0) + dur;
        final dateStr = _extractDate(record['created_at'] as String);
        dailyTime[dateStr] = (dailyTime[dateStr] ?? 0) + dur;
      }
      _totalStudyMinutes = totalSeconds ~/ 60;
      _subjectStudyTime = subjectTime.map((k, v) => MapEntry(k, v ~/ 60));
      _dailyStudyTime = dailyTime.map((k, v) => MapEntry(k, v ~/ 60));

      // 2. 查询考试结果
      final examResults = await _db.rawQuery(
        'SELECT er.*, e.title as exam_title, e.subject as exam_subject, '
        'e.total_score as exam_total_score '
        'FROM ${DatabaseService.tableExamResults} er '
        'LEFT JOIN ${DatabaseService.tableExams} e ON er.exam_id = e.id '
        'WHERE er.created_at >= ? AND er.created_at <= ? '
        'ORDER BY er.created_at DESC',
        [startDate, now.toIso8601String()],
      );

      // 计算统计
      int totalQuestions = 0;
      double totalAccuracy = 0;
      int accuracyCount = 0;

      for (final r in examResults) {
        totalQuestions += (r['correct_count'] as int? ?? 0) + (r['wrong_count'] as int? ?? 0);
        final acc = (r['accuracy'] as num?)?.toDouble() ?? 0;
        if (acc > 0) {
          totalAccuracy += acc;
          accuracyCount++;
        }
      }
      _totalQuestionCount = totalQuestions;
      _averageAccuracy = accuracyCount > 0 ? (totalAccuracy / accuracyCount) * 100 : 0;
      _examRecords = examResults;

      // 3. 成绩趋势（按日期聚合）
      final trendMap = <String, List<double>>{};
      for (final r in examResults) {
        final dateStr = _extractDate(r['created_at'] as String);
        final score = (r['score'] as num?)?.toDouble() ?? 0;
        final total = (r['total_count'] as int? ?? 1);
        final pct = total > 0 ? (score / total) * 100 : 0.0;
        trendMap.putIfAbsent(dateStr, () => []);
        trendMap[dateStr]!.add(pct);
      }
      _scoreTrend = trendMap.entries.map((e) {
        final avg = e.value.reduce((a, b) => a + b) / e.value.length;
        return {'date': e.key, 'score': avg};
      }).toList()
        ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

      // 4. 计算连续学习天数
      final allDates = studyRecords
          .map((r) => _extractDate(r['created_at'] as String))
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));
      _continuousDays = _calcContinuousDays(allDates);

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _extractDate(String isoStr) {
    try {
      return DateTime.parse(isoStr).toIso8601String().substring(0, 10);
    } catch (_) {
      return isoStr.substring(0, 10);
    }
  }

  int _calcContinuousDays(List<String> sortedDates) {
    if (sortedDates.isEmpty) return 0;
    int streak = 1;
    for (int i = 0; i < sortedDates.length - 1; i++) {
      final d1 = DateTime.parse(sortedDates[i]);
      final d2 = DateTime.parse(sortedDates[i + 1]);
      if (d1.difference(d2).inDays == 1) {
        streak++;
      } else {
        break;
      }
    }
    // 检查今天或昨天是否有记录
    final today = DateTime.now();
    final latest = DateTime.parse(sortedDates.first);
    if (today.difference(latest).inDays > 1) {
      return 0;
    }
    return streak;
  }

  Future<void> _deleteExamResult(int resultId) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context: context,
      title: '删除考试记录',
      message: '确定要删除这条考试记录吗？此操作不可撤销。',
    );
    if (confirmed == true) {
      await _db.deleteExamResult(resultId);
      showSnackBar(context, '已删除');
      _loadData();
    }
  }

  void _showAddScoreDialog() {
    final TextEditingController examNameController = TextEditingController();
    final TextEditingController scoreController = TextEditingController();
    final TextEditingController totalScoreController = TextEditingController(text: '100');
    String selectedSubject = kSubjectNames.first;
    String selectedSource = 'school'; // 默认学校考试
    DateTime selectedDate = DateTime.now();

    // 来源选项
    final sourceOptions = [
      {'value': 'school', 'label': '学校考试', 'icon': Icons.school},
      {'value': 'offline', 'label': '线下测试', 'icon': Icons.location_on},
      {'value': 'mock', 'label': '模拟测试', 'icon': Icons.computer},
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('添加考试记录'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: examNameController,
                  decoration: const InputDecoration(
                    labelText: '考试名称',
                    hintText: '如：期中考试、模拟测试',
                    prefixIcon: Icon(Icons.edit),
                  ),
                ),
                const SizedBox(height: 16),
                Text('学科', style: TextStyle(fontSize: AppFontSize.md, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kSubjectNames.map((subject) {
                    return AppTag(
                      label: subject,
                      color: getSubjectColor(subject),
                      selected: selectedSubject == subject,
                      onTap: () => setDialogState(() => selectedSubject = subject),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text('来源', style: TextStyle(fontSize: AppFontSize.md, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: sourceOptions.map((source) {
                    return AppTag(
                      label: source['label'] as String,
                      color: selectedSource == source['value'] ? AppColors.info : AppColors.textHint,
                      selected: selectedSource == source['value'],
                      onTap: () => setDialogState(() => selectedSource = source['value'] as String),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: scoreController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '得分',
                          hintText: '0',
                          prefixIcon: Icon(Icons.score),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: totalScoreController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '总分',
                          hintText: '100',
                          prefixIcon: Icon(Icons.format_list_numbered),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('考试日期'),
                  subtitle: Text(formatDate(selectedDate)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                if (examNameController.text.trim().isEmpty) {
                  showSnackBar(context, '请输入考试名称', isError: true);
                  return;
                }
                if (scoreController.text.trim().isEmpty) {
                  showSnackBar(context, '请输入得分', isError: true);
                  return;
                }

                final score = double.tryParse(scoreController.text) ?? 0;
                final totalScore = double.tryParse(totalScoreController.text) ?? 100;
                final accuracy = totalScore > 0 ? score / totalScore : 0;
                final isPassed = accuracy >= 0.6;

                try {
                  // 创建考试记录
                  final examData = {
                    'uuid': generateId(),
                    'title': examNameController.text.trim(),
                    'description': '手动录入的考试记录',
                    'subject': selectedSubject,
                    'exam_type': 'manual',
                    'total_questions': 0,
                    'total_score': totalScore,
                    'time_limit': 0,
                    'passing_score': totalScore * 0.6,
                    'is_completed': 1,
                  };
                  final examId = await _db.insertExam(examData);

                  // 创建考试结果
                  final resultData = {
                    'uuid': generateId(),
                    'exam_id': examId,
                    'score': score,
                    'correct_count': 0,
                    'wrong_count': 0,
                    'total_count': 0,
                    'time_spent': 0,
                    'accuracy': accuracy,
                    'is_passed': isPassed ? 1 : 0,
                    'created_at': selectedDate.toIso8601String(),
                    'source': selectedSource, // 来源：学校/线下/模拟
                    'subject': selectedSubject,
                  };
                  await _db.insertExamResult(resultData);

                  // 添加学习记录
                  final studyRecord = {
                    'uuid': generateId(),
                    'record_type': 'exam',
                    'title': examNameController.text.trim(),
                    'description': '考试得分: $score/$totalScore',
                    'subject': selectedSubject,
                    'duration': 0,
                    'related_id': examId,
                    'related_type': 'exam',
                    'score': score,
                    'is_completed': 1,
                  };
                  await _db.insertStudyRecord(studyRecord);

                  if (mounted) {
                    Navigator.pop(context);
                    showSnackBar(context, '考试记录已添加');
                    _loadData();
                  }
                } catch (e) {
                  if (mounted) {
                    showSnackBar(context, '添加失败: $e', isError: true);
                  }
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('学习历史'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddScoreDialog,
            tooltip: '添加考试记录',
          ),
          PopupMenuButton<_TimeRange>(
            initialValue: _selectedRange,
            onSelected: (val) {
              _selectedRange = val;
              _loadData();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: _TimeRange.week, child: Text('本周')),
              const PopupMenuItem(value: _TimeRange.month, child: Text('本月')),
              const PopupMenuItem(value: _TimeRange.all, child: Text('全部')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedRange == _TimeRange.week
                        ? '本周'
                        : _selectedRange == _TimeRange.month
                            ? '本月'
                            : '全部',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const AppLoading(message: '加载中...')
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 统计概览卡片
                  _buildStatsOverview(theme),
                  const SizedBox(height: 20),

                  // 成绩趋势柱状图
                  _buildScoreTrendChart(theme),
                  const SizedBox(height: 20),

                  // 学习时间统计
                  _buildStudyTimeSection(theme),
                  const SizedBox(height: 20),

                  // 考试记录列表
                  _buildExamRecordList(theme),
                  const SizedBox(height: 40),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddScoreDialog,
        icon: const Icon(Icons.add),
        label: const Text('添加考试'),
      ),
    );
  }

  // ==================== 统计概览 ====================
  Widget _buildStatsOverview(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '学习统计概览',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _StatCard(
              icon: Icons.access_time_rounded,
              iconColor: AppColors.info,
              label: '总学习时长',
              value: _formatMinutes(_totalStudyMinutes),
              bgColor: AppColors.info.withOpacity(0.1),
            ),
            _StatCard(
              icon: Icons.quiz_rounded,
              iconColor: AppColors.secondary,
              label: '总做题数',
              value: '$_totalQuestionCount题',
              bgColor: AppColors.secondary.withOpacity(0.1),
            ),
            _StatCard(
              icon: Icons.check_circle_rounded,
              iconColor: AppColors.success,
              label: '平均正确率',
              value: '${_averageAccuracy.toStringAsFixed(1)}%',
              bgColor: AppColors.success.withOpacity(0.1),
            ),
            _StatCard(
              icon: Icons.local_fire_department_rounded,
              iconColor: AppColors.warning,
              label: '连续学习',
              value: '$_continuousDays天',
              bgColor: AppColors.warning.withOpacity(0.1),
            ),
          ],
        ),
      ],
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '$minutes分钟';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m > 0 ? '$h小时$m分' : '$h小时';
  }

  // ==================== 成绩趋势柱状图 ====================
  Widget _buildScoreTrendChart(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '成绩趋势',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _scoreTrend.isEmpty
                ? SizedBox(
                    height: 180,
                    child: AppEmptyState(
                      message: '暂无考试记录',
                      icon: Icons.bar_chart_rounded,
                    ),
                  )
                : _buildBarChart(),
          ),
        ),
      ],
    );
  }

  Widget _buildBarChart() {
    // 取最近7条数据
    final data = _scoreTrend.length > 7 ? _scoreTrend.sublist(_scoreTrend.length - 7) : _scoreTrend;
    if (data.isEmpty) return const SizedBox(height: 180);

    final maxScore = data.map((d) => d['score'] as double).reduce((a, b) => a > b ? a : b);
    final chartHeight = 160.0;
    final barWidth = 28.0;
    final bottomPadding = 30.0;
    final topPadding = 10.0;

    return SizedBox(
      height: chartHeight + bottomPadding + topPadding,
      child: Stack(
        children: [
          // Y轴参考线
          Positioned.fill(
            bottom: bottomPadding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildYAxis(chartHeight, maxScore),
                const SizedBox(width: 4),
                Expanded(child: _buildGridLines(chartHeight, maxScore)),
              ],
            ),
          ),
          // 柱状图
          Positioned(
            left: 36,
            right: 8,
            bottom: bottomPadding,
            top: topPadding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: data.map((item) {
                final score = item['score'] as double;
                final barHeight = maxScore > 0 ? (score / maxScore) * chartHeight : 0.0;
                final isPass = score >= 60;
                final dateStr = (item['date'] as String).substring(5); // MM-dd
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 分数标签
                    Text(
                      '${score.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: isPass ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // 柱子
                    Container(
                      width: barWidth,
                      height: barHeight.clamp(2.0, chartHeight),
                      decoration: BoxDecoration(
                        color: isPass ? AppColors.success : AppColors.error,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 日期标签
                    SizedBox(
                      width: barWidth + 8,
                      child: Text(
                        dateStr,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYAxis(double height, double maxVal) {
    return SizedBox(
      width: 32,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('${maxVal.toStringAsFixed(0)}', style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
          Text('${(maxVal * 0.5).toStringAsFixed(0)}', style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
          Text('0', style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildGridLines(double height, double maxVal) {
    return SizedBox(
      height: height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(height: 1, color: AppColors.divider),
          Container(height: 1, color: AppColors.divider.withOpacity(0.5)),
          Container(height: 1, color: AppColors.divider),
        ],
      ),
    );
  }

  // ==================== 学习时间统计 ====================
  Widget _buildStudyTimeSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '学习时间统计',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        // 按学科饼图
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('按学科分类', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                _subjectStudyTime.isEmpty
                    ? const AppEmptyState(message: '暂无学习记录', icon: Icons.pie_chart_rounded)
                    : _buildSubjectPieChart(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 每日学习时长柱状图
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('每日学习时长', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                _dailyStudyTime.isEmpty
                    ? const AppEmptyState(message: '暂无学习记录', icon: Icons.bar_chart_rounded)
                    : _buildDailyBarChart(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectPieChart() {
    final entries = _subjectStudyTime.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (sum, e) => sum + e.value);
    if (total == 0) return const SizedBox(height: 100);

    const pieSize = 140.0;
    const legendHeight = 28.0;

    return Column(
      children: [
        SizedBox(
          height: pieSize + 20,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final centerX = constraints.maxWidth / 2;
              final centerY = pieSize / 2 + 10;
              final radius = pieSize / 2 - 4;

              return Stack(
                children: [
                  // 饼图扇形
                  ..._buildPieSlices(centerX, centerY, radius, entries, total),
                  // 中心空白圆（环形图效果）
                  Positioned(
                    left: centerX - 28,
                    top: centerY - 28,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatMinutes(total),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            Text('总计', style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // 图例
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: entries.map((e) {
            final color = getSubjectColor(e.key);
            final pct = total > 0 ? ((e.value / total) * 100).toStringAsFixed(1) : '0';
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text('${e.key} $pct%', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  List<Widget> _buildPieSlices(
    double cx, double cy, double radius,
    List<MapEntry<String, int>> entries, int total,
  ) {
    final slices = <Widget>[];
    double startAngle = -90.0; // 从12点方向开始
    const sweepFull = 360.0;

    for (int i = 0; i < entries.length; i++) {
      final fraction = entries[i].value / total;
      final sweepAngle = fraction * sweepFull;
      if (sweepAngle < 0.5) {
        startAngle += sweepAngle;
        continue;
      }
      final color = getSubjectColor(entries[i].key);

      // 使用 CustomPaint 绘制扇形
      slices.add(
        Positioned.fill(
          child: CustomPaint(
            painter: _PieSlicePainter(
              startAngle: startAngle,
              sweepAngle: sweepAngle,
              color: color,
              cx: cx,
              cy: cy,
              radius: radius,
            ),
          ),
        ),
      );
      startAngle += sweepAngle;
    }
    return slices;
  }

  Widget _buildDailyBarChart() {
    // 最近7天
    final now = DateTime.now();
    final days = <String, int>{};
    for (int i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key = DateFormat('MM-dd').format(d);
      days[key] = _dailyStudyTime[d.toIso8601String().substring(0, 10)] ?? 0;
    }

    final maxVal = days.values.fold<int>(0, (a, b) => a > b ? a : b);
    if (maxVal == 0) return const SizedBox(height: 100);

    final chartHeight = 120.0;

    return SizedBox(
      height: chartHeight + 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: days.entries.map((e) {
          final h = maxVal > 0 ? (e.value / maxVal) * chartHeight : 0.0;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${e.value}m',
                style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Container(
                width: 24,
                height: h.clamp(2.0, chartHeight),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                e.key,
                style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ==================== 考试记录列表 ====================
  Widget _buildExamRecordList(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '考试记录',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              '共${_examRecords.length}条',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _examRecords.isEmpty
            ? const AppEmptyState(message: '暂无考试记录', icon: Icons.assignment_rounded)
            : Column(
                children: _examRecords.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final record = entry.value;
                  final isExpanded = _expandedIndices.contains(idx);
                  return _buildExamRecordCard(record, idx, isExpanded, theme);
                }).toList(),
              ),
      ],
    );
  }

  Widget _buildExamRecordCard(
    Map<String, dynamic> record,
    int index,
    bool isExpanded,
    ThemeData theme,
  ) {
    final title = (record['exam_title'] as String?) ?? '未命名考试';
    final subject = (record['exam_subject'] as String?) ?? '其他';
    final score = (record['score'] as num?)?.toDouble() ?? 0;
    final totalScore = (record['exam_total_score'] as num?)?.toDouble() ?? 100;
    final correctCount = (record['correct_count'] as int?) ?? 0;
    final wrongCount = (record['wrong_count'] as int?) ?? 0;
    final totalCount = correctCount + wrongCount;
    final accuracy = totalCount > 0 ? (correctCount / totalCount * 100) : 0.0;
    final timeSpent = (record['time_spent'] as int?) ?? 0;
    final isPassed = (record['is_passed'] as int?) == 1;
    final createdAt = record['created_at'] as String? ?? '';
    final resultId = record['id'] as int? ?? 0;

    final subjectColor = getSubjectColor(subject);

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedIndices.remove(index);
                } else {
                  _expandedIndices.add(index);
                }
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // 学科图标
                  SubjectIcon(subjectName: subject, size: 36),
                  const SizedBox(width: 12),
                  // 标题和学科
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: subjectColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                subject,
                                style: TextStyle(fontSize: 10, color: subjectColor, fontWeight: FontWeight.w500),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDateShort(createdAt),
                              style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 分数
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${score.toStringAsFixed(0)}/${totalScore.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isPassed ? AppColors.success : AppColors.error,
                        ),
                      ),
                      Text(
                        '${accuracy.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 11,
                          color: accuracy >= 60 ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          // 展开详情
          if (isExpanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  _buildDetailRow(Icons.check_circle_outline, '正确题数', '$correctCount题'),
                  _buildDetailRow(Icons.cancel_outlined, '错误题数', '$wrongCount题'),
                  _buildDetailRow(Icons.format_list_numbered, '总题数', '$totalCount题'),
                  _buildDetailRow(Icons.timer_outlined, '用时', formatDuration(timeSpent)),
                  _buildDetailRow(Icons.calendar_today_outlined, '日期', _formatDateFull(createdAt)),
                  _buildDetailRow(
                    isPassed ? Icons.verified : Icons.warning_amber,
                    '结果',
                    isPassed ? '通过' : '未通过',
                    valueColor: isPassed ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _deleteExamResult(resultId),
                      icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                      label: const Text('删除', style: TextStyle(color: AppColors.error, fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: valueColor ?? AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  String _formatDateShort(String isoStr) {
    try {
      final dt = DateTime.parse(isoStr);
      return DateFormat('MM-dd HH:mm').format(dt);
    } catch (_) {
      return isoStr;
    }
  }

  String _formatDateFull(String isoStr) {
    try {
      final dt = DateTime.parse(isoStr);
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    } catch (_) {
      return isoStr;
    }
  }
}

// ==================== 统计卡片 ====================
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 饼图扇形绘制 ====================
class _PieSlicePainter extends CustomPainter {
  final double startAngle;
  final double sweepAngle;
  final Color color;
  final double cx;
  final double cy;
  final double radius;

  _PieSlicePainter({
    required this.startAngle,
    required this.sweepAngle,
    required this.color,
    required this.cx,
    required this.cy,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);
    canvas.drawArc(rect, _degToRad(startAngle), _degToRad(sweepAngle), true, paint);
  }

  double _degToRad(double deg) => deg * 3.141592653589793 / 180.0;

  @override
  bool shouldRepaint(covariant _PieSlicePainter oldDelegate) => false;
}
