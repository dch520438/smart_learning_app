import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/exam.dart';
import '../../models/exam_result.dart';
import '../../models/wrong_question.dart';
import '../../models/mother_question.dart';
import '../../services/database_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/question_widgets.dart';

// ============================================================
// ExamScreen - 主页面（两个Tab）
// ============================================================

class ExamScreen extends StatefulWidget {
  const ExamScreen({super.key});

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('考试中心'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '模拟测试', icon: Icon(Icons.quiz_outlined)),
            Tab(text: '做题模式', icon: Icon(Icons.edit_note_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _MockExamTab(),
          _PracticeTab(),
        ],
      ),
    );
  }
}

// ============================================================
// Tab1: 模拟测试
// ============================================================

class _MockExamTab extends StatefulWidget {
  const _MockExamTab();

  @override
  State<_MockExamTab> createState() => _MockExamTabState();
}

class _MockExamTabState extends State<_MockExamTab> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _exams = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    setState(() => _isLoading = true);
    try {
      final exams = await _db.queryAllExams();
      setState(() {
        _exams = exams;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteExam(int id) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context: context,
      title: '删除测试',
      message: '确定要删除这个测试吗？相关成绩记录也将被删除。',
    );
    if (confirmed == true) {
      await _db.deleteExam(id);
      _loadExams();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateExamDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('创建测试'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadExams,
        child: _isLoading
            ? const Center(child: AppLoading())
            : _exams.isEmpty
                ? AppEmptyState(
                    message: '暂无模拟测试，点击下方按钮创建',
                    icon: Icons.quiz_outlined,
                    actionText: '创建测试',
                    onAction: () => _showCreateExamDialog(context),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const SizedBox(height: 8),
                      ..._exams.map((exam) => _buildExamCard(exam)),
                      const SizedBox(height: 80),
                    ],
                  ),
      ),
    );
  }

  Widget _buildExamCard(Map<String, dynamic> exam) {
    final subject = exam['subject'] as String? ?? '未分类';
    final title = exam['title'] as String? ?? '未命名测试';
    final totalQuestions = exam['total_questions'] as int? ?? 0;
    final totalScore = exam['total_score'] as num? ?? 100;
    final timeLimit = exam['time_limit'] as int? ?? 0;
    final isCompleted = exam['is_completed'] as int? ?? 0;
    final createdAt = exam['created_at'] as String? ?? '';
    final examId = exam['id'] as int;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => _navigateToExam(exam),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SubjectIcon(subjectName: subject, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: AppFontSize.lg,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        AppTag(
                          label: subject,
                          color: getSubjectColor(subject),
                          dense: true,
                          fontSize: AppFontSize.xs,
                        ),
                        const SizedBox(width: 8),
                        if (isCompleted == 1)
                          AppTag(
                            label: '已完成',
                            color: AppColors.success,
                            dense: true,
                            fontSize: AppFontSize.xs,
                          )
                        else
                          AppTag(
                            label: '未完成',
                            color: AppColors.warning,
                            dense: true,
                            fontSize: AppFontSize.xs,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') _deleteExam(examId);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoItem(Icons.format_list_numbered, '$totalQuestions 题'),
              const SizedBox(width: 16),
              _buildInfoItem(Icons.score, '${totalScore.toInt()} 分'),
              if (timeLimit > 0) ...[
                const SizedBox(width: 16),
                _buildInfoItem(Icons.timer_outlined, '${timeLimit} 分钟'),
              ],
              const Spacer(),
              Text(
                createdAt.isNotEmpty
                    ? formatFriendlyTime(DateTime.parse(createdAt))
                    : '',
                style: TextStyle(
                  fontSize: AppFontSize.xs,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: AppFontSize.sm,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  void _navigateToExam(Map<String, dynamic> exam) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _ExamTakingScreen(examData: exam),
      ),
    ).then((_) => _loadExams());
  }

  Future<void> _showCreateExamDialog(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _CreateExamDialog(),
    );
    if (result != null) {
      try {
        await _db.insertExam(result);
        _loadExams();
        showSnackBar(context, '测试创建成功');
      } catch (e) {
        showSnackBar(context, '创建失败: $e', isError: true);
      }
    }
  }
}

