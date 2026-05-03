import 'dart:convert';
import 'package:uuid/uuid.dart';

/// 考试结果模型
class ExamResult {
  final String id;
  final String examId;
  final int score;
  final int totalScore;
  final int correctCount;
  final int wrongCount;
  final List<Map<String, dynamic>> answers; // 答题记录JSON
  final int? startTime; // 时间戳
  final int? endTime; // 时间戳
  final int createdAt; // 时间戳

  ExamResult({
    String? id,
    required this.examId,
    required this.score,
    required this.totalScore,
    this.correctCount = 0,
    this.wrongCount = 0,
    List<Map<String, dynamic>>? answers,
    this.startTime,
    this.endTime,
    int? createdAt,
  })  : id = id ?? const Uuid().v4(),
        answers = answers ?? [],
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  /// 从JSON创建
  factory ExamResult.fromJson(Map<String, dynamic> json) {
    return ExamResult(
      id: json['id'] as String,
      examId: json['examId'] as String,
      score: json['score'] as int,
      totalScore: json['totalScore'] as int,
      correctCount: json['correctCount'] as int? ?? 0,
      wrongCount: json['wrongCount'] as int? ?? 0,
      answers: (json['answers'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      startTime: json['startTime'] as int?,
      endTime: json['endTime'] as int?,
      createdAt: json['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'examId': examId,
      'score': score,
      'totalScore': totalScore,
      'correctCount': correctCount,
      'wrongCount': wrongCount,
      'answers': answers,
      'startTime': startTime,
      'endTime': endTime,
      'createdAt': createdAt,
    };
  }

  /// 复制并修改部分字段
  ExamResult copyWith({
    String? id,
    String? examId,
    int? score,
    int? totalScore,
    int? correctCount,
    int? wrongCount,
    List<Map<String, dynamic>>? answers,
    int? startTime,
    int? endTime,
    int? createdAt,
  }) {
    return ExamResult(
      id: id ?? this.id,
      examId: examId ?? this.examId,
      score: score ?? this.score,
      totalScore: totalScore ?? this.totalScore,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      answers: answers ?? this.answers,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 计算正确率
  double get accuracy {
    final total = correctCount + wrongCount;
    if (total == 0) return 0.0;
    return correctCount / total;
  }

  @override
  String toString() {
    return 'ExamResult(id: $id, examId: $examId, score: $score/$totalScore, '
        'correctCount: $correctCount, wrongCount: $wrongCount, '
        'accuracy: ${(accuracy * 100).toStringAsFixed(1)}%)';
  }
}
