import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../services/print_service.dart';
import '../../utils/helpers.dart';

/// 组合打印页面
/// 用户可以自由选择多个内容组合到一起打印
class PrintCombinationScreen extends StatefulWidget {
  const PrintCombinationScreen({super.key});

  @override
  State<PrintCombinationScreen> createState() => _PrintCombinationScreenState();
}

class _PrintCombinationScreenState extends State<PrintCombinationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseService _dbService = DatabaseService();

  // 各类数据列表（使用 Map 格式）
  List<Map<String, dynamic>> _knowledgePoints = [];
  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _wrongQuestions = [];
  List<Map<String, dynamic>> _motherQuestions = [];
  List<Map<String, dynamic>> _mustRemembers = [];

  // 选中的内容（使用数据库 ID）
  final Set<int> _selectedKnowledgePointIds = {};
  final Set<int> _selectedNoteIds = {};
  final Set<int> _selectedWrongQuestionIds = {};
  final Set<int> _selectedMotherQuestionIds = {};
  final Set<int> _selectedMustRememberIds = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // 并行加载所有数据
      final results = await Future.wait([
        _dbService.queryAllKnowledgePoints(),
        _dbService.queryAllNotes(),
        _dbService.queryAllWrongQuestions(),
        _dbService.queryAllMotherQuestions(),
        _dbService.queryAllMustRemembers(),
      ]);

      setState(() {
        _knowledgePoints = results[0];
        _notes = results[1];
        _wrongQuestions = results[2];
        _motherQuestions = results[3];
        _mustRemembers = results[4];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载数据失败: $e')),
        );
      }
    }
  }

  int get _totalSelectedCount {
    return _selectedKnowledgePointIds.length +
        _selectedNoteIds.length +
        _selectedWrongQuestionIds.length +
        _selectedMotherQuestionIds.length +
        _selectedMustRememberIds.length;
  }

  void _clearAllSelections() {
    setState(() {
      _selectedKnowledgePointIds.clear();
      _selectedNoteIds.clear();
      _selectedWrongQuestionIds.clear();
      _selectedMotherQuestionIds.clear();
      _selectedMustRememberIds.clear();
    });
  }

  void _selectAllInCurrentTab() {
    final index = _tabController.index;
    setState(() {
      switch (index) {
        case 0: // 知识点
          _selectedKnowledgePointIds
              .addAll(_knowledgePoints.map((e) => e['id'] as int));
          break;
        case 1: // 笔记
          _selectedNoteIds.addAll(_notes.map((e) => e['id'] as int));
          break;
        case 2: // 错题
          _selectedWrongQuestionIds
              .addAll(_wrongQuestions.map((e) => e['id'] as int));
          break;
        case 3: // 母题
          _selectedMotherQuestionIds
              .addAll(_motherQuestions.map((e) => e['id'] as int));
          break;
        case 4: // 必记必背
          _selectedMustRememberIds
              .addAll(_mustRemembers.map((e) => e['id'] as int));
          break;
      }
    });
  }

  Future<void> _printSelected() async {
    if (_totalSelectedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择要打印的内容')),
      );
      return;
    }

    // 构建打印内容列表
    final items = <PrintContentItem>[];

    // 添加知识点
    for (final kp in _knowledgePoints) {
      if (_selectedKnowledgePointIds.contains(kp['id'])) {
        items.add(PrintContentItem(
          type: PrintContentType.knowledgePoint,
          title: kp['title']?.toString() ?? '',
          content: kp['content']?.toString() ?? '',
          subject: kp['subject']?.toString(),
          category: kp['chapter']?.toString(),
          tags: kp['tags']?.toString(),
          difficulty: kp['difficulty'] as int?,
          masteryLevel: kp['mastery_level'] as int?,
          createdAt: _formatTimestamp(kp['created_at']),
        ));
      }
    }

    // 添加笔记
    for (final note in _notes) {
      if (_selectedNoteIds.contains(note['id'])) {
        items.add(PrintContentItem(
          type: PrintContentType.note,
          title: note['title']?.toString() ?? '',
          content: note['content']?.toString() ?? '',
          subject: note['subject']?.toString(),
          tags: note['tags']?.toString(),
          createdAt: _formatTimestamp(note['created_at']),
        ));
      }
    }

    // 添加错题
    for (final wq in _wrongQuestions) {
      if (_selectedWrongQuestionIds.contains(wq['id'])) {
        final content = StringBuffer();
        content.writeln('【题目】');
        content.writeln(wq['question_content'] ?? '');
        
        final options = wq['options'];
        if (options != null && options.toString().isNotEmpty) {
          content.writeln('\n【选项】');
          content.writeln(options.toString());
        }
        
        content.writeln('\n【正确答案】${wq['correct_answer'] ?? ''}');
        
        if (wq['my_answer'] != null) {
          content.writeln('【我的答案】${wq['my_answer']}');
        }
        
        if (wq['analysis'] != null && wq['analysis'].toString().isNotEmpty) {
          content.writeln('\n【解析】\n${wq['analysis']}');
        }

        items.add(PrintContentItem(
          type: PrintContentType.wrongQuestion,
          title: wq['title']?.toString() ?? '错题',
          content: content.toString(),
          subject: wq['subject']?.toString(),
          tags: wq['tags']?.toString(),
          createdAt: _formatTimestamp(wq['created_at']),
          additionalMetadata: {
            if (wq['error_type'] != null) '错误类型': wq['error_type'].toString(),
            '状态': (wq['is_mastered'] == 1) ? '已掌握' : '未掌握',
          },
        ));
      }
    }

    // 添加母题
    for (final mq in _motherQuestions) {
      if (_selectedMotherQuestionIds.contains(mq['id'])) {
        final content = StringBuffer();
        content.writeln('【题目】');
        content.writeln(mq['question_content'] ?? '');
        
        final options = mq['options'];
        if (options != null && options.toString().isNotEmpty) {
          content.writeln('\n【选项】');
          content.writeln(options.toString());
        }
        
        content.writeln('\n【正确答案】${mq['correct_answer'] ?? ''}');
        
        if (mq['analysis'] != null && mq['analysis'].toString().isNotEmpty) {
          content.writeln('\n【解析】\n${mq['analysis']}');
        }

        items.add(PrintContentItem(
          type: PrintContentType.motherQuestion,
          title: mq['title']?.toString() ?? '',
          content: content.toString(),
          subject: mq['subject']?.toString(),
          tags: mq['tags']?.toString(),
          difficulty: mq['difficulty'] as int?,
          createdAt: _formatTimestamp(mq['created_at']),
        ));
      }
    }

    // 添加必记必背
    for (final mr in _mustRemembers) {
      if (_selectedMustRememberIds.contains(mr['id'])) {
        items.add(PrintContentItem(
          type: PrintContentType.mustRemember,
          title: mr['title']?.toString() ?? '',
          content: mr['content']?.toString() ?? '',
          subject: mr['subject']?.toString(),
          category: mr['category']?.toString(),
          createdAt: _formatTimestamp(mr['created_at']),
          additionalMetadata: {
            if (mr['memory_level'] != null) '记忆程度': '${mr['memory_level']}%',
            '状态': (mr['is_mastered'] == 1) ? '已掌握' : '学习中',
          },
        ));
      }
    }

    // 执行打印
    final result = await PrintService.printBatch(
      context: context,
      items: items,
      customTitle: '学习资料汇总',
    );

    if (result.success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.filePath != null
              ? 'PDF已保存到: ${result.filePath}'
              : '打印成功'),
        ),
      );
    }
  }

  String? _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;
    try {
      if (timestamp is int) {
        return formatDateTime(DateTime.fromMillisecondsSinceEpoch(timestamp));
      }
      return timestamp.toString();
    } catch (_) {
      return timestamp.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('组合打印'),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all),
            tooltip: '全选当前分类',
            onPressed: _selectAllInCurrentTab,
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: '清除选择',
            onPressed: _clearAllSelections,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          tabs: [
            Tab(text: '知识点 (${_knowledgePoints.length})'),
            Tab(text: '笔记 (${_notes.length})'),
            Tab(text: '错题 (${_wrongQuestions.length})'),
            Tab(text: '母题 (${_motherQuestions.length})'),
            Tab(text: '必记必背 (${_mustRemembers.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildKnowledgePointList(),
                _buildNoteList(),
                _buildWrongQuestionList(),
                _buildMotherQuestionList(),
                _buildMustRememberList(),
              ],
            ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Text(
                '已选择 $_totalSelectedCount 项',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ElevatedButton.icon(
              onPressed: _totalSelectedCount > 0 ? _printSelected : null,
              icon: const Icon(Icons.print),
              label: const Text('打印'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKnowledgePointList() {
    if (_knowledgePoints.isEmpty) {
      return const Center(child: Text('暂无知识点'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _knowledgePoints.length,
      itemBuilder: (context, index) {
        final kp = _knowledgePoints[index];
        final id = kp['id'] as int;
        final isSelected = _selectedKnowledgePointIds.contains(id);
        final subject = kp['subject']?.toString() ?? '';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: CheckboxListTile(
            value: isSelected,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectedKnowledgePointIds.add(id);
                } else {
                  _selectedKnowledgePointIds.remove(id);
                }
              });
            },
            title: Text(
              kp['title']?.toString() ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: getSubjectColor(subject).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        subject,
                        style: TextStyle(
                          fontSize: 12,
                          color: getSubjectColor(subject),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (kp['chapter'] != null)
                      Text(
                        kp['chapter'].toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  truncateText(kp['content']?.toString() ?? '', 100),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            secondary: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: getDifficultyColor(kp['difficulty'] as int? ?? 0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    getDifficultyLabel(kp['difficulty'] as int? ?? 0),
                    style: TextStyle(
                      fontSize: 10,
                      color: getDifficultyColor(kp['difficulty'] as int? ?? 0),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${kp['mastery_level'] ?? 0}%',
                  style: TextStyle(
                    fontSize: 10,
                    color: getMasteryColor(kp['mastery_level'] as int? ?? 0),
                  ),
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildNoteList() {
    if (_notes.isEmpty) {
      return const Center(child: Text('暂无笔记'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _notes.length,
      itemBuilder: (context, index) {
        final note = _notes[index];
        final id = note['id'] as int;
        final isSelected = _selectedNoteIds.contains(id);
        final subject = note['subject']?.toString() ?? '';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: CheckboxListTile(
            value: isSelected,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectedNoteIds.add(id);
                } else {
                  _selectedNoteIds.remove(id);
                }
              });
            },
            title: Row(
              children: [
                if (note['is_pinned'] == 1)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.push_pin, size: 16, color: Colors.orange),
                  ),
                Expanded(
                  child: Text(
                    note['title']?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: getSubjectColor(subject).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        subject,
                        style: TextStyle(
                          fontSize: 12,
                          color: getSubjectColor(subject),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTimestamp(note['updated_at']) ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  truncateText(note['content']?.toString() ?? '', 80),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildWrongQuestionList() {
    if (_wrongQuestions.isEmpty) {
      return const Center(child: Text('暂无错题'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _wrongQuestions.length,
      itemBuilder: (context, index) {
        final wq = _wrongQuestions[index];
        final id = wq['id'] as int;
        final isSelected = _selectedWrongQuestionIds.contains(id);
        final subject = wq['subject']?.toString() ?? '';
        final title = wq['title']?.toString() ?? 
            truncateText(wq['question_content']?.toString() ?? '', 50);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: CheckboxListTile(
            value: isSelected,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectedWrongQuestionIds.add(id);
                } else {
                  _selectedWrongQuestionIds.remove(id);
                }
              });
            },
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: getSubjectColor(subject).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        subject,
                        style: TextStyle(
                          fontSize: 12,
                          color: getSubjectColor(subject),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        wq['error_type']?.toString() ?? '未知',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (wq['is_mastered'] == 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '已掌握',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  truncateText(wq['question_content']?.toString() ?? '', 60),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildMotherQuestionList() {
    if (_motherQuestions.isEmpty) {
      return const Center(child: Text('暂无母题'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _motherQuestions.length,
      itemBuilder: (context, index) {
        final mq = _motherQuestions[index];
        final id = mq['id'] as int;
        final isSelected = _selectedMotherQuestionIds.contains(id);
        final subject = mq['subject']?.toString() ?? '';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: CheckboxListTile(
            value: isSelected,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectedMotherQuestionIds.add(id);
                } else {
                  _selectedMotherQuestionIds.remove(id);
                }
              });
            },
            title: Text(
              mq['title']?.toString() ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: getSubjectColor(subject).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        subject,
                        style: TextStyle(
                          fontSize: 12,
                          color: getSubjectColor(subject),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: getDifficultyColor(mq['difficulty'] as int? ?? 0).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        getDifficultyLabel(mq['difficulty'] as int? ?? 0),
                        style: TextStyle(
                          fontSize: 10,
                          color: getDifficultyColor(mq['difficulty'] as int? ?? 0),
                        ),
                      ),
                    ),
                    if (mq['chapter'] != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        mq['chapter'].toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  truncateText(mq['question_content']?.toString() ?? '', 60),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildMustRememberList() {
    if (_mustRemembers.isEmpty) {
      return const Center(child: Text('暂无必记必背内容'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _mustRemembers.length,
      itemBuilder: (context, index) {
        final mr = _mustRemembers[index];
        final id = mr['id'] as int;
        final isSelected = _selectedMustRememberIds.contains(id);
        final subject = mr['subject']?.toString() ?? '';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: CheckboxListTile(
            value: isSelected,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectedMustRememberIds.add(id);
                } else {
                  _selectedMustRememberIds.remove(id);
                }
              });
            },
            title: Text(
              mr['title']?.toString() ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: getSubjectColor(subject).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        subject,
                        style: TextStyle(
                          fontSize: 12,
                          color: getSubjectColor(subject),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        mr['category']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (mr['is_mastered'] == 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '已掌握',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  truncateText(mr['content']?.toString() ?? '', 80),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            secondary: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${mr['memory_level'] ?? 0}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: getMasteryColor(mr['memory_level'] as int? ?? 0),
                  ),
                ),
                Text(
                  '记忆',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
