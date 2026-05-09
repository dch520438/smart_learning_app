import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/database_service.dart';
import '../../services/export_service.dart';
import '../../services/ocr_service.dart';
import '../../services/print_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/input_method_selector.dart';

// ============================================================
// ExamPapersScreen - 试卷管理页面
// ============================================================

class ExamPapersScreen extends StatefulWidget {
  const ExamPapersScreen({super.key});

  @override
  State<ExamPapersScreen> createState() => _ExamPapersScreenState();
}

class _ExamPapersScreenState extends State<ExamPapersScreen> {
  final DatabaseService _db = DatabaseService();
  final ExportService _exportService = ExportService();

  List<Map<String, dynamic>> _papers = [];
  List<Map<String, dynamic>> _filteredPapers = [];
  bool _isLoading = true;

  // 筛选条件
  String? _selectedSubject;
  String _searchQuery = '';

  // 多选模式
  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final rows = await _db.queryAllExamPapers();
      setState(() {
        _papers = rows;
        _applyFilters();
      });
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '加载失败: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    var result = _papers.where((paper) {
      if (_selectedSubject != null && paper['subject'] != _selectedSubject) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final name = (paper['name'] as String? ?? '').toLowerCase();
        if (!name.contains(query)) return false;
      }
      return true;
    }).toList();

    // 按考试日期倒序排列
    result.sort((a, b) {
      final dateA = a['exam_date'] as int? ?? 0;
      final dateB = b['exam_date'] as int? ?? 0;
      return dateB.compareTo(dateA);
    });

    setState(() {
      _filteredPapers = result;
    });
  }

  void _onSearch(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) _selectedIds.clear();
    });
  }

  void _toggleSelect(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      if (_selectedIds.isEmpty) _isSelectionMode = false;
    });
  }

  Future<void> _deletePaper(int id) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context: context,
      message: '确定要删除这张试卷吗？此操作不可撤销。',
    );
    if (confirmed != true) return;

    try {
      await _db.deleteExamPaper(id);
      showSnackBar(context, '已删除');
      await _loadData();
    } catch (e) {
      if (mounted) showSnackBar(context, '删除失败: $e', isError: true);
    }
  }

  Future<void> _showAddDialog() async {
    // 显示录入方式选择器
    final method = await InputMethodSelector.show(context);
    if (method == null) return;

    // 处理录入方式
    final handler = InputMethodHandler(context);
    final recognizedText = await handler.handleInputMethod(method);

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ExamPaperAddScreen(
          initialContent: recognizedText,
        ),
      ),
    );
    if (result == true) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = _isSelectionMode ? 60.0 : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('试卷管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final query = await showSearch<String>(
                context: context,
                delegate: _ExamPaperSearchDelegate(papers: _papers),
              );
              if (query != null) {
                _onSearch(query);
              }
            },
          ),
          if (!_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: _toggleSelectionMode,
              tooltip: '多选',
            ),
        ],
      ),
      body: Column(
        children: [
          // 学科筛选栏
          _buildSubjectFilterBar(theme),

          // 列表
          Expanded(
            child: _isLoading
                ? const AppLoading(message: '加载中...')
                : _filteredPapers.isEmpty
                    ? AppEmptyState(
                        message: '暂无试卷',
                        icon: Icons.assignment_outlined,
                        actionText: '添加试卷',
                        onAction: _showAddDialog,
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: EdgeInsets.only(
                            left: 16,
                            right: 16,
                            top: 8,
                            bottom: bottomPadding + 16,
                          ),
                          itemCount: _filteredPapers.length,
                          itemBuilder: (context, index) {
                            final paper = _filteredPapers[index];
                            return _buildPaperCard(paper);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: _showAddDialog,
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildSubjectFilterBar(ThemeData theme) {
    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildSubjectChip('全部', _selectedSubject == null, () {
            setState(() => _selectedSubject = null);
            _applyFilters();
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
                  _applyFilters();
                },
              ),
            );
          }),
        ],
      ),
    );
  }

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

  Widget _buildPaperCard(Map<String, dynamic> paper) {
    final theme = Theme.of(context);
    final id = paper['id'] as int;
    final name = paper['name'] as String? ?? '未命名试卷';
    final subject = paper['subject'] as String? ?? '其他';
    final examDate = paper['exam_date'] as int?;
    final totalScore = paper['total_score'] as int? ?? 0;
    final obtainedScore = paper['obtained_score'] as int?;
    final isSelected = _selectedIds.contains(id);

    return GestureDetector(
      onLongPress: () {
        if (!_isSelectionMode) {
          _toggleSelectionMode();
          _toggleSelect(id);
        }
      },
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelect(id);
        } else {
          _navigateToDetail(paper);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
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
          child: Row(
            children: [
              if (_isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleSelect(id),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: AppFontSize.md,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        AppTag(
                          label: subject,
                          color: getSubjectColor(subject),
                          dense: true,
                          fontSize: AppFontSize.xs,
                        ),
                        const SizedBox(width: 8),
                        if (examDate != null)
                          Text(
                            formatDate(DateTime.fromMillisecondsSinceEpoch(examDate)),
                            style: TextStyle(
                              fontSize: AppFontSize.xs,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '总分: $totalScore',
                          style: TextStyle(
                            fontSize: AppFontSize.sm,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (obtainedScore != null) ...[
                          const SizedBox(width: 16),
                          Text(
                            '得分: $obtainedScore',
                            style: TextStyle(
                              fontSize: AppFontSize.sm,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${((obtainedScore / totalScore) * 100).toStringAsFixed(1)}%)',
                            style: TextStyle(
                              fontSize: AppFontSize.xs,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (!_isSelectionMode)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _navigateToDetail(paper);
                        break;
                      case 'delete':
                        _deletePaper(id);
                        break;
                      case 'print':
                        _printPaper(paper);
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
                      value: 'print',
                      child: Row(
                        children: [
                          Icon(Icons.print_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('打印'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: AppColors.error),
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
      ),
    );
  }

  void _navigateToDetail(Map<String, dynamic> paper) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ExamPaperDetailScreen(paper: paper),
      ),
    );
    if (result == true) _loadData();
  }

  void _printPaper(Map<String, dynamic> paper) {
    PrintService.printExamPaper(
      context: context,
      paperName: paper['name'] as String? ?? '试卷',
      subject: paper['subject'] as String? ?? '其他',
      examDate: paper['exam_date'] != null
          ? formatDate(DateTime.fromMillisecondsSinceEpoch(paper['exam_date'] as int))
          : null,
      totalScore: paper['total_score'] as int? ?? 0,
      obtainedScore: paper['obtained_score'] as int?,
      questions: paper['questions'] as String?,
      notes: paper['notes'] as String?,
    );
  }
}

// ============================================================
// _ExamPaperSearchDelegate - 搜索代理
// ============================================================

class _ExamPaperSearchDelegate extends SearchDelegate<String> {
  final List<Map<String, dynamic>> papers;

  _ExamPaperSearchDelegate({required this.papers});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildResults();

  @override
  Widget buildSuggestions(BuildContext context) => _buildResults();

  Widget _buildResults() {
    if (query.isEmpty) {
      return Center(
        child: Text(
          '输入关键词搜索试卷',
          style: TextStyle(color: AppColors.textHint),
        ),
      );
    }

    final filtered = papers.where((paper) {
      final q = query.toLowerCase();
      final name = (paper['name'] as String? ?? '').toLowerCase();
      return name.contains(q);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          '未找到匹配的试卷',
          style: TextStyle(color: AppColors.textHint),
        ),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final paper = filtered[index];
        return ListTile(
          title: Text(paper['name'] as String? ?? '未命名'),
          subtitle: Text(paper['subject'] as String? ?? '其他'),
          onTap: () => close(context, query),
        );
      },
    );
  }
}

// ============================================================
// _ExamPaperAddScreen - 添加/编辑试卷页面
// ============================================================

class _ExamPaperAddScreen extends StatefulWidget {
  final Map<String, dynamic>? paper;
  final String? initialContent;

  const _ExamPaperAddScreen({this.paper, this.initialContent});

  @override
  State<_ExamPaperAddScreen> createState() => _ExamPaperAddScreenState();
}

class _ExamPaperAddScreenState extends State<_ExamPaperAddScreen> {
  final DatabaseService _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _totalScoreController = TextEditingController();
  final _obtainedScoreController = TextEditingController();
  final _notesController = TextEditingController();

  String _subject = '数学';
  DateTime? _examDate;

  @override
  void initState() {
    super.initState();
    if (widget.paper != null) {
      _nameController.text = widget.paper!['name'] as String? ?? '';
      _totalScoreController.text = (widget.paper!['total_score'] as int?)?.toString() ?? '';
      _obtainedScoreController.text = (widget.paper!['obtained_score'] as int?)?.toString() ?? '';
      _notesController.text = widget.paper!['notes'] as String? ?? '';
      _subject = widget.paper!['subject'] as String? ?? '数学';
      final examDate = widget.paper!['exam_date'] as int?;
      if (examDate != null) {
        _examDate = DateTime.fromMillisecondsSinceEpoch(examDate);
      }
    } else if (widget.initialContent != null) {
      // 如果是通过OCR或语音录入的内容，尝试解析
      _notesController.text = widget.initialContent!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _totalScoreController.dispose();
    _obtainedScoreController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _examDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _examDate = picked);
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      showSnackBar(context, '请输入试卷名称', isError: true);
      return;
    }

    final totalScore = int.tryParse(_totalScoreController.text) ?? 0;
    final obtainedScore = _obtainedScoreController.text.isEmpty
        ? null
        : int.tryParse(_obtainedScoreController.text);

    final data = <String, dynamic>{
      'name': _nameController.text.trim(),
      'subject': _subject,
      'exam_date': _examDate?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
      'total_score': totalScore,
      'obtained_score': obtainedScore,
      'notes': _notesController.text.trim(),
    };

    try {
      if (widget.paper != null) {
        await _db.updateExamPaper(widget.paper!['id'] as int, data);
      } else {
        await _db.insertExamPaper(data);
      }

      if (mounted) {
        showSnackBar(context, widget.paper != null ? '已更新' : '已添加');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) showSnackBar(context, '保存失败: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.paper != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '编辑试卷' : '添加试卷'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 试卷名称
              AppInput(
                label: '试卷名称',
                hintText: '如：2024年期中考试',
                controller: _nameController,
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
                children: kSubjectNames.map((s) {
                  final selected = _subject == s;
                  return AppTag(
                    label: s,
                    color: getSubjectColor(s),
                    selected: selected,
                    onTap: () => setState(() => _subject = s),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // 考试日期
              Text(
                '考试日期',
                style: TextStyle(
                  fontSize: AppFontSize.md,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.divider),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 20, color: AppColors.textSecondary),
                      const SizedBox(width: 12),
                      Text(
                        _examDate != null
                            ? formatDate(_examDate!)
                            : '选择日期',
                        style: TextStyle(
                          fontSize: AppFontSize.md,
                          color: _examDate != null ? AppColors.textPrimary : AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 分数
              Row(
                children: [
                  Expanded(
                    child: AppInput(
                      label: '总分',
                      hintText: '如：100',
                      controller: _totalScoreController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AppInput(
                      label: '得分（可选）',
                      hintText: '如：85',
                      controller: _obtainedScoreController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 备注
              AppInput(
                label: '备注',
                hintText: '输入试卷备注、错题分析等...',
                controller: _notesController,
                multiline: true,
                maxLines: 6,
              ),

              const SizedBox(height: 24),

              // 保存按钮
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  text: isEdit ? '保存修改' : '添加试卷',
                  style: AppButtonStyle.primary,
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// _ExamPaperDetailScreen - 试卷详情页面
// ============================================================

class _ExamPaperDetailScreen extends StatefulWidget {
  final Map<String, dynamic> paper;

  const _ExamPaperDetailScreen({required this.paper});

  @override
  State<_ExamPaperDetailScreen> createState() => _ExamPaperDetailScreenState();
}

class _ExamPaperDetailScreenState extends State<_ExamPaperDetailScreen> {
  late Map<String, dynamic> _paper;

  @override
  void initState() {
    super.initState();
    _paper = widget.paper;
  }

  Future<void> _loadPaper() async {
    try {
      final fresh = await DatabaseService().queryExamPaperById(_paper['id'] as int);
      if (fresh != null && mounted) {
        setState(() => _paper = fresh);
      }
    } catch (e) {
      // 忽略错误
    }
  }

  Future<void> _editPaper() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ExamPaperAddScreen(paper: _paper),
      ),
    );
    if (result == true) {
      await _loadPaper();
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = _paper['name'] as String? ?? '未命名试卷';
    final subject = _paper['subject'] as String? ?? '其他';
    final examDate = _paper['exam_date'] as int?;
    final totalScore = _paper['total_score'] as int? ?? 0;
    final obtainedScore = _paper['obtained_score'] as int?;
    final notes = _paper['notes'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('试卷详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _editPaper,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Text(
              name,
              style: TextStyle(
                fontSize: AppFontSize.xxl,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // 信息卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInfoRow('学科', subject),
                    const Divider(),
                    _buildInfoRow(
                      '考试日期',
                      examDate != null
                          ? formatDate(DateTime.fromMillisecondsSinceEpoch(examDate))
                          : '未设置',
                    ),
                    const Divider(),
                    _buildInfoRow('总分', '$totalScore'),
                    if (obtainedScore != null) ...[
                      const Divider(),
                      _buildInfoRow('得分', '$obtainedScore'),
                      const Divider(),
                      _buildInfoRow(
                        '得分率',
                        '${((obtainedScore / totalScore) * 100).toStringAsFixed(1)}%',
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 备注
            if (notes.isNotEmpty) ...[
              Text(
                '备注',
                style: TextStyle(
                  fontSize: AppFontSize.md,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Text(
                  notes,
                  style: TextStyle(
                    fontSize: AppFontSize.md,
                    color: AppColors.textPrimary,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: AppFontSize.md,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: AppFontSize.md,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
