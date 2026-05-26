import 'dart:convert';
import 'package:csv/csv.dart';
import 'database_service.dart';

/// 批量导入服务
/// 支持JSON和CSV格式的数据批量导入
class BatchImportService {
  final DatabaseService _db = DatabaseService();

  // 支持的导入类型
  static const String typeKnowledgePoint = 'knowledge_point';
  static const String typeMustRemember = 'must_remember';
  static const String typeWrongQuestion = 'wrong_question';
  static const String typeMotherQuestion = 'mother_question';
  static const String typeNote = 'note';

  /// 解析JSON数据
  List<Map<String, dynamic>> parseJsonData(String json, String type) {
    try {
      final decoded = jsonDecode(json);
      List<dynamic> items;

      if (decoded is List) {
        items = decoded;
      } else if (decoded is Map && decoded.containsKey('data')) {
        items = decoded['data'] as List;
      } else {
        throw Exception('JSON格式错误：期望数组或包含data字段的对象');
      }

      return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      throw Exception('JSON解析失败: $e');
    }
  }

  /// 解析CSV数据
  List<Map<String, dynamic>> parseCsvData(String csv, String type) {
    try {
      final rows = const CsvToListConverter().convert(csv);
      if (rows.isEmpty) {
        throw Exception('CSV数据为空');
      }

      final headers = rows.first.map((e) => e.toString()).toList();
      final dataRows = rows.skip(1);

      return dataRows.map((row) {
        final map = <String, dynamic>{};
        for (var i = 0; i < headers.length && i < row.length; i++) {
          map[headers[i]] = row[i];
        }
        return map;
      }).toList();
    } catch (e) {
      throw Exception('CSV解析失败: $e');
    }
  }

  /// 验证数据格式
  ValidationResult validateData(List<Map<String, dynamic>> data, String type) {
    final validData = <Map<String, dynamic>>[];
    final errors = <ValidationError>[];

    for (var i = 0; i < data.length; i++) {
      final item = data[i];
      final rowNum = i + 1;

      try {
        final validatedItem = _validateAndNormalizeItem(item, type, rowNum);
        if (validatedItem != null) {
          validData.add(validatedItem);
        }
      } on ValidationException catch (e) {
        errors.add(ValidationError(rowNum, e.message));
      }
    }

    return ValidationResult(validData, errors);
  }

  Map<String, dynamic>? _validateAndNormalizeItem(
    Map<String, dynamic> item,
    String type,
    int rowNum,
  ) {
    switch (type) {
      case typeKnowledgePoint:
        return _validateKnowledgePoint(item, rowNum);
      case typeMustRemember:
        return _validateMustRemember(item, rowNum);
      case typeWrongQuestion:
        return _validateWrongQuestion(item, rowNum);
      case typeMotherQuestion:
        return _validateMotherQuestion(item, rowNum);
      case typeNote:
        return _validateNote(item, rowNum);
      default:
        throw ValidationException('未知的导入类型: $type');
    }
  }

