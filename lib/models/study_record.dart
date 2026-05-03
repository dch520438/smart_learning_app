import 'dart:convert';
import 'package:uuid/uuid.dart';

/// 学习记录模型
class StudyRecord {
  final String id;
  final String date; // 格式: yyyy-MM-dd
  final String subject;
  final int studyDuration; // 分钟
  final int knowledgePointsCount;
  final int questionsCount;
  final int notesCount;

  StudyRecord({
    String? id,
    required this.date,
    required this.subject,
    this.studyDuration = 0,
    this.knowledgePointsCount = 0,
    this.questionsCount = 0,
    this.notesCount = 0,
  }) : id = id ?? const Uuid().v4();

  /// 从JSON创建
  factory StudyRecord.fromJson(Map<String, dynamic> json) {
    return StudyRecord(
      id: json['id'] as String,
      date: json['date'] as String,
      subject: json['subject'] as String,
      studyDuration: json['studyDuration'] as int? ?? 0,
      knowledgePointsCount: json['knowledgePointsCount'] as int? ?? 0,
      questionsCount: json['questionsCount'] as int? ?? 0,
      notesCount: json['notesCount'] as int? ?? 0,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'subject': subject,
      'studyDuration': studyDuration,
      'knowledgePointsCount': knowledgePointsCount,
      'questionsCount': questionsCount,
      'notesCount': notesCount,
    };
  }

  /// 复制并修改部分字段
  StudyRecord copyWith({
    String? id,
    String? date,
    String? subject,
    int? studyDuration,
    int? knowledgePointsCount,
    int? questionsCount,
    int? notesCount,
  }) {
    return StudyRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      subject: subject ?? this.subject,
      studyDuration: studyDuration ?? this.studyDuration,
      knowledgePointsCount: knowledgePointsCount ?? this.knowledgePointsCount,
      questionsCount: questionsCount ?? this.questionsCount,
      notesCount: notesCount ?? this.notesCount,
    );
  }

  /// 格式化学习时长
  String get formattedDuration {
    final hours = studyDuration ~/ 60;
    final minutes = studyDuration % 60;
    if (hours > 0) {
      return '${hours}小时${minutes > 0 ? '$minutes分钟' : ''}';
    }
    return '$minutes分钟';
  }

  @override
  String toString() {
    return 'StudyRecord(id: $id, date: $date, subject: $subject, '
        'studyDuration: ${formattedDuration}, '
        'knowledgePointsCount: $knowledgePointsCount, '
        'questionsCount: $questionsCount, notesCount: $notesCount)';
  }
}
