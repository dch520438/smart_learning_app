import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../services/ai_config_service.dart';
import '../../utils/constants.dart';
import '../../widgets/common_widgets.dart';

// ============================================================
// AI 服务页面
// ============================================================

/// AI服务页面 - 提供各种AI功能
class AIServiceScreen extends StatefulWidget {
  const AIServiceScreen({super.key});

  @override
  State<AIServiceScreen> createState() => _AIServiceScreenState();
}

class _AIServiceScreenState extends State<AIServiceScreen> {
  final AIService _aiService = AIService();

  @override
  void initState() {
    super.initState();
    _aiService.loadConfig();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI助手'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _openSettings(),
          ),
        ],
      ),
      body: !_aiService.isConfigured
          ? _buildNotConfiguredView()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 当前模型信息
                _buildCurrentModelCard(),

                const SizedBox(height: 24),

                // AI功能入口
                _buildSectionTitle('AI功能'),
                const SizedBox(height: 12),
                _buildFeatureGrid(),

                const SizedBox(height: 24),

                // AI对话测试
                _buildSectionTitle('AI对话测试'),
                const SizedBox(height: 12),
                _buildChatPreview(),
              ],
            ),
    );
  }

  Widget _buildNotConfiguredView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.psychology,
              size: 80,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 24),
            Text(
              'AI未配置',
              style: TextStyle(
                fontSize: AppFontSize.xxl,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '请先配置AI模型，然后即可使用各种AI功能',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppFontSize.md,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            AppButton(
              text: '去配置AI',
              icon: Icons.settings,
              onPressed: () => _openSettings(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentModelCard() {
    final config = _aiService.currentConfig;
    if (config == null) return const SizedBox.shrink();

    return AppCard(
      color: AppColors.primary.withOpacity(0.1),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              config.type == AIModelType.local
                  ? Icons.computer
                  : Icons.cloud,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.name,
                  style: const TextStyle(
                    fontSize: AppFontSize.lg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '模型: ${_aiService.currentModel ?? config.defaultModel}',
                  style: TextStyle(
                    fontSize: AppFontSize.sm,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            onPressed: () => _openSettings(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: AppFontSize.md,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildFeatureGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        _buildFeatureCard(
          icon: Icons.quiz,
          title: 'AI出题',
          description: '根据主题生成练习题',
          color: const Color(0xFF4CAF50),
          onTap: () => _showQuestionGenerator(),
        ),
        _buildFeatureCard(
          icon: Icons.check_circle,
          title: 'AI判卷',
          description: '智能判断答题正误',
          color: const Color(0xFF2196F3),
          onTap: () => _showAnswerChecker(),
        ),
        _buildFeatureCard(
          icon: Icons.lightbulb,
          title: 'AI解析',
          description: '详细解答题目',
          color: const Color(0xFFFF9800),
          onTap: () => _showAnalysis(),
        ),
        _buildFeatureCard(
          icon: Icons.account_tree,
          title: '思维导图',
          description: '生成知识结构图',
          color: const Color(0xFF9C27B0),
          onTap: () => _showMindMapGenerator(),
        ),
        _buildFeatureCard(
          icon: Icons.analytics,
          title: '学情分析',
          description: '分析学习情况',
          color: const Color(0xFFE91E63),
          onTap: () => _showLearningAnalysis(),
        ),
        _buildFeatureCard(
          icon: Icons.tips_and_updates,
          title: '学习建议',
          description: '个性化学习计划',
          color: const Color(0xFF00BCD4),
          onTap: () => _showLearningSuggestions(),
        ),
        _buildFeatureCard(
          icon: Icons.call_split,
          title: '内容拆分',
          description: '批量录入内容拆分',
          color: const Color(0xFF795548),
          onTap: () => _showContentSplitter(),
          gridSpan: 2,
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
    int gridSpan = 1,
  }) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: AppFontSize.md,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppFontSize.xs,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatPreview() {
    return AppCard(
      onTap: () => _showChatDialog(),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.chat_bubble, color: AppColors.info),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '与AI对话',
                  style: TextStyle(
                    fontSize: AppFontSize.md,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '点击这里与AI进行自由对话',
                  style: TextStyle(
                    fontSize: AppFontSize.sm,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textHint),
        ],
      ),
    );
  }

  void _openSettings() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AISettingsScreen(),
      ),
    );

    if (result == true) {
      setState(() {});
    }
  }

  // ============================================================
  // AI功能实现
  // ============================================================

  // AI出题
  void _showQuestionGenerator() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AIQuestionGeneratorScreen(),
      ),
    );
  }

  // AI判卷
  void _showAnswerChecker() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AIAnswerCheckerScreen(),
      ),
    );
  }

  // AI解析
  void _showAnalysis() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AIAnalysisScreen(),
      ),
    );
  }

  // 思维导图
  void _showMindMapGenerator() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AIMindMapScreen(),
      ),
    );
  }

  // 学情分析
  void _showLearningAnalysis() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AILearningAnalysisScreen(),
      ),
    );
  }

  // 学习建议
  void _showLearningSuggestions() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AILearningSuggestionsScreen(),
      ),
    );
  }

  // 内容拆分
  void _showContentSplitter() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AIContentSplitterScreen(),
      ),
    );
  }

  // AI对话
  void _showChatDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AIChatScreen(),
      ),
    );
  }
}

