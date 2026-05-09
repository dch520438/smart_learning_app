import 'dart:io';
import 'package:flutter/material.dart';
import '../models/exam_paper.dart';
import '../utils/constants.dart';
import 'common_widgets.dart';

/// 试卷卡片组件
class ExamPaperCard extends StatelessWidget {
  final ExamPaper examPaper;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ExamPaperCard({
    super.key,
    required this.examPaper,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjectColor = getSubjectColor(examPaper.subject);
    final hasScore = examPaper.obtainedScore != null;
    final scoreRate = examPaper.scoreRate ?? 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SubjectIcon(subjectName: examPaper.subject, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          examPaper.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            AppTag(
                              label: examPaper.subject,
                              color: subjectColor,
                              dense: true,
                            ),
                            const SizedBox(width: 8),
                            AppTag(
                              label: examPaper.source.label,
                              color: AppColors.info,
                              dense: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (onDelete != null)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'delete') onDelete!();
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                              SizedBox(width: 8),
                              Text('删除'),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    examPaper.examDateString,
                    style: TextStyle(
                      fontSize: AppFontSize.sm,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (hasScore) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: scoreRate >= 0.6
                            ? AppColors.success.withOpacity(0.1)
                            : AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${examPaper.obtainedScore}/${examPaper.totalScore}',
                        style: TextStyle(
                          fontSize: AppFontSize.md,
                          fontWeight: FontWeight.bold,
                          color: scoreRate >= 0.6 ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      examPaper.scoreRateString,
                      style: TextStyle(
                        fontSize: AppFontSize.sm,
                        color: scoreRate >= 0.6 ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ] else
                    Text(
                      '总分: ${examPaper.totalScore}',
                      style: TextStyle(
                        fontSize: AppFontSize.sm,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
              if (examPaper.images.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.image, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${examPaper.images.length} 张图片',
                      style: TextStyle(
                        fontSize: AppFontSize.sm,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
              if (examPaper.notes != null && examPaper.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.notes, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          examPaper.notes!,
                          style: TextStyle(
                            fontSize: AppFontSize.sm,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 试卷图片预览组件
class ExamPaperImagePreview extends StatelessWidget {
  final ExamPaperImage image;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const ExamPaperImagePreview({
    super.key,
    required this.image,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(image.path),
              fit: BoxFit.cover,
            ),
            // 页码标签
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '第${image.pageNumber}页',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            // 删除按钮
            if (onDelete != null)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            // OCR文本预览
            if (image.ocrText != null && image.ocrText!.isNotEmpty)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black87,
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Text(
                    image.ocrText!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 试卷题目组件
class ExamPaperQuestionItem extends StatelessWidget {
  final ExamPaperQuestion question;
  final int index;
  final VoidCallback? onDelete;

  const ExamPaperQuestionItem({
    super.key,
    required this.question,
    required this.index,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCorrect = question.score != null &&
        question.fullScore != null &&
        question.score == question.fullScore;
    final hasAnswer = question.userAnswer != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: hasAnswer
                        ? (isCorrect ? AppColors.success : AppColors.error)
                        : AppColors.textHint,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    question.content,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error),
                    onPressed: onDelete,
                  ),
              ],
            ),
            if (question.userAnswer != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow('你的答案', question.userAnswer!,
                  isCorrect: isCorrect),
            ],
            if (question.correctAnswer != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow('正确答案', question.correctAnswer!,
                  isAnswer: true),
            ],
            if (question.score != null && question.fullScore != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                '得分',
                '${question.score}/${question.fullScore}',
                isCorrect: question.score == question.fullScore,
              ),
            ],
            if (question.analysis != null && question.analysis!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb, size: 16, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        question.analysis!,
                        style: TextStyle(
                          fontSize: AppFontSize.sm,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value,
      {bool isCorrect = false, bool isAnswer = false}) {
    Color valueColor;
    if (isAnswer) {
      valueColor = AppColors.success;
    } else if (isCorrect) {
      valueColor = AppColors.success;
    } else {
      valueColor = AppColors.error;
    }

    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: AppFontSize.sm,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: AppFontSize.sm,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

/// 试卷统计卡片
class ExamPaperStatsCard extends StatelessWidget {
  final int totalCount;
  final double averageScore;

  const ExamPaperStatsCard({
    super.key,
    required this.totalCount,
    required this.averageScore,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _buildStatItem(
                icon: Icons.description,
                iconColor: AppColors.primary,
                label: '试卷总数',
                value: '$totalCount',
              ),
            ),
            Container(width: 1, height: 40, color: AppColors.divider),
            Expanded(
              child: _buildStatItem(
                icon: Icons.trending_up,
                iconColor: AppColors.success,
                label: '平均得分率',
                value: '${averageScore.toStringAsFixed(1)}%',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// 试卷来源标签
class ExamPaperSourceTag extends StatelessWidget {
  final ExamPaperSource source;
  final bool dense;

  const ExamPaperSourceTag({
    super.key,
    required this.source,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppTag(
      label: source.label,
      color: _getSourceColor(source),
      dense: dense,
    );
  }

  Color _getSourceColor(ExamPaperSource source) {
    switch (source) {
      case ExamPaperSource.mock:
        return AppColors.primary;
      case ExamPaperSource.school:
        return AppColors.success;
      case ExamPaperSource.offline:
        return AppColors.warning;
    }
  }
}

/// 试卷筛选器
class ExamPaperFilter extends StatelessWidget {
  final String? selectedSubject;
  final String? selectedSource;
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(String?) onSubjectChanged;
  final Function(String?) onSourceChanged;
  final Function(DateTime?) onStartDateChanged;
  final Function(DateTime?) onEndDateChanged;
  final VoidCallback onReset;

  const ExamPaperFilter({
    super.key,
    this.selectedSubject,
    this.selectedSource,
    this.startDate,
    this.endDate,
    required this.onSubjectChanged,
    required this.onSourceChanged,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 学科筛选
        Text('学科', style: TextStyle(fontSize: AppFontSize.md, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppTag(
              label: '全部',
              color: AppColors.primary,
              selected: selectedSubject == null,
              onTap: () => onSubjectChanged(null),
            ),
            ...kSubjectNames.map((subject) => AppTag(
              label: subject,
              color: getSubjectColor(subject),
              selected: selectedSubject == subject,
              onTap: () => onSubjectChanged(subject),
            )),
          ],
        ),
        const SizedBox(height: 16),

        // 来源筛选
        Text('来源', style: TextStyle(fontSize: AppFontSize.md, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppTag(
              label: '全部',
              color: AppColors.primary,
              selected: selectedSource == null,
              onTap: () => onSourceChanged(null),
            ),
            ...ExamPaperSource.values.map((source) => AppTag(
              label: source.label,
              color: AppColors.info,
              selected: selectedSource == source.value,
              onTap: () => onSourceChanged(source.value),
            )),
          ],
        ),
        const SizedBox(height: 16),

        // 日期范围
        Text('日期范围', style: TextStyle(fontSize: AppFontSize.md, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_today),
          title: const Text('开始日期'),
          subtitle: Text(startDate != null ? _formatDate(startDate!) : '不限'),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: startDate ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              onStartDateChanged(picked);
            }
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_today),
          title: const Text('结束日期'),
          subtitle: Text(endDate != null ? _formatDate(endDate!) : '不限'),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: endDate ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              onEndDateChanged(picked);
            }
          },
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// 试卷分数进度条
class ExamPaperScoreProgress extends StatelessWidget {
  final int obtainedScore;
  final int totalScore;
  final double height;

  const ExamPaperScoreProgress({
    super.key,
    required this.obtainedScore,
    required this.totalScore,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalScore > 0 ? obtainedScore / totalScore : 0.0;
    final color = progress >= 0.6 ? AppColors.success : AppColors.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$obtainedScore / $totalScore',
              style: TextStyle(
                fontSize: AppFontSize.md,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            Text(
              '${(progress * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: AppFontSize.sm,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: height,
            backgroundColor: AppColors.divider,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

/// 试卷分析摘要
class ExamPaperAnalysisSummary extends StatelessWidget {
  final int totalQuestions;
  final int wrongQuestions;
  final int answeredQuestions;

  const ExamPaperAnalysisSummary({
    super.key,
    required this.totalQuestions,
    required this.wrongQuestions,
    required this.answeredQuestions,
  });

  @override
  Widget build(BuildContext context) {
    final correctQuestions = answeredQuestions - wrongQuestions;
    final accuracy = answeredQuestions > 0
        ? (correctQuestions / answeredQuestions * 100).toStringAsFixed(1)
        : '0.0';

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
                  '试卷分析',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildAnalysisItem('总题数', '$totalQuestions 道', AppColors.primary),
            const SizedBox(height: 8),
            _buildAnalysisItem('已答', '$answeredQuestions 道', AppColors.info),
            const SizedBox(height: 8),
            _buildAnalysisItem('错题', '$wrongQuestions 道', AppColors.error),
            const SizedBox(height: 8),
            _buildAnalysisItem('正确率', '$accuracy%', AppColors.success),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisItem(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: AppFontSize.md,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: AppFontSize.md,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
