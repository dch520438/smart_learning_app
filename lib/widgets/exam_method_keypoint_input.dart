import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

/// ============================================================
/// ExamMethodKeyPointInput - 考法考点输入组件
/// ============================================================
/// 
/// 支持功能：
/// - 标签式输入（可添加多个）
/// - 从已有考法考点中选择
/// - 支持自定义输入
/// - 支持分类显示（考法/考点）

class ExamMethodKeyPointInput extends StatefulWidget {
  final List<String> examMethods;
  final List<String> keyPoints;
  final Function(List<String>) onExamMethodsChanged;
  final Function(List<String>) onKeyPointsChanged;
  final List<String>? existingExamMethods; // 已有的考法选项
  final List<String>? existingKeyPoints; // 已有的考点选项

  const ExamMethodKeyPointInput({
    super.key,
    required this.examMethods,
    required this.keyPoints,
    required this.onExamMethodsChanged,
    required this.onKeyPointsChanged,
    this.existingExamMethods,
    this.existingKeyPoints,
  });

  @override
  State<ExamMethodKeyPointInput> createState() => _ExamMethodKeyPointInputState();
}

class _ExamMethodKeyPointInputState extends State<ExamMethodKeyPointInput> {
  final TextEditingController _examMethodController = TextEditingController();
  final TextEditingController _keyPointController = TextEditingController();

  @override
  void dispose() {
    _examMethodController.dispose();
    _keyPointController.dispose();
    super.dispose();
  }

  void _addExamMethod(String value) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty && !widget.examMethods.contains(trimmed)) {
      widget.onExamMethodsChanged([...widget.examMethods, trimmed]);
      _examMethodController.clear();
    }
  }

  void _removeExamMethod(String value) {
    widget.onExamMethodsChanged(
      widget.examMethods.where((e) => e != value).toList(),
    );
  }

  void _addKeyPoint(String value) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty && !widget.keyPoints.contains(trimmed)) {
      widget.onKeyPointsChanged([...widget.keyPoints, trimmed]);
      _keyPointController.clear();
    }
  }

  void _removeKeyPoint(String value) {
    widget.onKeyPointsChanged(
      widget.keyPoints.where((e) => e != value).toList(),
    );
  }

  void _showSelectionDialog(bool isExamMethod) {
    final existingItems = isExamMethod
        ? (widget.existingExamMethods ?? [])
        : (widget.existingKeyPoints ?? []);
    final currentItems = isExamMethod ? widget.examMethods : widget.keyPoints;
    final title = isExamMethod ? '选择考法' : '选择考点';
    final icon = isExamMethod ? Icons.quiz_outlined : Icons.lightbulb_outline;
    final color = isExamMethod ? AppColors.primary : AppColors.warning;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题栏
                Row(
                  children: [
                    Icon(icon, color: color),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: AppFontSize.lg,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('完成'),
                    ),
                  ],
                ),
                const Divider(),
                // 已选项
                if (currentItems.isNotEmpty) ...[
                  Text(
                    '已选择:',
                    style: TextStyle(
                      fontSize: AppFontSize.sm,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: currentItems.map((item) {
                      return Chip(
                        label: Text(item),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          if (isExamMethod) {
                            _removeExamMethod(item);
                          } else {
                            _removeKeyPoint(item);
                          }
                          setState(() {});
                        },
                        backgroundColor: color.withOpacity(0.1),
                        labelStyle: TextStyle(
                          color: color,
                          fontSize: AppFontSize.sm,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                ],
                // 可选项
                Expanded(
                  child: existingItems.isEmpty
                      ? Center(
                          child: Text(
                            '暂无已有选项，请直接输入添加',
                            style: TextStyle(
                              color: AppColors.textHint,
                              fontSize: AppFontSize.md,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: existingItems.length,
                          itemBuilder: (context, index) {
                            final item = existingItems[index];
                            final isSelected = currentItems.contains(item);
                            return ListTile(
                              leading: Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                color: isSelected ? color : AppColors.textHint,
                              ),
                              title: Text(item),
                              onTap: () {
                                if (isSelected) {
                                  if (isExamMethod) {
                                    _removeExamMethod(item);
                                  } else {
                                    _removeKeyPoint(item);
                                  }
                                } else {
                                  if (isExamMethod) {
                                    _addExamMethod(item);
                                  } else {
                                    _addKeyPoint(item);
                                  }
                                }
                                setState(() {});
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 考法输入区域
        _buildSectionHeader(
          '考法',
          Icons.quiz_outlined,
          AppColors.primary,
          () => _showSelectionDialog(true),
        ),
        const SizedBox(height: 8),
        _buildTagInputArea(
          items: widget.examMethods,
          controller: _examMethodController,
          hintText: '添加考法...',
          onAdd: _addExamMethod,
          onRemove: _removeExamMethod,
          color: AppColors.primary,
        ),
        const SizedBox(height: 16),

        // 考点输入区域
        _buildSectionHeader(
          '考点',
          Icons.lightbulb_outline,
          AppColors.warning,
          () => _showSelectionDialog(false),
        ),
        const SizedBox(height: 8),
        _buildTagInputArea(
          items: widget.keyPoints,
          controller: _keyPointController,
          hintText: '添加考点...',
          onAdd: _addKeyPoint,
          onRemove: _removeKeyPoint,
          color: AppColors.warning,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon,
    Color color,
    VoidCallback onSelect,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: AppFontSize.md,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: onSelect,
          icon: const Icon(Icons.list, size: 16),
          label: const Text('从列表选择'),
          style: TextButton.styleFrom(
            foregroundColor: color,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }

  Widget _buildTagInputArea({
    required List<String> items,
    required TextEditingController controller,
    required String hintText,
    required Function(String) onAdd,
    required Function(String) onRemove,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标签展示
          if (items.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map((item) {
                return Chip(
                  label: Text(
                    item,
                    style: TextStyle(
                      fontSize: AppFontSize.sm,
                      color: color,
                    ),
                  ),
                  deleteIcon: Icon(Icons.close, size: 16, color: color),
                  onDeleted: () => onRemove(item),
                  backgroundColor: color.withOpacity(0.1),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],
          // 输入框
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: hintText,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: color.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: color.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: color),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  style: TextStyle(fontSize: AppFontSize.md),
                  onSubmitted: onAdd,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => onAdd(controller.text),
                icon: Icon(Icons.add_circle, color: color),
                tooltip: '添加',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// ExamMethodKeyPointDisplay - 考法考点展示组件
/// ============================================================

class ExamMethodKeyPointDisplay extends StatelessWidget {
  final List<String> examMethods;
  final List<String> keyPoints;
  final bool compact;

  const ExamMethodKeyPointDisplay({
    super.key,
    required this.examMethods,
    required this.keyPoints,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (examMethods.isEmpty && keyPoints.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (examMethods.isNotEmpty) ...[
          _buildSection('考法', Icons.quiz_outlined, AppColors.primary, examMethods),
          if (keyPoints.isNotEmpty) const SizedBox(height: 8),
        ],
        if (keyPoints.isNotEmpty)
          _buildSection('考点', Icons.lightbulb_outline, AppColors.warning, keyPoints),
      ],
    );
  }

  Widget _buildSection(
    String title,
    IconData icon,
    Color color,
    List<String> items,
  ) {
    if (compact) {
      return Wrap(
        spacing: 4,
        runSpacing: 4,
        children: items.map((item) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              item,
              style: TextStyle(
                fontSize: AppFontSize.xs,
                color: color,
              ),
            ),
          );
        }).toList(),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: items.map((item) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: AppFontSize.sm,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
