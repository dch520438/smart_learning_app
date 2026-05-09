import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
// MindMapScreen - 思维导图页面
// ============================================================

class MindMapScreen extends StatefulWidget {
  const MindMapScreen({super.key});

  @override
  State<MindMapScreen> createState() => _MindMapScreenState();
}

class _MindMapScreenState extends State<MindMapScreen> {
  final MindMapService _mindMapService = MindMapService();
  final DatabaseService _dbService = DatabaseService();
  final GlobalKey _mindMapKey = GlobalKey();

  MindMapData? _mindMapData;
  MindMapViewState _viewState = MindMapViewState();
  bool _isLoading = true;
  String _currentType = 'all';
  String? _currentFilter;

  // 可用选项
  List<String> _subjects = [];
  List<String> _tags = [];
  List<String> _examMethods = [];
  List<String> _keyPoints = [];

  @override
  void initState() {
    super.initState();
    _loadOptions();
    _generateMindMap();
  }

  Future<void> _loadOptions() async {
    final subjects = await _mindMapService.getAllSubjects();
    final tags = await _mindMapService.getAllTags();
    final examMethods = await _mindMapService.getAllExamMethods();
    final keyPoints = await _mindMapService.getAllKeyPoints();

    setState(() {
      _subjects = subjects;
      _tags = tags;
      _examMethods = examMethods;
      _keyPoints = keyPoints;
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
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showSnackBar(context, '生成思维导图失败: $e', isError: true);
      }
    }
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
      final file = File('${tempDir.path}/mind_map_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);

      // 分享图片
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '思维导图: ${_mindMapData?.title ?? '学习知识图谱'}',
      );

      if (mounted) {
        showSnackBar(context, '图片已导出');
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
                      _buildFilterOption('全部内容', 'all', null, Icons.account_tree),
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
                      
                      // 按考法
                      if (_examMethods.isNotEmpty) ...[
                        _buildFilterSection('按考法'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _examMethods.map((em) => ActionChip(
                            label: Text(em),
                            onPressed: () {
                              setState(() {
                                _currentType = 'exam_method';
                                _currentFilter = em;
                              });
                              _generateMindMap();
                              Navigator.pop(context);
                            },
                          )).toList(),
                        ),
                        const Divider(),
                      ],
                      
                      // 按考点
                      if (_keyPoints.isNotEmpty) ...[
                        _buildFilterSection('按考点'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _keyPoints.map((kp) => ActionChip(
                            label: Text(kp),
                            onPressed: () {
                              setState(() {
                                _currentType = 'key_point';
                                _currentFilter = kp;
                              });
                              _generateMindMap();
                              Navigator.pop(context);
                            },
                          )).toList(),
                        ),
                        const Divider(),
                      ],
                      
                      // 按标签
                      if (_tags.isNotEmpty) ...[
                        _buildFilterSection('按标签'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _tags.map((t) => ActionChip(
                            label: Text(t),
                            onPressed: () {
                              setState(() {
                                _currentType = 'tag';
                                _currentFilter = t;
                              });
                              _generateMindMap();
                              Navigator.pop(context);
                            },
                          )).toList(),
                        ),
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

  Widget _buildFilterOption(String label, String type, String? value, IconData icon, [Color? color]) {
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

  void _showNodeDetail(MindMapNode node) {
    // 根据节点类型显示详情
    if (node.data == null) return;

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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                if (item is KnowledgePoint) ...[
                  _buildDetailItem('学科', item.subject),
                  _buildDetailItem('难度', '${item.difficulty}/5'),
                  _buildDetailItem('掌握度', '${item.masteryLevel}%'),
                  if (item.tags.isNotEmpty)
                    _buildDetailItem('标签', item.tags.join(', ')),
                  if (item.examMethods.isNotEmpty)
                    _buildDetailItem('考法', item.examMethods.join(', ')),
                  if (item.keyPoints.isNotEmpty)
                    _buildDetailItem('考点', item.keyPoints.join(', ')),
                ] else if (item is WrongQuestion) ...[
                  _buildDetailItem('学科', item.subject),
                  _buildDetailItem('错误类型', item.errorType),
                  _buildDetailItem('错误次数', '${item.errorCount}'),
                  if (item.examMethods.isNotEmpty)
                    _buildDetailItem('考法', item.examMethods.join(', ')),
                  if (item.keyPoints.isNotEmpty)
                    _buildDetailItem('考点', item.keyPoints.join(', ')),
                ] else if (item is Note) ...[
                  _buildDetailItem('学科', item.subject),
                  if (item.tags.isNotEmpty)
                    _buildDetailItem('标签', item.tags.join(', ')),
                  if (item.examMethods.isNotEmpty)
                    _buildDetailItem('考法', item.examMethods.join(', ')),
                  if (item.keyPoints.isNotEmpty)
                    _buildDetailItem('考点', item.keyPoints.join(', ')),
                ] else if (item is MustRemember) ...[
                  _buildDetailItem('学科', item.subject),
                  _buildDetailItem('分类', item.category),
                  _buildDetailItem('记忆程度', '${item.memoryLevel}%'),
                  if (item.examMethods.isNotEmpty)
                    _buildDetailItem('考法', item.examMethods.join(', ')),
                  if (item.keyPoints.isNotEmpty)
                    _buildDetailItem('考点', item.keyPoints.join(', ')),
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
                        if (item is WrongQuestion && item.analysis.isNotEmpty) ...[
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          : _mindMapData == null || _mindMapData!.nodes.isEmpty
              ? _buildEmptyState()
              : _buildMindMap(),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'zoom_in',
            onPressed: () {
              setState(() {
                _viewState.scale = (_viewState.scale * 1.2).clamp(0.5, 3.0);
              });
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
            },
            child: const Icon(Icons.zoom_out),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'reset',
            onPressed: () {
              setState(() {
                _viewState = MindMapViewState();
              });
            },
            child: const Icon(Icons.center_focus_strong),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: 64,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无数据',
            style: TextStyle(
              fontSize: AppFontSize.lg,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '添加知识点、错题、笔记等内容后\n思维导图将自动生成',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppFontSize.sm,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMindMap() {
    return RepaintBoundary(
      key: _mindMapKey,
      child: InteractiveViewer(
        boundaryMargin: const EdgeInsets.all(100),
        minScale: 0.5,
        maxScale: 3.0,
        transformationController: TransformationController()
          ..value = Matrix4.identity()
            ..scale(_viewState.scale)
            ..translate(_viewState.offset.dx, _viewState.offset.dy),
        onInteractionUpdate: (details) {
          // 更新视图状态
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
                  final node = _mindMapData!.getNodeById(nodeId);
                  if (node != null) {
                    setState(() {
                      _viewState.selectedNodeId = nodeId;
                    });
                    _showNodeDetail(node);
                  }
                },
              ),
            ),
          ),
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

  MindMapPainter({
    required this.mindMapData,
    required this.viewState,
    this.onNodeTap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 绘制连接线
    if (viewState.showConnections) {
      _drawConnections(canvas, center);
    }

    // 绘制节点
    for (final node in mindMapData.nodes) {
      _drawNode(canvas, node, center);
    }
  }

  void _drawConnections(Canvas canvas, Offset center) {
    for (final connection in mindMapData.connections) {
      final source = mindMapData.getSourceNode(connection);
      final target = mindMapData.getTargetNode(connection);
      
      if (source == null || target == null) continue;

      final start = Offset(
        center.dx + source.x,
        center.dy + source.y,
      );
      final end = Offset(
        center.dx + target.x,
        center.dy + target.y,
      );

      final paint = Paint()
        ..color = connection.getColor(null as BuildContext)
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

    // 绘制父子关系线
    for (final node in mindMapData.nodes) {
      if (node.parentId != null) {
        final parent = mindMapData.getNodeById(node.parentId!);
        if (parent != null) {
          final start = Offset(
            center.dx + parent.x,
            center.dy + parent.y,
          );
          final end = Offset(
            center.dx + node.x,
            center.dy + node.y,
          );

          final paint = Paint()
            ..color = Colors.grey.shade400
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke;

          canvas.drawLine(start, end, paint);
        }
      }
    }
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
      Offset(position.dx - textPainter.width / 2, position.dy - textPainter.height / 2),
    );
  }

  void _drawNode(Canvas canvas, MindMapNode node, Offset center) {
    final position = Offset(center.dx + node.x, center.dy + node.y);
    final isSelected = viewState.selectedNodeId == node.id;
    
    // 节点颜色
    Color nodeColor;
    switch (node.type) {
      case NodeType.root:
        nodeColor = Colors.blue;
        break;
      case NodeType.subject:
        nodeColor = Colors.purple;
        break;
      case NodeType.category:
        nodeColor = Colors.teal;
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
      case NodeType.tag:
        nodeColor = Colors.cyan;
        break;
      case NodeType.examMethod:
        nodeColor = Colors.teal.shade700;
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
        fontWeight: node.type == NodeType.root ? FontWeight.bold : FontWeight.normal,
      );
      final textSpan = TextSpan(text: node.label, style: textStyle);
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
    // 处理点击事件
    final center = Offset(1000, 1000); // 对应画布中心
    
    for (final node in mindMapData.nodes) {
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
