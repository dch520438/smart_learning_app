import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/database_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';

// ============================================================
// SearchScreen - 全局搜索页面
// ============================================================

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // 搜索历史
  List<String> _recentSearches = [];
  static const String _kSearchHistoryKey = 'search_history';
  static const int _kMaxHistoryCount = 10;

  // 搜索状态
  bool _isSearching = false;
  String _currentQuery = '';
  Map<String, List<Map<String, dynamic>>> _searchResults = {};

  // 当前选中的Tab
  int _currentTab = 0;

  // Tab定义
  static const List<_SearchTab> _tabs = [
    _SearchTab(label: '全部', type: null),
    _SearchTab(label: '知识点', type: 'knowledge_points'),
    _SearchTab(label: '笔记', type: 'notes'),
    _SearchTab(label: '错题', type: 'wrong_questions'),
    _SearchTab(label: '母题', type: 'mother_questions'),
    _SearchTab(label: '必记必背', type: 'must_remembers'),
  ];

  // 防抖计时器
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    // 自动聚焦搜索框
    Future.delayed(const Duration(milliseconds: 100), () {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // ---- 搜索历史管理 ----

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches = prefs.getStringList(_kSearchHistoryKey) ?? [];
    });
  }

  Future<void> _addSearchHistory(String query) async {
    if (query.trim().isEmpty) return;
    final trimmed = query.trim();
    final updated = [trimmed, ..._recentSearches.where((s) => s != trimmed)];
    if (updated.length > _kMaxHistoryCount) {
      updated.removeRange(_kMaxHistoryCount, updated.length);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kSearchHistoryKey, updated);
    setState(() => _recentSearches = updated);
  }

  Future<void> _clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSearchHistoryKey);
    setState(() => _recentSearches = []);
  }

  Future<void> _removeSearchHistoryItem(String item) async {
    final updated = _recentSearches.where((s) => s != item).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kSearchHistoryKey, updated);
    setState(() => _recentSearches = updated);
  }

  // ---- 搜索逻辑 ----

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _currentQuery = '';
        _searchResults = {};
        _isSearching = false;
      });
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;
    setState(() {
      _isSearching = true;
      _currentQuery = query;
    });

    try {
      final results = await _db.searchByKeyword(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
      await _addSearchHistory(query);
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) showSnackBar(context, '搜索失败', isError: true);
    }
  }

  void _onSearchSubmitted(String query) {
    _debounceTimer?.cancel();
    _performSearch(query.trim());
  }

  // ---- 获取当前Tab的结果 ----

  List<Map<String, dynamic>> _getTabResults() {
    if (_currentTab == 0) {
      // 全部 - 合并所有结果
      final all = <Map<String, dynamic>>[];
      for (final entries in _searchResults.values) {
        all.addAll(entries);
      }
      return all;
    }
    final tabType = _tabs[_currentTab].type;
    if (tabType == null) return [];
    return _searchResults[tabType] ?? [];
  }

  /// 获取结果总数
  int _getTotalResultCount() {
    int count = 0;
    for (final entries in _searchResults.values) {
      count += entries.length;
    }
    return count;
  }

  // ---- 结果项信息提取 ----

  String _getResultTitle(Map<String, dynamic> item, String type) {
    switch (type) {
      case 'knowledge_points':
        return item['title'] as String? ?? '未命名知识点';
      case 'notes':
        return item['title'] as String? ?? '未命名笔记';
      case 'wrong_questions':
        final content = item['question_content'] as String? ?? '';
        return content.length > 30 ? '${content.substring(0, 30)}...' : content;
      case 'mother_questions':
        return item['title'] as String? ?? '未命名母题';
      case 'must_remembers':
        return item['title'] as String? ?? '未命名必记内容';
      default:
        return item['title'] as String? ?? '未命名';
    }
  }

  String _getResultSummary(Map<String, dynamic> item, String type) {
    switch (type) {
      case 'knowledge_points':
        final content = item['content'] as String? ?? '';
        return content.length > 60 ? '${content.substring(0, 60)}...' : content;
      case 'notes':
        final content = item['content'] as String? ?? '';
        return content.length > 60 ? '${content.substring(0, 60)}...' : content;
      case 'wrong_questions':
        final analysis = item['analysis'] as String? ?? '';
        return analysis.length > 60 ? '${analysis.substring(0, 60)}...' : analysis;
      case 'mother_questions':
        final content = item['question_content'] as String? ?? '';
        return content.length > 60 ? '${content.substring(0, 60)}...' : content;
      case 'must_remembers':
        final content = item['content'] as String? ?? '';
        return content.length > 60 ? '${content.substring(0, 60)}...' : content;
      default:
        return '';
    }
  }

  String _getResultSubject(Map<String, dynamic> item) {
    return item['subject'] as String? ?? '';
  }

  String _getResultUpdatedAt(Map<String, dynamic> item) {
    final updatedAt = item['updated_at'] as String? ?? '';
    if (updatedAt.isEmpty) return '';
    try {
      final dt = DateTime.parse(updatedAt);
      return formatFriendlyTime(dt);
    } catch (_) {
      return '';
    }
  }

  String _getResultType(Map<String, dynamic> item, String type) {
    switch (type) {
      case 'knowledge_points':
        return '知识点';
      case 'notes':
        return '笔记';
      case 'wrong_questions':
        return '错题';
      case 'mother_questions':
        return '母题';
      case 'must_remembers':
        return '必记必背';
      default:
        return '其他';
    }
  }

  IconData _getResultTypeIcon(String type) {
    switch (type) {
      case 'knowledge_points':
        return Icons.lightbulb_outline;
      case 'notes':
        return Icons.note_outlined;
      case 'wrong_questions':
        return Icons.error_outline;
      case 'mother_questions':
        return Icons.quiz_outlined;
      case 'must_remembers':
        return Icons.bookmark_outline;
      default:
        return Icons.article_outlined;
    }
  }

  Color _getResultTypeColor(String type) {
    switch (type) {
      case 'knowledge_points':
        return const Color(0xFF1565C0);
      case 'notes':
        return const Color(0xFF43A047);
      case 'wrong_questions':
        return const Color(0xFFE53935);
      case 'mother_questions':
        return const Color(0xFF8E24AA);
      case 'must_remembers':
        return const Color(0xFFFB8C00);
      default:
        return AppColors.textSecondary;
    }
  }

  // ---- 关键词高亮 ----

  List<TextSpan> _buildHighlightedText(String text, String keyword, TextStyle baseStyle) {
    if (keyword.isEmpty || !text.toLowerCase().contains(keyword.toLowerCase())) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerKeyword = keyword.toLowerCase();
    int start = 0;

    while (start < lowerText.length) {
      final index = lowerText.indexOf(lowerKeyword, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: baseStyle));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + keyword.length),
        style: baseStyle.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          backgroundColor: AppColors.primary.withOpacity(0.1),
        ),
      ));
      start = index + keyword.length;
    }

    return spans;
  }

  // ---- 导航到详情页 ----

  void _navigateToDetail(Map<String, dynamic> item, String type) {
    // 根据类型导航到对应详情页
    // 这里使用 Navigator.push 到对应页面
    // 实际项目中应使用 AppRoutes 中定义的路由
    switch (type) {
      case 'knowledge_points':
        Navigator.of(context).pop();
        // TODO: 导航到知识点详情页
        break;
      case 'notes':
        Navigator.of(context).pop();
        // TODO: 导航到笔记详情页
        break;
      case 'wrong_questions':
        Navigator.of(context).pop();
        // TODO: 导航到错题详情页
        break;
      case 'mother_questions':
        Navigator.of(context).pop();
        // TODO: 导航到母题详情页
        break;
      case 'must_remembers':
        Navigator.of(context).pop();
        // TODO: 导航到必记必背详情页
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasQuery = _currentQuery.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _buildSearchField(theme),
        actions: [
          TextButton(
            onPressed: () {
              if (hasQuery) {
                _searchController.clear();
                setState(() {
                  _currentQuery = '';
                  _searchResults = {};
                  _isSearching = false;
                });
              } else {
                Navigator.of(context).pop();
              }
            },
            child: Text(
              hasQuery ? '清除' : '取消',
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // 搜索结果Tab栏（仅在搜索后显示）
          if (hasQuery) _buildTabBar(theme),

          // 内容区域
          Expanded(
            child: hasQuery
                ? _buildSearchResults(theme)
                : _buildDefaultContent(theme),
          ),
        ],
      ),
    );
  }

  // ---- 搜索栏 ----

  Widget _buildSearchField(ThemeData theme) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        autofocus: true,
        onChanged: _onSearchChanged,
        onSubmitted: _onSearchSubmitted,
        textInputAction: TextInputAction.search,
        style: TextStyle(
          fontSize: AppFontSize.md,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: '搜索知识、笔记、题目...',
          hintStyle: TextStyle(
            color: AppColors.textHint,
            fontSize: AppFontSize.md,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 20,
            color: AppColors.textSecondary,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    size: 18,
                    color: AppColors.textHint,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    _focusNode.requestFocus();
                    setState(() {
                      _currentQuery = '';
                      _searchResults = {};
                      _isSearching = false;
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          isDense: true,
        ),
      ),
    );
  }

  // ---- Tab栏 ----

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: List.generate(_tabs.length, (index) {
            final tab = _tabs[index];
            final isSelected = _currentTab == index;
            final count = index == 0
                ? _getTotalResultCount()
                : (_searchResults[tab.type] ?? []).length;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tab.label),
                    if (count > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                selected: isSelected,
                onSelected: (_) {
                  setState(() => _currentTab = index);
                },
                visualDensity: VisualDensity.compact,
                labelStyle: TextStyle(
                  fontSize: AppFontSize.sm,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ---- 默认内容（搜索历史） ----

  Widget _buildDefaultContent(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 搜索历史
        if (_recentSearches.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '最近搜索',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton.icon(
                onPressed: _clearSearchHistory,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('清除'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._recentSearches.map((search) {
            return _buildHistoryItem(theme, search);
          }),
          const SizedBox(height: 24),
        ],

        // 空搜索历史提示
        if (_recentSearches.isEmpty) ...[
          const SizedBox(height: 48),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.search,
                  size: 48,
                  color: AppColors.textHint,
                ),
                const SizedBox(height: 16),
                Text(
                  '搜索知识点、笔记、错题等',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppFontSize.md,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '输入关键词开始搜索',
                  style: TextStyle(
                    color: AppColors.textHint,
                    fontSize: AppFontSize.sm,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHistoryItem(ThemeData theme, String search) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Dismissible(
        key: ValueKey(search),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          child: const Icon(Icons.delete_outline, color: AppColors.error),
        ),
        onDismissed: (_) => _removeSearchHistoryItem(search),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () {
            _searchController.text = search;
            _performSearch(search);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.history,
                  size: 18,
                  color: AppColors.textHint,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    search,
                    style: TextStyle(
                      fontSize: AppFontSize.md,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.north_west,
                  size: 16,
                  color: AppColors.textHint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- 搜索结果 ----

  Widget _buildSearchResults(ThemeData theme) {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    final results = _getTabResults();

    if (results.isEmpty) {
      return _buildEmptyResults(theme);
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: results.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 72,
        endIndent: 16,
        color: AppColors.divider,
      ),
      itemBuilder: (context, index) {
        final item = results[index];
        // 确定结果类型
        String type = _tabs[_currentTab].type ?? '';
        if (type.isEmpty) {
          // 全部Tab - 需要从 searchResults 中找到对应类型
          type = _findResultType(item);
        }
        return _buildResultItem(theme, item, type);
      },
    );
  }

  /// 在全部Tab中查找结果所属类型
  String _findResultType(Map<String, dynamic> item) {
    for (final entry in _searchResults.entries) {
      if (entry.value.contains(item)) {
        return entry.key;
      }
    }
    return '';
  }

  Widget _buildEmptyResults(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 56,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              '未找到"$_currentQuery"的相关结果',
              style: TextStyle(
                fontSize: AppFontSize.lg,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '请尝试其他关键词或检查输入',
              style: TextStyle(
                fontSize: AppFontSize.sm,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultItem(
    ThemeData theme,
    Map<String, dynamic> item,
    String type,
  ) {
    final title = _getResultTitle(item, type);
    final summary = _getResultSummary(item, type);
    final subject = _getResultSubject(item);
    final updatedAt = _getResultUpdatedAt(item);
    final typeLabel = _getResultType(item, type);
    final typeIcon = _getResultTypeIcon(type);
    final typeColor = _getResultTypeColor(type);
    final subjectColor = subject.isNotEmpty ? getSubjectColor(subject) : null;

    return InkWell(
      onTap: () => _navigateToDetail(item, type),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 类型图标
            Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(typeIcon, size: 20, color: typeColor),
            ),
            // 内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 类型标签 + 时间
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          typeLabel,
                          style: TextStyle(
                            fontSize: 10,
                            color: typeColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (subject.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: (subjectColor ?? AppColors.textHint).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            subject,
                            style: TextStyle(
                              fontSize: 10,
                              color: subjectColor ?? AppColors.textHint,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (updatedAt.isNotEmpty)
                        Text(
                          updatedAt,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textHint,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 标题（关键词高亮）
                  Text.rich(
                    TextSpan(
                      children: _buildHighlightedText(
                        title,
                        _currentQuery,
                        TextStyle(
                          fontSize: AppFontSize.md,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // 摘要（关键词高亮）
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: _buildHighlightedText(
                          summary,
                          _currentQuery,
                          TextStyle(
                            fontSize: AppFontSize.sm,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// _SearchTab - 搜索Tab定义
// ============================================================

class _SearchTab {
  final String label;
  final String? type; // null 表示"全部"

  const _SearchTab({required this.label, required this.type});
}
