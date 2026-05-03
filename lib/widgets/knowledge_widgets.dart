import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'common_widgets.dart';

// ============================================================
// KnowledgePointCard - 知识点卡片
// ============================================================

/// KnowledgePointCard: 知识点卡片组件
class KnowledgePointCard extends StatelessWidget {
  final String id;
  final String title;
  final String subject;
  final int difficulty;
  final int mastery;
  final String? summary;
  final DateTime? updatedAt;
  final int questionCount;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isSelected;
  final ValueChanged<bool>? onSelectionChanged;

  const KnowledgePointCard({
    super.key,
    required this.id,
    required this.title,
    required this.subject,
    this.difficulty = 1,
    this.mastery = 0,
    this.summary,
    this.updatedAt,
    this.questionCount = 0,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.isSelected = false,
    this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjectColor = getSubjectColor(subject);

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：学科图标 + 标题 + 操作
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 选择框（可选）
                if (onSelectionChanged != null) ...[
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (value) =>
                          onSelectionChanged?.call(value ?? false),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // 学科图标
                SubjectIcon(
                  subjectName: subject,
                  size: 36,
                ),
                const SizedBox(width: 12),
                // 标题和学科
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          AppTag(
                            label: subject,
                            color: subjectColor,
                            dense: true,
                            fontSize: AppFontSize.xs,
                          ),
                          const SizedBox(width: 8),
                          DifficultyStars(
                            difficulty: difficulty,
                            iconSize: 14,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 更多操作
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit?.call();
                        break;
                      case 'delete':
                        onDelete?.call();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('编辑'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18,
                              color: AppColors.error),
                          SizedBox(width: 8),
                          Text('删除', style: TextStyle(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 摘要
          if (summary != null && summary!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                summary!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          // 掌握度进度条
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: MasteryProgressBar(
              mastery: mastery,
              height: 6,
            ),
          ),
          // 底部信息
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Icon(
                  Icons.quiz_outlined,
                  size: 14,
                  color: AppColors.textHint,
                ),
                const SizedBox(width: 4),
                Text(
                  '$questionCount题',
                  style: TextStyle(
                    fontSize: AppFontSize.xs,
                    color: AppColors.textHint,
                  ),
                ),
                if (updatedAt != null) ...[
                  const Spacer(),
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    formatFriendlyTime(updatedAt!),
                    style: TextStyle(
                      fontSize: AppFontSize.xs,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// KnowledgeFilterBar - 知识点筛选栏
// ============================================================

/// KnowledgeFilterBar: 知识点筛选栏（按学科、难度、掌握度筛选）
class KnowledgeFilterBar extends StatefulWidget {
  final String? selectedSubject;
  final int? selectedDifficulty;
  final int? selectedMasteryRange;
  final ValueChanged<String?>? onSubjectChanged;
  final ValueChanged<int?>? onDifficultyChanged;
  final ValueChanged<int?>? onMasteryRangeChanged;
  final VoidCallback? onReset;

  const KnowledgeFilterBar({
    super.key,
    this.selectedSubject,
    this.selectedDifficulty,
    this.selectedMasteryRange,
    this.onSubjectChanged,
    this.onDifficultyChanged,
    this.onMasteryRangeChanged,
    this.onReset,
  });

  @override
  State<KnowledgeFilterBar> createState() => _KnowledgeFilterBarState();
}

class _KnowledgeFilterBarState extends State<KnowledgeFilterBar> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isWideScreen ? 32 : 16,
        vertical: 8,
      ),
      child: Column(
        children: [
          // 筛选触发按钮
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.filter_list_rounded,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '筛选',
                        style: TextStyle(
                          fontSize: AppFontSize.md,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      // 已选筛选条件标签
                      if (widget.selectedSubject != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: AppTag(
                            label: widget.selectedSubject!,
                            color: getSubjectColor(widget.selectedSubject!),
                            dense: true,
                            fontSize: AppFontSize.xs,
                          ),
                        ),
                      if (widget.selectedDifficulty != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: AppTag(
                            label: getDifficultyLabel(widget.selectedDifficulty!),
                            color: getDifficultyColor(widget.selectedDifficulty!),
                            dense: true,
                            fontSize: AppFontSize.xs,
                          ),
                        ),
                      if (widget.selectedMasteryRange != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: AppTag(
                            label: '掌握度 ${widget.selectedMasteryRange}%',
                            color: getMasteryColor(widget.selectedMasteryRange!),
                            dense: true,
                            fontSize: AppFontSize.xs,
                          ),
                        ),
                      Icon(
                        _isExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 展开的筛选面板
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildFilterPanel(theme),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 学科筛选
          _buildFilterSection(
            label: '学科',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppTag(
                  label: '全部',
                  selected: widget.selectedSubject == null,
                  onTap: () => widget.onSubjectChanged?.call(null),
                ),
                ...kSubjectNames.map((subject) => AppTag(
                      label: subject,
                      color: getSubjectColor(subject),
                      selected: widget.selectedSubject == subject,
                      onTap: () => widget.onSubjectChanged?.call(subject),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 难度筛选
          _buildFilterSection(
            label: '难度',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppTag(
                  label: '全部',
                  selected: widget.selectedDifficulty == null,
                  onTap: () => widget.onDifficultyChanged?.call(null),
                ),
                ...kDifficultyLevels.map((level) => AppTag(
                      label: level['label'] as String,
                      color: level['color'] as Color,
                      selected:
                          widget.selectedDifficulty == level['value'] as int,
                      onTap: () => widget.onDifficultyChanged
                          ?.call(level['value'] as int),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 掌握度筛选
          _buildFilterSection(
            label: '掌握度',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppTag(
                  label: '全部',
                  selected: widget.selectedMasteryRange == null,
                  onTap: () => widget.onMasteryRangeChanged?.call(null),
                ),
                AppTag(
                  label: '0-25%',
                  color: getMasteryColor(0),
                  selected: widget.selectedMasteryRange == 0,
                  onTap: () => widget.onMasteryRangeChanged?.call(0),
                ),
                AppTag(
                  label: '25-50%',
                  color: getMasteryColor(25),
                  selected: widget.selectedMasteryRange == 25,
                  onTap: () => widget.onMasteryRangeChanged?.call(25),
                ),
                AppTag(
                  label: '50-75%',
                  color: getMasteryColor(50),
                  selected: widget.selectedMasteryRange == 50,
                  onTap: () => widget.onMasteryRangeChanged?.call(50),
                ),
                AppTag(
                  label: '75-100%',
                  color: getMasteryColor(75),
                  selected: widget.selectedMasteryRange == 75,
                  onTap: () => widget.onMasteryRangeChanged?.call(75),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 重置按钮
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: widget.onReset,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('重置筛选'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: AppFontSize.sm,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

// ============================================================
// KnowledgeDetailPage - 知识点详情页
// ============================================================

/// KnowledgeDetailPage: 知识点详情页
class KnowledgeDetailPage extends StatelessWidget {
  final String knowledgeId;
  final String title;
  final String? subject;
  final int? difficulty;
  final int? mastery;
  final String? content;
  final String? summary;
  final List<Map<String, dynamic>>? relatedQuestions;
  final List<Map<String, dynamic>>? relatedNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onPractice;

  const KnowledgeDetailPage({
    super.key,
    required this.knowledgeId,
    required this.title,
    this.subject,
    this.difficulty,
    this.mastery,
    this.content,
    this.summary,
    this.relatedQuestions,
    this.relatedNotes,
    this.createdAt,
    this.updatedAt,
    this.onEdit,
    this.onDelete,
    this.onPractice,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;
    final effectiveSubject = subject ?? '其他';
    final effectiveDifficulty = difficulty ?? 1;
    final effectiveMastery = mastery ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('知识点详情'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: onEdit,
            tooltip: '编辑',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirmed = await ConfirmDeleteDialog.show(
                context: context,
                message: '确定要删除知识点"$title"吗？',
              );
              if (confirmed == true) {
                onDelete?.call();
              }
            },
            tooltip: '删除',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isWideScreen ? 48 : 16,
          vertical: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题区域
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SubjectIcon(
                  subjectName: effectiveSubject,
                  size: 48,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          AppTag(
                            label: effectiveSubject,
                            color: getSubjectColor(effectiveSubject),
                          ),
                          const SizedBox(width: 12),
                          DifficultyStars(difficulty: effectiveDifficulty),
                          const SizedBox(width: 12),
                          Text(
                            getDifficultyLabel(effectiveDifficulty),
                            style: TextStyle(
                              fontSize: AppFontSize.sm,
                              color: getDifficultyColor(effectiveDifficulty),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 掌握度
            AppCard(
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.trending_up_rounded,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '掌握度',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  MasteryProgressBar(
                    mastery: effectiveMastery,
                    height: 10,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 摘要
            if (summary != null && summary!.isNotEmpty) ...[
              AppCard(
                margin: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.summarize_rounded,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '摘要',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      summary!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 详细内容
            if (content != null && content!.isNotEmpty) ...[
              AppCard(
                margin: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '详细内容',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      content!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 相关题目
            if (relatedQuestions != null && relatedQuestions!.isNotEmpty) ...[
              AppCard(
                margin: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.quiz_outlined,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '相关题目 (${relatedQuestions!.length})',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...relatedQuestions!.map((q) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor:
                                getDifficultyColor(q['difficulty'] as int? ?? 1)
                                    .withOpacity(0.1),
                            child: Text(
                              '${(q['index'] as int? ?? 0) + 1}',
                              style: TextStyle(
                                fontSize: AppFontSize.sm,
                                fontWeight: FontWeight.w600,
                                color: getDifficultyColor(
                                    q['difficulty'] as int? ?? 1),
                              ),
                            ),
                          ),
                          title: Text(
                            q['title'] as String? ?? '题目',
                            style: theme.textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap: () {
                            // 跳转到题目详情
                          },
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 相关笔记
            if (relatedNotes != null && relatedNotes!.isNotEmpty) ...[
              AppCard(
                margin: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.note_outlined,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '相关笔记 (${relatedNotes!.length})',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...relatedNotes!.map((n) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.sticky_note_2_outlined,
                            color: AppColors.warning,
                          ),
                          title: Text(
                            n['title'] as String? ?? '笔记',
                            style: theme.textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: n['updatedAt'] != null
                              ? Text(
                                  formatFriendlyTime(
                                      n['updatedAt'] as DateTime),
                                  style: TextStyle(
                                    fontSize: AppFontSize.xs,
                                    color: AppColors.textHint,
                                  ),
                                )
                              : null,
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap: () {
                            // 跳转到笔记详情
                          },
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 时间信息
            if (createdAt != null || updatedAt != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    if (createdAt != null) ...[
                      Icon(Icons.access_time,
                          size: 14, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text(
                        '创建于 ${formatDate(createdAt!)}',
                        style: TextStyle(
                          fontSize: AppFontSize.xs,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                    if (createdAt != null && updatedAt != null)
                      const SizedBox(width: 16),
                    if (updatedAt != null) ...[
                      Icon(Icons.update,
                          size: 14, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text(
                        '更新于 ${formatFriendlyTime(updatedAt!)}',
                        style: TextStyle(
                          fontSize: AppFontSize.xs,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: '开始练习',
                    icon: Icons.play_arrow_rounded,
                    onPressed: onPractice,
                    style: AppButtonStyle.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    text: '编辑知识点',
                    icon: Icons.edit_outlined,
                    onPressed: onEdit,
                    style: AppButtonStyle.outlined,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
