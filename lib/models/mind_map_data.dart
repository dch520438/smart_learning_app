import 'dart:convert';
import 'package:uuid/uuid.dart';

/// 思维导图节点模型
class MindMapNode {
  final String id;
  final String text;
  final List<MindMapNode> children;
  final String? color;

  MindMapNode({
    required this.id,
    required this.text,
    List<MindMapNode>? children,
    this.color,
  }) : children = children ?? [];

  /// 从JSON创建
  factory MindMapNode.fromJson(Map<String, dynamic> json) {
    return MindMapNode(
      id: json['id'] as String,
      text: json['text'] as String,
      color: json['color'] as String?,
      children: (json['children'] as List<dynamic>?)
              ?.map((e) => MindMapNode.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'color': color,
      'children': children.map((e) => e.toJson()).toList(),
    };
  }

  /// 复制并修改部分字段
  MindMapNode copyWith({
    String? id,
    String? text,
    List<MindMapNode>? children,
    String? color,
  }) {
    return MindMapNode(
      id: id ?? this.id,
      text: text ?? this.text,
      children: children ?? this.children,
      color: color ?? this.color,
    );
  }

  @override
  String toString() {
    return 'MindMapNode(id: $id, text: $text, color: $color, '
        'childrenCount: ${children.length})';
  }
}

/// 思维导图数据模型
class MindMapData {
  final String id;
  final String title;
  final String subject;
  final MindMapNode? root; // 根节点
  final int createdAt; // 时间戳
  final int updatedAt; // 时间戳

  MindMapData({
    String? id,
    required this.title,
    required this.subject,
    this.root,
    int? createdAt,
    int? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  /// 从JSON创建
  factory MindMapData.fromJson(Map<String, dynamic> json) {
    MindMapNode? root;
    if (json['nodes'] != null) {
      root = MindMapNode.fromJson(Map<String, dynamic>.from(json['nodes'] as Map));
    }

    return MindMapData(
      id: json['id'] as String,
      title: json['title'] as String,
      subject: json['subject'] as String,
      root: root,
      createdAt: json['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: json['updatedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'nodes': root?.toJson(),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  /// 复制并修改部分字段
  MindMapData copyWith({
    String? id,
    String? title,
    String? subject,
    MindMapNode? root,
    int? createdAt,
    int? updatedAt,
  }) {
    return MindMapData(
      id: id ?? this.id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      root: root ?? this.root,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'MindMapData(id: $id, title: $title, subject: $subject, '
        'hasRoot: ${root != null})';
  }
}
