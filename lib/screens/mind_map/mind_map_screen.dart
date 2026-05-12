import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/mind_map_data.dart';
import '../../models/knowledge_point.dart';
import '../../models/wrong_question.dart';
import '../../models/note.dart';
import '../../models/must_remember.dart';
import '../../services/mind_map_service.dart';
import '../../services/database_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

// ============================================================
// MindMapScreen - 思维导图页面 (重构版)
// ============================================================
// 功能：
// 1. 自动生成：按学科->章节->内容层次结构
// 2. 手动创建：用户可以手动添加节点
// 3. 编辑功能：支持编辑、删除节点
// 4. 详情查看：点击节点显示详细内容

class MindMapScreen extends StatefulWidget {
  const MindMapScreen({super.key});

  @override
  State<MindMapScreen> createState() => _MindMapScreenState();
}

class _MindMapScreenState extends State<MindMapScreen> {
  final MindMapService _mindMapService = MindMapService();
  final DatabaseService _dbService = DatabaseService();
  final GlobalKey _mindMapKey = GlobalKey();
  final TransformationController _transformationController =
      TransformationController();

  MindMapData? _mindMapData;
  MindMapViewState _viewState = MindMapViewState();
  bool _isLoading = true;
  String _currentType = 'all';
  String? _currentFilter;

  // 可用选项
  List<String> _subjects = [];
  List<String> _chapters = [];

  @override
  void initState() {
    super.initState();
    _loadOptions();
    _generateMindMap();
  }

  Future<void> _loadOptions() async {
    final subjects = await _mindMapService.getAllSubjects();
    setState(() {
      _subjects = subjects;
    });
  }

  Future<void> _loadChapters(String subject) async {
    final chapters = await _mindMapService.getAllChapters(subject);
    setState(() {
      _chapters = chapters;
    });
  }

