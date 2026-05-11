import 'dart:convert';
import 'package:uuid/uuid.dart';

/// 必记必背模型
class MustRemember {
  final String id;
  final String title;
  final String content;
  final String subject;
  final String? chapter;
  final String category; // 如公式/单词/概念等
  final int memoryLevel; // 记忆程度 0-100
  final int? nextReviewTime; // 时间戳
  final int reviewInterval; // 复习间隔（秒）
  final int reviewCount;
  final bool isMastered;
  final int createdAt; // 时间戳
  final int updatedAt; // 时间戳
  final List<String> examMethods; // 考法列表
  final List<String> keyPoints; // 考点列表

  MustRemember({
    String? id,
    required this.title,
    required this.content,
    required this.subject,
    this.chapter,
    required this.category,
    this.memoryLevel = 0,
    this.nextReviewTime,
    this.reviewInterval = 0,
    this.reviewCount = 0,
    this.isMastered = false,
    int? createdAt,
    int? updatedAt,
    List<String>? examMethods,
    List<String>? keyPoints,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch,
        examMethods = examMethods ?? [],
        keyPoints = keyPoints ?? [];

  /// 从JSON创建
  factory MustRemember.fromJson(Map<String, dynamic> json) {
    return MustRemember(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      subject: json['subject'] as String,
      chapter: json['chapter'] as String?,
      category: json['category'] as String,
      memoryLevel: json['memoryLevel'] as int? ?? 0,
      nextReviewTime: json['nextReviewTime'] as int?,
      reviewInterval: json['reviewInterval'] as int? ?? 0,
      reviewCount: json['reviewCount'] as int? ?? 0,
      isMastered: json['isMastered'] as bool? ?? false,
      createdAt: json['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: json['updatedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
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
      'category': category,
      'memoryLevel': memoryLevel,
      'nextReviewTime': nextReviewTime,
      'reviewInterval': reviewInterval,
      'reviewCount': reviewCount,
      'isMastered': isMastered,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'examMethods': examMethods,
      'keyPoints': keyPoints,
    };
  }

  /// 复制并修改部分字段
  MustRemember copyWith({
    String? id,
    String? title,
    String? content,
    String? subject,
    String? chapter,
    String? category,
    int? memoryLevel,
    int? nextReviewTime,
    int? reviewInterval,
    int? reviewCount,
    bool? isMastered,
    int? createdAt,
    int? updatedAt,
    List<String>? examMethods,
    List<String>? keyPoints,
  }) {
    return MustRemember(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      subject: subject ?? this.subject,
      chapter: chapter ?? this.chapter,
      category: category ?? this.category,
      memoryLevel: memoryLevel ?? this.memoryLevel,
      nextReviewTime: nextReviewTime ?? this.nextReviewTime,
      reviewInterval: reviewInterval ?? this.reviewInterval,
      reviewCount: reviewCount ?? this.reviewCount,
      isMastered: isMastered ?? this.isMastered,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      examMethods: examMethods ?? this.examMethods,
      keyPoints: keyPoints ?? this.keyPoints,
    );
  }

  @override
  String toString() {
    return 'MustRemember(id: $id, title: $title, subject: $subject, '
        'chapter: $chapter, category: $category, memoryLevel: $memoryLevel, '
        'reviewCount: $reviewCount, isMastered: $isMastered, '
        'examMethods: $examMethods, keyPoints: $keyPoints)';
  }
}
