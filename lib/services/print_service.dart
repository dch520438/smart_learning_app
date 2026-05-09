import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../utils/helpers.dart';

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
