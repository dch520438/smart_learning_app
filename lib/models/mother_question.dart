import 'dart:convert';
import 'package:uuid/uuid.dart';

/// 母题模型
class MotherQuestion {
  final String id;
  final String title;
  final String content;
  final List<Map<String, dynamic>> options;
  final String correctAnswer;
  final String analysis;
  final String subject;
  final String? chapter;
  final int difficulty; // 1-5
  final List<String> relatedQuestions; // 关联题目ID列表
  final List<String> tags;
  final int createdAt; // 时间戳
  final int updatedAt; // 时间戳
  final List<Map<String, dynamic>> attachments;

  MotherQuestion({
    String? id,
    required this.title,
    required this.content,
    List<Map<String, dynamic>>? options,
    required this.correctAnswer,
    required this.analysis,
    required this.subject,
    this.chapter,
    this.difficulty = 1,
    List<String>? relatedQuestions,
    List<String>? tags,
    int? createdAt,
    int? updatedAt,
    List<Map<String, dynamic>>? attachments,
  })  : id = id ?? const Uuid().v4(),
        options = options ?? [],
        relatedQuestions = relatedQuestions ?? [],
        tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch,
        attachments = attachments ?? [];

  /// 从JSON创建
  factory MotherQuestion.fromJson(Map<String, dynamic> json) {
    return MotherQuestion(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      correctAnswer: json['correctAnswer'] as String,
      analysis: json['analysis'] as String? ?? '',
      subject: json['subject'] as String,
      chapter: json['chapter'] as String?,
      difficulty: json['difficulty'] as int? ?? 1,
      relatedQuestions: (json['relatedQuestions'] as List<dynamic>?)
              ?.cast<String>() ??
          [],
      tags: (json['tags'] as List<dynamic>).cast<String>(),
      createdAt: json['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: json['updatedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
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
      'options': options,
      'correctAnswer': correctAnswer,
      'analysis': analysis,
      'subject': subject,
      'chapter': chapter,
      'difficulty': difficulty,
      'relatedQuestions': relatedQuestions,
      'tags': tags,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'attachments': attachments,
    };
  }

  /// 复制并修改部分字段
  MotherQuestion copyWith({
    String? id,
    String? title,
    String? content,
    List<Map<String, dynamic>>? options,
    String? correctAnswer,
    String? analysis,
    String? subject,
    String? chapter,
    int? difficulty,
    List<String>? relatedQuestions,
    List<String>? tags,
    int? createdAt,
    int? updatedAt,
    List<Map<String, dynamic>>? attachments,
  }) {
    return MotherQuestion(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      options: options ?? this.options,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      analysis: analysis ?? this.analysis,
      subject: subject ?? this.subject,
      chapter: chapter ?? this.chapter,
      difficulty: difficulty ?? this.difficulty,
      relatedQuestions: relatedQuestions ?? this.relatedQuestions,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      attachments: attachments ?? this.attachments,
    );
  }

  @override
  String toString() {
    return 'MotherQuestion(id: $id, title: $title, subject: $subject, '
        'chapter: $chapter, difficulty: $difficulty, '
        'relatedQuestionsCount: ${relatedQuestions.length}, tags: $tags)';
  }
}
