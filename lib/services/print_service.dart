import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../utils/helpers.dart';

/// 打印内容类型枚举
enum PrintContentType {
  knowledgePoint,
  note,
  wrongQuestion,
  motherQuestion,
  mustRemember,
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
    }
  }
}

/// 打印服务类
/// 用于生成PDF并打印各类型内容
class PrintService {
  /// 打印知识点详情
  static Future<void> printKnowledgePoint({
    required BuildContext context,
    required String title,
    required String content,
    String? subject,
    String? category,
    String? tags,
    int? difficulty,
    int? masteryLevel,
  }) async {
    await _printContent(
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
  static Future<void> printNote({
    required BuildContext context,
    required String title,
    required String content,
    String? subject,
    String? tags,
    String? createdAt,
  }) async {
    await _printContent(
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
  static Future<void> printWrongQuestion({
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

    await _printContent(
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
  static Future<void> printMotherQuestion({
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

    await _printContent(
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
  static Future<void> printMustRemember({
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
    await _printContent(
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
  static Future<void> printExamPaper({
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

    await _printContent(
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
  static Future<void> printBatch({
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
      return;
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

      // 显示打印预览对话框
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
                  build: (format) => pdf.save(),
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
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成PDF失败: $e')),
        );
      }
    }
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
  static Future<void> _printContent({
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

      // 显示打印预览对话框
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
                build: (format) => pdf.save(),
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
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成PDF失败: $e')),
        );
      }
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
    }
  }
}
