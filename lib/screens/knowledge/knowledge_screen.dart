import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/knowledge_point.dart';
import '../../services/database_service.dart';
import '../../services/export_service.dart';
import '../../services/ocr_service.dart';
import '../../services/print_service.dart';
import '../../services/voice_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/knowledge_widgets.dart';
import '../../widgets/exam_method_keypoint_input.dart';
import '../../widgets/input_method_selector.dart';
import '../../widgets/symbol_picker.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';

// ============================================================
// KnowledgeScreen - 知识点积累页面
// ============================================================

class KnowledgeScreen extends StatefulWidget {
  final String? initialFilterTag;

  const KnowledgeScreen({super.key, this.initialFilterTag});

  @override
  State<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends State<KnowledgeScreen> {
  // 服务
  final DatabaseService _dbService = DatabaseService();
  final ExportService _exportService = ExportService();
  final OcrService _ocrService = OcrService();
  final VoiceService _voiceService = VoiceService();

  // 数据
  List<Map<String, dynamic>> _knowledgePoints = [];
  List<Map<String, dynamic>> _filteredPoints = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  // 分页
  int _currentPage = 0;
  static const int _pageSize = 20;

  // 搜索
  final TextEditingController _searchController = TextEditingController();
  String _searchKeyword = '';

  // 筛选
  String? _selectedSubject;
  int? _selectedDifficulty;
  int? _selectedMasteryRange;
  String? _selectedTag;

  // 多选模式
  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};

  // 语音识别
  bool _isVoiceListening = false;
  String _voiceText = '';

  @override
  void initState() {
    super.initState();
    _selectedTag = widget.initialFilterTag;
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _voiceService.dispose();
    super.dispose();
  }

