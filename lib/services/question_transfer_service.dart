import 'dart:convert';
import '../models/wrong_question.dart';
import '../models/mother_question.dart';
import 'database_service.dart';

/// 题目转换服务
/// 支持错题与母题之间的相互转换
class QuestionTransferService {
  final DatabaseService _db = DatabaseService();

  /// 错题转母题
  /// [wrongQuestionId] 错题ID
  /// [keepOriginal] 是否保留原错题
  /// [additionalData] 可选的额外数据（如难度、标签等）
  Future<TransferResult> convertWrongToMother(
    String wrongQuestionId, {
    bool keepOriginal = false,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // 1. 获取错题数据
      final wrongQuestionData = await _db.queryWrongQuestionByUuid(wrongQuestionId);
      if (wrongQuestionData == null) {
        return TransferResult(
          success: false,
          message: '未找到指定的错题',
        );
      }

      // 2. 转换为错题模型
      final wrongQuestion = _parseWrongQuestion(wrongQuestionData);

      // 3. 创建母题
      final motherQuestion = MotherQuestion(
        title: wrongQuestion.title,
        content: wrongQuestion.content,
        correctAnswer: wrongQuestion.correctAnswer,
        analysis: wrongQuestion.analysis,
        subject: wrongQuestion.subject,
        chapter: wrongQuestion.chapter,
        difficulty: additionalData?['difficulty'] ?? 1,
        options: wrongQuestion.options,
        tags: [
          ...wrongQuestion.tags,
          if (additionalData?['tags'] != null) ...additionalData!['tags'] as List<String>,
        ],
        examMethods: wrongQuestion.examMethods,
        keyPoints: wrongQuestion.keyPoints,
        attachments: wrongQuestion.attachments,
      );

      // 4. 保存母题到数据库
      final motherId = await _db.insertMotherQuestion(motherQuestion.toJson());

      // 5. 如果不保留原错题，则删除
      if (!keepOriginal) {
        await _db.deleteWrongQuestionByUuid(wrongQuestionId);
      }

      return TransferResult(
        success: true,
        message: keepOriginal
            ? '错题已复制为母题，原错题已保留'
            : '错题已成功转换为母题',
        sourceId: wrongQuestionId,
        targetId: motherQuestion.id,
        targetDbId: motherId,
      );
    } catch (e) {
      return TransferResult(
        success: false,
        message: '转换失败: $e',
      );
    }
  }

  /// 母题转错题
  /// [motherQuestionId] 母题ID
  /// [keepOriginal] 是否保留原母题
  /// [additionalData] 可选的额外数据（如错误类型、错误原因等）
  Future<TransferResult> convertMotherToWrong(
    String motherQuestionId, {
    bool keepOriginal = false,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // 1. 获取母题数据
      final motherQuestionData = await _db.queryMotherQuestionByUuid(motherQuestionId);
      if (motherQuestionData == null) {
        return TransferResult(
          success: false,
          message: '未找到指定的母题',
        );
      }

      // 2. 转换为母题模型
      final motherQuestion = _parseMotherQuestion(motherQuestionData);

      // 3. 创建错题
      final wrongQuestion = WrongQuestion(
        title: motherQuestion.title,
        content: motherQuestion.content,
        correctAnswer: motherQuestion.correctAnswer,
        analysis: motherQuestion.analysis,
        subject: motherQuestion.subject,
        chapter: motherQuestion.chapter,
        errorType: additionalData?['errorType'] ?? '知识盲区',
        options: motherQuestion.options,
        tags: [
          ...motherQuestion.tags,
          if (additionalData?['tags'] != null) ...additionalData!['tags'] as List<String>,
        ],
        examMethods: motherQuestion.examMethods,
        keyPoints: motherQuestion.keyPoints,
        attachments: motherQuestion.attachments,
        errorCount: additionalData?['errorCount'] ?? 1,
        isResolved: additionalData?['isResolved'] ?? false,
      );

      // 4. 保存错题到数据库
      final wrongId = await _db.insertWrongQuestion(wrongQuestion.toJson());

      // 5. 如果不保留原母题，则删除
      if (!keepOriginal) {
        await _db.deleteMotherQuestionByUuid(motherQuestionId);
      }

      return TransferResult(
        success: true,
        message: keepOriginal
            ? '母题已复制为错题，原母题已保留'
            : '母题已成功转换为错题',
        sourceId: motherQuestionId,
        targetId: wrongQuestion.id,
        targetDbId: wrongId,
      );
    } catch (e) {
      return TransferResult(
        success: false,
        message: '转换失败: $e',
      );
    }
  }

  /// 批量转换错题为母题
  /// [wrongQuestionIds] 错题ID列表
  /// [keepOriginal] 是否保留原错题
  Future<BatchTransferResult> batchConvertWrongToMother(
    List<String> wrongQuestionIds, {
    bool keepOriginal = false,
  }) async {
    final results = <TransferResult>[];
    int successCount = 0;
    int failCount = 0;

    for (final id in wrongQuestionIds) {
      final result = await convertWrongToMother(
        id,
        keepOriginal: keepOriginal,
      );
      results.add(result);
      if (result.success) {
        successCount++;
      } else {
        failCount++;
      }
    }

    return BatchTransferResult(
      totalCount: wrongQuestionIds.length,
      successCount: successCount,
      failCount: failCount,
      results: results,
    );
  }

