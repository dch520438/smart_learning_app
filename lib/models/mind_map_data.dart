import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// ============================================================
/// MindMapData - 思维导图数据模型 (重构版)
/// ============================================================

/// 节点类型
enum NodeType {
  root,           // 根节点
  subject,        // 学科节点
  chapter,        // 章节节点
  knowledgePoint, // 知识点节点
  wrongQuestion,  // 错题节点
  note,           // 笔记节点
  mustRemember,   // 必记必背节点
  keyPoint,       // 考点节点
  custom,         // 自定义节点
}

/// 思维导图节点 (重构版)
/// 支持树形结构和手动编辑
class MindMapNode {
  String id;
  String title;           // 节点标题
  String content;         // 简介内容
  NodeType type;          // 节点类型
  String subject;         // 所属学科
  String? chapter;        // 所属章节
  String? sourceId;       // 关联的原始内容ID
  List<MindMapNode> children; // 子节点列表
  double x;               // 位置坐标 X
  double y;               // 位置坐标 Y
  String? parentId;       // 父节点ID
  Map<String, dynamic>? data; // 原始数据
  Color? customColor;     // 自定义颜色
  bool isExpanded;        // 是否展开
  bool isSelected;        // 是否选中
  int createdAt;          // 创建时间
  int? updatedAt;         // 更新时间

