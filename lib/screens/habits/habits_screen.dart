import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/habit.dart';
import '../../services/database_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/habit_widgets.dart';

// ============================================================
// HabitsScreen - 习惯打卡主页面
// ============================================================

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  late TabController _tabController;

  List<Habit> _habits = [];
  List<Habit> _activeHabits = [];
  List<Habit> _completedHabits = [];
  bool _isLoading = true;

  // 统计数据
  int _totalHabits = 0;
  int _todayCheckIns = 0;
  int _maxStreak = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      final rows = await _db.queryAllHabits();
      final habits = <Habit>[];

      for (final row in rows) {
        final habit = await _rowToHabit(row);
        habits.add(habit);
      }

      _habits = habits;
      _categorizeHabits();
      _calculateStats();
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '加载失败: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Habit> _rowToHabit(Map<String, dynamic> row) async {
    final uuid = row['uuid'] as String;
    // 加载打卡记录
    final checkInRows = await _db.queryHabitCheckInsByHabitUuid(uuid);
    final checkIns = checkInRows.map((r) => _rowToCheckIn(r)).toList();

    return Habit(
      id: uuid,
      name: row['name'] as String,
      description: row['description'] as String?,
      targetDays: row['target_days'] as int,
      currentStreak: row['current_streak'] as int? ?? 0,
      totalCompletedDays: row['total_completed_days'] as int? ?? 0,
      createdAt: DateTime.parse(row['created_at'] as String),
      completedAt: row['completed_at'] != null
          ? DateTime.parse(row['completed_at'] as String)
          : null,
      isActive: (row['is_active'] as int?) == 1,
      icon: row['icon'] as String?,
      color: row['color'] as int?,
      reminderHour: row['reminder_hour'] as int?,
      reminderMinute: row['reminder_minute'] as int?,
      reminderEnabled: (row['reminder_enabled'] as int?) == 1,
      checkIns: checkIns,
    );
  }

  HabitCheckIn _rowToCheckIn(Map<String, dynamic> row) {
    return HabitCheckIn(
      id: row['uuid'] as String,
      checkInTime: DateTime.parse(row['check_in_time'] as String),
      note: row['note'] as String?,
      mood: row['mood'] as int?,
    );
  }

  void _categorizeHabits() {
    _activeHabits = _habits.where((h) => h.isActive && !h.isCompleted).toList();
    _completedHabits = _habits.where((h) => h.isCompleted).toList();
  }

  void _calculateStats() {
    _totalHabits = _habits.length;
    _todayCheckIns = _habits.where((h) => h.isCheckedInToday).length;
    _maxStreak = _habits.isEmpty
        ? 0
        : _habits.map((h) => h.currentStreak).reduce((a, b) => a > b ? a : b);
  }

  Future<void> _createHabit(Habit habit) async {
    try {
      await _db.insertHabit({
        'uuid': habit.id,
        'name': habit.name,
        'description': habit.description,
        'target_days': habit.targetDays,
        'current_streak': habit.currentStreak,
        'total_completed_days': habit.totalCompletedDays,
        'created_at': habit.createdAt.toIso8601String(),
        'is_active': habit.isActive ? 1 : 0,
        'icon': habit.icon,
        'color': habit.color,
        'reminder_hour': habit.reminderHour,
        'reminder_minute': habit.reminderMinute,
        'reminder_enabled': habit.reminderEnabled ? 1 : 0,
      });

      showSnackBar(context, '习惯创建成功');
      await _loadData();
    } catch (e) {
      if (mounted) showSnackBar(context, '创建失败: $e', isError: true);
    }
  }

  Future<void> _updateHabit(Habit habit) async {
    try {
      final row = await _db.queryHabitByUuid(habit.id);
      if (row != null) {
        await _db.updateHabit(row['id'] as int, {
          'name': habit.name,
          'description': habit.description,
          'target_days': habit.targetDays,
          'current_streak': habit.currentStreak,
          'total_completed_days': habit.totalCompletedDays,
          'completed_at': habit.completedAt?.toIso8601String(),
          'is_active': habit.isActive ? 1 : 0,
          'icon': habit.icon,
          'color': habit.color,
          'reminder_hour': habit.reminderHour,
          'reminder_minute': habit.reminderMinute,
          'reminder_enabled': habit.reminderEnabled ? 1 : 0,
        });

        showSnackBar(context, '习惯更新成功');
        await _loadData();
      }
    } catch (e) {
      if (mounted) showSnackBar(context, '更新失败: $e', isError: true);
    }
  }

  Future<void> _deleteHabit(Habit habit) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context: context,
      title: '删除习惯',
      message: '确定要删除"${habit.name}"吗？此操作不可撤销，所有打卡记录也将被删除。',
    );
    if (confirmed != true) return;

    try {
      final row = await _db.queryHabitByUuid(habit.id);
      if (row != null) {
        await _db.deleteHabit(row['id'] as int);
        showSnackBar(context, '习惯已删除');
        await _loadData();
      }
    } catch (e) {
      if (mounted) showSnackBar(context, '删除失败: $e', isError: true);
    }
  }

  Future<void> _checkIn(Habit habit, {String? note, int? mood}) async {
    if (habit.isCheckedInToday) {
      showSnackBar(context, '今天已经打卡了');
      return;
    }

    try {
      final checkIn = HabitCheckIn(
        id: generateId(),
        checkInTime: DateTime.now(),
        note: note,
        mood: mood,
      );

      // 保存打卡记录
      await _db.insertHabitCheckIn({
        'uuid': checkIn.id,
        'habit_uuid': habit.id,
        'check_in_time': checkIn.checkInTime.toIso8601String(),
        'note': checkIn.note,
        'mood': checkIn.mood,
      });

      // 更新习惯统计
      final newCheckIns = [...habit.checkIns, checkIn];
      final newStreak = Habit.calculateStreak(newCheckIns);
      final newTotalDays = habit.totalCompletedDays + 1;
      final isCompleted = newTotalDays >= habit.targetDays;

      final row = await _db.queryHabitByUuid(habit.id);
      if (row != null) {
        await _db.updateHabit(row['id'] as int, {
          'current_streak': newStreak,
          'total_completed_days': newTotalDays,
          'completed_at': isCompleted ? DateTime.now().toIso8601String() : null,
        });
      }

      if (mounted) {
        showSnackBar(
          context,
          isCompleted ? '恭喜！你已完成"${habit.name}"的目标！' : '打卡成功！',
        );
      }

      await _loadData();
    } catch (e) {
      if (mounted) showSnackBar(context, '打卡失败: $e', isError: true);
    }
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (context) => HabitFormDialog(
        onSave: _createHabit,
      ),
    );
  }

  void _showEditDialog(Habit habit) {
    showDialog(
      context: context,
      builder: (context) => HabitFormDialog(
        habit: habit,
        onSave: _updateHabit,
      ),
    );
  }

  void _showCheckInDialog(Habit habit) {
    showDialog(
      context: context,
      builder: (context) => CheckInDialog(
        habit: habit,
        onConfirm: (note, mood) => _checkIn(habit, note: note, mood: mood),
      ),
    );
  }

  void _showHabitDetail(Habit habit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HabitDetailScreen(
          habit: habit,
          onCheckIn: () => _showCheckInDialog(habit),
          onEdit: () => _showEditDialog(habit),
          onDelete: () => _deleteHabit(habit),
        ),
      ),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('习惯打卡'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '进行中'),
            Tab(text: '已完成'),
          ],
        ),
      ),
      body: _isLoading
          ? const AppLoading(message: '加载中...')
          : Column(
              children: [
                // 统计卡片
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: HabitStatsCard(
                    totalHabits: _totalHabits,
                    activeHabits: _activeHabits.length,
                    completedHabits: _completedHabits.length,
                    todayCheckIns: _todayCheckIns,
                    maxStreak: _maxStreak,
                  ),
                ),
                // 习惯列表
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // 进行中
                      _buildHabitList(_activeHabits, isActive: true),
                      // 已完成
                      _buildHabitList(_completedHabits, isActive: false),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHabitList(List<Habit> habits, {required bool isActive}) {
    if (habits.isEmpty) {
      return AppEmptyState(
        message: isActive ? '还没有进行中的习惯' : '还没有已完成的习惯',
        icon: isActive ? Icons.local_fire_department : Icons.emoji_events,
        actionText: isActive ? '创建习惯' : null,
        onAction: isActive ? _showCreateDialog : null,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: habits.length,
        itemBuilder: (context, index) {
          final habit = habits[index];
          return HabitCard(
            habit: habit,
            onTap: () => _showHabitDetail(habit),
            onCheckIn: () => _showCheckInDialog(habit),
            onLongPress: () => _showEditDialog(habit),
            showCheckInButton: isActive,
          );
        },
      ),
    );
  }
}