// ============================================================
// 创建测试对话框
// ============================================================

class _CreateExamDialog extends StatefulWidget {
  const _CreateExamDialog();

  @override
  State<_CreateExamDialog> createState() => _CreateExamDialogState();
}

class _CreateExamDialogState extends State<_CreateExamDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  String _selectedSubject = kSubjectNames.first;
  String _questionSource = 'all'; // all, wrong, mother
  int _questionCount = 10;
  int _timeLimit = 30;
  int _totalScore = 100;
  bool _isCreating = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('创建模拟测试'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                AppInput(
                  label: '测试名称',
                  hintText: '例如：数学期中模拟',
                  controller: _titleController,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? '请输入测试名称' : null,
                ),
                const SizedBox(height: 16),

                // 学科选择
                Text(
                  '选择学科',
                  style: TextStyle(
                    fontSize: AppFontSize.md,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kSubjectNames.map((subject) {
                    return AppTag(
                      label: subject,
                      color: getSubjectColor(subject),
                      selected: _selectedSubject == subject,
                      onTap: () =>
                          setState(() => _selectedSubject = subject),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // 题目来源
                Text(
                  '题目来源',
                  style: TextStyle(
                    fontSize: AppFontSize.md,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildSourceTag('全部题目', 'all'),
                    _buildSourceTag('错题本', 'wrong'),
                    _buildSourceTag('母题集', 'mother'),
                  ],
                ),
                const SizedBox(height: 16),

                // 题目数量
                _buildNumberSetting(
                  label: '题目数量',
                  value: _questionCount,
                  min: 5,
                  max: 50,
                  step: 5,
                  onChanged: (v) => setState(() => _questionCount = v),
                ),
                const SizedBox(height: 12),

                // 时间限制
                _buildNumberSetting(
                  label: '时间限制（分钟）',
                  value: _timeLimit,
                  min: 10,
                  max: 180,
                  step: 5,
                  onChanged: (v) => setState(() => _timeLimit = v),
                ),
                const SizedBox(height: 12),

                // 总分
                _buildNumberSetting(
                  label: '总分',
                  value: _totalScore,
                  min: 50,
                  max: 300,
                  step: 10,
                  onChanged: (v) => setState(() => _totalScore = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _isCreating ? null : _createExam,
          child: _isCreating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('创建'),
        ),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
    );
  }

  Widget _buildSourceTag(String label, String value) {
    return AppTag(
      label: label,
      color: AppColors.info,
      selected: _questionSource == value,
      onTap: () => setState(() => _questionSource = value),
    );
  }

  Widget _buildNumberSetting({
    required String label,
    required int value,
    required int min,
    required int max,
    required int step,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: AppFontSize.md,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: value > min ? () => onChanged(value - step) : null,
              iconSize: 28,
            ),
            Container(
              width: 48,
              alignment: Alignment.center,
              child: Text(
                '$value',
                style: TextStyle(
                  fontSize: AppFontSize.lg,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: value < max ? () => onChanged(value + step) : null,
              iconSize: 28,
            ),
          ],
        ),
      ],
    );
  }

  void _createExam() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isCreating = true);

    // 生成模拟题目数据
    final questionIds = <String>[];
    for (int i = 0; i < _questionCount; i++) {
      questionIds.add('q_${DateTime.now().millisecondsSinceEpoch}_$i');
    }

    final examData = {
      'uuid': generateId(),
      'title': _titleController.text.trim(),
      'description': '来源: ${_questionSource == 'all' ? '全部题目' : _questionSource == 'wrong' ? '错题本' : '母题集'}',
      'subject': _selectedSubject,
      'exam_type': 'mock',
      'total_questions': _questionCount,
      'total_score': _totalScore.toDouble(),
      'time_limit': _timeLimit,
      'passing_score': (_totalScore * 0.6).toDouble(),
      'question_ids': jsonEncode(questionIds),
      'is_completed': 0,
    };

    Navigator.of(context).pop(examData);
  }
}