  Future<void> _generateMindMap() async {
    setState(() => _isLoading = true);
    try {
      final data = await _mindMapService.generateMindMap(
        type: _currentType,
        filterValue: _currentFilter,
      );
      setState(() {
        _mindMapData = data;
        _isLoading = false;
      });
      // 重置视图
      _resetView();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showSnackBar(context, '生成思维导图失败: $e', isError: true);
      }
    }
  }

  void _resetView() {
    _transformationController.value = Matrix4.identity();
    setState(() {
      _viewState = MindMapViewState();
    });
  }

  Future<void> _exportToImage() async {
    try {
      final boundary = _mindMapKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        showSnackBar(context, '无法导出图片', isError: true);
        return;
      }

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();

      if (bytes == null) {
        showSnackBar(context, '导出失败', isError: true);
        return;
      }

      // 保存到临时文件
      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/mind_map_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);

      // Linux 平台不支持 share_plus，使用文件选择器保存
      if (Platform.isLinux) {
        String? outputPath = await FilePicker.platform.getDirectoryPath(
          dialogTitle: '选择图片保存位置',
        );

        if (outputPath != null) {
          final targetFile = File('$outputPath/${file.uri.pathSegments.last}');
          await file.copy(targetFile.path);
          if (mounted) {
            showSnackBar(context, '图片已保存至: ${targetFile.path}');
          }
        }
      } else {
        // 其他平台使用分享
        await Share.shareXFiles(
          [XFile(file.path)],
          text: '思维导图: ${_mindMapData?.title ?? '学习知识图谱'}',
        );
        if (mounted) {
          showSnackBar(context, '图片已导出');
        }
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '导出失败: $e', isError: true);
      }
    }
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                Row(
                  children: [
                    Icon(Icons.filter_list, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      '选择视图',
                      style: TextStyle(
                        fontSize: AppFontSize.lg,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('完成'),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      // 全部
                      _buildFilterOption(
                          '全部内容', 'all', null, Icons.account_tree),
                      const Divider(),

                      // 按学科
                      if (_subjects.isNotEmpty) ...[
                        _buildFilterSection('按学科'),
                        ..._subjects.map((s) => _buildFilterOption(
                              s,
                              'subject',
                              s,
                              Icons.school,
                              getSubjectColor(s),
                            )),
                        const Divider(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterSection(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: AppFontSize.md,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildFilterOption(
      String label, String type, String? value, IconData icon,
      [Color? color]) {
    final isSelected = _currentType == type && _currentFilter == value;
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.primary),
      title: Text(label),
      trailing: isSelected ? Icon(Icons.check, color: AppColors.success) : null,
      onTap: () {
        setState(() {
          _currentType = type;
          _currentFilter = value;
        });
        _generateMindMap();
        Navigator.pop(context);
      },
    );
  }

  /// 显示节点详情
  void _showNodeDetail(MindMapNode node) {
    // 如果是内容节点，显示原始内容详情
    if (node.data != null && node.sourceId != null) {
      _showContentNodeDetail(node);
      return;
    }

    // 显示普通节点详情
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => _NodeDetailSheet(
        node: node,
        onEdit: () {
          Navigator.pop(context);
          _showEditNodeDialog(node);
        },
        onAddChild: () {
          Navigator.pop(context);
          _showAddNodeDialog(parentNode: node);
        },
        onDelete: node.type == NodeType.root
            ? null
            : () {
                Navigator.pop(context);
                _deleteNode(node);
              },
      ),
    );
  }

  /// 显示内容节点详情（知识点、错题、笔记、必记必背）
  void _showContentNodeDetail(MindMapNode node) {
    dynamic item;
    String type = '';

    if (node.data!.containsKey('knowledgePoint')) {
      item = KnowledgePoint.fromJson(node.data!['knowledgePoint']);
      type = '知识点';
    } else if (node.data!.containsKey('wrongQuestion')) {
      item = WrongQuestion.fromJson(node.data!['wrongQuestion']);
      type = '错题';
    } else if (node.data!.containsKey('note')) {
      item = Note.fromJson(node.data!['note']);
      type = '笔记';
    } else if (node.data!.containsKey('mustRemember')) {
      item = MustRemember.fromJson(node.data!['mustRemember']);
      type = '必记必背';
    } else {
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: node.getColor(context).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          fontSize: AppFontSize.sm,
                          color: node.getColor(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: AppFontSize.xl,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                _buildDetailItem('学科', item.subject),
                if (item.chapter != null)
                  _buildDetailItem('章节', item.chapter!),
                if (item is KnowledgePoint) ...[
                  _buildDetailItem('难度', '${item.difficulty}/5'),
                  _buildDetailItem('掌握度', '${item.masteryLevel}%'),
                ] else if (item is WrongQuestion) ...[
                  _buildDetailItem('错误类型', item.errorType),
                  _buildDetailItem('错误次数', '${item.errorCount}'),
                ] else if (item is MustRemember) ...[
                  _buildDetailItem('分类', item.category),
                  _buildDetailItem('记忆程度', '${item.memoryLevel}%'),
                ],
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '内容',
                          style: TextStyle(
                            fontSize: AppFontSize.md,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.content,
                          style: TextStyle(
                            fontSize: AppFontSize.md,
                            color: AppColors.textPrimary,
                            height: 1.6,
                          ),
                        ),
                        if (item is WrongQuestion &&
                            item.analysis.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            '解析',
                            style: TextStyle(
                              fontSize: AppFontSize.md,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.analysis,
                            style: TextStyle(
                              fontSize: AppFontSize.md,
                              color: AppColors.textPrimary,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: AppFontSize.sm,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: AppFontSize.sm,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 显示添加节点对话框
  void _showAddNodeDialog({MindMapNode? parentNode}) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    NodeType selectedType = NodeType.custom;
    String selectedSubject = parentNode?.subject ?? '其他';
    String? selectedChapter = parentNode?.chapter;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(parentNode == null ? '添加根节点' : '添加子节点'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: '标题',
                      hintText: '输入节点标题',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: contentController,
                    decoration: const InputDecoration(
                      labelText: '内容',
                      hintText: '输入节点简介（可选）',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<NodeType>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: '类型'),
                    items: NodeType.values
                        .where((t) => t != NodeType.root)
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(_getNodeTypeName(type)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedType = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedSubject,
                    decoration: const InputDecoration(labelText: '学科'),
                    items: _subjects.isEmpty
                        ? [
                            const DropdownMenuItem(
                                value: '其他', child: Text('其他'))
                          ]
                        : _subjects
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s),
                                ))
                            .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedSubject = value!;
                        selectedChapter = null;
                      });
                      _loadChapters(selectedSubject);
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_chapters.isNotEmpty)
                    DropdownButtonFormField<String?>(
                      value: selectedChapter,
                      decoration: const InputDecoration(labelText: '章节'),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('无')),
                        ..._chapters.map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c),
                            )),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedChapter = value;
                        });
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  if (titleController.text.trim().isEmpty) {
                    showSnackBar(context, '请输入标题', isError: true);
                    return;
                  }
                  _addNode(
                    parentNode: parentNode,
                    title: titleController.text.trim(),
                    content: contentController.text.trim(),
                    type: selectedType,
                    subject: selectedSubject,
                    chapter: selectedChapter,
                  );
                  Navigator.pop(context);
                },
                child: const Text('添加'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 显示编辑节点对话框
  void _showEditNodeDialog(MindMapNode node) {
    final titleController = TextEditingController(text: node.title);
    final contentController = TextEditingController(text: node.content);
    NodeType selectedType = node.type;
    String selectedSubject = node.subject;
    String? selectedChapter = node.chapter;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('编辑节点'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: '标题',
                      hintText: '输入节点标题',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: contentController,
                    decoration: const InputDecoration(
                      labelText: '内容',
                      hintText: '输入节点简介（可选）',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  if (node.type != NodeType.root)
                    DropdownButtonFormField<NodeType>(
                      value: selectedType,
                      decoration: const InputDecoration(labelText: '类型'),
                      items: NodeType.values
                          .map((type) => DropdownMenuItem(
                                value: type,
                                child: Text(_getNodeTypeName(type)),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedType = value!;
                        });
                      },
                    ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedSubject,
                    decoration: const InputDecoration(labelText: '学科'),
                    items: _subjects.isEmpty
                        ? [
                            const DropdownMenuItem(
                                value: '其他', child: Text('其他'))
                          ]
                        : _subjects
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s),
                                ))
                            .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedSubject = value!;
                        selectedChapter = null;
                      });
                      _loadChapters(selectedSubject);
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_chapters.isNotEmpty)
                    DropdownButtonFormField<String?>(
                      value: selectedChapter,
                      decoration: const InputDecoration(labelText: '章节'),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('无')),
                        ..._chapters.map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c),
                            )),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedChapter = value;
                        });
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  if (titleController.text.trim().isEmpty) {
                    showSnackBar(context, '请输入标题', isError: true);
                    return;
                  }
                  _updateNode(
                    node: node,
                    title: titleController.text.trim(),
                    content: contentController.text.trim(),
                    type: selectedType,
                    subject: selectedSubject,
                    chapter: selectedChapter,
                  );
                  Navigator.pop(context);
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 添加节点
  void _addNode({
    MindMapNode? parentNode,
    required String title,
    required String content,
    required NodeType type,
    required String subject,
    String? chapter,
  }) {
    if (_mindMapData == null) return;

    // 计算新节点位置
    double x = 0, y = 0;
    if (parentNode != null) {
      final random = DateTime.now().millisecond;
      final angle = (random / 1000) * 2 * pi;
      const distance = 150.0;
      x = parentNode.x + cos(angle) * distance;
      y = parentNode.y + sin(angle) * distance;
    }

    final newNode = MindMapNode(
      title: title,
      content: content,
      type: type,
      subject: subject,
      chapter: chapter,
      x: x,
      y: y,
      parentId: parentNode?.id,
    );

    setState(() {
      if (parentNode != null) {
        parentNode.addChild(newNode);
      } else {
        // 添加到根节点
        _mindMapData!.rootNode.addChild(newNode);
      }
    });

    showSnackBar(context, '节点已添加');
  }

  /// 更新节点
  void _updateNode({
    required MindMapNode node,
    required String title,
    required String content,
    required NodeType type,
    required String subject,
    String? chapter,
  }) {
    if (_mindMapData == null) return;

    setState(() {
      node.title = title;
      node.content = content;
      if (node.type != NodeType.root) {
        node.type = type;
      }
      node.subject = subject;
      node.chapter = chapter;
      node.updatedAt = DateTime.now().millisecondsSinceEpoch;
    });

    showSnackBar(context, '节点已更新');
  }

  /// 删除节点
  void _deleteNode(MindMapNode node) {
    if (_mindMapData == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除节点 "${node.title}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _mindMapData!.removeNode(node.id);
              });
              Navigator.pop(context);
              showSnackBar(context, '节点已删除');
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  String _getNodeTypeName(NodeType type) {
    switch (type) {
      case NodeType.root:
        return '根节点';
      case NodeType.subject:
        return '学科';
      case NodeType.chapter:
        return '章节';
      case NodeType.knowledgePoint:
        return '知识点';
      case NodeType.wrongQuestion:
        return '错题';
      case NodeType.note:
        return '笔记';
      case NodeType.mustRemember:
        return '必记必背';
      case NodeType.keyPoint:
        return '考点';
      case NodeType.custom:
        return '自定义';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_mindMapData?.title ?? '思维导图'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _showFilterDialog,
            icon: const Icon(Icons.filter_list),
            tooltip: '筛选',
          ),
          IconButton(
            onPressed: _exportToImage,
            icon: const Icon(Icons.share),
            tooltip: '导出图片',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _mindMapData == null
              ? _buildEmptyState()
              : _buildMindMap(),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'add_node',
            onPressed: () => _showAddNodeDialog(),
            child: const Icon(Icons.add),
            tooltip: '添加节点',
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'zoom_in',
            onPressed: () {
              setState(() {
                _viewState.scale = (_viewState.scale * 1.2).clamp(0.5, 3.0);
              });
              _updateTransformation();
            },
            child: const Icon(Icons.zoom_in),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'zoom_out',
            onPressed: () {
              setState(() {
                _viewState.scale = (_viewState.scale / 1.2).clamp(0.5, 3.0);
              });
              _updateTransformation();
            },
            child: const Icon(Icons.zoom_out),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'reset',
            onPressed: _resetView,
            child: const Icon(Icons.center_focus_strong),
          ),
        ],
      ),
    );
  }

  void _updateTransformation() {
    _transformationController.value = Matrix4.identity()
      ..scale(_viewState.scale)
      ..translate(_viewState.offset.dx, _viewState.offset.dy);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_tree_outlined,
              size: 80,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 24),
            Text(
              '暂无思维导图数据',
              style: TextStyle(
                fontSize: AppFontSize.xl,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '您还没有添加任何学习内容。\n添加知识点、错题、笔记或必记必背后，思维导图将自动生成。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppFontSize.md,
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _generateMindMap,
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () => _showCreateDemoMindMap(),
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('创建示例'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 创建示例思维导图
  Future<void> _showCreateDemoMindMap() async {
    setState(() => _isLoading = true);
    try {
      // 创建示例数据
      final rootNode = MindMapNode(
        id: 'root',
        title: '学习知识图谱',
        content: '示例思维导图',
        type: NodeType.root,
        subject: '全部',
        x: 0,
        y: 0,
      );

      // 数学分支
      final mathNode = MindMapNode(
        id: 'subject_math',
        title: '数学',
        content: '数学学科',
        type: NodeType.subject,
        subject: '数学',
        x: -200,
        y: -150,
        parentId: rootNode.id,
      );
      rootNode.addChild(mathNode);

      // 数学 - 函数章节
      final mathChapter1 = MindMapNode(
        id: 'chapter_math_函数',
        title: '函数',
        content: '函数章节',
        type: NodeType.chapter,
        subject: '数学',
        chapter: '函数',
        x: -350,
        y: -250,
        parentId: mathNode.id,
      );
      mathNode.addChild(mathChapter1);

      // 函数 - 知识点
      mathChapter1.addChild(MindMapNode(
        title: '函数概念',
        content: '函数的基本概念和定义',
        type: NodeType.knowledgePoint,
        subject: '数学',
        chapter: '函数',
        x: -480,
        y: -320,
        parentId: mathChapter1.id,
      ));

      mathChapter1.addChild(MindMapNode(
        title: '定义域',
        content: '函数定义域的求法',
        type: NodeType.wrongQuestion,
        subject: '数学',
        chapter: '函数',
        x: -480,
        y: -180,
        parentId: mathChapter1.id,
      ));

      // 物理分支
      final physicsNode = MindMapNode(
        id: 'subject_physics',
        title: '物理',
        content: '物理学科',
        type: NodeType.subject,
        subject: '物理',
        x: 200,
        y: -150,
        parentId: rootNode.id,
      );
      rootNode.addChild(physicsNode);

      // 物理 - 力学章节
      final physicsChapter1 = MindMapNode(
        id: 'chapter_physics_力学',
        title: '力学',
        content: '力学章节',
        type: NodeType.chapter,
        subject: '物理',
        chapter: '力学',
        x: 350,
        y: -250,
        parentId: physicsNode.id,
      );
      physicsNode.addChild(physicsChapter1);

      physicsChapter1.addChild(MindMapNode(
        title: '牛顿定律',
        content: '牛顿三大定律',
        type: NodeType.knowledgePoint,
        subject: '物理',
        chapter: '力学',
        x: 480,
        y: -320,
        parentId: physicsChapter1.id,
      ));

      physicsChapter1.addChild(MindMapNode(
        title: 'F=ma',
        content: '牛顿第二定律公式',
        type: NodeType.mustRemember,
        subject: '物理',
        chapter: '力学',
        x: 480,
        y: -180,
        parentId: physicsChapter1.id,
      ));

      setState(() {
        _mindMapData = MindMapData(
          rootNode: rootNode,
          title: '示例：学习知识图谱',
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );
        _isLoading = false;
      });

      _resetView();

      if (mounted) {
        showSnackBar(context, '示例思维导图已创建');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showSnackBar(context, '创建示例失败: $e', isError: true);
      }
    }
  }

  Widget _buildMindMap() {
    return RepaintBoundary(
      key: _mindMapKey,
      child: InteractiveViewer(
        boundaryMargin: const EdgeInsets.all(500),
        minScale: 0.3,
        maxScale: 4.0,
        transformationController: _transformationController,
        onInteractionUpdate: (details) {
          // 可以在这里保存视图状态
        },
        child: GestureDetector(
          onTap: () {
            setState(() {
              _viewState.selectedNodeId = null;
            });
          },
          child: Container(
            width: 2000,
            height: 2000,
            color: Colors.transparent,
            child: CustomPaint(
              painter: MindMapPainter(
                mindMapData: _mindMapData!,
                viewState: _viewState,
                onNodeTap: (nodeId) {
                  final node = _mindMapData!.findNodeById(nodeId);
                  if (node != null) {
                    setState(() {
                      _viewState.selectedNodeId = nodeId;
                    });
                    _showNodeDetail(node);
                  }
                },
                onNodeLongPress: (nodeId) {
                  final node = _mindMapData!.findNodeById(nodeId);
                  if (node != null) {
                    _showNodeContextMenu(node);
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 显示节点上下文菜单
  void _showNodeContextMenu(MindMapNode node) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('查看详情'),
              onTap: () {
                Navigator.pop(context);
                _showNodeDetail(node);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('添加子节点'),
              onTap: () {
                Navigator.pop(context);
                _showAddNodeDialog(parentNode: node);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑节点'),
              onTap: () {
                Navigator.pop(context);
                _showEditNodeDialog(node);
              },
            ),
            if (node.type != NodeType.root)
              ListTile(
                leading: Icon(Icons.delete, color: AppColors.error),
                title: Text('删除节点', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteNode(node);
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// MindMapPainter - 思维导图绘制器
// ============================================================

class MindMapPainter extends CustomPainter {
  final MindMapData mindMapData;
  final MindMapViewState viewState;
  final Function(String nodeId)? onNodeTap;
  final Function(String nodeId)? onNodeLongPress;

  MindMapPainter({
    required this.mindMapData,
    required this.viewState,
    this.onNodeTap,
    this.onNodeLongPress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 绘制连接线
    _drawConnections(canvas, center);

    // 绘制节点（从根节点开始递归绘制）
    _drawNode(canvas, mindMapData.rootNode, center);
  }

  /// 递归绘制节点及其子节点
  void _drawNode(Canvas canvas, MindMapNode node, Offset center) {
    final position = Offset(center.dx + node.x, center.dy + node.y);
    final isSelected = viewState.selectedNodeId == node.id;

    // 绘制到父节点的连线
    if (node.parentId != null) {
      final parent = mindMapData.findNodeById(node.parentId!);
      if (parent != null) {
        final parentPos = Offset(center.dx + parent.x, center.dy + parent.y);
        _drawParentChildLine(canvas, parentPos, position, node.getColor(null as BuildContext));
      }
    }

    // 绘制节点
    _drawNodeCircle(canvas, node, position, isSelected);

    // 递归绘制子节点
    for (final child in node.children) {
      _drawNode(canvas, child, center);
    }
  }

  void _drawConnections(Canvas canvas, Offset center) {
    if (!viewState.showConnections) return;

    for (final connection in mindMapData.connections) {
      final source = mindMapData.findNodeById(connection.sourceId);
      final target = mindMapData.findNodeById(connection.targetId);

      if (source == null || target == null) continue;

      final start = Offset(center.dx + source.x, center.dy + source.y);
      final end = Offset(center.dx + target.x, center.dy + target.y);

      final paint = Paint()
        ..color = connection.isManual ? Colors.orange : Colors.grey.shade400
        ..strokeWidth = connection.strokeWidth
        ..style = PaintingStyle.stroke;

      // 绘制曲线连接
      final path = Path();
      path.moveTo(start.dx, start.dy);

      final controlPoint = Offset(
        (start.dx + end.dx) / 2,
        (start.dy + end.dy) / 2,
      );

      path.quadraticBezierTo(
        controlPoint.dx,
        controlPoint.dy,
        end.dx,
        end.dy,
      );

      canvas.drawPath(path, paint);

      // 绘制关联标签
      if (connection.relation != null && viewState.showLabels) {
        _drawConnectionLabel(canvas, controlPoint, connection.relation!);
      }
    }
  }

  void _drawParentChildLine(Canvas canvas, Offset start, Offset end, Color color) {
    final paint = Paint()
      ..color = color.withOpacity(0.4)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // 使用贝塞尔曲线绘制平滑连线
    final path = Path();
    path.moveTo(start.dx, start.dy);

    final midX = (start.dx + end.dx) / 2;
    path.cubicTo(
      midX, start.dy,
      midX, end.dy,
      end.dx, end.dy,
    );

    canvas.drawPath(path, paint);
  }

  void _drawConnectionLabel(Canvas canvas, Offset position, String text) {
    final textStyle = TextStyle(
      color: Colors.grey.shade600,
      fontSize: 10,
    );
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final rect = Rect.fromCenter(
      center: position,
      width: textPainter.width + 8,
      height: textPainter.height + 4,
    );

    final paint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      paint,
    );

    textPainter.paint(
      canvas,
      Offset(position.dx - textPainter.width / 2,
          position.dy - textPainter.height / 2),
    );
  }

  void _drawNodeCircle(
      Canvas canvas, MindMapNode node, Offset position, bool isSelected) {
    // 获取节点颜色
    Color nodeColor;
    switch (node.type) {
      case NodeType.root:
        nodeColor = Colors.blue;
        break;
      case NodeType.subject:
        nodeColor = Colors.purple;
        break;
      case NodeType.chapter:
        nodeColor = Colors.cyan;
        break;
      case NodeType.knowledgePoint:
        nodeColor = Colors.green;
        break;
      case NodeType.wrongQuestion:
        nodeColor = Colors.red;
        break;
      case NodeType.note:
        nodeColor = Colors.orange;
        break;
      case NodeType.mustRemember:
        nodeColor = Colors.indigo;
        break;
      case NodeType.keyPoint:
        nodeColor = Colors.deepOrange;
        break;
      case NodeType.custom:
        nodeColor = Colors.grey;
        break;
    }

    // 绘制节点阴影
    if (isSelected) {
      final shadowPaint = Paint()
        ..color = nodeColor.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(position, node.size / 2 + 5, shadowPaint);
    }

    // 绘制节点圆形
    final paint = Paint()
      ..color = nodeColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, node.size / 2, paint);

    // 绘制节点边框
    final borderPaint = Paint()
      ..color = isSelected ? Colors.white : nodeColor.withOpacity(0.5)
      ..strokeWidth = isSelected ? 3 : 1
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(position, node.size / 2, borderPaint);

    // 绘制节点图标
    final icon = node.icon;
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          fontSize: node.size * 0.4,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      Offset(
        position.dx - iconPainter.width / 2,
        position.dy - iconPainter.height / 2,
      ),
    );

    // 绘制节点标签
    if (viewState.showLabels) {
      final textStyle = TextStyle(
        color: Colors.black87,
        fontSize: node.type == NodeType.root ? 14 : 11,
        fontWeight:
            node.type == NodeType.root ? FontWeight.bold : FontWeight.normal,
      );
      final textSpan = TextSpan(text: node.title, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout(maxWidth: 100);

      final labelY = position.dy + node.size / 2 + 4;
      textPainter.paint(
        canvas,
        Offset(position.dx - textPainter.width / 2, labelY),
      );
    }
  }

  @override
  bool shouldRepaint(covariant MindMapPainter oldDelegate) {
    return oldDelegate.mindMapData != mindMapData ||
        oldDelegate.viewState.selectedNodeId != viewState.selectedNodeId ||
        oldDelegate.viewState.scale != viewState.scale;
  }

  @override
  bool hitTest(Offset position) {
    final center = const Offset(1000, 1000);
    final nodes = mindMapData.allNodes;

    for (final node in nodes) {
      final nodePos = Offset(center.dx + node.x, center.dy + node.y);
      final distance = (position - nodePos).distance;

      if (distance <= node.size / 2) {
        onNodeTap?.call(node.id);
        return true;
      }
    }
    return false;
  }
}

// ============================================================
// _NodeDetailSheet - 节点详情底部弹窗
// ============================================================

class _NodeDetailSheet extends StatelessWidget {
  final MindMapNode node;
  final VoidCallback? onEdit;
  final VoidCallback? onAddChild;
  final VoidCallback? onDelete;

  const _NodeDetailSheet({
    required this.node,
    this.onEdit,
    this.onAddChild,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.3,
      maxChildSize: 0.7,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题栏
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: node.getColor(context).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      node.typeName,
                      style: TextStyle(
                        fontSize: AppFontSize.sm,
                        color: node.getColor(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 节点标题
              Text(
                node.title,
                style: TextStyle(
                  fontSize: AppFontSize.xl,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              // 节点信息
              _buildInfoItem('学科', node.subject),
              if (node.chapter != null) _buildInfoItem('章节', node.chapter!),
              if (node.content.isNotEmpty) _buildInfoItem('简介', node.content),
              _buildInfoItem(
                '子节点数',
                '${node.children.length}',
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              // 操作按钮
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onAddChild,
                      icon: const Icon(Icons.add),
                      label: const Text('添加子节点'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit),
                      label: const Text('编辑'),
                    ),
                  ),
                ],
              ),
              if (onDelete != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete, color: AppColors.error),
                    label: Text('删除', style: TextStyle(color: AppColors.error)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.error.withOpacity(0.5)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: AppFontSize.sm,
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: AppFontSize.sm,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
