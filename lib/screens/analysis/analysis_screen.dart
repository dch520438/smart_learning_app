import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/analysis_service.dart';
import '../../services/ai_config_service.dart';
import '../../services/database_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

/// 时间段筛选枚举
enum TimeFilter { thisWeek, thisMonth, threeMonths, all }

/// 学习分析页面
class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> with SingleTickerProviderStateMixin {
  final AnalysisService _analysisService = AnalysisService();
  final DatabaseService _db = DatabaseService();
  final AIService _aiService = AIService();

  late TabController _tabController;
  bool _isLoading = true;
  bool _isAiAnalyzing = false;
  String? _aiAnalysisResult;

  // 学科筛选
  List<String> _selectedSubjects = [];

  // 时间段筛选
  TimeFilter _timeFilter = TimeFilter.thisMonth;

  // 所有学科列表
  static const List<String> _allSubjects = ['数学', '语文', '英语', '物理', '化学', '生物', '历史', '地理', '政治'];

  // 分析数据
  Map<String, dynamic> _overallAnalysis = {};
  Map<String, dynamic> _knowledgeMastery = {};
  Map<String, dynamic> _subjectStrength = {};
  Map<String, dynamic> _studyTimeDistribution = {};
  Map<String, dynamic> _wrongQuestionAnalysis = {};
  Map<String, dynamic> _learningTrend = {};
  List<Map<String, dynamic>> _suggestions = [];
  List<Map<String, dynamic>> _recommendedReview = [];
  Map<String, double> _radarData = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
    _aiService.loadConfig();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DateTime? get _startDate {
    final now = DateTime.now();
    switch (_timeFilter) {
      case TimeFilter.thisWeek:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return DateTime(monday.year, monday.month, monday.day);
      case TimeFilter.thisMonth:
        return DateTime(now.year, now.month, 1);
      case TimeFilter.threeMonths:
        final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);
        return threeMonthsAgo;
      case TimeFilter.all:
        return null;
    }
  }

  DateTime? get _endDate {
    if (_timeFilter == TimeFilter.all) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  String get _timeFilterLabel {
    switch (_timeFilter) {
      case TimeFilter.thisWeek: return '本周';
      case TimeFilter.thisMonth: return '本月';
      case TimeFilter.threeMonths: return '近三月';
      case TimeFilter.all: return '全部';
    }
  }

  String _getTimeFilterLabel(TimeFilter filter) {
    switch (filter) {
      case TimeFilter.thisWeek: return '本周';
      case TimeFilter.thisMonth: return '本月';
      case TimeFilter.threeMonths: return '近三月';
      case TimeFilter.all: return '全部时间';
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final subjects = _selectedSubjects.isNotEmpty ? _selectedSubjects : null;
      final results = await Future.wait([
        _analysisService.getOverallAnalysis(
          subjects: subjects,
          startDate: _startDate,
          endDate: _endDate,
        ),
        _analysisService.getKnowledgePointMastery(
          subjects: subjects,
          startDate: _startDate,
          endDate: _endDate,
        ),
        _analysisService.getSubjectStrengthAnalysis(
          subjects: subjects,
          startDate: _startDate,
          endDate: _endDate,
        ),
        _analysisService.getStudyTimeDistribution(
          subjects: subjects,
          startDate: _startDate,
          endDate: _endDate,
        ),
        _analysisService.getWrongQuestionAnalysis(
          subjects: subjects,
          startDate: _startDate,
          endDate: _endDate,
        ),
        _analysisService.getLearningTrend(
          days: _timeFilter == TimeFilter.thisWeek ? 7 : _timeFilter == TimeFilter.thisMonth ? 30 : 90,
          subjects: subjects,
          startDate: _startDate,
          endDate: _endDate,
        ),
        _analysisService.generateLearningSuggestions(
          subjects: subjects,
          startDate: _startDate,
          endDate: _endDate,
        ),
        _analysisService.getRecommendedReview(
          subjects: subjects,
          startDate: _startDate,
          endDate: _endDate,
        ),
        _analysisService.getRadarChartData(
          subjects: subjects,
          startDate: _startDate,
          endDate: _endDate,
        ),
      ]);

      setState(() {
        _overallAnalysis = results[0] as Map<String, dynamic>;
        _knowledgeMastery = results[1] as Map<String, dynamic>;
        _subjectStrength = results[2] as Map<String, dynamic>;
        _studyTimeDistribution = results[3] as Map<String, dynamic>;
        _wrongQuestionAnalysis = results[4] as Map<String, dynamic>;
        _learningTrend = results[5] as Map<String, dynamic>;
        _suggestions = results[6] as List<Map<String, dynamic>>;
        _recommendedReview = results[7] as List<Map<String, dynamic>>;
        _radarData = results[8] as Map<String, double>;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('加载分析数据失败: $e');
      debugPrint('堆栈跟踪: $stackTrace');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载数据失败: $e'),
            action: SnackBarAction(
              label: '重试',
              onPressed: _loadData,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('学习分析'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: '刷新',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: '概览', icon: Icon(Icons.dashboard)),
            Tab(text: '学科分析', icon: Icon(Icons.school)),
            Tab(text: '错题分析', icon: Icon(Icons.error_outline)),
            Tab(text: '学习建议', icon: Icon(Icons.lightbulb)),
            Tab(text: 'AI深度分析', icon: Icon(Icons.psychology)),
          ],
        ),
      ),
      body: _isLoading
          ? const AppLoading(message: '分析中...')
          : Column(
              children: [
                _buildFilterSection(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(theme),
                      _buildSubjectAnalysisTab(theme),
                      _buildWrongQuestionTab(theme),
                      _buildSuggestionsTab(theme),
                      _buildAiAnalysisTab(theme),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ==================== 筛选控件 ====================
  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 时间段筛选
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: TimeFilter.values.map((filter) {
                final isSelected = _timeFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_getTimeFilterLabel(filter)),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _timeFilter = filter);
                        _loadData();
                      }
                    },
                    selectedColor: AppColors.primary.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primary : null,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // 学科筛选
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('全部学科'),
                    selected: _selectedSubjects.isEmpty,
                    onSelected: (_) {
                      setState(() => _selectedSubjects.clear());
                      _loadData();
                    },
                    selectedColor: AppColors.primary.withOpacity(0.2),
                  ),
                ),
                ..._allSubjects.map((subject) {
                  final isSelected = _selectedSubjects.contains(subject);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(subject),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedSubjects.add(subject);
                          } else {
                            _selectedSubjects.remove(subject);
                          }
                        });
                        _loadData();
                      },
                      selectedColor: AppColors.primary.withOpacity(0.2),
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.primary : null,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 概览标签页 ====================
  Widget _buildOverviewTab(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 雷达图卡片
            _buildRadarChartCard(theme),
            const SizedBox(height: 16),

            // 关键指标
            _buildKeyMetricsCard(theme),
            const SizedBox(height: 16),

            // 学习趋势
            _buildTrendCard(theme),
            const SizedBox(height: 16),

            // 推荐复习
            _buildRecommendedReviewCard(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildRadarChartCard(ThemeData theme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.radar, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  '能力雷达图',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _radarData.isEmpty
                  ? const Center(child: Text('暂无数据'))
                  : CustomPaint(
                      size: const Size(double.infinity, 200),
                      painter: RadarChartPainter(data: _radarData),
                    ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _radarData.entries.map((entry) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _getRadarColor(entry.key),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${entry.key}: ${entry.value.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: AppFontSize.sm,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRadarColor(String key) {
    final colors = {
      '知识掌握': AppColors.primary,
      '考试成绩': AppColors.success,
      '学习时长': AppColors.info,
      '错题控制': AppColors.warning,
      '试卷得分': AppColors.secondary,
    };
    return colors[key] ?? AppColors.primary;
  }

  Widget _buildKeyMetricsCard(ThemeData theme) {
    final examResults = _overallAnalysis['examResults'] as Map<String, dynamic>?;
    final studyTime = _overallAnalysis['studyTime'] as Map<String, dynamic>?;
    final wrongQuestions = _overallAnalysis['wrongQuestions'] as Map<String, dynamic>?;
    final examPapers = _overallAnalysis['examPapers'] as Map<String, dynamic>?;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  '关键指标',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildMetricItem(
                  icon: Icons.score,
                  label: '平均成绩',
                  value: '${(examResults?['averageAccuracy'] as num? ?? 0).toStringAsFixed(1)}%',
                  color: AppColors.success,
                ),
                _buildMetricItem(
                  icon: Icons.access_time,
                  label: '学习时长',
                  value: '${studyTime?['totalMinutes'] ?? 0}分钟',
                  color: AppColors.info,
                ),
                _buildMetricItem(
                  icon: Icons.error_outline,
                  label: '错题数量',
                  value: '${wrongQuestions?['total'] ?? 0}道',
                  color: AppColors.error,
                ),
                _buildMetricItem(
                  icon: Icons.description,
                  label: '试卷得分率',
                  value: '${(examPapers?['averageScoreRate'] as num? ?? 0).toStringAsFixed(1)}%',
                  color: AppColors.warning,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: AppFontSize.lg,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: AppFontSize.sm,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendCard(ThemeData theme) {
    final dailyData = _learningTrend['dailyData'] as Map<String, dynamic>? ?? {};
    final dates = _learningTrend['dates'] as List<dynamic>? ?? [];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  '近30天学习趋势',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: dailyData.isEmpty
                  ? const Center(child: Text('暂无数据'))
                  : CustomPaint(
                      size: const Size(double.infinity, 150),
                      painter: TrendChartPainter(
                        data: dailyData,
                        dates: dates.cast<String>(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedReviewCard(ThemeData theme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.book, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  '推荐复习',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_recommendedReview.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('暂无推荐内容'),
                ),
              )
            else
              ..._recommendedReview.take(5).map((item) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: item['priority'] == 'high' ? AppColors.error : AppColors.warning,
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(item['name'] as String),
                  subtitle: item['subject'] != null ? Text(item['subject'] as String) : null,
                  trailing: item['mastery'] != null
                      ? Text(
                          '${(item['mastery'] as num).toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : Text(
                          '${item['count']}次',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ==================== 学科分析标签页 ====================
  Widget _buildSubjectAnalysisTab(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 学科强弱对比
            _buildSubjectStrengthCard(theme),
            const SizedBox(height: 16),

            // 学习时间分布
            _buildTimeDistributionCard(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectStrengthCard(ThemeData theme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.school, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  '学科强弱分析',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._subjectStrength.entries.map((entry) {
              final data = entry.value as Map<String, dynamic>;
              final strength = data['strength'] as String;
              final color = strength == 'strong'
                  ? AppColors.success
                  : strength == 'medium'
                      ? AppColors.warning
                      : AppColors.error;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: AppFontSize.sm,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (data['compositeScore'] as num).toDouble() / 100,
                          minHeight: 8,
                          backgroundColor: AppColors.divider,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        strength == 'strong'
                            ? '强'
                            : strength == 'medium'
                                ? '中'
                                : '弱',
                        style: TextStyle(
                          fontSize: AppFontSize.xs,
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeDistributionCard(ThemeData theme) {
    final byTimeSlot = _studyTimeDistribution['byTimeSlot'] as Map<String, int>? ?? {};
    final byWeekDay = _studyTimeDistribution['byWeekDay'] as Map<String, int>? ?? {};

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  '学习时间分布',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '时段分布',
              style: TextStyle(
                fontSize: AppFontSize.md,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ...byTimeSlot.entries.map((entry) {
              final maxValue = byTimeSlot.values.reduce((a, b) => a > b ? a : b);
              final progress = maxValue > 0 ? entry.value / maxValue : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        entry.key,
                        style: TextStyle(fontSize: AppFontSize.sm),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: AppColors.divider,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.info),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${entry.value}分钟',
                      style: TextStyle(
                        fontSize: AppFontSize.sm,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            Text(
              '星期分布',
              style: TextStyle(
                fontSize: AppFontSize.md,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: byWeekDay.entries.map((entry) {
                return Chip(
                  avatar: Icon(
                    Icons.access_time,
                    size: 16,
                    color: entry.value > 0 ? AppColors.success : AppColors.textHint,
                  ),
                  label: Text('${entry.key}: ${entry.value}分钟'),
                  backgroundColor: entry.value > 0
                      ? AppColors.success.withOpacity(0.1)
                      : AppColors.background,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 错题分析标签页 ====================
  Widget _buildWrongQuestionTab(ThemeData theme) {
    final byErrorType = _wrongQuestionAnalysis['byErrorType'] as Map<String, dynamic>? ?? {};
    final byDifficulty = _wrongQuestionAnalysis['byDifficulty'] as Map<String, dynamic>? ?? {};
    final topKnowledgePoints = _wrongQuestionAnalysis['topKnowledgePoints'] as List<dynamic>? ?? [];

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 错误类型分布
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.pie_chart, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          '错误类型分布',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...byErrorType.entries.map((entry) {
                      final data = entry.value as Map<String, dynamic>;
                      final total = byErrorType.values.fold<int>(
                        0,
                        (sum, item) => sum + ((item as Map<String, dynamic>)['count'] as int? ?? 0),
                      );
                      final count = data['count'] as int? ?? 0;
                      final percentage = total > 0 ? count / total : 0.0;
                      final color = Color(
                        int.parse((data['color'] as String).replaceFirst('#', '0xFF')),
                      );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  data['label'] as String,
                                  style: TextStyle(fontSize: AppFontSize.sm),
                                ),
                                const Spacer(),
                                Text(
                                  '$count道 (${(percentage * 100).toStringAsFixed(1)}%)',
                                  style: TextStyle(
                                    fontSize: AppFontSize.sm,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: percentage,
                                minHeight: 6,
                                backgroundColor: AppColors.divider,
                                valueColor: AlwaysStoppedAnimation<Color>(color),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 难度分布
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bar_chart, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          '错题难度分布',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDifficultyItem(
                            label: '简单',
                            count: byDifficulty['easy'] ?? 0,
                            color: AppColors.success,
                          ),
                        ),
                        Expanded(
                          child: _buildDifficultyItem(
                            label: '中等',
                            count: byDifficulty['medium'] ?? 0,
                            color: AppColors.warning,
                          ),
                        ),
                        Expanded(
                          child: _buildDifficultyItem(
                            label: '困难',
                            count: byDifficulty['hard'] ?? 0,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 高频错题知识点
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          '高频错题知识点',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (topKnowledgePoints.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('暂无数据'),
                        ),
                      )
                    else
                      ...topKnowledgePoints.take(10).map((point) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${point['count']}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                          title: Text(point['name'] as String),
                          trailing: IconButton(
                            icon: const Icon(Icons.arrow_forward_ios, size: 16),
                            onPressed: () {
                              // 跳转到相关练习
                            },
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyItem({
    required String label,
    required int count,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: AppFontSize.sm,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ==================== 学习建议标签页 ====================
  Widget _buildSuggestionsTab(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_suggestions.isEmpty)
              const Card(
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text('暂无学习建议，继续学习以获取更多分析'),
                  ),
                ),
              )
            else
              ..._suggestions.map((suggestion) {
                final priority = suggestion['priority'] as String;
                final color = priority == 'high'
                    ? AppColors.error
                    : priority == 'medium'
                        ? AppColors.warning
                        : AppColors.info;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                priority == 'high'
                                    ? '高优先级'
                                    : priority == 'medium'
                                        ? '中优先级'
                                        : '低优先级',
                                style: TextStyle(
                                  fontSize: AppFontSize.xs,
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              _getSuggestionIcon(suggestion['type'] as String),
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          suggestion['title'] as String,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          suggestion['description'] as String,
                          style: TextStyle(
                            fontSize: AppFontSize.sm,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () {
                              // 执行建议操作
                            },
                            icon: const Icon(Icons.arrow_forward, size: 16),
                            label: Text(suggestion['action'] as String),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  IconData _getSuggestionIcon(String type) {
    switch (type) {
      case 'weak_subject':
        return Icons.school;
      case 'careless':
        return Icons.warning;
      case 'knowledge_gap':
        return Icons.psychology;
      case 'study_time':
        return Icons.schedule;
      case 'knowledge_review':
        return Icons.book;
      case 'exam_practice':
        return Icons.quiz;
      default:
        return Icons.lightbulb;
    }
  }

  // ==================== AI深度分析标签页 ====================
  Widget _buildAiAnalysisTab(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI分析介绍卡片
            _buildAiIntroCard(theme),
            const SizedBox(height: 16),

            // AI分析按钮
            if (_aiAnalysisResult == null && !_isAiAnalyzing)
              _buildAiAnalysisButton(theme),

            // 加载中
            if (_isAiAnalyzing) _buildAiLoadingCard(),

            // AI分析结果
            if (_aiAnalysisResult != null) _buildAiResultCard(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildAiIntroCard(ThemeData theme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(Icons.psychology, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI深度学情分析',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '基于您的学习数据，AI将生成个性化的深度分析报告',
                        style: TextStyle(
                          fontSize: AppFontSize.sm,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiAnalysisButton(ThemeData theme) {
    final isConfigured = _aiService.isConfigured;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (!isConfigured) ...[
              Icon(
                Icons.warning_amber,
                size: 48,
                color: AppColors.warning,
              ),
              const SizedBox(height: 16),
              Text(
                'AI未配置',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '请先配置AI模型以使用深度分析功能',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppFontSize.sm,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _openAISettings(),
                icon: const Icon(Icons.settings),
                label: const Text('配置AI'),
              ),
            ] else ...[
              Icon(
                Icons.auto_awesome,
                size: 64,
                color: AppColors.primary.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                '开始AI深度分析',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'AI将分析您的学习数据，生成个性化的学习建议和改进方案',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppFontSize.sm,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startAiAnalysis,
                  icon: const Icon(Icons.analytics),
                  label: const Text('开始分析'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAiLoadingCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'AI正在分析您的学习数据...',
              style: TextStyle(
                fontSize: AppFontSize.md,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '这可能需要几秒钟时间',
              style: TextStyle(
                fontSize: AppFontSize.sm,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiResultCard(ThemeData theme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'AI分析报告',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _aiAnalysisResult = null;
                    });
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('重新分析'),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              _aiAnalysisResult!,
              style: TextStyle(
                fontSize: AppFontSize.md,
                height: 1.6,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAISettings() {
    Navigator.of(context).pushNamed('/ai/settings');
  }

  Future<void> _startAiAnalysis() async {
    if (!_aiService.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先配置AI模型'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isAiAnalyzing = true;
      _aiAnalysisResult = null;
    });

    try {
      // 准备分析数据
      final analysisData = _prepareAnalysisData();

      final prompt = '''
请作为一位专业的学习分析师，基于以下学习数据进行深度分析，并提供个性化的学习建议。

学习数据：
$analysisData

请从以下几个方面进行分析：
1. 学习概况总结
2. 优势学科和薄弱环节分析
3. 学习时间分配评估
4. 错题类型分析
5. 具体的学习改进建议
6. 下一阶段的学习计划建议

请以Markdown格式输出，结构清晰，语言亲切专业。
''';      

      final result = await _aiService.chat(prompt);

      setState(() {
        _aiAnalysisResult = result;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI分析失败: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() {
        _isAiAnalyzing = false;
      });
    }
  }

  String _prepareAnalysisData() {
    final buffer = StringBuffer();

    // 时间范围
    buffer.writeln('分析时间范围: ${_timeFilterLabel}');
    buffer.writeln();

    // 学科筛选
    if (_selectedSubjects.isNotEmpty) {
      buffer.writeln('分析学科: ${_selectedSubjects.join('、')}');
    } else {
      buffer.writeln('分析学科: 全部学科');
    }
    buffer.writeln();

    // 整体数据
    final examResults = _overallAnalysis['examResults'] as Map<String, dynamic>?;
    final studyTime = _overallAnalysis['studyTime'] as Map<String, dynamic>?;
    final wrongQuestions = _overallAnalysis['wrongQuestions'] as Map<String, dynamic>?;

    buffer.writeln('=== 整体学习数据 ===');
    buffer.writeln('平均成绩: ${(examResults?['averageAccuracy'] as num? ?? 0).toStringAsFixed(1)}%');
    buffer.writeln('学习时长: ${studyTime?['totalMinutes'] ?? 0}分钟');
    buffer.writeln('错题数量: ${wrongQuestions?['total'] ?? 0}道');
    buffer.writeln();

    // 学科强弱
    if (_subjectStrength.isNotEmpty) {
      buffer.writeln('=== 学科强弱分析 ===');
      _subjectStrength.forEach((subject, data) {
        final d = data as Map<String, dynamic>;
        final strength = d['strength'] as String;
        final strengthText = strength == 'strong' ? '强' : strength == 'medium' ? '中' : '弱';
        buffer.writeln('$subject: 综合得分 ${(d['compositeScore'] as num).toStringAsFixed(1)}分 (等级: $strengthText)');
      });
      buffer.writeln();
    }

    // 错题分析
    final byErrorType = _wrongQuestionAnalysis['byErrorType'] as Map<String, dynamic>?;
    if (byErrorType != null && byErrorType.isNotEmpty) {
      buffer.writeln('=== 错题类型分布 ===');
      byErrorType.forEach((type, data) {
        final d = data as Map<String, dynamic>;
        buffer.writeln('${d['label']}: ${d['count']}道');
      });
      buffer.writeln();
    }

    // 高频错题知识点
    final topKnowledgePoints = _wrongQuestionAnalysis['topKnowledgePoints'] as List<dynamic>?;
    if (topKnowledgePoints != null && topKnowledgePoints.isNotEmpty) {
      buffer.writeln('=== 高频错题知识点 ===');
      for (final point in topKnowledgePoints.take(5)) {
        buffer.writeln('${point['name']}: ${point['count']}次错误');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }
}

// ==================== 雷达图绘制器 ====================
class RadarChartPainter extends CustomPainter {
  final Map<String, double> data;

  RadarChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 20;
    final labels = data.keys.toList();
    final values = data.values.toList();
    final count = labels.length;

    final paint = Paint()
      ..color = AppColors.primary.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final gridPaint = Paint()
      ..color = AppColors.divider
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // 绘制网格
    for (int i = 1; i <= 5; i++) {
      final r = radius * i / 5;
      final path = Path();
      for (int j = 0; j < count; j++) {
        final angle = 2 * pi * j / count - pi / 2;
        final x = center.dx + r * cos(angle);
        final y = center.dy + r * sin(angle);
        if (j == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // 绘制轴线
    for (int i = 0; i < count; i++) {
      final angle = 2 * pi * i / count - pi / 2;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      canvas.drawLine(center, Offset(x, y), gridPaint);
    }

    // 绘制数据区域
    final path = Path();
    for (int i = 0; i < count; i++) {
      final angle = 2 * pi * i / count - pi / 2;
      final value = values[i] / 100;
      final r = radius * value;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
    canvas.drawPath(path, strokePaint);

    // 绘制数据点
    final pointPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    for (int i = 0; i < count; i++) {
      final angle = 2 * pi * i / count - pi / 2;
      final value = values[i] / 100;
      final r = radius * value;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      canvas.drawCircle(Offset(x, y), 4, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ==================== 趋势图绘制器 ====================
class TrendChartPainter extends CustomPainter {
  final Map<String, dynamic> data;
  final List<String> dates;

  TrendChartPainter({required this.data, required this.dates});

  @override
  void paint(Canvas canvas, Size size) {
    if (dates.isEmpty) return;

    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final fillPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = AppColors.divider
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final padding = 20.0;
    final chartWidth = size.width - padding * 2;
    final chartHeight = size.height - padding * 2;

    // 绘制网格
    for (int i = 0; i <= 5; i++) {
      final y = padding + chartHeight * i / 5;
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        gridPaint,
      );
    }

    // 计算最大值
    int maxDuration = 0;
    for (final date in dates) {
      final dayData = data[date] as Map<String, dynamic>?;
      final duration = dayData?['duration'] as int? ?? 0;
      if (duration > maxDuration) maxDuration = duration;
    }
    if (maxDuration == 0) maxDuration = 1;

    // 绘制数据线
    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < dates.length; i++) {
      final x = padding + chartWidth * i / (dates.length - 1);
      final dayData = data[dates[i]] as Map<String, dynamic>?;
      final duration = dayData?['duration'] as int? ?? 0;
      final y = padding + chartHeight * (1 - duration / maxDuration);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height - padding);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(padding + chartWidth, size.height - padding);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // 绘制数据点
    final pointPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    for (int i = 0; i < dates.length; i++) {
      final x = padding + chartWidth * i / (dates.length - 1);
      final dayData = data[dates[i]] as Map<String, dynamic>?;
      final duration = dayData?['duration'] as int? ?? 0;
      final y = padding + chartHeight * (1 - duration / maxDuration);

      canvas.drawCircle(Offset(x, y), 3, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter) => true;
}
