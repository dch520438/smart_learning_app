import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

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
        return '[Word文档内容 - 请复制粘贴文本内容到编辑器中]';
      
      case 'xls':
      case 'xlsx':
        // Excel文档 - 返回占位符
        return '[Excel文档内容 - 请导出为CSV格式后导入]';
      
      case 'pdf':
        // PDF文档 - 返回占位符
        return '[PDF文档内容 - 请复制粘贴文本内容到编辑器中]';
      
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
  /// 尝试从文档中提取题目信息
  List<Map<String, dynamic>> parseDocumentContent(
    String content, {
    String type = 'single_choice',
  }) {
    final questions = <Map<String, dynamic>>[];
    
    // 按行分割
    final lines = content.split('\n');
    Map<String, dynamic>? currentQuestion;
    List<String> currentOptions = [];
    
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      
      // 检测题目开始（以数字开头或包含"题"字）
      if (_isQuestionStart(line)) {
        // 保存上一题
        if (currentQuestion != null) {
          currentQuestion['options'] = currentOptions;
          questions.add(currentQuestion);
        }
        
        // 开始新题目
        currentQuestion = {
          'title': _extractTitle(line),
          'content': line,
          'type': type,
          'options': <String>[],
          'answer': '',
          'analysis': '',
        };
        currentOptions = [];
      }
      // 检测选项（以A、B、C、D开头）
      else if (_isOption(line)) {
        currentOptions.add(line);
      }
      // 检测答案
      else if (_isAnswer(line)) {
        if (currentQuestion != null) {
          currentQuestion['answer'] = _extractAnswer(line);
        }
      }
      // 检测解析
      else if (_isAnalysis(line)) {
        if (currentQuestion != null) {
          currentQuestion['analysis'] = _extractAnalysis(line);
        }
      }
    }
    
    // 保存最后一题
    if (currentQuestion != null) {
      currentQuestion['options'] = currentOptions;
      questions.add(currentQuestion);
    }
    
    return questions;
  }

  /// 检测是否是题目开始
  bool _isQuestionStart(String line) {
    // 以数字开头，如 "1."、"1、"、"第1题"
    final patterns = [
      RegExp(r'^\d+[\.、]'),
      RegExp(r'^第\d+题'),
      RegExp(r'^【题'),
    ];
    return patterns.any((p) => p.hasMatch(line));
  }

  /// 检测是否是选项
  bool _isOption(String line) {
    return RegExp(r'^[A-D][\.、\s]').hasMatch(line);
  }

  /// 检测是否是答案行
  bool _isAnswer(String line) {
    return line.contains('答案') || line.contains('正确答案');
  }

  /// 检测是否是解析行
  bool _isAnalysis(String line) {
    return line.contains('解析') || line.contains('分析');
  }

  /// 提取标题
  String _extractTitle(String line) {
    // 移除题号，提取标题
    return line.replaceAll(RegExp(r'^\d+[\.、]\s*'), '')
               .replaceAll(RegExp(r'^第\d+题[\.、\s]*'), '')
               .substring(0, line.length > 20 ? 20 : line.length);
  }

  /// 提取答案
  String _extractAnswer(String line) {
    // 从"答案：A"或"正确答案：B"中提取
    final match = RegExp(r'答案[：:]\s*([A-D]+)').firstMatch(line);
    return match?.group(1) ?? '';
  }

  /// 提取解析
  String _extractAnalysis(String line) {
    // 从"解析：..."中提取
    return line.replaceAll(RegExp(r'^解析[：:]\s*'), '');
  }

  /// 获取支持的文件类型描述
  static String getSupportedTypesDescription() {
    return '支持格式: Word (.doc, .docx), Excel (.xls, .xlsx), PDF (.pdf), 文本 (.txt, .md)';
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
