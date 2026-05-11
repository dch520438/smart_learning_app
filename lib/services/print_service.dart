import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
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
  /// 检查打印功能是否可用
  static Future<bool> isPrintingAvailable() async {
    try {
      // 在 Linux 上，printing 插件可能有问题
      // 我们尝试检测是否可用
      if (Platform.isLinux) {
        // Linux 上打印功能可能不稳定，返回 true 让用户尝试
        // 如果失败会捕获异常并提供替代方案
        return true;
      }
      return true;
    } catch (e) {
      return false;
    }
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
      final pdf = pw.Document();
      final now = DateTime.now();
      final printTime = formatDateTime(now);

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
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Text(
                    '共 ${items.length} 项内容',
                    style: pw.TextStyle(
                      fontSize: 16,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    '打印时间: $printTime',
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey500,
                    ),
                  ),
                  pw.SizedBox(height: 32),
                  // 内容类型统计
                  _buildTypeStatistics(items),
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
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.white,
                              ),
                            ),
                          ),
                          pw.SizedBox(width: 12),
                          pw.Expanded(
                            child: pw.Text(
                              '$index. ${item.title}',
                              style: const pw.TextStyle(fontSize: 12),
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
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Spacer(),
                      pw.Text(
                        '${i + 1} / ${items.length}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey500,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 16),

                  // 标题
                  pw.Text(
                    item.title,
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 12),

                  // 元数据
                  _buildItemMetadata(item),
                  pw.SizedBox(height: 16),

                  // 分隔线
                  pw.Divider(color: PdfColors.grey300),
                  pw.SizedBox(height: 16),

                  // 内容
                  pw.Text(
                    item.content,
                    style: const pw.TextStyle(
                      fontSize: 12,
                      lineSpacing: 1.5,
                    ),
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
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey500,
                        ),
                      ),
                      pw.Text(
                        '打印时间: $printTime',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey500,
                        ),
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

      // 在 Linux 上，提供保存 PDF 的选项
      if (Platform.isLinux) {
        return await _savePdfOnLinux(context, pdfBytes, customTitle ?? '学习资料', now);
      }

      // 其他平台：显示打印预览对话框
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
                  pdfFileName: '学习资料_${formatDate(now)}.pdf',
                ),
              ),
            ),
          ),
        );
      }

      return PrintResult(success: true);
    } catch (e) {
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
    try {
      // 获取默认下载目录
      String? defaultDirectory;
      try {
        final home = Platform.environment['HOME'];
        if (home != null) {
          defaultDirectory = '$home/Downloads';
          final downloadDir = Directory(defaultDirectory);
          if (!await downloadDir.exists()) {
            defaultDirectory = home;
          }
        }
      } catch (_) {}

      // 使用文件选择器让用户选择保存位置
      String? outputPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择PDF保存位置',
        initialDirectory: defaultDirectory,
      );

      if (outputPath == null) {
        return const PrintResult(success: false, errorMessage: '用户取消了保存操作');
      }

      // 构建文件路径
      final fileName = '${defaultName}_${formatDate(now)}.pdf';
      final filePath = '$outputPath/$fileName';
      final file = File(filePath);

      // 写入文件
      await file.writeAsBytes(pdfBytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF已保存到: $filePath'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: '打开目录',
              onPressed: () async {
                // 打开文件所在目录
                final dir = file.parent;
                // 可以使用 xdg-open 打开目录
              },
            ),
          ),
        );
      }

      return PrintResult(success: true, filePath: filePath);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存PDF失败: $e')),
        );
      }
      return PrintResult(success: false, errorMessage: '保存PDF失败: $e');
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
  static pw.Widget _buildTypeStatistics(List<PrintContentItem> items) {
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

  /// 构建项目元数据
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
                // 标题
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
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
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.blue800,
                    ),
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
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey700,
                              ),
                            ),
                            pw.Text(
                              entry.value,
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                              ),
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
                  style: const pw.TextStyle(fontSize: 12),
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

      // 生成 PDF 字节
      final pdfBytes = await pdf.save();

      // 在 Linux 上，提供保存 PDF 的选项
      if (Platform.isLinux) {
        return await _savePdfOnLinux(context, pdfBytes, type, now);
      }

      // 其他平台：显示打印预览对话框
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
                pdfFileName: '${type}_${formatDate(now)}.pdf',
              ),
            ),
          ),
        ),
      );

      return const PrintResult(success: true);
    } catch (e) {
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
