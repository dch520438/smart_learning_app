import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/exam_paper.dart';
import '../../services/database_service.dart';
import '../../services/ocr_service.dart';
import '../../services/voice_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

/// 试卷详情页面
class ExamPaperDetailScreen extends StatefulWidget {
  final ExamPaper examPaper;

  const ExamPaperDetailScreen({
    super.key,
    required this.examPaper,
  });

  @override
  State<ExamPaperDetailScreen> createState() => _ExamPaperDetailScreenState();
}

class _ExamPaperDetailScreenState extends State<ExamPaperDetailScreen> with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  final OcrService _ocrService = OcrService();
  final VoiceService _voiceService = VoiceService();

  late ExamPaper _examPaper;
  bool _isLoading = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _examPaper = widget.examPaper;
    _tabController = TabController(length: 3, vsync: this);
    _loadPaperDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPaperDetail() async {
    setState(() => _isLoading = true);
    try {
      final dbPaper = await _db.queryExamPaperByUuid(_examPaper.id);
      if (dbPaper != null) {
        setState(() {
          _examPaper = ExamPaper.fromJson(dbPaper);
        });
      }
    } catch (e) {
      // 忽略错误
    }
    setState(() => _isLoading = false);
  }

  Future<void> _updateExamPaper() async {
    final dbPaper = await _db.queryExamPaperByUuid(_examPaper.id);
    if (dbPaper != null) {
      await _db.updateExamPaper(dbPaper['id'] as int, {
        'name': _examPaper.name,
        'subject': _examPaper.subject,
        'exam_date': _examPaper.examDate,
        'total_score': _examPaper.totalScore,
        'obtained_score': _examPaper.obtainedScore,
        'questions': jsonEncode(_examPaper.questions.map((q) => q.toJson()).toList()),
        'images': jsonEncode(_examPaper.images.map((i) => i.toJson()).toList()),
        'notes': _examPaper.notes,
        'source': _examPaper.source.value,
      });
    }
  }

  void _showEditDialog() {
    final nameController = TextEditingController(text: _examPaper.name);
    final totalScoreController = TextEditingController(text: _examPaper.totalScore.toString());
    final obtainedScoreController = TextEditingController(
      text: _examPaper.obtainedScore?.toString() ?? '',
    );
    final notesController = TextEditingController(text: _examPaper.notes ?? '');

    String selectedSubject = _examPaper.subject;
    ExamPaperSource selectedSource = _examPaper.source;
    DateTime selectedDate = DateTime.fromMillisecondsSinceEpoch(_examPaper.examDate);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('编辑试卷'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '试卷名称',
                    prefixIcon: Icon(Icons.description),
                  ),
                ),
                const SizedBox(height: 16),

                // 学科选择
                Text('学科', style: TextStyle(fontSize: AppFontSize.md, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kSubjectNames.map((subject) => AppTag(
                    label: subject,
                    color: getSubjectColor(subject),
                    selected: selectedSubject == subject,
                    onTap: () => setDialogState(() => selectedSubject = subject),
                  )).toList(),
                ),
                const SizedBox(height: 16),

                // 来源选择
                Text('来源', style: TextStyle(fontSize: AppFontSize.md, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ExamPaperSource.values.map((source) => AppTag(
                    label: source.label,
                    color: AppColors.info,
                    selected: selectedSource == source,
                    onTap: () => setDialogState(() => selectedSource = source),
                  )).toList(),
                ),
                const SizedBox(height: 16),

                // 考试日期
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
                const SizedBox(height: 16),

                // 分数
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: totalScoreController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '总分',
                          prefixIcon: Icon(Icons.format_list_numbered),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: obtainedScoreController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '得分',
                          prefixIcon: Icon(Icons.score),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 备注
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: '备注',
                    prefixIcon: const Icon(Icons.notes),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.mic),
                      onPressed: () async {
                        final success = await _voiceService.startListening();
                        if (success) {
                          // 语音识别通过 onFinalResult 回调返回结果
                          // 这里使用 onResult 回调来获取中间结果
                          _voiceService.onFinalResult = (text) {
                            if (mounted && text.isNotEmpty) {
                              notesController.text = text;
                            }
                          };
                        }
                      },
                    ),
                  ),
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
                setState(() {
                  _examPaper = _examPaper.copyWith(
                    name: nameController.text.trim(),
                    subject: selectedSubject,
                    source: selectedSource,
                    examDate: selectedDate.millisecondsSinceEpoch,
                    totalScore: int.tryParse(totalScoreController.text) ?? _examPaper.totalScore,
                    obtainedScore: int.tryParse(obtainedScoreController.text),
                    notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                  );
                });
                await _updateExamPaper();
                if (mounted) {
                  Navigator.pop(context);
                  showSnackBar(context, '试卷已更新');
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked != null) {
      String? ocrText;
      try {
        ocrText = await _ocrService.recognizeText(picked.path);
      } catch (e) {
        // OCR失败继续
      }

      final newImage = ExamPaperImage(
        path: picked.path,
        pageNumber: _examPaper.images.length + 1,
        ocrText: ocrText,
      );

      setState(() {
        _examPaper = _examPaper.copyWith(
          images: [..._examPaper.images, newImage],
        );
      });
      await _updateExamPaper();
      if (mounted) {
        showSnackBar(context, '图片添加成功');
      }
    }
  }

  Future<void> _deleteImage(int index) async {
    final confirmed = await AppDialog.showConfirmDelete(
      context: context,
      title: '删除图片',
      message: '确定要删除这张图片吗？',
    );
    if (confirmed == true) {
      final newImages = List<ExamPaperImage>.from(_examPaper.images);
      newImages.removeAt(index);

      setState(() {
        _examPaper = _examPaper.copyWith(images: newImages);
      });
      await _updateExamPaper();
      if (mounted) {
        showSnackBar(context, '图片已删除');
      }
    }
  }

  void _showAddQuestionDialog() {
    final contentController = TextEditingController();
    final userAnswerController = TextEditingController();
    final correctAnswerController = TextEditingController();
    final scoreController = TextEditingController();
    final fullScoreController = TextEditingController(text: '10');
    final analysisController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加题目'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: contentController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '题目内容',
                  prefixIcon: Icon(Icons.question_answer),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: userAnswerController,
                      decoration: const InputDecoration(
                        labelText: '你的答案',
                        prefixIcon: Icon(Icons.edit),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: correctAnswerController,
                      decoration: const InputDecoration(
                        labelText: '正确答案',
                        prefixIcon: Icon(Icons.check_circle),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: scoreController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '得分',
                        prefixIcon: Icon(Icons.score),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: fullScoreController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '满分',
                        prefixIcon: Icon(Icons.format_list_numbered),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: analysisController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '解析',
                  prefixIcon: Icon(Icons.lightbulb),
                ),
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
              final question = ExamPaperQuestion(
                content: contentController.text.trim(),
                userAnswer: userAnswerController.text.trim().isEmpty ? null : userAnswerController.text.trim(),
                correctAnswer: correctAnswerController.text.trim().isEmpty ? null : correctAnswerController.text.trim(),
                score: int.tryParse(scoreController.text),
                fullScore: int.tryParse(fullScoreController.text) ?? 10,
                analysis: analysisController.text.trim().isEmpty ? null : analysisController.text.trim(),
              );

              setState(() {
                _examPaper = _examPaper.copyWith(
                  questions: [..._examPaper.questions, question],
                );
              });
              await _updateExamPaper();
              if (mounted) {
                Navigator.pop(context);
                showSnackBar(context, '题目添加成功');
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteQuestion(int index) async {
    final confirmed = await AppDialog.showConfirmDelete(
      context: context,
      title: '删除题目',
      message: '确定要删除这道题目吗？',
    );
    if (confirmed == true) {
      final newQuestions = List<ExamPaperQuestion>.from(_examPaper.questions);
      newQuestions.removeAt(index);

      setState(() {
        _examPaper = _examPaper.copyWith(questions: newQuestions);
      });
      await _updateExamPaper();
      if (mounted) {
        showSnackBar(context, '题目已删除');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjectColor = getSubjectColor(_examPaper.subject);
    final hasScore = _examPaper.obtainedScore != null;
    final scoreRate = _examPaper.scoreRate ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('试卷详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditDialog,
            tooltip: '编辑',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '概览', icon: Icon(Icons.info_outline)),
            Tab(text: '图片', icon: Icon(Icons.image)),
            Tab(text: '题目', icon: Icon(Icons.question_answer)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(theme, subjectColor, hasScore, scoreRate),
                _buildImagesTab(theme),
                _buildQuestionsTab(theme),
              ],
            ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: _addImage,
              icon: const Icon(Icons.camera_alt),
              label: const Text('拍照'),
            )
          : _tabController.index == 2
              ? FloatingActionButton.extended(
                  onPressed: _showAddQuestionDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('添加题目'),
                )
              : null,
    );
  }

  Widget _buildOverviewTab(ThemeData theme, Color subjectColor, bool hasScore, double scoreRate) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 基本信息卡片
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SubjectIcon(subjectName: _examPaper.subject, size: 48),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _examPaper.name,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                AppTag(
                                  label: _examPaper.subject,
                                  color: subjectColor,
                                  dense: true,
                                ),
                                const SizedBox(width: 8),
                                AppTag(
                                  label: _examPaper.source.label,
                                  color: AppColors.info,
                                  dense: true,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),

                  // 考试日期
                  _buildInfoRow(Icons.calendar_today, '考试日期', _examPaper.examDateString),
                  const SizedBox(height: 12),

                  // 总分
                  _buildInfoRow(Icons.format_list_numbered, '总分', '${_examPaper.totalScore} 分'),
                  const SizedBox(height: 12),

                  // 得分
                  if (hasScore) ...[
                    _buildInfoRow(
                      Icons.score,
                      '得分',
                      '${_examPaper.obtainedScore} 分',
                      valueColor: scoreRate >= 0.6 ? AppColors.success : AppColors.error,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.trending_up,
                      '得分率',
                      _examPaper.scoreRateString,
                      valueColor: scoreRate >= 0.6 ? AppColors.success : AppColors.error,
                    ),
                  ] else ...[
                    _buildInfoRow(Icons.score, '得分', '未录入', valueColor: AppColors.textHint),
                  ],
                  const SizedBox(height: 12),

                  // 题目数量
                  _buildInfoRow(Icons.question_answer, '题目数量', '${_examPaper.questions.length} 道'),
                  const SizedBox(height: 12),

                  // 图片数量
                  _buildInfoRow(Icons.image, '试卷图片', '${_examPaper.images.length} 张'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 备注卡片
          if (_examPaper.notes != null && _examPaper.notes!.isNotEmpty)
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.notes, color: subjectColor),
                        const SizedBox(width: 8),
                        Text(
                          '备注',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _examPaper.notes!,
                      style: TextStyle(
                        fontSize: AppFontSize.md,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 试卷分析
          if (hasScore && _examPaper.questions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.analytics, color: subjectColor),
                        const SizedBox(width: 8),
                        Text(
                          '试卷分析',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildAnalysisItem('错题数量', '${_examPaper.wrongQuestionCount} 道', AppColors.error),
                    const SizedBox(height: 8),
                    _buildAnalysisItem('已答题目', '${_examPaper.answeredQuestionCount} 道', AppColors.info),
                    const SizedBox(height: 8),
                    _buildAnalysisItem(
                      '正确率',
                      '${((1 - _examPaper.wrongQuestionCount / _examPaper.questions.length) * 100).toStringAsFixed(1)}%',
                      AppColors.success,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
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
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
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

  Widget _buildImagesTab(ThemeData theme) {
    if (_examPaper.images.isEmpty) {
      return AppEmptyState(
        message: '暂无试卷图片',
        icon: Icons.image_not_supported,
        actionText: '拍照上传',
        onAction: _addImage,
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: _examPaper.images.length,
      itemBuilder: (context, index) {
        final image = _examPaper.images[index];
        return Card(
          clipBehavior: Clip.antiAlias,
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
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => _deleteImage(index),
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
        );
      },
    );
  }

  Widget _buildQuestionsTab(ThemeData theme) {
    if (_examPaper.questions.isEmpty) {
      return AppEmptyState(
        message: '暂无题目记录',
        icon: Icons.question_answer_outlined,
        actionText: '添加题目',
        onAction: _showAddQuestionDialog,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _examPaper.questions.length,
      itemBuilder: (context, index) {
        final question = _examPaper.questions[index];
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
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      onPressed: () => _deleteQuestion(index),
                    ),
                  ],
                ),
                if (question.userAnswer != null) ...[
                  const SizedBox(height: 12),
                  _buildQuestionInfoRow('你的答案', question.userAnswer!,
                      isCorrect: isCorrect),
                ],
                if (question.correctAnswer != null) ...[
                  const SizedBox(height: 8),
                  _buildQuestionInfoRow('正确答案', question.correctAnswer!,
                      isAnswer: true),
                ],
                if (question.score != null && question.fullScore != null) ...[
                  const SizedBox(height: 8),
                  _buildQuestionInfoRow(
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
      },
    );
  }

  Widget _buildQuestionInfoRow(String label, String value,
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
