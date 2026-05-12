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

  /// 清理题目内容，移除提示部分
  String _cleanQuestionContent(String content) {
    // 移除 "（提示：...）" 或 "(提示：...)" 格式的提示
    final hintPattern = RegExp(r'[（(]提示：[^）)]+[）)]');
    return content.replaceAll(hintPattern, '').trim();
  }

  /// 解析选项文本，处理 {label: A, content: ...} 格式
  String _parseOptionText(String optionText) {
    final trimmedText = optionText.trim();

    // 尝试匹配 {label: A, content: xxx} 格式
    // 使用非贪婪匹配来正确处理 content 中的内容
    final pattern = RegExp(r'\{label:\s*([^,]+?),\s*content:\s*(.+?)\s*\}$', caseSensitive: false);
    final match = pattern.firstMatch(trimmedText);
    if (match != null && match.groupCount >= 2) {
      final content = match.group(2)?.trim() ?? '';
      // 移除 content 值两端可能存在的引号
      if ((content.startsWith('"') && content.endsWith('"')) ||
          (content.startsWith("'") && content.endsWith("'"))) {
        return content.substring(1, content.length - 1);
      }
      return content;
    }

    // 尝试匹配 {"label": "A", "content": "xxx"} 格式
    final jsonPattern = RegExp(r"""["']?label["']?\s*:\s*["']?([^,]+)["']?\s*,\s*["']?content["']?\s*:\s*["']?(.+?)["']?\s*}""", caseSensitive: false);
    final jsonMatch = jsonPattern.firstMatch(trimmedText);
    if (jsonMatch != null && jsonMatch.groupCount >= 2) {
      return jsonMatch.group(2)?.trim() ?? trimmedText;
    }

    // 如果不是特殊格式，直接返回原文本
    return trimmedText;
  }

  /// 清理题目内容，处理可能的代码格式
  String _cleanContent(String content) {
    if (content.isEmpty) return content;

    // 处理 {label: ..., content: ...} 格式的题目内容
    if (content.trim().startsWith('{') && content.trim().endsWith('}')) {
      // 尝试提取 content 字段
      final contentPattern = RegExp(r"""["']?content["']?\s*:\s*["']?(.+?)["']?\s*[,}]""", caseSensitive: false);
      final match = contentPattern.firstMatch(content);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.trim();
      }
    }

    return content;
  }

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

          // 题目内容（移除提示部分，清理代码格式）
          Text(
            _cleanContent(_cleanQuestionContent(widget.content)),
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
              final optionText = _parseOptionText(entry.value);
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

          // 填空题输入框（带特殊符号按钮）
          if (widget.type == QuestionType.fillBlank && !widget.showResult) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.edit_note,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '答题区域',
                        style: TextStyle(
                          fontSize: AppFontSize.sm,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSymbolInputField(
                    hintText: '请输入答案，点击右侧按钮插入特殊符号...',
                    onChanged: (value) {
                      setState(() {
                        _selectedAnswer = value;
                      });
                      widget.onAnswer?.call(value);
                    },
                  ),
                ],
              ),
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

          // 多选题选项
          if (widget.type == QuestionType.multipleChoice &&
              widget.options != null) ...[
            const SizedBox(height: 12),
            ...widget.options!.asMap().entries.map((entry) {
              final idx = entry.key;
              final optionText = _parseOptionText(entry.value);
              final optionLabel = _optionLabels[idx];
              final selectedAnswers = _selectedAnswer?.split(',').toSet() ?? <String>{};
              final isSelected = selectedAnswers.contains(optionLabel);
              final correctAnswers = widget.correctAnswer?.split(',').toSet() ?? <String>{};
              final isCorrect = correctAnswers.contains(optionLabel);

              return QuestionOption(
                label: optionLabel,
                text: optionText,
                isSelected: isSelected,
                isCorrect: isCorrect,
                showResult: widget.showResult,
                enabled: !widget.showResult,
                onTap: (_) {
                  setState(() {
                    final currentSelected = _selectedAnswer?.split(',').where((s) => s.isNotEmpty).toSet() ?? <String>{};
                    if (currentSelected.contains(optionLabel)) {
                      currentSelected.remove(optionLabel);
                    } else {
                      currentSelected.add(optionLabel);
                    }
                    final sorted = currentSelected.toList()..sort();
                    _selectedAnswer = sorted.join(',');
                  });
                  widget.onAnswer?.call(_selectedAnswer ?? '');
                },
              );
            }),
          ],

          // 简答题/证明题/论述题输入框（用于需要文字作答的题型，带特殊符号按钮）
          if ((widget.type == QuestionType.shortAnswer ||
               widget.type == QuestionType.proof ||
               widget.type == QuestionType.essay ||
               (widget.options == null &&
                widget.type != QuestionType.singleChoice &&
                widget.type != QuestionType.multipleChoice &&
                widget.type != QuestionType.trueFalse &&
                widget.type != QuestionType.fillBlank)) &&
              !widget.showResult) ...[
            const SizedBox(height: 16),
            _buildAnswerAreaWithSymbols(
              hintText: widget.type == QuestionType.proof
                  ? '请输入证明过程，点击右侧 ƒ 按钮插入数学符号...'
                  : widget.type == QuestionType.essay
                      ? '请输入论述内容，点击右侧 ƒ 按钮插入特殊符号...'
                      : '请输入您的答案，点击右侧 ƒ 按钮插入特殊符号...',
              maxLines: widget.type == QuestionType.proof || widget.type == QuestionType.essay ? 8 : 5,
              maxLength: widget.type == QuestionType.proof || widget.type == QuestionType.essay ? 2000 : 1000,
              onChanged: (value) {
                setState(() {
                  _selectedAnswer = value;
                });
                widget.onAnswer?.call(value);
              },
            ),
          ],

          // 简答题/证明题/论述题答案显示
          if ((widget.type == QuestionType.shortAnswer ||
               widget.type == QuestionType.proof ||
               widget.type == QuestionType.essay) &&
              widget.showResult &&
              widget.correctAnswer != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.info),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lightbulb_outline,
                          color: AppColors.info, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '参考答案',
                        style: TextStyle(
                          fontSize: AppFontSize.md,
                          color: AppColors.info,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.correctAnswer!,
                    style: TextStyle(
                      fontSize: AppFontSize.md,
                      color: AppColors.textPrimary,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
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

  /// 构建带符号按钮的输入框（用于填空题）
  Widget _buildSymbolInputField({
    required String hintText,
    required ValueChanged<String> onChanged,
  }) {
    final controller = TextEditingController();
    return Row(
      children: [
        Expanded(
          child: AppInput(
            hintText: hintText,
            controller: controller,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 8),
        _buildSymbolButton(controller, onChanged),
      ],
    );
  }

  /// 构建带符号按钮的多行文本框（用于简答题）
  Widget _buildSymbolTextField({
    required String hintText,
    required int maxLines,
    required int? maxLength,
    required ValueChanged<String> onChanged,
  }) {
    final controller = TextEditingController();
    return StatefulBuilder(
      builder: (context, setState) {
        return TextField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            filled: true,
            fillColor: AppColors.background,
            suffixIcon: _buildSymbolButton(controller, onChanged, isCompact: true),
            counterText: '', // 隐藏默认计数器
          ),
          style: TextStyle(
            fontSize: AppFontSize.md,
            color: AppColors.textPrimary,
          ),
          onChanged: (value) {
            setState(() {}); // 更新字数统计
            onChanged(value);
          },
        );
      },
    );
  }

  /// 构建带特殊符号按钮的答题区域（用于简答题/证明题/论述题）
  Widget _buildAnswerAreaWithSymbols({
    required String hintText,
    required int maxLines,
    required int maxLength,
    required ValueChanged<String> onChanged,
  }) {
    final controller = TextEditingController();
    final theme = Theme.of(context);

    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部：标题和字数统计
              Row(
                children: [
                  Icon(
                    Icons.edit_note,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '答题区域',
                    style: TextStyle(
                      fontSize: AppFontSize.sm,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  // 字数统计
                  Text(
                    '${controller.text.length}/$maxLength',
                    style: TextStyle(
                      fontSize: AppFontSize.xs,
                      color: controller.text.length > maxLength * 0.9
                          ? AppColors.error
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 文本输入框
              TextField(
                controller: controller,
                maxLines: maxLines,
                maxLength: maxLength,
                decoration: InputDecoration(
                  hintText: hintText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                  suffixIcon: _buildSymbolButton(controller, onChanged, isCompact: true),
                  counterText: '', // 隐藏默认计数器
                ),
                style: TextStyle(
                  fontSize: AppFontSize.md,
                  color: AppColors.textPrimary,
                ),
                onChanged: (value) {
                  setState(() {}); // 更新字数统计
                  onChanged(value);
                },
              ),
              const SizedBox(height: 8),
              // 提示文字
              Row(
                children: [
                  Icon(
                    Icons.functions,
                    size: 14,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '点击输入框右侧的 ƒ 按钮插入数学/化学符号',
                      style: TextStyle(
                        fontSize: AppFontSize.xs,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建符号按钮
  Widget _buildSymbolButton(
    TextEditingController controller,
    ValueChanged<String> onChanged, {
    bool isCompact = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          SpecialSymbolInput.showBottomSheet(
            context: context,
            controller: controller,
            onSymbolTap: (symbol) {
              onChanged(controller.text);
            },
          );
        },
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          padding: EdgeInsets.all(isCompact ? 8 : 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(
            Icons.functions,
            size: isCompact ? 20 : 24,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
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
// SpecialSymbolInput - 特殊符号输入面板
// ============================================================

/// SpecialSymbolInput: 特殊符号输入面板
/// 支持数学符号、化学符号和上下标
class SpecialSymbolInput extends StatefulWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onSymbolTap;
  final bool showSuperscriptSubscript;

  const SpecialSymbolInput({
    super.key,
    this.controller,
    this.onSymbolTap,
    this.showSuperscriptSubscript = true,
  });

  @override
  State<SpecialSymbolInput> createState() => _SpecialSymbolInputState();

  /// 显示特殊符号输入面板（底部弹出）
  static Future<void> showBottomSheet({
    required BuildContext context,
    TextEditingController? controller,
    ValueChanged<String>? onSymbolTap,
    bool showSuperscriptSubscript = true,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SpecialSymbolInput(
        controller: controller,
        onSymbolTap: onSymbolTap,
        showSuperscriptSubscript: showSuperscriptSubscript,
      ),
    );
  }
}

class _SpecialSymbolInputState extends State<SpecialSymbolInput>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 数学符号
  final List<String> _mathSymbols = [
    '±', '×', '÷', '√', '∞', '∫', '∑', '∏', '∂', '∆',
    'π', 'α', 'β', 'γ', 'θ', 'λ', 'μ', 'σ', 'φ', 'ω',
    '≤', '≥', '≠', '≈', '∼', '∈', '∉', '∩', '∪', '⊂',
    '⊃', '⊆', '⊇', '∅', '∀', '∃', '∴', '∵', '°', '′',
    '″', '∠', '⊥', '∥', '→', '←', '↑', '↓', '↔', '⇌',
  ];

  // 化学符号
  final List<String> _chemSymbols = [
    '°', '→', '⇌', '↑', '↓', '(s)', '(l)', '(g)', '(aq)',
    'Δ', '±', 'mol', 'g', 'L', 'mL', 'cm³', 'dm³', 'nm', 'pm',
    '℃', '℉', 'K', 'Pa', 'kPa', 'MPa', 'atm', 'mmHg',
    'H', 'He', 'Li', 'Be', 'B', 'C', 'N', 'O', 'F', 'Ne',
    'Na', 'Mg', 'Al', 'Si', 'P', 'S', 'Cl', 'Ar', 'K', 'Ca',
  ];

  // 上标符号
  final List<String> _superscripts = [
    '⁰', '¹', '²', '³', '⁴', '⁵', '⁶', '⁷', '⁸', '⁹',
    '⁺', '⁻', '⁼', '⁽', '⁾', 'ⁿ', 'ⁱ', 'ˣ', 'ʸ', 'ᶻ',
    'ᵃ', 'ᵇ', 'ᶜ', 'ᵈ', 'ᵉ', 'ᶠ', 'ᵍ', 'ʰ', 'ⁱ', 'ʲ',
    'ᵏ', 'ˡ', 'ᵐ', 'ⁿ', 'ᵒ', 'ᵖ', 'ʳ', 'ˢ', 'ᵗ', 'ᵘ',
    'ᵛ', 'ʷ', 'ˣ', 'ʸ', 'ᶻ', 'ᴬ', 'ᴮ', 'ᴰ', 'ᴱ', 'ᴳ',
  ];

  // 下标符号
  final List<String> _subscripts = [
    '₀', '₁', '₂', '₃', '₄', '₅', '₆', '₇', '₈', '₉',
    '₊', '₋', '₌', '₍', '₎', 'ₐ', 'ₑ', 'ₕ', 'ᵢ', 'ⱼ',
    'ₖ', 'ₗ', 'ₘ', 'ₙ', 'ₒ', 'ₚ', 'ᵣ', 'ₛ', 'ₜ', 'ᵤ',
    'ᵥ', 'ₓ', 'ᵧ', 'ᵦ', 'ᵧ', 'ᵨ', 'ᵩ', 'ᵪ', 'ᵧ', 'ᵨ',
  ];

  @override
  void initState() {
    super.initState();
    final tabCount = widget.showSuperscriptSubscript ? 4 : 2;
    _tabController = TabController(length: tabCount, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _insertSymbol(String symbol) {
    if (widget.onSymbolTap != null) {
      widget.onSymbolTap!(symbol);
    } else if (widget.controller != null) {
      final controller = widget.controller!;
      final text = controller.text;
      final selection = controller.selection;
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        symbol,
      );
      controller.text = newText;
      controller.selection = TextSelection.collapsed(
        offset: selection.start + symbol.length,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tab 栏
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: theme.colorScheme.primary,
            tabs: [
              const Tab(text: '数学'),
              const Tab(text: '化学'),
              if (widget.showSuperscriptSubscript) ...[
                const Tab(text: '上标'),
                const Tab(text: '下标'),
              ],
            ],
          ),
          // 符号网格
          SizedBox(
            height: 160,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSymbolGrid(_mathSymbols),
                _buildSymbolGrid(_chemSymbols),
                if (widget.showSuperscriptSubscript) ...[
                  _buildSymbolGrid(_superscripts),
                  _buildSymbolGrid(_subscripts),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSymbolGrid(List<String> symbols) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 10,
        childAspectRatio: 1.2,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: symbols.length,
      itemBuilder: (context, index) {
        final symbol = symbols[index];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _insertSymbol(symbol),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.divider),
              ),
              alignment: Alignment.center,
              child: Text(
                symbol,
                style: TextStyle(
                  fontSize: 18,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      },
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