  Map<String, dynamic> _validateKnowledgePoint(
    Map<String, dynamic> item,
    int rowNum,
  ) {
    final title = _getStringValue(item, ['title', '标题', 'name', '名称']);
    final content = _getStringValue(item, ['content', '内容', 'description', '描述']);
    final subject = _getStringValue(item, ['subject', '学科', '科目']);

    if (title == null || title.isEmpty) {
      throw ValidationException('标题不能为空');
    }
    if (content == null || content.isEmpty) {
      throw ValidationException('内容不能为空');
    }
    if (subject == null || subject.isEmpty) {
      throw ValidationException('学科不能为空');
    }

    return {
      'title': title,
      'content': content,
      'subject': subject,
      'chapter': _getStringValue(item, ['chapter', '章节']),
      'tags': jsonEncode(_parseListValue(item, ['tags', '标签'])),
      'difficulty': _getIntValue(item, ['difficulty', '难度'], defaultValue: 1),
      'mastery_level': _getIntValue(item, ['masteryLevel', '掌握程度'], defaultValue: 0),
      'exam_methods': jsonEncode(_parseListValue(item, ['examMethods', '考法'])),
      'key_points': jsonEncode(_parseListValue(item, ['keyPoints', '考点'])),
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> _validateMustRemember(
    Map<String, dynamic> item,
    int rowNum,
  ) {
    final title = _getStringValue(item, ['title', '标题', 'name', '名称']);
    final content = _getStringValue(item, ['content', '内容', 'description', '描述']);
    final subject = _getStringValue(item, ['subject', '学科', '科目']);
    final category = _getStringValue(item, ['category', '分类', '类型']);

    if (title == null || title.isEmpty) {
      throw ValidationException('标题不能为空');
    }
    if (content == null || content.isEmpty) {
      throw ValidationException('内容不能为空');
    }
    if (subject == null || subject.isEmpty) {
      throw ValidationException('学科不能为空');
    }
    if (category == null || category.isEmpty) {
      throw ValidationException('分类不能为空');
    }

    return {
      'title': title,
      'content': content,
      'subject': subject,
      'chapter': _getStringValue(item, ['chapter', '章节']),
      'category': category,
      'exam_methods': jsonEncode(_parseListValue(item, ['examMethods', '考法'])),
      'key_points': jsonEncode(_parseListValue(item, ['keyPoints', '考点'])),
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> _validateWrongQuestion(
    Map<String, dynamic> item,
    int rowNum,
  ) {
    final title = _getStringValue(item, ['title', '标题']);
    final content = _getStringValue(item, ['content', '题目内容', 'question_content', '题目']);
    final correctAnswer = _getStringValue(item, ['correctAnswer', '正确答案', 'correct_answer', '答案']);
    final subject = _getStringValue(item, ['subject', '学科', '科目']);

    if (content == null || content.isEmpty) {
      throw ValidationException('题目内容不能为空');
    }
    if (correctAnswer == null || correctAnswer.isEmpty) {
      throw ValidationException('正确答案不能为空');
    }
    if (subject == null || subject.isEmpty) {
      throw ValidationException('学科不能为空');
    }

    return {
      'title': title ?? content.substring(0, content.length > 20 ? 20 : content.length),
      'question_content': content,
      'correct_answer': correctAnswer,
      'analysis': _getStringValue(item, ['analysis', '解析', 'explanation'], defaultValue: ''),
      'subject': subject,
      'chapter': _getStringValue(item, ['chapter', '章节']),
      'error_type': _getStringValue(item, ['errorType', '错误类型', 'error_type'], defaultValue: '知识盲区'),
      'options': jsonEncode(_parseOptions(item['options'] ?? item['选项'])),
      'tags': jsonEncode(_parseListValue(item, ['tags', '标签'])),
      'exam_methods': jsonEncode(_parseListValue(item, ['examMethods', '考法'])),
      'key_points': jsonEncode(_parseListValue(item, ['keyPoints', '考点'])),
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> _validateMotherQuestion(
    Map<String, dynamic> item,
    int rowNum,
  ) {
    final title = _getStringValue(item, ['title', '标题']);
    final content = _getStringValue(item, ['content', '题目内容', 'question_content', '题目']);
    final correctAnswer = _getStringValue(item, ['correctAnswer', '正确答案', 'correct_answer', '答案']);
    final subject = _getStringValue(item, ['subject', '学科', '科目']);

    if (content == null || content.isEmpty) {
      throw ValidationException('题目内容不能为空');
    }
    if (correctAnswer == null || correctAnswer.isEmpty) {
      throw ValidationException('正确答案不能为空');
    }
    if (subject == null || subject.isEmpty) {
      throw ValidationException('学科不能为空');
    }

    return {
      'title': title ?? content.substring(0, content.length > 20 ? 20 : content.length),
      'question_content': content,
      'correct_answer': correctAnswer,
      'analysis': _getStringValue(item, ['analysis', '解析', 'explanation'], defaultValue: ''),
      'subject': subject,
      'chapter': _getStringValue(item, ['chapter', '章节']),
      'difficulty': _getIntValue(item, ['difficulty', '难度'], defaultValue: 1),
      'options': jsonEncode(_parseOptions(item['options'] ?? item['选项'])),
      'tags': jsonEncode(_parseListValue(item, ['tags', '标签'])),
      'exam_methods': jsonEncode(_parseListValue(item, ['examMethods', '考法'])),
      'key_points': jsonEncode(_parseListValue(item, ['keyPoints', '考点'])),
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> _validateNote(
    Map<String, dynamic> item,
    int rowNum,
  ) {
    final title = _getStringValue(item, ['title', '标题', 'name', '名称']);
    final content = _getStringValue(item, ['content', '内容', 'description', '描述']);
    final subject = _getStringValue(item, ['subject', '学科', '科目']);

    if (title == null || title.isEmpty) {
      throw ValidationException('标题不能为空');
    }
    if (content == null || content.isEmpty) {
      throw ValidationException('内容不能为空');
    }
    if (subject == null || subject.isEmpty) {
      throw ValidationException('学科不能为空');
    }

    return {
      'title': title,
      'content': content,
      'subject': subject,
      'chapter': _getStringValue(item, ['chapter', '章节']),
      'tags': jsonEncode(_parseListValue(item, ['tags', '标签'])),
      'color': _getStringValue(item, ['color', '颜色'], defaultValue: '#FFFFFF'),
      'exam_methods': jsonEncode(_parseListValue(item, ['examMethods', '考法'])),
      'key_points': jsonEncode(_parseListValue(item, ['keyPoints', '考点'])),
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Future<ImportResult> importData(
    List<Map<String, dynamic>> data,
    String type,
  ) async {
    int successCount = 0;
    int failCount = 0;
    final errors = <String>[];

    for (var i = 0; i < data.length; i++) {
      try {
        await _importSingleItem(data[i], type);
        successCount++;
      } catch (e) {
        failCount++;
        errors.add('第${i + 1}行: $e');
      }
    }

    return ImportResult(
      totalCount: data.length,
      successCount: successCount,
      failCount: failCount,
      errors: errors,
    );
  }

  Future<void> _importSingleItem(Map<String, dynamic> data, String type) async {
    final db = await _db.database;
    
    switch (type) {
      case typeKnowledgePoint:
        await db.insert('knowledge_points', data);
        break;
      case typeMustRemember:
        await db.insert('must_remembers', data);
        break;
      case typeWrongQuestion:
        await db.insert('wrong_questions', data);
        break;
      case typeMotherQuestion:
        await db.insert('mother_questions', data);
        break;
      case typeNote:
        await db.insert('notes', data);
        break;
      default:
        throw Exception('未知的导入类型: $type');
    }
  }

  String? _getStringValue(
    Map<String, dynamic> item,
    List<String> keys, {
    String? defaultValue,
  }) {
    for (final key in keys) {
      if (item.containsKey(key)) {
        final value = item[key];
        if (value != null && value.toString().isNotEmpty) {
          return value.toString();
        }
      }
    }
    return defaultValue;
  }

  int _getIntValue(
    Map<String, dynamic> item,
    List<String> keys, {
    required int defaultValue,
  }) {
    for (final key in keys) {
      if (item.containsKey(key)) {
        final value = item[key];
        if (value is int) return value;
        if (value is String) {
          return int.tryParse(value) ?? defaultValue;
        }
      }
    }
    return defaultValue;
  }

  List<String> _parseListValue(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      if (item.containsKey(key)) {
        final value = item[key];
        if (value is List) {
          return value.map((e) => e.toString()).toList();
        }
        if (value is String && value.isNotEmpty) {
          return value
              .split(RegExp(r'[,;，；\n]'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      }
    }
    return [];
  }

  List<Map<String, dynamic>> _parseOptions(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value.map((e) {
        if (e is Map) {
          return Map<String, dynamic>.from(e);
        }
        return {'text': e.toString()};
      }).toList();
    }

    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.map((e) {
            if (e is Map) {
              return Map<String, dynamic>.from(e);
            }
            return {'text': e.toString()};
          }).toList();
        }
      } catch (_) {
        return value
            .split(RegExp(r'[,;，；]'))
            .map((e) => {'text': e.trim()})
            .where((e) => e['text']!.isNotEmpty)
            .toList();
      }
    }

    return [];
  }

  String getJsonTemplate(String type) {
    switch (type) {
      case typeKnowledgePoint:
        return '''[\n  {\n    "title": "知识点标题",\n    "content": "知识点内容",\n    "subject": "数学",\n    "chapter": "第一章",\n    "tags": ["重要", "常考"],\n    "difficulty": 3,\n    "masteryLevel": 50,\n    "examMethods": ["选择题", "填空题"],\n    "keyPoints": ["核心概念", "易错点"]\n  }\n]''';
      case typeMustRemember:
        return '''[\n  {\n    "title": "公式名称",\n    "content": "公式内容",\n    "subject": "数学",\n    "chapter": "第一章",\n    "category": "公式",\n    "examMethods": ["计算题"],\n    "keyPoints": ["适用条件"]\n  }\n]''';
      case typeWrongQuestion:
        return '''[\n  {\n    "title": "错题标题",\n    "content": "题目内容",\n    "correctAnswer": "正确答案",\n    "analysis": "解析",\n    "subject": "数学",\n    "chapter": "第一章",\n    "errorType": "知识盲区",\n    "options": [\n      {"text": "选项A"},\n      {"text": "选项B"}\n    ],\n    "tags": ["易错"],\n    "examMethods": ["选择题"],\n    "keyPoints": ["考点1"]\n  }\n]''';
      case typeMotherQuestion:
        return '''[\n  {\n    "title": "母题标题",\n    "content": "题目内容",\n    "correctAnswer": "正确答案",\n    "analysis": "解析",\n    "subject": "数学",\n    "chapter": "第一章",\n    "difficulty": 3,\n    "options": [\n      {"text": "选项A"},\n      {"text": "选项B"}\n    ],\n    "tags": ["经典"],\n    "examMethods": ["解答题"],\n    "keyPoints": ["核心考点"]\n  }\n]''';
      case typeNote:
        return '''[\n  {\n    "title": "笔记标题",\n    "content": "笔记内容（支持Markdown）",\n    "subject": "数学",\n    "chapter": "第一章",\n    "tags": ["课堂笔记"],\n    "color": "#FFFFFF",\n    "examMethods": ["复习用"],\n    "keyPoints": ["重点"]\n  }\n]''';
      default:
        return '[]';
    }
  }

  String getCsvTemplate(String type) {
    switch (type) {
      case typeKnowledgePoint:
        return 'title,content,subject,chapter,tags,difficulty,masteryLevel,examMethods,keyPoints\n'
            '知识点标题,知识点内容,数学,第一章,"重要,常考",3,50,"选择题,填空题","核心概念,易错点"';
      case typeMustRemember:
        return 'title,content,subject,chapter,category,examMethods,keyPoints\n'
            '公式名称,公式内容,数学,第一章,公式,计算题,适用条件';
      case typeWrongQuestion:
        return 'title,content,correctAnswer,analysis,subject,chapter,errorType,options,tags,examMethods,keyPoints\n'
            '错题标题,题目内容,正确答案,解析,数学,第一章,知识盲区,"选项A;选项B","易错",选择题,考点1';
      case typeMotherQuestion:
        return 'title,content,correctAnswer,analysis,subject,chapter,difficulty,options,tags,examMethods,keyPoints\n'
            '母题标题,题目内容,正确答案,解析,数学,第一章,3,"选项A;选项B",经典,解答题,核心考点';
      case typeNote:
        return 'title,content,subject,chapter,tags,color,examMethods,keyPoints\n'
            '笔记标题,笔记内容,数学,第一章,课堂笔记,#FFFFFF,复习用,重点';
      default:
        return '';
    }
  }

  static String getTypeDisplayName(String type) {
    switch (type) {
      case typeKnowledgePoint:
        return '知识点';
      case typeMustRemember:
        return '必记必背';
      case typeWrongQuestion:
        return '错题';
      case typeMotherQuestion:
        return '母题';
      case typeNote:
        return '学习笔记';
      default:
        return type;
    }
  }
}

class ValidationResult {
  final List<Map<String, dynamic>> validData;
  final List<ValidationError> errors;

  ValidationResult(this.validData, this.errors);

  bool get isValid => errors.isEmpty;
  int get validCount => validData.length;
  int get errorCount => errors.length;
}

class ValidationError {
  final int rowNum;
  final String message;

  ValidationError(this.rowNum, this.message);
}

class ValidationException implements Exception {
  final String message;

  ValidationException(this.message);

  @override
  String toString() => message;
}

class ImportResult {
  final int totalCount;
  final int successCount;
  final int failCount;
  final List<String> errors;

  ImportResult({
    required this.totalCount,
    required this.successCount,
    required this.failCount,
    required this.errors,
  });

  bool get isSuccess => failCount == 0;
  double get successRate =>
      totalCount > 0 ? (successCount / totalCount * 100) : 0;
}