  MindMapNode({
    String? id,
    required this.title,
    this.content = '',
    required this.type,
    required this.subject,
    this.chapter,
    this.sourceId,
    List<MindMapNode>? children,
    required this.x,
    required this.y,
    this.parentId,
    this.data,
    this.customColor,
    this.isExpanded = true,
    this.isSelected = false,
    int? createdAt,
    this.updatedAt,
  })  : id = id ?? const Uuid().v4(),
        children = children ?? [],
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  /// 从JSON创建
  factory MindMapNode.fromJson(Map<String, dynamic> json) {
    return MindMapNode(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String? ?? '',
      type: NodeType.values.firstWhere(
        (e) => e.toString() == 'NodeType.${json['type']}',
        orElse: () => NodeType.custom,
      ),
      subject: json['subject'] as String? ?? '其他',
      chapter: json['chapter'] as String?,
      sourceId: json['sourceId'] as String?,
      children: (json['children'] as List<dynamic>?)
              ?.map((e) => MindMapNode.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      parentId: json['parentId'] as String?,
      data: json['data'] != null
          ? Map<String, dynamic>.from(json['data'] as Map)
          : null,
      customColor: json['customColor'] != null
          ? Color(json['customColor'] as int)
          : null,
      isExpanded: json['isExpanded'] as bool? ?? true,
      isSelected: json['isSelected'] as bool? ?? false,
      createdAt: json['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: json['updatedAt'] as int?,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'type': type.toString().split('.').last,
      'subject': subject,
      'chapter': chapter,
      'sourceId': sourceId,
      'children': children.map((c) => c.toJson()).toList(),
      'x': x,
      'y': y,
      'parentId': parentId,
      'data': data,
      'customColor': customColor?.value,
      'isExpanded': isExpanded,
      'isSelected': isSelected,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  /// 复制并修改
  MindMapNode copyWith({
    String? id,
    String? title,
    String? content,
    NodeType? type,
    String? subject,
    String? chapter,
    String? sourceId,
    List<MindMapNode>? children,
    double? x,
    double? y,
    String? parentId,
    Map<String, dynamic>? data,
    Color? customColor,
    bool? isExpanded,
    bool? isSelected,
    int? createdAt,
    int? updatedAt,
  }) {
    return MindMapNode(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      subject: subject ?? this.subject,
      chapter: chapter ?? this.chapter,
      sourceId: sourceId ?? this.sourceId,
      children: children ?? List.from(this.children),
      x: x ?? this.x,
      y: y ?? this.y,
      parentId: parentId ?? this.parentId,
      data: data ?? this.data,
      customColor: customColor ?? this.customColor,
      isExpanded: isExpanded ?? this.isExpanded,
      isSelected: isSelected ?? this.isSelected,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 获取节点颜色
  Color getColor(BuildContext context) {
    if (customColor != null) return customColor!;

    final theme = Theme.of(context);
    switch (type) {
      case NodeType.root:
        return theme.colorScheme.primary;
      case NodeType.subject:
        return theme.colorScheme.secondary;
      case NodeType.chapter:
        return const Color(0xFF00BCD4); // Cyan
      case NodeType.knowledgePoint:
        return const Color(0xFF4CAF50); // Green
      case NodeType.wrongQuestion:
        return const Color(0xFFE53935); // Red
      case NodeType.note:
        return const Color(0xFFFFA726); // Orange
      case NodeType.mustRemember:
        return const Color(0xFFAB47BC); // Purple
      case NodeType.keyPoint:
        return const Color(0xFFFF7043); // Deep Orange
      case NodeType.custom:
        return theme.colorScheme.outline;
    }
  }

  /// 获取节点大小
  double get size {
    switch (type) {
      case NodeType.root:
        return 70;
      case NodeType.subject:
        return 55;
      case NodeType.chapter:
        return 45;
      case NodeType.keyPoint:
        return 40;
      default:
        return 35;
    }
  }

  /// 获取节点图标
  IconData get icon {
    switch (type) {
      case NodeType.root:
        return Icons.account_tree;
      case NodeType.subject:
        return Icons.school;
      case NodeType.chapter:
        return Icons.menu_book;
      case NodeType.knowledgePoint:
        return Icons.lightbulb;
      case NodeType.wrongQuestion:
        return Icons.error_outline;
      case NodeType.note:
        return Icons.note;
      case NodeType.mustRemember:
        return Icons.memory;
      case NodeType.keyPoint:
        return Icons.star;
      case NodeType.custom:
        return Icons.circle;
    }
  }

  /// 获取类型显示名称
  String get typeName {
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

  /// 添加子节点
  void addChild(MindMapNode child) {
    child.parentId = id;
    children.add(child);
  }

  /// 移除子节点
  void removeChild(String childId) {
    children.removeWhere((c) => c.id == childId);
  }

  /// 查找节点（递归）
  MindMapNode? findNode(String nodeId) {
    if (id == nodeId) return this;
    for (final child in children) {
      final found = child.findNode(nodeId);
      if (found != null) return found;
    }
    return null;
  }

  /// 获取所有节点（扁平化）
  List<MindMapNode> getAllNodes() {
    final result = [this];
    for (final child in children) {
      result.addAll(child.getAllNodes());
    }
    return result;
  }

  /// 更新位置
  void updatePosition(double newX, double newY) {
    x = newX;
    y = newY;
  }
}

/// 思维导图连接
class MindMapConnection {
  String sourceId;
  String targetId;
  String? relation;
  double strength; // 关联强度 0.0 - 1.0
  bool isManual;   // 是否手动添加

  MindMapConnection({
    required this.sourceId,
    required this.targetId,
    this.relation,
    this.strength = 0.5,
    this.isManual = false,
  });

  /// 从JSON创建
  factory MindMapConnection.fromJson(Map<String, dynamic> json) {
    return MindMapConnection(
      sourceId: json['sourceId'] as String,
      targetId: json['targetId'] as String,
      relation: json['relation'] as String?,
      strength: (json['strength'] as num?)?.toDouble() ?? 0.5,
      isManual: json['isManual'] as bool? ?? false,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'sourceId': sourceId,
      'targetId': targetId,
      'relation': relation,
      'strength': strength,
      'isManual': isManual,
    };
  }

  /// 获取连接线颜色
  Color getColor(BuildContext context) {
    if (isManual) return Colors.orange;

    // 根据关联强度返回不同颜色
    if (strength >= 0.8) return Colors.green;
    if (strength >= 0.5) return Colors.blue;
    if (strength >= 0.3) return Colors.grey;
    return Colors.grey.shade300;
  }

  /// 获取线宽
  double get strokeWidth {
    return 1 + strength * 3;
  }
}

/// 思维导图数据
class MindMapData {
  String id;
  String title;
  MindMapNode rootNode; // 根节点（包含树形结构）
  List<MindMapConnection> connections;
  int createdAt;
  int? updatedAt;
  double scale;
  Offset offset;

  MindMapData({
    String? id,
    required this.title,
    required this.rootNode,
    List<MindMapConnection>? connections,
    required this.createdAt,
    this.updatedAt,
    this.scale = 1.0,
    this.offset = Offset.zero,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        connections = connections ?? [];

  /// 从JSON创建
  factory MindMapData.fromJson(Map<String, dynamic> json) {
    return MindMapData(
      id: json['id'] as String,
      title: json['title'] as String,
      rootNode: MindMapNode.fromJson(json['rootNode'] as Map<String, dynamic>),
      connections: (json['connections'] as List<dynamic>?)
              ?.map((e) => MindMapConnection.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] as int,
      updatedAt: json['updatedAt'] as int?,
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      offset: json['offset'] != null
          ? Offset(
              (json['offset']['dx'] as num).toDouble(),
              (json['offset']['dy'] as num).toDouble(),
            )
          : Offset.zero,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'rootNode': rootNode.toJson(),
      'connections': connections.map((c) => c.toJson()).toList(),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'scale': scale,
      'offset': {'dx': offset.dx, 'dy': offset.dy},
    };
  }

  /// 获取所有节点（扁平化列表）
  List<MindMapNode> get allNodes => rootNode.getAllNodes();

  /// 根据ID查找节点
  MindMapNode? findNodeById(String nodeId) {
    return rootNode.findNode(nodeId);
  }

  /// 添加节点
  void addNode(String parentId, MindMapNode node) {
    final parent = findNodeById(parentId);
    if (parent != null) {
      parent.addChild(node);
      updatedAt = DateTime.now().millisecondsSinceEpoch;
    }
  }

  /// 删除节点
  void removeNode(String nodeId) {
    if (nodeId == rootNode.id) return; // 不能删除根节点

    // 从根节点递归删除
    _removeNodeRecursive(rootNode, nodeId);

    // 删除相关连接
    connections.removeWhere(
      (c) => c.sourceId == nodeId || c.targetId == nodeId,
    );

    updatedAt = DateTime.now().millisecondsSinceEpoch;
  }

  /// 递归删除节点
  bool _removeNodeRecursive(MindMapNode parent, String nodeId) {
    for (int i = 0; i < parent.children.length; i++) {
      if (parent.children[i].id == nodeId) {
        parent.children.removeAt(i);
        return true;
      }
      if (_removeNodeRecursive(parent.children[i], nodeId)) {
        return true;
      }
    }
    return false;
  }

  /// 更新节点
  void updateNode(String nodeId, MindMapNode updatedNode) {
    final node = findNodeById(nodeId);
    if (node != null) {
      node.title = updatedNode.title;
      node.content = updatedNode.content;
      node.type = updatedNode.type;
      node.subject = updatedNode.subject;
      node.chapter = updatedNode.chapter;
      node.sourceId = updatedNode.sourceId;
      node.customColor = updatedNode.customColor;
      node.updatedAt = DateTime.now().millisecondsSinceEpoch;
    }
  }

  /// 更新节点位置
  void updateNodePosition(String nodeId, double x, double y) {
    final node = findNodeById(nodeId);
    if (node != null) {
      node.updatePosition(x, y);
      updatedAt = DateTime.now().millisecondsSinceEpoch;
    }
  }

  /// 添加连接
  void addConnection(MindMapConnection connection) {
    connections.add(connection);
    updatedAt = DateTime.now().millisecondsSinceEpoch;
  }

  /// 删除连接
  void removeConnection(String sourceId, String targetId) {
    connections.removeWhere(
      (c) =>
          (c.sourceId == sourceId && c.targetId == targetId) ||
          (c.sourceId == targetId && c.targetId == sourceId),
    );
    updatedAt = DateTime.now().millisecondsSinceEpoch;
  }

  /// 获取边界框
  Rect getBounds() {
    final nodes = allNodes;
    if (nodes.isEmpty) return Rect.zero;

    double minX = nodes.first.x;
    double maxX = nodes.first.x;
    double minY = nodes.first.y;
    double maxY = nodes.first.y;

    for (final node in nodes) {
      if (node.x < minX) minX = node.x;
      if (node.x > maxX) maxX = node.x;
      if (node.y < minY) minY = node.y;
      if (node.y > maxY) maxY = node.y;
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// 获取中心点
  Offset getCenter() {
    final bounds = getBounds();
    return Offset(
      (bounds.left + bounds.right) / 2,
      (bounds.top + bounds.bottom) / 2,
    );
  }

  /// 导出为JSON字符串
  String exportToJson() {
    return jsonEncode(toJson());
  }

  /// 从JSON字符串导入
  static MindMapData importFromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return MindMapData.fromJson(json);
  }
}

/// 思维导图视图状态
class MindMapViewState {
  double scale;
  Offset offset;
  String? selectedNodeId;
  String? hoveredNodeId;
  bool showConnections;
  bool showLabels;
  bool autoLayout;

  MindMapViewState({
    this.scale = 1.0,
    this.offset = Offset.zero,
    this.selectedNodeId,
    this.hoveredNodeId,
    this.showConnections = true,
    this.showLabels = true,
    this.autoLayout = false,
  });

  /// 复制
  MindMapViewState copy() {
    return MindMapViewState(
      scale: scale,
      offset: offset,
      selectedNodeId: selectedNodeId,
      hoveredNodeId: hoveredNodeId,
      showConnections: showConnections,
      showLabels: showLabels,
      autoLayout: autoLayout,
    );
  }
}