// ============================================================
// HabitDetailScreen - 习惯详情页面
// ============================================================

class HabitDetailScreen extends StatelessWidget {
  final Habit habit;
  final VoidCallback onCheckIn;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const HabitDetailScreen({
    super.key,
    required this.habit,
    required this.onCheckIn,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = habit.color != null ? Color(habit.color!) : AppColors.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(habit.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: onEdit,
            tooltip: '编辑',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: onDelete,
            tooltip: '删除',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部信息卡片
            _buildHeaderCard(color),
            const SizedBox(height: 20),
            // 打卡日历
            HabitCalendar(habit: habit),
            const SizedBox(height: 20),
            // 打卡记录列表
            _buildCheckInHistory(),
          ],
        ),
      ),
      bottomNavigationBar: habit.isCheckedInToday || habit.isCompleted
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: onCheckIn,
                icon: const Icon(Icons.check),
                label: const Text('今日打卡'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderCard(Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color,
            color.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  _getIconData(habit.icon),
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (habit.description != null)
                      Text(
                        habit.description!,
                        style: TextStyle(
                          fontSize: AppFontSize.sm,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDetailStat('目标天数', '${habit.targetDays}'),
              _buildDetailStat('已完成', '${habit.totalCompletedDays}'),
              _buildDetailStat('连续打卡', '${habit.currentStreak}'),
              _buildDetailStat('剩余', '${habit.remainingDays}'),
            ],
          ),
          if (habit.reminderEnabled && habit.reminderTimeString != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.alarm,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '每日提醒 ${habit.reminderTimeString}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: AppFontSize.sm,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckInHistory() {
    final sortedCheckIns = habit.checkIns.toList()
      ..sort((a, b) => b.checkInTime.compareTo(a.checkInTime));

    if (sortedCheckIns.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Center(
          child: Text(
            '还没有打卡记录',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '打卡记录',
            style: TextStyle(
              fontSize: AppFontSize.lg,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...sortedCheckIns.take(10).map((checkIn) => _buildCheckInItem(checkIn)),
          if (sortedCheckIns.length > 10)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: Text(
                  '还有 ${sortedCheckIns.length - 10} 条记录',
                  style: TextStyle(
                    fontSize: AppFontSize.sm,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCheckInItem(HabitCheckIn checkIn) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.check,
              color: AppColors.success,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatDateTime(checkIn.checkInTime),
                  style: TextStyle(
                    fontSize: AppFontSize.sm,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (checkIn.note != null)
                  Text(
                    checkIn.note!,
                    style: TextStyle(
                      fontSize: AppFontSize.xs,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (checkIn.mood != null)
            Icon(
              _getMoodIcon(checkIn.mood!),
              color: _getMoodColor(checkIn.mood!),
              size: 24,
            ),
        ],
      ),
    );
  }

  IconData _getIconData(String? iconName) {
    final Map<String, IconData> iconMap = {
      'book': Icons.book,
      'school': Icons.school,
      'calculate': Icons.calculate,
      'language': Icons.language,
      'science': Icons.science,
      'history': Icons.history,
      'translate': Icons.translate,
      'edit': Icons.edit,
      'create': Icons.create,
      'lightbulb': Icons.lightbulb,
      'star': Icons.star,
      'favorite': Icons.favorite,
      'fitness_center': Icons.fitness_center,
      'directions_run': Icons.directions_run,
      'self_improvement': Icons.self_improvement,
      'timer': Icons.timer,
      'alarm': Icons.alarm,
      'schedule': Icons.schedule,
      'check_circle': Icons.check_circle,
      'emoji_events': Icons.emoji_events,
    };
    return iconMap[iconName] ?? Icons.star;
  }

  IconData _getMoodIcon(int mood) {
    switch (mood) {
      case 1:
        return Icons.sentiment_very_dissatisfied;
      case 2:
        return Icons.sentiment_dissatisfied;
      case 3:
        return Icons.sentiment_neutral;
      case 4:
        return Icons.sentiment_satisfied;
      case 5:
        return Icons.sentiment_very_satisfied;
      default:
        return Icons.sentiment_neutral;
    }
  }

  Color _getMoodColor(int mood) {
    switch (mood) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow.shade700;
      case 4:
        return Colors.lightGreen;
      case 5:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
