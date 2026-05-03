import 'dart:convert';
import 'dart:io' as io;
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/mind_map_data.dart';
import '../../services/database_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';

// ============================================================
// MindMapScreen - 思维导图列表页面
// ============================================================

class MindMapScreen extends StatefulWidget {
  const MindMapScreen({super.key});

  @override
  State<MindMapScreen> createState() => _MindMapScreenState();
}

class _MindMapScreenState extends State<MindMapScreen> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _mindMaps = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadMindMaps();
  }

  Future<void> _loadMindMaps() async {
    setState(() => _isLoading = true);
    final maps = await _db.queryAllMindMaps(orderBy: 'updated_at DESC');
    setState(() {
      _mindMaps = maps;
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredMaps {
    if (_searchQuery.isEmpty) return _mindMaps;
    final q = _searchQuery.toLowerCase();
    return _mindMaps.where((m) {
      final title = (m['title'] as String? ?? '').toLowerCase();
      final subject = (m['subject'] as String? ?? '').toLowerCase();
      return title.contains(q) || subject.contains(q);
    }).toList();
  }

  /// 计算节点总数
  int _countNodes(MindMapNode? node) {
    if (node == null) return 0;
    int count = 1;
    for (final child in node.children) {
      count += _countNodes(child);
    }
    return count;
  }

  /// 从数据库记录解析 MindMapData
  MindMapData? _parseMindMapData(Map<String, dynamic> row) {
    try {
      final mapDataStr = row['map_data'] as String?;
      if (mapDataStr == null) return null;
      final mapDataJson = jsonDecode(mapDataStr) as Map<String, dynamic>;
      return MindMapData.fromJson(mapDataJson);
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteMindMap(int id, String title) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context: context,
      title: '删除思维导图',
      message: '确定要删除"$title"吗？此操作不可撤销。',
    );
    if (confirmed == true) {
      await _db.deleteMindMap(id);
      _loadMindMaps();
      if (mounted) showSnackBar(context, '已删除');
    }
  }

  Future<void> _createNewMindMap() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => const _MindMapEditorScreen(),
      ),
    );
    if (result != null) {
      _loadMindMaps();
    }
  }

  Future<void> _openMindMap(Map<String, dynamic> row) async {
    final data = _parseMindMapData(row);
    if (data == null) return;
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => _MindMapEditorScreen(
          dbRow: row,
          mindMapData: data,
        ),
      ),
    );
    if (result != null) {
      _loadMindMaps();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('思维导图'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: _MindMapSearchDelegate(
                  mindMaps: _mindMaps,
                  onOpen: _openMindMap,
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredMaps.isEmpty
              ? AppEmptyState(
                  message: _searchQuery.isEmpty ? '暂无思维导图' : '未找到匹配的思维导图',
                  icon: Icons.account_tree_outlined,
                  actionText: _searchQuery.isEmpty ? '创建思维导图' : null,
                  onAction: _searchQuery.isEmpty ? _createNewMindMap : null,
                )
              : RefreshIndicator(
                  onRefresh: _loadMindMaps,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _filteredMaps.length,
                    itemBuilder: (context, index) {
                      return _MindMapCard(
                        row: _filteredMaps[index],
                        onTap: () => _openMindMap(_filteredMaps[index]),
                        onLongPress: () => _deleteMindMap(
                          _filteredMaps[index]['id'] as int,
                          _filteredMaps[index]['title'] as String? ?? '',
                        ),
                        parseData: _parseMindMapData,
                        countNodes: _countNodes,
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewMindMap,
        icon: const Icon(Icons.add),
        label: const Text('新建'),
      ),
    );
  }
}

// ============================================================
// _MindMapSearchDelegate - 搜索代理
// ============================================================

class _MindMapSearchDelegate extends SearchDelegate<String> {
  final List<Map<String, dynamic>> mindMaps;
  final Function(Map<String, dynamic>) onOpen;

  _MindMapSearchDelegate({required this.mindMaps, required this.onOpen});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
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
  Widget buildResults(BuildContext context) {
    final q = query.toLowerCase();
    final filtered = mindMaps.where((m) {
      final title = (m['title'] as String? ?? '').toLowerCase();
      final subject = (m['subject'] as String? ?? '').toLowerCase();
      return title.contains(q) || subject.contains(q);
    }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('未找到匹配的思维导图'));
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final m = filtered[index];
        return ListTile(
          leading: const Icon(Icons.account_tree, color: AppColors.primary),
          title: Text(m['title'] as String? ?? '未命名'),
          subtitle: Text(m['subject'] as String? ?? '未分类'),
          onTap: () {
            close(context, '');
            onOpen(m);
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return buildResults(context);
  }
}

// ============================================================
// _MindMapCard - 思维导图卡片
// ============================================================

class _MindMapCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final MindMapData? Function(Map<String, dynamic>) parseData;
  final int Function(MindMapNode?) countNodes;

  const _MindMapCard({
    required this.row,
    required this.onTap,
    required this.onLongPress,
    required this.parseData,
    required this.countNodes,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = row['title'] as String? ?? '未命名';
    final subject = row['subject'] as String? ?? '未分类';
    final updatedAtStr = row['updated_at'] as String? ?? '';
    final data = parseData(row);
    final nodeCount = data != null ? countNodes(data.root) : 0;
    final subjectColor = getSubjectColor(subject);

    DateTime? updatedAt;
    try {
      updatedAt = DateTime.parse(updatedAtStr);
    } catch (_) {}

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 缩略图预览
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg),
                ),
                child: Container(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withOpacity(0.3),
                  child: data != null && data.root != null
                      ? CustomPaint(
                          painter: _MindMapThumbnailPainter(
                            root: data.root,
                            color: subjectColor,
                          ),
                        )
                      : Center(
                          child: Icon(
                            Icons.account_tree_outlined,
                            size: 40,
                            color: AppColors.textHint,
                          ),
                        ),
                ),
              ),
            ),
            // 信息区域
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: subjectColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                subject,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: subjectColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$nodeCount 个节点',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      updatedAt != null
                          ? formatFriendlyTime(updatedAt)
                          : '',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// _MindMapThumbnailPainter - 缩略图绘制器
// ============================================================

class _MindMapThumbnailPainter extends CustomPainter {
  final MindMapNode root;
  final Color color;

  _MindMapThumbnailPainter({required this.root, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final positions = <String, Offset>{};
    _layoutNodes(root, size.width / 2, size.height / 2, 0, size, positions);

    // 绘制连线
    _drawConnections(canvas, root, positions);
    // 绘制节点
    _drawNodes(canvas, root, positions);
  }

  void _layoutNodes(
    MindMapNode node,
    double x,
    double y,
    int depth,
    Size size,
    Map<String, Offset> positions,
  ) {
    positions[node.id] = Offset(x, y);
    if (node.children.isEmpty) return;

    final spread = size.width * 0.35 / max(depth + 1, 1);
    final verticalGap = size.height * 0.3 / max(depth + 1, 1);
    final totalHeight = (node.children.length - 1) * verticalGap;
    final startY = y - totalHeight / 2;

    for (int i = 0; i < node.children.length; i++) {
      final child = node.children[i];
      final angle = (i / (node.children.length - 1)) * pi - pi / 2;
      final cx = x + cos(angle) * spread;
      final cy = startY + i * verticalGap;
      _layoutNodes(child, cx, cy, depth + 1, size, positions);
    }
  }

  void _drawConnections(
    Canvas canvas,
    MindMapNode node,
    Map<String, Offset> positions,
  ) {
    final paint = Paint()
      ..color = color.withOpacity(0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (final child in node.children) {
      final startPos = positions[node.id];
      final endPos = positions[child.id];
      if (startPos == null || endPos == null) continue;

      final path = Path();
      path.moveTo(startPos.dx, startPos.dy);
      final midX = (startPos.dx + endPos.dx) / 2;
      path.cubicTo(midX, startPos.dy, midX, endPos.dy, endPos.dx, endPos.dy);
      canvas.drawPath(path, paint);

      _drawConnections(canvas, child, positions);
    }
  }

  void _drawNodes(
    Canvas canvas,
    MindMapNode node,
    Map<String, Offset> positions,
  ) {
    final pos = positions[node.id];
    if (pos == null) return;

    final nodeColor = node.color != null
        ? parseColor(node.color!)
        : color;
    final isRoot = node.id == root.id;
    final radius = isRoot ? 6.0 : 4.0;

    final paint = Paint()
      ..color = nodeColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(pos, radius, paint);

    for (final child in node.children) {
      _drawNodes(canvas, child, positions);
    }
  }

  @override
  bool shouldRepaint(covariant _MindMapThumbnailPainter oldDelegate) {
    return oldDelegate.root != root;
  }
}

// ============================================================
// _MindMapEditorScreen - 思维导图编辑器
// ============================================================

class _MindMapEditorScreen extends StatefulWidget {
  final Map<String, dynamic>? dbRow;
  final MindMapData? mindMapData;

  const _MindMapEditorScreen({this.dbRow, this.mindMapData});

  @override
  State<_MindMapEditorScreen> createState() => _MindMapEditorScreenState();
}

class _MindMapEditorScreenState extends State<_MindMapEditorScreen> {
  final DatabaseService _db = DatabaseService();

  late TextEditingController _titleController;
  late String _subject;
  MindMapNode? _root;
  int? _dbId;

  // 画布变换
  double _scale = 1.0;
  Offset _offset = Offset.zero;

  // 拖拽状态
  MindMapNode? _draggingNode;
  Offset _dragStart = Offset.zero;
  Offset _dragNodeStart = Offset.zero;

  // 布局方式
  _LayoutMode _layoutMode = _LayoutMode.horizontal;

  // 撤销/重做
  final List<MindMapNode> _undoStack = [];
  final List<MindMapNode> _redoStack = [];

  // 节点位置缓存
  final Map<String, Offset> _nodePositions = {};

  // 节点尺寸缓存
  final Map<String, Size> _nodeSizes = {};

  bool _isSaving = false;
  bool _hasChanges = false;

  // 颜色选择
  static const List<Color> _colorOptions = [
    Color(0xFF1565C0), // 蓝
    Color(0xFFE53935), // 红
    Color(0xFF43A047), // 绿
    Color(0xFFFB8C00), // 橙
    Color(0xFF8E24AA), // 紫
    Color(0xFF00ACC1), // 青
    Color(0xFF6D4C41), // 棕
    Color(0xFF546E7A), // 灰蓝
  ];

  @override
  void initState() {
    super.initState();
    if (widget.mindMapData != null) {
      _titleController =
          TextEditingController(text: widget.mindMapData!.title);
      _subject = widget.mindMapData!.subject;
      _root = widget.mindMapData!.root;
      _dbId = widget.dbRow?['id'] as int?;
    } else {
      _titleController = TextEditingController(text: '新建思维导图');
      _subject = '其他';
      _root = null;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // ---- 撤销/重做 ----

  void _pushUndo() {
    if (_root != null) {
      _undoStack.add(_root!);
      if (_undoStack.length > 50) _undoStack.removeAt(0);
      _redoStack.clear();
      _hasChanges = true;
    }
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_root!);
    _root = _undoStack.removeLast();
    _recalculateLayout();
    setState(() {});
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_root!);
    _root = _redoStack.removeLast();
    _recalculateLayout();
    setState(() {});
  }

  // ---- 布局计算 ----

  void _recalculateLayout() {
    _nodePositions.clear();
    _nodeSizes.clear();
    if (_root == null) return;
    _calculateNodeSizes(_root!);
    _layoutNode(_root!, Offset.zero, _layoutMode);
  }

  void _calculateNodeSizes(MindMapNode node) {
    final text = node.text;
    final isRoot = node == _root;
    final fontSize = isRoot ? 16.0 : 13.0;
    final padding = isRoot ? 24.0 : 16.0;

    // 估算文字宽度
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: 200);

    _nodeSizes[node.id] = Size(
      textPainter.width + padding * 2,
      max(textPainter.height + padding, 36.0),
    );

    for (final child in node.children) {
      _calculateNodeSizes(child);
    }
  }

  void _layoutNode(
    MindMapNode node,
    Offset offset,
    _LayoutMode mode,
  ) {
    _nodePositions[node.id] = offset;
    if (node.children.isEmpty) return;

    final nodeSize = _nodeSizes[node.id] ?? const Size(100, 36);
    const hGap = 60.0;
    const vGap = 20.0;

    switch (mode) {
      case _LayoutMode.horizontal:
        _layoutHorizontal(node, offset, nodeSize, hGap, vGap);
        break;
      case _LayoutMode.vertical:
        _layoutVertical(node, offset, nodeSize, hGap, vGap);
        break;
      case _LayoutMode.radial:
        _layoutRadial(node, offset, hGap);
        break;
    }
  }

  void _layoutHorizontal(
    MindMapNode node,
    Offset offset,
    Size nodeSize,
    double hGap,
    double vGap,
  ) {
    double totalHeight = 0;
    for (final child in node.children) {
      totalHeight += (_nodeSizes[child.id]?.height ?? 36) + vGap;
    }
    totalHeight -= vGap;

    double currentY = offset.dy - totalHeight / 2;
    for (final child in node.children) {
      final childSize = _nodeSizes[child.id] ?? const Size(80, 36);
      final childOffset = Offset(
        offset.dx + nodeSize.width / 2 + hGap + childSize.width / 2,
        currentY + childSize.height / 2,
      );
      _layoutNode(child, childOffset, _LayoutMode.horizontal);
      currentY += childSize.height + vGap;
    }
  }

  void _layoutVertical(
    MindMapNode node,
    Offset offset,
    Size nodeSize,
    double hGap,
    double vGap,
  ) {
    double totalWidth = 0;
    for (final child in node.children) {
      totalWidth += (_nodeSizes[child.id]?.width ?? 80) + hGap;
    }
    totalWidth -= hGap;

    double currentX = offset.dx - totalWidth / 2;
    for (final child in node.children) {
      final childSize = _nodeSizes[child.id] ?? const Size(80, 36);
      final childOffset = Offset(
        currentX + childSize.width / 2,
        offset.dy + nodeSize.height / 2 + vGap + childSize.height / 2,
      );
      _layoutNode(child, childOffset, _LayoutMode.vertical);
      currentX += childSize.width + hGap;
    }
  }

  void _layoutRadial(
    MindMapNode node,
    Offset offset,
    double hGap,
  ) {
    final count = node.children.length;
    if (count == 0) return;
    final radius = 120.0 + count * 15.0;

    for (int i = 0; i < count; i++) {
      final angle = (2 * pi * i / count) - pi / 2;
      final childOffset = Offset(
        offset.dx + cos(angle) * radius,
        offset.dy + sin(angle) * radius,
      );
      _layoutNode(node.children[i], childOffset, _LayoutMode.radial);
    }
  }

  // ---- 节点操作 ----

  MindMapNode? _findNodeById(MindMapNode? node, String id) {
    if (node == null) return null;
    if (node.id == id) return node;
    for (final child in node.children) {
      final found = _findNodeById(child, id);
      if (found != null) return found;
    }
    return null;
  }

  MindMapNode? _findParentOf(MindMapNode? node, String childId) {
    if (node == null) return null;
    for (final child in node.children) {
      if (child.id == childId) return node;
      final found = _findParentOf(child, childId);
      if (found != null) return found;
    }
    return null;
  }

  MindMapNode _removeNodeFromTree(MindMapNode tree, String nodeId) {
    final newChildren = tree.children
        .where((c) => c.id != nodeId)
        .map((c) => _removeNodeFromTree(c, nodeId))
        .toList();
    return tree.copyWith(children: newChildren);
  }

  MindMapNode _updateNodeInTree(MindMapNode tree, String nodeId, String newText) {
    if (tree.id == nodeId) {
      return tree.copyWith(text: newText);
    }
    return tree.copyWith(
      children: tree.children
          .map((c) => _updateNodeInTree(c, nodeId, newText))
          .toList(),
    );
  }

  MindMapNode _updateNodeColorInTree(
      MindMapNode tree, String nodeId, String newColor) {
    if (tree.id == nodeId) {
      return tree.copyWith(color: newColor);
    }
    return tree.copyWith(
      children: tree.children
          .map((c) => _updateNodeColorInTree(c, nodeId, newColor))
          .toList(),
    );
  }

  MindMapNode _addChildToNode(MindMapNode tree, String parentId, MindMapNode child) {
    if (tree.id == parentId) {
      return tree.copyWith(children: [...tree.children, child]);
    }
    return tree.copyWith(
      children: tree.children
          .map((c) => _addChildToNode(c, parentId, child))
          .toList(),
    );
  }

  void _addRootNode() {
    _pushUndo();
    setState(() {
      _root = MindMapNode(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: '中心主题',
        color: colorToHex(_colorOptions[0]),
      );
    });
    _recalculateLayout();
    _fitToScreen();
  }

  void _addChildNode(String parentId) {
    _pushUndo();
    final newChild = MindMapNode(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: '新节点',
      color: colorToHex(_colorOptions[1]),
    );
    setState(() {
      _root = _addChildToNode(_root!, parentId, newChild);
    });
    _recalculateLayout();
  }

  void _deleteNode(String nodeId) {
    if (_root == null || _root!.id == nodeId) {
      // 删除根节点 = 清空整个导图
      _pushUndo();
      setState(() => _root = null);
      return;
    }
    _pushUndo();
    setState(() {
      _root = _removeNodeFromTree(_root!, nodeId);
    });
    _recalculateLayout();
  }

  void _editNodeText(String nodeId) async {
    final node = _findNodeById(_root, nodeId);
    if (node == null) return;

    final controller = TextEditingController(text: node.text);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑节点'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入节点文字',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (result != null && result.trim().isNotEmpty) {
      _pushUndo();
      setState(() {
        _root = _updateNodeInTree(_root!, nodeId, result.trim());
      });
      _recalculateLayout();
    }
  }

  void _changeNodeColor(String nodeId) async {
    final node = _findNodeById(_root, nodeId);
    if (node == null) return;

    final currentColor = node.color != null
        ? parseColor(node.color!)
        : _colorOptions[0];
    final selected = await showDialog<Color>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择颜色'),
        children: _colorOptions.map((c) {
          return SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(c),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: c == currentColor
                        ? Border.all(color: Colors.black, width: 2)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Text(colorToHex(c)),
              ],
            ),
          );
        }).toList(),
      ),
    );

    if (selected != null) {
      _pushUndo();
      setState(() {
        _root = _updateNodeColorInTree(_root!, nodeId, colorToHex(selected));
      });
    }
  }

  void _showNodeMenu(String nodeId, Offset screenPosition) {
    final isRoot = _root?.id == nodeId;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑文字'),
              onTap: () {
                Navigator.pop(ctx);
                _editNodeText(nodeId);
              },
            ),
            if (!isRoot)
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('添加子节点'),
                onTap: () {
                  Navigator.pop(ctx);
                  _addChildNode(nodeId);
                },
              ),
            ListTile(
              leading: const Icon(Icons.palette),
              title: const Text('改变颜色'),
              onTap: () {
                Navigator.pop(ctx);
                _changeNodeColor(nodeId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('删除节点', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteNode(nodeId);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---- 缩放控制 ----

  void _zoomIn() {
    setState(() => _scale = (_scale * 1.2).clamp(0.3, 3.0));
  }

  void _zoomOut() {
    setState(() => _scale = (_scale / 1.2).clamp(0.3, 3.0));
  }

  void _fitToScreen() {
    if (_root == null || _nodePositions.isEmpty) return;
    final bounds = _calculateBounds();
    final screenSize = MediaQuery.of(context).size;
    final padding = 80.0;
    final scaleX = (screenSize.width - padding * 2) / max(bounds.width, 1);
    final scaleY = (screenSize.height - padding * 2) / max(bounds.height, 1);
    setState(() {
      _scale = min(scaleX, scaleY).clamp(0.3, 2.0);
      _offset = Offset(
        screenSize.width / 2 - (bounds.left + bounds.width / 2) * _scale,
        screenSize.height / 2 - (bounds.top + bounds.height / 2) * _scale,
      );
    });
  }

  Rect _calculateBounds() {
    if (_nodePositions.isEmpty) return Rect.zero;
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final pos in _nodePositions.values) {
      minX = min(minX, pos.dx);
      minY = min(minY, pos.dy);
      maxX = max(maxX, pos.dx);
      maxY = max(maxY, pos.dy);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  // ---- 命中测试 ----

  String? _hitTest(Offset localPos) {
    for (final entry in _nodePositions.entries) {
      final nodePos = entry.value;
      final size = _nodeSizes[entry.key] ?? const Size(80, 36);
      final screenNodePos = Offset(
        nodePos.dx * _scale + _offset.dx,
        nodePos.dy * _scale + _offset.dy,
      );
      final screenSize = Size(size.width * _scale, size.height * _scale);
      final rect = Rect.fromCenter(
        center: screenNodePos,
        width: screenSize.width,
        height: screenSize.height,
      );
      if (rect.contains(localPos)) {
        return entry.key;
      }
    }
    return null;
  }

  // ---- 保存 ----

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      showSnackBar(context, '请输入标题', isError: true);
      return;
    }
    setState(() => _isSaving = true);

    final now = DateTime.now().millisecondsSinceEpoch;
    final data = MindMapData(
      id: widget.mindMapData?.id,
      title: _titleController.text.trim(),
      subject: _subject,
      root: _root,
      createdAt: widget.mindMapData?.createdAt ?? now,
      updatedAt: now,
    );

    final mapDataJson = jsonEncode(data.toJson());

    try {
      if (_dbId != null) {
        await _db.updateMindMap(_dbId!, {
          'title': data.title,
          'subject': data.subject,
          'map_data': mapDataJson,
        });
      } else {
        _dbId = await _db.insertMindMap({
          'uuid': data.id,
          'title': data.title,
          'subject': data.subject,
          'map_data': mapDataJson,
        });
      }
      _hasChanges = false;
      if (mounted) showSnackBar(context, '保存成功');
    } catch (e) {
      if (mounted) showSnackBar(context, '保存失败', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ---- 导出为图片 ----

  Future<void> _exportAsImage() async {
    if (_root == null) {
      showSnackBar(context, '没有可导出的内容', isError: true);
      return;
    }

    final bounds = _calculateBounds();
    final padding = 40.0;
    final width = (bounds.width + padding * 2).ceil();
    final height = (bounds.height + padding * 2).ceil();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

    // 白色背景
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = Colors.white,
    );

    // 偏移使内容居中
    final exportOffset = Offset(
      padding - bounds.left,
      padding - bounds.top,
    );

    final exportPositions = <String, Offset>{};
    for (final entry in _nodePositions.entries) {
      exportPositions[entry.key] = entry.value + exportOffset;
    }

    // 绘制连线
    _drawExportConnections(canvas, _root!, exportPositions);
    // 绘制节点
    _drawExportNodes(canvas, _root!, exportPositions);

    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

    // 保存到临时文件
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/mind_map_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = io.File(path);
      await file.writeAsBytes(byteData.buffer.asUint8List());
      if (mounted) {
        showSnackBar(context, '图片已保存至 $path');
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '导出失败: $e', isError: true);
      }
    }
  }

  void _drawExportConnections(
    Canvas canvas,
    MindMapNode node,
    Map<String, Offset> positions,
  ) {
    final nodeColor = node.color != null
        ? parseColor(node.color!)
        : AppColors.primary;

    final paint = Paint()
      ..color = nodeColor.withOpacity(0.5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (final child in node.children) {
      final startPos = positions[node.id];
      final endPos = positions[child.id];
      if (startPos == null || endPos == null) continue;

      final startSize = _nodeSizes[node.id] ?? const Size(100, 36);
      final endSize = _nodeSizes[child.id] ?? const Size(80, 36);

      // 计算连接点
      final dx = endPos.dx - startPos.dx;
      final dy = endPos.dy - startPos.dy;

      Offset startEdge;
      if (dx.abs() > dy.abs()) {
        startEdge = Offset(
          startPos.dx + (dx > 0 ? startSize.width / 2 : -startSize.width / 2),
          startPos.dy,
        );
      } else {
        startEdge = Offset(
          startPos.dx,
          startPos.dy + (dy > 0 ? startSize.height / 2 : -startSize.height / 2),
        );
      }

      final path = Path();
      path.moveTo(startEdge.dx, startEdge.dy);
      final midX = (startEdge.dx + endPos.dx) / 2;
      final midY = (startEdge.dy + endPos.dy) / 2;
      path.cubicTo(midX, startEdge.dy, midX, endPos.dy, endPos.dx, endPos.dy);
      canvas.drawPath(path, paint);

      _drawExportConnections(canvas, child, positions);
    }
  }

  void _drawExportNodes(
    Canvas canvas,
    MindMapNode node,
    Map<String, Offset> positions,
  ) {
    final pos = positions[node.id];
    if (pos == null) return;

    final size = _nodeSizes[node.id] ?? const Size(80, 36);
    final nodeColor = node.color != null
        ? parseColor(node.color!)
        : AppColors.primary;
    final isRoot = node.id == _root!.id;

    // 绘制圆角矩形
    final rect = Rect.fromCenter(center: pos, width: size.width, height: size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(isRoot ? 12.0 : 8.0));

    // 阴影
    canvas.drawShadow(rrect, Colors.black.withOpacity(0.1), 4, false);

    // 填充
    final fillPaint = Paint()..color = nodeColor.withOpacity(0.1);
    canvas.drawRRect(rrect, fillPaint);

    // 边框
    final borderPaint = Paint()
      ..color = nodeColor
      ..strokeWidth = isRoot ? 2.5 : 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(rrect, borderPaint);

    // 文字
    final textPainter = TextPainter(
      text: TextSpan(
        text: node.text,
        style: TextStyle(
          fontSize: isRoot ? 16 : 13,
          color: Colors.black87,
          fontWeight: isRoot ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.width - 16);

    textPainter.paint(
      canvas,
      Offset(
        pos.dx - textPainter.width / 2,
        pos.dy - textPainter.height / 2,
      ),
    );

    for (final child in node.children) {
      _drawExportNodes(canvas, child, positions);
    }
  }

  // ---- 删除整个思维导图 ----

  Future<void> _deleteMindMap() async {
    if (_dbId == null) return;
    final confirmed = await ConfirmDeleteDialog.show(
      context: context,
      title: '删除思维导图',
      message: '确定要删除此思维导图吗？此操作不可撤销。',
    );
    if (confirmed == true) {
      await _db.deleteMindMap(_dbId!);
      if (mounted) {
        Navigator.of(context).pop({'deleted': true});
      }
    }
  }

  // ---- 从知识点生成 ----

  Future<void> _generateFromKnowledgePoint() async {
    final kps = await _db.queryAllKnowledgePoints(limit: 50);
    if (kps.isEmpty) {
      showSnackBar(context, '暂无知识点数据', isError: true);
      return;
    }

    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择知识点生成思维导图'),
        children: kps.map((kp) {
          final title = kp['title'] as String? ?? '未命名';
          final subject = kp['subject'] as String? ?? '';
          return SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(kp),
            child: Row(
              children: [
                SubjectIcon(subjectName: subject, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );

    if (selected == null) return;

    final kpTitle = selected['title'] as String? ?? '知识点';
    final kpContent = selected['content'] as String? ?? '';
    final kpSubject = selected['subject'] as String? ?? '其他';
    final kpId = selected['id'] as int?;

    // 解析内容生成节点
    _pushUndo();
    final rootNode = MindMapNode(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: kpTitle,
      color: colorToHex(getSubjectColor(kpSubject)),
    );

    // 将内容按换行或分号分割为子节点
    final lines = kpContent
        .split(RegExp(r'[\n;；]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .take(8)
        .toList();

    final children = lines.map((line) {
      return MindMapNode(
        id: DateTime.now().millisecondsSinceEpoch.toString() + line.hashCode.toString(),
        text: line.length > 20 ? '${line.substring(0, 20)}...' : line,
        color: colorToHex(_colorOptions[lines.indexOf(line) % _colorOptions.length]),
      );
    }).toList();

    setState(() {
      _root = rootNode.copyWith(children: children);
      _titleController.text = kpTitle;
      _subject = kpSubject;
    });
    _recalculateLayout();
    _fitToScreen();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_hasChanges) {
          final save = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('未保存的更改'),
              content: const Text('你有未保存的更改，是否保存？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('不保存'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('保存'),
                ),
              ],
            ),
          );
          if (save == true) {
            await _save();
          }
          if (mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surfaceContainerLow,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: GestureDetector(
            onTap: () async {
              final newTitle = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('编辑标题'),
                  content: TextField(
                    controller: _titleController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: '输入标题',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(_titleController.text),
                      child: const Text('确定'),
                    ),
                  ],
                ),
              );
              if (newTitle != null) setState(() {});
            },
            child: Text(
              _titleController.text,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          actions: [
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _save,
                tooltip: '保存',
              ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'export':
                    _exportAsImage();
                    break;
                  case 'delete':
                    _deleteMindMap();
                    break;
                  case 'generate':
                    _generateFromKnowledgePoint();
                    break;
                  case 'subject':
                    _showSubjectPicker();
                    break;
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'subject',
                  child: ListTile(
                    leading: Icon(Icons.subject),
                    title: Text('选择学科'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'generate',
                  child: ListTile(
                    leading: Icon(Icons.auto_awesome),
                    title: Text('从知识点生成'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'export',
                  child: ListTile(
                    leading: Icon(Icons.image),
                    title: Text('导出图片'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (_dbId != null)
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline, color: AppColors.error),
                      title: Text('删除', style: TextStyle(color: AppColors.error)),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
          ],
        ),
        body: _root == null
            ? Center(
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
                      '点击下方按钮添加中心节点',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _generateFromKnowledgePoint,
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text('或从知识点自动生成'),
                    ),
                  ],
                ),
              )
            : GestureDetector(
                onScaleStart: (details) {
                  if (details.pointerCount == 1) {
                    final hitId = _hitTest(details.localFocalPoint);
                    if (hitId != null) {
                      _draggingNode = _findNodeById(_root, hitId);
                      _dragStart = details.localFocalPoint;
                      _dragNodeStart = _nodePositions[hitId] ?? Offset.zero;
                    }
                  }
                },
                onScaleUpdate: (details) {
                  if (details.pointerCount >= 2) {
                    // 缩放
                    setState(() {
                      _scale = (_scale * details.scale).clamp(0.3, 3.0);
                    });
                  } else if (_draggingNode != null) {
                    // 拖拽节点
                    final delta = details.localFocalPoint - _dragStart;
                    final newPos = _dragNodeStart + delta / _scale;
                    setState(() {
                      _nodePositions[_draggingNode!.id] = newPos;
                    });
                  } else {
                    // 平移画布
                    setState(() {
                      _offset += details.focalPointDelta;
                    });
                  }
                },
                onScaleEnd: (_) {
                  _draggingNode = null;
                },
                onTapDown: (details) {
                  // 用于双击检测
                },
                onDoubleTapDown: (details) {
                  final hitId = _hitTest(details.localPosition);
                  if (hitId != null) {
                    _editNodeText(hitId);
                  }
                },
                onLongPressStart: (details) {
                  final hitId = _hitTest(details.localPosition);
                  if (hitId != null) {
                    _showNodeMenu(hitId, details.globalPosition);
                  }
                },
                child: CustomPaint(
                  painter: _MindMapCanvasPainter(
                    root: _root!,
                    nodePositions: _nodePositions,
                    nodeSizes: _nodeSizes,
                    scale: _scale,
                    offset: _offset,
                    selectedNodeId: null,
                  ),
                  size: Size(screenSize.width, screenSize.height),
                ),
              ),
        bottomNavigationBar: _buildBottomToolbar(theme),
      ),
    );
  }

  Widget _buildBottomToolbar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // 添加根节点
            if (_root == null)
              IconButton(
                icon: const Icon(Icons.add_circle),
                onPressed: _addRootNode,
                tooltip: '添加中心节点',
                color: theme.colorScheme.primary,
              )
            else
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () {
                  if (_root != null) _addChildNode(_root!.id);
                },
                tooltip: '添加子节点到根',
              ),

            // 缩放控制
            IconButton(
              icon: const Icon(Icons.zoom_out),
              onPressed: _zoomOut,
              tooltip: '缩小',
            ),
            Text(
              '${(_scale * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.zoom_in),
              onPressed: _zoomIn,
              tooltip: '放大',
            ),

            // 适应屏幕
            IconButton(
              icon: const Icon(Icons.fit_screen),
              onPressed: _fitToScreen,
              tooltip: '适应屏幕',
            ),

            // 布局切换
            PopupMenuButton<_LayoutMode>(
              icon: const Icon(Icons.view_module),
              onSelected: (mode) {
                setState(() => _layoutMode = mode);
                _recalculateLayout();
                _fitToScreen();
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: _LayoutMode.horizontal,
                  child: Text('水平布局'),
                ),
                const PopupMenuItem(
                  value: _LayoutMode.vertical,
                  child: Text('垂直布局'),
                ),
                const PopupMenuItem(
                  value: _LayoutMode.radial,
                  child: Text('放射状布局'),
                ),
              ],
              tooltip: '布局方式',
            ),

            // 撤销
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed: _undoStack.isNotEmpty ? _undo : null,
              tooltip: '撤销',
            ),

            // 重做
            IconButton(
              icon: const Icon(Icons.redo),
              onPressed: _redoStack.isNotEmpty ? _redo : null,
              tooltip: '重做',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSubjectPicker() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择学科'),
        children: kSubjectNames.map((name) {
          return SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(name),
            child: Row(
              children: [
                SubjectIcon(subjectName: name, size: 28),
                const SizedBox(width: 12),
                Text(name),
                if (name == _subject)
                  const Spacer(),
                if (name == _subject)
                  const Icon(Icons.check, color: AppColors.primary),
              ],
            ),
          );
        }).toList(),
      ),
    );
    if (selected != null) {
      setState(() => _subject = selected);
    }
  }
}

// ============================================================
// _LayoutMode - 布局枚举
// ============================================================

enum _LayoutMode { horizontal, vertical, radial }

// ============================================================
// _MindMapCanvasPainter - 主画布绘制器
// ============================================================

class _MindMapCanvasPainter extends CustomPainter {
  final MindMapNode root;
  final Map<String, Offset> nodePositions;
  final Map<String, Size> nodeSizes;
  final double scale;
  final Offset offset;
  final String? selectedNodeId;

  _MindMapCanvasPainter({
    required this.root,
    required this.nodePositions,
    required this.nodeSizes,
    required this.scale,
    required this.offset,
    this.selectedNodeId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 绘制连线
    _drawConnections(canvas, root);
    // 绘制节点
    _drawNodes(canvas, root);
  }

  void _drawConnections(Canvas canvas, MindMapNode node) {
    final nodeColor = node.color != null
        ? parseColor(node.color!)
        : AppColors.primary;

    final paint = Paint()
      ..color = nodeColor.withOpacity(0.5)
      ..strokeWidth = 2.0 * scale
      ..style = PaintingStyle.stroke;

    for (final child in node.children) {
      final startPos = nodePositions[node.id];
      final endPos = nodePositions[child.id];
      if (startPos == null || endPos == null) continue;

      final startSize = nodeSizes[node.id] ?? const Size(100, 36);
      final endSize = nodeSizes[child.id] ?? const Size(80, 36);

      // 计算连接点（从边缘出发）
      final dx = (endPos.dx - startPos.dx);
      final dy = (endPos.dy - startPos.dy);

      Offset startEdge;
      if (dx.abs() > dy.abs()) {
        startEdge = Offset(
          startPos.dx + (dx > 0 ? startSize.width / 2 : -startSize.width / 2),
          startPos.dy,
        );
      } else {
        startEdge = Offset(
          startPos.dx,
          startPos.dy + (dy > 0 ? startSize.height / 2 : -startSize.height / 2),
        );
      }

      // 转换到屏幕坐标
      final screenStart = _toScreen(startEdge);
      final screenEnd = _toScreen(endPos);

      // 贝塞尔曲线
      final path = Path();
      path.moveTo(screenStart.dx, screenStart.dy);

      if (dx.abs() > dy.abs()) {
        // 水平连接
        final midX = (screenStart.dx + screenEnd.dx) / 2;
        path.cubicTo(midX, screenStart.dy, midX, screenEnd.dy, screenEnd.dx, screenEnd.dy);
      } else {
        // 垂直连接
        final midY = (screenStart.dy + screenEnd.dy) / 2;
        path.cubicTo(screenStart.dx, midY, screenEnd.dx, midY, screenEnd.dx, screenEnd.dy);
      }

      canvas.drawPath(path, paint);
      _drawConnections(canvas, child);
    }
  }

  void _drawNodes(Canvas canvas, MindMapNode node) {
    final pos = nodePositions[node.id];
    if (pos == null) return;

    final size = nodeSizes[node.id] ?? const Size(80, 36);
    final nodeColor = node.color != null
        ? parseColor(node.color!)
        : AppColors.primary;
    final isRoot = node.id == root.id;
    final isSelected = node.id == selectedNodeId;

    // 屏幕坐标和尺寸
    final screenPos = _toScreen(pos);
    final screenSize = Size(size.width * scale, size.height * scale);
    final rect = Rect.fromCenter(center: screenPos, width: screenSize.width, height: screenSize.height);
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular((isRoot ? 12.0 : 8.0) * scale),
    );

    // 阴影
    canvas.drawShadow(rrect, Colors.black.withOpacity(0.08), 4 * scale, false);

    // 填充
    final fillPaint = Paint()..color = nodeColor.withOpacity(0.08);
    canvas.drawRRect(rrect, fillPaint);

    // 选中高亮
    if (isSelected) {
      final highlightPaint = Paint()
        ..color = nodeColor.withOpacity(0.15);
      canvas.drawRRect(rrect, highlightPaint);
    }

    // 边框
    final borderPaint = Paint()
      ..color = nodeColor
      ..strokeWidth = (isRoot ? 2.5 : 1.5) * scale
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(rrect, borderPaint);

    // 文字
    final fontSize = (isRoot ? 16.0 : 13.0) * scale;
    final textPainter = TextPainter(
      text: TextSpan(
        text: node.text,
        style: TextStyle(
          fontSize: fontSize,
          color: Colors.black87,
          fontWeight: isRoot ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      textAlign: TextAlign.center,
    )..layout(maxWidth: screenSize.width - 16 * scale);

    textPainter.paint(
      canvas,
      Offset(
        screenPos.dx - textPainter.width / 2,
        screenPos.dy - textPainter.height / 2,
      ),
    );

    // 递归绘制子节点
    for (final child in node.children) {
      _drawNodes(canvas, child);
    }
  }

  Offset _toScreen(Offset logicalPos) {
    return Offset(
      logicalPos.dx * scale + offset.dx,
      logicalPos.dy * scale + offset.dy,
    );
  }

  @override
  bool shouldRepaint(covariant _MindMapCanvasPainter oldDelegate) {
    return oldDelegate.root != root ||
        oldDelegate.scale != scale ||
        oldDelegate.offset != offset ||
        oldDelegate.selectedNodeId != selectedNodeId ||
        !const DeepCollectionEquality()
            .equals(oldDelegate.nodePositions, nodePositions) ||
        !const DeepCollectionEquality()
            .equals(oldDelegate.nodeSizes, nodeSizes);
  }
}

// ============================================================
// ConfirmDeleteDialog - 删除确认对话框（从 common_widgets 引入的备用）
// ============================================================

/// 如果 common_widgets.dart 中已有此组件，可删除此处
class ConfirmDeleteDialog extends StatelessWidget {
  final String title;
  final String? message;
  final String confirmText;
  final String cancelText;
  final VoidCallback? onConfirm;

  const ConfirmDeleteDialog({
    super.key,
    this.title = '确认删除',
    this.message,
    this.confirmText = '删除',
    this.cancelText = '取消',
    this.onConfirm,
  });

  static Future<bool?> show({
    required BuildContext context,
    String title = '确认删除',
    String? message,
    String confirmText = '删除',
    String cancelText = '取消',
    VoidCallback? onConfirm,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConfirmDeleteDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 32),
      title: Text(title),
      content: Text(
        message ?? '此操作不可撤销，确定要删除吗？',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () {
            onConfirm?.call();
            Navigator.of(context).pop(true);
          },
          child: Text(confirmText),
        ),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
    );
  }
}
