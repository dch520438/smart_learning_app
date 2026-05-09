import 'dart:async';
import 'package:flutter/material.dart';
import '../screens/wrong_questions/wrong_questions_screen.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'common_widgets.dart';

// ============================================================
// QuestionOption - 选项组件
// ============================================================

/// QuestionOption: 选项组件
class QuestionOption extends StatelessWidget {
  final String label; // A, B, C, D
  final String text;
  final bool isSelected;
  final bool isCorrect;
  final bool showResult;
  final bool enabled;
  final ValueChanged<bool>? onTap;

  const QuestionOption({
    super.key,
    required this.label,
    required this.text,
    this.isSelected = false,
    this.isCorrect = false,
    this.showResult = false,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color borderColor;
    Color? backgroundColor;
    Color labelColor;
    Color textColor;

    if (showResult) {
      if (isCorrect) {
        borderColor = AppColors.success;
        backgroundColor = AppColors.success.withOpacity(0.08);
        labelColor = AppColors.success;
        textColor = AppColors.success;
      } else if (isSelected && !isCorrect) {
        borderColor = AppColors.error;
        backgroundColor = AppColors.error.withOpacity(0.08);
        labelColor = AppColors.error;
        textColor = AppColors.error;
      } else {
        borderColor = AppColors.divider;
        backgroundColor = null;
        labelColor = AppColors.textSecondary;
        textColor = AppColors.textSecondary;
      }
    } else if (isSelected) {
      borderColor = theme.colorScheme.primary;
      backgroundColor = theme.colorScheme.primary.withOpacity(0.08);
      labelColor = theme.colorScheme.primary;
      textColor = AppColors.textPrimary;
    } else {
      borderColor = AppColors.divider;
      backgroundColor = null;
      labelColor = AppColors.textSecondary;
      textColor = AppColors.textPrimary;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? () => onTap?.call(true) : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border.all(color: borderColor, width: 1.5),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 选项标签
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: borderColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: AppFontSize.sm,
                      fontWeight: FontWeight.w700,
                      color: labelColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 选项内容
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: AppFontSize.md,
                      color: textColor,
                      height: 1.5,
                    ),
                  ),
                ),
                // 结果图标
                if (showResult) ...[
                  const SizedBox(width: 8),
                  Icon(
                    isCorrect
                        ? Icons.check_circle_rounded
                        : (isSelected ? Icons.cancel_rounded : Icons.circle_outlined),
                    color: isCorrect
                        ? AppColors.success
                        : (isSelected ? AppColors.error : AppColors.textHint),
                    size: 22,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// QuestionCard - 题目卡片
// ============================================================

/// QuestionCard: 题目卡片（支持选择题、填空题等）
class QuestionCard extends StatefulWidget {
  final String id;
  final String content;
  final QuestionType type;
  final String? subject;
  final int? difficulty;
  final List<String>? options; // 选择题选项
  final String? correctAnswer; // 正确答案
  final String? userAnswer; // 用户答案
  final String? analysis; // 解析
  final int? index; // 题号
  final bool showResult;
  final bool showAnalysis;
  final ValueChanged<String>? onAnswer;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final bool isFavorited;

  const QuestionCard({
    super.key,
    required this.id,
    required this.content,
    this.type = QuestionType.singleChoice,
    this.subject,
    this.difficulty,
    this.options,
    this.correctAnswer,
    this.userAnswer,
    this.analysis,
    this.index,
    this.showResult = false,
    this.showAnalysis = false,
    this.onAnswer,
    this.onTap,
    this.onFavorite,
    this.isFavorited = false,
  });

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  String? _selectedAnswer;
  bool _showAnalysis = false;

  @override
  void initState() {
    super.initState();
    _selectedAnswer = widget.userAnswer;
    _showAnalysis = widget.showAnalysis;
  }

  @override
  void didUpdateWidget(QuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userAnswer != oldWidget.userAnswer) {
      _selectedAnswer = widget.userAnswer;
    }
    if (widget.showAnalysis != oldWidget.showAnalysis) {
      _showAnalysis = widget.showAnalysis;
    }
  }

  static const List<String> _optionLabels = ['A', 'B', 'C', 'D', 'E', 'F'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return AppCard(
      onTap: widget.onTap,
      margin: EdgeInsets.symmetric(
        horizontal: isWideScreen ? 32 : 16,
        vertical: 8,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：题号 + 学科 + 难度 + 收藏
          Row(
            children: [
              if (widget.index != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    '${widget.index! + 1}',
                    style: TextStyle(
                      fontSize: AppFontSize.sm,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (widget.subject != null) ...[
                AppTag(
                  label: widget.subject!,
                  color: getSubjectColor(widget.subject!),
                  dense: true,
                  fontSize: AppFontSize.xs,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => WrongQuestionsScreen(
                          initialFilterTag: widget.subject,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
              if (widget.difficulty != null) ...[
                DifficultyStars(
                  difficulty: widget.difficulty!,
                  iconSize: 14,
                ),
                const Spacer(),
              ],
              if (widget.difficulty == null) const Spacer(),
              // 题型标签
              AppTag(
                label: widget.type.label,
                color: AppColors.info,
                dense: true,
                fontSize: AppFontSize.xs,
              ),
              const SizedBox(width: 8),
              // 收藏按钮
              if (widget.onFavorite != null)
                IconButton(
                  icon: Icon(
                    widget.isFavorited
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    size: 20,
                    color: widget.isFavorited
                        ? AppColors.warning
                        : AppColors.textHint,
                  ),
                  onPressed: widget.onFavorite,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          const SizedBox(height: 12),

          // 题目内容
          Text(
            widget.content,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
              height: 1.6,
            ),
          ),

          // 选择题选项
          if (widget.type == QuestionType.singleChoice &&
              widget.options != null) ...[
            const SizedBox(height: 12),
            ...widget.options!.asMap().entries.map((entry) {
              final idx = entry.key;
              final optionText = entry.value;
              final optionLabel = _optionLabels[idx];
              final isSelected = _selectedAnswer == optionLabel;
              final isCorrect = widget.correctAnswer == optionLabel;

              return QuestionOption(
                label: optionLabel,
                text: optionText,
                isSelected: isSelected,
                isCorrect: isCorrect,
                showResult: widget.showResult,
                enabled: !widget.showResult,
                onTap: (_) {
                  setState(() {
                    _selectedAnswer = optionLabel;
                  });
                  widget.onAnswer?.call(optionLabel);
                },
              );
            }),
          ],

          // 填空题输入框
          if (widget.type == QuestionType.fillBlank && !widget.showResult) ...[
            const SizedBox(height: 12),
            AppInput(
              hintText: '请输入答案...',
              onChanged: (value) {
                setState(() {
                  _selectedAnswer = value;
                });
                widget.onAnswer?.call(value);
              },
            ),
          ],

          // 填空题答案显示
          if (widget.type == QuestionType.fillBlank &&
              widget.showResult &&
              widget.correctAnswer != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.success),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '正确答案: ${widget.correctAnswer}',
                    style: TextStyle(
                      fontSize: AppFontSize.md,
                      color: AppColors.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 判断题
          if (widget.type == QuestionType.trueFalse) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: QuestionOption(
                    label: 'T',
                    text: '正确',
                    isSelected: _selectedAnswer == 'T',
                    isCorrect: widget.correctAnswer == 'T',
                    showResult: widget.showResult,
                    enabled: !widget.showResult,
                    onTap: (_) {
                      setState(() {
                        _selectedAnswer = 'T';
                      });
                      widget.onAnswer?.call('T');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: QuestionOption(
                    label: 'F',
                    text: '错误',
                    isSelected: _selectedAnswer == 'F',
                    isCorrect: widget.correctAnswer == 'F',
                    showResult: widget.showResult,
                    enabled: !widget.showResult,
                    onTap: (_) {
                      setState(() {
                        _selectedAnswer = 'F';
                      });
                      widget.onAnswer?.call('F');
                    },
                  ),
                ),
              ],
            ),
          ],

          // 查看解析按钮
          if (widget.analysis != null && widget.analysis!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() => _showAnalysis = !_showAnalysis),
                icon: Icon(
                  _showAnalysis
                      ? Icons.expand_less
                      : Icons.expand_more,
                  size: 18,
                ),
                label: Text(
                  _showAnalysis ? '收起解析' : '查看解析',
                  style: TextStyle(fontSize: AppFontSize.sm),
                ),
              ),
            ),
            if (_showAnalysis)
              QuestionAnalysis(
                analysis: widget.analysis!,
                correctAnswer: widget.correctAnswer,
                userAnswer: _selectedAnswer,
              ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// QuestionAnalysis - 解析展示组件
// ============================================================

/// QuestionAnalysis: 解析展示组件
class QuestionAnalysis extends StatelessWidget {
  final String analysis;
  final String? correctAnswer;
  final String? userAnswer;
  final bool isCorrect;

  const QuestionAnalysis({
    super.key,
    required this.analysis,
    this.correctAnswer,
    this.userAnswer,
    this.isCorrect = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIsCorrect = userAnswer == correctAnswer;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: effectiveIsCorrect ? AppColors.success : AppColors.error,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 结果标题
          Row(
            children: [
              Icon(
                effectiveIsCorrect
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                color: effectiveIsCorrect ? AppColors.success : AppColors.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                effectiveIsCorrect ? '回答正确' : '回答错误',
                style: TextStyle(
                  fontSize: AppFontSize.md,
                  fontWeight: FontWeight.w600,
                  color:
                      effectiveIsCorrect ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 答案对比
          if (correctAnswer != null) ...[
            Row(
              children: [
                Text(
                  '正确答案: ',
                  style: TextStyle(
                    fontSize: AppFontSize.sm,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  correctAnswer!,
                  style: TextStyle(
                    fontSize: AppFontSize.sm,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
                if (userAnswer != null && userAnswer != correctAnswer) ...[
                  const SizedBox(width: 16),
                  Text(
                    '你的答案: ',
                    style: TextStyle(
                      fontSize: AppFontSize.sm,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    userAnswer!,
                    style: TextStyle(
                      fontSize: AppFontSize.sm,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
          ],
          // 解析内容
          Text(
            '解析',
            style: TextStyle(
              fontSize: AppFontSize.sm,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            analysis,
            style: TextStyle(
              fontSize: AppFontSize.md,
              color: AppColors.textPrimary,
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// AnswerSheet - 答题卡组件
// ============================================================

/// AnswerSheet: 答题卡组件
class AnswerSheet extends StatelessWidget {
  final int totalCount;
  final Map<int, String?> answers; // 题号 -> 用户答案
  final Map<int, String> correctAnswers; // 题号 -> 正确答案
  final bool showResult;
  final int currentIndex;
  final ValueChanged<int>? onQuestionTap;

  const AnswerSheet({
    super.key,
    required this.totalCount,
    required this.answers,
    this.correctAnswers = const {},
    this.showResult = false,
    this.currentIndex = 0,
    this.onQuestionTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;
    final itemSize = isWideScreen ? 44.0 : 36.0;

    // 统计
    final answeredCount = answers.values.where((a) => a != null).length;
    final correctCount = showResult
        ? correctAnswers.entries
            .where((e) => answers[e.key] == e.value)
            .length
        : 0;
    final wrongCount = showResult
        ? correctAnswers.entries
            .where((e) =>
                answers[e.key] != null && answers[e.key] != e.value)
            .length
        : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Text(
            '答题卡',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // 统计信息
          if (showResult) ...[
            Row(
              children: [
                _buildStatItem(
                  label: '正确',
                  count: correctCount,
                  color: AppColors.success,
                ),
                const SizedBox(width: 16),
                _buildStatItem(
                  label: '错误',
                  count: wrongCount,
                  color: AppColors.error,
                ),
                const SizedBox(width: 16),
                _buildStatItem(
                  label: '未答',
                  count: totalCount - answeredCount,
                  color: AppColors.textHint,
                ),
              ],
            ),
            const SizedBox(height: 12),
          ] else ...[
            Text(
              '已答 $answeredCount/$totalCount',
              style: TextStyle(
                fontSize: AppFontSize.sm,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 题号网格
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(totalCount, (index) {
              final questionNum = index + 1;
              final userAnswer = answers[questionNum];
              final isCurrent = index == currentIndex;

              Color backgroundColor;
              Color textColor;
              Color borderColor;

              if (showResult) {
                final isCorrect =
                    correctAnswers[questionNum] == userAnswer;
                if (userAnswer == null) {
                  backgroundColor = Colors.transparent;
                  textColor = AppColors.textHint;
                  borderColor = AppColors.divider;
                } else if (isCorrect) {
                  backgroundColor = AppColors.success.withOpacity(0.1);
                  textColor = AppColors.success;
                  borderColor = AppColors.success;
                } else {
                  backgroundColor = AppColors.error.withOpacity(0.1);
                  textColor = AppColors.error;
                  borderColor = AppColors.error;
                }
              } else {
                if (userAnswer != null) {
                  backgroundColor =
                      theme.colorScheme.primary.withOpacity(0.1);
                  textColor = theme.colorScheme.primary;
                  borderColor = theme.colorScheme.primary;
                } else {
                  backgroundColor = Colors.transparent;
                  textColor = AppColors.textSecondary;
                  borderColor = AppColors.divider;
                }
              }

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onQuestionTap?.call(index),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Container(
                    width: itemSize,
                    height: itemSize,
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: isCurrent
                            ? theme.colorScheme.primary
                            : borderColor,
                        width: isCurrent ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$questionNum',
                      style: TextStyle(
                        fontSize: isWideScreen ? AppFontSize.md : AppFontSize.sm,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: isCurrent
                            ? theme.colorScheme.primary
                            : textColor,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required int count,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label $count',
          style: TextStyle(
            fontSize: AppFontSize.sm,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// ExamTimer - 考试计时器组件
// ============================================================

/// ExamTimer: 考试计时器组件
class ExamTimer extends StatefulWidget {
  final int totalSeconds; // 总时长（秒）
  final VoidCallback? onTimeUp;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final bool autoStart;

  const ExamTimer({
    super.key,
    required this.totalSeconds,
    this.onTimeUp,
    this.onPause,
    this.onResume,
    this.autoStart = true,
  });

  @override
  State<ExamTimer> createState() => _ExamTimerState();
}

class _ExamTimerState extends State<ExamTimer> {
  late int _remainingSeconds;
  Timer? _timer;
  bool _isRunning = false;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.totalSeconds;
    if (widget.autoStart) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _isRunning = true;
    _isPaused = false;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _timer?.cancel();
            _isRunning = false;
            widget.onTimeUp?.call();
          }
        });
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isPaused = true;
      _isRunning = false;
    });
    widget.onPause?.call();
  }

  void _resumeTimer() {
    setState(() {
      _isPaused = false;
    });
    _startTimer();
    widget.onResume?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    final hours = _remainingSeconds ~/ 3600;
    final minutes = (_remainingSeconds % 3600) ~/ 60;
    final seconds = _remainingSeconds % 60;

    final isWarning = _remainingSeconds <= 300; // 最后5分钟警告
    final isDanger = _remainingSeconds <= 60; // 最后1分钟危险

    Color timerColor;
    if (isDanger) {
      timerColor = AppColors.error;
    } else if (isWarning) {
      timerColor = AppColors.warning;
    } else {
      timerColor = theme.colorScheme.primary;
    }

    final progress = _remainingSeconds / widget.totalSeconds;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth > 600 ? 24 : 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: isDanger
            ? AppColors.error.withOpacity(0.08)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDanger
              ? AppColors.error.withOpacity(0.3)
              : AppColors.divider,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 图标
          Icon(
            _isPaused ? Icons.pause_circle : Icons.timer_outlined,
            size: 22,
            color: timerColor,
          ),
          const SizedBox(width: 8),
          // 时间显示
          Text(
            '${hours.toString().padLeft(2, '0')}:'
            '${minutes.toString().padLeft(2, '0')}:'
            '${seconds.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: screenWidth > 600 ? AppFontSize.xl : AppFontSize.lg,
              fontWeight: FontWeight.w700,
              color: timerColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 12),
          // 暂停/继续按钮
          if (_isRunning || _isPaused)
            IconButton(
              icon: Icon(
                _isPaused ? Icons.play_arrow : Icons.pause,
                size: 20,
                color: timerColor,
              ),
              onPressed: _isPaused ? _resumeTimer : _pauseTimer,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }
}
