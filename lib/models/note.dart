import 'dart:convert';
import 'package:uuid/uuid.dart';

/// 学习笔记模型
class Note {
  final String id;
  final String title;
  final String content; // markdown格式
  final String subject;
  final List<String> tags;
  final String color; // 笔记颜色
  final bool isPinned; // 是否置顶
  final bool isFavorite;
  final int createdAt; // 时间戳
  final int updatedAt; // 时间戳
  final List<Map<String, dynamic>> attachments;
  final List<String> examMethods; // 考法列表
  final List<String> keyPoints; // 考点列表

  Note({
    String? id,
    required this.title,
    required this.content,
    required this.subject,
    List<String>? tags,
    this.color = '#FFFFFF',
    this.isPinned = false,
    this.isFavorite = false,
    int? createdAt,
    int? updatedAt,
    List<Map<String, dynamic>>? attachments,
    List<String>? examMethods,
    List<String>? keyPoints,
  })  : id = id ?? const Uuid().v4(),
        tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch,
        attachments = attachments ?? [],
        examMethods = examMethods ?? [],
        keyPoints = keyPoints ?? [];

  /// 从JSON创建
  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      subject: json['subject'] as String,
      tags: (json['tags'] as List<dynamic>).cast<String>(),
      color: json['color'] as String? ?? '#FFFFFF',
      isPinned: json['isPinned'] as bool? ?? false,
      isFavorite: json['isFavorite'] as bool? ?? false,
      createdAt: json['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: json['updatedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      examMethods: (json['examMethods'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      keyPoints: (json['keyPoints'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'subject': subject,
      'tags': tags,
      'color': color,
      'isPinned': isPinned,
      'isFavorite': isFavorite,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'attachments': attachments,
      'examMethods': examMethods,
      'keyPoints': keyPoints,
    };
  }

  /// 复制并修改部分字段
  Note copyWith({
    String? id,
    String? title,
    String? content,
    String? subject,
    List<String>? tags,
    String? color,
    bool? isPinned,
    bool? isFavorite,
    int? createdAt,
    int? updatedAt,
    List<Map<String, dynamic>>? attachments,
    List<String>? examMethods,
    List<String>? keyPoints,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      subject: subject ?? this.subject,
      tags: tags ?? this.tags,
      color: color ?? this.color,
      isPinned: isPinned ?? this.isPinned,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      attachments: attachments ?? this.attachments,
      examMethods: examMethods ?? this.examMethods,
      keyPoints: keyPoints ?? this.keyPoints,
    );
  }

  @override
  String toString() {
    return 'Note(id: $id, title: $title, subject: $subject, '
        'color: $color, isPinned: $isPinned, isFavorite: $isFavorite, '
        'tags: $tags, examMethods: $examMethods, keyPoints: $keyPoints)';
  }
}
