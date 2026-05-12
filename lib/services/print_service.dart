import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/helpers.dart';

/// 打印内容类型枚举
enum PrintContentType {
  knowledgePoint,
  note,
  wrongQuestion,
  motherQuestion,
  mustRemember,
  studySuggestion, // 学习建议
}

/// 打印选项枚举
enum PrintOption {
  /// 直接打印（使用系统打印对话框）
  print,

  /// 保存PDF文件
  savePdf,

  /// 打印预览
  preview,
}

/// 打印内容项模型
class PrintContentItem {
  final PrintContentType type;
  final String title;
  final String content;
  final String? subject;
  final String? category;
  final String? tags;
  final int? difficulty;
  final int? masteryLevel;
  final String? examMethod;
  final String? keyPoint;
  final String? createdAt;
  final Map<String, String> additionalMetadata;

  PrintContentItem({
    required this.type,
    required this.title,
    required this.content,
    this.subject,
    this.category,
    this.tags,
    this.difficulty,
    this.masteryLevel,
    this.examMethod,
    this.keyPoint,
    this.createdAt,
    this.additionalMetadata = const {},
  });

  String get typeLabel {
    switch (type) {
      case PrintContentType.knowledgePoint:
        return '知识点';
      case PrintContentType.note:
        return '笔记';
      case PrintContentType.wrongQuestion:
        return '错题';
      case PrintContentType.motherQuestion:
        return '母题';
      case PrintContentType.mustRemember:
        return '必背必记';
      case PrintContentType.studySuggestion:
        return '学习建议';
    }
  }

  Color get typeColor {
    switch (type) {
      case PrintContentType.knowledgePoint:
        return Colors.blue;
      case PrintContentType.note:
        return Colors.green;
      case PrintContentType.wrongQuestion:
        return Colors.red;
      case PrintContentType.motherQuestion:
        return Colors.purple;
      case PrintContentType.mustRemember:
        return Colors.orange;
      case PrintContentType.studySuggestion:
        return Colors.teal;
    }
  }
}

/// 打印结果
class PrintResult {
  final bool success;
  final String? filePath;
  final String? errorMessage;

  const PrintResult({
    required this.success,
    this.filePath,
    this.errorMessage,
  });
}

/// 打印服务类
/// 用于生成PDF并打印各类型内容
class PrintService {
  /// 日志输出
  static void _log(String message) {
    // ignore: avoid_print
    print('[PrintService] $message');
  }

  // 缓存中文字体
  static pw.Font? _chineseFont;
  static pw.Font? _chineseFontBold;

  /// 加载中文字体
  /// 优先使用系统已安装的中文字体，避免加载外部 TTF 文件导致的错误
  static Future<pw.Font> _loadChineseFont() async {
    if (_chineseFont != null) return _chineseFont!;

    try {
      if (Platform.isLinux) {
        // Linux 平台：尝试加载系统已安装的中文字体
        final systemFontPaths = [
          '/usr/share/fonts/truetype/wqy/wqy-microhei.ttc',  // 文泉驿微米黑
          '/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc',    // 文泉驿正黑
          '/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc',  // Noto Sans CJK
          '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
          '/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc',
        ];

        for (final fontPath in systemFontPaths) {
          try {
            final file = File(fontPath);
            if (await file.exists()) {
              _log('加载系统字体: $fontPath');
              final fontData = await file.readAsBytes();
              _chineseFont = pw.Font.ttf(ByteData.sublistView(Uint8List.fromList(fontData)));
              return _chineseFont!;
            }
          } catch (e) {
            _log('加载字体 $fontPath 失败: $e');
          }
        }
      }
    } catch (e) {
      _log('尝试加载系统字体失败: $e');
    }

    // 回退：使用 pdf 包内置字体（不支持中文，但不会报错）
    _log('使用 pdf 包内置 Helvetica 字体（中文可能显示为方框）');
    _chineseFont = pw.Font.helvetica();
    return _chineseFont!;
  }

  /// 加载中文字体（粗体）
  static Future<pw.Font> _loadChineseFontBold() async {
    if (_chineseFontBold != null) return _chineseFontBold!;

    try {
      if (Platform.isLinux) {
        // Linux 平台：尝试加载系统已安装的粗体中文字体
        final systemFontPaths = [
          '/usr/share/fonts/truetype/wqy/wqy-microhei.ttc',  // 文泉驿微米黑（包含粗体）
          '/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc',    // 文泉驿正黑
          '/usr/share/fonts/truetype/noto/NotoSansCJK-Bold.ttc',  // Noto Sans CJK Bold
          '/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc',
          '/usr/share/fonts/noto-cjk/NotoSansCJK-Bold.ttc',
        ];

        for (final fontPath in systemFontPaths) {
          try {
            final file = File(fontPath);
            if (await file.exists()) {
              _log('加载系统粗体字体: $fontPath');
              final fontData = await file.readAsBytes();
              _chineseFontBold = pw.Font.ttf(ByteData.sublistView(Uint8List.fromList(fontData)));
              return _chineseFontBold!;
            }
          } catch (e) {
            _log('加载字体 $fontPath 失败: $e');
          }
        }
      }
    } catch (e) {
      _log('尝试加载系统粗体字体失败: $e');
    }

    // 回退：使用 pdf 包内置粗体字体
    _log('使用 pdf 包内置 Helvetica Bold 字体');
    _chineseFontBold = pw.Font.helveticaBold();
    return _chineseFontBold!;
  }

