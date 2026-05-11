import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/wrong_question.dart';
import '../../services/database_service.dart';
import '../../services/export_service.dart';
import '../../services/ocr_service.dart';
import '../../services/print_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/question_widgets.dart';
import '../../widgets/exam_method_keypoint_input.dart';
import '../../widgets/input_method_selector.dart';
import '../../widgets/symbol_picker.dart';

// ============================================================
// WrongQuestionsScreen - 错题本主页面
// ============================================================

class WrongQuestionsScreen extends StatefulWidget {
  final String? initialFilterTag;

  const WrongQuestionsScreen({super.key, this.initialFilterTag});

  @override
  State<WrongQuestionsScreen> createState() => _WrongQuestionsScreenState();
}

class _WrongQuestionsScreenState extends State<WrongQuestionsScreen> {
  final DatabaseService _db = DatabaseService();
  final ExportService _exportService = ExportService();
  final OcrService _ocrService = OcrService();

  List<WrongQuestion> _questions = [];
  List<WrongQuestion> _filteredQuestions = [];
  bool _isLoading = true;

  // 筛选条件
  String? _filterSubject;
  String? _filterErrorType;
  bool? _filterResolved;
  String? _filterTag;
  String _searchQuery = '';

  // 多选模式
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  // 统计信息
  int _totalCount = 0;
  int _resolvedCount = 0;
  final Map<String, int> _subjectDistribution = {};

