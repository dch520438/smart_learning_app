import 'dart:convert';
import 'package:uuid/uuid.dart';

/// 考试/测试模型
class Exam {
  final String id;
  final String title;
  final String subject;
  final List<String> questions; // 题目ID列表
  final int totalScore;
  final int duration; // 分钟
  final int createdAt; // 时间戳

  Exam({
    String? id,
    required this.title,
    required this.subject,
    List<String>? questions,
    this.totalScore = 100,
    this.duration = 60,
    int? createdAt,
  })  : id = id ?? const Uuid().v4(),
        questions = questions ?? [],
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  /// 从JSON创建
  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
      id: json['id'] as String,
      title: json['title'] as String,
      subject: json['subject'] as String,
      questions: (json['questions'] as List<dynamic>).cast<String>(),
      totalScore: json['totalScore'] as int? ?? 100,
      duration: json['duration'] as int? ?? 60,
      createdAt: json['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'questions': questions,
      'totalScore': totalScore,
      'duration': duration,
      'createdAt': createdAt,
    };
  }

  /// 复制并修改部分字段
  Exam copyWith({
    String? id,
    String? title,
    String? subject,
    List<String>? questions,
    int? totalScore,
    int? duration,
    int? createdAt,
  }) {
    return Exam(
      id: id ?? this.id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      questions: questions ?? this.questions,
      totalScore: totalScore ?? this.totalScore,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Exam(id: $id, title: $title, subject: $subject, '
        'totalScore: $totalScore, duration: ${duration}min, '
        'questionsCount: ${questions.length})';
  }
}
