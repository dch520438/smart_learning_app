import 'dart:convert';
import 'package:uuid/uuid.dart';

/// 试卷来源类型
enum ExamPaperSource {
  mock('模拟', 'mock'),
  school('学校', 'school'),
  offline('线下', 'offline');

  const ExamPaperSource(this.label, this.value);
  final String label;
  final String value;

  static ExamPaperSource fromValue(String value) {
    return ExamPaperSource.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ExamPaperSource.mock,
    );
  }
}

/// 试卷中的题目模型
class ExamPaperQuestion {
  final String id;
  final String content;
  final String? userAnswer;
  final String? correctAnswer;
  final int? score;
  final int? fullScore;
  final String? analysis;
  final List<String>? options;
  final String? questionType;

  ExamPaperQuestion({
    String? id,
    required this.content,
    this.userAnswer,
    this.correctAnswer,
    this.score,
    this.fullScore,
    this.analysis,
    this.options,
    this.questionType,
  }) : id = id ?? const Uuid().v4();

  factory ExamPaperQuestion.fromJson(Map<String, dynamic> json) {
    return ExamPaperQuestion(
      id: json['id'] as String?,
      content: json['content'] as String,
      userAnswer: json['userAnswer'] as String?,
      correctAnswer: json['correctAnswer'] as String?,
      score: json['score'] as int?,
      fullScore: json['fullScore'] as int?,
      analysis: json['analysis'] as String?,
      options: (json['options'] as List<dynamic>?)?.cast<String>(),
      questionType: json['questionType'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'userAnswer': userAnswer,
      'correctAnswer': correctAnswer,
      'score': score,
      'fullScore': fullScore,
      'analysis': analysis,
      'options': options,
      'questionType': questionType,
    };
  }

  ExamPaperQuestion copyWith({
    String? id,
    String? content,
    String? userAnswer,
    String? correctAnswer,
    int? score,
    int? fullScore,
    String? analysis,
    List<String>? options,
    String? questionType,
  }) {
    return ExamPaperQuestion(
      id: id ?? this.id,
      content: content ?? this.content,
      userAnswer: userAnswer ?? this.userAnswer,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      score: score ?? this.score,
      fullScore: fullScore ?? this.fullScore,
      analysis: analysis ?? this.analysis,
      options: options ?? this.options,
      questionType: questionType ?? this.questionType,
    );
  }
}

/// 试卷图片模型
class ExamPaperImage {
  final String id;
  final String path;
  final int? pageNumber;
  final String? ocrText;
  final int createdAt;

  ExamPaperImage({
    String? id,
    required this.path,
    this.pageNumber,
    this.ocrText,
    int? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  factory ExamPaperImage.fromJson(Map<String, dynamic> json) {
    return ExamPaperImage(
      id: json['id'] as String?,
      path: json['path'] as String,
      pageNumber: json['pageNumber'] as int?,
      ocrText: json['ocrText'] as String?,
      createdAt: json['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'path': path,
      'pageNumber': pageNumber,
      'ocrText': ocrText,
      'createdAt': createdAt,
    };
  }
}

/// 试卷模型
class ExamPaper {
  final String id;
  final String name;
  final String subject;
  final int examDate; // 考试时间戳
  final int totalScore;
  final int? obtainedScore;
  final List<ExamPaperQuestion> questions;
  final List<ExamPaperImage> images;
  final String? notes;
  final ExamPaperSource source;
  final int createdAt;
  final int updatedAt;

  ExamPaper({
    String? id,
    required this.name,
    required this.subject,
    required this.examDate,
    required this.totalScore,
    this.obtainedScore,
    List<ExamPaperQuestion>? questions,
    List<ExamPaperImage>? images,
    this.notes,
    this.source = ExamPaperSource.mock,
    int? createdAt,
    int? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        questions = questions ?? [],
        images = images ?? [],
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  /// 从JSON创建
  factory ExamPaper.fromJson(Map<String, dynamic> json) {
    return ExamPaper(
      id: json['id'] as String?,
      name: json['name'] as String,
      subject: json['subject'] as String,
      examDate: json['examDate'] as int,
      totalScore: json['totalScore'] as int,
      obtainedScore: json['obtainedScore'] as int?,
      questions: (json['questions'] as List<dynamic>?)
              ?.map((e) => ExamPaperQuestion.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => ExamPaperImage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      notes: json['notes'] as String?,
      source: ExamPaperSource.fromValue(json['source'] as String? ?? 'mock'),
      createdAt: json['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: json['updatedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'subject': subject,
      'examDate': examDate,
      'totalScore': totalScore,
      'obtainedScore': obtainedScore,
      'questions': questions.map((q) => q.toJson()).toList(),
      'images': images.map((i) => i.toJson()).toList(),
      'notes': notes,
      'source': source.value,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  /// 复制并修改部分字段
  ExamPaper copyWith({
    String? id,
    String? name,
    String? subject,
    int? examDate,
    int? totalScore,
    int? obtainedScore,
    List<ExamPaperQuestion>? questions,
    List<ExamPaperImage>? images,
    String? notes,
    ExamPaperSource? source,
    int? createdAt,
    int? updatedAt,
  }) {
    return ExamPaper(
      id: id ?? this.id,
      name: name ?? this.name,
      subject: subject ?? this.subject,
      examDate: examDate ?? this.examDate,
      totalScore: totalScore ?? this.totalScore,
      obtainedScore: obtainedScore ?? this.obtainedScore,
      questions: questions ?? this.questions,
      images: images ?? this.images,
      notes: notes ?? this.notes,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 计算得分率
  double? get scoreRate {
    if (obtainedScore == null || totalScore == 0) return null;
    return obtainedScore! / totalScore;
  }

  /// 获取得分率百分比字符串
  String get scoreRateString {
    final rate = scoreRate;
    if (rate == null) return '--';
    return '${(rate * 100).toStringAsFixed(1)}%';
  }

  /// 获取考试日期字符串
  String get examDateString {
    final date = DateTime.fromMillisecondsSinceEpoch(examDate);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 错题数量
  int get wrongQuestionCount {
    return questions.where((q) {
      if (q.score == null || q.fullScore == null) return false;
      return q.score! < q.fullScore!;
    }).length;
  }

  /// 已录入答案的题目数量
  int get answeredQuestionCount {
    return questions.where((q) => q.userAnswer != null).length;
  }

  @override
  String toString() {
    return 'ExamPaper(id: $id, name: $name, subject: $subject, '
        'score: $obtainedScore/$totalScore, source: ${source.label}, '
        'questions: ${questions.length}, images: ${images.length})';
  }
}
