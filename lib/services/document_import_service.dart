import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

/// 文档拆分方式
enum SplitMode {
  byMarker,   // 按标识拆分
  byParagraph, // 按段落拆分
  bySemantic, // 按语义拆分（按题目数量）
}

/// 文档导入服务
/// 支持Word、Excel、PDF等文档格式的导入
class DocumentImportService {
  /// 支持的文件类型
  static const List<String> supportedExtensions = [
    'doc', 'docx', 'xls', 'xlsx', 'pdf', 'txt', 'md'
  ];

  /// 选择并读取文档文件
  /// 返回文件内容和文件信息
  Future<DocumentImportResult?> pickAndReadDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: supportedExtensions,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final file = result.files.first;
      final extension = file.extension?.toLowerCase() ?? '';
      
      if (!supportedExtensions.contains(extension)) {
        throw Exception('不支持的文件格式: $extension');
      }

      // 读取文件内容
      String content;
      if (file.bytes != null) {
        content = await _readFileContent(file.bytes!, extension);
      } else if (file.path != null) {
        final fileObj = File(file.path!);
        final bytes = await fileObj.readAsBytes();
        content = await _readFileContent(bytes, extension);
      } else {
        throw Exception('无法读取文件内容');
      }

      return DocumentImportResult(
        fileName: file.name,
        extension: extension,
        content: content,
        size: file.size,
      );
    } catch (e) {
      throw Exception('文档导入失败: $e');
    }
  }

  /// 读取文件内容
  /// 根据文件类型使用不同的解析方式
  Future<String> _readFileContent(List<int> bytes, String extension) async {
    switch (extension) {
      case 'txt':
      case 'md':
        // 文本文件直接读取
        return utf8.decode(bytes, allowMalformed: true);
      
      case 'doc':
      case 'docx':
        // Word文档 - 返回占位符，实际解析需要额外库
        return '''[Word文档内容]

请按照以下格式整理题目：

【题目1】
题目内容：这里写题目
选项：
A. 选项A
B. 选项B
C. 选项C
D. 选项D
答案：A
解析：这里写解析

【题目2】
...
'''; 
      
      case 'xls':
      case 'xlsx':
        // Excel文档 - 返回占位符
        return '''[Excel文档内容]

请导出为CSV格式后导入，或使用以下格式：

【题目1】
题目内容：...
选项：A. ... B. ... C. ... D. ...
答案：...
解析：...
'''; 
      
      case 'pdf':
        // PDF文档 - 返回占位符
        return '''[PDF文档内容]

请复制粘贴文本内容，并按照以下格式整理：

【题目1】
题目内容：...
选项：A. ... B. ... C. ... D. ...
答案：...
解析：...
'''; 
      
      default:
        // 尝试作为文本读取
        try {
          return utf8.decode(bytes, allowMalformed: true);
        } catch (e) {
          return '[无法解析的文件内容]';
        }
    }
  }

  /// 解析文档内容为结构化数据
  /// 支持多种拆分方式
  List<Map<String, dynamic>> parseDocumentContent(
    String content, {
    String type = 'single_choice',
    SplitMode splitMode = SplitMode.byMarker,
    String? customMarker, // 自定义标识，如"【题目】"
    int? targetCount, // 目标题目数量（语义拆分用）
  }) {
    switch (splitMode) {
      case SplitMode.byMarker:
        return _parseByMarker(content, type, customMarker);
      case SplitMode.byParagraph:
        return _parseByParagraph(content, type);
      case SplitMode.bySemantic:
        return _parseBySemantic(content, type, targetCount ?? 10);
    }
  }

  /// 按标识拆分
  List<Map<String, dynamic>> _parseByMarker(
    String content, 
    String type,
    String? customMarker,
  ) {
    final questions = <Map<String, dynamic>>[];
    
    // 使用自定义标识或默认标识
    final marker = customMarker?.trim() ?? '【题目';
    
    // 分割内容
    final parts = content.split(RegExp(r'(?=' + RegExp.escape(marker) + r')'));
    
    for (var part in parts) {
      part = part.trim();
      if (part.isEmpty) continue;
      if (!part.contains(marker) && questions.isNotEmpty) continue;
      
      final question = _parseQuestionBlock(part, type);
      if (question != null) {
        questions.add(question);
      }
    }
    
    return questions;
  }

  /// 按段落拆分
  List<Map<String, dynamic>> _parseByParagraph(
    String content, 
    String type,
  ) {
    final questions = <Map<String, dynamic>>[];
    
    // 按空行分割段落
    final paragraphs = content.split(RegExp(r'\n\s*\n'));
    
    for (var paragraph in paragraphs) {
      paragraph = paragraph.trim();
      if (paragraph.isEmpty) continue;
      
      // 尝试解析每个段落为题目
      final question = _parseQuestionBlock(paragraph, type);
      if (question != null) {
        questions.add(question);
      }
    }
    
    return questions;
  }

  /// 按语义拆分（智能识别题目数量）
  List<Map<String, dynamic>> _parseBySemantic(
    String content, 
    String type,
    int targetCount,
  ) {
    // 首先尝试按标识拆分
    var questions = _parseByMarker(content, type, null);
    
    // 如果按标识拆分得到足够题目，直接返回
    if (questions.length >= targetCount) {
      return questions.take(targetCount).toList();
    }
    
    // 否则尝试按段落拆分补充
    final paragraphQuestions = _parseByParagraph(content, type);
    
    // 合并并去重
    final seenContents = <String>{};
    final result = <Map<String, dynamic>>[];
    
    for (var q in [...questions, ...paragraphQuestions]) {
      final contentKey = q['content']?.toString() ?? '';
      if (contentKey.isNotEmpty && !seenContents.contains(contentKey)) {
        seenContents.add(contentKey);
        result.add(q);
        if (result.length >= targetCount) break;
      }
    }
    
    return result;
  }

  /// 解析单个题目块
  Map<String, dynamic>? _parseQuestionBlock(String block, String type) {
    final lines = block.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return null;
    
    final question = <String, dynamic>{
      'title': '',
      'content': '',
      'type': type,
      'options': <String>[],
      'answer': '',
      'analysis': '',
    };
    
    // 提取标题（第一行或包含"题目"的行）
    var firstLine = lines.first;
    if (firstLine.contains('【') && firstLine.contains('】')) {
      final match = RegExp(r'【(.+?)】').firstMatch(firstLine);
      if (match != null) {
        question['title'] = match.group(1)?.replaceAll(RegExp(r'^题目\s*'), '') ?? '';
        // 移除标题标记，保留剩余内容
        firstLine = firstLine.replaceFirst(RegExp(r'【.+?】\s*'), '');
      }
    }
    
    // 提取题目内容
    final contentLines = <String>[];
    final optionLines = <String>[];
    String? answerLine;
    String? analysisLine;
    
    var inOptions = false;
    var inAnalysis = false;
    
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lowerLine = line.toLowerCase();
      
      // 检测答案行
      if (lowerLine.contains('答案') || lowerLine.contains('正确答案')) {
        answerLine = line;
        inOptions = false;
        continue;
      }
      
      // 检测解析行
      if (lowerLine.contains('解析') || lowerLine.contains('分析')) {
        analysisLine = line;
        inOptions = false;
        inAnalysis = true;
        continue;
      }
      
      // 检测选项开始
      if (RegExp(r'^[A-D][\.、\s]').hasMatch(line) || 
          lowerLine.contains('选项') ||
          lowerLine.startsWith('a.') ||
          lowerLine.startsWith('a、')) {
        inOptions = true;
      }
      
      if (inAnalysis) {
        // 解析内容
        if (analysisLine != null && analysisLine != line) {
          analysisLine += '\n$line';
        }
      } else if (inOptions) {
        // 选项内容
        if (RegExp(r'^[A-D][\.、\s]').hasMatch(line)) {
          optionLines.add(line);
        }
      } else {
        // 题目内容
        if (i == 0 && firstLine.isNotEmpty) {
          contentLines.add(firstLine);
        } else if (i > 0) {
          contentLines.add(line);
        }
      }
    }
    
    question['content'] = contentLines.join('\n');
    question['options'] = optionLines;
    
    // 提取答案
    if (answerLine != null) {
      final match = RegExp(r'答案[：:]\s*([A-D]+)').firstMatch(answerLine);
      question['answer'] = match?.group(1) ?? '';
    }
    
    // 提取解析
    if (analysisLine != null) {
      question['analysis'] = analysisLine.replaceFirst(RegExp(r'解析[：:]\s*'), '');
    }
    
    // 如果没有标题，使用内容的前20个字符
    if (question['title']?.toString().isEmpty ?? true) {
      final content = question['content']?.toString() ?? '';
      question['title'] = content.length > 20 ? content.substring(0, 20) + '...' : content;
    }
    
    // 验证题目有效性
    if (question['content']?.toString().isEmpty ?? true) {
      return null;
    }
    
    return question;
  }

  /// 获取支持的文件类型描述
  static String getSupportedTypesDescription() {
    return '支持格式: Word (.doc, .docx), Excel (.xls, .xlsx), PDF (.pdf), 文本 (.txt, .md)';
  }

  /// 获取拆分方式描述
  static String getSplitModeDescription(SplitMode mode) {
    switch (mode) {
      case SplitMode.byMarker:
        return '按标识拆分（如【题目1】）';
      case SplitMode.byParagraph:
        return '按段落拆分（空行分隔）';
      case SplitMode.bySemantic:
        return '智能拆分（自动识别题目）';
    }
  }

  /// 获取文档导入模板
  static String getDocumentTemplate() {
    return '''【文档导入格式模板】

请按照以下格式准备文档内容：

========== 按标识拆分格式（推荐）==========

【题目1】
题目内容：以下关于光合作用的说法正确的是？
选项：
A. 光合作用只在白天进行
B. 光合作用需要光、叶绿体和二氧化碳
C. 光合作用的产物只有氧气
D. 光合作用在动物细胞中也能进行
答案：B
解析：光合作用是绿色植物利用光能，将二氧化碳和水转化为有机物并释放氧气的过程。需要光、叶绿体和二氧化碳作为条件。

【题目2】
题目内容：...
...

========== 按段落拆分格式 ==========

以下关于光合作用的说法正确的是？
A. 光合作用只在白天进行
B. 光合作用需要光、叶绿体和二氧化碳
C. 光合作用的产物只有氧气
D. 光合作用在动物细胞中也能进行
答案：B
解析：光合作用是绿色植物利用光能...

（每道题之间用空行分隔）

========== 格式说明 ==========

1. 题目内容：写在"题目内容："后或直接写题目
2. 选项：以A、B、C、D开头，每行一个选项
3. 答案：写在"答案："后，如"答案：A"或"答案：AB"
4. 解析：写在"解析："后，可换行
5. 支持题型：单选题、多选题、判断题、填空题、简答题

导入时请选择正确的拆分方式和题型。''';
  }

  /// 获取示例题目
  static List<Map<String, dynamic>> getExampleQuestions() {
    return [
      {
        'title': '光合作用示例',
        'content': '以下关于光合作用的说法正确的是？',
        'type': 'single_choice',
        'options': [
          'A. 光合作用只在白天进行',
          'B. 光合作用需要光、叶绿体和二氧化碳',
          'C. 光合作用的产物只有氧气',
          'D. 光合作用在动物细胞中也能进行',
        ],
        'answer': 'B',
        'analysis': '光合作用是绿色植物利用光能，将二氧化碳和水转化为有机物并释放氧气的过程。',
      },
      {
        'title': '化学元素示例',
        'content': '水的化学式是____。',
        'type': 'fill_blank',
        'options': [],
        'answer': 'H₂O',
        'analysis': '水由氢元素和氧元素组成，化学式为H₂O。',
      },
    ];
  }
}

/// 文档导入结果
class DocumentImportResult {
  final String fileName;
  final String extension;
  final String content;
  final int size;

  DocumentImportResult({
    required this.fileName,
    required this.extension,
    required this.content,
    required this.size,
  });

  /// 格式化文件大小
  String get formattedSize {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}
