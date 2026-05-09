import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';

/// ============================================================
/// MindMapData - 思维导图数据模型
/// ============================================================

/// 节点类型
enum NodeType {
  root,           // 根节点
  subject,        // 学科节点
  category,       // 分类节点
  knowledgePoint, // 知识点节点
  wrongQuestion,  // 错题节点
  note,           // 笔记节点
  mustRemember,   // 必记必背节点
  tag,            // 标签节点
  examMethod,     // 考法节点
  keyPoint,       // 考点节点
  custom,         // 自定义节点
}

/// 思维导图节点
class MindMapNode {
  final String id;
  String label;
  NodeType type;
  double x;
  double y;
  String? parentId;
  Map<String, dynamic>? data;
  Color? customColor;
  bool isExpanded;
  bool isSelected;

  MindMapNode({
    required this.id,
    required this.label,
    required this.type,
    required this.x,
    required this.y,
    this.parentId,
    this.data,
    this.customColor,
    this.isExpanded = true,
    this.isSelected = false,
  });

  /// 从JSON创建
  factory MindMapNode.fromJson(Map<String, dynamic> json) {
    return MindMapNode(
      id: json['id'] as String,
      label: json['label'] as String,
      type: NodeType.values.firstWhere(
        (e) => e.toString() == 'NodeType.${json['type']}',
        orElse: () => NodeType.custom,
      ),
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      parentId: json['parentId'] as String?,
      data: json['data'] != null
          ? Map<String, dynamic>.from(json['data'] as Map)
          : null,
      customColor: json['customColor'] != null
          ? Color(json['customColor'] as int)
          : null,
      isExpanded: json['isExpanded'] as bool? ?? true,
      isSelected: json['isSelected'] as bool? ?? false,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'type': type.toString().split('.').last,
      'x': x,
      'y': y,
      'parentId': parentId,
      'data': data,
      'customColor': customColor?.value,
      'isExpanded': isExpanded,
      'isSelected': isSelected,
    };
  }

  /// 复制并修改
  MindMapNode copyWith({
    String? id,
    String? label,
    NodeType? type,
    double? x,
    double? y,
    String? parentId,
    Map<String, dynamic>? data,
    Color? customColor,
    bool? isExpanded,
    bool? isSelected,
  }) {
    return MindMapNode(
      id: id ?? this.id,
      label: label ?? this.label,
      type: type ?? this.type,
      x: x ?? this.x,
      y: y ?? this.y,
      parentId: parentId ?? this.parentId,
      data: data ?? this.data,
      customColor: customColor ?? this.customColor,
      isExpanded: isExpanded ?? this.isExpanded,
      isSelected: isSelected ?? this.isSelected,
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
      case NodeType.category:
        return theme.colorScheme.tertiary;
      case NodeType.knowledgePoint:
        return const Color(0xFF4CAF50);
      case NodeType.wrongQuestion:
        return const Color(0xFFE53935);
      case NodeType.note:
        return const Color(0xFFFFA726);
      case NodeType.mustRemember:
        return const Color(0xFFAB47BC);
      case NodeType.tag:
        return const Color(0xFF42A5F5);
      case NodeType.examMethod:
        return const Color(0xFF26A69A);
      case NodeType.keyPoint:
        return const Color(0xFFFF7043);
      case NodeType.custom:
        return theme.colorScheme.outline;
    }
  }

  /// 获取节点大小
  double get size {
    switch (type) {
      case NodeType.root:
        return 60;
      case NodeType.subject:
      case NodeType.category:
        return 45;
      case NodeType.tag:
      case NodeType.examMethod:
      case NodeType.keyPoint:
        return 35;
      default:
        return 30;
    }
  }

  /// 获取节点图标
  IconData get icon {
    switch (type) {
      case NodeType.root:
        return Icons.account_tree;
      case NodeType.subject:
        return Icons.school;
      case NodeType.category:
        return Icons.folder;
      case NodeType.knowledgePoint:
        return Icons.lightbulb;
      case NodeType.wrongQuestion:
        return Icons.error_outline;
      case NodeType.note:
        return Icons.note;
      case NodeType.mustRemember:
        return Icons.memory;
      case NodeType.tag:
        return Icons.label;
      case NodeType.examMethod:
        return Icons.quiz;
      case NodeType.keyPoint:
        return Icons.star;
      case NodeType.custom:
        return Icons.circle;
    }
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
  List<MindMapNode> nodes;
  List<MindMapConnection> connections;
  int createdAt;
  int? updatedAt;
  double scale;
  Offset offset;

  MindMapData({
    String? id,
    required this.title,
    required this.nodes,
    required this.connections,
    required this.createdAt,
    this.updatedAt,
    this.scale = 1.0,
    this.offset = Offset.zero,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  /// 从JSON创建
  factory MindMapData.fromJson(Map<String, dynamic> json) {
    return MindMapData(
      id: json['id'] as String,
      title: json['title'] as String,
      nodes: (json['nodes'] as List<dynamic>)
          .map((e) => MindMapNode.fromJson(e as Map<String, dynamic>))
          .toList(),
      connections: (json['connections'] as List<dynamic>)
          .map((e) => MindMapConnection.fromJson(e as Map<String, dynamic>))
          .toList(),
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
      'nodes': nodes.map((n) => n.toJson()).toList(),
      'connections': connections.map((c) => c.toJson()).toList(),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'scale': scale,
      'offset': {'dx': offset.dx, 'dy': offset.dy},
    };
  }

  /// 获取根节点
  MindMapNode? get rootNode {
    try {
      return nodes.firstWhere((n) => n.type == NodeType.root);
    } catch (_) {
      return null;
    }
  }

  /// 获取节点的子节点
  List<MindMapNode> getChildren(String parentId) {
    return nodes.where((n) => n.parentId == parentId).toList();
  }

  /// 获取节点的连接
  List<MindMapConnection> getNodeConnections(String nodeId) {
    return connections.where(
      (c) => c.sourceId == nodeId || c.targetId == nodeId,
    ).toList();
  }

  /// 获取连接的源节点
  MindMapNode? getSourceNode(MindMapConnection connection) {
    try {
      return nodes.firstWhere((n) => n.id == connection.sourceId);
    } catch (_) {
      return null;
    }
  }

  /// 获取连接的目标节点
  MindMapNode? getTargetNode(MindMapConnection connection) {
    try {
      return nodes.firstWhere((n) => n.id == connection.targetId);
    } catch (_) {
      return null;
    }
  }

  /// 根据ID获取节点
  MindMapNode? getNodeById(String id) {
    try {
      return nodes.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 添加节点
  void addNode(MindMapNode node) {
    nodes.add(node);
    updatedAt = DateTime.now().millisecondsSinceEpoch;
  }

  /// 删除节点
  void removeNode(String nodeId) {
    nodes.removeWhere((n) => n.id == nodeId);
    // 同时删除相关连接
    connections.removeWhere(
      (c) => c.sourceId == nodeId || c.targetId == nodeId,
    );
    updatedAt = DateTime.now().millisecondsSinceEpoch;
  }

  /// 更新节点位置
  void updateNodePosition(String nodeId, double x, double y) {
    final node = getNodeById(nodeId);
    if (node != null) {
      node.x = x;
      node.y = y;
      updatedAt = DateTime.now().millisecondsSinceEpoch;
    }
  }

  /// 获取边界框
  Rect getBounds() {
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
