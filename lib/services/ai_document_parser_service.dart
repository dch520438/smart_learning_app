import 'dart:convert';
import 'dart:io';
import 'ai_config_service.dart';
import 'ocr_service.dart';
import '../utils/constants.dart' show QuestionType;

// ============================================================
// AI 文档解析服务 - 自动拆分试卷/文档题目
// ============================================================

/// 题目类型扩展（兼容 constants.dart 中的 QuestionType）
extension QuestionTypeParserExtension on QuestionType {
  String get parseValue {
    switch (this) {
      case QuestionType.singleChoice:
        return 'single_choice';
      case QuestionType.multipleChoice:
        return 'multi_choice';
      case QuestionType.fillBlank:
        return 'fill_blank';
      case QuestionType.shortAnswer:
        return 'short_answer';
      case QuestionType.trueFalse:
        return 'true_false';
      case QuestionType.proof:
        return 'proof';
      case QuestionType.essay:
        return 'essay';
    }
  }

  String get parseDisplayName {
    switch (this) {
      case QuestionType.singleChoice:
        return '单选题';
      case QuestionType.multipleChoice:
        return '多选题';
      case QuestionType.fillBlank:
        return '填空题';
      case QuestionType.shortAnswer:
        return '简答题';
      case QuestionType.trueFalse:
        return '判断题';
      case QuestionType.proof:
        return '证明题';
      case QuestionType.essay:
        return '论述题';
    }
  }

  static QuestionType parseFromString(String? value) {
    switch (value) {
      case 'single_choice':
        return QuestionType.singleChoice;
      case 'multi_choice':
        return QuestionType.multipleChoice;
      case 'fill_blank':
        return QuestionType.fillBlank;
      case 'short_answer':
        return QuestionType.shortAnswer;
      case 'true_false':
        return QuestionType.trueFalse;
      case 'proof':
        return QuestionType.proof;
      case 'essay':
        return QuestionType.essay;
      default:
        return QuestionType.singleChoice;
    }
  }
}

/// 解析后的题目数据
class ParsedQuestion {
  final int number;
  final QuestionType type;
  final String content;
  final List<String>? options;
  final String? answer;
  final String? analysis;
  final String? subject;
  final String? knowledgePoint;
  final String? chapter;
  final int? difficulty; // 1-5

  ParsedQuestion({
    required this.number,
    required this.type,
    required this.content,
    this.options,
    this.answer,
    this.analysis,
    this.subject,
    this.knowledgePoint,
    this.chapter,
    this.difficulty,
  });

