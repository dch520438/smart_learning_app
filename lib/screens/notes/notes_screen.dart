import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/note.dart';
import '../../services/database_service.dart';
import '../../services/export_service.dart';
import '../../services/ocr_service.dart';
import '../../services/print_service.dart';
import '../../services/voice_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/note_widgets.dart';
import '../../widgets/exam_method_keypoint_input.dart';
import '../../widgets/input_method_selector.dart';
import '../../widgets/symbol_picker.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';

// ============================================================
// NotesScreen - 学习笔记页面
// ============================================================

class NotesScreen extends StatefulWidget {
  final String? initialFilterTag;

  const NotesScreen({super.key, this.initialFilterTag});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final DatabaseService _dbService = DatabaseService();
  final ExportService _exportService = ExportService();

  // 数据
  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _filteredNotes = [];
  bool _isLoading = true;

  // 搜索
  final TextEditingController _searchController = TextEditingController();
  String _searchKeyword = '';

  // 视图模式
  bool _isGridView = false;

  // 筛选
  String? _selectedSubject;
  String? _selectedTag;
  String _sortBy = 'updated_at'; // 'updated_at' or 'created_at'
  bool _sortDescending = true;

  // 多选模式
  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _selectedTag = widget.initialFilterTag;
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==================== 数据加载 ====================

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await _dbService.queryAllNotes(
        orderBy: '${_sortBy} ${_sortDescending ? 'DESC' : 'ASC'}',
      );
      setState(() {
        _notes = results;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showSnackBar(context, '加载失败: $e', isError: true);
      }
    }
  }

  Future<void> _onRefresh() async {
    await _loadData();
  }

  // ==================== 搜索与筛选 ====================

  void _onSearchChanged(String value) {
    _searchKeyword = value.trim();
    _applyFilters();
  }

  void _applyFilters() {
    var notes = _notes;

    // 搜索过滤
    if (_searchKeyword.isNotEmpty) {
      final keyword = _searchKeyword.toLowerCase();
      notes = notes.where((n) {
        final title = (n['title'] as String? ?? '').toLowerCase();
        final content = (n['content'] as String? ?? '').toLowerCase();
        final tags = (n['tags'] as String? ?? '').toLowerCase();
        return title.contains(keyword) ||
            content.contains(keyword) ||
            tags.contains(keyword);
      }).toList();
    }

    // 学科过滤
    if (_selectedSubject != null) {
      notes = notes
          .where((n) => (n['subject'] as String?) == _selectedSubject)
          .toList();
    }

    // 标签过滤
    if (_selectedTag != null) {
      final tag = _selectedTag!.toLowerCase();
      notes = notes.where((n) {
        final tags = (n['tags'] as String? ?? '').toLowerCase();
        return tags.contains(tag);
      }).toList();
    }

    setState(() {
      _filteredNotes = notes;
    });
  }

  void _onSubjectFilterChanged(String? subject) {
    setState(() => _selectedSubject = subject);
    _applyFilters();
  }

  void _onSortChanged(String sortBy) {
    setState(() {
      if (_sortBy == sortBy) {
        _sortDescending = !_sortDescending;
      } else {
        _sortBy = sortBy;
        _sortDescending = true;
      }
    });
    _loadData();
  }

  // ==================== 多选模式 ====================

  void _enterSelectionMode(int dbId) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.clear();
      _selectedIds.add(dbId);
    });
  }

  void _toggleSelection(int dbId) {
    setState(() {
      if (_selectedIds.contains(dbId)) {
        _selectedIds.remove(dbId);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(dbId);
      }
    });
  }

  void _selectAll() {
    if (_selectedIds.length == _filteredNotes.length) {
      setState(() {
        _selectedIds.clear();
        _isSelectionMode = false;
      });
    } else {
      setState(() {
        _selectedIds.clear();
        for (final n in _filteredNotes) {
          final id = n['id'] as int?;
          if (id != null) _selectedIds.add(id);
        }
      });
    }
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _batchDelete() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await AppDialog.showConfirmDelete(
      context: context,
      title: '批量删除',
      message: '确定要删除选中的 ${_selectedIds.length} 篇笔记吗？此操作不可撤销。',
    );
    if (confirmed == true) {
      try {
        await _dbService.batchDelete(
            DatabaseService.tableNotes, _selectedIds.toList());
        final count = _selectedIds.length;
        _exitSelectionMode();
        await _loadData();
        if (mounted) {
          showSnackBar(context, '已删除 $count 篇笔记');
        }
      } catch (e) {
        if (mounted) {
          showSnackBar(context, '删除失败: $e', isError: true);
        }
      }
    }
  }

  Future<void> _batchExport() async {
    if (_selectedIds.isEmpty) return;
    try {
      final result = await _exportService.exportModulesToJson(
        [ExportService.moduleNotes],
        fileName: 'notes_export',
      );
      _exitSelectionMode();
      if (mounted) {
        if (result.success) {
          showSnackBar(context, '笔记导出成功: ${result.filePath}');
        } else {
          showSnackBar(context, '导出失败: ${result.errorMessage}', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '导出失败: $e', isError: true);
      }
    }
  }

  Future<void> _batchPrint() async {
    if (_selectedIds.isEmpty) return;

    // 获取选中的笔记数据
    final selectedNotes = _notes.where((n) {
      final id = n['id'] as int?;
      return id != null && _selectedIds.contains(id);
    }).toList();

    // 转换为打印内容项
    final printItems = selectedNotes.map((n) {
      return PrintContentItem(
        type: PrintContentType.note,
        title: n['title'] as String? ?? '无标题',
        content: n['content'] as String? ?? '',
        subject: n['subject'] as String?,
        tags: n['tags'] as String?,
        createdAt: n['created_at'] != null
            ? formatDate(DateTime.parse(n['created_at'] as String))
            : null,
      );
    }).toList();

    // 调用批量打印
    await PrintService.printBatch(
      context: context,
      items: printItems,
      customTitle: '笔记打印 (${printItems.length}项)',
    );

    _exitSelectionMode();
  }

  // ==================== CRUD 操作 ====================

  Future<void> _deleteNote(int dbId, String title) async {
    final confirmed = await AppDialog.showConfirmDelete(
      context: context,
      title: '删除笔记',
      message: '确定要删除笔记"$title"吗？',
    );
    if (confirmed == true) {
      try {
        await _dbService.deleteNote(dbId);
        await _loadData();
        if (mounted) {
          showSnackBar(context, '已删除');
        }
      } catch (e) {
        if (mounted) {
          showSnackBar(context, '删除失败: $e', isError: true);
        }
      }
    }
  }

  Future<void> _toggleFavorite(int dbId, bool currentFavorite) async {
    try {
      await _dbService.updateNote(dbId, {
        'is_favorite': currentFavorite ? 0 : 1,
      });
      await _loadData();
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '操作失败: $e', isError: true);
      }
    }
  }

  // ==================== 导航 ====================

  Future<void> _navigateToEditor({Map<String, dynamic>? existingNote, String? initialContent}) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NoteEditorPage(
          existingNote: existingNote,
          initialContent: initialContent,
        ),
      ),
    );
    if (result == true) {
      await _loadData();
    }
  }

  /// 显示录入方式选择器并处理录入
  Future<void> _showInputMethodSelector() async {
    final method = await InputMethodSelector.show(context);
    if (method == null) return;

    final handler = InputMethodHandler(context);
    final recognizedText = await handler.handleInputMethod(method);

    await _navigateToEditor(initialContent: recognizedText);
  }

  // ==================== 辅助方法 ====================

  List<String> _parseTags(dynamic tagsValue) {
    if (tagsValue == null) return [];
    if (tagsValue is List) return tagsValue.cast<String>();
    if (tagsValue is String) {
      try {
        final decoded = jsonDecode(tagsValue);
        if (decoded is List) return decoded.cast<String>();
      } catch (_) {}
      return tagsValue
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  // ==================== 构建UI ====================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('学习笔记'),
        centerTitle: true,
        actions: [
          // 视图切换
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () => setState(() => _isGridView = !_isGridView),
            tooltip: _isGridView ? '列表视图' : '网格视图',
          ),
          // 筛选
          if (!_isSelectionMode)
            PopupMenuButton<String>(
              icon: const Icon(Icons.tune_rounded),
              onSelected: (value) {
                switch (value) {
                  case 'subject_all':
                    _onSubjectFilterChanged(null);
                    break;
                  default:
                    if (value.startsWith('subject_')) {
                      _onSubjectFilterChanged(value.replaceFirst('subject_', ''));
                    }
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'subject_all',
                  child: Row(
                    children: [
                      Icon(Icons.filter_list_off, size: 18),
                      SizedBox(width: 8),
                      Text('全部学科'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                ...kSubjectNames.map((subject) => PopupMenuItem(
                      value: 'subject_$subject',
                      child: Row(
                        children: [
                          SubjectIcon(subjectName: subject, size: 20),
                          const SizedBox(width: 8),
                          Text(subject),
                          if (_selectedSubject == subject)
                            const Spacer(),
                          if (_selectedSubject == subject)
                            const Icon(Icons.check, size: 18),
                        ],
                      ),
                    )),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'sort_updated',
                  child: Row(
                    children: [
                      Icon(
                        Icons.update,
                        size: 18,
                        color: _sortBy == 'updated_at'
                            ? theme.colorScheme.primary
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '按修改时间排序',
                        style: TextStyle(
                          color: _sortBy == 'updated_at'
                              ? theme.colorScheme.primary
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'sort_created',
                  child: Row(
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        size: 18,
                        color: _sortBy == 'created_at'
                            ? theme.colorScheme.primary
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '按创建时间排序',
                        style: TextStyle(
                          color: _sortBy == 'created_at'
                              ? theme.colorScheme.primary
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              tooltip: '筛选与排序',
            ),
          // 多选全选
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: _selectAll,
              tooltip: '全选',
            ),
        ],
      ),
      body: Column(
        children: [
          // 学科筛选栏
          _buildSubjectFilterBar(theme),

          // 搜索栏
          AppSearchBar(
            controller: _searchController,
            hintText: '搜索笔记...',
            onChanged: _onSearchChanged,
            onSearch: _onSearchChanged,
          ),

          // 筛选条件标签
          if (_selectedSubject != null || _selectedTag != null)
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  if (_selectedSubject != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InputChip(
                        avatar: Icon(
                          Icons.close,
                          size: 14,
                          color: getSubjectColor(_selectedSubject!),
                        ),
                        label: Text(_selectedSubject!),
                        backgroundColor:
                            getSubjectColor(_selectedSubject!).withOpacity(0.1),
                        labelStyle: TextStyle(
                          color: getSubjectColor(_selectedSubject!),
                          fontSize: AppFontSize.sm,
                        ),
                        onDeleted: () => _onSubjectFilterChanged(null),
                      ),
                    ),
                  if (_selectedTag != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InputChip(
                        avatar: const Icon(Icons.close, size: 14),
                        label: Text('标签: $_selectedTag'),
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        labelStyle: TextStyle(
                          color: AppColors.primary,
                          fontSize: AppFontSize.sm,
                        ),
                        onDeleted: () {
                          setState(() => _selectedTag = null);
                          _applyFilters();
                        },
                      ),
                    ),
                ],
              ),
            ),

          // 笔记列表
          Expanded(
            child: _isLoading
                ? const Center(child: AppLoading())
                : _filteredNotes.isEmpty
                    ? AppEmptyState(
                        message: _searchKeyword.isNotEmpty ||
                                _selectedSubject != null
                            ? '没有找到匹配的笔记'
                            : '还没有笔记\n点击右下角按钮创建',
                        icon: Icons.note_add_outlined,
                        actionText: '创建笔记',
                        onAction: () => _navigateToEditor(),
                      )
                    : RefreshIndicator(
                        onRefresh: _onRefresh,
                        child: _isGridView
                            ? _buildGridView()
                            : _buildListView(),
                      ),
          ),
        ],
      ),
      // 批量操作栏
      bottomNavigationBar: _isSelectionMode
          ? BatchOperationBar(
              totalCount: _filteredNotes.length,
              selectedCount: _selectedIds.length,
              isAllSelected:
                  _selectedIds.length == _filteredNotes.length,
              onSelectAll: (_) => _selectAll(),
              onDelete: _batchDelete,
              onExport: _batchExport,
              onPrint: _batchPrint,
              onCancel: _exitSelectionMode,
            )
          : null,
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: () => _showInputMethodSelector(),
              tooltip: '新建笔记',
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _filteredNotes.length,
      itemBuilder: (context, index) {
        final note = _filteredNotes[index];
        return _buildNoteItem(note);
      },
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 80,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: _filteredNotes.length,
      itemBuilder: (context, index) {
        final note = _filteredNotes[index];
        return _buildNoteCard(note);
      },
    );
  }

  Widget _buildNoteItem(Map<String, dynamic> note) {
    final dbId = note['id'] as int?;
    final tags = _parseTags(note['tags']);
    final noteColor = _parseNoteColor(note['color']);
    final isFavorite = (note['is_favorite'] as int?) == 1;

    return GestureDetector(
      onLongPress: () {
        if (dbId != null) _enterSelectionMode(dbId);
      },
      child: NoteCard(
        id: (note['uuid'] as String?) ?? note['id'].toString(),
        title: note['title'] as String? ?? '无标题',
        content: note['content'] as String?,
        subject: note['subject'] as String?,
        noteColor: noteColor,
        updatedAt: _parseDateTime(note['updated_at']),
        tags: tags,
        isFavorited: isFavorite,
        isSelected: dbId != null && _selectedIds.contains(dbId),
        onSelectionChanged: _isSelectionMode
            ? (selected) {
                if (dbId != null) _toggleSelection(dbId);
              }
            : null,
        onTap: () {
          if (!_isSelectionMode) {
            _navigateToEditor(existingNote: note);
          }
        },
        onEdit: () => _navigateToEditor(existingNote: note),
        onDelete: () {
          if (dbId != null) {
            _deleteNote(dbId, note['title'] as String? ?? '无标题');
          }
        },
        onFavorite: () {
          if (dbId != null) _toggleFavorite(dbId, isFavorite);
        },
      ),
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> note) {
    final dbId = note['id'] as int?;
    final tags = _parseTags(note['tags']);
    final noteColor = _parseNoteColor(note['color']);
    final isFavorite = (note['is_favorite'] as int?) == 1;
    final theme = Theme.of(context);

    return GestureDetector(
      onLongPress: () {
        if (dbId != null) _enterSelectionMode(dbId);
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: dbId != null && _selectedIds.contains(dbId)
              ? BorderSide(color: theme.colorScheme.primary, width: 2)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            if (!_isSelectionMode) {
              _navigateToEditor(existingNote: note);
            } else if (dbId != null) {
              _toggleSelection(dbId);
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部颜色条
              Container(
                height: 4,
                width: double.infinity,
                color: noteColor,
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 选择框 + 标题 + 收藏
                    Row(
                      children: [
                        if (_isSelectionMode)
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: Checkbox(
                              value: dbId != null &&
                                  _selectedIds.contains(dbId),
                              onChanged: (v) {
                                if (dbId != null) _toggleSelection(dbId);
                              },
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        if (_isSelectionMode)
                          const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            note['title'] as String? ?? '无标题',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isFavorite)
                          const Icon(
                            Icons.bookmark_rounded,
                            size: 16,
                            color: AppColors.warning,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // 学科标签
                    if (note['subject'] != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: AppTag(
                          label: note['subject'] as String,
                          color: getSubjectColor(note['subject'] as String),
                          dense: true,
                          fontSize: AppFontSize.xs,
                        ),
                      ),
                    // 内容预览
                    if (note['content'] != null &&
                        (note['content'] as String).isNotEmpty)
                      Text(
                        note['content'] as String,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const Spacer(),
                    // 标签
                    if (tags.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: tags
                            .take(2)
                            .map((tag) => Text(
                                  '#$tag',
                                  style: TextStyle(
                                    fontSize: AppFontSize.xs,
                                    color: theme.colorScheme.primary,
                                  ),
                                ))
                            .toList(),
                      ),
                    const SizedBox(height: 4),
                    // 时间
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        _parseDateTime(note['updated_at']) != null
                            ? formatFriendlyTime(
                                _parseDateTime(note['updated_at'])!)
                            : '',
                        style: TextStyle(
                          fontSize: AppFontSize.xs,
                          color: AppColors.textHint,
                        ),
                      ),
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

  Color _parseNoteColor(dynamic colorValue) {
    if (colorValue == null) return AppColors.primary;
    if (colorValue is Color) return colorValue;
    if (colorValue is String) return parseColor(colorValue);
    return AppColors.primary;
  }

  // ==================== 学科筛选栏 ====================

  Widget _buildSubjectFilterBar(ThemeData theme) {
    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // 全部选项
          _buildSubjectChip('全部', _selectedSubject == null, () {
            _onSubjectFilterChanged(null);
          }),
          const SizedBox(width: 8),
          // 各学科选项
          ...kSubjectNames.map((subject) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildSubjectChip(
                subject,
                _selectedSubject == subject,
                () => _onSubjectFilterChanged(subject),
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
}

// ============================================================
// NoteEditorPage - 笔记编辑页面
// ============================================================

class NoteEditorPage extends StatefulWidget {
  final Map<String, dynamic>? existingNote;
  final String? initialContent;

  const NoteEditorPage({super.key, this.existingNote, this.initialContent});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  final DatabaseService _dbService = DatabaseService();

  // 控制器
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _tagController;
  late TextEditingController _chapterController;

  // 数据
  String? _selectedSubject;
  Color _selectedColor = AppColors.primary;
  List<String> _tags = [];
  List<String> _examMethods = [];
  List<String> _keyPoints = [];
  bool _isPreviewMode = false;
  bool _isSaving = false;
  bool _isEditing = false;

  // 已有的考法考点选项
  List<String> _existingExamMethods = [];
  List<String> _existingKeyPoints = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _contentController = TextEditingController();
    _tagController = TextEditingController();
    _chapterController = TextEditingController();

    if (widget.existingNote != null) {
      _isEditing = true;
      final note = widget.existingNote!;
      _titleController.text = note['title'] as String? ?? '';
      _contentController.text = note['content'] as String? ?? '';
      _chapterController.text = note['chapter'] as String? ?? '';
      _selectedSubject = note['subject'] as String?;
      _selectedColor = _parseNoteColor(note['color']);
      _parseExistingTags(note['tags']);
      _parseExistingExamMethods(note['exam_methods']);
      _parseExistingKeyPoints(note['key_points']);
    } else if (widget.initialContent != null) {
      // 如果是通过OCR或语音录入的内容
      _contentController.text = widget.initialContent!;
    }
    _loadExistingExamMethodsAndKeyPoints();
  }

  Future<void> _loadExistingExamMethodsAndKeyPoints() async {
    // 从数据库加载已有的考法考点作为选项
    final notes = await _dbService.queryAllNotes(limit: 100);
    final Set<String> examMethodsSet = {};
    final Set<String> keyPointsSet = {};

    for (final note in notes) {
      final em = note['exam_methods'];
      final kp = note['key_points'];
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

  void _parseExistingExamMethods(dynamic value) {
    if (value == null) return;
    if (value is List) {
      _examMethods = value.map((e) => e.toString()).toList();
    } else if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          _examMethods = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        _examMethods = value
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }
  }

  void _parseExistingKeyPoints(dynamic value) {
    if (value == null) return;
    if (value is List) {
      _keyPoints = value.map((e) => e.toString()).toList();
    } else if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          _keyPoints = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        _keyPoints = value
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }
  }

  void _parseExistingTags(dynamic tagsValue) {
    if (tagsValue == null) return;
    if (tagsValue is List) {
      _tags = tagsValue.map((e) => e.toString()).toList();
    } else if (tagsValue is String) {
      try {
        final decoded = jsonDecode(tagsValue);
        if (decoded is List) {
          _tags = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        _tags = tagsValue
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }
  }

  Color _parseNoteColor(dynamic colorValue) {
    if (colorValue == null) return AppColors.primary;
    if (colorValue is Color) return colorValue;
    if (colorValue is String) return parseColor(colorValue);
    return AppColors.primary;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    _chapterController.dispose();
    super.dispose();
  }

  // ==================== 标签管理 ====================

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() => _tags.add(tag));
      _tagController.clear();
    }
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  // ==================== Markdown 工具栏 ====================

  void _insertMarkdown(String prefix, String suffix) {
    final controller = _contentController;
    final text = controller.text;
    final selection = controller.selection;

    final start = selection.start;
    final end = selection.end;

    String newText;
    int newCursorPos;

    if (start == end) {
      // 没有选中文本，在光标处插入
      newText = text.substring(0, start) + prefix + suffix + text.substring(end);
      newCursorPos = start + prefix.length;
    } else {
      // 有选中文本，包裹选中文本
      final selectedText = text.substring(start, end);
      newText = text.substring(0, start) + prefix + selectedText + suffix + text.substring(end);
      newCursorPos = start + prefix.length + selectedText.length + suffix.length;
    }

    controller.text = newText;
    controller.selection = TextSelection.collapsed(offset: newCursorPos);
    setState(() {});
  }

  void _insertBold() => _insertMarkdown('**', '**');
  void _insertItalic() => _insertMarkdown('*', '*');
  void _insertHeading() => _insertMarkdown('## ', '');
  void _insertBulletList() => _insertMarkdown('- ', '');
  void _insertQuote() => _insertMarkdown('> ', '');
  void _insertCode() => _insertMarkdown('`', '`');
  void _insertDivider() => _insertMarkdown('\n---\n', '');

  // ==================== 保存 ====================

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      showSnackBar(context, '请输入标题', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now().toIso8601String();
      final data = {
        'uuid': widget.existingNote?['uuid'] ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'subject': _selectedSubject ?? '其他',
        'chapter': _chapterController.text.trim().isEmpty 
            ? null 
            : _chapterController.text.trim(),
        'tags': jsonEncode(_tags),
        'color': colorToHex(_selectedColor),
        'note_type': 'text',
        'is_favorite': widget.existingNote?['is_favorite'] ?? 0,
        'knowledge_point_id': widget.existingNote?['knowledge_point_id'],
        'exam_methods': jsonEncode(_examMethods),
        'key_points': jsonEncode(_keyPoints),
      };

      if (_isEditing && widget.existingNote != null) {
        final dbId = widget.existingNote!['id'] as int?;
        if (dbId != null) {
          await _dbService.updateNote(dbId, data);
        }
      } else {
        data['created_at'] = now;
        data['updated_at'] = now;
        await _dbService.insertNote(data);
      }

      if (mounted) {
        showSnackBar(context, _isEditing ? '已保存' : '已创建');
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

  // ==================== 构建UI ====================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑笔记' : '新建笔记'),
        centerTitle: true,
        actions: [
          // 打印按钮（仅在编辑已有笔记时显示）
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.print_outlined),
              onPressed: () => PrintService.printNote(
                context: context,
                title: _titleController.text.isEmpty ? '无标题' : _titleController.text,
                content: _contentController.text,
                subject: _selectedSubject,
                tags: _tags.join(', '),
              ),
              tooltip: '打印',
            ),
          // 预览切换
          IconButton(
            icon: Icon(
              _isPreviewMode ? Icons.edit_outlined : Icons.visibility_outlined,
            ),
            onPressed: () => setState(() => _isPreviewMode = !_isPreviewMode),
            tooltip: _isPreviewMode ? '编辑' : '预览',
          ),
          // 保存
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 工具栏（编辑模式下显示）
          if (!_isPreviewMode) _buildToolbar(theme),

          // 编辑/预览区域
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题输入
                  if (!_isPreviewMode)
                    TextField(
                      controller: _titleController,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: '输入笔记标题...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.next,
                    )
                  else
                    Text(
                      _titleController.text.isEmpty
                          ? '无标题'
                          : _titleController.text,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  const SizedBox(height: 8),

                  // 学科选择 + 颜色选择
                  if (!_isPreviewMode)
                    Row(
                      children: [
                        // 学科选择
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withOpacity(0.3),
                            borderRadius:
                                BorderRadius.circular(AppRadius.xl),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedSubject,
                              hint: const Text('选择学科'),
                              items: kSubjectNames.map((subject) {
                                return DropdownMenuItem(
                                  value: subject,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SubjectIcon(
                                        subjectName: subject,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(subject),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _selectedSubject = value);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 颜色选择按钮
                        GestureDetector(
                          onTap: () => _showColorPicker(context),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _selectedColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.divider,
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.palette,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (_selectedSubject != null)
                    AppTag(
                      label: _selectedSubject!,
                      color: getSubjectColor(_selectedSubject!),
                    ),

                  // 章节输入
                  if (!_isPreviewMode) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _chapterController,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: '输入章节（如：第三章 函数）',
                        hintStyle: TextStyle(
                          color: AppColors.textHint,
                        ),
                        prefixIcon: const Icon(
                          Icons.book_outlined,
                          size: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        isDense: true,
                      ),
                    ),
                  ] else if (_chapterController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.book_outlined,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _chapterController.text,
                            style: TextStyle(
                              fontSize: AppFontSize.sm,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // 内容区域
                  if (_isPreviewMode)
                    _buildMarkdownPreview(theme)
                  else
                    Column(
                      children: [
                        // 特殊符号选择栏
                        CompactSymbolBar(controller: _contentController),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _contentController,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimary,
                            height: 1.8,
                          ),
                          decoration: InputDecoration(
                            hintText: '开始记录笔记...\n\n支持Markdown语法：\n# 标题\n'
                                '**粗体** *斜体*\n- 列表项\n> 引用\n`代码`\n--- 分割线',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            hintStyle: TextStyle(
                              color: AppColors.textHint,
                              height: 1.8,
                            ),
                          ),
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                        ),
                      ],
                    ),

                  const SizedBox(height: 24),

                  // 考法考点区域
                  if (!_isPreviewMode) ...[
                    const Divider(height: 1),
                    const SizedBox(height: 12),
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
                  ],

                  // 标签区域
                  if (!_isPreviewMode) ...[
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          '标签',
                          style: TextStyle(
                            fontSize: AppFontSize.sm,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        if (_tags.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              setState(() => _tags.clear());
                            },
                            child: Text(
                              '清空',
                              style: TextStyle(
                                fontSize: AppFontSize.xs,
                                color: AppColors.textHint,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._tags.map((tag) => Chip(
                              label: Text(tag),
                              deleteIcon:
                                  const Icon(Icons.close, size: 16),
                              onDeleted: () => _removeTag(tag),
                              visualDensity: VisualDensity.compact,
                            )),
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _tagController,
                            decoration: InputDecoration(
                              hintText: '添加标签',
                              isDense: true,
                              prefixIcon:
                                  const Icon(Icons.add, size: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                    AppRadius.xl),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                            ),
                            style: TextStyle(fontSize: AppFontSize.sm),
                            onSubmitted: (_) => _addTag(),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // 底部安全区域
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 工具栏 ====================

  Widget _buildToolbar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.divider),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildToolbarButton(
              icon: Icons.format_bold,
              tooltip: '粗体',
              onPressed: _insertBold,
            ),
            _buildToolbarButton(
              icon: Icons.format_italic,
              tooltip: '斜体',
              onPressed: _insertItalic,
            ),
            _buildToolbarButton(
              icon: Icons.title,
              tooltip: '标题',
              onPressed: _insertHeading,
            ),
            _buildToolbarButton(
              icon: Icons.format_list_bulleted,
              tooltip: '列表',
              onPressed: _insertBulletList,
            ),
            _buildToolbarButton(
              icon: Icons.format_quote,
              tooltip: '引用',
              onPressed: _insertQuote,
            ),
            _buildToolbarButton(
              icon: Icons.code,
              tooltip: '代码',
              onPressed: _insertCode,
            ),
            _buildToolbarButton(
              icon: Icons.horizontal_rule,
              tooltip: '分割线',
              onPressed: _insertDivider,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: 20),
      onPressed: onPressed,
      tooltip: tooltip,
      constraints: const BoxConstraints(
        minWidth: 36,
        minHeight: 36,
      ),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  // ==================== Markdown 预览 ====================

  Widget _buildMarkdownPreview(ThemeData theme) {
    final content = _contentController.text;
    if (content.isEmpty) {
      return Text(
        '暂无内容',
        style: TextStyle(
          fontSize: AppFontSize.md,
          color: AppColors.textHint,
        ),
      );
    }

    final lines = content.split('\n');
    final List<Widget> widgets = [];

    for (final line in lines) {
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      // 标题
      if (line.startsWith('# ')) {
        widgets.add(Text(
          line.substring(2),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ));
        widgets.add(const SizedBox(height: 8));
      } else if (line.startsWith('## ')) {
        widgets.add(Text(
          line.substring(3),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ));
        widgets.add(const SizedBox(height: 6));
      } else if (line.startsWith('### ')) {
        widgets.add(Text(
          line.substring(4),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ));
        widgets.add(const SizedBox(height: 4));
      }
      // 引用
      else if (line.startsWith('> ')) {
        widgets.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border(
              left: BorderSide(
                color: theme.colorScheme.primary,
                width: 3,
              ),
            ),
          ),
          child: Text(
            line.substring(2),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ));
      }
      // 无序列表
      else if (line.startsWith('- ') || line.startsWith('* ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 16, top: 2, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInlineFormattedText(line.substring(2), theme),
              ),
            ],
          ),
        ));
      }
      // 有序列表
      else if (RegExp(r'^\d+\.\s').hasMatch(line)) {
        final match = RegExp(r'^(\d+\.\s)(.*)').firstMatch(line);
        if (match != null) {
          widgets.add(Padding(
            padding: const EdgeInsets.only(left: 16, top: 2, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  match.group(1)!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: _buildInlineFormattedText(match.group(2)!, theme),
                ),
              ],
            ),
          ));
        }
      }
      // 分割线
      else if (line.trim() == '---') {
        widgets.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(),
        ));
      }
      // 普通段落
      else {
        widgets.add(_buildInlineFormattedText(line, theme));
        widgets.add(const SizedBox(height: 4));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// 内联格式化文本（处理粗体、斜体、行内代码）
  Widget _buildInlineFormattedText(String text, ThemeData theme) {
    final spans = <TextSpan>[];
    final buffer = StringBuffer();
    var i = 0;

    while (i < text.length) {
      // 粗体 **text**
      if (i + 1 < text.length &&
          text[i] == '*' &&
          text[i + 1] == '*') {
        if (buffer.isNotEmpty) {
          spans.add(TextSpan(text: buffer.toString()));
          buffer.clear();
        }
        final end = text.indexOf('**', i + 2);
        if (end != -1) {
          spans.add(TextSpan(
            text: text.substring(i + 2, end),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ));
          i = end + 2;
        } else {
          buffer.write(text[i]);
          i++;
        }
      }
      // 斜体 *text*
      else if (text[i] == '*' && (i == 0 || text[i - 1] != '*')) {
        if (buffer.isNotEmpty) {
          spans.add(TextSpan(text: buffer.toString()));
          buffer.clear();
        }
        final end = text.indexOf('*', i + 1);
        if (end != -1 && end + 1 < text.length && text[end + 1] != '*') {
          spans.add(TextSpan(
            text: text.substring(i + 1, end),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ));
          i = end + 1;
        } else {
          buffer.write(text[i]);
          i++;
        }
      }
      // 行内代码 `code`
      else if (text[i] == '`') {
        if (buffer.isNotEmpty) {
          spans.add(TextSpan(text: buffer.toString()));
          buffer.clear();
        }
        final end = text.indexOf('`', i + 1);
        if (end != -1) {
          spans.add(TextSpan(
            text: text.substring(i + 1, end),
            style: TextStyle(
              fontFamily: 'monospace',
              backgroundColor:
                  theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              fontSize: AppFontSize.sm,
            ),
          ));
          i = end + 1;
        } else {
          buffer.write(text[i]);
          i++;
        }
      } else {
        buffer.write(text[i]);
        i++;
      }
    }

    if (buffer.isNotEmpty) {
      spans.add(TextSpan(text: buffer.toString()));
    }

    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
          height: 1.8,
        ),
        children: spans,
      ),
    );
  }

  // ==================== 颜色选择器 ====================

  void _showColorPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '选择笔记颜色',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),
            ColorPicker(
              selectedColor: _selectedColor,
              onColorChanged: (color) {
                setState(() => _selectedColor = color);
                Navigator.of(context).pop();
              },
              circleSize: 40,
              spacing: 16,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