  // ==================== 数据加载 ====================

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await _dbService.queryAllKnowledgePoints(
        orderBy: 'updated_at DESC',
        limit: _pageSize,
        offset: 0,
      );
      setState(() {
        _knowledgePoints = results;
        _currentPage = 0;
        _hasMore = results.length >= _pageSize;
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

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _currentPage + 1;
      final results = await _dbService.queryAllKnowledgePoints(
        orderBy: 'updated_at DESC',
        limit: _pageSize,
        offset: nextPage * _pageSize,
      );
      setState(() {
        _knowledgePoints.addAll(results);
        _currentPage = nextPage;
        _hasMore = results.length >= _pageSize;
        _isLoadingMore = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() => _isLoadingMore = false);
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
    var points = _knowledgePoints;

    // 搜索过滤
    if (_searchKeyword.isNotEmpty) {
      final keyword = _searchKeyword.toLowerCase();
      points = points.where((p) {
        final title = (p['title'] as String? ?? '').toLowerCase();
        final content = (p['content'] as String? ?? '').toLowerCase();
        final tags = (p['tags'] as String? ?? '').toLowerCase();
        return title.contains(keyword) ||
            content.contains(keyword) ||
            tags.contains(keyword);
      }).toList();
    }

    // 学科过滤
    if (_selectedSubject != null) {
      points = points
          .where((p) => (p['subject'] as String?) == _selectedSubject)
          .toList();
    }

    // 难度过滤
    if (_selectedDifficulty != null) {
      points = points
          .where(
              (p) => (p['difficulty'] as int? ?? 1) == _selectedDifficulty)
          .toList();
    }

    // 掌握度过滤
    if (_selectedMasteryRange != null) {
      final range = _selectedMasteryRange!;
      points = points.where((p) {
        final mastery = p['mastery_level'] as int? ?? 0;
        if (range == 0) return mastery >= 0 && mastery < 25;
        if (range == 25) return mastery >= 25 && mastery < 50;
        if (range == 50) return mastery >= 50 && mastery < 75;
        if (range == 75) return mastery >= 75 && mastery <= 100;
        return true;
      }).toList();
    }

    // 标签过滤
    if (_selectedTag != null) {
      final tag = _selectedTag!.toLowerCase();
      points = points.where((p) {
        final tags = (p['tags'] as String? ?? '').toLowerCase();
        return tags.contains(tag);
      }).toList();
    }

    setState(() {
      _filteredPoints = points;
    });
  }

  void _onSubjectChanged(String? subject) {
    setState(() => _selectedSubject = subject);
    _applyFilters();
  }

  void _onDifficultyChanged(int? difficulty) {
    setState(() => _selectedDifficulty = difficulty);
    _applyFilters();
  }

  void _onMasteryRangeChanged(int? range) {
    setState(() => _selectedMasteryRange = range);
    _applyFilters();
  }

  void _resetFilters() {
    setState(() {
      _selectedSubject = null;
      _selectedDifficulty = null;
      _selectedMasteryRange = null;
      _selectedTag = null;
      _searchKeyword = '';
      _searchController.clear();
    });
    _applyFilters();
  }

  void _onTagChanged(String? tag) {
    setState(() => _selectedTag = tag);
    _applyFilters();
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
    if (_selectedIds.length == _filteredPoints.length) {
      setState(() {
        _selectedIds.clear();
        _isSelectionMode = false;
      });
    } else {
      setState(() {
        _selectedIds.clear();
        for (final p in _filteredPoints) {
          final id = p['id'] as int?;
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
    final confirmed = await ConfirmDeleteDialog.show(
      context: context,
      title: '批量删除',
      message: '确定要删除选中的 ${_selectedIds.length} 个知识点吗？此操作不可撤销。',
    );
    if (confirmed == true) {
      try {
        await _dbService.batchDelete(
            DatabaseService.tableKnowledgePoints, _selectedIds.toList());
        _exitSelectionMode();
        await _loadData();
        if (mounted) {
          showSnackBar(context, '已删除 ${_selectedIds.length} 个知识点');
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
      AppLoading.show(context, message: '正在导出...');

      // 获取选中的知识点数据
      final selectedPoints = _knowledgePoints.where((p) {
        final id = p['id'] as int?;
        return id != null && _selectedIds.contains(id);
      }).toList();

      // 构建导出数据
      final exportData = {
        'export_version': '1.0',
        'export_time': DateTime.now().toIso8601String(),
        'knowledge_points': selectedPoints,
      };

      // 保存到文件
      final result = await _exportService.exportAllToJson(
        fileName: 'knowledge_points_export_${DateTime.now().millisecondsSinceEpoch}.json',
      );

      AppLoading.hide(context);
      _exitSelectionMode();

      if (result.success && mounted) {
        showSnackBar(context, '已导出 ${_selectedIds.length} 个知识点到 ${result.fileName}');
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

    // 获取选中的知识点数据
    final selectedPoints = _knowledgePoints.where((p) {
      final id = p['id'] as int?;
      return id != null && _selectedIds.contains(id);
    }).toList();

    // 转换为打印内容项
    final printItems = selectedPoints.map((p) {
      final examMethods = p['exam_methods'] as String?;
      final keyPoints = p['key_points'] as String?;
      String? examMethod;
      String? keyPoint;

      if (examMethods != null && examMethods.isNotEmpty) {
        try {
          final decoded = jsonDecode(examMethods);
          if (decoded is List && decoded.isNotEmpty) {
            examMethod = decoded.first.toString();
          }
        } catch (_) {}
      }

      if (keyPoints != null && keyPoints.isNotEmpty) {
        try {
          final decoded = jsonDecode(keyPoints);
          if (decoded is List && decoded.isNotEmpty) {
            keyPoint = decoded.first.toString();
          }
        } catch (_) {}
      }

      return PrintContentItem(
        type: PrintContentType.knowledgePoint,
        title: p['title'] as String? ?? '无标题',
        content: p['content'] as String? ?? '',
        subject: p['subject'] as String?,
        category: p['category'] as String?,
        tags: p['tags'] as String?,
        difficulty: p['difficulty'] as int?,
        masteryLevel: p['mastery_level'] as int?,
        examMethod: examMethod,
        keyPoint: keyPoint,
        createdAt: p['created_at'] != null
            ? formatDate(DateTime.parse(p['created_at'] as String))
            : null,
      );
    }).toList();

    // 调用批量打印
    await PrintService.printBatch(
      context: context,
      items: printItems,
      customTitle: '知识点打印 (${printItems.length}项)',
    );

    _exitSelectionMode();
  }

  // ==================== CRUD 操作 ====================

  Future<void> _deleteKnowledgePoint(int dbId, String title) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context: context,
      message: '确定要删除知识点"$title"吗？',
    );
    if (confirmed == true) {
      try {
        await _dbService.deleteKnowledgePoint(dbId);
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

  // ==================== 添加知识点 ====================

  void _showAddMenu() async {
    // 使用统一的录入方式选择器
    final method = await InputMethodSelector.show(context);
    if (method == null) return;

    // 处理录入方式
    final handler = InputMethodHandler(context);
    final recognizedText = await handler.handleInputMethod(method);

    // 跳转到添加页面，传入识别到的内容
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => KnowledgeAddPage(
          initialContent: recognizedText,
        ),
      ),
    );
    if (result == true) {
      await _loadData();
    }
  }

  Future<void> _showManualAddDialog() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const KnowledgeAddPage(),
      ),
    );
    if (result == true) {
      await _loadData();
    }
  }

  Future<void> _startOcrAdd() async {
    try {
      final picker = ImagePicker();
      // Linux平台只支持相册选择
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image == null) return;

      if (mounted) {
        AppLoading.show(context, message: '正在识别文字...');
      }

      final ocrResult = await _ocrService.recognizeImage(image.path);

      if (mounted) {
        AppLoading.hide(context);
      }

      if (ocrResult.success && ocrResult.text.isNotEmpty) {
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => KnowledgeAddPage(
              initialContent: ocrResult.text,
              addMode: KnowledgeAddMode.ocr,
            ),
          ),
        );
        if (result == true) {
          await _loadData();
        }
      } else {
        if (mounted) {
          showSnackBar(
            context,
            ocrResult.errorMessage ?? '未识别到文字内容',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppLoading.hide(context);
        showSnackBar(context, 'OCR识别失败: $e', isError: true);
      }
    }
  }

  Future<void> _startVoiceInput() async {
    final initialized = await _voiceService.initialize();
    if (!initialized) {
      if (mounted) {
        showSnackBar(context, '语音识别初始化失败，请检查权限设置', isError: true);
      }
      return;
    }

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _VoiceInputDialog(voiceService: _voiceService),
      ),
    );

    if (result != null && result is String && result.isNotEmpty) {
      final navResult = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => KnowledgeAddPage(
            initialContent: result,
            addMode: KnowledgeAddMode.voice,
          ),
        ),
      );
      if (navResult == true) {
        await _loadData();
      }
    }
  }

  // ==================== 导航到详情 ====================

  void _navigateToDetail(Map<String, dynamic> point) {
    if (_isSelectionMode) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => KnowledgeDetailPage(
          knowledgeId: (point['uuid'] as String?) ?? point['id'].toString(),
          title: point['title'] as String? ?? '',
          subject: point['subject'] as String?,
          difficulty: point['difficulty'] as int?,
          mastery: point['mastery_level'] as int?,
          content: point['content'] as String?,
          summary: point['content'] as String?,
          createdAt: _parseDateTime(point['created_at']),
          updatedAt: _parseDateTime(point['updated_at']),
          onEdit: () async {
            Navigator.pop(context);
            final editResult = await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => KnowledgeAddPage(
                  existingPoint: point,
                ),
              ),
            );
            if (editResult == true) {
              await _loadData();
            }
          },
          onDelete: () async {
            final dbId = point['id'] as int?;
            if (dbId != null) {
              await _deleteKnowledgePoint(
                  dbId, point['title'] as String? ?? '');
              Navigator.pop(context);
            }
          },
        ),
      ),
    );
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
        title: const Text('知识点积累'),
        centerTitle: true,
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: _selectAll,
              tooltip: '全选',
            )
          else
            IconButton(
              icon: const Icon(Icons.filter_list_rounded),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppRadius.xl),
                    ),
                  ),
                  builder: (context) => DraggableScrollableSheet(
                    initialChildSize: 0.7,
                    minChildSize: 0.5,
                    maxChildSize: 0.9,
                    expand: false,
                    builder: (context, scrollController) => SingleChildScrollView(
                      controller: scrollController,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: KnowledgeFilterBar(
                          selectedSubject: _selectedSubject,
                          selectedDifficulty: _selectedDifficulty,
                          selectedMasteryRange: _selectedMasteryRange,
                          onSubjectChanged: (v) {
                            _onSubjectChanged(v);
                            Navigator.pop(context);
                          },
                          onDifficultyChanged: (v) {
                            _onDifficultyChanged(v);
                            Navigator.pop(context);
                          },
                          onMasteryRangeChanged: (v) {
                            _onMasteryRangeChanged(v);
                            Navigator.pop(context);
                          },
                          onReset: () {
                            _resetFilters();
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
              tooltip: '筛选',
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
            hintText: '搜索知识点...',
            onChanged: _onSearchChanged,
            onSearch: _onSearchChanged,
          ),

          // 筛选条件标签
          if (_selectedSubject != null ||
              _selectedDifficulty != null ||
              _selectedMasteryRange != null ||
              _selectedTag != null)
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                        onDeleted: () => _onSubjectChanged(null),
                      ),
                    ),
                  if (_selectedDifficulty != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InputChip(
                        avatar: Icon(
                          Icons.close,
                          size: 14,
                          color:
                              getDifficultyColor(_selectedDifficulty!),
                        ),
                        label: Text(
                            getDifficultyLabel(_selectedDifficulty!)),
                        backgroundColor: getDifficultyColor(
                                _selectedDifficulty!)
                            .withOpacity(0.1),
                        labelStyle: TextStyle(
                          color: getDifficultyColor(_selectedDifficulty!),
                          fontSize: AppFontSize.sm,
                        ),
                        onDeleted: () => _onDifficultyChanged(null),
                      ),
                    ),
                  if (_selectedMasteryRange != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InputChip(
                        avatar: const Icon(Icons.close, size: 14),
                        label: Text(
                            '掌握度 ${_selectedMasteryRange}%-${_selectedMasteryRange! + 25}%'),
                        onDeleted: () => _onMasteryRangeChanged(null),
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
                        onDeleted: () => _onTagChanged(null),
                      ),
                    ),
                ],
              ),
            ),

          // 列表
          Expanded(
            child: _isLoading
                ? const Center(child: AppLoading())
                : _filteredPoints.isEmpty
                    ? AppEmptyState(
                        message: _searchKeyword.isNotEmpty ||
                                _selectedSubject != null
                            ? '没有找到匹配的知识点'
                            : '还没有知识点\n点击右下角按钮添加',
                        icon: Icons.auto_stories_outlined,
                        actionText: '添加知识点',
                        onAction: _showAddMenu,
                      )
                    : RefreshIndicator(
                        onRefresh: _onRefresh,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: _filteredPoints.length +
                              (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _filteredPoints.length) {
                              _loadMore();
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                              );
                            }

                            final point = _filteredPoints[index];
                            final dbId = point['id'] as int?;
                            final tags = _parseTags(point['tags']);

                            return GestureDetector(
                              onLongPress: () {
                                if (dbId != null) {
                                  _enterSelectionMode(dbId);
                                }
                              },
                              child: KnowledgePointCard(
                                id: (point['uuid'] as String?) ??
                                    point['id'].toString(),
                                title: point['title'] as String? ?? '',
                                subject: point['subject'] as String? ?? '其他',
                                difficulty:
                                    point['difficulty'] as int? ?? 1,
                                mastery:
                                    point['mastery_level'] as int? ?? 0,
                                summary: point['content'] as String?,
                                updatedAt:
                                    _parseDateTime(point['updated_at']),
                                questionCount: 0,
                                tags: tags,
                                isSelected: dbId != null &&
                                    _selectedIds.contains(dbId),
                                onSelectionChanged: _isSelectionMode
                                    ? (selected) {
                                        if (dbId != null) {
                                          _toggleSelection(dbId);
                                        }
                                      }
                                    : null,
                                onTap: () => _navigateToDetail(point),
                                onTagTap: (tag) {
                                  _onTagChanged(tag);
                                },
                                onEdit: () async {
                                  final editResult =
                                      await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          KnowledgeAddPage(
                                        existingPoint: point,
                                      ),
                                    ),
                                  );
                                  if (editResult == true) {
                                    await _loadData();
                                  }
                                },
                                onDelete: () {
                                  if (dbId != null) {
                                    _deleteKnowledgePoint(
                                        dbId,
                                        point['title'] as String? ??
                                            '');
                                  }
                                },
                              ),
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
              totalCount: _filteredPoints.length,
              selectedCount: _selectedIds.length,
              isAllSelected: _selectedIds.length ==
                  _filteredPoints.length,
              onSelectAll: (selectAll) => _selectAll(),
              onDelete: _batchDelete,
              onExport: _batchExport,
              onPrint: _batchPrint,
              onCancel: _exitSelectionMode,
            )
          : null,
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: _showAddMenu,
              tooltip: '添加知识点',
              child: const Icon(Icons.add),
            ),
    );
  }

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
            _onSubjectChanged(null);
          }),
          const SizedBox(width: 8),
          // 各学科选项
          ...kSubjectNames.map((subject) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildSubjectChip(
                subject,
                _selectedSubject == subject,
                () => _onSubjectChanged(subject),
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
    final theme = Theme.of(context);
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
// KnowledgeAddPage - 知识点添加/编辑页面
// ============================================================

enum KnowledgeAddMode { manual, ocr, voice }

class KnowledgeAddPage extends StatefulWidget {
  final Map<String, dynamic>? existingPoint;
  final String? initialContent;
  final KnowledgeAddMode addMode;

  const KnowledgeAddPage({
    super.key,
    this.existingPoint,
    this.initialContent,
    this.addMode = KnowledgeAddMode.manual,
  });

  @override
  State<KnowledgeAddPage> createState() => _KnowledgeAddPageState();
}

class _KnowledgeAddPageState extends State<KnowledgeAddPage> {
  final DatabaseService _dbService = DatabaseService();
  final ImagePicker _imagePicker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _tagController;
  late TextEditingController _chapterController;

  String _selectedSubject = '数学';
  int _difficulty = 1;
  List<String> _tags = [];
  List<String> _attachmentPaths = [];
  List<String> _examMethods = [];
  List<String> _keyPoints = [];
  bool _isSaving = false;
  bool _isEditing = false;

  // 已有的考法考点选项（从数据库获取）
  List<String> _existingExamMethods = [];
  List<String> _existingKeyPoints = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _contentController = TextEditingController(
        text: widget.initialContent ?? '');
    _tagController = TextEditingController();
    _chapterController = TextEditingController();

    if (widget.existingPoint != null) {
      _isEditing = true;
      final point = widget.existingPoint!;
      _titleController.text = point['title'] as String? ?? '';
      _contentController.text = point['content'] as String? ?? '';
      _chapterController.text = point['chapter'] as String? ?? '';
      _selectedSubject = point['subject'] as String? ?? '数学';
      _difficulty = point['difficulty'] as int? ?? 1;
      _parseExistingTags(point['tags']);
      _parseExistingAttachments(point['attachment_paths']);
      _parseExistingExamMethods(point['exam_methods']);
      _parseExistingKeyPoints(point['key_points']);
    }
    _loadExistingExamMethodsAndKeyPoints();
  }

  Future<void> _loadExistingExamMethodsAndKeyPoints() async {
    // 从数据库加载已有的考法考点作为选项
    final knowledgePoints = await _dbService.queryAllKnowledgePoints(limit: 100);
    final Set<String> examMethodsSet = {};
    final Set<String> keyPointsSet = {};

    for (final kp in knowledgePoints) {
      final em = kp['exam_methods'];
      final kpList = kp['key_points'];
      if (em != null) {
        try {
          final List<dynamic> decoded = jsonDecode(em.toString());
          examMethodsSet.addAll(decoded.map((e) => e.toString()));
        } catch (_) {}
      }
      if (kpList != null) {
        try {
          final List<dynamic> decoded = jsonDecode(kpList.toString());
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

  void _parseExistingAttachments(dynamic attachmentsValue) {
    if (attachmentsValue == null) return;
    if (attachmentsValue is String) {
      try {
        final decoded = jsonDecode(attachmentsValue);
        if (decoded is List) {
          _attachmentPaths =
              decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    } else if (attachmentsValue is List) {
      _attachmentPaths =
          attachmentsValue.map((e) => e.toString()).toList();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    _chapterController.dispose();
    super.dispose();
  }

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

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() => _attachmentPaths.add(image.path));
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '选择图片失败: $e', isError: true);
      }
    }
  }

  void _removeAttachment(int index) {
    setState(() => _attachmentPaths.removeAt(index));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_titleController.text.trim().isEmpty) {
      showSnackBar(context, '请输入标题', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now().toIso8601String();
      final data = {
        'uuid': widget.existingPoint?['uuid'] ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'subject': _selectedSubject,
        'chapter': _chapterController.text.trim().isEmpty ? null : _chapterController.text.trim(),
        'difficulty': _difficulty,
        'mastery_level': widget.existingPoint?['mastery_level'] ?? 0,
        'review_count': widget.existingPoint?['review_count'] ?? 0,
        'last_review_time': widget.existingPoint?['last_review_time'],
        'parent_id': widget.existingPoint?['parent_id'],
        'sort_order': widget.existingPoint?['sort_order'] ?? 0,
        'is_favorite': widget.existingPoint?['is_favorite'] ?? 0,
        'tags': jsonEncode(_tags),
        'attachment_paths': jsonEncode(_attachmentPaths),
        'category': widget.existingPoint?['category'],
        'exam_methods': jsonEncode(_examMethods),
        'key_points': jsonEncode(_keyPoints),
      };

      if (_isEditing && widget.existingPoint != null) {
        final dbId = widget.existingPoint!['id'] as int?;
        if (dbId != null) {
          await _dbService.updateKnowledgePoint(dbId, data);
        }
      } else {
        data['created_at'] = now;
        data['updated_at'] = now;
        await _dbService.insertKnowledgePoint(data);
      }

      if (mounted) {
        showSnackBar(context, _isEditing ? '已更新' : '已添加');
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑知识点' : '添加知识点'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题输入
              AppInput(
                controller: _titleController,
                label: '标题',
                hintText: '输入知识点标题',
                prefixIcon: Icons.title_outlined,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入标题';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 学科选择
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '学科',
                    style: TextStyle(
                      fontSize: AppFontSize.md,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withOpacity(0.3),
                      borderRadius:
                          BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedSubject,
                        isExpanded: true,
                        items: kSubjectNames.map((subject) {
                          return DropdownMenuItem(
                            value: subject,
                            child: Row(
                              children: [
                                SubjectIcon(
                                  subjectName: subject,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
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
                ],
              ),
              const SizedBox(height: 16),

              // 内容编辑
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '内容',
                    style: TextStyle(
                      fontSize: AppFontSize.md,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // 特殊符号选择栏
                  CompactSymbolBar(controller: _contentController),
                  const SizedBox(height: 8),
                  AppInput(
                    controller: _contentController,
                    hintText: '输入知识点内容...',
                    multiline: true,
                    maxLines: 10,
                    prefixIcon: Icons.article_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 难度选择
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '难度',
                    style: TextStyle(
                      fontSize: AppFontSize.md,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: List.generate(5, (index) {
                      final level = index + 1;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _difficulty = level),
                        child: Padding(
                          padding:
                              const EdgeInsets.only(right: 8),
                          child: Icon(
                            level <= _difficulty
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 32,
                            color: level <= _difficulty
                                ? getDifficultyColor(
                                    _difficulty <= 2
                                        ? 1
                                        : _difficulty <= 4
                                            ? 2
                                            : 3)
                                : AppColors.textHint,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '难度: $_difficulty/5',
                    style: TextStyle(
                      fontSize: AppFontSize.sm,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 章节输入
              AppInput(
                controller: _chapterController,
                label: '章节',
                hintText: '如：第三章 函数',
                prefixIcon: Icons.book_outlined,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '标签',
                    style: TextStyle(
                      fontSize: AppFontSize.md,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
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
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                          ),
                          style:
                              TextStyle(fontSize: AppFontSize.sm),
                          onSubmitted: (_) => _addTag(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 附件添加
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '附件',
                        style: TextStyle(
                          fontSize: AppFontSize.md,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.add_photo_alternate,
                            size: 18),
                        label: const Text('添加图片'),
                      ),
                    ],
                  ),
                  if (_attachmentPaths.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _attachmentPaths.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                margin: const EdgeInsets.only(
                                    right: 8),
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(
                                          AppRadius.md),
                                  image: DecorationImage(
                                    image: _buildAttachmentImage(
                                        _attachmentPaths[index]),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _attachmentPaths[index]
                                        is String
                                    ? Image.asset(
                                        'assets/placeholder.png',
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            Container(
                                          color: AppColors
                                              .divider,
                                          child:
                                              const Icon(Icons.image),
                                        ),
                                      )
                                    : null,
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () =>
                                      _removeAttachment(index),
                                  child: Container(
                                    padding:
                                        const EdgeInsets.all(2),
                                    decoration:
                                        BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 14,
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
                ],
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  ImageProvider _buildAttachmentImage(dynamic path) {
    if (path is String && path.isNotEmpty) {
      final uri = Uri.tryParse(path);
      if (uri != null && uri.scheme.isNotEmpty) {
        return NetworkImage(path);
      }
      final file = File(path);
      if (file.existsSync()) {
        return FileImage(file);
      }
    }
    return _buildFallbackImage();
  }

  ImageProvider _buildFallbackImage() {
    return const AssetImage('assets/placeholder.png');
  }
}

// ============================================================
// _VoiceInputDialog - 语音录入对话框
// ============================================================

class _VoiceInputDialog extends StatefulWidget {
  final VoiceService voiceService;

  const _VoiceInputDialog({required this.voiceService});

  @override
  State<_VoiceInputDialog> createState() => _VoiceInputDialogState();
}

class _VoiceInputDialogState extends State<_VoiceInputDialog> {
  bool _isListening = false;
  String _recognizedText = '';
  String _interimText = '';

  @override
  void initState() {
    super.initState();
    widget.voiceService.onResult = (text) {
      if (mounted) {
        setState(() => _interimText = text);
      }
    };
    widget.voiceService.onFinalResult = (text) {
      if (mounted) {
        setState(() {
          _recognizedText += (text);
          _interimText = '';
        });
      }
    };
    widget.voiceService.onError = (error) {
      if (mounted) {
        setState(() => _isListening = false);
        showSnackBar(context, error, isError: true);
      }
    };
    widget.voiceService.onListeningStateChanged = () {
      if (mounted) {
        setState(() {
          _isListening = widget.voiceService.isListening;
        });
      }
    };
  }

  @override
  void dispose() {
    widget.voiceService.onResult = null;
    widget.voiceService.onFinalResult = null;
    widget.voiceService.onError = null;
    widget.voiceService.onListeningStateChanged = null;
    widget.voiceService.stopListening();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await widget.voiceService.stopListening();
    } else {
      final success = await widget.voiceService.startListening();
      if (!success && mounted) {
        showSnackBar(context, '无法启动语音识别', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('语音录入'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _recognizedText.trim().isNotEmpty
                ? () => Navigator.of(context).pop(_recognizedText.trim())
                : null,
            child: const Text('完成'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withOpacity(0.3),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.divider),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_recognizedText.isEmpty && _interimText.isEmpty)
                        Center(
                          child: Text(
                            '点击下方麦克风按钮开始语音录入',
                            style: TextStyle(
                              color: AppColors.textHint,
                              fontSize: AppFontSize.md,
                            ),
                          ),
                        ),
                      Text(
                        _recognizedText + _interimText,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.8,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (_interimText.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _interimText,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.8,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 麦克风按钮
            GestureDetector(
              onTap: _toggleListening,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _isListening
                      ? AppColors.error
                      : theme.colorScheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening
                              ? AppColors.error
                              : theme.colorScheme.primary)
                          .withOpacity(0.3),
                      blurRadius: _isListening ? 20 : 10,
                      spreadRadius: _isListening ? 4 : 0,
                    ),
                  ],
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isListening ? '正在聆听... (再次点击停止)' : '点击开始录音',
              style: TextStyle(
                fontSize: AppFontSize.sm,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