  /// 从JSON创建
  factory ParsedQuestion.fromJson(Map<String, dynamic> json) {
    return ParsedQuestion(
      number: json['number'] as int? ?? 1,
      type: QuestionTypeExtension.fromString(json['type'] as String?),
      content: json['content'] as String? ?? '',
      options: (json['options'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      answer: json['answer'] as String?,
      analysis: json['analysis'] as String?,
      subject: json['subject'] as String?,
      knowledgePoint: json['knowledge_point'] as String? ??
          json['knowledgePoint'] as String?,
      chapter: json['chapter'] as String?,
      difficulty: json['difficulty'] as int?,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'type': type.value,
      'content': content,
      'options': options,
      'answer': answer,
      'analysis': analysis,
      'subject': subject,
      'knowledge_point': knowledgePoint,
      'chapter': chapter,
      'difficulty': difficulty,
    };
  }

  /// 转换为错题格式
  Map<String, dynamic> toWrongQuestionJson() {
    // 转换选项格式
    final formattedOptions = options?.asMap().entries.map((entry) {
      final index = entry.key;
      final option = entry.value;
      // 如果选项已经包含A. B. C. D.前缀，则保留，否则添加
      final label = String.fromCharCode(65 + index); // A, B, C, D...
      final text = option.startsWith(RegExp(r'^[A-D][\.．、\s]'))
          ? option
          : '$label. $option';
      return {
        'label': label,
        'text': text,
      };
    }).toList();

    return {
      'title': '第$number题',
      'content': content,
      'options': formattedOptions ?? [],
      'correctAnswer': answer ?? '',
      'analysis': analysis ?? '',
      'subject': subject ?? '未分类',
      'chapter': chapter,
      'errorType': '知识盲区',
      'errorCount': 1,
      'isResolved': false,
      'examMethods': [],
      'keyPoints': knowledgePoint != null ? [knowledgePoint!] : [],
      'tags': [],
      'attachments': [],
    };
  }

  /// 转换为母题格式
  Map<String, dynamic> toMotherQuestionJson() {
    // 转换选项格式
    final formattedOptions = options?.asMap().entries.map((entry) {
      final index = entry.key;
      final option = entry.value;
      final label = String.fromCharCode(65 + index);
      final text = option.startsWith(RegExp(r'^[A-D][\.．、\s]'))
          ? option
          : '$label. $option';
      return {
        'label': label,
        'text': text,
      };
    }).toList();

    return {
      'title': '第$number题',
      'content': content,
      'options': formattedOptions ?? [],
      'correctAnswer': answer ?? '',
      'analysis': analysis ?? '',
      'subject': subject ?? '未分类',
      'chapter': chapter,
      'difficulty': difficulty ?? 1,
      'relatedQuestions': [],
      'tags': knowledgePoint != null ? [knowledgePoint!] : [],
      'attachments': [],
    };
  }

  /// 复制并修改部分字段
  ParsedQuestion copyWith({
    int? number,
    QuestionType? type,
    String? content,
    List<String>? options,
    String? answer,
    String? analysis,
    String? subject,
    String? knowledgePoint,
    String? chapter,
    int? difficulty,
  }) {
    return ParsedQuestion(
      number: number ?? this.number,
      type: type ?? this.type,
      content: content ?? this.content,
      options: options ?? this.options,
      answer: answer ?? this.answer,
      analysis: analysis ?? this.analysis,
      subject: subject ?? this.subject,
      knowledgePoint: knowledgePoint ?? this.knowledgePoint,
      chapter: chapter ?? this.chapter,
      difficulty: difficulty ?? this.difficulty,
    );
  }

  @override
  String toString() {
    return 'ParsedQuestion(number: $number, type: ${type.displayName}, '
        'content: ${content.substring(0, content.length > 30 ? 30 : content.length)}..., '
        'subject: $subject)';
  }
}

/// 解析结果
class ParseResult {
  final bool success;
  final List<ParsedQuestion> questions;
  final String? errorMessage;
  final String? rawText; // OCR识别的原始文本

  ParseResult({
    required this.success,
    required this.questions,
    this.errorMessage,
    this.rawText,
  });

  factory ParseResult.success(List<ParsedQuestion> questions, {String? rawText}) {
    return ParseResult(
      success: true,
      questions: questions,
      rawText: rawText,
    );
  }

  factory ParseResult.error(String message, {String? rawText}) {
    return ParseResult(
      success: false,
      questions: [],
      errorMessage: message,
      rawText: rawText,
    );
  }
}

/// AI文档解析服务
class AIDocumentParserService {
  // 单例模式
  static final AIDocumentParserService _instance = AIDocumentParserService._internal();
  factory AIDocumentParserService() => _instance;
  AIDocumentParserService._internal();

  final AIService _aiService = AIService();
  final OcrService _ocrService = OcrService();

  // ============================================================
  // 文档解析方法
  // ============================================================

  /// 解析试卷/文档图片，提取题目
  /// [imagePath] 图片文件路径
  /// 返回解析结果
  Future<ParseResult> parseDocumentFromImage(String imagePath) async {
    try {
      // 1. OCR识别文字
      final ocrResult = await _ocrService.recognizeImage(imagePath);

      if (!ocrResult.success) {
        return ParseResult.error(
          ocrResult.errorMessage ?? 'OCR识别失败',
          rawText: ocrResult.text,
        );
      }

      if (ocrResult.text.trim().isEmpty) {
        return ParseResult.error(
          '未识别到文字内容，请检查图片清晰度',
          rawText: ocrResult.text,
        );
      }

      // 2. AI拆分题目
      final questions = await _parseQuestionsWithAI(ocrResult.text);

      return ParseResult.success(questions, rawText: ocrResult.text);
    } catch (e) {
      return ParseResult.error('解析失败: $e');
    }
  }

  /// 直接解析文本内容
  /// [text] 文本内容
  /// 返回解析结果
  Future<ParseResult> parseDocumentFromText(String text) async {
    try {
      if (text.trim().isEmpty) {
        return ParseResult.error('文本内容为空');
      }

      final questions = await _parseQuestionsWithAI(text);
      return ParseResult.success(questions, rawText: text);
    } catch (e) {
      return ParseResult.error('解析失败: $e', rawText: text);
    }
  }

  /// 批量解析多张图片
  /// [imagePaths] 图片路径列表
  /// 返回每张图片的解析结果列表
  Future<List<ParseResult>> parseDocumentsFromImages(List<String> imagePaths) async {
    final results = <ParseResult>[];
    for (final path in imagePaths) {
      final result = await parseDocumentFromImage(path);
      results.add(result);
    }
    return results;
  }

  // ============================================================
  // AI解析核心方法
  // ============================================================

  /// 使用AI拆分题目
  Future<List<ParsedQuestion>> _parseQuestionsWithAI(String text) async {
    final prompt = '''
请将以下试卷/练习内容拆分为独立的题目，并以JSON格式返回。

要求：
1. 识别每道题的题号、题干、选项（如有）、答案、解析
2. 判断题目类型：single_choice(单选)、multi_choice(多选)、fill_blank(填空)、short_answer(简答)、true_false(判断)
3. 提取所属学科和知识点（如可识别）
4. 题号从1开始连续编号
5. 如果内容中包含答案和解析，请一并提取

返回格式（JSON）：
{
  "questions": [
    {
      "number": 1,
      "type": "single_choice",
      "content": "题目内容",
      "options": ["选项1", "选项2", "选项3", "选项4"],
      "answer": "A",
      "analysis": "解析内容",
      "subject": "数学",
      "knowledge_point": "相关知识点",
      "chapter": "章节名称",
      "difficulty": 3
    }
  ]
}

注意：
- 如果某字段无法识别，可以省略或设为null
- options字段仅选择题需要，其他类型可省略
- difficulty为1-5的整数，1最简单，5最难

待拆分内容：
$text
''';  
    
    final response = await _aiService.chat(prompt);
    return _parseAIResponse(response);
  }

  /// 解析AI返回的JSON
  List<ParsedQuestion> _parseAIResponse(String response) {
    try {
      // 提取JSON
      final jsonStr = _extractJson(response);
      final data = json.decode(jsonStr) as Map<String, dynamic>;

      // 获取题目列表
      final questionsJson = data['questions'] as List<dynamic>?;
      if (questionsJson == null || questionsJson.isEmpty) {
        throw Exception('未解析到题目');
      }

      // 转换为ParsedQuestion列表
      return questionsJson.map((q) {
        if (q is Map<String, dynamic>) {
          return ParsedQuestion.fromJson(q);
        }
        throw Exception('题目格式错误');
      }).toList();
    } catch (e) {
      throw Exception('解析AI响应失败: $e');
    }
  }

  /// 从响应中提取JSON字符串
  String _extractJson(String response) {
    // 尝试找到JSON对象的开始和结束
    var start = response.indexOf('{');
    var end = response.lastIndexOf('}');

    if (start != -1 && end != -1 && end > start) {
      return response.substring(start, end + 1);
    }

    throw FormatException('无法从响应中提取JSON: $response');
  }

  // ============================================================
  // 辅助方法
  // ============================================================

  /// 智能识别学科
  /// 根据题目内容尝试识别所属学科
  String? detectSubject(String content) {
    final lowerContent = content.toLowerCase();
    
    // 数学关键词
    final mathKeywords = [
      '函数', '方程', '几何', '代数', '微积分', '概率', '统计',
      '三角形', '圆', '数列', '向量', '矩阵', '导数', '积分',
      'equation', 'function', 'geometry', 'algebra', 'calculus'
    ];
    
    // 物理关键词
    final physicsKeywords = [
      '力', '速度', '加速度', '能量', '功', '功率', '电场', '磁场',
      '光', '声', '热', '牛顿', '欧姆', '焦耳', 'force', 'velocity'
    ];
    
    // 化学关键词
    final chemistryKeywords = [
      '化学', '元素', '化合物', '反应', '分子', '原子', '离子',
      '氧化', '还原', '酸碱', '盐', '有机', '无机', 'chemistry'
    ];
    
    // 生物关键词
    final biologyKeywords = [
      '生物', '细胞', '基因', 'DNA', '蛋白质', '酶', '代谢',
      '植物', '动物', '人体', '生态', '进化', 'biology'
    ];
    
    // 英语关键词
    final englishKeywords = [
      'grammar', 'vocabulary', 'reading', 'listening', 'writing',
      'tense', 'passive', 'clause', 'article', 'preposition'
    ];

    int mathCount = mathKeywords.where((k) => lowerContent.contains(k)).length;
    int physicsCount = physicsKeywords.where((k) => lowerContent.contains(k)).length;
    int chemistryCount = chemistryKeywords.where((k) => lowerContent.contains(k)).length;
    int biologyCount = biologyKeywords.where((k) => lowerContent.contains(k)).length;
    int englishCount = englishKeywords.where((k) => lowerContent.contains(k)).length;

    final counts = {
      '数学': mathCount,
      '物理': physicsCount,
      '化学': chemistryCount,
      '生物': biologyCount,
      '英语': englishCount,
    };

    final maxEntry = counts.entries.reduce((a, b) => a.value > b.value ? a : b);
    
    if (maxEntry.value > 0) {
      return maxEntry.key;
    }
    
    return null;
  }

  /// 释放资源
  void dispose() {
    _ocrService.dispose();
  }
}

// ============================================================
// 录入目标枚举
// ============================================================

/// 录入目标类型
enum ImportTarget {
  wrongQuestionBook,  // 错题本
  motherQuestionBank, // 母题库
}

extension ImportTargetExtension on ImportTarget {
  String get displayName {
    switch (this) {
      case ImportTarget.wrongQuestionBook:
        return '错题本';
      case ImportTarget.motherQuestionBank:
        return '母题库';
    }
  }
}