// ============================================================
// 考试做题界面
// ============================================================

class _ExamTakingScreen extends StatefulWidget {
  final Map<String, dynamic> examData;

  const _ExamTakingScreen({required this.examData});

  @override
  State<_ExamTakingScreen> createState() => _ExamTakingScreenState();
}

class _ExamTakingScreenState extends State<_ExamTakingScreen> {
  late int _totalQuestions;
  late int _totalSeconds;
  int _currentIndex = 0;
  Map<int, String?> _answers = {};
  bool _isSubmitted = false;
  bool _showAnswerSheet = false;
  int _startTime = 0;
  int _endTime = 0;

  // 模拟题目数据
  late List<Map<String, dynamic>> _questions;

  // 考试结果
  int _score = 0;
  int _correctCount = 0;
  int _wrongCount = 0;

  @override
  void initState() {
    super.initState();
    _totalQuestions = widget.examData['total_questions'] as int? ?? 10;
    final timeLimit = widget.examData['time_limit'] as int? ?? 30;
    _totalSeconds = timeLimit * 60;
    _startTime = DateTime.now().millisecondsSinceEpoch;
    _generateMockQuestions();
  }

  void _generateMockQuestions() {
    final subject = widget.examData['subject'] as String? ?? '数学';
    final random = Random();
    _questions = List.generate(_totalQuestions, (index) {
      final questionTypes = ['singleChoice', 'trueFalse', 'fillBlank'];
      final type = questionTypes[random.nextInt(questionTypes.length)];
      final correctAnswer = type == 'singleChoice'
          ? ['A', 'B', 'C', 'D'][random.nextInt(4)]
          : type == 'trueFalse'
              ? (random.nextBool() ? 'T' : 'F')
              : '${random.nextInt(100)}';

      return {
        'id': index,
        'content': '第${index + 1}题：这是一道${subject}相关的${type == 'singleChoice' ? '选择题' : type == 'trueFalse' ? '判断题' : '填空题'}，请根据所学知识作答。',
        'type': type,
        'subject': subject,
        'options': type == 'singleChoice'
            ? ['选项A的内容', '选项B的内容', '选项C的内容', '选项D的内容']
            : null,
        'correctAnswer': correctAnswer,
        'analysis': '这是第${index + 1}题的解析。根据${subject}的基本原理，正确答案是$correctAnswer。需要掌握相关知识点才能准确作答。',
        'difficulty': random.nextInt(3) + 1,
      };
    });
  }

  void _onAnswer(int questionIndex, String answer) {
    setState(() {
      _answers[questionIndex + 1] = answer;
    });
  }

  void _submitExam() {
    _endTime = DateTime.now().millisecondsSinceEpoch;
    setState(() => _isSubmitted = true);

    // 计算分数
    int correct = 0;
    int wrong = 0;
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final userAnswer = _answers[i + 1];
      if (userAnswer != null && userAnswer == q['correctAnswer']) {
        correct++;
      } else {
        wrong++;
      }
    }

    final scorePerQuestion = _totalQuestions > 0
        ? (widget.examData['total_score'] as num? ?? 100).toInt() ~/
            _totalQuestions
        : 0;

    setState(() {
      _correctCount = correct;
      _wrongCount = wrong;
      _score = correct * scorePerQuestion;
    });