  @override
  void initState() {
    super.initState();
    _filterTag = widget.initialFilterTag;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final rows = await _db.queryAllWrongQuestions();
      final questions = rows.map((r) => _rowToWrongQuestion(r)).toList();
      _questions = questions;
      _applyFilters();
      _computeStats();
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '加载失败: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  WrongQuestion _rowToWrongQuestion(Map<String, dynamic> r) {
    List<Map<String, dynamic>> options = [];
    if (r['options'] != null) {
      if (r['options'] is String) {
        options = (jsonDecode(r['options']) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else if (r['options'] is List) {
        options = (r['options'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    }
    List<Map<String, dynamic>> attachments = [];
    if (r['attachment_paths'] != null) {
      if (r['attachment_paths'] is String) {
        final decoded = jsonDecode(r['attachment_paths']);
        if (decoded is List) {
          attachments = decoded
              .map((e) => {'path': e.toString()})
              .toList();
        }
      } else if (r['attachment_paths'] is List) {
        attachments = (r['attachment_paths'] as List)
            .map((e) => {'path': e.toString()})
            .toList();
      }
    }
    return WrongQuestion(
      id: r['uuid'] as String? ?? r['id'].toString(),
      title: r['question_content'] as String? ?? '',
      content: r['question_content'] as String? ?? '',
      options: options,
      correctAnswer: r['correct_answer'] as String? ?? '',
      userAnswer: r['my_answer'] as String?,
      analysis: r['analysis'] as String? ?? '',
      subject: r['subject'] as String? ?? '其他',
      chapter: null,
      errorType: _mapErrorType(r),
      errorCount: r['error_count'] as int? ?? 1,
      isResolved: (r['is_mastered'] as int?) == 1,
      createdAt: r['created_at'] != null
          ? DateTime.tryParse(r['created_at'] as String)
                  ?.millisecondsSinceEpoch ??
              DateTime.now().millisecondsSinceEpoch
          : DateTime.now().millisecondsSinceEpoch,
      updatedAt: r['updated_at'] != null
          ? DateTime.tryParse(r['updated_at'] as String)
                  ?.millisecondsSinceEpoch ??
              DateTime.now().millisecondsSinceEpoch
          : DateTime.now().millisecondsSinceEpoch,
      attachments: attachments,
      tags: (r['tags'] as String? ?? '').split(',').where((t) => t.trim().isNotEmpty).toList(),
    );
  }

  String _mapErrorType(Map<String, dynamic> r) {
    // 从数据库行推断错误类型
    final errorCount = r['error_count'] as int? ?? 1;
    if (errorCount <= 1) return '粗心';
    if (errorCount <= 2) return '知识盲区';
    return '方法错误';
  }

  void _computeStats() {
    _totalCount = _questions.length;
    _resolvedCount = _questions.where((q) => q.isResolved).length;
    _subjectDistribution.clear();
    for (final q in _questions) {
      _subjectDistribution[q.subject] =
          (_subjectDistribution[q.subject] ?? 0) + 1;
    }
  }

  void _applyFilters() {
    var result = _questions.where((q) {
      if (_filterSubject != null && q.subject != _filterSubject) return false;
      if (_filterErrorType != null && q.errorType != _filterErrorType) {
        return false;
      }
      if (_filterResolved != null && q.isResolved != _filterResolved) {
        return false;
      }
      if (_filterTag != null) {
        final tag = _filterTag!.toLowerCase();
        if (!q.subject.toLowerCase().contains(tag) &&
            !q.errorType.toLowerCase().contains(tag)) {
          return false;
        }
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!q.title.toLowerCase().contains(query) &&
            !q.content.toLowerCase().contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();
    setState(() {
      _filteredQuestions = result;
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

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      if (_selectedIds.isEmpty) _isSelectionMode = false;
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _filteredQuestions.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
            .addAll(_filteredQuestions.map((q) => q.id));
      }
    });
  }

  Future<void> _batchDelete() async {
    final confirmed = await ConfirmDeleteDialog.show(
      context: context,
      title: '批量删除',
      message: '确定要删除选中的 ${_selectedIds.length} 道错题吗？此操作不可撤销。',
    );
    if (confirmed != true) return;

    try {
      for (final q in _filteredQuestions) {
        if (_selectedIds.contains(q.id)) {
          final row = await _db.queryWrongQuestionByUuid(q.id);
          if (row != null) {
            await _db.deleteWrongQuestion(row['id'] as int);
          }
        }
      }
      showSnackBar(context, '已删除 ${_selectedIds.length} 道错题');
      _selectedIds.clear();
      _isSelectionMode = false;
      await _loadData();
    } catch (e) {
      if (mounted) showSnackBar(context, '删除失败: $e', isError: true);
    }
  }

  Future<void> _batchMarkResolved() async {
    try {
      for (final q in _filteredQuestions) {
        if (_selectedIds.contains(q.id)) {
          final row = await _db.queryWrongQuestionByUuid(q.id);
          if (row != null) {
            await _db.updateWrongQuestion(row['id'] as int, {
              'is_mastered': 1,
              'last_correct_time': DateTime.now().toIso8601String(),
            });
          }
        }
      }
      showSnackBar(context, '已标记 ${_selectedIds.length} 道为已解决');
      _selectedIds.clear();
      _isSelectionMode = false;
      await _loadData();
    } catch (e) {
      if (mounted) showSnackBar(context, '操作失败: $e', isError: true);
    }
  }

  Future<void> _batchExport() async {
    if (_selectedIds.isEmpty) return;
    try {
      AppLoading.show(context, message: '正在导出...');

      // 获取选中的错题数据
      final selectedQuestions = _questions.where((q) {
        return _selectedIds.contains(q.id);
      }).toList();

      // 构建导出数据
      final exportData = {
        'export_version': '1.0',
        'export_time': DateTime.now().toIso8601String(),
        'wrong_questions': selectedQuestions.map((q) => q.toJson()).toList(),
      };

      // 保存到文件
      final result = await _exportService.exportAllToJson(
        fileName: 'wrong_questions_export_${DateTime.now().millisecondsSinceEpoch}.json',
      );

      AppLoading.hide(context);
      setState(() {
        _isSelectionMode = false;
        _selectedIds.clear();
      });

      if (result.success && mounted) {
        showSnackBar(context, '已导出 ${_selectedIds.length} 道错题到 ${result.fileName}');
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

    // 获取选中的错题数据
    final selectedQuestions = _questions.where((q) {
      return _selectedIds.contains(q.id);
    }).toList();

    // 转换为打印内容项
    final printItems = selectedQuestions.map((q) {
      // 构建错题内容
      final buffer = StringBuffer();
      buffer.writeln('【题目】');
      buffer.writeln(q.content);
      buffer.writeln();
      if (q.options.isNotEmpty) {
        buffer.writeln('【选项】');
        for (int i = 0; i < q.options.length; i++) {
          final option = q.options[i];
          final label = option['label'] ?? String.fromCharCode(65 + i);
          final text = option['text'] ?? '';
          buffer.writeln('$label. $text');
        }
        buffer.writeln();
      }
      if (q.correctAnswer.isNotEmpty) {
        buffer.writeln('【正确答案】');
        buffer.writeln(q.correctAnswer);
        buffer.writeln();
      }
      if (q.userAnswer != null && q.userAnswer!.isNotEmpty) {
        buffer.writeln('【我的答案】');
        buffer.writeln(q.userAnswer);
        buffer.writeln();
      }
      if (q.analysis.isNotEmpty) {
        buffer.writeln('【解析】');
        buffer.writeln(q.analysis);
      }

      return PrintContentItem(
        type: PrintContentType.wrongQuestion,
        title: q.title.isNotEmpty ? q.title : '错题详情',
        content: buffer.toString(),
        subject: q.subject,
        additionalMetadata: {
          '错误类型': q.errorType,
          '状态': q.isResolved ? '已掌握' : '未掌握',
          '错误次数': '${q.errorCount}次',
        },
      );
    }).toList();

    // 调用批量打印
    await PrintService.printBatch(
      context: context,
      items: printItems,
      customTitle: '错题打印 (${printItems.length}项)',
    );

    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = _isSelectionMode ? 60.0 : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('错题本'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final query = await showSearch<String>(
                context: context,
                delegate: _WrongQuestionSearchDelegate(
                  questions: _questions,
                ),
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
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'unresolved') {
                setState(() => _filterResolved = false);
              } else if (value == 'resolved') {
                setState(() => _filterResolved = true);
              } else if (value == 'all') {
                setState(() {
                  _filterResolved = null;
                  _filterSubject = null;
                  _filterErrorType = null;
                  _searchQuery = '';
                });
              }
              _applyFilters();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Text('显示全部'),
              ),
              const PopupMenuItem(
                value: 'unresolved',
                child: Text('未解决'),
              ),
              const PopupMenuItem(
                value: 'resolved',
                child: Text('已解决'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 统计信息栏
          _buildStatsBar(theme),
          // 学科筛选栏
          _buildSubjectFilterBar(theme),
          // 筛选栏
          _buildFilterBar(theme),
          // 列表
          Expanded(
            child: _isLoading
                ? const AppLoading(message: '加载中...')
                : _filteredQuestions.isEmpty
                    ? AppEmptyState(
                        message: '暂无错题',
                        icon: Icons.check_circle_outline,
                        actionText: '添加错题',
                        onAction: () => _showAddDialog(),
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
                          itemCount: _filteredQuestions.length,
                          itemBuilder: (context, index) {
                            final q = _filteredQuestions[index];
                            return _buildQuestionCard(q, index);
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
              onDelete: _batchDelete,
              onExport: _batchExport,
              onPrint: _batchPrint,
              onCancel: () {
                setState(() {
                  _isSelectionMode = false;
                  _selectedIds.clear();
                });
              },
            )
          : null,
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: () => _showAddDialog(),
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildStatsBar(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.error.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          _buildStatItem('总错题', _totalCount, AppColors.error),
          Container(
            width: 1,
            height: 32,
            color: AppColors.divider,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          _buildStatItem('已解决', _resolvedCount, AppColors.success),
          Container(
            width: 1,
            height: 32,
            color: AppColors.divider,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          _buildStatItem('待复习', _totalCount - _resolvedCount, AppColors.warning),
          const Spacer(),
          // 学科分布小标签
          if (_subjectDistribution.isNotEmpty)
            SizedBox(
              height: 24,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _subjectDistribution.length > 4
                    ? 4
                    : _subjectDistribution.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final entry =
                      _subjectDistribution.entries.elementAt(index);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: getSubjectColor(entry.key).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${entry.key} ${entry.value}',
                      style: TextStyle(
                        fontSize: AppFontSize.xs,
                        color: getSubjectColor(entry.key),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: AppFontSize.xl,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: AppFontSize.xs,
            color: AppColors.textSecondary,
          ),
        ),
      ],
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
          // 全部选项
          _buildSubjectChip('全部', _filterSubject == null, () {
            setState(() => _filterSubject = null);
            _applyFilters();
          }),
          const SizedBox(width: 8),
          // 各学科选项
          ...kSubjectNames.map((subject) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildSubjectChip(
                subject,
                _filterSubject == subject,
                () {
                  setState(() => _filterSubject = subject);
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

  Widget _buildFilterBar(ThemeData theme) {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // 错误类型筛选
          _buildFilterChip('粗心', _filterErrorType == '粗心', () {
            setState(() => _filterErrorType = '粗心');
            _applyFilters();
          }),
          _buildFilterChip('知识盲区', _filterErrorType == '知识盲区', () {
            setState(() => _filterErrorType = '知识盲区');
            _applyFilters();
          }),
          _buildFilterChip('方法错误', _filterErrorType == '方法错误', () {
            setState(() => _filterErrorType = '方法错误');
            _applyFilters();
          }),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppFontSize.sm,
            color: selected
                ? theme.colorScheme.onPrimary
                : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(WrongQuestion q, int index) {
    final theme = Theme.of(context);
    final isSelected = _selectedIds.contains(q.id);

    return GestureDetector(
      onLongPress: () {
        if (!_isSelectionMode) {
          _toggleSelectionMode();
          _toggleSelect(q.id);
        }
      },
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelect(q.id);
        } else {
          _navigateToDetail(q);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: q.isResolved
              ? AppColors.success.withOpacity(0.04)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : q.isResolved
                    ? AppColors.success.withOpacity(0.3)
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 多选复选框
              if (_isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 10, top: 2),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleSelect(q.id),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              // 内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题行
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _filterSubject = q.subject;
                              _applyFilters();
                            });
                          },
                          child: AppTag(
                            label: q.subject,
                            color: getSubjectColor(q.subject),
                            dense: true,
                            fontSize: AppFontSize.xs,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _filterErrorType = q.errorType;
                              _applyFilters();
                            });
                          },
                          child: AppTag(
                            label: q.errorType,
                            color: _getErrorTypeColor(q.errorType),
                            dense: true,
                            fontSize: AppFontSize.xs,
                          ),
                        ),
                        const Spacer(),
                        if (q.isResolved)
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: AppColors.success,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 题目标题
                    Text(
                      q.title.isNotEmpty ? q.title : q.content,
                      style: TextStyle(
                        fontSize: AppFontSize.md,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // 底部信息
                    Row(
                      children: [
                        Icon(
                          Icons.repeat,
                          size: 14,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '错${q.errorCount}次',
                          style: TextStyle(
                            fontSize: AppFontSize.xs,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formatFriendlyTime(
                            DateTime.fromMillisecondsSinceEpoch(q.updatedAt),
                          ),
                          style: TextStyle(
                            fontSize: AppFontSize.xs,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getErrorTypeColor(String errorType) {
    switch (errorType) {
      case '粗心大意':
        return AppColors.warning;
      case '知识盲区':
        return AppColors.error;
      case '方法错误':
        return AppColors.info;
      case '审题不清':
        return Colors.orange;
      case '时间不够':
        return Colors.purple;
      default:
        return AppColors.textSecondary;
    }
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
    widgets.add(_buildSectionTitle('选项'));
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
    widgets.add(_buildSectionTitle('正确答案'));
    widgets.add(const SizedBox(height: 8));
    if (isMulti) {
      // 多选正确答案
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
      // 单选正确答案
      widgets.add(Row(
        children: labels.map((label) {
          final selected = _correctAnswer == label;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) => setState(() => _correctAnswer = label),
              selectedColor: AppColors.success.withOpacity(0.2),
              labelStyle: TextStyle(
                color: selected ? AppColors.success : null,
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ));
    }
    widgets.add(const SizedBox(height: 16));

    // 我的答案
    widgets.add(_buildSectionTitle('我的答案'));
    widgets.add(const SizedBox(height: 8));
    if (isMulti) {
      widgets.add(Wrap(
        spacing: 8,
        runSpacing: 8,
        children: labels.map((label) {
          final selected = _multiUserAnswers.contains(label);
          return FilterChip(
            label: Text(label),
            selected: selected,
            onSelected: (selected) {
              setState(() {
                if (selected) {
                  if (!_multiUserAnswers.contains(label)) {
                    _multiUserAnswers.add(label);
                    _multiUserAnswers.sort();
                  }
                } else {
                  _multiUserAnswers.remove(label);
                }
              });
            },
            selectedColor: AppColors.error.withOpacity(0.2),
            checkmarkColor: AppColors.error,
            labelStyle: TextStyle(
              color: selected ? AppColors.error : null,
              fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            ),
          );
        }).toList(),
      ));
    } else {
      widgets.add(Row(
        children: labels.map((label) {
          final selected = _userAnswer == label;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) => setState(() => _userAnswer = label),
              selectedColor: AppColors.error.withOpacity(0.2),
              labelStyle: TextStyle(
                color: selected ? AppColors.error : null,
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              ),
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
      _buildSectionTitle('正确答案'),
      const SizedBox(height: 8),
      AppInput(
        hintText: '请输入正确答案...',
        controller: _fillCorrectAnswerController,
      ),
      const SizedBox(height: 16),
      _buildSectionTitle('我的答案'),
      const SizedBox(height: 8),
      AppInput(
        hintText: '请输入我的答案...',
        controller: _fillUserAnswerController,
      ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _buildShortAnswerForm(ThemeData theme) {
    return [
      _buildSectionTitle('正确答案'),
      const SizedBox(height: 8),
      AppInput(
        hintText: '请输入正确答案要点...',
        controller: _shortCorrectAnswerController,
        multiline: true,
        maxLines: 4,
      ),
      const SizedBox(height: 16),
      _buildSectionTitle('我的答案'),
      const SizedBox(height: 8),
      AppInput(
        hintText: '请输入我的答案...',
        controller: _shortUserAnswerController,
        multiline: true,
        maxLines: 4,
      ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _buildTrueFalseForm(ThemeData theme) {
    return [
      _buildSectionTitle('正确答案'),
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
      _buildSectionTitle('我的答案'),
      const SizedBox(height: 8),
      Row(
        children: ['对', '错'].map((label) {
          final selected = _trueFalseUserAnswer == label;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) => setState(() => _trueFalseUserAnswer = label),
              selectedColor: AppColors.error.withOpacity(0.2),
              labelStyle: TextStyle(
                color: selected ? AppColors.error : null,
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 16),
    ];
  }

  void _navigateToDetail(WrongQuestion q) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WrongQuestionDetailScreen(
          question: q,
          onUpdated: () => _loadData(),
          onDeleted: () => _loadData(),
        ),
      ),
    );
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
        builder: (_) => WrongQuestionAddScreen(
          initialContent: recognizedText,
        ),
      ),
    );
    if (result == true) _loadData();
  }
}

// ============================================================
// WrongQuestionSearchDelegate - 搜索代理
// ============================================================

class _WrongQuestionSearchDelegate extends SearchDelegate<String> {
  final List<WrongQuestion> questions;

  _WrongQuestionSearchDelegate({required this.questions});

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
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final filtered = questions.where((q) {
      final qLower = query.toLowerCase();
      return q.title.toLowerCase().contains(qLower) ||
          q.content.toLowerCase().contains(qLower);
    }).toList();

    if (query.isEmpty) {
      return Center(
        child: Text(
          '输入关键词搜索错题',
          style: TextStyle(color: AppColors.textHint),
        ),
      );
    }

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          '未找到匹配的错题',
          style: TextStyle(color: AppColors.textHint),
        ),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final q = filtered[index];
        return ListTile(
          title: Text(
            q.title.isNotEmpty ? q.title : q.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text('${q.subject} - ${q.errorType}'),
          onTap: () => close(context, query),
        );
      },
    );
  }
}

// ============================================================
// WrongQuestionDetailScreen - 错题详情页
// ============================================================

class WrongQuestionDetailScreen extends StatefulWidget {
  final WrongQuestion question;
  final VoidCallback? onUpdated;
  final VoidCallback? onDeleted;

  const WrongQuestionDetailScreen({
    super.key,
    required this.question,
    this.onUpdated,
    this.onDeleted,
  });

  @override
  State<WrongQuestionDetailScreen> createState() =>
      _WrongQuestionDetailScreenState();
}

class _WrongQuestionDetailScreenState extends State<WrongQuestionDetailScreen> {
  late WrongQuestion _question;
  final DatabaseService _db = DatabaseService();

  @override
  void initState() {
    super.initState();
    _question = widget.question;
  }

  Future<void> _toggleResolved() async {
    try {
      final row = await _db.queryWrongQuestionByUuid(_question.id);
      if (row != null) {
        final newResolved = !_question.isResolved;
        await _db.updateWrongQuestion(row['id'] as int, {
          'is_mastered': newResolved ? 1 : 0,
          if (newResolved)
            'last_correct_time': DateTime.now().toIso8601String(),
        });
        setState(() {
          _question = _question.copyWith(
            isResolved: newResolved,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          );
        });
        widget.onUpdated?.call();
        showSnackBar(
          context,
          newResolved ? '已标记为已解决' : '已标记为未解决',
        );
      }
    } catch (e) {
      if (mounted) showSnackBar(context, '操作失败: $e', isError: true);
    }
  }

  Future<void> _deleteQuestion() async {
    final confirmed = await ConfirmDeleteDialog.show(
      context: context,
      message: '确定要删除这道错题吗？此操作不可撤销。',
    );
    if (confirmed != true) return;

    try {
      final row = await _db.queryWrongQuestionByUuid(_question.id);
      if (row != null) {
        await _db.deleteWrongQuestion(row['id'] as int);
      }
      widget.onDeleted?.call();
      if (mounted) Navigator.of(context).pop();
      showSnackBar(context, '已删除');
    } catch (e) {
      if (mounted) showSnackBar(context, '删除失败: $e', isError: true);
    }
  }

  void _editQuestion() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WrongQuestionAddScreen(question: _question),
      ),
    );
    if (result == true) {
      widget.onUpdated?.call();
      Navigator.of(context).pop();
    }
  }

  void _redoQuestion() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _WrongQuestionRedoScreen(question: _question),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final optionLabels = ['A', 'B', 'C', 'D', 'E', 'F'];

    return Scaffold(
      appBar: AppBar(
        title: Text(_question.isResolved ? '错题详情 (已解决)' : '错题详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            onPressed: () => PrintService.printWrongQuestion(
              context: context,
              question: _question.content,
              options: _question.options.isNotEmpty
                  ? _question.options.asMap().entries.map((e) => '${['A', 'B', 'C', 'D', 'E', 'F'][e.key]}. ${e.value}').join('\n')
                  : null,
              correctAnswer: _question.correctAnswer,
              myAnswer: _question.userAnswer,
              analysis: _question.analysis,
              subject: _question.subject,
              errorType: _question.errorType,
              isMastered: _question.isResolved,
              createdAt: formatDate(DateTime.fromMillisecondsSinceEpoch(_question.createdAt)),
            ),
            tooltip: '打印',
          ),
          IconButton(
            icon: Icon(
              _question.isResolved
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: _question.isResolved ? AppColors.success : null,
            ),
            onPressed: _toggleResolved,
            tooltip: _question.isResolved ? '标记为未解决' : '标记为已解决',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标签行
            Row(
              children: [
                AppTag(
                  label: _question.subject,
                  color: getSubjectColor(_question.subject),
                ),
                const SizedBox(width: 8),
                AppTag(
                  label: _question.errorType,
                  color: _getErrorTypeColor(_question.errorType),
                ),
                const SizedBox(width: 8),
                AppTag(
                  label: '错${_question.errorCount}次',
                  color: AppColors.error,
                ),
                if (_question.chapter != null &&
                    _question.chapter!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  AppTag(
                    label: _question.chapter!,
                    color: AppColors.textSecondary,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // 题目内容
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '题目',
                    style: TextStyle(
                      fontSize: AppFontSize.sm,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _question.content,
                    style: TextStyle(
                      fontSize: AppFontSize.lg,
                      color: AppColors.textPrimary,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),

            // 选项（如果有）
            if (_question.options.isNotEmpty) ...[
              const SizedBox(height: 12),
              ..._question.options.asMap().entries.map((entry) {
                final idx = entry.key;
                final opt = entry.value;
                final label = idx < optionLabels.length ? optionLabels[idx] : '${idx + 1}';
                final optText = opt['text'] as String? ?? opt['content'] as String? ?? '';
                final isCorrect = _question.correctAnswer == label;
                final isUserAnswer = _question.userAnswer == label;

                return QuestionOption(
                  label: label,
                  text: optText,
                  isSelected: isUserAnswer,
                  isCorrect: isCorrect,
                  showResult: true,
                  enabled: false,
                );
              }),
            ],

            // 答案对比
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.05),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.error.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.close, color: AppColors.error, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '我的答案',
                        style: TextStyle(
                          fontSize: AppFontSize.sm,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _question.userAnswer ?? '未作答',
                    style: TextStyle(
                      fontSize: AppFontSize.lg,
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.05),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.success.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check, color: AppColors.success, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '正确答案',
                        style: TextStyle(
                          fontSize: AppFontSize.sm,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _question.correctAnswer,
                    style: TextStyle(
                      fontSize: AppFontSize.lg,
                      color: AppColors.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // 解析
            if (_question.analysis.isNotEmpty) ...[
              const SizedBox(height: 16),
              QuestionAnalysis(
                analysis: _question.analysis,
                correctAnswer: _question.correctAnswer,
                userAnswer: _question.userAnswer,
              ),
            ],

            // 附件图片
            if (_question.attachments.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '附件图片',
                style: TextStyle(
                  fontSize: AppFontSize.md,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _question.attachments.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final att = _question.attachments[index];
                    final path = att['path'] as String? ?? '';
                    return ClipRRect(
                      borderRadius:
                          BorderRadius.circular(AppRadius.md),
                      child: path.isNotEmpty
                          ? Image.asset(
                              path,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 120,
                                height: 120,
                                color: AppColors.divider,
                                child: const Icon(Icons.broken_image),
                              ),
                            )
                          : Container(
                              width: 120,
                              height: 120,
                              color: AppColors.divider,
                              child: const Icon(Icons.image),
                            ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 24),

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: '重新做',
                    icon: Icons.refresh,
                    style: AppButtonStyle.outlined,
                    onPressed: _redoQuestion,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    text: _question.isResolved ? '取消解决' : '标记已解决',
                    icon: _question.isResolved
                        ? Icons.radio_button_unchecked
                        : Icons.check_circle,
                    style: AppButtonStyle.primary,
                    onPressed: _toggleResolved,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: '编辑错题',
                icon: Icons.edit_outlined,
                style: AppButtonStyle.secondary,
                onPressed: _editQuestion,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getErrorTypeColor(String errorType) {
    switch (errorType) {
      case '粗心':
        return AppColors.warning;
      case '知识盲区':
        return AppColors.error;
      case '方法错误':
        return AppColors.info;
      default:
        return AppColors.textSecondary;
    }
  }
}

// ============================================================
// _WrongQuestionRedoScreen - 重新做题页面
// ============================================================

class _WrongQuestionRedoScreen extends StatefulWidget {
  final WrongQuestion question;

  const _WrongQuestionRedoScreen({required this.question});

  @override
  State<_WrongQuestionRedoScreen> createState() =>
      _WrongQuestionRedoScreenState();
}

class _WrongQuestionRedoScreenState extends State<_WrongQuestionRedoScreen> {
  String? _selectedAnswer;
  bool _showResult = false;
  final DatabaseService _db = DatabaseService();
  static const _optionLabels = ['A', 'B', 'C', 'D', 'E', 'F'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = widget.question;

    return Scaffold(
      appBar: AppBar(
        title: const Text('重新做题'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 题目
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Text(
                q.content,
                style: TextStyle(
                  fontSize: AppFontSize.lg,
                  color: AppColors.textPrimary,
                  height: 1.6,
                ),
              ),
            ),

            // 选项
            if (q.options.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...q.options.asMap().entries.map((entry) {
                final idx = entry.key;
                final opt = entry.value;
                final label = idx < _optionLabels.length
                    ? _optionLabels[idx]
                    : '${idx + 1}';
                final optText =
                    opt['text'] as String? ?? opt['content'] as String? ?? '';

                return QuestionOption(
                  label: label,
                  text: optText,
                  isSelected: _selectedAnswer == label,
                  isCorrect: q.correctAnswer == label,
                  showResult: _showResult,
                  enabled: !_showResult,
                  onTap: (_) {
                    setState(() => _selectedAnswer = label);
                  },
                );
              }),
            ] else ...[
              const SizedBox(height: 16),
              AppInput(
                hintText: '请输入你的答案...',
                onChanged: (v) => _selectedAnswer = v,
                enabled: !_showResult,
              ),
            ],

            // 提交/查看结果按钮
            const SizedBox(height: 24),
            if (!_showResult)
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  text: '提交答案',
                  style: AppButtonStyle.primary,
                  enabled: _selectedAnswer != null &&
                      _selectedAnswer!.isNotEmpty,
                  onPressed: () {
                    setState(() => _showResult = true);
                  },
                ),
              ),

            // 结果
            if (_showResult) ...[
              const SizedBox(height: 16),
              QuestionAnalysis(
                analysis: q.analysis,
                correctAnswer: q.correctAnswer,
                userAnswer: _selectedAnswer,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: '再做一次',
                      style: AppButtonStyle.outlined,
                      onPressed: () {
                        setState(() {
                          _selectedAnswer = null;
                          _showResult = false;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      text: '返回',
                      style: AppButtonStyle.primary,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// WrongQuestionAddScreen - 添加/编辑错题页面
// ============================================================

class WrongQuestionAddScreen extends StatefulWidget {
  final WrongQuestion? question;
  final String? initialContent;

  const WrongQuestionAddScreen({super.key, this.question, this.initialContent});

  @override
  State<WrongQuestionAddScreen> createState() =>
      _WrongQuestionAddScreenState();
}

class _WrongQuestionAddScreenState extends State<WrongQuestionAddScreen> {
  final DatabaseService _db = DatabaseService();
  final OcrService _ocrService = OcrService();
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _analysisController = TextEditingController();
  final TextEditingController _chapterController = TextEditingController();
  final TextEditingController _examPointController = TextEditingController();

  String _subject = '数学';
  String _errorType = '知识盲区';
  String _correctAnswer = 'A';
  String _userAnswer = 'B';
  List<String> _examMethods = [];
  List<String> _keyPoints = [];
  List<String> _tags = [];

  // 题目类型: single_choice, multi_choice, fill_blank, short_answer, true_false
  String _questionType = 'single_choice';

  // 多选题正确答案（多个）
  List<String> _multiCorrectAnswers = ['A'];
  // 多选题我的答案（多个）
  List<String> _multiUserAnswers = ['B'];
  // 判断题正确答案
  String _trueFalseCorrectAnswer = '对';
  // 判断题我的答案
  String _trueFalseUserAnswer = '错';

  // 填空题/简答题的答案控制器
  final TextEditingController _fillCorrectAnswerController = TextEditingController();
  final TextEditingController _fillUserAnswerController = TextEditingController();
  final TextEditingController _shortCorrectAnswerController = TextEditingController();
  final TextEditingController _shortUserAnswerController = TextEditingController();

  // 动态选项
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  // 附件图片路径
  final List<String> _attachmentPaths = [];

  bool _isSaving = false;
  bool _isOcrLoading = false;

  // 已有的考法考点选项
  List<String> _existingExamMethods = [];
  List<String> _existingKeyPoints = [];

  @override
  void initState() {
    super.initState();
    if (widget.question != null) {
      _titleController.text = widget.question!.title;
      _contentController.text = widget.question!.content;
      _analysisController.text = widget.question!.analysis;
      _chapterController.text = widget.question!.chapter ?? '';
      _subject = widget.question!.subject;
      _errorType = widget.question!.errorType;
      _correctAnswer = widget.question!.correctAnswer;
      _userAnswer = widget.question!.userAnswer ?? '';
      _examMethods = widget.question!.examMethods;
      _keyPoints = widget.question!.keyPoints;
      _tags = widget.question!.tags;

      // 推断题目类型
      if (_correctAnswer.contains(',') || _correctAnswer.contains('、')) {
        _questionType = 'multi_choice';
        _multiCorrectAnswers = _correctAnswer.split(RegExp(r'[,、]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        if (_userAnswer.isNotEmpty) {
          _multiUserAnswers = _userAnswer.split(RegExp(r'[,、]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        }
      } else if (_correctAnswer == '对' || _correctAnswer == '错' || _correctAnswer == '正确' || _correctAnswer == '错误' || _correctAnswer == 'true' || _correctAnswer == 'false') {
        _questionType = 'true_false';
        _trueFalseCorrectAnswer = (_correctAnswer == '对' || _correctAnswer == '正确' || _correctAnswer == 'true') ? '对' : '错';
        if (_userAnswer != null && _userAnswer!.isNotEmpty) {
          _trueFalseUserAnswer = (_userAnswer == '对' || _userAnswer == '正确' || _userAnswer == 'true') ? '对' : '错';
        }
      } else if (widget.question!.options.isEmpty) {
        // 没有选项，判断是填空还是简答
        _questionType = 'fill_blank';
      }

      // 初始化填空题/简答题控制器
      _fillCorrectAnswerController.text = _correctAnswer;
      _fillUserAnswerController.text = _userAnswer;
      _shortCorrectAnswerController.text = _correctAnswer;
      _shortUserAnswerController.text = _userAnswer;

      for (int i = 0; i < widget.question!.options.length && i < 4; i++) {
        final opt = widget.question!.options[i];
        _optionControllers[i].text =
            opt['text'] as String? ?? opt['content'] as String? ?? '';
      }

      for (final att in widget.question!.attachments) {
        final path = att['path'] as String? ?? '';
        if (path.isNotEmpty) _attachmentPaths.add(path);
      }
    } else if (widget.initialContent != null) {
      _contentController.text = widget.initialContent!;
    }
    _loadExistingExamMethodsAndKeyPoints();
  }

  Future<void> _loadExistingExamMethodsAndKeyPoints() async {
    // 从数据库加载已有的考法考点作为选项
    final questions = await _db.queryAllWrongQuestions(limit: 100);
    final Set<String> examMethodsSet = {};
    final Set<String> keyPointsSet = {};

    for (final q in questions) {
      final em = q['exam_methods'];
      final kp = q['key_points'];
      if (em != null) {
        try {
          final List<dynamic> decoded = jsonDecode(em.toString());
          examMethodsSet.addAll(decoded.map((e) => e.toString()));
        } catch (_) {}
      }
      if (kp != null) {
        try {
          final List<dynamic> decoded = jsonDecode(kp.toString());
          keyPointsSet.addAll(decoded.map((e) => e.toString()));
        } catch (_) {}
      }
    }

    setState(() {
      _existingExamMethods = examMethodsSet.toList()..sort();
      _existingKeyPoints = keyPointsSet.toList()..sort();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _analysisController.dispose();
    _chapterController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _attachmentPaths.add(picked.path));
        showSnackBar(context, '已添加图片');
      }
    } catch (e) {
      if (mounted) showSnackBar(context, '选择图片失败: $e', isError: true);
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _attachmentPaths.add(picked.path));
        showSnackBar(context, '已添加图片');
      }
    } catch (e) {
      if (mounted) showSnackBar(context, '拍照失败: $e', isError: true);
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Linux平台不支持相机功能，只显示相册选项
            if (!Platform.isLinux)
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('拍照'),
                subtitle: const Text('使用相机拍摄题目'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromCamera();
                },
              ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              subtitle: const Text('选择已有图片'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageForOcr() async {
    try {
      // Linux平台不支持相机功能，使用相册选择
      final ImageSource source = Platform.isLinux ? ImageSource.gallery : ImageSource.camera;
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _isOcrLoading = true);
      showSnackBar(context, '正在识别...');

      final result = await _ocrService.recognizeImage(picked.path);

      if (result.success && result.text.isNotEmpty) {
        setState(() {
          _contentController.text = result.text;
          _isOcrLoading = false;
        });
        showSnackBar(context, '识别成功');
      } else {
        setState(() => _isOcrLoading = false);
        showSnackBar(
          context,
          result.errorMessage ?? '未识别到文字',
          isError: true,
        );
      }
    } catch (e) {
      setState(() => _isOcrLoading = false);
      if (mounted) showSnackBar(context, 'OCR识别失败: $e', isError: true);
    }
  }

  Future<void> _save() async {
    if (_contentController.text.trim().isEmpty) {
      showSnackBar(context, '请输入题目内容', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 构建选项列表
      final options = <Map<String, dynamic>>[];
      final labels = ['A', 'B', 'C', 'D'];
      if (_questionType == 'single_choice' || _questionType == 'multi_choice') {
        for (int i = 0; i < _optionControllers.length; i++) {
          final text = _optionControllers[i].text.trim();
          if (text.isNotEmpty) {
            options.add({
              'label': labels[i],
              'text': text,
              'content': text,
            });
          }
        }
      }

      final hasOptions = options.isNotEmpty;

      // 根据题目类型确定正确答案和我的答案
      String correctAnswer;
      String? userAnswer;
      switch (_questionType) {
        case 'multi_choice':
          correctAnswer = _multiCorrectAnswers.join(',');
          userAnswer = _multiUserAnswers.isNotEmpty ? _multiUserAnswers.join(',') : null;
          break;
        case 'true_false':
          correctAnswer = _trueFalseCorrectAnswer;
          userAnswer = _trueFalseUserAnswer;
          break;
        case 'fill_blank':
          correctAnswer = _fillCorrectAnswerController.text.trim();
          userAnswer = _fillUserAnswerController.text.trim().isEmpty ? null : _fillUserAnswerController.text.trim();
          break;
        case 'short_answer':
          correctAnswer = _shortCorrectAnswerController.text.trim();
          userAnswer = _shortUserAnswerController.text.trim().isEmpty ? null : _shortUserAnswerController.text.trim();
          break;
        default:
          correctAnswer = _correctAnswer;
          userAnswer = _userAnswer.isNotEmpty ? _userAnswer : null;
      }

      final data = <String, dynamic>{
        'uuid': widget.question?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'question_content':
            _titleController.text.trim().isEmpty
                ? _contentController.text.trim()
                : _contentController.text.trim(),
        'title': _titleController.text.trim(),
        'question_type': _questionType,
        'options': hasOptions ? jsonEncode(options) : null,
        'correct_answer': correctAnswer,
        'my_answer': userAnswer,
        'analysis': _analysisController.text.trim(),
        'subject': _subject,
        'chapter': _chapterController.text.trim().isEmpty ? null : _chapterController.text.trim(),
        'error_type': _errorType,
        'error_count': widget.question?.errorCount ?? 1,
        'is_mastered': widget.question?.isResolved == true ? 1 : 0,
        'attachment_paths':
            _attachmentPaths.isNotEmpty
                ? jsonEncode(_attachmentPaths)
                : null,
        'exam_methods': jsonEncode(_examMethods),
        'key_points': jsonEncode(_keyPoints),
        'tags': _tags.isNotEmpty ? _tags.join(',') : null,
      };

      if (widget.question != null) {
        // 更新
        final row = await _db.queryWrongQuestionByUuid(widget.question!.id);
        if (row != null) {
          await _db.updateWrongQuestion(row['id'] as int, data);
        }
      } else {
        // 新增
        await _db.insertWrongQuestion(data);
      }

      if (mounted) {
        showSnackBar(context, widget.question != null ? '已更新' : '已添加');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) showSnackBar(context, '保存失败: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.question != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '编辑错题' : '添加错题'),
        actions: [
          if (_isOcrLoading)
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            AppInput(
              label: '题目标题（选填）',
              hintText: '如：第三章第5题',
              controller: _titleController,
            ),
            const SizedBox(height: 16),

            // 学科选择
            _buildSectionTitle('学科'),
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

            // 题目类型选择
            _buildSectionTitle('题目类型'),
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
            _buildSectionTitle('题目内容'),
            const SizedBox(height: 8),
            // 特殊符号选择栏
            CompactSymbolBar(controller: _contentController),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: AppInput(
                    hintText: '请输入题目内容...',
                    controller: _contentController,
                    multiline: true,
                    maxLines: 5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _isOcrLoading ? null : _pickImageForOcr,
                  icon: const Icon(Icons.document_scanner, size: 18),
                  label: const Text('OCR识别'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _showImagePickerOptions,
                  icon: const Icon(Icons.image, size: 18),
                  label: const Text('添加附件'),
                ),
              ],
            ),

            // 附件预览
            if (_attachmentPaths.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _attachmentPaths.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            _attachmentPaths[index],
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 80,
                              height: 80,
                              color: AppColors.divider,
                              child: const Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _attachmentPaths.removeAt(index);
                              });
                            },
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 16),

            // 根据题目类型显示不同的表单
            ..._buildQuestionTypeForm(),

            // 解析
            AppInput(
              label: '解析',
              hintText: '请输入题目解析...',
              controller: _analysisController,
              multiline: true,
              maxLines: 4,
            ),
            const SizedBox(height: 16),

            // 错误类型
            _buildSectionTitle('错误原因'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['粗心大意', '知识盲区', '方法错误', '审题不清', '时间不够'].map((type) {
                final selected = _errorType == type;
                return AppTag(
                  label: type,
                  color: _getErrorTypeColor(type),
                  selected: selected,
                  onTap: () => setState(() => _errorType = type),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // 考法考点输入
            ExamMethodKeyPointInput(
              examMethods: _examMethods,
              keyPoints: _keyPoints,
              onExamMethodsChanged: (methods) {
                setState(() => _examMethods = methods);
              },
              onKeyPointsChanged: (points) {
                setState(() => _keyPoints = points);
              },
              existingExamMethods: _existingExamMethods,
              existingKeyPoints: _existingKeyPoints,
            ),
            const SizedBox(height: 16),

            // 标签输入
            _buildSectionTitle('标签'),
            const SizedBox(height: 8),
            _buildTagsInput(),
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
            const SizedBox(height: 24),

            // 保存按钮
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: isEdit ? '保存修改' : '添加错题',
                style: AppButtonStyle.primary,
                isLoading: _isSaving,
                onPressed: _save,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: AppFontSize.md,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Color _getErrorTypeColor(String errorType) {
    switch (errorType) {
      case '粗心':
        return AppColors.warning;
      case '知识盲区':
        return AppColors.error;
      case '方法错误':
        return AppColors.info;
      default:
        return AppColors.textSecondary;
    }
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
