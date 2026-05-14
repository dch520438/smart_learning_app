import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/mother_question.dart';
import '../../services/database_service.dart';
import '../../services/export_service.dart';
import '../../services/ocr_service.dart';
import '../../services/print_service.dart';
import '../../services/voice_service.dart';
import '../../services/attachment_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/input_method_selector.dart';
import '../../widgets/symbol_picker.dart';
import '../../widgets/image_attachment_widget.dart';

// ============================================================
// MotherQuestionsScreen - 母题集主页面
// ============================================================

class MotherQuestionsScreen extends StatefulWidget {
  const MotherQuestionsScreen({super.key});

  @override
  State<MotherQuestionsScreen> createState() => _MotherQuestionsScreenState();
}

class _MotherQuestionsScreenState extends State<MotherQuestionsScreen> {
  final DatabaseService _db = DatabaseService();
  final ExportService _exportService = ExportService();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _questions = [];
  List<Map<String, dynamic>> _filteredQuestions = [];
  bool _isLoading = true;
  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};

  // 筛选条件
  String _selectedSubject = '全部';
  int _selectedDifficulty = 0; // 0 = 全部
  String _searchKeyword = '';

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> questions;
      if (_selectedSubject == '全部') {
        questions = await _db.queryAllMotherQuestions();
      } else {
        questions = await _db.queryMotherQuestionsBySubject(_selectedSubject);
      }
      setState(() {
        _questions = questions;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    var filtered = _questions.where((q) {
      // 难度筛选
      if (_selectedDifficulty > 0) {
        final difficulty = q['difficulty'] as int? ?? 1;
        if (difficulty != _selectedDifficulty) return false;
      }
      // 搜索关键词
      if (_searchKeyword.isNotEmpty) {
        final title = (q['title'] as String? ?? '').toLowerCase();
        final content = (q['question_content'] as String? ?? '').toLowerCase();
        final tags = (q['tags'] as String? ?? '').toLowerCase();
        final keyword = _searchKeyword.toLowerCase();
        if (!title.contains(keyword) &&
            !content.contains(keyword) &&
            !tags.contains(keyword)) {
          return false;
        }
      }
      return true;
    }).toList();
    setState(() => _filteredQuestions = filtered);
  }

  Future<void> _deleteQuestions(List<int> ids) async {
    try {
      for (final id in ids) {
        await _db.deleteMotherQuestion(id);
      }
      _exitSelectionMode();
      _loadQuestions();
      showSnackBar(context, '已删除 ${ids.length} 道母题');
    } catch (e) {
      showSnackBar(context, '删除失败', isError: true);
    }
  }

  void _enterSelectionMode() {
    setState(() => _isSelectionMode = true);
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      if (_selectedIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _filteredQuestions.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.clear();
        for (final q in _filteredQuestions) {
          _selectedIds.add(q['id'] as int);
        }
      }
    });
  }

  Future<void> _batchExport() async {
    if (_selectedIds.isEmpty) return;
    try {
      AppLoading.show(context, message: '正在导出...');

      // 获取选中的母题数据
      final selectedQuestions = _questions.where((q) {
        final id = q['id'] as int?;
        return id != null && _selectedIds.contains(id);
      }).toList();

      // 构建导出数据
      final exportData = {
        'export_version': '1.0',
        'export_time': DateTime.now().toIso8601String(),
        'mother_questions': selectedQuestions,
      };

      // 保存到文件
      final result = await _exportService.exportAllToJson(
        fileName: 'mother_questions_export_${DateTime.now().millisecondsSinceEpoch}.json',
      );

      AppLoading.hide(context);
      _exitSelectionMode();

      if (result.success && mounted) {
        showSnackBar(context, '已导出 ${_selectedIds.length} 道母题到 ${result.fileName}');
      } else if (mounted) {
        showSnackBar(context, '导出失败: ${result.errorMessage}', isError: true);
      }
    } catch (e) {
      AppLoading.hide(context);
      if (mounted) {
        showSnackBar(context, '导出失败: $e', isError: true);
      }
    }
  }

  Future<void> _batchPrint() async {
    if (_selectedIds.isEmpty) return;

    // 获取选中的母题数据
    final selectedQuestions = _questions.where((q) {
      final id = q['id'] as int?;
      return id != null && _selectedIds.contains(id);
    }).toList();

    // 转换为打印内容项
    final printItems = selectedQuestions.map((q) {
      // 构建母题内容
      final buffer = StringBuffer();
      buffer.writeln('【标题】');
      buffer.writeln(q['title'] as String? ?? '无标题');
      buffer.writeln();
      buffer.writeln('【题目】');
      buffer.writeln(q['question'] as String? ?? '');
      buffer.writeln();

      final options = q['options'];
      if (options != null && options.toString().isNotEmpty) {
        buffer.writeln('【选项】');
        try {
          final optionsList = options is String ? jsonDecode(options) : options;
          if (optionsList is List) {
            for (int i = 0; i < optionsList.length; i++) {
              final option = optionsList[i];
              if (option is Map) {
                final label = option['label'] ?? String.fromCharCode(65 + i);
                final text = option['text'] ?? '';
                buffer.writeln('$label. $text');
              }
            }
          }
        } catch (_) {}
        buffer.writeln();
      }

      final correctAnswer = q['correct_answer'] as String?;
      if (correctAnswer != null && correctAnswer.isNotEmpty) {
        buffer.writeln('【正确答案】');
        buffer.writeln(correctAnswer);
        buffer.writeln();
      }

      final analysis = q['analysis'] as String?;
      if (analysis != null && analysis.isNotEmpty) {
        buffer.writeln('【解析】');
        buffer.writeln(analysis);
      }

      return PrintContentItem(
        type: PrintContentType.motherQuestion,
        title: q['title'] as String? ?? '母题详情',
        content: buffer.toString(),
        subject: q['subject'] as String?,
        difficulty: q['difficulty'] as int?,
        tags: q['tags'] as String?,
        masteryLevel: q['mastery_level'] as int?,
        createdAt: q['created_at'] != null
            ? formatDate(DateTime.parse(q['created_at'] as String))
            : null,
      );
    }).toList();

    // 调用批量打印
    await PrintService.printBatch(
      context: context,
      items: printItems,
      customTitle: '母题打印 (${printItems.length}项)',
    );

    _exitSelectionMode();
  }

  Future<void> _showSearch() async {
    final keyword = await showSearch<String>(
      context: context,
      delegate: _MotherQuestionSearchDelegate(
        onSearch: (keyword) {
          setState(() {
            _searchKeyword = keyword;
            _applyFilters();
          });
        },
      ),
    );
    if (keyword != null && keyword.isEmpty) {
      setState(() {
        _searchKeyword = '';
        _applyFilters();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('母题集'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearch,
            tooltip: '搜索',
          ),
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _exitSelectionMode,
              tooltip: '取消选择',
            ),
        ],
      ),
      body: Column(
        children: [
          // 筛选栏
          _buildFilterBar(),
          // 列表
          Expanded(
            child: _isLoading
                ? const Center(child: AppLoading())
                : _filteredQuestions.isEmpty
                    ? AppEmptyState(
                        message: '暂无母题',
                        icon: Icons.psychology_outlined,
                        actionText: '添加母题',
                        onAction: () => _showAddMotherQuestion(context),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadQuestions,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: _filteredQuestions.length,
                          itemBuilder: (context, index) {
                            final question = _filteredQuestions[index];
                            return _buildMotherQuestionCard(
                              question,
                              index,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      // 批量操作栏
      bottomNavigationBar: _isSelectionMode
          ? BatchOperationBar(
              totalCount: _filteredQuestions.length,
              selectedCount: _selectedIds.length,
              isAllSelected:
                  _selectedIds.length == _filteredQuestions.length &&
                      _filteredQuestions.isNotEmpty,
              onSelectAll: (_) => _selectAll(),
              onDelete: _selectedIds.isNotEmpty
                  ? () {
                      AppDialog.showConfirmDelete(
                        context: context,
                        title: '批量删除',
                        message:
                            '确定要删除选中的 ${_selectedIds.length} 道母题吗？',
                        onConfirm: () =>
                            _deleteQuestions(_selectedIds.toList()),
                      );
                    }
                  : null,
              onExport: _batchExport,
              onPrint: _batchPrint,
              onCancel: _exitSelectionMode,
            )
          : null,
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: () => _showAddMotherQuestion(context),
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          // 学科筛选
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildSubjectChip('全部', _selectedSubject == '全部', () {
                  setState(() {
                    _selectedSubject = '全部';
                  });
                  _loadQuestions();
                }),
                const SizedBox(width: 8),
                ...kSubjectNames.map((subject) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildSubjectChip(
                      subject,
                      _selectedSubject == subject,
                      () {
                        setState(() => _selectedSubject = subject);
                        _loadQuestions();
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 难度筛选
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                AppTag(
                  label: '全部难度',
                  color: AppColors.textSecondary,
                  selected: _selectedDifficulty == 0,
                  onTap: () {
                    setState(() => _selectedDifficulty = 0);
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 8),
                ...kDifficultyLevels.map((level) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AppTag(
                      label: level['label'] as String,
                      color: level['color'] as Color,
                      selected: _selectedDifficulty == level['value'],
                      onTap: () {
                        setState(() =>
                            _selectedDifficulty = level['value'] as int);
                        _applyFilters();
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          // 搜索提示
          if (_searchKeyword.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.search, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '搜索: $_searchKeyword (${_filteredQuestions.length} 条结果)',
                  style: TextStyle(
                    fontSize: AppFontSize.sm,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () {
                    setState(() {
                      _searchKeyword = '';
                      _applyFilters();
                    });
                  },
                  child: Icon(Icons.clear, size: 18, color: AppColors.textHint),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMotherQuestionCard(
      Map<String, dynamic> question, int index) {
    final subject = question['subject'] as String? ?? '未分类';
    final title = question['title'] as String? ?? '未命名母题';
    final difficulty = question['difficulty'] as int? ?? 1;
    final variantCount = question['variant_count'] as int? ?? 0;
    final masteryLevel = question['mastery_level'] as int? ?? 0;
    final tags = question['tags'] as String? ?? '';
    final questionId = question['id'] as int;
    final isSelected = _selectedIds.contains(questionId);
    final createdAt = question['created_at'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onLongPress: () {
          if (!_isSelectionMode) {
            _enterSelectionMode();
            _toggleSelection(questionId);
          }
        },
        onTap: _isSelectionMode
            ? () => _toggleSelection(questionId)
            : () => _navigateToDetail(question),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : AppColors.divider,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 第一行：标题 + 选择框
                Row(
                  children: [
                    if (_isSelectionMode) ...[
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleSelection(questionId),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    // 学科图标
                    SubjectIcon(subjectName: subject, size: 36),
                    const SizedBox(width: 10),
                    // 标题
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: AppFontSize.lg,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // 更多操作
                    if (!_isSelectionMode)
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'delete') {
                            AppDialog.showConfirmDelete(
                              context: context,
                              title: '删除母题',
                              onConfirm: () =>
                                  _deleteQuestions([questionId]),
                            );
                          } else if (value == 'select') {
                            _enterSelectionMode();
                            _toggleSelection(questionId);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                              value: 'select', child: Text('多选')),
                          const PopupMenuItem(
                              value: 'delete', child: Text('删除')),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // 第二行：标签
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedSubject = subject;
                          _applyFilters();
                        });
                      },
                      child: AppTag(
                        label: subject,
                        color: getSubjectColor(subject),
                        dense: true,
                        fontSize: AppFontSize.xs,
                      ),
                    ),
                    DifficultyStars(difficulty: difficulty, iconSize: 14),
                    if (variantCount > 0)
                      AppTag(
                        label: '$variantCount 道变式题',
                        color: AppColors.info,
                        dense: true,
                        fontSize: AppFontSize.xs,
                        icon: Icons.call_split,
                      ),
                  ],
                ),

                // 第三行：掌握度
                const SizedBox(height: 10),
                MasteryProgressBar(
                  mastery: masteryLevel,
                  height: 6,
                ),

                // 第四行：标签和时间
                if (tags.isNotEmpty || createdAt.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (tags.isNotEmpty) ...[
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: tags.split(',').map((tag) {
                              final trimmedTag = tag.trim();
                              if (trimmedTag.isEmpty) return const SizedBox.shrink();
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _searchKeyword = trimmedTag;
                                    _applyFilters();
                                  });
                                },
                                child: Text(
                                  '#$trimmedTag',
                                  style: TextStyle(
                                    fontSize: AppFontSize.xs,
                                    color: AppColors.primary,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                      if (createdAt.isNotEmpty) ...[
                        const SizedBox(width: 8),
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
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToDetail(Map<String, dynamic> question) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            MotherQuestionDetailScreen(questionData: question),
      ),
    ).then((_) => _loadQuestions());
  }

  // ==================== 学科筛选Chip ====================

  Widget _buildSubjectChip(
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    final color = label == '全部' ? AppColors.primary : getSubjectColor(label);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: selected ? color : color.withOpacity(0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppFontSize.sm,
            color: selected ? Colors.white : color,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Future<void> _showAddMotherQuestion(BuildContext context) async {
    // 显示录入方式选择器
    final method = await InputMethodSelector.show(context);
    if (method == null) return;

    // 处理录入方式
    final handler = InputMethodHandler(context);
    final recognizedText = await handler.handleInputMethod(method);

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _AddMotherQuestionScreen(
          initialContent: recognizedText,
        ),
      ),
    );
    if (result == true) {
      _loadQuestions();
    }
  }
}

// ============================================================
// 搜索代理
// ============================================================

class _MotherQuestionSearchDelegate extends SearchDelegate<String> {
  final ValueChanged<String> onSearch;

  _MotherQuestionSearchDelegate({required this.onSearch});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          onSearch('');
          close(context, '');
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    onSearch(query);
    close(context, query);
    return const SizedBox.shrink();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Container();
  }
}

// ============================================================
// 母题详情页
// ============================================================

class MotherQuestionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> questionData;

  const MotherQuestionDetailScreen({super.key, required this.questionData});

  @override
  State<MotherQuestionDetailScreen> createState() =>
      MotherQuestionDetailScreenState();
}

class MotherQuestionDetailScreenState
    extends State<MotherQuestionDetailScreen> {
  final DatabaseService _db = DatabaseService();
  late Map<String, dynamic> _question;
  bool _isLoading = true;

  // 关联变式题
  List<Map<String, dynamic>> _variantQuestions = [];

  @override
  void initState() {
    super.initState();
    _question = widget.questionData;
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    try {
      // 重新从数据库加载最新数据
      final id = _question['id'] as int;
      final fresh = await _db.queryMotherQuestionById(id);
      if (fresh != null) {
        setState(() => _question = fresh);
      }
      // 加载关联变式题（模拟数据）
      final variantCount = _question['variant_count'] as int? ?? 0;
      _variantQuestions = List.generate(
        variantCount.clamp(0, 10),
        (index) => {
          'id': index,
          'title': '变式题 ${index + 1}',
          'content': '这是母题的第${index + 1}道变式题，基于原题进行了变形和扩展。',
          'difficulty': (_question['difficulty'] as int? ?? 1),
        },
      );
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteQuestion() async {
    final confirmed = await AppDialog.showConfirmDelete(
      context: context,
      title: '删除母题',
      message: '确定要删除这道母题吗？关联的变式题也将被删除。',
    );
    if (confirmed == true) {
      try {
        await _db.deleteMotherQuestion(_question['id'] as int);
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          showSnackBar(context, '删除失败', isError: true);
        }
      }
    }
  }

  Future<void> _editQuestion() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _AddMotherQuestionScreen(
          existingQuestion: _question,
        ),
      ),
    );
    if (result == true) {
      _loadDetail();
    }
  }

  Future<void> _addVariantQuestion() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _AddMotherQuestionScreen(
          motherQuestionId: _question['id'] as int?,
          isVariant: true,
          parentTitle: _question['title'] as String?,
        ),
      ),
    );
    if (result == true) {
      _loadDetail();
    }
  }

  @override
  Widget build(BuildContext context) {
    final subject = _question['subject'] as String? ?? '未分类';
    final title = _question['title'] as String? ?? '未命名母题';
    final content = _question['question_content'] as String? ?? '';
    final options = _question['options'] as String? ?? '';
    final correctAnswer = _question['correct_answer'] as String? ?? '';
    final analysis = _question['analysis'] as String? ?? '';
    final difficulty = _question['difficulty'] as int? ?? 1;
    final tags = _question['tags'] as String? ?? '';
    final masteryLevel = _question['mastery_level'] as int? ?? 0;
    final variantCount = _question['variant_count'] as int? ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            onPressed: () => PrintService.printMotherQuestion(
              context: context,
              title: title,
              question: content,
              options: options.isNotEmpty ? options : null,
              correctAnswer: correctAnswer,
              analysis: analysis,
              subject: subject,
              difficulty: difficulty,
              tags: tags,
              masteryLevel: masteryLevel,
            ),
            tooltip: '打印',
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _editQuestion,
            tooltip: '编辑',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteQuestion,
            tooltip: '删除',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: AppLoading())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 学科和难度
                  Row(
                    children: [
                      AppTag(
                        label: subject,
                        color: getSubjectColor(subject),
                      ),
                      const SizedBox(width: 8),
                      DifficultyStars(difficulty: difficulty),
                      const Spacer(),
                      if (variantCount > 0)
                        AppTag(
                          label: '$variantCount 道变式题',
                          color: AppColors.info,
                          icon: Icons.call_split,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 掌握度
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '掌握度',
                          style: TextStyle(
                            fontSize: AppFontSize.md,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        MasteryProgressBar(mastery: masteryLevel),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 题目内容
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.quiz, size: 20, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              '题目内容',
                              style: TextStyle(
                                fontSize: AppFontSize.md,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          content,
                          style: TextStyle(
                            fontSize: AppFontSize.md,
                            color: AppColors.textPrimary,
                            height: 1.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 选项
                  if (options.isNotEmpty) ...[
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.list_alt, size: 20, color: AppColors.info),
                              const SizedBox(width: 8),
                              Text(
                                '选项',
                                style: TextStyle(
                                  fontSize: AppFontSize.md,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildOptions(options, correctAnswer),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 正确答案
                  if (correctAnswer.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.success),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.success, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '正确答案: $correctAnswer',
                            style: TextStyle(
                              fontSize: AppFontSize.md,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 解析
                  if (analysis.isNotEmpty) ...[
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lightbulb_outline,
                                  size: 20, color: AppColors.warning),
                              const SizedBox(width: 8),
                              Text(
                                '解析',
                                style: TextStyle(
                                  fontSize: AppFontSize.md,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
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
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 标签
                  if (tags.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tags.split(',').where((t) => t.trim().isNotEmpty).map((tag) {
                        return AppTag(
                          label: tag.trim(),
                          color: AppColors.textSecondary,
                          dense: true,
                          fontSize: AppFontSize.xs,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 关联变式题列表
                  if (_variantQuestions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '关联变式题',
                          style: TextStyle(
                            fontSize: AppFontSize.xl,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        AppTag(
                          label: '${_variantQuestions.length} 道',
                          color: AppColors.info,
                          dense: true,
                          fontSize: AppFontSize.xs,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._variantQuestions.map((variant) => AppCard(
                          margin: const EdgeInsets.only(bottom: 8),
                          onTap: () {
                            // 可以跳转到变式题详情
                          },
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.info.withOpacity(0.1),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${variant['id']! + 1}',
                                  style: TextStyle(
                                    fontSize: AppFontSize.sm,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.info,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  variant['title'] as String,
                                  style: TextStyle(
                                    fontSize: AppFontSize.md,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              DifficultyStars(
                                difficulty: variant['difficulty'] as int,
                                iconSize: 14,
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right,
                                  color: AppColors.textHint, size: 20),
                            ],
                          ),
                        )),
                  ],

                  const SizedBox(height: 24),

                  // 添加变式题按钮
                  AppButton(
                    text: '添加变式题',
                    icon: Icons.add_circle_outline,
                    style: AppButtonStyle.outlined,
                    onPressed: _addVariantQuestion,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildOptions(String optionsJson, String correctAnswer) {
    try {
      final options = jsonDecode(optionsJson) as List;
      const labels = ['A', 'B', 'C', 'D', 'E', 'F'];
      return Column(
        children: options.asMap().entries.map((entry) {
          final idx = entry.key;
          final option = entry.value;
          final label = idx < labels.length ? labels[idx] : '${idx + 1}';
          final isCorrect = label == correctAnswer;
          final optionText = option is Map
              ? (option['text'] as String? ?? option.toString())
              : option.toString();

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isCorrect
                    ? AppColors.success.withOpacity(0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: isCorrect ? AppColors.success : AppColors.divider,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: isCorrect
                          ? AppColors.success.withOpacity(0.15)
                          : AppColors.divider.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: AppFontSize.sm,
                        fontWeight: FontWeight.w700,
                        color: isCorrect
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      optionText,
                      style: TextStyle(
                        fontSize: AppFontSize.md,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (isCorrect)
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.success, size: 20),
                ],
              ),
            ),
          );
        }).toList(),
      );
    } catch (e) {
      return Text(
        optionsJson,
        style: TextStyle(
          fontSize: AppFontSize.md,
          color: AppColors.textPrimary,
        ),
      );
    }
  }
}

// ============================================================
// 添加母题页面
// ============================================================

class _AddMotherQuestionScreen extends StatefulWidget {
  final int? motherQuestionId;
  final bool isVariant;
  final String? parentTitle;
  final String? initialContent;
  final Map<String, dynamic>? existingQuestion; // 用于编辑模式

  const _AddMotherQuestionScreen({
    this.motherQuestionId,
    this.isVariant = false,
    this.parentTitle,
    this.initialContent,
    this.existingQuestion,
  });

  @override
  State<_AddMotherQuestionScreen> createState() =>
      _AddMotherQuestionScreenState();
}

class _AddMotherQuestionScreenState extends State<_AddMotherQuestionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _analysisController = TextEditingController();
  final _chapterController = TextEditingController();
  final _examPointController = TextEditingController();
  List<String> _tags = [];

  // 选项控制器
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  String _selectedSubject = kSubjectNames.first;
  int _selectedDifficulty = 1;
  int _selectedCorrectAnswer = 0; // 0=A, 1=B, 2=C, 3=D
  bool _isSaving = false;
  bool _isEditing = false; // 编辑模式标记

  // 题目类型: single_choice, multi_choice, fill_blank, short_answer, true_false
  String _questionType = 'single_choice';

  // 多选题正确答案（多个）
  List<String> _multiCorrectAnswers = ['A'];
  // 判断题正确答案
  String _trueFalseCorrectAnswer = '对';

  // 填空题/简答题的答案控制器
  final TextEditingController _fillCorrectAnswerController = TextEditingController();
  final TextEditingController _shortCorrectAnswerController = TextEditingController();

  // OCR 和语音服务
  final OcrService _ocrService = OcrService();
  final VoiceService _voiceService = VoiceService();
  final AttachmentService _attachmentService = AttachmentService();
  bool _isListening = false;
  String _voiceText = '';

  // 附件
  final List<String> _imagePaths = [];
  final ImagePicker _imagePicker = ImagePicker();
  // 父记录ID（用于新附件系统）
  late String _parentId;

  @override
  void initState() {
    super.initState();

    // 设置父记录ID
    _parentId = widget.existingQuestion?['uuid'] as String? ??
        (widget.isVariant && widget.motherQuestionId != null
            ? 'mq_variant_${widget.motherQuestionId}_${DateTime.now().millisecondsSinceEpoch}'
            : 'mq_${DateTime.now().millisecondsSinceEpoch}');

    // 编辑模式：加载现有数据
    if (widget.existingQuestion != null) {
      _isEditing = true;
      final q = widget.existingQuestion!;
      _titleController.text = q['title'] as String? ?? '';
      _contentController.text = q['question_content'] as String? ?? '';
      _analysisController.text = q['analysis'] as String? ?? '';
      _chapterController.text = q['chapter'] as String? ?? '';
      _tags = (q['tags'] as String? ?? '').split(',').where((t) => t.trim().isNotEmpty).toList();
      _selectedSubject = q['subject'] as String? ?? kSubjectNames.first;
      _selectedDifficulty = q['difficulty'] as int? ?? 1;

      // 推断题目类型
      final questionType = q['question_type'] as String?;
      if (questionType != null && questionType.isNotEmpty) {
        _questionType = questionType;
      }
      final correctAnswer = q['correct_answer'] as String?;
      if (correctAnswer != null && correctAnswer.isNotEmpty) {
        if (correctAnswer.contains(',') || correctAnswer.contains('、')) {
          _questionType = 'multi_choice';
          _multiCorrectAnswers = correctAnswer.split(RegExp(r'[,、]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        } else if (correctAnswer == '对' || correctAnswer == '错' || correctAnswer == '正确' || correctAnswer == '错误') {
          _questionType = 'true_false';
          _trueFalseCorrectAnswer = (correctAnswer == '对' || correctAnswer == '正确') ? '对' : '错';
        }
      }

      // 解析选项
      final options = q['options'];
      if (options != null && options.toString().isNotEmpty) {
        try {
          final optionsList = options is String ? jsonDecode(options) : options;
          if (optionsList is List) {
            for (int i = 0; i < optionsList.length && i < _optionControllers.length; i++) {
              final opt = optionsList[i];
              if (opt is Map) {
                _optionControllers[i].text = opt['text'] as String? ?? '';
              }
              // 检查正确答案
              final label = opt['label'] as String?;
              if (label != null && opt['isCorrect'] == true) {
                _selectedCorrectAnswer = label.codeUnitAt(0) - 65; // A=0, B=1, etc.
              }
            }
          }
        } catch (_) {}
      }

      // 解析正确答案
      if (correctAnswer != null && correctAnswer.isNotEmpty && _questionType == 'single_choice') {
        _selectedCorrectAnswer = correctAnswer.codeUnitAt(0) - 65; // A=0, B=1, etc.
      }

      // 初始化填空题/简答题控制器
      if (_questionType == 'fill_blank') {
        _fillCorrectAnswerController.text = correctAnswer ?? '';
      } else if (_questionType == 'short_answer') {
        _shortCorrectAnswerController.text = correctAnswer ?? '';
      }

      // 兼容旧数据：解析附件
      final attachments = q['attachment_paths'];
      if (attachments != null && attachments.toString().isNotEmpty) {
        try {
          final paths = attachments is String ? jsonDecode(attachments) : attachments;
          if (paths is List) {
            for (final p in paths) {
              _imagePaths.add(p.toString());
            }
          }
        } catch (_) {}
      }
    } else if (widget.isVariant && widget.parentTitle != null) {
      _titleController.text = '${widget.parentTitle} - 变式题';
    } else if (widget.initialContent != null) {
      _contentController.text = widget.initialContent!;
    }
    
    _voiceService.onListeningStateChanged = () {
      if (mounted) {
        setState(() => _isListening = _voiceService.isListening);
      }
    };
    _voiceService.onFinalResult = (text) {
      if (mounted) {
        setState(() {
          _voiceText = text;
          _contentController.text =
              _contentController.text.isEmpty
                  ? text
                  : '${_contentController.text}\n$text';
        });
      }
    };
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _analysisController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    _voiceService.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() => _imagePaths.add(image.path));
        // 自动OCR识别
        _performOcr(image.path);
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '选择图片失败', isError: true);
      }
    }
  }

  Future<void> _takePhoto() async {
    // Linux平台不支持相机功能
    if (Platform.isLinux) {
      if (mounted) {
        showSnackBar(context, 'Linux平台暂不支持拍照功能，请使用相册选择', isError: true);
      }
      return;
    }
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() => _imagePaths.add(image.path));
        _performOcr(image.path);
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '拍照失败: $e', isError: true);
      }
    }
  }

  Future<void> _performOcr(String imagePath) async {
    showSnackBar(context, '正在识别文字...');
    final result = await _ocrService.recognizeImage(imagePath);
    if (result.success && result.text.isNotEmpty) {
      if (mounted) {
        setState(() {
          _contentController.text =
              _contentController.text.isEmpty
                  ? result.text
                  : '${_contentController.text}\n${result.text}';
        });
        showSnackBar(context, '文字识别成功');
      }
    } else {
      if (mounted) {
        showSnackBar(
          context,
          result.errorMessage ?? '文字识别失败',
          isError: true,
        );
      }
    }
  }

  Future<void> _startVoiceInput() async {
    if (_isListening) {
      await _voiceService.stopListening();
    } else {
      final initialized = await _voiceService.initialize();
      if (initialized) {
        await _voiceService.startListening();
        if (mounted) {
          showSnackBar(context, '请开始说话...');
        }
      } else {
        if (mounted) {
          showSnackBar(context, '语音识别初始化失败', isError: true);
        }
      }
    }
  }

  Future<void> _saveMotherQuestion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final db = DatabaseService();

      // 构建选项JSON
      final options = <Map<String, dynamic>>[];
      const labels = ['A', 'B', 'C', 'D'];
      if (_questionType == 'single_choice' || _questionType == 'multi_choice') {
        for (int i = 0; i < _optionControllers.length; i++) {
          final text = _optionControllers[i].text.trim();
          if (text.isNotEmpty) {
            options.add({
              'label': labels[i],
              'text': text,
              'isCorrect': _questionType == 'single_choice' ? i == _selectedCorrectAnswer : _multiCorrectAnswers.contains(labels[i]),
            });
          }
        }
      }

      // 根据题目类型确定正确答案
      String correctAnswer;
      switch (_questionType) {
        case 'multi_choice':
          correctAnswer = _multiCorrectAnswers.join(',');
          break;
        case 'true_false':
          correctAnswer = _trueFalseCorrectAnswer;
          break;
        case 'fill_blank':
          correctAnswer = _fillCorrectAnswerController.text.trim();
          break;
        case 'short_answer':
          correctAnswer = _shortCorrectAnswerController.text.trim();
          break;
        default:
          correctAnswer = options.isNotEmpty
              ? labels[_selectedCorrectAnswer]
              : '';
      }

      final data = {
        'uuid': _parentId,
        'title': _titleController.text.trim(),
        'question_content': _contentController.text.trim(),
        'question_type': _questionType,
        'options': options.isNotEmpty ? jsonEncode(options) : null,
        'correct_answer': correctAnswer,
        'analysis': _analysisController.text.trim(),
        'subject': _selectedSubject,
        'chapter': _chapterController.text.trim().isEmpty ? null : _chapterController.text.trim(),
        'category': '',
        'tags': _tags.isNotEmpty ? _tags.join(',') : null,
        'difficulty': _selectedDifficulty,
      };

      if (_isEditing && widget.existingQuestion != null) {
        // 编辑模式：更新现有记录
        final id = widget.existingQuestion!['id'] as int?;
        if (id != null) {
          await db.updateMotherQuestion(id, data);
        }
      } else {
        // 添加模式：插入新记录
        data['variant_count'] = 0;
        data['mastery_level'] = 0;
        data['practice_count'] = 0;
        data['is_favorite'] = 0;
        await db.insertMotherQuestion(data);

        // 如果是变式题，更新母题的变式题数量
        if (widget.isVariant && widget.motherQuestionId != null) {
          final parentQuestion =
              await db.queryMotherQuestionById(widget.motherQuestionId!);
          if (parentQuestion != null) {
            final currentVariantCount =
                parentQuestion['variant_count'] as int? ?? 0;
            await db.updateMotherQuestion(widget.motherQuestionId!, {
              'variant_count': currentVariantCount + 1,
            });
          }
        }
      }

      // 迁移旧附件到新系统（如果是编辑模式且还有旧附件）
      if (_imagePaths.isNotEmpty) {
        for (final path in _imagePaths) {
          if (await _attachmentService.fileExists(path)) {
            await _attachmentService.addAttachment(
              parentId: _parentId,
              parentType: 'mother_question',
              filePath: path,
            );
          }
        }
      }

      if (mounted) {
        showSnackBar(context, _isEditing ? '更新成功' : '保存成功');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '保存失败: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const labels = ['A', 'B', 'C', 'D'];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
            ? '编辑母题'
            : (widget.isVariant ? '添加变式题' : '添加母题')),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              AppInput(
                label: '标题',
                hintText: '输入题目标题',
                controller: _titleController,
                validator: (v) =>
                    (v == null || v.isEmpty) ? '请输入标题' : null,
              ),
              const SizedBox(height: 16),

              // 学科选择
              Text(
                '学科',
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

              // 难度选择
              Text(
                '难度',
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
                children: kDifficultyLevels.map((level) {
                  return AppTag(
                    label: level['label'] as String,
                    color: level['color'] as Color,
                    selected: _selectedDifficulty == level['value'],
                    onTap: () => setState(
                        () => _selectedDifficulty = level['value'] as int),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // 题目类型选择
              Text(
                '题目类型',
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
                  _buildQuestionTypeChip('单选题', 'single_choice', Icons.radio_button_checked),
                  _buildQuestionTypeChip('多选题', 'multi_choice', Icons.check_box_outlined),
                  _buildQuestionTypeChip('填空题', 'fill_blank', Icons.text_fields),
                  _buildQuestionTypeChip('简答题', 'short_answer', Icons.article_outlined),
                  _buildQuestionTypeChip('判断题', 'true_false', Icons.done_all),
                ],
              ),
              const SizedBox(height: 16),

              // 题目内容
              Row(
                children: [
                  Text(
                    '题目内容',
                    style: TextStyle(
                      fontSize: AppFontSize.md,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  // OCR 按钮
                  IconButton(
                    icon: const Icon(Icons.document_scanner, size: 20),
                    onPressed: _pickImage,
                    tooltip: '从图片识别',
                    color: AppColors.info,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 4),
                  // 拍照按钮（Linux平台不显示）
                  if (!Platform.isLinux)
                    IconButton(
                      icon: const Icon(Icons.camera_alt, size: 20),
                      onPressed: _takePhoto,
                      tooltip: '拍照识别',
                      color: AppColors.info,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  const SizedBox(width: 4),
                  // 语音按钮
                  IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      size: 20,
                      color: _isListening ? AppColors.error : AppColors.info,
                    ),
                    onPressed: _startVoiceInput,
                    tooltip: '语音输入',
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 特殊符号选择栏
              CompactSymbolBar(controller: _contentController),
              const SizedBox(height: 8),
              AppInput(
                hintText: '输入题目内容（支持多行文本和图片）',
                controller: _contentController,
                multiline: true,
                maxLines: 6,
                validator: (v) =>
                    (v == null || v.isEmpty) ? '请输入题目内容' : null,
              ),

              // 图片附件组件
              const SizedBox(height: 16),
              ImageAttachmentWidget(
                parentId: _parentId,
                parentType: 'mother_question',
                existingImages: _imagePaths,
                onImagesChanged: (paths) {
                  // 更新本地附件路径列表
                  _imagePaths.clear();
                  _imagePaths.addAll(paths);
                },
              ),
              const SizedBox(height: 16),

              // 根据题目类型显示不同的表单
              ..._buildQuestionTypeForm(),

              // 解析
              AppInput(
                label: '解析',
                hintText: '输入题目解析',
                controller: _analysisController,
                multiline: true,
                maxLines: 4,
              ),
              const SizedBox(height: 16),

              // 章节
              AppInput(
                label: '章节（选填）',
                hintText: '如：第三章 函数',
                controller: _chapterController,
              ),
              const SizedBox(height: 16),

              // 考点
              AppInput(
                label: '考点（选填）',
                hintText: '如：函数的单调性',
                controller: _examPointController,
              ),
              const SizedBox(height: 16),

              // 标签
              Text(
                '标签',
                style: TextStyle(
                  fontSize: AppFontSize.md,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              _buildTagsInput(),
              const SizedBox(height: 24),

              // 保存按钮
              AppButton(
                text: widget.isVariant ? '添加变式题' : '保存母题',
                icon: Icons.save,
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _saveMotherQuestion,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionTypeChip(String label, String type, IconData icon) {
    final selected = _questionType == type;
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return GestureDetector(
      onTap: () => setState(() => _questionType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: AppFontSize.sm,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildQuestionTypeForm() {
    final theme = Theme.of(context);
    switch (_questionType) {
      case 'single_choice':
        return _buildChoiceQuestionForm(theme, isMulti: false);
      case 'multi_choice':
        return _buildChoiceQuestionForm(theme, isMulti: true);
      case 'fill_blank':
        return _buildFillBlankForm(theme);
      case 'short_answer':
        return _buildShortAnswerForm(theme);
      case 'true_false':
        return _buildTrueFalseForm(theme);
      default:
        return [];
    }
  }

  List<Widget> _buildChoiceQuestionForm(ThemeData theme, {required bool isMulti}) {
    final widgets = <Widget>[];
    const labels = ['A', 'B', 'C', 'D'];

    // 选项输入
    widgets.add(Text(
      '选项',
      style: TextStyle(
        fontSize: AppFontSize.md,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    ));
    widgets.add(const SizedBox(height: 8));
    for (int index = 0; index < 4; index++) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                labels[index],
                style: TextStyle(
                  fontSize: AppFontSize.sm,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppInput(
                hintText: '选项${labels[index]}内容...',
                controller: _optionControllers[index],
              ),
            ),
          ],
        ),
      ));
    }
    widgets.add(const SizedBox(height: 16));

    // 正确答案
    widgets.add(Text(
      '正确答案',
      style: TextStyle(
        fontSize: AppFontSize.md,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    ));
    widgets.add(const SizedBox(height: 8));
    if (isMulti) {
      widgets.add(Wrap(
        spacing: 8,
        runSpacing: 8,
        children: labels.map((label) {
          final selected = _multiCorrectAnswers.contains(label);
          return FilterChip(
            label: Text(label),
            selected: selected,
            onSelected: (selected) {
              setState(() {
                if (selected) {
                  if (!_multiCorrectAnswers.contains(label)) {
                    _multiCorrectAnswers.add(label);
                    _multiCorrectAnswers.sort();
                  }
                } else {
                  _multiCorrectAnswers.remove(label);
                }
              });
            },
            selectedColor: AppColors.success.withOpacity(0.2),
            checkmarkColor: AppColors.success,
            labelStyle: TextStyle(
              color: selected ? AppColors.success : null,
              fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            ),
          );
        }).toList(),
      ));
    } else {
      widgets.add(Wrap(
        spacing: 8,
        children: labels.map((label) {
          final index = labels.indexOf(label);
          final selected = _selectedCorrectAnswer == index;
          return ChoiceChip(
            label: Text(label),
            selected: selected,
            onSelected: (_) => setState(() => _selectedCorrectAnswer = index),
            selectedColor: AppColors.success.withOpacity(0.2),
            labelStyle: TextStyle(
              color: selected ? AppColors.success : null,
              fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            ),
          );
        }).toList(),
      ));
    }
    widgets.add(const SizedBox(height: 16));

    return widgets;
  }

  List<Widget> _buildFillBlankForm(ThemeData theme) {
    return [
      Text(
        '正确答案',
        style: TextStyle(
          fontSize: AppFontSize.md,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 8),
      AppInput(
        hintText: '请输入正确答案...',
        controller: _fillCorrectAnswerController,
      ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _buildShortAnswerForm(ThemeData theme) {
    return [
      Text(
        '正确答案',
        style: TextStyle(
          fontSize: AppFontSize.md,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 8),
      AppInput(
        hintText: '请输入正确答案要点...',
        controller: _shortCorrectAnswerController,
        multiline: true,
        maxLines: 4,
      ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _buildTrueFalseForm(ThemeData theme) {
    return [
      Text(
        '正确答案',
        style: TextStyle(
          fontSize: AppFontSize.md,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: ['对', '错'].map((label) {
          final selected = _trueFalseCorrectAnswer == label;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) => setState(() => _trueFalseCorrectAnswer = label),
              selectedColor: AppColors.success.withOpacity(0.2),
              labelStyle: TextStyle(
                color: selected ? AppColors.success : null,
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 16),
    ];
  }

  Widget _buildTagsInput() {
    final _tagController = TextEditingController();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_tags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags.map((tag) {
              return Chip(
                label: Text(tag, style: const TextStyle(fontSize: 13)),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () {
                  setState(() => _tags.remove(tag));
                },
                padding: const EdgeInsets.symmetric(horizontal: 4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
        if (_tags.isNotEmpty) const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagController,
                decoration: InputDecoration(
                  hintText: '输入标签名称',
                  hintStyle: TextStyle(
                    fontSize: AppFontSize.sm,
                    color: AppColors.textHint,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: AppColors.divider),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
                style: TextStyle(fontSize: AppFontSize.sm),
                onSubmitted: (value) {
                  final trimmed = value.trim();
                  if (trimmed.isNotEmpty && !_tags.contains(trimmed)) {
                    setState(() => _tags.add(trimmed));
                    _tagController.clear();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () {
                final trimmed = _tagController.text.trim();
                if (trimmed.isNotEmpty && !_tags.contains(trimmed)) {
                  setState(() => _tags.add(trimmed));
                  _tagController.clear();
                }
              },
              color: AppColors.primary,
              constraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ],
    );
  }
}