  /// 获取支持中文的文本样式
  static Future<pw.TextStyle> _getChineseTextStyle({
    double fontSize = 12,
    pw.FontWeight fontWeight = pw.FontWeight.normal,
    PdfColor? color,
    double lineSpacing = 1.5,
  }) async {
    final font = await _loadChineseFont();
    return pw.TextStyle(
      font: font,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      lineSpacing: lineSpacing,
    );
  }

  /// 检查打印功能是否可用
  static Future<bool> isPrintingAvailable() async {
    try {
      if (Platform.isLinux) {
        // 检查系统是否有打印命令
        try {
          final result = await Process.run('which', ['lp']);
          if (result.exitCode == 0) {
            _log('Linux平台检测到系统打印命令: lp');
            return true;
          }
        } catch (_) {}
        // 如果没有lp命令，也返回true，使用PDF预览方式
        return true;
      }
      return true;
    } catch (e) {
      _log('检测打印功能可用性失败: $e');
      return false;
    }
  }

  /// 显示打印选项对话框
  /// 返回用户选择的打印方式
  static Future<PrintOption?> showPrintOptionsDialog(
    BuildContext context, {
    String title = '选择打印方式',
    bool showDirectPrint = true,
    bool showSavePdf = true,
    bool showPreview = true,
  }) async {
    // 默认选项（根据平台不同）
    final options = <PrintOption>[];

    // 非Linux平台支持直接打印
    if (!Platform.isLinux) {
      if (showDirectPrint) options.add(PrintOption.print);
    } else {
      // Linux平台如果有lp命令，支持直接打印
      if (showDirectPrint) {
        try {
          final result = await Process.run('which', ['lp']);
          if (result.exitCode == 0) {
            options.add(PrintOption.print);
          }
        } catch (_) {}
      }
    }

    if (showSavePdf) options.add(PrintOption.savePdf);
    if (showPreview) options.add(PrintOption.preview);

    if (options.isEmpty) {
      options.add(PrintOption.savePdf);
    }

    // 如果只有一个选项，直接返回
    if (options.length == 1) {
      return options.first;
    }

    // 显示选择对话框
    return await showDialog<PrintOption>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((option) {
            IconData icon;
            String label;
            String description;

            switch (option) {
              case PrintOption.print:
                icon = Icons.print;
                label = '直接打印';
                description = Platform.isLinux
                    ? '使用系统打印命令打印'
                    : '使用系统打印对话框打印';
                break;
              case PrintOption.savePdf:
                icon = Icons.save_alt;
                label = '保存PDF';
                description = '将内容保存为PDF文件';
                break;
              case PrintOption.preview:
                icon = Icons.preview;
                label = '打印预览';
                description = '预览后选择打印或分享';
                break;
            }

            return ListTile(
              leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
              title: Text(label),
              subtitle: Text(description, style: const TextStyle(fontSize: 12)),
              onTap: () => Navigator.pop(context, option),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  /// 使用系统打印命令打印PDF（Linux平台）
  static Future<PrintResult> _printWithSystemCommand(
    Uint8List pdfBytes,
    String fileName,
  ) async {
    _log('使用系统打印命令打印...');

    File? tempFile;
    try {
      // 创建临时文件
      final tempDir = await getTemporaryDirectory();
      final sanitizedFileName = fileName.replaceAll(RegExp(r'[^\w\-\.]'), '_');
      tempFile = File('${tempDir.path}/$sanitizedFileName.pdf');
      await tempFile.writeAsBytes(pdfBytes);

      _log('临时文件: ${tempFile.path}');

      // 首先检查 lp 命令是否可用
      final whichResult = await Process.run('which', ['lp']);
      if (whichResult.exitCode != 0) {
        _log('lp 命令不可用，尝试使用备用方案...');
        // 使用系统默认应用打开 PDF
        return await _openPdfWithDefaultApp(tempFile.path);
      }

      // 尝试使用 lp 命令打印
      // lp 是CUPS打印系统的标准命令
      final result = await Process.run('lp', ['-d', 'any', tempFile.path]);

      if (result.exitCode == 0) {
        _log('打印任务已提交: ${result.stdout}');

        // 清理临时文件（延迟删除，确保打印任务已接收）
        Future.delayed(const Duration(seconds: 30), () async {
          try {
            if (await tempFile!.exists()) {
              await tempFile.delete();
              _log('临时文件已清理');
            }
          } catch (_) {}
        });

        return const PrintResult(success: true);
      } else {
        final error = result.stderr.toString();
        _log('lp 命令失败: $error，尝试备用方案...');
        // 尝试使用备用方案
        return await _openPdfWithDefaultApp(tempFile.path);
      }
    } catch (e) {
      _log('系统打印失败: $e');
      // 如果临时文件存在，尝试用默认应用打开
      if (tempFile != null && await tempFile.exists()) {
        return await _openPdfWithDefaultApp(tempFile.path);
      }
      return PrintResult(
        success: false,
        errorMessage: '系统打印失败: $e',
      );
    }
  }

  /// 使用系统默认应用打开 PDF（备用方案）
  static Future<PrintResult> _openPdfWithDefaultApp(String pdfPath) async {
    _log('使用系统默认应用打开 PDF...');

    try {
      // 尝试使用 xdg-open（大多数 Linux 桌面环境支持）
      final result = await Process.run('xdg-open', [pdfPath]);

      if (result.exitCode == 0) {
        _log('已使用默认应用打开 PDF: $pdfPath');
        return PrintResult(
          success: true,
          filePath: pdfPath,
        );
      }
    } catch (e) {
      _log('xdg-open 失败: $e');
    }

    // 尝试使用 evince（GNOME 文档查看器）
    try {
      final result = await Process.run('evince', [pdfPath]);
      if (result.exitCode == 0 || result.exitCode == null) {
        _log('已使用 evince 打开 PDF');
        return PrintResult(
          success: true,
          filePath: pdfPath,
        );
      }
    } catch (e) {
      _log('evince 失败: $e');
    }

    // 尝试使用 okular（KDE 文档查看器）
    try {
      final result = await Process.run('okular', [pdfPath]);
      if (result.exitCode == 0 || result.exitCode == null) {
        _log('已使用 okular 打开 PDF');
        return PrintResult(
          success: true,
          filePath: pdfPath,
        );
      }
    } catch (e) {
      _log('okular 失败: $e');
    }

    // 尝试使用 firefox/chromium 浏览器打开
    try {
      final result = await Process.run('firefox', [pdfPath]);
      if (result.exitCode == 0 || result.exitCode == null) {
        _log('已使用 firefox 打开 PDF');
        return PrintResult(
          success: true,
          filePath: pdfPath,
        );
      }
    } catch (e) {
      _log('firefox 失败: $e');
    }

    return PrintResult(
      success: false,
      errorMessage: '无法打开 PDF，请手动打开文件: $pdfPath',
      filePath: pdfPath,
    );
  }

  /// 打印知识点详情
  static Future<PrintResult> printKnowledgePoint({
    required BuildContext context,
    required String title,
    required String content,
    String? subject,
    String? category,
    String? tags,
    int? difficulty,
    int? masteryLevel,
  }) async {
    return await _printContent(
      context: context,
      title: title,
      content: content,
      type: '知识点',
      metadata: {
        if (subject != null) '学科': subject,
        if (category != null) '分类': category,
        if (tags != null && tags.isNotEmpty) '标签': tags,
        if (difficulty != null) '难度': _getDifficultyLabel(difficulty),
        if (masteryLevel != null) '掌握度': '$masteryLevel%',
      },
    );
  }

  /// 打印笔记详情
  static Future<PrintResult> printNote({
    required BuildContext context,
    required String title,
    required String content,
    String? subject,
    String? tags,
    String? createdAt,
  }) async {
    return await _printContent(
      context: context,
      title: title,
      content: content,
      type: '笔记',
      metadata: {
        if (subject != null) '学科': subject,
        if (tags != null && tags.isNotEmpty) '标签': tags,
        if (createdAt != null) '创建时间': createdAt,
      },
    );
  }

  /// 打印错题详情
  static Future<PrintResult> printWrongQuestion({
    required BuildContext context,
    required String question,
    String? options,
    String? correctAnswer,
    String? myAnswer,
    String? analysis,
    String? subject,
    String? errorType,
    String? createdAt,
    bool? isMastered,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('【题目】');
    buffer.writeln(question);
    buffer.writeln();
    if (options != null && options.isNotEmpty) {
      buffer.writeln('【选项】');
      buffer.writeln(options);
      buffer.writeln();
    }
    if (correctAnswer != null) {
      buffer.writeln('【正确答案】');
      buffer.writeln(correctAnswer);
      buffer.writeln();
    }
    if (myAnswer != null) {
      buffer.writeln('【我的答案】');
      buffer.writeln(myAnswer);
      buffer.writeln();
    }
    if (analysis != null && analysis.isNotEmpty) {
      buffer.writeln('【解析】');
      buffer.writeln(analysis);
    }

    return await _printContent(
      context: context,
      title: '错题详情',
      content: buffer.toString(),
      type: '错题',
      metadata: {
        if (subject != null) '学科': subject,
        if (errorType != null) '错误类型': errorType,
        if (isMastered != null) '状态': isMastered ? '已掌握' : '未掌握',
        if (createdAt != null) '添加时间': createdAt,
      },
    );
  }

  /// 打印母题详情
  static Future<PrintResult> printMotherQuestion({
    required BuildContext context,
    required String title,
    required String question,
    String? options,
    String? correctAnswer,
    String? analysis,
    String? subject,
    int? difficulty,
    String? tags,
    String? createdAt,
    int? masteryLevel,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('【标题】');
    buffer.writeln(title);
    buffer.writeln();
    buffer.writeln('【题目】');
    buffer.writeln(question);
    buffer.writeln();
    if (options != null && options.isNotEmpty) {
      buffer.writeln('【选项】');
      buffer.writeln(options);
      buffer.writeln();
    }
    if (correctAnswer != null) {
      buffer.writeln('【正确答案】');
      buffer.writeln(correctAnswer);
      buffer.writeln();
    }
    if (analysis != null && analysis.isNotEmpty) {
      buffer.writeln('【解析】');
      buffer.writeln(analysis);
    }

    return await _printContent(
      context: context,
      title: '母题详情',
      content: buffer.toString(),
      type: '母题',
      metadata: {
        if (subject != null) '学科': subject,
        if (difficulty != null) '难度': _getDifficultyLabel(difficulty),
        if (tags != null && tags.isNotEmpty) '标签': tags,
        if (masteryLevel != null) '掌握度': '$masteryLevel%',
        if (createdAt != null) '创建时间': createdAt,
      },
    );
  }

  /// 打印必背必记详情
  static Future<PrintResult> printMustRemember({
    required BuildContext context,
    required String title,
    required String content,
    String? subject,
    String? category,
    int? memoryLevel,
    int? reviewCount,
    String? nextReviewTime,
    bool? isMastered,
    String? createdAt,
  }) async {
    return await _printContent(
      context: context,
      title: title,
      content: content,
      type: '必背必记',
      metadata: {
        if (subject != null) '学科': subject,
        if (category != null) '分类': category,
        if (memoryLevel != null) '记忆程度': '$memoryLevel%',
        if (reviewCount != null) '复习次数': '$reviewCount次',
        if (nextReviewTime != null) '下次复习': nextReviewTime,
        if (isMastered != null) '状态': isMastered ? '已掌握' : '学习中',
        if (createdAt != null) '创建时间': createdAt,
      },
    );
  }

  /// 打印试卷
  static Future<PrintResult> printExamPaper({
    required BuildContext context,
    required String paperName,
    required String subject,
    String? examDate,
    required int totalScore,
    int? obtainedScore,
    String? questions,
    String? notes,
  }) async {
    final content = StringBuffer();
    content.writeln('总分: $totalScore');
    if (obtainedScore != null) {
      content.writeln('得分: $obtainedScore');
      final rate = totalScore > 0 ? (obtainedScore / totalScore * 100).toStringAsFixed(1) : '0.0';
      content.writeln('得分率: $rate%');
    }
    if (questions != null && questions.isNotEmpty) {
      content.writeln('\n题目:\n$questions');
    }
    if (notes != null && notes.isNotEmpty) {
      content.writeln('\n备注:\n$notes');
    }

    return await _printContent(
      context: context,
      title: paperName,
      content: content.toString(),
      type: '试卷',
      metadata: {
        '学科': subject,
        if (examDate != null) '考试日期': examDate,
      },
    );
  }

  /// 批量打印内容
  /// 支持多种内容类型混合打印
  static Future<PrintResult> printBatch({
    required BuildContext context,
    required List<PrintContentItem> items,
    String? customTitle,
  }) async {
    if (items.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有选择要打印的内容')),
        );
      }
      return const PrintResult(success: false, errorMessage: '没有选择要打印的内容');
    }

    try {
      // 先加载中文字体
      final chineseFont = await _loadChineseFont();
      _log('中文字体加载完成，开始生成PDF...');

      final pdf = pw.Document();
      final now = DateTime.now();
      final printTime = formatDateTime(now);

      // 创建支持中文的文本样式
      final titleStyle = pw.TextStyle(
        font: chineseFont,
        fontSize: 28,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blue800,
      );
      final subtitleStyle = pw.TextStyle(
        font: chineseFont,
        fontSize: 16,
        color: PdfColors.grey600,
      );
      final timeStyle = pw.TextStyle(
        font: chineseFont,
        fontSize: 12,
        color: PdfColors.grey500,
      );
      final contentStyle = pw.TextStyle(
        font: chineseFont,
        fontSize: 12,
        lineSpacing: 1.5,
      );
      final headerStyle = pw.TextStyle(
        font: chineseFont,
        fontSize: 20,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blue900,
      );
      final labelStyle = pw.TextStyle(
        font: chineseFont,
        fontSize: 10,
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
      );
      final pageNumStyle = pw.TextStyle(
        font: chineseFont,
        fontSize: 10,
        color: PdfColors.grey500,
      );
      final footerStyle = pw.TextStyle(
        font: chineseFont,
        fontSize: 10,
        color: PdfColors.grey500,
      );

      // 封面页
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Icon(
                    pw.IconData(Icons.print.codePoint),
                    size: 64,
                    color: PdfColors.blue700,
                  ),
                  pw.SizedBox(height: 24),
                  pw.Text(
                    customTitle ?? '学习资料打印',
                    style: titleStyle,
                  ),
                  pw.SizedBox(height: 16),
                  pw.Text(
                    '共 ${items.length} 项内容',
                    style: subtitleStyle,
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    '打印时间: $printTime',
                    style: timeStyle,
                  ),
                  pw.SizedBox(height: 32),
                  // 内容类型统计
                  _buildTypeStatistics(items, chineseFont),
                ],
              ),
            );
          },
        ),
      );

