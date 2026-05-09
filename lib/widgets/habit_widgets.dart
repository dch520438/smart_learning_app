import 'dart:async';
import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

/// 习惯卡片组件
class HabitCard extends StatelessWidget {
  final Habit habit;
  final VoidCallback? onTap;
  final VoidCallback? onCheckIn;
  final VoidCallback? onLongPress;
  final bool showCheckInButton;

  const HabitCard({
    super.key,
    required this.habit,
    this.onTap,
    this.onCheckIn,
    this.onLongPress,
    this.showCheckInButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = habit.color != null ? Color(habit.color!) : theme.colorScheme.primary;
    final progress = habit.progressPercent;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 图标
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    _getIconData(habit.icon),
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                // 标题和描述
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.name,
                        style: TextStyle(
                          fontSize: AppFontSize.lg,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (habit.description != null && habit.description!.isNotEmpty)
                        Text(
                          habit.description!,
                          style: TextStyle(
                            fontSize: AppFontSize.sm,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // 打卡按钮
                if (showCheckInButton && !habit.isCheckedInToday)
                  GestureDetector(
                    onTap: onCheckIn,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  )
                else if (habit.isCheckedInToday)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.success),
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 24,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // 进度条
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.divider,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 12),
            // 统计信息
            Row(
              children: [
                _buildStatItem(
                  '连续',
                  '${habit.currentStreak}天',
                  color,
                ),
                const SizedBox(width: 16),
                _buildStatItem(
                  '总打卡',
                  '${habit.totalCompletedDays}天',
                  AppColors.primary,
                ),
                const SizedBox(width: 16),
                _buildStatItem(
                  '剩余',
                  '${habit.remainingDays}天',
                  AppColors.warning,
                ),
                const Spacer(),
                // 目标天数标签
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '目标 ${habit.targetDays}天',
                    style: TextStyle(
                      fontSize: AppFontSize.xs,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: AppFontSize.xs,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: AppFontSize.sm,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
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
}

/// 习惯打卡日历组件
class HabitCalendar extends StatelessWidget {
  final Habit habit;
  final DateTime? selectedDate;
  final Function(DateTime)? onDateSelected;

  const HabitCalendar({
    super.key,
    required this.habit,
    this.selectedDate,
    this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final firstWeekday = DateTime(now.year, now.month, 1).weekday % 7;

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
            '${now.year}年${now.month}月',
            style: TextStyle(
              fontSize: AppFontSize.lg,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          // 星期标题
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['日', '一', '二', '三', '四', '五', '六']
                .map((day) => SizedBox(
                      width: 36,
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: AppFontSize.sm,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          // 日期网格
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: daysInMonth + firstWeekday,
            itemBuilder: (context, index) {
              if (index < firstWeekday) {
                return const SizedBox.shrink();
              }
              final day = index - firstWeekday + 1;
              final date = DateTime(now.year, now.month, day);
              final isCheckedIn = habit.isCheckedInOn(date);
              final isToday = date.year == now.year &&
                  date.month == now.month &&
                  date.day == now.day;
              final isSelected = selectedDate != null &&
                  date.year == selectedDate!.year &&
                  date.month == selectedDate!.month &&
                  date.day == selectedDate!.day;

              return GestureDetector(
                onTap: () => onDateSelected?.call(date),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isCheckedIn
                        ? AppColors.success
                        : isToday
                            ? AppColors.primary.withOpacity(0.1)
                            : isSelected
                                ? AppColors.primary.withOpacity(0.2)
                                : null,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday
                        ? Border.all(color: AppColors.primary)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: AppFontSize.sm,
                        fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                        color: isCheckedIn
                            ? Colors.white
                            : isToday
                                ? AppColors.primary
                                : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // 图例
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('已打卡', AppColors.success),
              const SizedBox(width: 24),
              _buildLegendItem('今天', AppColors.primary),
              const SizedBox(width: 24),
              _buildLegendItem('未打卡', AppColors.divider),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: AppFontSize.xs,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// 习惯统计卡片
class HabitStatsCard extends StatelessWidget {
  final int totalHabits;
  final int activeHabits;
  final int completedHabits;
  final int todayCheckIns;
  final int maxStreak;

  const HabitStatsCard({
    super.key,
    required this.totalHabits,
    required this.activeHabits,
    required this.completedHabits,
    required this.todayCheckIns,
    required this.maxStreak,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
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
              const Icon(
                Icons.local_fire_department,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                '习惯打卡',
                style: TextStyle(
                  fontSize: AppFontSize.lg,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatColumn('总习惯', '$totalHabits'),
              _buildStatColumn('进行中', '$activeHabits'),
              _buildStatColumn('已完成', '$completedHabits'),
              _buildStatColumn('今日打卡', '$todayCheckIns'),
            ],
          ),
          if (maxStreak > 0) ...[
            const SizedBox(height: 12),
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
                    Icons.emoji_events,
                    color: Colors.amber,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '最高连续 $maxStreak 天',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
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

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
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
}

/// 创建/编辑习惯对话框
class HabitFormDialog extends StatefulWidget {
  final Habit? habit;
  final Function(Habit) onSave;

  const HabitFormDialog({
    super.key,
    this.habit,
    required this.onSave,
  });

  @override
  State<HabitFormDialog> createState() => _HabitFormDialogState();
}

class _HabitFormDialogState extends State<HabitFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _customDaysController;

  int _targetDays = 21;
  String? _selectedIcon;
  int? _selectedColor;
  bool _reminderEnabled = false;
  TimeOfDay? _reminderTime;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.habit?.name ?? '');
    _descriptionController = TextEditingController(text: widget.habit?.description ?? '');
    _customDaysController = TextEditingController();

    if (widget.habit != null) {
      _targetDays = widget.habit!.targetDays;
      _selectedIcon = widget.habit!.icon;
      _selectedColor = widget.habit!.color;
      _reminderEnabled = widget.habit!.reminderEnabled;
      if (widget.habit!.reminderHour != null && widget.habit!.reminderMinute != null) {
        _reminderTime = TimeOfDay(
          hour: widget.habit!.reminderHour!,
          minute: widget.habit!.reminderMinute!,
        );
      }
    } else {
      _selectedIcon = HabitIcons.options.first;
      _selectedColor = HabitColors.options.first;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _customDaysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.habit != null;

    return AlertDialog(
      title: Text(isEditing ? '编辑习惯' : '创建新习惯'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 习惯名称
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '习惯名称',
                  hintText: '例如：每日阅读30分钟',
                  prefixIcon: Icon(Icons.edit),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入习惯名称';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // 描述
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '描述（可选）',
                  hintText: '简单描述这个习惯',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              // 目标天数
              Text(
                '目标天数',
                style: TextStyle(
                  fontSize: AppFontSize.sm,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...HabitTargetDays.presetOptions.map((days) {
                    final isSelected = _targetDays == days;
                    return ChoiceChip(
                      label: Text('$days天'),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _targetDays = days);
                        }
                      },
                    );
                  }),
                  ChoiceChip(
                    label: const Text('自定义'),
                    selected: !HabitTargetDays.presetOptions.contains(_targetDays),
                    onSelected: (selected) {
                      if (selected) {
                        _showCustomDaysDialog();
                      }
                    },
                  ),
                ],
              ),
              if (!HabitTargetDays.presetOptions.contains(_targetDays))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '自定义: $_targetDays 天',
                    style: TextStyle(
                      fontSize: AppFontSize.sm,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              // 图标选择
              Text(
                '选择图标',
                style: TextStyle(
                  fontSize: AppFontSize.sm,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: HabitIcons.options.map((icon) {
                  final isSelected = _selectedIcon == icon;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = icon),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.2)
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(color: AppColors.primary)
                            : null,
                      ),
                      child: Icon(
                        _getIconData(icon),
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // 颜色选择
              Text(
                '选择颜色',
                style: TextStyle(
                  fontSize: AppFontSize.sm,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: HabitColors.options.map((color) {
                  final isSelected = _selectedColor == color;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Color(color).withOpacity(0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // 提醒设置
              SwitchListTile(
                title: const Text('每日提醒'),
                subtitle: Text(_reminderEnabled && _reminderTime != null
                    ? '提醒时间: ${_reminderTime!.format(context)}'
                    : '关闭'),
                value: _reminderEnabled,
                onChanged: (value) {
                  setState(() => _reminderEnabled = value);
                  if (value && _reminderTime == null) {
                    _selectReminderTime();
                  }
                },
              ),
              if (_reminderEnabled)
                TextButton.icon(
                  onPressed: _selectReminderTime,
                  icon: const Icon(Icons.access_time),
                  label: const Text('设置提醒时间'),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(isEditing ? '保存' : '创建'),
        ),
      ],
    );
  }

  Future<void> _selectReminderTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (time != null) {
      setState(() => _reminderTime = time);
    }
  }

  void _showCustomDaysDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自定义天数'),
        content: TextField(
          controller: _customDaysController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '天数',
            hintText: '请输入目标天数',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final days = int.tryParse(_customDaysController.text);
              if (days != null && days > 0) {
                setState(() => _targetDays = days);
              }
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final habit = Habit(
      id: widget.habit?.id ?? generateId(),
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      targetDays: _targetDays,
      currentStreak: widget.habit?.currentStreak ?? 0,
      totalCompletedDays: widget.habit?.totalCompletedDays ?? 0,
      createdAt: widget.habit?.createdAt ?? DateTime.now(),
      completedAt: widget.habit?.completedAt,
      isActive: widget.habit?.isActive ?? true,
      icon: _selectedIcon,
      color: _selectedColor,
      reminderEnabled: _reminderEnabled,
      reminderHour: _reminderTime?.hour,
      reminderMinute: _reminderTime?.minute,
      checkIns: widget.habit?.checkIns ?? [],
    );

    widget.onSave(habit);
    Navigator.pop(context);
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
}

/// 打卡确认对话框
class CheckInDialog extends StatefulWidget {
  final Habit habit;
  final Function(String? note, int? mood) onConfirm;

  const CheckInDialog({
    super.key,
    required this.habit,
    required this.onConfirm,
  });

  @override
  State<CheckInDialog> createState() => _CheckInDialogState();
}

class _CheckInDialogState extends State<CheckInDialog> {
  final _noteController = TextEditingController();
  int? _selectedMood;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.habit.color != null
        ? Color(widget.habit.color!)
        : AppColors.primary;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.check_circle, color: color),
          const SizedBox(width: 8),
          const Text('打卡'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.habit.name,
            style: TextStyle(
              fontSize: AppFontSize.lg,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: '备注（可选）',
              hintText: '记录一下今天的情况...',
              prefixIcon: Icon(Icons.edit_note),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Text(
            '心情',
            style: TextStyle(
              fontSize: AppFontSize.sm,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMoodIcon(Icons.sentiment_very_dissatisfied, 1, Colors.red),
              _buildMoodIcon(Icons.sentiment_dissatisfied, 2, Colors.orange),
              _buildMoodIcon(Icons.sentiment_neutral, 3, Colors.yellow.shade700),
              _buildMoodIcon(Icons.sentiment_satisfied, 4, Colors.lightGreen),
              _buildMoodIcon(Icons.sentiment_very_satisfied, 5, Colors.green),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onConfirm(
              _noteController.text.trim().isEmpty
                  ? null
                  : _noteController.text.trim(),
              _selectedMood,
            );
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
          ),
          child: const Text('确认打卡'),
        ),
      ],
    );
  }

  Widget _buildMoodIcon(IconData icon, int mood, Color color) {
    final isSelected = _selectedMood == mood;
    return GestureDetector(
      onTap: () => setState(() => _selectedMood = mood),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : null,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: color) : null,
        ),
        child: Icon(
          icon,
          color: color,
          size: isSelected ? 32 : 28,
        ),
      ),
    );
  }
}
