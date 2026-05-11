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
  final DatabaseService _db = DatabaseService();

  late int _totalQuestions;
  late int _totalSeconds;
  int _currentIndex = 0;
  Map<int, String?> _answers = {};
  bool _isSubmitted = false;
  bool _showAnswerSheet = false;
  int _startTime = 0;
  int _endTime = 0;

  // 题目数据（包含用户录入的题目）
  List<Map<String, dynamic>> _questions = [];
  bool _isLoadingQuestions = true;

  // 题目来源统计
  int _motherQuestionCount = 0;
  int _wrongQuestionCount = 0;
  int _systemQuestionCount = 0;

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
    _loadQuestions();
  }

  /// 从数据库加载题目（母题、错题、系统题库）
  Future<void> _loadQuestions() async {
    final subject = widget.examData['subject'] as String? ?? '数学';
    final description = widget.examData['description'] as String? ?? '';

    // 解析题目来源
    String questionSource = 'all';
    if (description.contains('错题本')) {
      questionSource = 'wrong';
    } else if (description.contains('母题集')) {
      questionSource = 'mother';
    }

    final random = Random();
    final List<Map<String, dynamic>> loadedQuestions = [];

    try {
      // 1. 加载错题
      if (questionSource == 'all' || questionSource == 'wrong') {
        final wrongQuestions = await _db.queryWrongQuestionsBySubject(subject);
        for (final wq in wrongQuestions) {
          loadedQuestions.add({
            'id': 'wrong_${wq['id']}',
            'content': wq['question_content'] as String? ?? '',
            'type': wq['question_type'] as String? ?? 'singleChoice',
            'subject': wq['subject'] as String? ?? subject,
            'options': wq['options'] != null
                ? (jsonDecode(wq['options'] as String) as List).cast<String>()
                : null,
            'correctAnswer': wq['correct_answer'] as String? ?? '',
            'analysis': wq['analysis'] as String? ?? '暂无解析',
            'difficulty': wq['difficulty'] as int? ?? 2,
            'source': 'wrong',
            'sourceLabel': '错题',
          });
        }
        _wrongQuestionCount = wrongQuestions.length;
      }

      // 2. 加载母题
      if (questionSource == 'all' || questionSource == 'mother') {
        final motherQuestions = await _db.queryMotherQuestionsBySubject(subject);
        for (final mq in motherQuestions) {
          loadedQuestions.add({
            'id': 'mother_${mq['id']}',
            'content': mq['question_content'] as String? ?? '',
            'type': mq['question_type'] as String? ?? 'singleChoice',
            'subject': mq['subject'] as String? ?? subject,
            'options': mq['options'] != null
                ? (jsonDecode(mq['options'] as String) as List).cast<String>()
                : null,
            'correctAnswer': mq['correct_answer'] as String? ?? '',
            'analysis': mq['analysis'] as String? ?? '暂无解析',
            'difficulty': mq['difficulty'] as int? ?? 2,
            'source': 'mother',
            'sourceLabel': '母题',
          });
        }
        _motherQuestionCount = motherQuestions.length;
      }

      // 3. 如果用户录入的题目不够，用系统题库补充
      if (loadedQuestions.length < _totalQuestions) {
        final needed = _totalQuestions - loadedQuestions.length;
        for (int i = 0; i < needed; i++) {
          final questionTypes = ['singleChoice', 'trueFalse', 'fillBlank'];
          final type = questionTypes[random.nextInt(questionTypes.length)];
          final correctAnswer = type == 'singleChoice'
              ? ['A', 'B', 'C', 'D'][random.nextInt(4)]
              : type == 'trueFalse'
                  ? (random.nextBool() ? 'T' : 'F')
                  : '${random.nextInt(100)}';

          loadedQuestions.add({
            'id': 'system_$i',
            'content': '第${loadedQuestions.length + 1}题：这是一道${subject}相关的${type == 'singleChoice' ? '选择题' : type == 'trueFalse' ? '判断题' : '填空题'}，请根据所学知识作答。',
            'type': type,
            'subject': subject,
            'options': type == 'singleChoice'
                ? ['选项A的内容', '选项B的内容', '选项C的内容', '选项D的内容']
                : null,
            'correctAnswer': correctAnswer,
            'analysis': '这是系统生成的题目解析。根据${subject}的基本原理，正确答案是$correctAnswer。',
            'difficulty': random.nextInt(3) + 1,
            'source': 'system',
            'sourceLabel': '系统',
          });
        }
        _systemQuestionCount = needed;
      }

      // 打乱题目顺序
      loadedQuestions.shuffle(random);

      // 限制题目数量
      _questions = loadedQuestions.take(_totalQuestions).toList();
      _totalQuestions = _questions.length;

      setState(() {
        _isLoadingQuestions = false;
      });
    } catch (e) {
      // 如果加载失败，使用系统生成的题目
      _generateMockQuestions();
      setState(() {
        _isLoadingQuestions = false;
      });
    }
  }

  /// 生成模拟题目（作为后备方案）
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
        'source': 'system',
        'sourceLabel': '系统',
      };
    });
    _systemQuestionCount = _totalQuestions;
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
      final title = widget.examData['title'] as String? ?? '模拟测试';
      final subject = widget.examData['subject'] as String? ?? '未分类';
      final totalScore = (widget.examData['total_score'] as num? ?? 100).toDouble();
      final timeSpent = (_endTime - _startTime) ~/ 1000;

      // 标记考试为已完成
      await db.updateExam(examId, {'is_completed': 1});

      // 保存考试结果到 exam_results 表
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
        'time_spent': timeSpent,
        'accuracy': _totalQuestions > 0
            ? (_correctCount / _totalQuestions * 100)
            : 0.0,
        'answers': jsonEncode(answersJson),
        'is_passed': _score >=
            ((widget.examData['passing_score'] as num? ?? 60).toInt())
            ? 1
            : 0,
        'source': 'mock',
        'subject': subject,
      });

      // 同时添加学习记录到 study_records 表
      await db.insertStudyRecord({
        'uuid': generateId(),
        'record_type': 'exam',
        'title': title,
        'description': '得分: $_score/$totalScore，正确率: ${_totalQuestions > 0 ? (_correctCount / _totalQuestions * 100).toStringAsFixed(1) : 0}%',
        'subject': subject,
        'duration': timeSpent,
        'related_id': examId,
        'related_type': 'exam',
        'score': _score.toDouble(),
        'is_completed': 1,
      });

      debugPrint('考试结果已保存: $title, 得分: $_score/$totalScore');
    } catch (e) {
      debugPrint('保存考试结果失败: $e');
      if (mounted) {
        showSnackBar(context, '保存考试结果失败: $e', isError: true);
      }
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

    if (_isLoadingQuestions) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            '${widget.examData['title'] ?? '模拟测试'}',
            style: TextStyle(fontSize: AppFontSize.md),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppLoading(),
              SizedBox(height: 16),
              Text('正在加载题目...', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            '${widget.examData['title'] ?? '模拟测试'}',
            style: TextStyle(fontSize: AppFontSize.md),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.quiz_outlined, size: 64, color: AppColors.textHint),
              const SizedBox(height: 16),
              const Text('暂无可用题目', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              AppButton(
                text: '返回',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      );
    }

    final currentQuestion = _questions[_currentIndex];
    final sourceLabel = currentQuestion['sourceLabel'] as String? ?? '';
    final sourceColor = currentQuestion['source'] == 'wrong'
        ? AppColors.error
        : currentQuestion['source'] == 'mother'
            ? AppColors.warning
            : AppColors.info;

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
          if (_currentIndex == 0 && (_motherQuestionCount > 0 || _wrongQuestionCount > 0))
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.background,
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  if (_motherQuestionCount > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(4))),
                        const SizedBox(width: 4),
                        Text('母题: $_motherQuestionCount', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  if (_wrongQuestionCount > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(4))),
                        const SizedBox(width: 4),
                        Text('错题: $_wrongQuestionCount', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  if (_systemQuestionCount > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.info, borderRadius: BorderRadius.circular(4))),
                        const SizedBox(width: 4),
                        Text('系统: $_systemQuestionCount', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (sourceLabel.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          AppTag(
                            label: sourceLabel,
                            color: sourceColor,
                            dense: true,
                            fontSize: AppFontSize.xs,
                          ),
                        ],
                      ),
                    ),
                  QuestionCard(
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
                ],
              ),
            ),
          ),
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
// Tab2: 做题模式（优化版）
// ============================================================