      // 目录页
      if (items.length > 5) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '目录',
                    style: pw.TextStyle(
                      font: chineseFont,
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Divider(),
                  pw.SizedBox(height: 16),
                  ...items.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final item = entry.value;
                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 4),
                      child: pw.Row(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: pw.BoxDecoration(
                              color: _getPdfColorForType(item.type),
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                            child: pw.Text(
                              item.typeLabel,
                              style: labelStyle,
                            ),
                          ),
                          pw.SizedBox(width: 12),
                          pw.Expanded(
                            child: pw.Text(
                              '$index. ${item.title}',
                              style: pw.TextStyle(font: chineseFont, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        );
      }

      // 内容页
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // 页眉
                  pw.Row(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: pw.BoxDecoration(
                          color: _getPdfColorForType(item.type),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          item.typeLabel,
                          style: labelStyle,
                        ),
                      ),
                      pw.Spacer(),
                      pw.Text(
                        '${i + 1} / ${items.length}',
                        style: pageNumStyle,
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 16),

                  // 标题
                  pw.Text(
                    item.title,
                    style: headerStyle,
                  ),
                  pw.SizedBox(height: 12),

                  // 元数据
                  _buildItemMetadataWithFont(item, chineseFont),
                  pw.SizedBox(height: 16),

                  // 分隔线
                  pw.Divider(color: PdfColors.grey300),
                  pw.SizedBox(height: 16),

                  // 内容
                  pw.Text(
                    item.content,
                    style: contentStyle,
                  ),

                  pw.Spacer(),

                  // 页脚
                  pw.Divider(color: PdfColors.grey300),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '智慧学习 App',
                        style: footerStyle,
                      ),
                      pw.Text(
                        '打印时间: $printTime',
                        style: footerStyle,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      }

      // 生成 PDF 字节
      final pdfBytes = await pdf.save();

      // 显示打印选项让用户选择
      final option = await showPrintOptionsDialog(
        context,
        title: '选择打印方式',
      );

      if (option == null) {
        return const PrintResult(success: false, errorMessage: '用户取消了操作');
      }

      _log('用户选择的打印方式: $option');

      switch (option) {
        case PrintOption.print:
          // 直接打印
          if (Platform.isLinux) {
            return await _printWithSystemCommand(
              pdfBytes,
              customTitle ?? '学习资料',
            );
          } else {
            // 其他平台使用 printing 包直接打印
            return await Printing.layoutPdf(
              onLayout: (_) async => pdfBytes,
              name: customTitle ?? '学习资料',
            ).then((_) => const PrintResult(success: true))
              .catchError((e) => PrintResult(success: false, errorMessage: '打印失败: $e'));
          }

        case PrintOption.savePdf:
          // 保存 PDF
          if (Platform.isLinux) {
            return await _savePdfOnLinux(context, pdfBytes, customTitle ?? '学习资料', now);
          } else {
            return await _savePdfOnOtherPlatform(context, pdfBytes, customTitle ?? '学习资料', now);
          }

        case PrintOption.preview:
          // 打印预览
          if (Platform.isLinux) {
            // Linux 平台没有原生预览，使用 savePdf
            return await _savePdfOnLinux(context, pdfBytes, customTitle ?? '学习资料', now);
          } else {
            return await _showPdfPreview(context, pdfBytes, customTitle ?? '学习资料', now);
          }
      }
    } catch (e) {
      _log('批量打印失败: $e');
      // 打印失败，提供替代方案
      if (context.mounted) {
        _showPrintErrorDialog(context, e.toString());
      }
      return PrintResult(success: false, errorMessage: '生成PDF失败: $e');
    }
  }

  /// Linux 平台保存 PDF
  static Future<PrintResult> _savePdfOnLinux(
    BuildContext context,
    Uint8List pdfBytes,
    String defaultName,
    DateTime now,
  ) async {
    _log('Linux平台保存PDF...');
    try {
      // 获取默认下载目录
      String? defaultDirectory;
      try {
        final home = Platform.environment['HOME'];
        if (home != null) {
          defaultDirectory = '$home/Downloads';
          final downloadDir = Directory(defaultDirectory);
          if (!await downloadDir.exists()) {
            _log('下载目录不存在，使用HOME目录');
            defaultDirectory = home;
          }
        }
      } catch (e) {
        _log('获取默认目录失败: $e');
      }

      // 使用文件选择器让用户选择保存位置
      String? outputPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择PDF保存位置',
        initialDirectory: defaultDirectory,
      );

      if (outputPath == null) {
        _log('用户取消了保存操作');
        return const PrintResult(success: false, errorMessage: '用户取消了保存操作');
      }

      _log('用户选择目录: $outputPath');

      // 构建文件路径
      final fileName = '${defaultName}_${formatDate(now)}.pdf';
      final filePath = '$outputPath/$fileName';
      final file = File(filePath);

      // 写入文件
      await file.writeAsBytes(pdfBytes);

      // 验证写入成功
      if (await file.exists()) {
        final fileSize = await file.length();
        _log('PDF保存成功，大小: $fileSize 字节');

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF已保存到: $filePath'),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: '打印',
                onPressed: () async {
                  // 可以选择打印已保存的文件
                  await _printWithSystemCommand(pdfBytes, defaultName);
                },
              ),
            ),
          );
        }

        return PrintResult(success: true, filePath: filePath);
      } else {
        return const PrintResult(success: false, errorMessage: '文件写入验证失败');
      }
    } catch (e) {
      _log('保存PDF失败: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存PDF失败: $e')),
        );
      }
      return PrintResult(success: false, errorMessage: '保存PDF失败: $e');
    }
  }

  /// 其他平台保存 PDF
  static Future<PrintResult> _savePdfOnOtherPlatform(
    BuildContext context,
    Uint8List pdfBytes,
    String defaultName,
    DateTime now,
  ) async {
    _log('其他平台保存PDF...');
    try {
      final fileName = '${defaultName}_${formatDate(now)}.pdf';

      final result = await FilePicker.platform.saveFile(
        dialogTitle: '保存PDF文件',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null) {
        return const PrintResult(success: false, errorMessage: '用户取消了保存操作');
      }

      final file = File(result);
      await file.writeAsBytes(pdfBytes);

      _log('PDF保存成功: ${file.path}');
      return PrintResult(success: true, filePath: file.path);
    } catch (e) {
      _log('保存PDF失败: $e');
      return PrintResult(success: false, errorMessage: '保存PDF失败: $e');
    }
  }

  /// 显示 PDF 预览
  static Future<PrintResult> _showPdfPreview(
    BuildContext context,
    Uint8List pdfBytes,
    String defaultName,
    DateTime now,
  ) async {
    _log('显示PDF预览...');
    try {
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (context) => Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.8,
                child: PdfPreview(
                  build: (format) => pdfBytes,
                  allowPrinting: true,
                  allowSharing: true,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  pdfFileName: '${defaultName}_${formatDate(now)}.pdf',
                ),
              ),
            ),
          ),
        );
      }
      return const PrintResult(success: true);
    } catch (e) {
      _log('PDF预览失败: $e');
      return PrintResult(success: false, errorMessage: 'PDF预览失败: $e');
    }
  }

  /// 显示打印错误对话框，提供替代方案
  static void _showPrintErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('打印失败'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('错误信息: $error'),
            const SizedBox(height: 16),
            const Text('您可以尝试以下替代方案:'),
            const SizedBox(height: 8),
            const Text('1. 导出数据为JSON文件'),
            const Text('2. 使用截图功能保存内容'),
            const Text('3. 复制文本内容到其他应用'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 构建类型统计
  static pw.Widget _buildTypeStatistics(List<PrintContentItem> items, pw.Font chineseFont) {
    final typeCounts = <PrintContentType, int>{};
    for (final item in items) {
      typeCounts[item.type] = (typeCounts[item.type] ?? 0) + 1;
    }

    return pw.Wrap(
      spacing: 16,
      runSpacing: 8,
      children: typeCounts.entries.map((entry) {
        return pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: pw.BoxDecoration(
            color: _withOpacity(_getPdfColorForType(entry.key), 0.1),
            borderRadius: pw.BorderRadius.circular(20),
            border: pw.Border.all(
              color: _getPdfColorForType(entry.key),
              width: 1,
            ),
          ),
          child: pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Container(
                width: 8,
                height: 8,
                decoration: pw.BoxDecoration(
                  color: _getPdfColorForType(entry.key),
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Text(
                '${entry.key.typeLabel}: ${entry.value}',
                style: pw.TextStyle(
                  font: chineseFont,
                  fontSize: 11,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// 获取PDF颜色
  static PdfColor _getPdfColorForType(PrintContentType type) {
    switch (type) {
      case PrintContentType.knowledgePoint:
        return PdfColors.blue700;
      case PrintContentType.note:
        return PdfColors.green700;
      case PrintContentType.wrongQuestion:
        return PdfColors.red700;
      case PrintContentType.motherQuestion:
        return PdfColors.purple700;
      case PrintContentType.mustRemember:
        return PdfColors.orange700;
      case PrintContentType.studySuggestion:
        return PdfColors.teal700;
    }
  }

  /// 为PdfColor添加透明度
  static PdfColor _withOpacity(PdfColor color, double opacity) {
    return PdfColor(color.red, color.green, color.blue, opacity);
  }

  /// 构建项目元数据（支持中文字体）
  static pw.Widget _buildItemMetadataWithFont(PrintContentItem item, pw.Font chineseFont) {
    final metadata = <pw.Widget>[];

    if (item.subject != null) {
      metadata.add(_buildMetadataChipWithFont('学科', item.subject!, chineseFont));
    }
    if (item.category != null) {
      metadata.add(_buildMetadataChipWithFont('分类', item.category!, chineseFont));
    }
    if (item.difficulty != null) {
      metadata.add(_buildMetadataChipWithFont('难度', _getDifficultyLabel(item.difficulty!), chineseFont));
    }
    if (item.masteryLevel != null) {
      metadata.add(_buildMetadataChipWithFont('掌握度', '${item.masteryLevel}%', chineseFont));
    }
    if (item.examMethod != null && item.examMethod!.isNotEmpty) {
      metadata.add(_buildMetadataChipWithFont('考法', item.examMethod!, chineseFont));
    }
    if (item.keyPoint != null && item.keyPoint!.isNotEmpty) {
      metadata.add(_buildMetadataChipWithFont('考点', item.keyPoint!, chineseFont));
    }
    if (item.tags != null && item.tags!.isNotEmpty) {
      metadata.add(_buildMetadataChipWithFont('标签', item.tags!, chineseFont));
    }
    if (item.createdAt != null) {
      metadata.add(_buildMetadataChipWithFont('创建时间', item.createdAt!, chineseFont));
    }

    // 添加额外元数据
    item.additionalMetadata.forEach((key, value) {
      metadata.add(_buildMetadataChipWithFont(key, value, chineseFont));
    });

    if (metadata.isEmpty) return pw.SizedBox.shrink();

    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: metadata,
    );
  }

  /// 构建项目元数据（旧版本，用于向后兼容）
  static pw.Widget _buildItemMetadata(PrintContentItem item) {
    final metadata = <pw.Widget>[];

    if (item.subject != null) {
      metadata.add(_buildMetadataChip('学科', item.subject!));
    }
    if (item.category != null) {
      metadata.add(_buildMetadataChip('分类', item.category!));
    }
    if (item.difficulty != null) {
      metadata.add(_buildMetadataChip('难度', _getDifficultyLabel(item.difficulty!)));
    }
    if (item.masteryLevel != null) {
      metadata.add(_buildMetadataChip('掌握度', '${item.masteryLevel}%'));
    }
    if (item.examMethod != null && item.examMethod!.isNotEmpty) {
      metadata.add(_buildMetadataChip('考法', item.examMethod!));
    }
    if (item.keyPoint != null && item.keyPoint!.isNotEmpty) {
      metadata.add(_buildMetadataChip('考点', item.keyPoint!));
    }
    if (item.tags != null && item.tags!.isNotEmpty) {
      metadata.add(_buildMetadataChip('标签', item.tags!));
    }
    if (item.createdAt != null) {
      metadata.add(_buildMetadataChip('创建时间', item.createdAt!));
    }

    // 添加额外元数据
    item.additionalMetadata.forEach((key, value) {
      metadata.add(_buildMetadataChip(key, value));
    });

    if (metadata.isEmpty) return pw.SizedBox.shrink();

    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: metadata,
    );
  }

  /// 构建元数据标签（支持中文字体）
  static pw.Widget _buildMetadataChipWithFont(String label, String value, pw.Font chineseFont) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            '$label: ',
            style: pw.TextStyle(
              font: chineseFont,
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: chineseFont,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建元数据标签
  static pw.Widget _buildMetadataChip(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            '$label: ',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
        ],
      ),
    );
  }

  /// 通用打印内容方法
  static Future<PrintResult> _printContent({
    required BuildContext context,
    required String title,
    required String content,
    required String type,
    Map<String, String> metadata = const {},
  }) async {
    try {
      // 先加载中文字体
      final chineseFont = await _loadChineseFont();
      _log('通用打印: 中文字体加载完成');

      final pdf = pw.Document();
      final now = DateTime.now();
      final printTime = formatDateTime(now);

      // 创建支持中文的文本样式
      final titleStyle = pw.TextStyle(
        font: chineseFont,
        fontSize: 24,
        fontWeight: pw.FontWeight.bold,
      );
      final typeStyle = pw.TextStyle(
        font: chineseFont,
        fontSize: 12,
        color: PdfColors.blue800,
      );
      final labelStyle = pw.TextStyle(
        font: chineseFont,
        fontSize: 10,
        color: PdfColors.grey700,
      );
      final valueStyle = pw.TextStyle(
        font: chineseFont,
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
      );
      final contentStyle = pw.TextStyle(
        font: chineseFont,
        fontSize: 12,
      );
      final footerStyle = pw.TextStyle(
        font: chineseFont,
        fontSize: 10,
        color: PdfColors.grey600,
        fontStyle: pw.FontStyle.italic,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // 标题
                pw.Text(
                  title,
                  style: titleStyle,
                ),
                pw.SizedBox(height: 8),
                // 类型标签
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue100,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    type,
                    style: typeStyle,
                  ),
                ),
                pw.SizedBox(height: 16),
                // 元数据
                if (metadata.isNotEmpty) ...[
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: metadata.entries.map((entry) {
                        return pw.Row(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Text(
                              '${entry.key}: ',
                              style: labelStyle,
                            ),
                            pw.Text(
                              entry.value,
                              style: valueStyle,
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  pw.SizedBox(height: 16),
                ],
                // 分隔线
                pw.Divider(),
                pw.SizedBox(height: 16),
                // 内容
                pw.Text(
                  content,
                  style: contentStyle,
                ),
                pw.SizedBox(height: 32),
                // 分隔线
                pw.Divider(),
                pw.SizedBox(height: 8),
                // 打印时间
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text(
                      '打印时间: $printTime',
                      style: footerStyle,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      // 生成 PDF 字节
      final pdfBytes = await pdf.save();

      // 显示打印选项让用户选择
      final option = await showPrintOptionsDialog(
        context,
        title: '选择打印方式',
      );

      if (option == null) {
        return const PrintResult(success: false, errorMessage: '用户取消了操作');
      }

      switch (option) {
        case PrintOption.print:
          // 直接打印
          if (Platform.isLinux) {
            return await _printWithSystemCommand(pdfBytes, type);
          } else {
            return await Printing.layoutPdf(
              onLayout: (_) async => pdfBytes,
              name: type,
            ).then((_) => const PrintResult(success: true))
              .catchError((e) => PrintResult(success: false, errorMessage: '打印失败: $e'));
          }

        case PrintOption.savePdf:
          // 保存 PDF
          if (Platform.isLinux) {
            return await _savePdfOnLinux(context, pdfBytes, type, now);
          } else {
            return await _savePdfOnOtherPlatform(context, pdfBytes, type, now);
          }

        case PrintOption.preview:
          // 打印预览
          if (Platform.isLinux) {
            return await _savePdfOnLinux(context, pdfBytes, type, now);
          } else {
            return await _showPdfPreview(context, pdfBytes, type, now);
          }
      }
    } catch (e) {
      _log('打印失败: $e');
      if (context.mounted) {
        _showPrintErrorDialog(context, e.toString());
      }
      return PrintResult(success: false, errorMessage: '生成PDF失败: $e');
    }
  }

  /// 生成PDF字节（不显示预览）
  /// 用于组合打印或保存到文件
  static Future<Uint8List?> generatePdfBytes({
    required String title,
    required String content,
    required String type,
    Map<String, String> metadata = const {},
  }) async {
    try {
      final pdf = pw.Document();
      final now = DateTime.now();
      final printTime = formatDateTime(now);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue100,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    type,
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.blue800,
                    ),
                  ),
                ),
                pw.SizedBox(height: 16),
                if (metadata.isNotEmpty) ...[
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: metadata.entries.map((entry) {
                        return pw.Row(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Text(
                              '${entry.key}: ',
                              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                            ),
                            pw.Text(
                              entry.value,
                              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  pw.SizedBox(height: 16),
                ],
                pw.Divider(),
                pw.SizedBox(height: 16),
                pw.Text(content, style: const pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 32),
                pw.Divider(),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text(
                      '打印时间: $printTime',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      return await pdf.save();
    } catch (e) {
      _log('生成PDF失败: $e');
      return null;
    }
  }

  static String _getDifficultyLabel(int difficulty) {
    switch (difficulty) {
      case 1:
        return '简单';
      case 2:
        return '中等';
      case 3:
        return '困难';
      default:
        return '未知';
    }
  }
}

/// 扩展PrintContentType
extension PrintContentTypeExtension on PrintContentType {
  String get typeLabel {
    switch (this) {
      case PrintContentType.knowledgePoint:
        return '知识点';
      case PrintContentType.note:
        return '笔记';
      case PrintContentType.wrongQuestion:
        return '错题';
      case PrintContentType.motherQuestion:
        return '母题';
      case PrintContentType.mustRemember:
        return '必背必记';
      case PrintContentType.studySuggestion:
        return '学习建议';
    }
  }
}
