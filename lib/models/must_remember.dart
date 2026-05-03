import 'dart:convert';
import 'package:uuid/uuid.dart';

/// 必记必背模型
class MustRemember {
  final String id;
  final String title;
  final String content;
  final String subject;
  final String category; // 如公式/单词/概念等
  final int memoryLevel; // 记忆程度 0-100
  final int? nextReviewTime; // 时间戳
  final int reviewInterval; // 复习间隔（秒）
  final int reviewCount;
  final bool isMastered;
  final int createdAt; // 时间戳
  final int updatedAt; // 时间戳

  MustRemember({
    String? id,
    required this.title,
    required this.content,
    required this.subject,
    required this.category,
    this.memoryLevel = 0,
    this.nextReviewTime,
    this.reviewInterval = 0,
    this.reviewCount = 0,
    this.isMastered = false,
    int? createdAt,
    int? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  /// 从JSON创建
  factory MustRemember.fromJson(Map<String, dynamic> json) {
    return MustRemember(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      subject: json['subject'] as String,
      category: json['category'] as String,
      memoryLevel: json['memoryLevel'] as int? ?? 0,
      nextReviewTime: json['nextReviewTime'] as int?,
      reviewInterval: json['reviewInterval'] as int? ?? 0,
      reviewCount: json['reviewCount'] as int? ?? 0,
      isMastered: json['isMastered'] as bool? ?? false,
      createdAt: json['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: json['updatedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'subject': subject,
      'category': category,
      'memoryLevel': memoryLevel,
      'nextReviewTime': nextReviewTime,
      'reviewInterval': reviewInterval,
      'reviewCount': reviewCount,
      'isMastered': isMastered,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  /// 复制并修改部分字段
  MustRemember copyWith({
    String? id,
    String? title,
    String? content,
    String? subject,
    String? category,
    int? memoryLevel,
    int? nextReviewTime,
    int? reviewInterval,
    int? reviewCount,
    bool? isMastered,
    int? createdAt,
    int? updatedAt,
  }) {
    return MustRemember(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      subject: subject ?? this.subject,
      category: category ?? this.category,
      memoryLevel: memoryLevel ?? this.memoryLevel,
      nextReviewTime: nextReviewTime ?? this.nextReviewTime,
      reviewInterval: reviewInterval ?? this.reviewInterval,
      reviewCount: reviewCount ?? this.reviewCount,
      isMastered: isMastered ?? this.isMastered,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'MustRemember(id: $id, title: $title, subject: $subject, '
        'category: $category, memoryLevel: $memoryLevel, '
        'reviewCount: $reviewCount, isMastered: $isMastered)';
  }
}
