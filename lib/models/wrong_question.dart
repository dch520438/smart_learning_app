import 'dart:convert';
import 'package:uuid/uuid.dart';

/// 错题模型
class WrongQuestion {
  final String id;
  final String title;
  final String content; // 题目内容
  final List<Map<String, dynamic>> options; // 选项JSON
  final String correctAnswer;
  final String? userAnswer;
  final String analysis; // 解析
  final String subject;
  final String? chapter;
  final String errorType; // 粗心/知识盲区/方法错误
  final int errorCount;
  final bool isResolved;
  final int createdAt; // 时间戳
  final int updatedAt; // 时间戳
  final List<Map<String, dynamic>> attachments;
  final List<String> examMethods; // 考法列表
  final List<String> keyPoints; // 考点列表

  WrongQuestion({
    String? id,
    required this.title,
    required this.content,
    List<Map<String, dynamic>>? options,
    required this.correctAnswer,
    this.userAnswer,
    required this.analysis,
    required this.subject,
    this.chapter,
    this.errorType = '知识盲区',
    this.errorCount = 1,
    this.isResolved = false,
    int? createdAt,
    int? updatedAt,
    List<Map<String, dynamic>>? attachments,
    List<String>? examMethods,
    List<String>? keyPoints,
  })  : id = id ?? const Uuid().v4(),
        options = options ?? [],
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch,
        attachments = attachments ?? [],
        examMethods = examMethods ?? [],
        keyPoints = keyPoints ?? [];

  /// 从JSON创建
  factory WrongQuestion.fromJson(Map<String, dynamic> json) {
    return WrongQuestion(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      correctAnswer: json['correctAnswer'] as String,
      userAnswer: json['userAnswer'] as String?,
      analysis: json['analysis'] as String? ?? '',
      subject: json['subject'] as String,
      chapter: json['chapter'] as String?,
      errorType: json['errorType'] as String? ?? '知识盲区',
      errorCount: json['errorCount'] as int? ?? 1,
      isResolved: json['isResolved'] as bool? ?? false,
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
      'options': options,
      'correctAnswer': correctAnswer,
      'userAnswer': userAnswer,
      'analysis': analysis,
      'subject': subject,
      'chapter': chapter,
      'errorType': errorType,
      'errorCount': errorCount,
      'isResolved': isResolved,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'attachments': attachments,
      'examMethods': examMethods,
      'keyPoints': keyPoints,
    };
  }

  /// 复制并修改部分字段
  WrongQuestion copyWith({
    String? id,
    String? title,
    String? content,
    List<Map<String, dynamic>>? options,
    String? correctAnswer,
    String? userAnswer,
    String? analysis,
    String? subject,
    String? chapter,
    String? errorType,
    int? errorCount,
    bool? isResolved,
    int? createdAt,
    int? updatedAt,
    List<Map<String, dynamic>>? attachments,
    List<String>? examMethods,
    List<String>? keyPoints,
  }) {
    return WrongQuestion(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      options: options ?? this.options,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      userAnswer: userAnswer ?? this.userAnswer,
      analysis: analysis ?? this.analysis,
      subject: subject ?? this.subject,
      chapter: chapter ?? this.chapter,
      errorType: errorType ?? this.errorType,
      errorCount: errorCount ?? this.errorCount,
      isResolved: isResolved ?? this.isResolved,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      attachments: attachments ?? this.attachments,
      examMethods: examMethods ?? this.examMethods,
      keyPoints: keyPoints ?? this.keyPoints,
    );
  }

  @override
  String toString() {
    return 'WrongQuestion(id: $id, title: $title, subject: $subject, '
        'chapter: $chapter, errorType: $errorType, errorCount: $errorCount, '
        'isResolved: $isResolved, examMethods: $examMethods, keyPoints: $keyPoints)';
  }
}