    // 保存考试结果到数据库
    _saveExamResult();
  }

  Future<void> _saveExamResult() async {
    try {
      final db = DatabaseService();
      final examId = widget.examData['id'] as int;

      // 标记考试为已完成
      await db.updateExam(examId, {'is_completed': 1});

      // 保存考试结果
      final answersJson = _answers.map((key, value) => MapEntry(
          key.toString(),
          {
            'questionIndex': key - 1,
            'userAnswer': value,
            'correctAnswer': _questions[key - 1]['correctAnswer'],
            'isCorrect': value == _questions[key - 1]['correctAnswer'],
          }));

      await db.insertExamResult({
        'uuid': generateId(),
        'exam_id': examId,
        'score': _score.toDouble(),
        'correct_count': _correctCount,
        'wrong_count': _wrongCount,
        'total_count': _totalQuestions,
        'time_spent': (_endTime - _startTime) ~/ 1000,
        'accuracy': _totalQuestions > 0
            ? (_correctCount / _totalQuestions * 100)
            : 0.0,
        'answers': jsonEncode(answersJson),
        'is_passed': _score >=
            ((widget.examData['passing_score'] as num? ?? 60).toInt())
            ? 1
            : 0,
        'source': 'mock', // 来源：模拟测试
        'subject': widget.examData['subject'] as String? ?? '未分类',
      });
    } catch (e) {
      // 静默处理保存错误
    }
  }

  Future<void> _addWrongQuestionsToBook() async {
    try {
      final db = DatabaseService();
      int addedCount = 0;
      for (int i = 0; i < _questions.length; i++) {
        final q = _questions[i];
        final userAnswer = _answers[i + 1];
        if (userAnswer != null && userAnswer != q['correctAnswer']) {
          await db.insertWrongQuestion({
            'uuid': generateId(),
            'question_content': q['content'],
            'question_type': q['type'],
            'options': q['options'] != null ? jsonEncode(q['options']) : null,
            'correct_answer': q['correctAnswer'],
            'my_answer': userAnswer,
            'analysis': q['analysis'],
            'subject': q['subject'],
            'difficulty': q['difficulty'],
          });
          addedCount++;
        }
      }
      if (mounted) {
        showSnackBar(context, '已将 $addedCount 道错题加入错题本');
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '添加错题失败', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSubmitted) {
      return _buildResultPage();
    }
    return _buildExamPage();
  }

  Widget _buildExamPage() {
    final theme = Theme.of(context);
    final currentQuestion = _questions[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.examData['title'] ?? '模拟测试'}',
          style: TextStyle(fontSize: AppFontSize.md),
        ),
        actions: [
          ExamTimer(
            totalSeconds: _totalSeconds,
            onTimeUp: _submitExam,
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentIndex + 1) / _totalQuestions,
            backgroundColor: AppColors.divider,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: QuestionCard(
                id: 'q_$_currentIndex',
                content: currentQuestion['content'],
                type: _parseQuestionType(currentQuestion['type']),
                subject: currentQuestion['subject'],
                difficulty: currentQuestion['difficulty'],
                options: (currentQuestion['options'] as List?)
                    ?.cast<String>(),
                correctAnswer: currentQuestion['correctAnswer'],
                userAnswer: _answers[_currentIndex + 1],
                analysis: currentQuestion['analysis'],
                index: _currentIndex,
                showResult: false,
                onAnswer: (answer) => _onAnswer(_currentIndex, answer),
              ),
            ),
          ),
          // 底部导航
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 上一题/下一题
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          text: '上一题',
                          icon: Icons.chevron_left,
                          style: AppButtonStyle.outlined,
                          enabled: _currentIndex > 0,
                          onPressed: () => setState(() => _currentIndex--),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          text: _currentIndex < _totalQuestions - 1
                              ? '下一题'
                              : '交卷',
                          icon: _currentIndex < _totalQuestions - 1
                              ? Icons.chevron_right
                              : Icons.send,
                          style: _currentIndex < _totalQuestions - 1
                              ? AppButtonStyle.outlined
                              : AppButtonStyle.primary,
                          onPressed: () {
                            if (_currentIndex < _totalQuestions - 1) {
                              setState(() => _currentIndex++);
                            } else {
                              _showSubmitConfirmDialog();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.grid_view_outlined),
                        onPressed: () =>
                            _showAnswerSheetBottom(context),
                        tooltip: '答题卡',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAnswerSheetBottom(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              // 拖拽指示条
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              AnswerSheet(
                totalCount: _totalQuestions,
                answers: _answers,
                currentIndex: _currentIndex,
                onQuestionTap: (index) {
                  Navigator.of(context).pop();
                  setState(() => _currentIndex = index);
                },
              ),
              const SizedBox(height: 16),
              AppButton(
                text: '交卷',
                icon: Icons.send,
                onPressed: () {
                  Navigator.of(context).pop();
                  _showSubmitConfirmDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSubmitConfirmDialog() {
    final answeredCount =
        _answers.values.where((a) => a != null).length;
    AppDialog.show(
      context: context,
      title: '确认交卷',
      icon: Icons.quiz_outlined,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('已答 $answeredCount/$_totalQuestions 题'),
          if (answeredCount < _totalQuestions) ...[
            const SizedBox(height: 8),
            Text(
              '还有 ${_totalQuestions - answeredCount} 题未作答，确定要交卷吗？',
              style: TextStyle(color: AppColors.warning),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('继续答题'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            _submitExam();
          },
          child: const Text('确认交卷'),
        ),
      ],
    );
  }

  Widget _buildResultPage() {
    final theme = Theme.of(context);
    final totalScore =
        (widget.examData['total_score'] as num? ?? 100).toInt();
    final passingScore =
        (widget.examData['passing_score'] as num? ?? 60).toInt();
    final isPassed = _score >= passingScore;
    final timeSpent = (_endTime - _startTime) ~/ 1000;
    final accuracy = _totalQuestions > 0
        ? (_correctCount / _totalQuestions * 100).toStringAsFixed(1)
        : '0.0';

    return Scaffold(
      appBar: AppBar(
        title: const Text('测试结果'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 分数展示
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isPassed
                      ? [AppColors.success.withOpacity(0.1), AppColors.success.withOpacity(0.05)]
                      : [AppColors.error.withOpacity(0.1), AppColors.error.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(
                  color: isPassed ? AppColors.success : AppColors.error,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    isPassed ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                    size: 64,
                    color: isPassed ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$_score',
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w800,
                      color: isPassed ? AppColors.success : AppColors.error,
                    ),
                  ),
                  Text(
                    '/ $totalScore 分',
                    style: TextStyle(
                      fontSize: AppFontSize.lg,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPassed
                          ? AppColors.success.withOpacity(0.15)
                          : AppColors.error.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                    child: Text(
                      isPassed ? '及格' : '不及格',
                      style: TextStyle(
                        fontSize: AppFontSize.md,
                        fontWeight: FontWeight.w600,
                        color: isPassed ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 统计信息
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    '正确率',
                    '$accuracy%',
                    Icons.check_circle_outline,
                    AppColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    '用时',
                    formatDuration(timeSpent),
                    Icons.timer_outlined,
                    AppColors.info,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    '正确/错误',
                    '$_correctCount/$_wrongCount',
                    Icons.format_list_numbered,
                    AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 各题答题详情
            Text(
              '答题详情',
              style: TextStyle(
                fontSize: AppFontSize.xl,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(_questions.length, (index) {
              final q = _questions[index];
              final userAnswer = _answers[index + 1];
              final isCorrect = userAnswer == q['correctAnswer'];
              return AppCard(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isCorrect
                                ? AppColors.success.withOpacity(0.1)
                                : AppColors.error.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: AppFontSize.sm,
                              fontWeight: FontWeight.w700,
                              color: isCorrect
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            q['content'],
                            style: TextStyle(
                              fontSize: AppFontSize.md,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          isCorrect
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          color: isCorrect
                              ? AppColors.success
                              : AppColors.error,
                          size: 22,
                        ),
                      ],
                    ),
                    if (!isCorrect) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '你的答案: ',
                            style: TextStyle(
                              fontSize: AppFontSize.sm,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            userAnswer ?? '未作答',
                            style: TextStyle(
                              fontSize: AppFontSize.sm,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '正确答案: ',
                            style: TextStyle(
                              fontSize: AppFontSize.sm,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${q['correctAnswer']}',
                            style: TextStyle(
                              fontSize: AppFontSize.sm,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),

            // 操作按钮
            if (_wrongCount > 0)
              AppButton(
                text: '将错题加入错题本',
                icon: Icons.add_to_photos_outlined,
                style: AppButtonStyle.outlined,
                onPressed: _addWrongQuestionsToBook,
              ),
            const SizedBox(height: 12),
            AppButton(
              text: '返回',
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: AppFontSize.lg,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: AppFontSize.xs,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  QuestionType _parseQuestionType(String? type) {
    switch (type) {
      case 'singleChoice':
        return QuestionType.singleChoice;
      case 'trueFalse':
        return QuestionType.trueFalse;
      case 'fillBlank':
        return QuestionType.fillBlank;
      case 'multipleChoice':
        return QuestionType.multipleChoice;
      case 'shortAnswer':
        return QuestionType.shortAnswer;
      default:
        return QuestionType.singleChoice;
    }
  }
}

// ============================================================
// Tab2: 做题模式
// ============================================================

class _PracticeTab extends StatefulWidget {
  const _PracticeTab();

  @override
  State<_PracticeTab> createState() => _PracticeTabState();
}

class _PracticeTabState extends State<_PracticeTab> {
  String _selectedSubject = kSubjectNames.first;
  QuestionType _selectedType = QuestionType.singleChoice;
  bool _isContinuousMode = false;

  // 练习统计
  int _todayCount = 0;
  int _todayCorrect = 0;

  // 当前题目
  int _currentIndex = 0;
  Map<String, dynamic>? _currentQuestion;
  String? _userAnswer;
  bool _showResult = false;
  bool _hasAnswered = false;

  // 题目池
  List<Map<String, dynamic>> _questionPool = [];

  @override
  void initState() {
    super.initState();
    _generateQuestionPool();
  }

  void _generateQuestionPool() {
    final random = Random();
    _questionPool = List.generate(50, (index) {
      final type = _selectedType;
      final correctAnswer = type == QuestionType.singleChoice
          ? ['A', 'B', 'C', 'D'][random.nextInt(4)]
          : type == QuestionType.trueFalse
              ? (random.nextBool() ? 'T' : 'F')
              : '${random.nextInt(100)}';

      return {
        'id': 'p_$index',
        'content': '练习题${index + 1}：这是一道${_selectedSubject}相关的${type.label}，请根据所学知识作答。本题考查基础概念的理解和应用能力。',
        'type': type.name,
        'subject': _selectedSubject,
        'options': type == QuestionType.singleChoice
            ? ['选项A的内容', '选项B的内容', '选项C的内容', '选项D的内容']
            : null,
        'correctAnswer': correctAnswer,
        'analysis': '解析：本题考查${_selectedSubject}的基础知识。正确答案是$correctAnswer。需要理解相关概念和原理才能准确作答。',
        'difficulty': random.nextInt(3) + 1,
      };
    });
    _currentIndex = 0;
    _loadNextQuestion();
  }

  void _loadNextQuestion() {
    if (_currentIndex < _questionPool.length) {
      setState(() {
        _currentQuestion = _questionPool[_currentIndex];
        _userAnswer = null;
        _showResult = false;
        _hasAnswered = false;
      });
    }
  }

  void _submitAnswer() {
    if (_userAnswer == null || _userAnswer!.isEmpty) {
      showSnackBar(context, '请先选择或输入答案', isError: true);
      return;
    }
    setState(() {
      _hasAnswered = true;
      _showResult = true;
      _todayCount++;
      if (_userAnswer == _currentQuestion?['correctAnswer']) {
        _todayCorrect++;
      }
    });
  }

  void _nextQuestion() {
    setState(() {
      _currentIndex++;
    });
    if (_currentIndex < _questionPool.length) {
      _loadNextQuestion();
    } else {
      // 题目做完了，重新生成
      showSnackBar(context, '本轮练习完成，已重新生成题目');
      _generateQuestionPool();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accuracy =
        _todayCount > 0 ? (_todayCorrect / _todayCount * 100) : 0.0;

    return Column(
      children: [
        // 筛选栏
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              // 学科选择
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: kSubjectNames.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final subject = kSubjectNames[index];
                    return AppTag(
                      label: subject,
                      color: getSubjectColor(subject),
                      selected: _selectedSubject == subject,
                      onTap: () {
                        setState(() {
                          _selectedSubject = subject;
                          _generateQuestionPool();
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              // 题型选择 + 连续模式
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: QuestionType.values.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final type = QuestionType.values[index];
                          return AppTag(
                            label: type.label,
                            color: AppColors.info,
                            selected: _selectedType == type,
                            onTap: () {
                              setState(() {
                                _selectedType = type;
                                _generateQuestionPool();
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppTag(
                    label: '连续模式',
                    color: AppColors.secondary,
                    selected: _isContinuousMode,
                    icon: Icons.all_inclusive,
                    onTap: () =>
                        setState(() => _isContinuousMode = !_isContinuousMode),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 练习统计
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppColors.background,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPracticeStat('今日做题', '$_todayCount', Icons.edit_note_outlined),
              _buildPracticeStat('正确率', '${accuracy.toStringAsFixed(1)}%', Icons.trending_up),
              _buildPracticeStat('剩余', '${_questionPool.length - _currentIndex}', Icons.hourglass_top_outlined),
            ],
          ),
        ),

        // 题目区域
        Expanded(
          child: _currentQuestion == null
              ? const Center(child: AppLoading())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // 进度
                      Row(
                        children: [
                          Text(
                            '第 ${_currentIndex + 1} 题',
                            style: TextStyle(
                              fontSize: AppFontSize.sm,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          AppTag(
                            label: _selectedType.label,
                            color: AppColors.info,
                            dense: true,
                            fontSize: AppFontSize.xs,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 题目卡片
                      QuestionCard(
                        id: _currentQuestion!['id'],
                        content: _currentQuestion!['content'],
                        type: _parseQuestionType(_currentQuestion!['type']),
                        subject: _currentQuestion!['subject'],
                        difficulty: _currentQuestion!['difficulty'],
                        options: (_currentQuestion!['options'] as List?)
                            ?.cast<String>(),
                        correctAnswer: _currentQuestion!['correctAnswer'],
                        userAnswer: _userAnswer,
                        analysis: _currentQuestion!['analysis'],
                        index: _currentIndex,
                        showResult: _showResult,
                        showAnalysis: _showResult,
                        onAnswer: (answer) {
                          if (!_hasAnswered) {
                            setState(() => _userAnswer = answer);
                          }
                        },
                      ),
                      const SizedBox(height: 24),

                      // 操作按钮
                      if (!_hasAnswered)
                        AppButton(
                          text: '提交答案',
                          icon: Icons.check,
                          onPressed: _submitAnswer,
                        )
                      else
                        AppButton(
                          text: _isContinuousMode ? '下一题' : '下一题',
                          icon: Icons.arrow_forward,
                          onPressed: _nextQuestion,
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPracticeStat(String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: AppFontSize.md,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: AppFontSize.xs,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      ],
    );
  }

  QuestionType _parseQuestionType(String? type) {
    switch (type) {
      case 'singleChoice':
        return QuestionType.singleChoice;
      case 'trueFalse':
        return QuestionType.trueFalse;
      case 'fillBlank':
        return QuestionType.fillBlank;
      case 'multipleChoice':
        return QuestionType.multipleChoice;
      case 'shortAnswer':
        return QuestionType.shortAnswer;
      default:
        return QuestionType.singleChoice;
    }
  }
}
