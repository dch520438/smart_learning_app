import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/must_remember.dart';
import '../../services/database_service.dart';
import '../../services/export_service.dart';
import '../../services/ocr_service.dart';
import '../../services/print_service.dart';
import '../../services/voice_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/exam_method_keypoint_input.dart';
import '../../widgets/input_method_selector.dart';
import '../../widgets/symbol_picker.dart';

// ============================================================
// MustRememberScreen - 必记必背主页面
// ============================================================

class MustRememberScreen extends StatefulWidget {
  const MustRememberScreen({super.key});

  @override
  State<MustRememberScreen> createState() => _MustRememberScreenState();
}

class _MustRememberScreenState extends State<MustRememberScreen> {
  final DatabaseService _db = DatabaseService();
  final ExportService _exportService = ExportService();

  List<MustRemember> _items = [];
  List<MustRemember> _filteredItems = [];
  bool _isLoading = true;

  // 分类Tab
  int _currentTabIndex = 0;
  final List<String> _categories = ['全部', '公式', '单词', '概念', '定理', '其他'];

  // 搜索
  String _searchQuery = '';

  // 学科筛选
  String? _selectedSubject;

  // 分类筛选
  String? _selectedCategory;

  // 多选模式
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  // 今日待复习数量
  int _todayReviewCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final rows = await _db.queryAllMustRemembers();
      final items = rows.map((r) => _rowToMustRemember(r)).toList();
      _items = items;

      // 计算今日待复习数量
      final now = DateTime.now();
      _todayReviewCount = items.where((item) {
        if (item.isMastered) return false;
        if (item.nextReviewTime == null) return true;
        return item.nextReviewTime! <= now.millisecondsSinceEpoch;
      }).length;

      _applyFilters();
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '加载失败: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  MustRemember _rowToMustRemember(Map<String, dynamic> r) {
    int? nextReviewTime;
    if (r['next_review_time'] != null) {
      if (r['next_review_time'] is int) {
        nextReviewTime = r['next_review_time'] as int;
      } else if (r['next_review_time'] is String) {
        nextReviewTime = DateTime.tryParse(r['next_review_time'] as String)
                ?.millisecondsSinceEpoch;
      }
    }

    int reviewInterval = 0;
    if (r['review_interval'] != null) {
      reviewInterval = r['review_interval'] is int
          ? r['review_interval'] as int
          : int.tryParse(r['review_interval'].toString()) ?? 0;
    }

