import 'dart:io';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// OCR 识别服务
/// 使用 Google ML Kit 的 TextRecognizer 进行文字识别
class OcrService {
  // 单例模式
  static final OcrService _instance = OcrService._internal();
  factory OcrService() => _instance;
  OcrService._internal();

  TextRecognizer? _textRecognizer;
  bool _isInitialized = false;

  /// 初始化识别器
  Future<void> _ensureInitialized() async {
    if (!_isInitialized || _textRecognizer == null) {
      _textRecognizer = TextRecognizer(script: TextRecognitionScript.chinese);
      _isInitialized = true;
    }
  }

  /// 识别图片中的文字
  /// [imagePath] 图片文件路径
  /// 返回识别出的文字内容
  Future<OcrResult> recognizeImage(String imagePath) async {
    try {
      // 检查文件是否存在
      final file = File(imagePath);
      if (!await file.exists()) {
        return OcrResult(
          text: '',
          success: false,
          errorMessage: '图片文件不存在: $imagePath',
        );
      }

      // 检查文件大小（限制20MB）
      final fileSize = await file.length();
      if (fileSize > 20 * 1024 * 1024) {
        return OcrResult(
          text: '',
          success: false,
          errorMessage: '图片文件过大，请选择小于20MB的图片',
        );
      }

      // 初始化识别器
      await _ensureInitialized();

      // 创建输入图片
      final inputImage = InputImage.fromFilePath(imagePath);

      // 执行识别
      final RecognizedText recognizedText =
          await _textRecognizer!.processImage(inputImage);

      // 提取所有文本块
      final textBlocks = <OcrTextBlock>[];
      for (final block in recognizedText.blocks) {
        final lines = <OcrTextLine>[];
        for (final line in block.lines) {
          final elements = <OcrTextElement>[];
          for (final element in line.elements) {
            elements.add(OcrTextElement(
              text: element.text,
              confidence: element.confidence ?? 0.0,
              boundingBox: element.boundingBox,
            ));
          }
          lines.add(OcrTextLine(
            text: line.text,
            confidence: line.confidence ?? 0.0,
            boundingBox: line.boundingBox,
            elements: elements,
          ));
        }
        final blockConfidence = lines.isEmpty
            ? 0.0
            : lines.map((l) => l.confidence).reduce((a, b) => a + b) / lines.length;
        textBlocks.add(OcrTextBlock(
          text: block.text,
          confidence: blockConfidence,
          boundingBox: block.boundingBox,
          lines: lines,
          language: block.recognizedLanguages.isNotEmpty
              ? block.recognizedLanguages.first
              : null,
        ));
      }

      final fullText = recognizedText.text;

      if (fullText.trim().isEmpty) {
        return OcrResult(
          text: '',
          success: true,
          textBlocks: textBlocks,
          errorMessage: '未识别到文字内容',
        );
      }

      return OcrResult(
        text: fullText,
        success: true,
        textBlocks: textBlocks,
      );
    } on PlatformException catch (e) {
      return OcrResult(
        text: '',
        success: false,
        errorMessage: '平台异常: ${e.message}',
      );
    } catch (e) {
      return OcrResult(
        text: '',
        success: false,
        errorMessage: '识别失败: $e',
      );
    }
  }

  /// 识别图片中的文字（仅返回纯文本）
  /// [imagePath] 图片文件路径
  /// 返回识别出的纯文字内容，失败返回空字符串
  Future<String> recognizeText(String imagePath) async {
    final result = await recognizeImage(imagePath);
    return result.text;
  }

  /// 批量识别多张图片
  /// [imagePaths] 图片路径列表
  /// 返回每张图片的识别结果列表
  Future<List<OcrResult>> recognizeImages(List<String> imagePaths) async {
    final results = <OcrResult>[];
    for (final path in imagePaths) {
      final result = await recognizeImage(path);
      results.add(result);
    }
    return results;
  }

  /// 释放资源
  void dispose() {
    _textRecognizer?.close();
    _textRecognizer = null;
    _isInitialized = false;
  }
}

/// OCR 识别结果
class OcrResult {
  /// 识别出的完整文本
  final String text;

  /// 是否识别成功
  final bool success;

  /// 错误信息
  final String? errorMessage;

  /// 文本块列表（包含位置信息）
  final List<OcrTextBlock>? textBlocks;

  const OcrResult({
    required this.text,
    required this.success,
    this.errorMessage,
    this.textBlocks,
  });

  /// 获取识别出的文本行数
  int get lineCount {
    if (textBlocks == null) return 0;
    return textBlocks!.fold<int>(
      0,
      (sum, block) => sum + block.lines.length,
    );
  }

  /// 获取平均置信度
  double get averageConfidence {
    if (textBlocks == null || textBlocks!.isEmpty) return 0.0;
    double totalConfidence = 0;
    int totalCount = 0;
    for (final block in textBlocks!) {
      for (final line in block.lines) {
        totalConfidence += line.confidence;
        totalCount++;
      }
    }
    return totalCount > 0 ? totalConfidence / totalCount : 0.0;
  }

  @override
  String toString() {
    return 'OcrResult(success: $success, textLength: ${text.length}, '
        'lineCount: $lineCount, errorMessage: $errorMessage)';
  }
}

/// OCR 文本块
class OcrTextBlock {
  /// 块文本
  final String text;

  /// 置信度 (0.0 - 1.0)
  final double confidence;

  /// 边界框
  final Rect? boundingBox;

  /// 文本行列表
  final List<OcrTextLine> lines;

  /// 识别语言
  final String? language;

  const OcrTextBlock({
    required this.text,
    required this.confidence,
    this.boundingBox,
    required this.lines,
    this.language,
  });
}

/// OCR 文本行
class OcrTextLine {
  /// 行文本
  final String text;

  /// 置信度 (0.0 - 1.0)
  final double confidence;

  /// 边界框
  final Rect? boundingBox;

  /// 文本元素列表
  final List<OcrTextElement> elements;

  const OcrTextLine({
    required this.text,
    required this.confidence,
    this.boundingBox,
    required this.elements,
  });
}

/// OCR 文本元素（单词级别）
class OcrTextElement {
  /// 元素文本
  final String text;

  /// 置信度 (0.0 - 1.0)
  final double confidence;

  /// 边界框
  final Rect? boundingBox;

  const OcrTextElement({
    required this.text,
    required this.confidence,
    this.boundingBox,
  });
}
