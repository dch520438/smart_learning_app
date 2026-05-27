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

      return items.map((e) => _sanitizeMap(Map<String, dynamic>.from(e as Map))).toList();
    } catch (e) {
      throw Exception('JSON解析失败: $e');
    }
  }

  /// 解析CSV数据
  List<Map<String, dynamic>> parseCsvData(String csv, String type) {
    try {
      final rows = const CsvToListConverter(
        fieldDelimiter: ',',
        textDelimiter: '"',
        textEndDelimiter: '"',
        eol: '\n',
      ).convert(csv);
      if (rows.isEmpty) {
        throw Exception('CSV数据为空');
      }

      final headers = rows.first.map((e) => e.toString().trim()).toList();
      final dataRows = rows.skip(1);

      return dataRows.map((row) {
        final map = <String, dynamic>{};
        for (var i = 0; i < headers.length && i < row.length; i++) {
          final value = row[i];
          // 将 null 值转为空字符串，确保后续处理安全
          map[headers[i]] = value == null ? '' : value.toString().trim();
        }
        return map;
      }).where((map) {
        // 过滤掉完全空的行
        return map.values.any((v) => v.toString().isNotEmpty);
      }).toList();
    } catch (e) {
      throw Exception('CSV解析失败: $e');
    }
  }

  /// 清理 Map 中的值，将布尔值转为整数，确保 SQLite 兼容
  Map<String, dynamic> _sanitizeMap(Map<String, dynamic> map) {
    final sanitized = <String, dynamic>{};
    map.forEach((key, value) {
      if (value is bool) {
        sanitized[key] = value ? 1 : 0;
      } else if (value == null) {
        // 跳过 null 值
      } else {
        sanitized[key] = value;
      }
    });
    return sanitized;
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
      } catch (e) {
        errors.add(ValidationError(rowNum, '验证异常: $e'));
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
      'uuid': _generateUuid(),
      'title': title,
      'content': content,
      'subject': subject,
      'chapter': _getStringValue(item, ['chapter', '章节'], defaultValue: ''),
      'tags': jsonEncode(_parseListValue(item, ['tags', '标签'])),
      'difficulty': _getIntValue(item, ['difficulty', '难度'], defaultValue: 1),
      'mastery_level': _getIntValue(item, ['masteryLevel', '掌握程度'], defaultValue: 0),
      'review_count': 0,
      'last_review_time': '',
      'is_favorite': 0,
      'exam_methods': jsonEncode(_parseListValue(item, ['examMethods', 'examMethods', '考法'])),
      'key_points': jsonEncode(_parseListValue(item, ['keyPoints', 'keyPoints', '考点'])),
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
    final category = _getStringValue(item, ['category', '分类', '类型'], defaultValue: '公式');

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
      'uuid': _generateUuid(),
      'title': title,
      'content': content,
      'subject': subject,
      'chapter': _getStringValue(item, ['chapter', '章节'], defaultValue: ''),
      'category': category,
      'importance': _getIntValue(item, ['importance', '重要性'], defaultValue: 1),
      'memory_level': 0,
      'review_count': 0,
      'review_interval': 0,
      'is_mastered': 0,
      'is_favorite': 0,
      'exam_methods': jsonEncode(_parseListValue(item, ['examMethods', 'examMethods', '考法'])),
      'key_points': jsonEncode(_parseListValue(item, ['keyPoints', 'keyPoints', '考点'])),
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
    final correctAnswer = _getStringValue(item, ['correctAnswer', 'correct_answer', '答案']);
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
      'uuid': _generateUuid(),
      'title': title ?? content.substring(0, content.length > 20 ? 20 : content.length),
      'question_content': content,
      'correct_answer': correctAnswer,
      'analysis': _getStringValue(item, ['analysis', '解析', 'explanation'], defaultValue: ''),
      'subject': subject,
      'chapter': _getStringValue(item, ['chapter', '章节'], defaultValue: ''),
      'error_type': _getStringValue(item, ['errorType', 'error_type', '错误类型'], defaultValue: '知识盲区'),
      'difficulty': _getIntValue(item, ['difficulty', '难度'], defaultValue: 1),
      'is_mastered': 0,
      'options': jsonEncode(_parseOptions(item['options'] ?? item['选项'])),
      'tags': jsonEncode(_parseListValue(item, ['tags', '标签'])),
      'exam_methods': jsonEncode(_parseListValue(item, ['examMethods', 'examMethods', '考法'])),
      'key_points': jsonEncode(_parseListValue(item, ['keyPoints', 'keyPoints', '考点'])),
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
    final correctAnswer = _getStringValue(item, ['correctAnswer', 'correct_answer', '答案']);
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
      'uuid': _generateUuid(),
      'title': title ?? content.substring(0, content.length > 20 ? 20 : content.length),
      'question_content': content,
      'correct_answer': correctAnswer,
      'analysis': _getStringValue(item, ['analysis', '解析', 'explanation'], defaultValue: ''),
      'subject': subject,
      'chapter': _getStringValue(item, ['chapter', '章节'], defaultValue: ''),
      'difficulty': _getIntValue(item, ['difficulty', '难度'], defaultValue: 1),
      'options': jsonEncode(_parseOptions(item['options'] ?? item['选项'])),
      'tags': jsonEncode(_parseListValue(item, ['tags', '标签'])),
      'exam_methods': jsonEncode(_parseListValue(item, ['examMethods', 'examMethods', '考法'])),
      'key_points': jsonEncode(_parseListValue(item, ['keyPoints', 'keyPoints', '考点'])),
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
      'uuid': _generateUuid(),
      'title': title,
      'content': content,
      'subject': subject,
      'chapter': _getStringValue(item, ['chapter', '章节'], defaultValue: ''),
      'note_type': 'text',
      'is_favorite': 0,
      'tags': jsonEncode(_parseListValue(item, ['tags', '标签'])),
      'color': _getStringValue(item, ['color', '颜色'], defaultValue: '#FFFFFF'),
      'exam_methods': jsonEncode(_parseListValue(item, ['examMethods', 'examMethods', '考法'])),
      'key_points': jsonEncode(_parseListValue(item, ['keyPoints', 'keyPoints', '考点'])),
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// 生成唯一 ID
  String _generateUuid() {
    return 'imp_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
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
    
    // 最终清理：确保所有值都是 SQLite 兼容类型
    final cleanData = _sanitizeMap(data);
    
    switch (type) {
      case typeKnowledgePoint:
        await db.insert('knowledge_points', cleanData);
        break;
      case typeMustRemember:
        await db.insert('must_remembers', cleanData);
        break;
      case typeWrongQuestion:
        await db.insert('wrong_questions', cleanData);
        break;
      case typeMotherQuestion:
        await db.insert('mother_questions', cleanData);
        break;
      case typeNote:
        await db.insert('notes', cleanData);
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
        if (value != null) {
          final str = value.toString().trim();
          if (str.isNotEmpty) {
            return str;
          }
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
        if (value is bool) return value ? 1 : 0;
        if (value is double) return value.toInt();
        if (value is String) {
          return int.tryParse(value) ?? defaultValue;
        }
      }
    }
    return defaultValue;
  }

  /// 解析列表值
  /// 优先尝试 JSON 解析，失败则按分隔符拆分
  List<String> _parseListValue(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      if (item.containsKey(key)) {
        final value = item[key];
        if (value == null) continue;
        
        // 如果已经是 List
        if (value is List) {
          return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
        }
        
        final str = value.toString().trim();
        if (str.isEmpty) continue;
        
        // 优先尝试 JSON 解析（处理 ["a","b"] 格式）
        if (str.startsWith('[')) {
          try {
            final decoded = jsonDecode(str);
            if (decoded is List) {
              return decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
            }
          } catch (_) {
            // JSON 解析失败，继续用分隔符
          }
        }
        
        // 按分隔符拆分
        return str
            .split(RegExp(r'[,;，；\n]'))
            .map((e) => e.trim().replaceAll(RegExp(r'^["\'\[\]]+|["\'\[\]]+\$'), ''))
            .where((e) => e.isNotEmpty)
            .toList();
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

    final str = value.toString().trim();
    if (str.isEmpty) return [];

    // 优先尝试 JSON 解析
    if (str.startsWith('[')) {
      try {
        final decoded = jsonDecode(str);
        if (decoded is List) {
          return decoded.map((e) {
            if (e is Map) {
              return Map<String, dynamic>.from(e);
            }
            return {'text': e.toString()};
          }).toList();
        }
      } catch (_) {
        // JSON 解析失败，继续用分隔符
      }
    }

    // 按分隔符拆分
    return str
        .split(RegExp(r'[,;，；]'))
        .map((e) => {'text': e.trim()})
        .where((e) => e['text']!.isNotEmpty)
        .toList();
  }

  String getJsonTemplate(String type) {
    switch (type) {
      case typeKnowledgePoint:
        return '[\n  {\n'
            '    "title": "牛顿第二定律",\n'
            '    "content": "物体的加速度与所受合力成正比，与物体的质量成反比，公式F=ma",\n'
            '    "subject": "物理",\n'
            '    "chapter": "牛顿运动定律",\n'
            '    "tags": ["力学", "核心公式"],\n'
            '    "difficulty": 3,\n'
            '    "masteryLevel": 50,\n'
            '    "examMethods": ["选择题", "计算题"],\n'
            '    "keyPoints": ["合力", "质量", "加速度"]\n'
            '  }\n'
            ']';
      case typeMustRemember:
        return '[\n  {\n'
            '    "title": "勾股定理",\n'
            '    "content": "直角三角形两条直角边的平方和等于斜边的平方，即a²+b²=c²",\n'
            '    "subject": "数学",\n'
            '    "chapter": "勾股定理",\n'
            '    "category": "公式",\n'
            '    "examMethods": ["计算题", "证明题"],\n'
            '    "keyPoints": ["直角三角形", "平方关系"]\n'
            '  }\n'
            ']';
      case typeWrongQuestion:
        return '[\n  {\n'
            '    "title": "函数定义域",\n'
            '    "content": "求函数f(x)=√(x-2)/(x-3)的定义域",\n'
            '    "options": [\n'
            '      {"label": "A", "content": "x≥2"},\n'
            '      {"label": "B", "content": "x≥2且x≠3"},\n'
            '      {"label": "C", "content": "x>2"},\n'
            '      {"label": "D", "content": "x>3"}\n'
            '    ],\n'
            '    "correctAnswer": "B",\n'
            '    "analysis": "根号内非负得x≥2，分母不为零得x≠3",\n'
            '    "subject": "数学",\n'
            '    "chapter": "函数",\n'
            '    "errorType": "概念错误",\n'
            '    "tags": ["函数", "定义域"],\n'
            '    "examMethods": ["选择题"],\n'
            '    "keyPoints": ["根式", "分式"]\n'
            '  }\n'
            ']';
      case typeMotherQuestion:
        return '[\n  {\n'
            '    "title": "二次函数最值",\n'
            '    "content": "已知f(x)=-x²+4x-3，求其在[0,3]上的最大值",\n'
            '    "options": [\n'
            '      {"label": "A", "content": "0"},\n'
            '      {"label": "B", "content": "1"},\n'
            '      {"label": "C", "content": "3"},\n'
            '      {"label": "D", "content": "4"}\n'
            '    ],\n'
            '    "correctAnswer": "B",\n'
            '    "analysis": "配方法得f(x)=-(x-2)²+1，对称轴x=2在区间内",\n'
            '    "subject": "数学",\n'
            '    "chapter": "二次函数",\n'
            '    "difficulty": 3,\n'
            '    "tags": ["经典", "高频"],\n'
            '    "examMethods": ["选择题", "解答题"],\n'
            '    "keyPoints": ["配方法", "对称轴", "最值"]\n'
            '  }\n'
            ']';
      case typeNote:
        return '[\n  {\n'
            '    "title": "英语时态总结",\n'
            '    "content": "一般现在时：主语+动词原形\\n一般过去时：主语+动词过去式\\n一般将来时：主语+will+动词原形",\n'
            '    "subject": "英语",\n'
            '    "chapter": "时态",\n'
            '    "tags": ["语法", "总结"],\n'
            '    "color": "#E3F2FD",\n'
            '    "examMethods": ["选择题", "填空题"],\n'
            '    "keyPoints": ["时态结构", "时间标志词"]\n'
            '  }\n'
            ']';
      default:
        return '[]';
    }
  }

  String getCsvTemplate(String type) {
    switch (type) {
      case typeKnowledgePoint:
        return 'title,content,subject,chapter,tags,difficulty,masteryLevel,examMethods,keyPoints\n'
            '牛顿第二定律,F=ma,物理,牛顿运动定律,"力学;核心公式",3,50,"选择题;计算题","合力;质量;加速度"';
      case typeMustRemember:
        return 'title,content,subject,chapter,category,examMethods,keyPoints\n'
            '勾股定理,"a²+b²=c²",数学,勾股定理,公式,"计算题;证明题","直角三角形;平方关系"';
      case typeWrongQuestion:
        return 'title,content,correctAnswer,analysis,subject,chapter,errorType,options,tags,examMethods,keyPoints\n'
            '函数定义域,"求f(x)=√(x-2)/(x-3)的定义域",B,根号内非负且分母不为零,数学,函数,概念错误,"A:x≥2;B:x≥2且x≠3;C:x>2;D:x>3","函数;定义域",选择题,"根式;分式"';
      case typeMotherQuestion:
        return 'title,content,correctAnswer,analysis,subject,chapter,difficulty,options,tags,examMethods,keyPoints\n'
            '二次函数最值,"求f(x)=-x²+4x-3在[0,3]上的最大值",B,配方法得f(x)=-(x-2)²+1,数学,二次函数,3,"A:0;B:1;C:3;D:4","经典;高频","选择题;解答题","配方法;对称轴;最值"';
      case typeNote:
        return 'title,content,subject,chapter,tags,color,examMethods,keyPoints\n'
            '英语时态总结,"一般现在时/过去时/将来时/进行时",英语,时态,"语法;总结",#E3F2FD,"选择题;填空题","时态结构;时间标志词"';
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