/// 题目来源选项
enum _QuestionSource {
  all('全部', Icons.folder_open_outlined),
  wrong('错题本', Icons.error_outline),
  mother('母题集', Icons.auto_awesome_outlined),
  mustRemember('必记必背', Icons.menu_book_outlined),
  system('系统题库', Icons.cloud_outlined);

  const _QuestionSource(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// 题目类型筛选
enum _QuestionTypeFilter {
  all('全部'),
  singleChoice('单选'),
  multipleChoice('多选'),
  fillBlank('填空'),
  shortAnswer('简答'),
  trueFalse('判断');

  const _QuestionTypeFilter(this.label);
  final String label;
}

class _PracticeTab extends StatefulWidget {
  const _PracticeTab();

  @override
  State<_PracticeTab> createState() => _PracticeTabState();
}

class _PracticeTabState extends State<_PracticeTab> {
  final DatabaseService _db = DatabaseService();

  // ==================== 设置页面状态 ====================
  String _selectedSubject = kSubjectNames.first;
  List<String> _availableChapters = [];
  Set<String> _selectedChapters = {};
  int _questionCount = 10;
  bool _isCustomCount = false;
  final TextEditingController _customCountController = TextEditingController();
  _QuestionTypeFilter _selectedTypeFilter = _QuestionTypeFilter.all;
  _QuestionSource _selectedSource = _QuestionSource.all;
  bool _isLoadingChapters = false;

  // ==================== 做题状态 ====================
  bool _isInExam = false;
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  Map<int, String?> _answers = {};
  Map<int, bool> _selfEvalScores = {}; // 简答题自评: true=对, false=错
  bool _showResult = false; // 当前题是否已提交
  bool _isExamSubmitted = false;
  int _startTime = 0;
  int _endTime = 0;

  // ==================== 结果状态 ====================
  double _totalScore = 0;
  int _correctCount = 0;
  int _wrongCount = 0;
  int _halfCorrectCount = 0; // 多选少选
  int _selfEvalCount = 0; // 简答题自评
  double _scorePerQuestion = 0;

  // 来源统计
  int _wrongSourceCount = 0;
  int _motherSourceCount = 0;
  int _mustRememberSourceCount = 0;
  int _systemSourceCount = 0;

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  @override
  void dispose() {
    _customCountController.dispose();
    super.dispose();
  }

  /// 加载章节列表
  Future<void> _loadChapters() async {
    setState(() => _isLoadingChapters = true);
    try {
      final chapterSet = <String>{};

      // 从错题本获取标签
      final wrongTags = await _db.queryWrongQuestionTagsBySubject(_selectedSubject);
      chapterSet.addAll(wrongTags);

      // 从母题集获取分类
      final motherCats = await _db.queryMotherQuestionCategoriesBySubject(_selectedSubject);
      chapterSet.addAll(motherCats);

      // 从必记必背获取分类
      final mustCats = await _db.queryMustRememberCategoriesBySubject(_selectedSubject);
      chapterSet.addAll(mustCats);

      setState(() {
        _availableChapters = chapterSet.toList()..sort();
        _selectedChapters = {}; // 切换学科时清空章节选择
        _isLoadingChapters = false;
      });
    } catch (e) {
      setState(() => _isLoadingChapters = false);
    }
  }

  /// 开始测试 - 自动抽题
  Future<void> _startPractice() async {
    setState(() => _isInExam = true);
    _startTime = DateTime.now().millisecondsSinceEpoch;
    _answers = {};
    _selfEvalScores = {};
    _showResult = false;
    _isExamSubmitted = false;
    _currentIndex = 0;

    final random = Random();
    final List<Map<String, dynamic>> loadedQuestions = [];
    _wrongSourceCount = 0;
    _motherSourceCount = 0;
    _mustRememberSourceCount = 0;
    _systemSourceCount = 0;

    try {
      // 1. 根据来源加载题目
      if (_selectedSource == _QuestionSource.all ||
          _selectedSource == _QuestionSource.wrong) {
        final wrongQuestions = await _db.queryWrongQuestionsBySubjectAndTags(
          _selectedSubject,
          _selectedChapters.isEmpty ? null : _selectedChapters.toList(),
        );
        for (final wq in wrongQuestions) {
          final qType = wq['question_type'] as String? ?? 'singleChoice';
          if (_selectedTypeFilter != _QuestionTypeFilter.all &&
              qType != _selectedTypeFilter.name) continue;
          loadedQuestions.add(_convertWrongQuestion(wq));
        }
        _wrongSourceCount = wrongQuestions.length;
      }

      if (_selectedSource == _QuestionSource.all ||
          _selectedSource == _QuestionSource.mother) {
        final motherQuestions = await _db.queryMotherQuestionsBySubjectAndTags(
          _selectedSubject,
          _selectedChapters.isEmpty ? null : _selectedChapters.toList(),
        );
        for (final mq in motherQuestions) {
          final qType = mq['question_type'] as String? ?? 'singleChoice';
          if (_selectedTypeFilter != _QuestionTypeFilter.all &&
              qType != _selectedTypeFilter.name) continue;
          loadedQuestions.add(_convertMotherQuestion(mq));
        }
        _motherSourceCount = motherQuestions.length;
      }

      if (_selectedSource == _QuestionSource.all ||
          _selectedSource == _QuestionSource.mustRemember) {
        final mustRemembers = await _db.queryMustRemembersBySubjectAndTags(
          _selectedSubject,
          _selectedChapters.isEmpty ? null : _selectedChapters.toList(),
        );
        for (final mr in mustRemembers) {
          loadedQuestions.add(_convertMustRememberToQuestion(mr));
        }
        _mustRememberSourceCount = mustRemembers.length;
      }

      // 2. 如果不够，用系统题库补充
      if (loadedQuestions.length < _questionCount) {
        final needed = _questionCount - loadedQuestions.length;
        for (int i = 0; i < needed; i++) {
          loadedQuestions.add(_generateSystemQuestion(
            index: loadedQuestions.length,
            subject: _selectedSubject,
            random: random,
          ));
        }
        _systemSourceCount = needed;
      }

      // 3. 打乱题目顺序
      loadedQuestions.shuffle(random);

      // 4. 限制题目数量
      _questions = loadedQuestions.take(_questionCount).toList();
      _scorePerQuestion = _questions.isNotEmpty ? 100.0 / _questions.length : 0;

      setState(() {});
    } catch (e) {
      // 如果加载失败，使用系统生成的题目
      _questions = List.generate(_questionCount, (index) {
        return _generateSystemQuestion(
          index: index,
          subject: _selectedSubject,
          random: random,
        );
      });
      _systemSourceCount = _questionCount;
      _scorePerQuestion = _questions.isNotEmpty ? 100.0 / _questions.length : 0;
      setState(() {});
    }
  }

  Map<String, dynamic> _convertWrongQuestion(Map<String, dynamic> wq) {
    return {
      'id': 'wrong_${wq['id']}',
      'content': wq['question_content'] as String? ?? '',
      'type': wq['question_type'] as String? ?? 'singleChoice',
      'subject': wq['subject'] as String? ?? _selectedSubject,
      'options': wq['options'] != null
          ? (jsonDecode(wq['options'] as String) as List).cast<String>()
          : null,
      'correctAnswer': wq['correct_answer'] as String? ?? '',
      'analysis': wq['analysis'] as String? ?? '暂无解析',
      'difficulty': wq['difficulty'] as int? ?? 2,
      'source': 'wrong',
      'sourceLabel': '错题',
      'originalId': wq['id'],
    };
  }

  Map<String, dynamic> _convertMotherQuestion(Map<String, dynamic> mq) {
    return {
      'id': 'mother_${mq['id']}',
      'content': mq['question_content'] as String? ?? '',
      'type': mq['question_type'] as String? ?? 'singleChoice',
      'subject': mq['subject'] as String? ?? _selectedSubject,
      'options': mq['options'] != null
          ? (jsonDecode(mq['options'] as String) as List).cast<String>()
          : null,
      'correctAnswer': mq['correct_answer'] as String? ?? '',
      'analysis': mq['analysis'] as String? ?? '暂无解析',
      'difficulty': mq['difficulty'] as int? ?? 2,
      'source': 'mother',
      'sourceLabel': '母题',
      'originalId': mq['id'],
    };
  }

  Map<String, dynamic> _convertMustRememberToQuestion(Map<String, dynamic> mr) {
    final title = mr['title'] as String? ?? '';
    final content = mr['content'] as String? ?? '';
    // 将必记必背转化为填空题
    return {
      'id': 'must_${mr['id']}',
      'content': '请默写：$title\n（提示：$content）',
      'type': 'fillBlank',
      'subject': mr['subject'] as String? ?? _selectedSubject,
      'options': null,
      'correctAnswer': content,
      'analysis': '正确答案为：$content',
      'difficulty': 2,
      'source': 'mustRemember',
      'sourceLabel': '必记必背',
      'originalId': mr['id'],
    };
  }

  Map<String, dynamic> _generateSystemQuestion({
    required int index,
    required String subject,
    required Random random,
  }) {
    String type;
    if (_selectedTypeFilter == _QuestionTypeFilter.all) {
      final types = ['singleChoice', 'trueFalse', 'fillBlank', 'multipleChoice', 'shortAnswer'];
      type = types[random.nextInt(types.length)];
    } else {
      type = _selectedTypeFilter.name;
    }

    String correctAnswer;
    List<String>? options;

    switch (type) {
      case 'singleChoice':
        correctAnswer = ['A', 'B', 'C', 'D'][random.nextInt(4)];
        options = ['选项A的内容', '选项B的内容', '选项C的内容', '选项D的内容'];
        break;
      case 'multipleChoice':
        // 随机生成2-3个正确答案
        final allOptions = ['A', 'B', 'C', 'D'];
        allOptions.shuffle(random);
        final correctCount = random.nextInt(2) + 2;
        correctAnswer = allOptions.take(correctCount).join(',');
        options = ['选项A的内容', '选项B的内容', '选项C的内容', '选项D的内容'];
        break;
      case 'trueFalse':
        correctAnswer = random.nextBool() ? 'T' : 'F';
        options = null;
        break;
      case 'fillBlank':
        correctAnswer = '${random.nextInt(100)}';
        options = null;
        break;
      case 'shortAnswer':
        correctAnswer = '参考答案：这是${subject}相关简答题的标准答案要点。';
        options = null;
        break;
      default:
        correctAnswer = 'A';
        options = ['选项A的内容', '选项B的内容', '选项C的内容', '选项D的内容'];
    }

    final typeLabel = type == 'singleChoice' ? '选择题'
        : type == 'multipleChoice' ? '多选题'
        : type == 'trueFalse' ? '判断题'
        : type == 'fillBlank' ? '填空题'
        : '简答题';

    return {
      'id': 'system_$index',
      'content': '第${index + 1}题：这是一道${subject}相关的${typeLabel}，请根据所学知识作答。',
      'type': type,
      'subject': subject,
      'options': options,
      'correctAnswer': correctAnswer,
      'analysis': '这是系统生成的题目解析。根据${subject}的基本原理，正确答案是$correctAnswer。',
      'difficulty': random.nextInt(3) + 1,
      'source': 'system',
      'sourceLabel': '系统',
    };
  }

  /// 提交当前题目答案
  void _submitCurrentAnswer() {
    final userAnswer = _answers[_currentIndex + 1];
    if (userAnswer == null || userAnswer.isEmpty) {
      showSnackBar(context, '请先选择或输入答案', isError: true);
      return;
    }
    setState(() => _showResult = true);
  }

  /// 导航到下一题
  void _goToNext() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _showResult = false;
      });
    } else {
      // 最后一题，提交整个测试
      _submitExam();
    }
  }

  /// 导航到上一题
  void _goToPrevious() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _showResult = _answers[_currentIndex + 1] != null;
      });
    }
  }

  /// 提交整个测试
  void _submitExam() {
    _endTime = DateTime.now().millisecondsSinceEpoch;
    setState(() => _isExamSubmitted = true);

    // 自动判分
    double totalScore = 0;
    int correct = 0;
    int wrong = 0;
    int halfCorrect = 0;
    int selfEval = 0;

    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final userAnswer = _answers[i + 1];
      final correctAnswer = (q['correctAnswer'] as String?) ?? '';
      final type = q['type'] as String? ?? 'singleChoice';

      if (userAnswer == null || userAnswer.isEmpty) {
        wrong++;
        continue;
      }

      switch (type) {
        case 'singleChoice':
        case 'trueFalse':
          // 单选/判断：选对得分
          if (userAnswer == correctAnswer) {
            correct++;
            totalScore += _scorePerQuestion;
          } else {
            wrong++;
          }
          break;
        case 'multipleChoice':
          // 多选：全对得分，少选得一半分
          final userSet = userAnswer.split(',').map((s) => s.trim()).toSet();
          final correctSet = correctAnswer.split(',').map((s) => s.trim()).toSet();
          if (_setEquals(userSet, correctSet)) {
            correct++;
            totalScore += _scorePerQuestion;
          } else if (userSet.every((e) => correctSet.contains(e)) && userSet.isNotEmpty) {
            // 少选但没选错
            halfCorrect++;
            totalScore += _scorePerQuestion * 0.5;
          } else {
            wrong++;
          }
          break;
        case 'fillBlank':
          // 填空题：完全匹配得分
          if (userAnswer.trim() == correctAnswer.trim()) {
            correct++;
            totalScore += _scorePerQuestion;
          } else {
            wrong++;
          }
          break;
        case 'shortAnswer':
          // 简答题：用户自评
          selfEval++;
          if (_selfEvalScores[i + 1] == true) {
            correct++;
            totalScore += _scorePerQuestion;
          } else {
            wrong++;
          }
          break;
      }
    }

    setState(() {
      _totalScore = totalScore;
      _correctCount = correct;
      _wrongCount = wrong;
      _halfCorrectCount = halfCorrect;
      _selfEvalCount = selfEval;
    });

    // 保存结果
    _savePracticeResult();
  }

  bool _setEquals<T>(Set<T> a, Set<T> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  /// 保存练习结果
  Future<void> _savePracticeResult() async {
    try {
      final timeSpent = (_endTime - _startTime) ~/ 1000;
      final totalQ = _questions.length;
      final accuracy = totalQ > 0 ? (_correctCount / totalQ * 100) : 0.0;

      // 保存学习记录
      await _db.insertStudyRecord({
        'uuid': generateId(),
        'record_type': 'practice',
        'title': '${_selectedSubject}练习测试',
        'description': '得分: ${_totalScore.toStringAsFixed(1)}/100，正确率: ${accuracy.toStringAsFixed(1)}%',
        'subject': _selectedSubject,
        'duration': timeSpent,
        'score': _totalScore,
        'is_completed': 1,
      });

      // 做错的题目自动录入错题本
      await _autoAddWrongQuestions();

      debugPrint('练习结果已保存: $_totalScore/100');
    } catch (e) {
      debugPrint('保存练习结果失败: $e');
    }
  }

  /// 做错的题目自动录入错题本
  Future<void> _autoAddWrongQuestions() async {
    try {
      int addedCount = 0;
      for (int i = 0; i < _questions.length; i++) {
        final q = _questions[i];
        final userAnswer = _answers[i + 1];
        final correctAnswer = (q['correctAnswer'] as String?) ?? '';
        final type = q['type'] as String? ?? 'singleChoice';

        // 判断是否答错
        bool isWrong = false;
        if (userAnswer == null || userAnswer.isEmpty) {
          isWrong = true;
        } else {
          switch (type) {
            case 'singleChoice':
            case 'trueFalse':
            case 'fillBlank':
              isWrong = userAnswer.trim() != correctAnswer.trim();
              break;
            case 'multipleChoice':
              final userSet = userAnswer.split(',').map((s) => s.trim()).toSet();
              final correctSet = correctAnswer.split(',').map((s) => s.trim()).toSet();
              isWrong = !_setEquals(userSet, correctSet) &&
                  !(userSet.every((e) => correctSet.contains(e)) && userSet.isNotEmpty);
              break;
            case 'shortAnswer':
              isWrong = _selfEvalScores[i + 1] != true;
              break;
          }
        }

        if (isWrong) {
          // 检查是否已经在错题本中（通过source和originalId判断）
          final source = q['source'] as String? ?? '';
          if (source == 'wrong') continue; // 已经是错题，不需要重复添加

          await _db.insertWrongQuestion({
            'uuid': generateId(),
            'title': '练习错题 #${i + 1}',
            'question_content': q['content'],
            'question_type': q['type'],
            'options': q['options'] != null ? jsonEncode(q['options']) : null,
            'correct_answer': correctAnswer,
            'my_answer': userAnswer,
            'analysis': q['analysis'],
            'subject': q['subject'],
            'difficulty': q['difficulty'],
          });
          addedCount++;
        }
      }
      if (mounted && addedCount > 0) {
        showSnackBar(context, '已自动将 $addedCount 道错题加入错题本');
      }
    } catch (e) {
      debugPrint('自动添加错题失败: $e');
    }
  }

  /// 返回设置页面
  void _backToSettings() {
    setState(() {
      _isInExam = false;
      _isExamSubmitted = false;
      _questions = [];
      _currentIndex = 0;
      _answers = {};
      _selfEvalScores = {};
      _showResult = false;
    });
  }

  // ==================== 构建UI ====================

  @override
  Widget build(BuildContext context) {
    if (_isExamSubmitted) {
      return _buildResultPage();
    }
    if (_isInExam) {
      return _buildExamPage();
    }
    return _buildSettingsPage();
  }

  // ==================== 设置页面 ====================

  Widget _buildSettingsPage() {
    final theme = Theme.of(context);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // 标题
            Text(
              '做题模式',
              style: TextStyle(
                fontSize: AppFontSize.title,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '自定义练习参数，智能抽取题目',
              style: TextStyle(
                fontSize: AppFontSize.md,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // 1. 学科选择
            _buildSectionTitle('选择学科'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kSubjectNames.map((subject) {
                return AppTag(
                  label: subject,
                  color: getSubjectColor(subject),
                  selected: _selectedSubject == subject,
                  onTap: () {
                    setState(() => _selectedSubject = subject);
                    _loadChapters();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // 2. 章节选择（多选）
            _buildSectionTitle('选择章节（可选，不选则全部）'),
            const SizedBox(height: 8),
            if (_isLoadingChapters)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: AppLoading()),
              )
            else if (_availableChapters.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Text(
                  '当前学科暂无章节数据',
                  style: TextStyle(
                    fontSize: AppFontSize.sm,
                    color: AppColors.textHint,
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableChapters.map((chapter) {
                  final isSelected = _selectedChapters.contains(chapter);
                  return AppTag(
                    label: chapter,
                    color: AppColors.secondary,
                    selected: isSelected,
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedChapters.remove(chapter);
                        } else {
                          _selectedChapters.add(chapter);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            const SizedBox(height: 24),

            // 3. 题目数量
            _buildSectionTitle('题目数量'),
            const SizedBox(height: 8),
            Row(
              children: [10, 20, 30, 50].map((count) {
                final isSelected = !_isCustomCount && _questionCount == count;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AppTag(
                    label: '$count 题',
                    color: AppColors.info,
                    selected: isSelected,
                    onTap: () => setState(() {
                      _isCustomCount = false;
                      _questionCount = count;
                    }),
                  ),
                );
              }).toList(),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                AppTag(
                  label: '自定义',
                  color: AppColors.info,
                  selected: _isCustomCount,
                  onTap: () => setState(() => _isCustomCount = true),
                ),
                if (_isCustomCount) ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 80,
                    child: AppInput(
                      hintText: '数量',
                      controller: _customCountController,
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null && n > 0) {
                          setState(() => _questionCount = n.clamp(1, 200));
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),

            // 4. 题目类型
            _buildSectionTitle('题目类型'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _QuestionTypeFilter.values.map((filter) {
                return AppTag(
                  label: filter.label,
                  color: AppColors.warning,
                  selected: _selectedTypeFilter == filter,
                  onTap: () => setState(() => _selectedTypeFilter = filter),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // 5. 题目来源
            _buildSectionTitle('题目来源'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _QuestionSource.values.map((source) {
                return AppTag(
                  label: source.label,
                  color: AppColors.primary,
                  icon: source.icon,
                  selected: _selectedSource == source,
                  onTap: () => setState(() => _selectedSource = source),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // 开始按钮
            AppButton(
              text: '开始做题',
              icon: Icons.play_arrow_rounded,
              onPressed: _startPractice,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: AppFontSize.lg,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  // ==================== 做题页面 ====================

  Widget _buildExamPage() {
    final theme = Theme.of(context);

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('做题中')),
        body: const Center(child: AppLoading()),
      );
    }

    final currentQuestion = _questions[_currentIndex];
    final qType = currentQuestion['type'] as String? ?? 'singleChoice';
    final sourceLabel = currentQuestion['sourceLabel'] as String? ?? '';
    final sourceColor = currentQuestion['source'] == 'wrong'
        ? AppColors.error
        : currentQuestion['source'] == 'mother'
            ? AppColors.warning
            : currentQuestion['source'] == 'mustRemember'
                ? AppColors.info
                : AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${_selectedSubject} - ${_selectedTypeFilter.label}',
          style: TextStyle(fontSize: AppFontSize.md),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            AppDialog.show(
              context: context,
              title: '退出做题',
              message: '确定要退出吗？当前进度不会保存。',
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('继续做题'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _backToSettings();
                  },
                  child: const Text('退出'),
                ),
              ],
            );
          },
        ),
        actions: [
          // 答题卡按钮
          IconButton(
            icon: const Icon(Icons.grid_view_outlined),
            onPressed: () => _showAnswerSheetBottom(context),
            tooltip: '答题卡',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentIndex + 1) / _questions.length,
            backgroundColor: AppColors.divider,
          ),
        ),
      ),
      body: Column(
        children: [
          // 进度信息栏
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.background,
            child: Row(
              children: [
                Text(
                  '第 ${_currentIndex + 1} 题 / 共 ${_questions.length} 题',
                  style: TextStyle(
                    fontSize: AppFontSize.sm,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (sourceLabel.isNotEmpty)
                  AppTag(
                    label: sourceLabel,
                    color: sourceColor,
                    dense: true,
                    fontSize: AppFontSize.xs,
                  ),
              ],
            ),
          ),
          // 题目区域
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  QuestionCard(
                    id: 'q_$_currentIndex',
                    content: currentQuestion['content'],
                    type: _parseQuestionType(qType),
                    subject: currentQuestion['subject'],
                    difficulty: currentQuestion['difficulty'],
                    options: (currentQuestion['options'] as List?)?.cast<String>(),
                    correctAnswer: currentQuestion['correctAnswer'],
                    userAnswer: _answers[_currentIndex + 1],
                    analysis: currentQuestion['analysis'],
                    index: _currentIndex,
                    showResult: _showResult,
                    showAnalysis: _showResult,
                    onAnswer: (answer) {
                      if (!_showResult) {
                        setState(() => _answers[_currentIndex + 1] = answer);
                      }
                    },
                  ),
                  // 简答题自评区域
                  if (_showResult && qType == 'shortAnswer') ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.info),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '请对照参考答案自评',
                            style: TextStyle(
                              fontSize: AppFontSize.md,
                              fontWeight: FontWeight.w600,
                              color: AppColors.info,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: AppButton(
                                  text: '回答正确',
                                  icon: Icons.check_circle_outline,
                                  style: AppButtonStyle.outlined,
                                  onPressed: () {
                                    setState(() => _selfEvalScores[_currentIndex + 1] = true);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: AppButton(
                                  text: '回答错误',
                                  icon: Icons.cancel_outlined,
                                  style: AppButtonStyle.outlined,
                                  onPressed: () {
                                    setState(() => _selfEvalScores[_currentIndex + 1] = false);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // 底部操作栏
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
              child: Row(
                children: [
                  // 上一题
                  Expanded(
                    child: AppButton(
                      text: '上一题',
                      icon: Icons.chevron_left,
                      style: AppButtonStyle.outlined,
                      enabled: _currentIndex > 0,
                      onPressed: _goToPrevious,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 提交/下一题
                  Expanded(
                    child: AppButton(
                      text: _showResult
                          ? (_currentIndex < _questions.length - 1 ? '下一题' : '提交全部')
                          : '提交答案',
                      icon: _showResult
                          ? (_currentIndex < _questions.length - 1 ? Icons.chevron_right : Icons.send)
                          : Icons.check,
                      style: _showResult
                          ? AppButtonStyle.primary
                          : AppButtonStyle.secondary,
                      onPressed: _showResult ? _goToNext : _submitCurrentAnswer,
                    ),
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
                totalCount: _questions.length,
                answers: _answers,
                currentIndex: _currentIndex,
                onQuestionTap: (index) {
                  Navigator.of(context).pop();
                  setState(() {
                    _currentIndex = index;
                    _showResult = _answers[index + 1] != null;
                  });
                },
              ),
              const SizedBox(height: 16),
              AppButton(
                text: '提交全部',
                icon: Icons.send,
                onPressed: () {
                  Navigator.of(context).pop();
                  _submitExam();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 结果页面 ====================

  Widget _buildResultPage() {
    final theme = Theme.of(context);
    final timeSpent = (_endTime - _startTime) ~/ 1000;
    final accuracy = _questions.isNotEmpty
        ? (_correctCount / _questions.length * 100).toStringAsFixed(1)
        : '0.0';
    final isGood = _totalScore >= 60;

    return Scaffold(
      appBar: AppBar(
        title: const Text('练习结果'),
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
                  colors: isGood
                      ? [AppColors.success.withOpacity(0.1), AppColors.success.withOpacity(0.05)]
                      : [AppColors.error.withOpacity(0.1), AppColors.error.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(
                  color: isGood ? AppColors.success : AppColors.error,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    isGood ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                    size: 64,
                    color: isGood ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _totalScore.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w800,
                      color: isGood ? AppColors.success : AppColors.error,
                    ),
                  ),
                  Text(
                    '/ 100 分',
                    style: TextStyle(
                      fontSize: AppFontSize.lg,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: isGood
                          ? AppColors.success.withOpacity(0.15)
                          : AppColors.error.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                    child: Text(
                      isGood ? '表现不错' : '继续加油',
                      style: TextStyle(
                        fontSize: AppFontSize.md,
                        fontWeight: FontWeight.w600,
                        color: isGood ? AppColors.success : AppColors.error,
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
                  child: _buildStatCard('正确率', '$accuracy%', Icons.check_circle_outline, AppColors.success),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard('用时', formatDuration(timeSpent), Icons.timer_outlined, AppColors.info),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard('正确/错误', '$_correctCount/$_wrongCount', Icons.format_list_numbered, AppColors.warning),
                ),
              ],
            ),
            // 半对和自评统计
            if (_halfCorrectCount > 0 || _selfEvalCount > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (_halfCorrectCount > 0)
                    Expanded(
                      child: _buildStatCard('多选半对', '$_halfCorrectCount', Icons.remove_circle_outline, AppColors.warning),
                    ),
                  if (_halfCorrectCount > 0) const SizedBox(width: 12),
                  if (_selfEvalCount > 0)
                    Expanded(
                      child: _buildStatCard('简答自评', '$_selfEvalCount', Icons.rate_review_outlined, AppColors.info),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),

            // 答题详情
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
              final correctAnswer = (q['correctAnswer'] as String?) ?? '';
              final type = q['type'] as String? ?? 'singleChoice';

              // 判断对错
              bool isCorrect = false;
              bool isHalfCorrect = false;

              if (userAnswer != null && userAnswer.isNotEmpty) {
                switch (type) {
                  case 'singleChoice':
                  case 'trueFalse':
                  case 'fillBlank':
                    isCorrect = userAnswer.trim() == correctAnswer.trim();
                    break;
                  case 'multipleChoice':
                    final userSet = userAnswer.split(',').map((s) => s.trim()).toSet();
                    final correctSet = correctAnswer.split(',').map((s) => s.trim()).toSet();
                    isCorrect = _setEquals(userSet, correctSet);
                    isHalfCorrect = !isCorrect &&
                        userSet.every((e) => correctSet.contains(e)) &&
                        userSet.isNotEmpty;
                    break;
                  case 'shortAnswer':
                    isCorrect = _selfEvalScores[index + 1] == true;
                    break;
                }
              }

              Color statusColor;
              IconData statusIcon;
              String statusText;
              if (isCorrect) {
                statusColor = AppColors.success;
                statusIcon = Icons.check_circle_rounded;
                statusText = '正确';
              } else if (isHalfCorrect) {
                statusColor = AppColors.warning;
                statusIcon = Icons.remove_circle_rounded;
                statusText = '半对';
              } else {
                statusColor = AppColors.error;
                statusIcon = Icons.cancel_rounded;
                statusText = '错误';
              }

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
                            color: statusColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: AppFontSize.sm,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
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
                        Icon(statusIcon, color: statusColor, size: 22),
                      ],
                    ),
                    if (!isCorrect) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('你: ', style: TextStyle(fontSize: AppFontSize.sm, color: AppColors.textSecondary)),
                          Text(
                            userAnswer ?? '未作答',
                            style: TextStyle(fontSize: AppFontSize.sm, fontWeight: FontWeight.w600, color: statusColor),
                          ),
                          const SizedBox(width: 16),
                          Text('正确: ', style: TextStyle(fontSize: AppFontSize.sm, color: AppColors.textSecondary)),
                          Text(
                            correctAnswer,
                            style: TextStyle(fontSize: AppFontSize.sm, fontWeight: FontWeight.w600, color: AppColors.success),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                    // 查看解析
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _showQuestionAnalysis(context, q, isCorrect, userAnswer),
                        icon: const Icon(Icons.visibility, size: 16),
                        label: const Text('查看解析', style: TextStyle(fontSize: AppFontSize.sm)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),

            // 操作按钮
            AppButton(
              text: '再做一套',
              icon: Icons.refresh,
              onPressed: _backToSettings,
            ),
            const SizedBox(height: 12),
            AppButton(
              text: '返回考试中心',
              style: AppButtonStyle.outlined,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showQuestionAnalysis(BuildContext context, Map<String, dynamic> q, bool isCorrect, String? userAnswer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
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
              QuestionAnalysis(
                analysis: q['analysis'] as String? ?? '暂无解析',
                correctAnswer: q['correctAnswer'] as String?,
                userAnswer: userAnswer,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
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