// ============================================================
// AI 出题页面
// ============================================================

class AIQuestionGeneratorScreen extends StatefulWidget {
  const AIQuestionGeneratorScreen({super.key});

  @override
  State<AIQuestionGeneratorScreen> createState() => _AIQuestionGeneratorScreenState();
}

class _AIQuestionGeneratorScreenState extends State<AIQuestionGeneratorScreen> {
  final AIService _aiService = AIService();
  final TextEditingController _topicController = TextEditingController();
  int _questionCount = 5;
  String _questionType = 'single_choice';
  bool _isLoading = false;
  List<Map<String, dynamic>> _questions = [];
  String? _error;

  final List<Map<String, String>> _questionTypes = [
    {'value': 'single_choice', 'label': '单选题'},
    {'value': 'multiple_choice', 'label': '多选题'},
    {'value': 'true_false', 'label': '判断题'},
    {'value': 'fill_blank', 'label': '填空题'},
  ];

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI出题')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 输入区域
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '题目主题',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _topicController,
                  decoration: InputDecoration(
                    hintText: '例如：Python编程基础',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // 题目数量
                Row(
                  children: [
                    const Text('题目数量：'),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Slider(
                        value: _questionCount.toDouble(),
                        min: 1,
                        max: 20,
                        divisions: 19,
                        label: '$_questionCount',
                        onChanged: (value) {
                          setState(() {
                            _questionCount = value.toInt();
                          });
                        },
                      ),
                    ),
                    Text('$_questionCount'),
                  ],
                ),