  /// 批量转换母题为错题
  /// [motherQuestionIds] 母题ID列表
  /// [keepOriginal] 是否保留原母题
  Future<BatchTransferResult> batchConvertMotherToWrong(
    List<String> motherQuestionIds, {
    bool keepOriginal = false,
  }) async {
    final results = <TransferResult>[];
    int successCount = 0;
    int failCount = 0;

    for (final id in motherQuestionIds) {
      final result = await convertMotherToWrong(
        id,
        keepOriginal: keepOriginal,
      );
      results.add(result);
      if (result.success) {
        successCount++;
      } else {
        failCount++;
      }
    }

    return BatchTransferResult(
      totalCount: motherQuestionIds.length,
      successCount: successCount,
      failCount: failCount,
      results: results,
    );
  }

  /// 解析错题数据
  WrongQuestion _parseWrongQuestion(Map<String, dynamic> data) {
    return WrongQuestion(
      id: data['uuid'] as String? ?? data['id'].toString(),
      title: data['title'] as String? ?? data['question_content'] as String? ?? '',
      content: data['question_content'] as String? ?? data['content'] as String? ?? '',
      correctAnswer: data['correct_answer'] as String? ?? '',
      userAnswer: data['my_answer'] as String?,
      analysis: data['analysis'] as String? ?? '',
      subject: data['subject'] as String? ?? '其他',
      chapter: data['chapter'] as String?,
      errorType: data['error_type'] as String? ?? '知识盲区',
      errorCount: data['error_count'] as int? ?? 1,
      isResolved: (data['is_mastered'] as int? ?? 0) == 1,
      createdAt: _parseTimestamp(data['created_at']),
      updatedAt: _parseTimestamp(data['updated_at']),
      options: _parseOptions(data['options']),
      attachments: _parseAttachments(data['attachment_paths']),
      tags: _parseTags(data['tags']),
      examMethods: _parseList(data['exam_methods']),
      keyPoints: _parseList(data['key_points']),
    );
  }

  /// 解析母题数据
  MotherQuestion _parseMotherQuestion(Map<String, dynamic> data) {
    return MotherQuestion(
      id: data['uuid'] as String? ?? data['id'].toString(),
      title: data['title'] as String? ?? '',
      content: data['question_content'] as String? ?? data['content'] as String? ?? '',
      correctAnswer: data['correct_answer'] as String? ?? '',
      analysis: data['analysis'] as String? ?? '',
      subject: data['subject'] as String? ?? '其他',
      chapter: data['chapter'] as String?,
      difficulty: data['difficulty'] as int? ?? 1,
      createdAt: _parseTimestamp(data['created_at']),
      updatedAt: _parseTimestamp(data['updated_at']),
      options: _parseOptions(data['options']),
      attachments: _parseAttachments(data['attachment_paths']),
      tags: _parseTags(data['tags']),
      examMethods: _parseList(data['exam_methods']),
      keyPoints: _parseList(data['key_points']),
    );
  }

  /// 解析时间戳
  int _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now().millisecondsSinceEpoch;
    if (value is int) return value;
    if (value is String) {
      final dateTime = DateTime.tryParse(value);
      return dateTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;
    }
    return DateTime.now().millisecondsSinceEpoch;
  }

  /// 解析选项
  List<Map<String, dynamic>> _parseOptions(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) {
        if (e is Map) return Map<String, dynamic>.from(e);
        return {'text': e.toString()};
      }).toList();
    }
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.map((e) {
            if (e is Map) return Map<String, dynamic>.from(e);
            return {'text': e.toString()};
          }).toList();
        }
      } catch (_) {
        return [];
      }
    }
    return [];
  }

  /// 解析附件
  List<Map<String, dynamic>> _parseAttachments(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => {'path': e.toString()}).toList();
    }
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.map((e) => {'path': e.toString()}).toList();
        }
      } catch (_) {
        return value.split(',').map((e) => {'path': e.trim()}).toList();
      }
    }
    return [];
  }

  /// 解析标签
  List<String> _parseTags(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String) {
      return value.split(',').where((e) => e.trim().isNotEmpty).toList();
    }
    return [];
  }

  /// 解析列表
  List<String> _parseList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String && value.isNotEmpty) {
      return value.split(',').where((e) => e.trim().isNotEmpty).toList();
    }
    return [];
  }
}

/// 转换结果
class TransferResult {
  final bool success;
  final String message;
  final String? sourceId;
  final String? targetId;
  final int? targetDbId;

  TransferResult({
    required this.success,
    required this.message,
    this.sourceId,
    this.targetId,
    this.targetDbId,
  });
}

/// 批量转换结果
class BatchTransferResult {
  final int totalCount;
  final int successCount;
  final int failCount;
  final List<TransferResult> results;

  BatchTransferResult({
    required this.totalCount,
    required this.successCount,
    required this.failCount,
    required this.results,
  });

  bool get isSuccess => failCount == 0;
  double get successRate => totalCount > 0 ? (successCount / totalCount * 100) : 0;
}