    return MustRemember(
      id: r['uuid'] as String? ?? r['id'].toString(),
      title: r['title'] as String? ?? '',
      content: r['content'] as String? ?? '',
      subject: r['subject'] as String? ?? '其他',
      category: r['category'] as String? ?? '其他',
      memoryLevel: r['memory_level'] as int? ?? 0,
      nextReviewTime: nextReviewTime,
      reviewInterval: reviewInterval,
      reviewCount: r['review_count'] as int? ?? 0,
      isMastered: (r['is_mastered'] as int?) == 1,
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
    );
  }

  void _applyFilters() {
    final category = _currentTabIndex == 0
        ? null
        : _categories[_currentTabIndex];

    var result = _items.where((item) {
      if (category != null && item.category != category) return false;
      if (_selectedSubject != null && item.subject != _selectedSubject) {
        return false;
      }
      if (_selectedCategory != null && item.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!item.title.toLowerCase().contains(query) &&
            !item.content.toLowerCase().contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();

    // 排序：待复习优先，然后按更新时间倒序
    result.sort((a, b) {
      // 未掌握的排前面
      if (a.isMastered != b.isMastered) {
        return a.isMastered ? 1 : -1;
      }
      // 有待复习时间的按复习时间排
      if (a.nextReviewTime != null && b.nextReviewTime != null) {
        return a.nextReviewTime!.compareTo(b.nextReviewTime!);
      }
      // 无复习时间的排前面（新内容）
      if (a.nextReviewTime == null && b.nextReviewTime != null) return -1;
      if (a.nextReviewTime != null && b.nextReviewTime == null) return 1;
      // 最后按更新时间倒序
      return b.updatedAt.compareTo(a.updatedAt);
    });

    setState(() {
      _filteredItems = result;
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
      if (_selectedIds.length == _filteredItems.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_filteredItems.map((q) => q.id));
      }
    });
  }

  Future<void> _batchDelete() async {
    final confirmed = await AppDialog.showConfirmDelete(
      context: context,
      title: '批量删除',
      message: '确定要删除选中的 ${_selectedIds.length} 条内容吗？此操作不可撤销。',
    );
    if (confirmed != true) return;

    try {
      for (final item in _filteredItems) {
        if (_selectedIds.contains(item.id)) {
          final row = await _db.queryMustRememberByUuid(item.id);
          if (row != null) {
            await _db.deleteMustRemember(row['id'] as int);
          }
        }
      }
      showSnackBar(context, '已删除 ${_selectedIds.length} 条内容');
      _selectedIds.clear();
      _isSelectionMode = false;
      await _loadData();
    } catch (e) {
      if (mounted) showSnackBar(context, '删除失败: $e', isError: true);
    }
  }

  Future<void> _batchMarkMastered() async {
    try {
      for (final item in _filteredItems) {
        if (_selectedIds.contains(item.id)) {
          final row = await _db.queryMustRememberByUuid(item.id);
          if (row != null) {
            await _db.updateMustRemember(row['id'] as int, {
              'is_mastered': 1,
              'memory_level': 100,
            });
          }
        }
      }
      showSnackBar(context, '已标记 ${_selectedIds.length} 条为已掌握');
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

      // 获取选中的必记内容数据
      final selectedItems = _items.where((item) {
        return _selectedIds.contains(item.id);
      }).toList();

      // 构建导出数据
      final exportData = {
        'export_version': '1.0',
        'export_time': DateTime.now().toIso8601String(),
        'must_remembers': selectedItems.map((item) => item.toJson()).toList(),
      };

      // 保存到文件
      final result = await _exportService.exportAllToJson(
        fileName: 'must_remember_export_${DateTime.now().millisecondsSinceEpoch}.json',
      );

      AppLoading.hide(context);
      setState(() {
        _isSelectionMode = false;
        _selectedIds.clear();
      });

      if (result.success && mounted) {
        showSnackBar(context, '已导出 ${_selectedIds.length} 条必记内容到 ${result.fileName}');
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

    // 获取选中的必记内容数据
    final selectedItems = _items.where((item) {
      return _selectedIds.contains(item.id);
    }).toList();

    // 转换为打印内容项
    final printItems = selectedItems.map((item) {
      return PrintContentItem(
        type: PrintContentType.mustRemember,
        title: item.title.isNotEmpty ? item.title : '必背内容',
        content: item.content,
        subject: item.subject,
        category: item.category,
        masteryLevel: item.memoryLevel,
        additionalMetadata: {
          '状态': item.isMastered ? '已掌握' : '学习中',
          '复习次数': '${item.reviewCount}次',
          if (item.nextReviewTime != null)
            '下次复习': formatDate(
              DateTime.fromMillisecondsSinceEpoch(item.nextReviewTime!),
            ),
        },
      );
    }).toList();

    // 调用批量打印
    await PrintService.printBatch(
      context: context,
      items: printItems,
      customTitle: '必背必记打印 (${printItems.length}项)',
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
        title: const Text('必记必背'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final query = await showSearch<String>(
                context: context,
                delegate: _MustRememberSearchDelegate(items: _items),
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

          // 今日待复习提示
          if (_todayReviewCount > 0)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '今日有 $_todayReviewCount 条内容待复习',
                      style: TextStyle(
                        fontSize: AppFontSize.sm,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() => _currentTabIndex = 0);
                      _applyFilters();
                    },
                    child: Text(
                      '查看',
                      style: TextStyle(
                        fontSize: AppFontSize.sm,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 分类Tab
          Container(
            margin: const EdgeInsets.only(top: 12),
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final selected = _currentTabIndex == index;
                return GestureDetector(
                  onTap: () {
                    setState(() => _currentTabIndex = index);
                    _applyFilters();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest
                              .withOpacity(0.5),
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                    child: Center(
                      child: Text(
                        _categories[index],
                        style: TextStyle(
                          fontSize: AppFontSize.sm,
                          color: selected
                              ? theme.colorScheme.onPrimary
                              : AppColors.textSecondary,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 筛选状态标签
          if (_selectedSubject != null || _selectedCategory != null)
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
                        avatar: const Icon(Icons.close, size: 14),
                        label: Text('学科: $_selectedSubject'),
                        backgroundColor: getSubjectColor(_selectedSubject!).withOpacity(0.1),
                        labelStyle: TextStyle(
                          color: getSubjectColor(_selectedSubject!),
                          fontSize: AppFontSize.sm,
                        ),
                        onDeleted: () {
                          setState(() {
                            _selectedSubject = null;
                            _applyFilters();
                          });
                        },
                      ),
                    ),
                  if (_selectedCategory != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InputChip(
                        avatar: const Icon(Icons.close, size: 14),
                        label: Text('分类: $_selectedCategory'),
                        backgroundColor: _getCategoryColor(_selectedCategory!).withOpacity(0.1),
                        labelStyle: TextStyle(
                          color: _getCategoryColor(_selectedCategory!),
                          fontSize: AppFontSize.sm,
                        ),
                        onDeleted: () {
                          setState(() {
                            _selectedCategory = null;
                            _applyFilters();
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),

          // 列表
          Expanded(
            child: _isLoading
                ? const AppLoading(message: '加载中...')
                : _filteredItems.isEmpty
                    ? AppEmptyState(
                        message: '暂无内容',
                        icon: Icons.menu_book_outlined,
                        actionText: '添加内容',
                        onAction: () => _showAddScreen(),
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
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = _filteredItems[index];
                            return _buildItemCard(item, index);
                          },
                        ),
                      ),
          ),
        ],
      ),
      // 批量操作栏
      bottomNavigationBar: _isSelectionMode
          ? BatchOperationBar(
              totalCount: _filteredItems.length,
              selectedCount: _selectedIds.length,
              isAllSelected:
                  _selectedIds.length == _filteredItems.length &&
                  _filteredItems.isNotEmpty,
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
              onPressed: () => _showAddScreen(),
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildItemCard(MustRemember item, int index) {
    final theme = Theme.of(context);
    final isSelected = _selectedIds.contains(item.id);
    final isDueForReview = item.nextReviewTime != null &&
        item.nextReviewTime! <= DateTime.now().millisecondsSinceEpoch;

    return GestureDetector(
      onLongPress: () {
        if (!_isSelectionMode) {
          _toggleSelectionMode();
          _toggleSelect(item.id);
        }
      },
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelect(item.id);
        } else {
          _navigateToDetail(item);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: item.isMastered
              ? AppColors.success.withOpacity(0.04)
              : isDueForReview
                  ? AppColors.warning.withOpacity(0.04)
                  : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : item.isMastered
                    ? AppColors.success.withOpacity(0.3)
                    : isDueForReview
                        ? AppColors.warning.withOpacity(0.3)
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
                      onChanged: (_) => _toggleSelect(item.id),
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
                        if (item.isMastered)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(
                              Icons.check_circle,
                              size: 16,
                              color: AppColors.success,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            item.title,
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
                    const SizedBox(height: 6),
                    // 内容预览
                    Text(
                      item.content,
                      style: TextStyle(
                        fontSize: AppFontSize.sm,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    // 标签行
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedSubject = item.subject;
                              _applyFilters();
                            });
                          },
                          child: AppTag(
                            label: item.subject,
                            color: getSubjectColor(item.subject),
                            dense: true,
                            fontSize: AppFontSize.xs,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory = item.category;
                              _applyFilters();
                            });
                          },
                          child: AppTag(
                            label: item.category,
                            color: _getCategoryColor(item.category),
                            dense: true,
                            fontSize: AppFontSize.xs,
                          ),
                        ),
                        const Spacer(),
                        if (isDueForReview && !item.isMastered)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '待复习',
                              style: TextStyle(
                                fontSize: AppFontSize.xs,
                                color: AppColors.warning,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 记忆程度进度条
                    MasteryProgressBar(
                      mastery: item.memoryLevel,
                      height: 6,
                      showLabel: false,
                    ),
                    const SizedBox(height: 4),
                    // 底部信息
                    Row(
                      children: [
                        Text(
                          '记忆程度 ${item.memoryLevel}%',
                          style: TextStyle(
                            fontSize: AppFontSize.xs,
                            color: AppColors.textHint,
                          ),
                        ),
                        const Spacer(),
                        if (item.nextReviewTime != null && !item.isMastered)
                          Text(
                            _formatNextReview(item.nextReviewTime!),
                            style: TextStyle(
                              fontSize: AppFontSize.xs,
                              color: isDueForReview
                                  ? AppColors.warning
                                  : AppColors.textHint,
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

  String _formatNextReview(int timestamp) {
    final now = DateTime.now();
    final reviewTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final diff = reviewTime.difference(now);

    if (diff.isNegative) {
      return '已到期';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟后';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时后';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天后';
    } else {
      return formatDate(reviewTime);
    }
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
            setState(() => _selectedSubject = null);
            _applyFilters();
          }),
          const SizedBox(width: 8),
          // 各学科选项
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

  Color _getCategoryColor(String category) {
    switch (category) {
      case '公式':
        return const Color(0xFF1E88E5);
      case '单词':
        return const Color(0xFF43A047);
      case '概念':
        return const Color(0xFFFB8C00);
      case '定理':
        return const Color(0xFF8E24AA);
      case '其他':
        return const Color(0xFF757575);
      default:
        return AppColors.textSecondary;
    }
  }

  void _navigateToDetail(MustRemember item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MustRememberDetailScreen(
          item: item,
          onUpdated: () => _loadData(),
          onDeleted: () => _loadData(),
        ),
      ),
    );
  }

  Future<void> _showAddScreen() async {
    // 显示录入方式选择器
    final method = await InputMethodSelector.show(context);
    if (method == null) return;

    // 处理录入方式
    final handler = InputMethodHandler(context);
    final recognizedText = await handler.handleInputMethod(method);

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MustRememberAddScreen(
          initialContent: recognizedText,
        ),
      ),
    );
    if (result == true) _loadData();
  }
}

// ============================================================
// _MustRememberSearchDelegate - 搜索代理
// ============================================================

class _MustRememberSearchDelegate extends SearchDelegate<String> {
  final List<MustRemember> items;

  _MustRememberSearchDelegate({required this.items});

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
          '输入关键词搜索',
          style: TextStyle(color: AppColors.textHint),
        ),
      );
    }

    final filtered = items.where((item) {
      final q = query.toLowerCase();
      return item.title.toLowerCase().contains(q) ||
          item.content.toLowerCase().contains(q);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          '未找到匹配的内容',
          style: TextStyle(color: AppColors.textHint),
        ),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        return ListTile(
          title: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${item.subject} - ${item.category}',
          ),
          trailing: item.isMastered
              ? Icon(Icons.check_circle, color: AppColors.success, size: 20)
              : null,
          onTap: () => close(context, query),
        );
      },
    );
  }
}

// ============================================================
// MustRememberDetailScreen - 详情/学习模式页面
// ============================================================

class MustRememberDetailScreen extends StatefulWidget {
  final MustRemember item;
  final VoidCallback? onUpdated;
  final VoidCallback? onDeleted;

  const MustRememberDetailScreen({
    super.key,
    required this.item,
    this.onUpdated,
    this.onDeleted,
  });

  @override
  State<MustRememberDetailScreen> createState() =>
      _MustRememberDetailScreenState();
}

class _MustRememberDetailScreenState extends State<MustRememberDetailScreen> {
  late MustRemember _item;
  final DatabaseService _db = DatabaseService();

  bool _showAnswer = false;
  int _selfRating = 0; // 1-5星自评

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  /// 艾宾浩斯遗忘曲线计算下次复习时间
  /// 根据自评星级(1-5)映射到不同复习间隔
  int _calculateNextReviewInterval(int rating) {
    // 艾宾浩斯遗忘曲线间隔（秒）
    // rating 1: 5分钟, 2: 30分钟, 3: 12小时, 4: 1天, 5: 2天
    switch (rating) {
      case 1:
        return 5 * 60; // 5分钟
      case 2:
        return 30 * 60; // 30分钟
      case 3:
        return 12 * 3600; // 12小时
      case 4:
        return 24 * 3600; // 1天
      case 5:
        return 2 * 24 * 3600; // 2天
      default:
        return 24 * 3600;
    }
  }

  /// 根据复习次数和自评计算记忆程度
  int _calculateMemoryLevel(int reviewCount, int rating) {
    // 基础记忆程度随复习次数增长
    int baseLevel;
    if (reviewCount == 0) {
      baseLevel = 0;
    } else if (reviewCount == 1) {
      baseLevel = 20;
    } else if (reviewCount == 2) {
      baseLevel = 40;
    } else if (reviewCount <= 4) {
      baseLevel = 60;
    } else if (reviewCount <= 6) {
      baseLevel = 75;
    } else {
      baseLevel = 85;
    }

    // 根据自评调整
    final bonus = rating * 3;
    return (baseLevel + bonus).clamp(0, 100);
  }

  Future<void> _submitReview() async {
    if (_selfRating == 0) {
      showSnackBar(context, '请先自评记忆程度', isError: true);
      return;
    }

    try {
      final row = await _db.queryMustRememberByUuid(_item.id);
      if (row == null) return;

      final newReviewCount = _item.reviewCount + 1;
      final interval = _calculateNextReviewInterval(_selfRating);
      final newMemoryLevel = _calculateMemoryLevel(newReviewCount, _selfRating);
      final nextReviewTime =
          DateTime.now().millisecondsSinceEpoch + interval;

      // 如果记忆程度达到100，自动标记为已掌握
      final isMastered = newMemoryLevel >= 100;

      await _db.updateMustRemember(row['id'] as int, {
        'memory_level': newMemoryLevel,
        'review_count': newReviewCount,
        'review_interval': interval,
        'next_review_time':
            DateTime.fromMillisecondsSinceEpoch(nextReviewTime)
                .toIso8601String(),
        'last_review_time': DateTime.now().toIso8601String(),
        'is_mastered': isMastered ? 1 : 0,
      });

      setState(() {
        _item = _item.copyWith(
          memoryLevel: newMemoryLevel,
          reviewCount: newReviewCount,
          reviewInterval: interval,
          nextReviewTime: nextReviewTime,
          isMastered: isMastered,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        _selfRating = 0;
        _showAnswer = false;
      });

      widget.onUpdated?.call();
      showSnackBar(
        context,
        isMastered ? '已掌握，太棒了！' : '复习完成，下次复习时间已更新',
      );
    } catch (e) {
      if (mounted) showSnackBar(context, '操作失败: $e', isError: true);
    }
  }

  Future<void> _toggleMastered() async {
    try {
      final row = await _db.queryMustRememberByUuid(_item.id);
      if (row == null) return;

      final newMastered = !_item.isMastered;
      await _db.updateMustRemember(row['id'] as int, {
        'is_mastered': newMastered ? 1 : 0,
        'memory_level': newMastered ? 100 : _item.memoryLevel,
      });

      setState(() {
        _item = _item.copyWith(
          isMastered: newMastered,
          memoryLevel: newMastered ? 100 : _item.memoryLevel,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
      });

      widget.onUpdated?.call();
      showSnackBar(
        context,
        newMastered ? '已标记为已掌握' : '已取消掌握标记',
      );
    } catch (e) {
      if (mounted) showSnackBar(context, '操作失败: $e', isError: true);
    }
  }

  Future<void> _deleteItem() async {
    final confirmed = await AppDialog.showConfirmDelete(
      context: context,
      message: '确定要删除这条内容吗？此操作不可撤销。',
    );
    if (confirmed != true) return;

    try {
      final row = await _db.queryMustRememberByUuid(_item.id);
      if (row != null) {
        await _db.deleteMustRemember(row['id'] as int);
      }
      widget.onDeleted?.call();
      if (mounted) Navigator.of(context).pop();
      showSnackBar(context, '已删除');
    } catch (e) {
      if (mounted) showSnackBar(context, '删除失败: $e', isError: true);
    }
  }

  void _editItem() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MustRememberAddScreen(item: _item),
      ),
    );
    if (result == true) {
      widget.onUpdated?.call();
      Navigator.of(context).pop();
    }
  }

  /// 转为题目功能
  void _convertToQuestion() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => _ConvertToQuestionSheet(
        item: _item,
        onConverted: () {
          widget.onUpdated?.call();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_item.isMastered ? '详情 (已掌握)' : '学习模式'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            onPressed: () => PrintService.printMustRemember(
              context: context,
              title: _item.title,
              content: _item.content,
              subject: _item.subject,
              category: _item.category,
              memoryLevel: _item.memoryLevel,
              reviewCount: _item.reviewCount,
              nextReviewTime: _item.nextReviewTime != null
                  ? formatDate(DateTime.fromMillisecondsSinceEpoch(_item.nextReviewTime!))
                  : null,
              isMastered: _item.isMastered,
              createdAt: formatDate(DateTime.fromMillisecondsSinceEpoch(_item.createdAt)),
            ),
            tooltip: '打印',
          ),
          IconButton(
            icon: Icon(
              _item.isMastered
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: _item.isMastered ? AppColors.success : null,
            ),
            onPressed: _toggleMastered,
            tooltip: _item.isMastered ? '取消掌握' : '标记已掌握',
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _editItem,
            tooltip: '编辑',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteItem,
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
                  label: _item.subject,
                  color: getSubjectColor(_item.subject),
                ),
                const SizedBox(width: 8),
                AppTag(
                  label: _item.category,
                  color: _getCategoryColor(_item.category),
                ),
                const SizedBox(width: 8),
                AppTag(
                  label: '复习${_item.reviewCount}次',
                  color: AppColors.info,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 标题
            Text(
              _item.title,
              style: TextStyle(
                fontSize: AppFontSize.xxl,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // 记忆程度进度条
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '记忆程度',
                        style: TextStyle(
                          fontSize: AppFontSize.sm,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '${_item.memoryLevel}%',
                        style: TextStyle(
                          fontSize: AppFontSize.sm,
                          fontWeight: FontWeight.w700,
                          color: getMasteryColor(_item.memoryLevel),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  MasteryProgressBar(
                    mastery: _item.memoryLevel,
                    height: 10,
                    showLabel: false,
                  ),
                  if (_item.nextReviewTime != null && !_item.isMastered) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '下次复习: ${_formatNextReview(_item.nextReviewTime!)}',
                          style: TextStyle(
                            fontSize: AppFontSize.xs,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 内容区域（先隐藏答案）
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.04),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '内容',
                    style: TextStyle(
                      fontSize: AppFontSize.sm,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_showAnswer)
                    Text(
                      _item.content,
                      style: TextStyle(
                        fontSize: AppFontSize.lg,
                        color: AppColors.textPrimary,
                        height: 1.8,
                      ),
                    )
                  else
                    Column(
                      children: [
                        Container(
                          height: 60,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.divider.withOpacity(0.3),
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '内容已隐藏，点击下方按钮查看',
                            style: TextStyle(
                              fontSize: AppFontSize.sm,
                              color: AppColors.textHint,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 显示答案按钮
            if (!_showAnswer)
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  text: '显示答案',
                  icon: Icons.visibility,
                  style: AppButtonStyle.primary,
                  onPressed: () {
                    setState(() => _showAnswer = true);
                  },
                ),
              ),

            // 自评记忆程度（显示答案后）
            if (_showAnswer) ...[
              const SizedBox(height: 16),
              Text(
                '自评记忆程度',
                style: TextStyle(
                  fontSize: AppFontSize.md,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '请根据你回忆内容的准确程度打分',
                style: TextStyle(
                  fontSize: AppFontSize.sm,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final star = index + 1;
                  final isSelected = _selfRating >= star;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selfRating = star);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        isSelected
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 40,
                        color: isSelected
                            ? AppColors.warning
                            : AppColors.divider,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                _getRatingDescription(_selfRating),
                style: TextStyle(
                  fontSize: AppFontSize.sm,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  text: '提交复习',
                  icon: Icons.check,
                  style: AppButtonStyle.primary,
                  enabled: _selfRating > 0,
                  onPressed: _submitReview,
                ),
              ),
            ],

            const SizedBox(height: 16),

            // 底部操作
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: _item.isMastered ? '取消掌握' : '标记已掌握',
                    icon: _item.isMastered
                        ? Icons.radio_button_unchecked
                        : Icons.emoji_events,
                    style: AppButtonStyle.outlined,
                    onPressed: _toggleMastered,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    text: '编辑',
                    icon: Icons.edit_outlined,
                    style: AppButtonStyle.secondary,
                    onPressed: _editItem,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 转为题目按钮
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: '转为题目',
                icon: Icons.transform,
                style: AppButtonStyle.outlined,
                onPressed: _convertToQuestion,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingDescription(int rating) {
    switch (rating) {
      case 0:
        return '';
      case 1:
        return '完全想不起来';
      case 2:
        return '只记得一点点';
      case 3:
        return '记得大部分，有些模糊';
      case 4:
        return '基本都记得';
      case 5:
        return '完全记住，倒背如流';
      default:
        return '';
    }
  }

  String _formatNextReview(int timestamp) {
    final now = DateTime.now();
    final reviewTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final diff = reviewTime.difference(now);

    if (diff.isNegative) {
      return '已到期，请尽快复习';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟后';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时后';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天后';
    } else {
      return formatDate(reviewTime);
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case '公式':
        return const Color(0xFF1E88E5);
      case '单词':
        return const Color(0xFF43A047);
      case '概念':
        return const Color(0xFFFB8C00);
      case '定理':
        return const Color(0xFF8E24AA);
      case '其他':
        return const Color(0xFF757575);
      default:
        return AppColors.textSecondary;
    }
  }
}

// ============================================================
// _ConvertToQuestionSheet - 转为题目底部弹出组件
// ============================================================

class _ConvertToQuestionSheet extends StatefulWidget {
  final MustRemember item;
  final VoidCallback? onConverted;

  const _ConvertToQuestionSheet({
    required this.item,
    this.onConverted,
  });

  @override
  State<_ConvertToQuestionSheet> createState() => _ConvertToQuestionSheetState();
}

class _ConvertToQuestionSheetState extends State<_ConvertToQuestionSheet> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  final TextEditingController _analysisController = TextEditingController();

  String _questionType = 'fillBlank'; // fillBlank, choice, shortAnswer
  String _targetTable = 'mother'; // mother, wrong
  bool _isSaving = false;

  // 选择题选项
  List<String> _choiceOptions = [];
  String? _correctOption; // 正确选项（从选项列表中选择）

  @override
  void initState() {
    super.initState();
    _initChoiceOptions();
    _autoGenerateQuestion();
  }

  /// 初始化选择题选项
  void _initChoiceOptions() {
    _choiceOptions = ['A. ', 'B. ', 'C. ', 'D. '];
    _correctOption = null;
  }

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    _analysisController.dispose();
    super.dispose();
  }

  /// 切换题目类型时重置选项
  void _onQuestionTypeChanged(String newType) {
    setState(() {
      _questionType = newType;
      if (newType == 'choice') {
        _initChoiceOptions();
        // 用当前内容填充第一个选项作为正确答案
        if (_choiceOptions.isNotEmpty) {
          _choiceOptions[0] = 'A. ${_answerController.text.trim()}';
          _correctOption = 'A';
        }
      }
    });
  }

  /// 更新选择题选项
  void _updateChoiceOption(int index, String value) {
    if (index >= 0 && index < _choiceOptions.length) {
      final prefix = String.fromCharCode(65 + index); // A, B, C, D
      setState(() {
        _choiceOptions[index] = '$prefix. $value';
      });
    }
  }

  /// 随机打乱选项顺序（同时保持正确答案对应）
  void _shuffleOptions() {
    setState(() {
      // 创建带标记的选项
      final indexedOptions = <MapEntry<int, String>>[];
      for (int i = 0; i < _choiceOptions.length; i++) {
        indexedOptions.add(MapEntry(i, _choiceOptions[i]));
      }

      // 打乱
      indexedOptions.shuffle();

      // 更新选项
      _choiceOptions = indexedOptions.map((e) => e.value).toList();

      // 更新正确答案标记
      final correctIndex = _correctOption != null
          ? _correctOption!.codeUnitAt(0) - 65
          : 0;
      // 找到正确答案在新位置
      int newCorrectIndex = 0;
      for (int i = 0; i < indexedOptions.length; i++) {
        if (indexedOptions[i].key == correctIndex) {
          newCorrectIndex = i;
          break;
        }
      }
      _correctOption = String.fromCharCode(65 + newCorrectIndex);
    });
  }

  /// 自动生成题目
  void _autoGenerateQuestion() {
    final content = widget.item.content;

    // 尝试将"xxx是yyy"格式转换为填空题
    final patterns = [
      // 匹配 "A是B" 格式
      RegExp(r'(.+?)是(.+?)(?=，|。|；|$)'),
      // 匹配 "A为B" 格式
      RegExp(r'(.+?)为(.+?)(?=，|。|；|$)'),
      // 匹配 "A等于B" 格式
      RegExp(r'(.+?)等于(.+?)(?=，|。|；|$)'),
      // 匹配 "A叫做B" 格式
      RegExp(r'(.+?)叫做(.+?)(?=，|。|；|$)'),
      // 匹配 "A称为B" 格式
      RegExp(r'(.+?)称为(.+?)(?=，|。|；|$)'),
    ];

    String? questionText;
    String? answerText;
    String? correctChoice; // 正确答案（选择题用）

    for (final pattern in patterns) {
      final match = pattern.firstMatch(content);
      if (match != null) {
        final subject = match.group(1)?.trim() ?? '';
        final object = match.group(2)?.trim() ?? '';

        // 生成填空题
        questionText = '$subject是______。';
        answerText = object;

        // 选择题：生成4个选项
        if (_questionType == 'choice') {
          // 正确答案是 object
          _choiceOptions = [
            'A. $object',
            'B. ___干扰选项1___',
            'C. ___干扰选项2___',
            'D. ___干扰选项3___',
          ];
          _correctOption = 'A';
          correctChoice = 'A';
        }
        break;
      }
    }

    // 如果没有匹配到特定模式，使用整个内容作为答案
    if (questionText == null) {
      // 尝试提取关键词
      if (content.length > 20) {
        // 内容较长，取前20个字符作为问题提示
        questionText = '${content.substring(0, 20)}...（请填写完整内容）';
        answerText = content;
      } else {
        questionText = '请填写以下内容：______';
        answerText = content;
      }

      // 选择题：使用整个内容作为正确答案
      if (_questionType == 'choice') {
        _choiceOptions = [
          'A. $content',
          'B. ___干扰选项1___',
          'C. ___干扰选项2___',
          'D. ___干扰选项3___',
        ];
        _correctOption = 'A';
        correctChoice = 'A';
      }
    }

    // 更新题目类型时也要生成选择题选项
    if (_questionType == 'choice' && _choiceOptions[0].contains('___')) {
      // 还没生成过选择题选项
      _generateDistractors(answerText ?? content);
    }

    setState(() {
      _questionController.text = questionText ?? '';
      _answerController.text = answerText ?? '';
      _analysisController.text = '来源：必背必记 - ${widget.item.title}';
    });
  }

  /// 生成干扰选项（选择题用）
  void _generateDistractors(String correctAnswer) {
    // 从正确答案生成一些合理的干扰选项
    // 这里使用简单的策略：在正确答案前后添加"不"、换词等方式生成干扰项

    final distractors = <String>[];

    // 策略1：否定形式（如果适用）
    if (!correctAnswer.contains('不')) {
      distractors.add('不$correctAnswer');
    }

    // 策略2：截取部分内容
    if (correctAnswer.length > 3) {
      distractors.add(correctAnswer.substring(0, correctAnswer.length ~/ 2));
    }

    // 策略3：添加常见错误后缀
    distractors.add('$correctAnswer的变体');
    distractors.add('与$correctAnswer无关');

    // 随机选择一些干扰项填入
    _choiceOptions = [
      'A. $correctAnswer',
      'B. ${distractors.isNotEmpty ? distractors[0] : "___干扰选项1___"}',
      'C. ${distractors.length > 1 ? distractors[1] : "___干扰选项2___"}',
      'D. ${distractors.length > 2 ? distractors[2] : "___干扰选项3___"}',
    ];
    _correctOption = 'A';
  }

  /// 获取格式化的选项文本（用于保存）
  String _getFormattedOptions() {
    return _choiceOptions.join('\n');
  }

  /// 获取正确选项对应的文本
  String _getCorrectAnswerText() {
    if (_correctOption == null) return '';
    final index = _correctOption!.codeUnitAt(0) - 65;
    if (index >= 0 && index < _choiceOptions.length) {
      // 去掉前缀 "A. " 等
      final option = _choiceOptions[index];
      if (option.contains('. ')) {
        return option.substring(option.indexOf('. ') + 2);
      }
      return option;
    }
    return '';
  }

  Future<void> _saveQuestion() async {
    if (_questionController.text.trim().isEmpty) {
      showSnackBar(context, '请输入题目内容', isError: true);
      return;
    }

    // 选择题需要验证选项
    if (_questionType == 'choice') {
      // 检查选项是否都已填写
      final hasEmptyOption = _choiceOptions.any((opt) {
        final value = opt.contains('. ')
            ? opt.substring(opt.indexOf('. ') + 2)
            : opt;
        return value.trim().isEmpty || value.contains('___');
      });

      if (hasEmptyOption) {
        showSnackBar(context, '请填写完整的选项内容', isError: true);
        return;
      }
    }

    if (_answerController.text.trim().isEmpty) {
      showSnackBar(context, '请输入答案', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now().toIso8601String();

      // 确定保存的答案内容
      String savedAnswer;
      String? savedOptions;

      if (_questionType == 'choice') {
        // 选择题：保存选项和正确答案
        savedOptions = _getFormattedOptions();
        savedAnswer = _correctOption != null
            ? _getCorrectAnswerText()
            : _answerController.text.trim();
      } else {
        // 填空题和简答题
        savedAnswer = _answerController.text.trim();
      }

      if (_targetTable == 'mother') {
        // 保存到母题表
        final data = {
          'uuid': DateTime.now().millisecondsSinceEpoch.toString(),
          'title': widget.item.title,
          'question_content': _questionController.text.trim(),
          'question_type': _questionType == 'choice'
              ? 'singleChoice'
              : (_questionType == 'fillBlank' ? 'fillBlank' : 'shortAnswer'),
          'correct_answer': savedAnswer,
          if (savedOptions != null) 'options': savedOptions,
          'analysis': _analysisController.text.trim(),
          'subject': widget.item.subject,
          'category': widget.item.category,
          'difficulty': 2,
          'variant_count': 0,
          'mastery_level': 0,
          'practice_count': 0,
          'is_favorite': 0,
          'tags': widget.item.title,
          'created_at': now,
          'updated_at': now,
        };
        await _db.insertMotherQuestion(data);
      } else {
        // 保存到错题表
        final data = {
          'uuid': DateTime.now().millisecondsSinceEpoch.toString(),
          'title': widget.item.title,
          'question_content': _questionController.text.trim(),
          'correct_answer': savedAnswer,
          if (savedOptions != null) 'options': savedOptions,
          'analysis': _analysisController.text.trim(),
          'subject': widget.item.subject,
          'error_type': '知识盲区',
          'error_count': 0,
          'is_mastered': 0,
          'created_at': now,
          'updated_at': now,
        };
        await _db.insertWrongQuestion(data);
      }

      if (mounted) {
        showSnackBar(context, '已保存到${_targetTable == 'mother' ? '母题集' : '错题本'}');
        Navigator.of(context).pop();
        widget.onConverted?.call();
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

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Icon(Icons.transform, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '转为题目',
                  style: TextStyle(
                    fontSize: AppFontSize.xl,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 原内容预览
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '原内容',
                    style: TextStyle(
                      fontSize: AppFontSize.xs,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.item.content,
                    style: TextStyle(
                      fontSize: AppFontSize.sm,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
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
                _buildTypeChip('填空题', 'fillBlank'),
                _buildTypeChip('选择题', 'choice'),
                _buildTypeChip('简答题', 'shortAnswer'),
              ],
            ),
            const SizedBox(height: 16),

            // 保存位置选择
            Text(
              '保存到',
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
                _buildTargetChip('母题集', 'mother'),
                _buildTargetChip('错题本', 'wrong'),
              ],
            ),
            const SizedBox(height: 16),

            // 题目内容
            AppInput(
              label: '题目内容',
              hintText: '输入题目...',
              controller: _questionController,
              multiline: true,
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // 选择题选项区域
            if (_questionType == 'choice') ...[
              Row(
                children: [
                  Text(
                    '选项设置',
                    style: TextStyle(
                      fontSize: AppFontSize.md,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _shuffleOptions,
                    icon: const Icon(Icons.shuffle, size: 18),
                    label: const Text('打乱选项'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 正确选项选择
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '请选择正确答案',
                      style: TextStyle(
                        fontSize: AppFontSize.sm,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildCorrectOptionChip('A', 0),
                        _buildCorrectOptionChip('B', 1),
                        _buildCorrectOptionChip('C', 2),
                        _buildCorrectOptionChip('D', 3),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // 选项输入
              ..._buildChoiceOptionInputs(),
              const SizedBox(height: 16),
            ],

            // 填空题和简答题的答案输入
            if (_questionType != 'choice') ...[
              AppInput(
                label: _questionType == 'fillBlank' ? '答案' : '参考答案',
                hintText: _questionType == 'fillBlank'
                    ? '输入答案...'
                    : '输入参考答案...',
                controller: _answerController,
                multiline: true,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
            ],

            // 解析
            AppInput(
              label: '解析（选填）',
              hintText: '输入解析...',
              controller: _analysisController,
              multiline: true,
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // 保存按钮
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: '保存题目',
                icon: Icons.save,
                style: AppButtonStyle.primary,
                isLoading: _isSaving,
                onPressed: _saveQuestion,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label, String value) {
    final theme = Theme.of(context);
    final selected = _questionType == value;
    
    return GestureDetector(
      onTap: () => setState(() => _questionType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppFontSize.sm,
            color: selected ? theme.colorScheme.onPrimary : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildTargetChip(String label, String value) {
    final theme = Theme.of(context);
    final selected = _targetTable == value;

    return GestureDetector(
      onTap: () => setState(() => _targetTable = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppFontSize.sm,
            color: selected ? theme.colorScheme.onPrimary : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  /// 构建正确选项选择按钮
  Widget _buildCorrectOptionChip(String label, int index) {
    final isSelected = _correctOption == label;

    return GestureDetector(
      onTap: () {
        setState(() {
          _correctOption = label;
          // 同时更新答案文本框
          _answerController.text = _getCorrectAnswerText();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green : Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: Colors.green,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              size: 18,
              color: isSelected ? Colors.white : Colors.green,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: AppFontSize.md,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建选择题选项输入框列表
  List<Widget> _buildChoiceOptionInputs() {
    return List.generate(_choiceOptions.length, (index) {
      final prefix = String.fromCharCode(65 + index); // A, B, C, D
      final optionText = _choiceOptions[index];
      final value = optionText.contains('. ')
          ? optionText.substring(optionText.indexOf('. ') + 2)
          : optionText;

      // 为每个选项创建控制器
      final controller = TextEditingController(text: value);
      controller.addListener(() {
        _updateChoiceOption(index, controller.text);
        // 如果是正确答案，同时更新答案文本
        if (_correctOption == prefix) {
          _answerController.text = controller.text;
        }
      });

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _correctOption == prefix
                    ? Colors.green
                    : Colors.grey.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                prefix,
                style: TextStyle(
                  fontSize: AppFontSize.sm,
                  fontWeight: FontWeight.bold,
                  color: _correctOption == prefix
                      ? Colors.white
                      : Colors.grey[700],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: '输入选项$prefix...',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: AppFontSize.sm,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                style: TextStyle(
                  fontSize: AppFontSize.sm,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ============================================================
// MustRememberAddScreen - 添加/编辑必记内容页面
// ============================================================

class MustRememberAddScreen extends StatefulWidget {
  final MustRemember? item;
  final String? initialContent;

  const MustRememberAddScreen({super.key, this.item, this.initialContent});

  @override
  State<MustRememberAddScreen> createState() =>
      _MustRememberAddScreenState();
}

class _MustRememberAddScreenState extends State<MustRememberAddScreen> {
  final DatabaseService _db = DatabaseService();
  final OcrService _ocrService = OcrService();
  final VoiceService _voiceService = VoiceService();
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _chapterController = TextEditingController();

  String _subject = '数学';
  String _category = '公式';
  List<String> _examMethods = [];
  List<String> _keyPoints = [];

  bool _isSaving = false;
  bool _isOcrLoading = false;
  bool _isVoiceListening = false;

  // 已有的考法考点选项
  List<String> _existingExamMethods = [];
  List<String> _existingKeyPoints = [];

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _titleController.text = widget.item!.title;
      _contentController.text = widget.item!.content;
      _subject = widget.item!.subject;
      _chapterController.text = widget.item!.chapter ?? '';
      _category = widget.item!.category;
      _examMethods = widget.item!.examMethods;
      _keyPoints = widget.item!.keyPoints;
    } else if (widget.initialContent != null) {
      // 如果是通过OCR或语音录入的内容
      _contentController.text = widget.initialContent!;
    }
    _loadExistingExamMethodsAndKeyPoints();
  }

  Future<void> _loadExistingExamMethodsAndKeyPoints() async {
    // 从数据库加载已有的考法考点作为选项
    final items = await _db.queryAllMustRemembers(limit: 100);
    final Set<String> examMethodsSet = {};
    final Set<String> keyPointsSet = {};

    for (final item in items) {
      final em = item['exam_methods'];
      final kp = item['key_points'];
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
    _voiceService.dispose();
    super.dispose();
  }

  Future<void> _startVoiceInput() async {
    try {
      final initialized = await _voiceService.initialize();
      if (!initialized) {
        showSnackBar(context, '语音识别初始化失败', isError: true);
        return;
      }

      setState(() => _isVoiceListening = true);
      showSnackBar(context, '开始语音输入，请说话...');

      _voiceService.onFinalResult = (text) {
        if (mounted) {
          setState(() {
            _contentController.text += text;
            _isVoiceListening = false;
          });
          showSnackBar(context, '语音输入完成');
        }
      };

      _voiceService.onError = (error) {
        if (mounted) {
          setState(() => _isVoiceListening = false);
          showSnackBar(context, error, isError: true);
        }
      };

      await _voiceService.startListening();
    } catch (e) {
      setState(() => _isVoiceListening = false);
      if (mounted) showSnackBar(context, '语音输入失败: $e', isError: true);
    }
  }

  Future<void> _stopVoiceInput() async {
    await _voiceService.stopListening();
    setState(() => _isVoiceListening = false);
  }

  Future<void> _pickImageForOcr() async {
    // Linux平台不支持相机功能，使用相册选择
    if (Platform.isLinux) {
      try {
        final picked = await _imagePicker.pickImage(
          source: ImageSource.gallery,
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
      return;
    }

    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
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

  /// 艾宾浩斯遗忘曲线计算下次复习时间
  /// 新内容首次复习间隔为1天
  int _calculateInitialReviewInterval() {
    // 首次学习后1天进行第一次复习
    return 24 * 3600; // 1天（秒）
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      showSnackBar(context, '请输入标题', isError: true);
      return;
    }
    if (_contentController.text.trim().isEmpty) {
      showSnackBar(context, '请输入内容', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final data = <String, dynamic>{
        'uuid': widget.item?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'subject': _subject,
        'chapter': _chapterController.text.trim().isEmpty ? null : _chapterController.text.trim(),
        'category': _category,
        'memory_level': widget.item?.memoryLevel ?? 0,
        'review_count': widget.item?.reviewCount ?? 0,
        'review_interval': widget.item?.reviewInterval ?? 0,
        'next_review_time': widget.item?.nextReviewTime != null
            ? DateTime.fromMillisecondsSinceEpoch(
                    widget.item!.nextReviewTime!)
                .toIso8601String()
            : null,
        'is_mastered': widget.item?.isMastered == true ? 1 : 0,
        'exam_methods': jsonEncode(_examMethods),
        'key_points': jsonEncode(_keyPoints),
      };

      // 如果是新添加的内容，按艾宾浩斯遗忘曲线计算首次复习时间
      if (widget.item == null) {
        final interval = _calculateInitialReviewInterval();
        final nextReviewTime = now.add(Duration(seconds: interval));
        data['next_review_time'] = nextReviewTime.toIso8601String();
        data['review_interval'] = interval;
      }

      if (widget.item != null) {
        final row = await _db.queryMustRememberByUuid(widget.item!.id);
        if (row != null) {
          await _db.updateMustRemember(row['id'] as int, data);
        }
      } else {
        await _db.insertMustRemember(data);
      }

      if (mounted) {
        showSnackBar(context, widget.item != null ? '已更新' : '已添加');
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
    final isEdit = widget.item != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '编辑内容' : '添加内容'),
        actions: [
          if (_isOcrLoading || _isVoiceListening)
            const Padding(
              padding: EdgeInsets.all(12),
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
              label: '标题',
              hintText: '如：勾股定理、二次公式...',
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

            // 章节输入
            AppInput(
              controller: _chapterController,
              label: '章节（选填）',
              hintText: '如：第三章 函数',
              prefixIcon: Icons.book_outlined,
            ),
            const SizedBox(height: 16),

            // 分类选择
            _buildSectionTitle('分类'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['公式', '单词', '概念', '定理', '其他'].map((cat) {
                final selected = _category == cat;
                return AppTag(
                  label: cat,
                  color: _getCategoryColor(cat),
                  selected: selected,
                  onTap: () => setState(() => _category = cat),
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

            // 内容输入
            _buildSectionTitle('内容'),
            const SizedBox(height: 8),
            // 特殊符号选择栏
            CompactSymbolBar(controller: _contentController),
            const SizedBox(height: 8),
            AppInput(
              hintText: '请输入需要记忆的内容...\n支持公式和特殊符号',
              controller: _contentController,
              multiline: true,
              maxLines: 8,
            ),
            const SizedBox(height: 8),

            // OCR和语音录入按钮
            Row(
              children: [
                TextButton.icon(
                  onPressed: _isOcrLoading ? null : _pickImageForOcr,
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: Text(Platform.isLinux ? '从相册识别' : 'OCR识别'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _isVoiceListening
                      ? _stopVoiceInput
                      : (_isOcrLoading ? null : _startVoiceInput),
                  icon: Icon(
                    _isVoiceListening
                        ? Icons.mic_off
                        : Icons.mic,
                    size: 18,
                    color: _isVoiceListening ? AppColors.error : null,
                  ),
                  label: Text(_isVoiceListening ? '停止录音' : '语音录入'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 保存按钮
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: isEdit ? '保存修改' : '添加内容',
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

  Color _getCategoryColor(String category) {
    switch (category) {
      case '公式':
        return const Color(0xFF1E88E5);
      case '单词':
        return const Color(0xFF43A047);
      case '概念':
        return const Color(0xFFFB8C00);
      case '定理':
        return const Color(0xFF8E24AA);
      case '其他':
        return const Color(0xFF757575);
      default:
        return AppColors.textSecondary;
    }
  }
}