                // 题目类型
                const SizedBox(height: 12),
                const Text('题目类型：'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _questionTypes.map((type) {
                    final isSelected = _questionType == type['value'];
                    return ChoiceChip(
                      label: Text(type['label']!),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _questionType = type['value']!;
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 生成按钮
          SizedBox(
            width: double.infinity,
            child: AppButton(
              text: '生成题目',
              icon: Icons.auto_awesome,
              isLoading: _isLoading,
              onPressed: _generateQuestions,
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: AppColors.error),
            ),
          ],

          // 生成的题目
          if (_questions.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              '生成的题目',
              style: TextStyle(
                fontSize: AppFontSize.lg,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ..._questions.asMap().entries.map((entry) {
              final index = entry.key;
              final question = entry.value;
              return _buildQuestionCard(index + 1, question);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionCard(int index, Map<String, dynamic> question) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  '第$index题',
                  style: TextStyle(
                    fontSize: AppFontSize.sm,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                question['type'] ?? '单选题',
                style: TextStyle(
                  fontSize: AppFontSize.xs,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            question['content'] ?? '',
            style: const TextStyle(fontSize: AppFontSize.md),
          ),
          if (question['options'] != null) ...[
            const SizedBox(height: 12),
            ...((question['options'] as List).map((option) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(option.toString()),
              );
            })),
          ],
          const Divider(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 16),
                const SizedBox(width: 8),
                Text(
                  '答案: ${question['answer'] ?? ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          if (question['analysis'] != null) ...[
            const SizedBox(height: 12),
            ExpansionTile(
              title: const Text('查看解析'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              children: [
                Text(
                  question['analysis'].toString(),
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _generateQuestions() async {
    if (_topicController.text.isEmpty) {
      setState(() {
        _error = '请输入题目主题';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _questions = [];
    });

    try {
      final questions = await _aiService.generateQuestions(
        _topicController.text,
        count: _questionCount,
        type: _questionType,
      );

      setState(() {
        _questions = questions;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

// ============================================================
// AI 判卷页面
// ============================================================

class AIAnswerCheckerScreen extends StatefulWidget {
  const AIAnswerCheckerScreen({super.key});

  @override
  State<AIAnswerCheckerScreen> create State() => _AIAnswerCheckerScreenState();
}

class _AIAnswerCheckerScreenState extends State<AIAnswerCheckerScreen> {
  final AIService _aiService = AIService();
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _correctController = TextEditingController();
  final TextEditingController _userAnswerController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _questionController.dispose();
    _correctController.dispose();
    _userAnswerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI判卷')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('题目', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _questionController,
                  decoration: InputDecoration(
                    hintText: '请输入题目内容',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                const Text('正确答案', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _correctController,
                  decoration: InputDecoration(
                    hintText: '请输入正确答案',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('用户答案', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _userAnswerController,
                  decoration: InputDecoration(
                    hintText: '请输入用户答案',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              text: '提交判卷',
              icon: Icons.check,
              isLoading: _isLoading,
              onPressed: _checkAnswer,
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 24),
            _buildResultCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final isCorrect = _result!['isCorrect'] as bool? ?? false;
    final score = _result!['score'] as int? ?? 0;
    final feedback = _result!['feedback'] as String? ?? '';

    return AppCard(
      color: isCorrect
          ? AppColors.success.withOpacity(0.1)
          : AppColors.error.withOpacity(0.1),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: isCorrect ? AppColors.success : AppColors.error,
                size: 48,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCorrect ? '回答正确！' : '回答错误',
                    style: TextStyle(
                      fontSize: AppFontSize.xl,
                      fontWeight: FontWeight.w600,
                      color: isCorrect ? AppColors.success : AppColors.error,
                    ),
                  ),
                  Text(
                    '得分：$score分',
                    style: TextStyle(
                      fontSize: AppFontSize.lg,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '反馈',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                MarkdownBody(
                  data: feedback,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(fontSize: AppFontSize.md),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkAnswer() async {
    if (_questionController.text.isEmpty ||
        _correctController.text.isEmpty ||
        _userAnswerController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请填写所有字段'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _result = null;
    });

    try {
      final result = await _aiService.checkAnswer(
        question: _questionController.text,
        userAnswer: _userAnswerController.text,
        correctAnswer: _correctController.text,
      );

      setState(() {
        _result = result;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('判卷失败: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

// ============================================================
// AI 解析页面
// ============================================================

class AIAnalysisScreen extends StatefulWidget {
  const AIAnalysisScreen({super.key});

  @override
  State<AIAnalysisScreen> createState() => _AIAnalysisScreenState();
}

class _AIAnalysisScreenState extends State<AIAnalysisScreen> {
  final AIService _aiService = AIService();
  final TextEditingController _questionController = TextEditingController();
  bool _isLoading = false;
  String? _analysis;

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI解析')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('题目', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _questionController,
                  decoration: InputDecoration(
                    hintText: '请输入需要解析的题目',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  maxLines: 4,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              text: '获取解析',
              icon: Icons.lightbulb,
              isLoading: _isLoading,
              onPressed: _getAnalysis,
            ),
          ),
          if (_analysis != null) ...[
            const SizedBox(height: 24),
            const Text(
              '解析结果',
              style: TextStyle(
                fontSize: AppFontSize.lg,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: MarkdownBody(
                data: _analysis!,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(fontSize: AppFontSize.md, height: 1.6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _getAnalysis() async {
    if (_questionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请输入题目'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _analysis = null;
    });

    try {
      final prompt = '''
请详细解析以下题目，给出解题思路、知识点和步骤说明。

题目：${_questionController.text}

请以Markdown格式返回解析内容，包括：
1. 解题思路
2. 涉及知识点
3. 详细解题步骤
''';

      final result = await _aiService.chat(prompt);
      setState(() {
        _analysis = result;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('解析失败: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

// ============================================================
// AI 思维导图页面
// ============================================================

class AIMindMapScreen extends StatefulWidget {
  const AIMindMapScreen({super.key});

  @override
  State<AIMindMapScreen> createState() => _AIMindMapScreenState();
}

class _AIMindMapScreenState extends State<AIMindMapScreen> {
  final AIService _aiService = AIService();
  final TextEditingController _topicController = TextEditingController();
  bool _isLoading = false;
  String? _mermaidCode;
  List<Map<String, dynamic>>? _jsonData;

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI思维导图')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('主题', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _topicController,
                  decoration: InputDecoration(
                    hintText: '请输入思维导图主题',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: '生成Mermaid',
                  icon: Icons.code,
                  isLoading: _isLoading,
                  onPressed: () => _generateMindMap(format: 'mermaid'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  text: '生成JSON',
                  icon: Icons.data_object,
                  isLoading: _isLoading,
                  onPressed: () => _generateMindMap(format: 'json'),
                ),
              ),
            ],
          ),
          if (_mermaidCode != null) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Mermaid代码',
                  style: TextStyle(
                    fontSize: AppFontSize.lg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: _copyMermaidCode,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText(
                  _mermaidCode!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: AppFontSize.sm,
                  ),
                ),
              ),
            ),
          ],
          if (_jsonData != null) ...[
            const SizedBox(height: 24),
            const Text(
              'JSON数据',
              style: TextStyle(
                fontSize: AppFontSize.lg,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildJsonTree(_jsonData!),
          ],
        ],
      ),
    );
  }

  Widget _buildJsonTree(List<Map<String, dynamic>> data) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: data.map((item) => _buildJsonNode(item, 0)).toList(),
      ),
    );
  }

  Widget _buildJsonNode(Map<String, dynamic> node, int depth) {
    final children = node['children'] as List<dynamic>?;
    final hasChildren = children != null && children.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: depth * 16.0, top: 4, bottom: 4),
          child: Row(
            children: [
              if (hasChildren)
                Icon(
                  Icons.folder_open,
                  size: 16,
                  color: AppColors.primary,
                )
              else
                Icon(
                  Icons.article,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  node['text']?.toString() ?? '',
                  style: const TextStyle(fontSize: AppFontSize.sm),
                ),
              ),
            ],
          ),
        ),
        if (hasChildren)
          ...children!.map((child) => _buildJsonNode(
            child as Map<String, dynamic>,
            depth + 1,
          )),
      ],
    );
  }

  Future<void> _generateMindMap({required String format}) async {
    if (_topicController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请输入主题'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _mermaidCode = null;
      _jsonData = null;
    });

    try {
      if (format == 'mermaid') {
        final result = await _aiService.generateMindMap(_topicController.text);
        setState(() {
          _mermaidCode = result;
        });
      } else {
        final result = await _aiService.generateMindMapJson(_topicController.text);
        setState(() {
          _jsonData = result;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('生成失败: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _copyMermaidCode() {
    // 实现复制功能
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已复制到剪贴板'),
        backgroundColor: AppColors.success,
      ),
    );
  }
}

// ============================================================
// AI 学情分析页面
// ============================================================

class AILearningAnalysisScreen extends StatefulWidget {
  const AILearningAnalysisScreen({super.key});

  @override
  State<AILearningAnalysisScreen> createState() => _AILearningAnalysisScreenState();
}

class _AILearningAnalysisScreenState extends State<AILearningAnalysisScreen> {
  final AIService _aiService = AIService();
  final TextEditingController _dataController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _analysisResult;

  @override
  void dispose() {
    _dataController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI学情分析')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('学习数据', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  '请输入学习数据，包括学习时长、正确率、薄弱知识点等',
                  style: TextStyle(
                    fontSize: AppFontSize.sm,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _dataController,
                  decoration: InputDecoration(
                    hintText: '例如：\n- 数学本周学习时长：5小时\n- 正确率：75%\n- 薄弱点：几何、函数',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  maxLines: 6,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              text: '开始分析',
              icon: Icons.analytics,
              isLoading: _isLoading,
              onPressed: _analyze,
            ),
          ),
          if (_analysisResult != null) ...[
            const SizedBox(height: 24),
            _buildAnalysisResult(),
          ],
        ],
      ),
    );
  }

  Widget _buildAnalysisResult() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 学习概况
        AppCard(
          color: AppColors.primary.withOpacity(0.1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.school, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text(
                    '学习概况',
                    style: TextStyle(
                      fontSize: AppFontSize.lg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(_analysisResult!['summary'] ?? ''),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 优势
        _buildSectionCard(
          '优势',
          Icons.thumb_up,
          AppColors.success,
          (_analysisResult!['strengths'] as List<dynamic>?)?.cast<String>() ?? [],
        ),

        const SizedBox(height: 12),

        // 薄弱点
        _buildSectionCard(
          '薄弱点',
          Icons.warning_amber,
          AppColors.warning,
          (_analysisResult!['weaknesses'] as List<dynamic>?)?.cast<String>() ?? [],
        ),

        const SizedBox(height: 12),

        // 建议
        _buildSectionCard(
          '改进建议',
          Icons.lightbulb,
          AppColors.info,
          (_analysisResult!['suggestions'] as List<dynamic>?)?.cast<String>() ?? [],
        ),

        if (_analysisResult!['studyPlan']?.toString().isNotEmpty ?? false) ...[
          const SizedBox(height: 12),
          AppCard(
            color: AppColors.secondary.withOpacity(0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.event_note, color: AppColors.secondary),
                    const SizedBox(width: 8),
                    const Text(
                      '学习计划',
                      style: TextStyle(
                        fontSize: AppFontSize.lg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                MarkdownBody(data: _analysisResult!['studyPlan'] ?? ''),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionCard(
    String title,
    IconData icon,
    Color color,
    List<String> items,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: AppFontSize.lg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(color: color)),
                Expanded(child: Text(item)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Future<void> _analyze() async {
    if (_dataController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请输入学习数据'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _analysisResult = null;
    });

    try {
      final result = await _aiService.analyzeLearning(_dataController.text);
      setState(() {
        _analysisResult = result;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('分析失败: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

// ============================================================
// AI 学习建议页面
// ============================================================

class AILearningSuggestionsScreen extends StatefulWidget {
  const AILearningSuggestionsScreen({super.key});

  @override
  State<AILearningSuggestionsScreen> createState() => _AILearningSuggestionsScreenState();
}

class _AILearningSuggestionsScreenState extends State<AILearningSuggestionsScreen> {
  final AIService _aiService = AIService();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _weakTopicsController = TextEditingController();
  double _studyTime = 2.0;
  bool _isLoading = false;
  Map<String, dynamic>? _suggestions;

  @override
  void dispose() {
    _subjectController.dispose();
    _weakTopicsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI学习建议')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('科目', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _subjectController,
                  decoration: InputDecoration(
                    hintText: '例如：数学',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('薄弱知识点', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _weakTopicsController,
                  decoration: InputDecoration(
                    hintText: '用逗号分隔，例如：几何，函数，三角函数',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('每日学习时间：'),
                    Expanded(
                      child: Slider(
                        value: _studyTime,
                        min: 0.5,
                        max: 6,
                        divisions: 11,
                        label: '${_studyTime}h',
                        onChanged: (value) {
                          setState(() {
                            _studyTime = value;
                          });
                        },
                      ),
                    ),
                    Text('${_studyTime}小时'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              text: '获取建议',
              icon: Icons.tips_and_updates,
              isLoading: _isLoading,
              onPressed: _getSuggestions,
            ),
          ),
          if (_suggestions != null) ...[
            const SizedBox(height: 24),
            _buildSuggestionsResult(),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestionsResult() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_suggestions!['dailyPlan']?.toString().isNotEmpty ?? false)
          _buildPlanCard(
            '每日计划',
            Icons.today,
            AppColors.primary,
            _suggestions!['dailyPlan'] ?? '',
          ),
        const SizedBox(height: 12),
        if (_suggestions!['weeklyPlan']?.toString().isNotEmpty ?? false)
          _buildPlanCard(
            '每周计划',
            Icons.date_range,
            AppColors.info,
            _suggestions!['weeklyPlan'] ?? '',
          ),
        const SizedBox(height: 12),
        if ((_suggestions!['tips'] as List<dynamic>?)?.isNotEmpty ?? false)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb, color: AppColors.warning),
                    const SizedBox(width: 8),
                    const Text(
                      '学习技巧',
                      style: TextStyle(
                        fontSize: AppFontSize.lg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...((_suggestions!['tips'] as List<dynamic>).cast<String>())
                    .map((tip) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('• ', style: TextStyle(color: AppColors.warning)),
                              Expanded(child: Text(tip)),
                            ],
                          ),
                        )),
              ],
            ),
          ),
        if (_suggestions!['resources']?.toString().isNotEmpty ?? false) ...[
          const SizedBox(height: 12),
          AppCard(
            color: AppColors.secondary.withOpacity(0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.library_books, color: AppColors.secondary),
                    const SizedBox(width: 8),
                    const Text(
                      '推荐资源',
                      style: TextStyle(
                        fontSize: AppFontSize.lg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                MarkdownBody(data: _suggestions!['resources'] ?? ''),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlanCard(String title, IconData icon, Color color, String content) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: AppFontSize.lg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MarkdownBody(data: content),
        ],
      ),
    );
  }

  Future<void> _getSuggestions() async {
    if (_subjectController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请输入科目'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final weakTopics = _weakTopicsController.text
        .split(RegExp(r'[,，、]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    setState(() {
      _isLoading = true;
      _suggestions = null;
    });

    try {
      final result = await _aiService.generateLearningSuggestions(
        subject: _subjectController.text,
        weakTopics: weakTopics,
        studyTimePerDay: _studyTime.toInt(),
      );

      setState(() {
        _suggestions = result;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('获取建议失败: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

// ============================================================
// AI 内容拆分页面
// ============================================================

class AIContentSplitterScreen extends StatefulWidget {
  const AIContentSplitterScreen({super.key});

  @override
  State<AIContentSplitterScreen> createState() => _AIContentSplitterScreenState();
}

class _AIContentSplitterScreenState extends State<AIContentSplitterScreen> {
  final AIService _aiService = AIService();
  final TextEditingController _contentController = TextEditingController();
  String _splitType = 'questions';
  bool _isLoading = false;
  List<String> _splitResults = [];

  final List<Map<String, String>> _splitTypes = [
    {'value': 'questions', 'label': '拆分为题目'},
    {'value': 'knowledge_points', 'label': '拆分为知识点'},
    {'value': 'notes', 'label': '拆分为笔记'},
  ];

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI内容拆分')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('拆分类型', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: _splitTypes.map((type) {
                    final isSelected = _splitType == type['value'];
                    return ChoiceChip(
                      label: Text(type['label']!),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _splitType = type['value']!;
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('待拆分内容', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  '请输入需要拆分的长文本内容',
                  style: TextStyle(
                    fontSize: AppFontSize.sm,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _contentController,
                  decoration: InputDecoration(
                    hintText: '请输入要拆分的内容...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  maxLines: 8,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              text: '开始拆分',
              icon: Icons.call_split,
              isLoading: _isLoading,
              onPressed: _splitContent,
            ),
          ),
          if (_splitResults.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '拆分结果 (${_splitResults.length}项)',
                  style: const TextStyle(
                    fontSize: AppFontSize.lg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_all),
                  onPressed: _copyResults,
                  tooltip: '复制全部',
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._splitResults.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _buildSplitItem(index + 1, item);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildSplitItem(int index, String item) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Center(
              child: Text(
                '$index',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item,
              style: const TextStyle(fontSize: AppFontSize.md),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _splitContent() async {
    if (_contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请输入要拆分的内容'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _splitResults = [];
    });

    try {
      final result = await _aiService.splitContent(
        _contentController.text,
        type: _splitType,
      );

      setState(() {
        _splitResults = result;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('拆分失败: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _copyResults() {
    // 实现复制功能
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已复制到剪贴板'),
        backgroundColor: AppColors.success,
      ),
    );
  }
}

// ============================================================
// AI 对话页面
// ============================================================

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final AIService _aiService = AIService();
  final TextEditingController _messageController = TextEditingController();
  final List<AIMessage> _messages = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI对话')),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            '开始与AI对话吧！',
            style: TextStyle(
              fontSize: AppFontSize.lg,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(AIMessage message) {
    final isUser = message.role == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.textPrimary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MarkdownBody(
              data: message.content,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(fontSize: AppFontSize.md),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: '输入消息...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                maxLines: null,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: _isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : Icon(Icons.send, color: AppColors.primary),
              onPressed: _isLoading ? null : _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    _messageController.clear();

    setState(() {
      _messages.add(AIMessage(role: 'user', content: text));
      _isLoading = true;
    });

    try {
      final response = await _aiService.chat(text);
      setState(() {
        _messages.add(AIMessage(role: 'assistant', content: response));
      });
    } catch (e) {
      setState(() {
        _messages.add(AIMessage(
          role: 'assistant',
          content: '抱歉，发生了错误：${e.toString()}',
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

// 导出设置页面
export 'ai_settings_screen.dart';
