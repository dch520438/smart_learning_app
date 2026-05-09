import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/wrong_question.dart';
import '../../models/must_remember.dart';
import '../../services/database_service.dart';
import '../../utils/app_routes.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/knowledge_widgets.dart';
import '../notes/notes_screen.dart';
import '../wrong_questions/wrong_questions_screen.dart';
import '../knowledge/knowledge_screen.dart';
import '../mother_questions/mother_questions_screen.dart';
import '../must_remember/must_remember_screen.dart';

// ============================================================
// SearchScreen - 全局搜索页面
// ============================================================

enum SearchResultType {
  knowledge,  // 知识点
  note,       // 笔记
  wrongQuestion, // 错题
  motherQuestion, // 母题
  mustRemember,   // 必记必背
}

class SearchResult {
  final String id;
  final String title;
  final String summary;
  final String subject;
  final SearchResultType type;
  final dynamic rawData;
  final DateTime? updatedAt;

  SearchResult({
    required this.id,
    required this.title,
    required this.summary,
    required this.subject,
    required this.type,
    this.rawData,
    this.updatedAt,
  });
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isLoading = false;
  String _searchQuery = '';
  List<SearchResult> _allResults = [];

  // Tab控制器
  late TabController _tabController;
  final List<String> _tabs = ['全部', '知识点', '笔记', '错题', '母题', '必记必背'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    // 自动聚焦搜索框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // 执行全局搜索
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchQuery = '';
        _allResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _searchQuery = query.trim();
    });

    try {
      final results = <SearchResult>[];
      final keyword = query.toLowerCase();

      // 1. 搜索知识点
      final knowledgeRows = await _db.queryAllKnowledgePoints();
      for (final row in knowledgeRows) {
        final title = (row['title'] as String? ?? '').toLowerCase();
        final content = (row['content'] as String? ?? '').toLowerCase();
        if (title.contains(keyword) || content.contains(keyword)) {
          results.add(SearchResult(
            id: row['id'].toString(),
            title: row['title'] as String? ?? '未命名知识点',
            summary: _extractSummary(row['content'] as String? ?? ''),
            subject: row['subject'] as String? ?? '未分类',
            type: SearchResultType.knowledge,
            rawData: row,
            updatedAt: row['updated_at'] != null
                ? DateTime.tryParse(row['updated_at'] as String)
                : null,
          ));
        }
      }

      // 2. 搜索笔记
      final noteRows = await _db.queryAllNotes();
      for (final row in noteRows) {
        final title = (row['title'] as String? ?? '').toLowerCase();
        final content = (row['content'] as String? ?? '').toLowerCase();
        if (title.contains(keyword) || content.contains(keyword)) {
          results.add(SearchResult(
            id: row['uuid'] as String? ?? row['id'].toString(),
            title: row['title'] as String? ?? '未命名笔记',
            summary: _extractSummary(row['content'] as String? ?? ''),
            subject: row['subject'] as String? ?? '未分类',
            type: SearchResultType.note,
            rawData: row,
            updatedAt: row['updated_at'] != null
                ? DateTime.tryParse(row['updated_at'] as String)
                : null,
          ));
        }
      }

      // 3. 搜索错题
      final wrongQuestionRows = await _db.queryAllWrongQuestions();
      for (final row in wrongQuestionRows) {
        final content = (row['question_content'] as String? ?? '').toLowerCase();
        final analysis = (row['analysis'] as String? ?? '').toLowerCase();
        if (content.contains(keyword) || analysis.contains(keyword)) {
          results.add(SearchResult(
            id: row['uuid'] as String? ?? row['id'].toString(),
            title: row['question_content'] as String? ?? '未命名错题',
            summary: _extractSummary(row['analysis'] as String? ?? ''),
            subject: row['subject'] as String? ?? '未分类',
            type: SearchResultType.wrongQuestion,
            rawData: row,
            updatedAt: row['updated_at'] != null
                ? DateTime.tryParse(row['updated_at'] as String)
                : null,
          ));
        }
      }

      // 4. 搜索母题
      final motherQuestionRows = await _db.queryAllMotherQuestions();
      for (final row in motherQuestionRows) {
        final title = (row['title'] as String? ?? '').toLowerCase();
        final content = (row['question_content'] as String? ?? '').toLowerCase();
        final tags = (row['tags'] as String? ?? '').toLowerCase();
        if (title.contains(keyword) || content.contains(keyword) || tags.contains(keyword)) {
          results.add(SearchResult(
            id: row['id'].toString(),
            title: row['title'] as String? ?? '未命名母题',
            summary: _extractSummary(row['question_content'] as String? ?? ''),
            subject: row['subject'] as String? ?? '未分类',
            type: SearchResultType.motherQuestion,
            rawData: row,
            updatedAt: row['updated_at'] != null
                ? DateTime.tryParse(row['updated_at'] as String)
                : null,
          ));
        }
      }

      // 5. 搜索必记必背
      final mustRememberRows = await _db.queryAllMustRemembers();
      for (final row in mustRememberRows) {
        final title = (row['title'] as String? ?? '').toLowerCase();
        final content = (row['content'] as String? ?? '').toLowerCase();
        if (title.contains(keyword) || content.contains(keyword)) {
          results.add(SearchResult(
            id: row['uuid'] as String? ?? row['id'].toString(),
            title: row['title'] as String? ?? '未命名内容',
            summary: _extractSummary(row['content'] as String? ?? ''),
            subject: row['subject'] as String? ?? '未分类',
            type: SearchResultType.mustRemember,
            rawData: row,
            updatedAt: row['updated_at'] != null
                ? DateTime.tryParse(row['updated_at'] as String)
                : null,
          ));
        }
      }

      // 按更新时间排序
      results.sort((a, b) {
        if (a.updatedAt == null && b.updatedAt == null) return 0;
        if (a.updatedAt == null) return 1;
        if (b.updatedAt == null) return -1;
        return b.updatedAt!.compareTo(a.updatedAt!);
      });

      setState(() {
        _allResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showSnackBar(context, '搜索失败: $e', isError: true);
      }
    }
  }

  // 提取摘要
  String _extractSummary(String content) {
    if (content.isEmpty) return '暂无内容';
    // 去除多余空白并截取前50个字符
    final cleaned = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= 50) return cleaned;
    return '${cleaned.substring(0, 50)}...';
  }

  // 获取类型标签文本
  String _getTypeLabel(SearchResultType type) {
    switch (type) {
      case SearchResultType.knowledge:
        return '知识点';
      case SearchResultType.note:
        return '笔记';
      case SearchResultType.wrongQuestion:
        return '错题';
      case SearchResultType.motherQuestion:
        return '母题';
      case SearchResultType.mustRemember:
        return '必记必背';
    }
  }

  // 获取类型标签颜色
  Color _getTypeColor(SearchResultType type) {
    switch (type) {
      case SearchResultType.knowledge:
        return AppColors.info;
      case SearchResultType.note:
        return AppColors.success;
      case SearchResultType.wrongQuestion:
        return AppColors.error;
      case SearchResultType.motherQuestion:
        return AppColors.warning;
      case SearchResultType.mustRemember:
        return const Color(0xFF8E24AA);
    }
  }

  // 获取各类型数量
  Map<SearchResultType, int> _getTypeCounts() {
    final counts = <SearchResultType, int>{};
    for (final type in SearchResultType.values) {
      counts[type] = _allResults.where((r) => r.type == type).length;
    }
    return counts;
  }

  // 获取当前Tab的结果列表
  List<SearchResult> _getCurrentResults() {
    if (_tabController.index == 0) {
      return _allResults;
    }
    final typeMap = {
      1: SearchResultType.knowledge,
      2: SearchResultType.note,
      3: SearchResultType.wrongQuestion,
      4: SearchResultType.motherQuestion,
      5: SearchResultType.mustRemember,
    };
    final targetType = typeMap[_tabController.index];
    if (targetType == null) return _allResults;
    return _allResults.where((r) => r.type == targetType).toList();
  }

  // 跳转到详情页
  void _navigateToDetail(SearchResult result) {
    switch (result.type) {
      case SearchResultType.knowledge:
        _navigateToKnowledgeDetail(result);
        break;
      case SearchResultType.note:
        _navigateToNoteDetail(result);
        break;
      case SearchResultType.wrongQuestion:
        _navigateToWrongQuestionDetail(result);
        break;
      case SearchResultType.motherQuestion:
        _navigateToMotherQuestionDetail(result);
        break;
      case SearchResultType.mustRemember:
        _navigateToMustRememberDetail(result);
        break;
    }
  }

  void _navigateToKnowledgeDetail(SearchResult result) async {
    // 从数据库获取完整的知识点数据
    final db = DatabaseService();
    final row = await db.queryKnowledgePointById(int.parse(result.id));
    
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => KnowledgeDetailPage(
            knowledgeId: result.id,
            title: result.title,
            subject: row?['subject'] as String?,
            difficulty: row?['difficulty'] as int?,
            mastery: row?['mastery_level'] as int?,
            content: row?['content'] as String?,
            summary: row?['content'] as String?,
            createdAt: row?['created_at'] != null
                ? DateTime.tryParse(row!['created_at'] as String)
                : null,
            updatedAt: row?['updated_at'] != null
                ? DateTime.tryParse(row!['updated_at'] as String)
                : null,
            onEdit: () async {
              Navigator.pop(context);
              if (row != null) {
                final editResult = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => KnowledgeAddPage(
                      existingPoint: row,
                    ),
                  ),
                );
                if (editResult == true) {
                  // 刷新搜索结果
                  _performSearch(_searchController.text);
                }
              }
            },
            onDelete: () async {
              if (row != null) {
                final dbId = row['id'] as int?;
                if (dbId != null) {
                  await db.deleteKnowledgePoint(dbId);
                  Navigator.pop(context);
                  _performSearch(_searchController.text);
                }
              }
            },
          ),
        ),
      );
    }
  }

  void _navigateToNoteDetail(SearchResult result) async {
    // 从数据库获取完整的笔记数据
    final db = DatabaseService();
    final row = await db.queryNoteByUuid(result.id);
    
    if (mounted && row != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => NoteEditorPage(
            existingNote: row,
          ),
        ),
      ).then((_) {
        // 刷新搜索结果
        _performSearch(_searchController.text);
      });
    }
  }

  void _navigateToWrongQuestionDetail(SearchResult result) async {
    // 从数据库获取完整的错题数据
    final db = DatabaseService();
    final row = await db.queryWrongQuestionByUuid(result.id);
    
    if (mounted && row != null) {
      // 将数据库行转换为 WrongQuestion 对象
      final question = _rowToWrongQuestion(row);
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => WrongQuestionDetailScreen(
            question: question,
            onUpdated: () => _performSearch(_searchController.text),
            onDeleted: () => _performSearch(_searchController.text),
          ),
        ),
      );
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
    );
  }
  
  String _mapErrorType(Map<String, dynamic> r) {
    final errorCount = r['error_count'] as int? ?? 1;
    if (errorCount <= 1) return '粗心';
    if (errorCount <= 2) return '知识盲区';
    return '方法错误';
  }

  void _navigateToMotherQuestionDetail(SearchResult result) async {
    // 从数据库获取完整的母题数据
    final db = DatabaseService();
    final row = await db.queryMotherQuestionById(int.parse(result.id));
    
    if (mounted && row != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MotherQuestionDetailScreen(questionData: row),
        ),
      ).then((_) => _performSearch(_searchController.text));
    }
  }

  void _navigateToMustRememberDetail(SearchResult result) async {
    // 从数据库获取完整的必记必背数据
    final db = DatabaseService();
    final row = await db.queryMustRememberByUuid(result.id);
    
    if (mounted && row != null) {
      final item = _rowToMustRemember(row);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MustRememberDetailScreen(
            item: item,
            onUpdated: () => _performSearch(_searchController.text),
            onDeleted: () => _performSearch(_searchController.text),
          ),
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = _getTypeCounts();
    final currentResults = _getCurrentResults();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 搜索栏
            _buildSearchBar(theme),

            // Tab栏
            if (_searchQuery.isNotEmpty) _buildTabBar(theme, counts),

            // 搜索结果
            Expanded(
              child: _buildResultContent(currentResults),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Row(
        children: [
          // 返回按钮
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),

          // 搜索输入框
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: '搜索知识点、笔记、错题、母题、必记必背...',
                  hintStyle: TextStyle(
                    fontSize: AppFontSize.md,
                    color: AppColors.textHint,
                  ),
                  prefixIcon: Icon(Icons.search, color: AppColors.textHint),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: AppColors.textHint),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _allResults = [];
                            });
                            _searchFocusNode.requestFocus();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                style: TextStyle(
                  fontSize: AppFontSize.md,
                  color: AppColors.textPrimary,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: _performSearch,
                onChanged: (value) {
                  setState(() {});
                },
              ),
            ),
          ),

          // 搜索按钮
          const SizedBox(width: 8),
          AppButton(
            text: '搜索',
            onPressed: () => _performSearch(_searchController.text),
            style: AppButtonStyle.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme, Map<SearchResultType, int> counts) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.divider),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: theme.colorScheme.primary,
        indicatorWeight: 3,
        labelStyle: const TextStyle(
          fontSize: AppFontSize.md,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: AppFontSize.md,
          fontWeight: FontWeight.w400,
        ),
        tabs: [
          _buildTab('全部', _allResults.length),
          _buildTab('知识点', counts[SearchResultType.knowledge] ?? 0),
          _buildTab('笔记', counts[SearchResultType.note] ?? 0),
          _buildTab('错题', counts[SearchResultType.wrongQuestion] ?? 0),
          _buildTab('母题', counts[SearchResultType.motherQuestion] ?? 0),
          _buildTab('必记必背', counts[SearchResultType.mustRemember] ?? 0),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int count) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: count > 0 ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: AppFontSize.xs,
                  fontWeight: FontWeight.w600,
                  color: count > 0 ? AppColors.primary : AppColors.textHint,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultContent(List<SearchResult> results) {
    if (_searchQuery.isEmpty) {
      return _buildEmptyState(
        icon: Icons.search,
        message: '输入关键词开始搜索',
        subMessage: '支持搜索知识点、笔记、错题、母题、必记必背',
      );
    }

    if (_isLoading) {
      return const Center(
        child: AppLoading(message: '搜索中...'),
      );
    }

    if (results.isEmpty) {
      return _buildEmptyState(
        icon: Icons.search_off,
        message: '未找到相关结果',
        subMessage: '尝试使用其他关键词搜索',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        return _buildResultCard(result);
      },
    );
  }

  Widget _buildResultCard(SearchResult result) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => _navigateToDetail(result),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 第一行：类型标签 + 学科标签
              Row(
                children: [
                  // 类型标签
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getTypeColor(result.type).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      _getTypeLabel(result.type),
                      style: TextStyle(
                        fontSize: AppFontSize.xs,
                        fontWeight: FontWeight.w600,
                        color: _getTypeColor(result.type),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 学科标签
                  AppTag(
                    label: result.subject,
                    color: getSubjectColor(result.subject),
                    dense: true,
                    fontSize: AppFontSize.xs,
                  ),
                  const Spacer(),
                  // 时间
                  if (result.updatedAt != null)
                    Text(
                      formatFriendlyTime(result.updatedAt!),
                      style: TextStyle(
                        fontSize: AppFontSize.xs,
                        color: AppColors.textHint,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // 标题
              Text(
                result.title,
                style: TextStyle(
                  fontSize: AppFontSize.lg,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // 摘要
              Text(
                result.summary,
                style: TextStyle(
                  fontSize: AppFontSize.md,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required String subMessage,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: AppColors.textHint.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: AppFontSize.lg,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subMessage,
            style: TextStyle(
              fontSize: AppFontSize.md,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}
