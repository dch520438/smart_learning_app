import 'dart:convert';
import 'package:uuid/uuid.dart';

/// 知识点模型
class KnowledgePoint {
  final String id;
  final String title;
  final String content;
  final String subject;
  final String? chapter;
  final List<String> tags;
  final String? categoryId;
  final int difficulty; // 1-5
  final int masteryLevel; // 0-100
  final int reviewCount;
  final int? lastReviewTime; // 时间戳
  final bool isFavorite;
  final int createdAt; // 时间戳
  final int updatedAt; // 时间戳
  final List<Map<String, dynamic>> attachments; // 附件列表
  final List<String> examMethods; // 考法列表
  final List<String> keyPoints; // 考点列表

  KnowledgePoint({
    String? id,
    required this.title,
    required this.content,
    required this.subject,
    this.chapter,
    List<String>? tags,
    this.categoryId,
    this.difficulty = 1,
    this.masteryLevel = 0,
    this.reviewCount = 0,
    this.lastReviewTime,
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
  factory KnowledgePoint.fromJson(Map<String, dynamic> json) {
    return KnowledgePoint(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      subject: json['subject'] as String,
      chapter: json['chapter'] as String?,
      tags: (json['tags'] as List<dynamic>).cast<String>(),
      categoryId: json['categoryId'] as String?,
      difficulty: json['difficulty'] as int? ?? 1,
      masteryLevel: json['masteryLevel'] as int? ?? 0,
      reviewCount: json['reviewCount'] as int? ?? 0,
      lastReviewTime: json['lastReviewTime'] as int?,
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
      'chapter': chapter,
      'tags': tags,
      'categoryId': categoryId,
      'difficulty': difficulty,
      'masteryLevel': masteryLevel,
      'reviewCount': reviewCount,
      'lastReviewTime': lastReviewTime,
      'isFavorite': isFavorite,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'attachments': attachments,
      'examMethods': examMethods,
      'keyPoints': keyPoints,
    };
  }

  /// 复制并修改部分字段
  KnowledgePoint copyWith({
    String? id,
    String? title,
    String? content,
    String? subject,
    String? chapter,
    List<String>? tags,
    String? categoryId,
    int? difficulty,
    int? masteryLevel,
    int? reviewCount,
    int? lastReviewTime,
    bool? isFavorite,
    int? createdAt,
    int? updatedAt,
    List<Map<String, dynamic>>? attachments,
    List<String>? examMethods,
    List<String>? keyPoints,
  }) {
    return KnowledgePoint(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      subject: subject ?? this.subject,
      chapter: chapter ?? this.chapter,
      tags: tags ?? this.tags,
      categoryId: categoryId ?? this.categoryId,
      difficulty: difficulty ?? this.difficulty,
      masteryLevel: masteryLevel ?? this.masteryLevel,
      reviewCount: reviewCount ?? this.reviewCount,
      lastReviewTime: lastReviewTime ?? this.lastReviewTime,
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
    return 'KnowledgePoint(id: $id, title: $title, subject: $subject, '
        'chapter: $chapter, difficulty: $difficulty, masteryLevel: $masteryLevel, '
        'reviewCount: $reviewCount, isFavorite: $isFavorite, '
        'tags: $tags, categoryId: $categoryId, '
        'examMethods: $examMethods, keyPoints: $keyPoints)';
  }
}
