import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../services/database_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

/// 网络抓取结果数据模型
class WebFetchResult {
  final String title;
  final String textContent;
  final List<String> imageUrls;
  final String sourceUrl;
  final DateTime fetchTime;

  WebFetchResult({
    required this.title,
    required this.textContent,
    required this.imageUrls,
    required this.sourceUrl,
    required this.fetchTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'textContent': textContent,
      'imageUrls': jsonEncode(imageUrls),
      'sourceUrl': sourceUrl,
      'fetchTime': fetchTime.toIso8601String(),
    };
  }

  factory WebFetchResult.fromMap(Map<String, dynamic> map) {
    return WebFetchResult(
      title: map['title'] as String? ?? '',
      textContent: map['textContent'] as String? ?? '',
      imageUrls: (map['imageUrls'] != null)
          ? List<String>.from(jsonDecode(map['imageUrls'] as String))
          : [],
      sourceUrl: map['sourceUrl'] as String? ?? '',
      fetchTime: DateTime.parse(map['fetchTime'] as String),
    );
  }
}

/// 网络知识抓取页面
class WebKnowledgeScreen extends StatefulWidget {
  const WebKnowledgeScreen({super.key});

  @override
  State<WebKnowledgeScreen> createState() => _WebKnowledgeScreenState();
}

class _WebKnowledgeScreenState extends State<WebKnowledgeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseService _db = DatabaseService();
  final TextEditingController _urlController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isFetching = false;
  String? _errorMessage;
  WebFetchResult? _fetchResult;
  List<Map<String, dynamic>> _savedItems = [];
  bool _isLoadingSaved = true;

  // 选中打印的文本范围
  int _printSelectionStart = 0;
  int _printSelectionEnd = -1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSavedItems();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 加载已保存的网络知识列表
  Future<void> _loadSavedItems() async {
    setState(() => _isLoadingSaved = true);
    try {
      final records = await _db.queryStudyRecordsByType('web_knowledge');
      setState(() {
        _savedItems = records;
        _isLoadingSaved = false;
      });
    } catch (e) {
      setState(() => _isLoadingSaved = false);
    }
  }

  /// 抓取网页内容
  Future<void> _fetchWebContent() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      showSnackBar(context, '请输入网址', isError: true);
      return;
    }

    // 简单URL格式验证
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      showSnackBar(context, '请输入有效的网址（以 http:// 或 https:// 开头）', isError: true);
      return;
    }

    setState(() {
      _isFetching = true;
      _errorMessage = null;
      _fetchResult = null;
    });

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('服务器返回错误状态码: ${response.statusCode}');
      }

      final html = response.body;

      // 提取网页标题
      final title = _extractTitle(html);

      // 提取纯文本内容
      final textContent = _extractTextContent(html);

      // 提取图片URL
      final imageUrls = _extractImageUrls(url, html);

      if (textContent.trim().isEmpty) {
        throw Exception('未能从该网页提取到有效文本内容');
      }

      setState(() {
        _fetchResult = WebFetchResult(
          title: title.isNotEmpty ? title : url,
          textContent: textContent,
          imageUrls: imageUrls,
          sourceUrl: url,
          fetchTime: DateTime.now(),
        );
        _isFetching = false;
        _printSelectionStart = 0;
        _printSelectionEnd = -1;
      });

      // 切换到抓取结果标签
      _tabController.animateTo(0);
    } on FormatException {
      setState(() {
        _errorMessage = '网页内容格式错误，无法解析';
        _isFetching = false;
      });
    } catch (e) {
      String msg;
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        msg = '网络连接失败，请检查网络设置';
      } else if (e.toString().contains('TimeoutException')) {
        msg = '请求超时，请稍后重试';
      } else {
        msg = e.toString().replaceFirst('Exception: ', '');
      }
      setState(() {
        _errorMessage = msg;
        _isFetching = false;
      });
    }
  }

  /// 从HTML中提取标题
  String _extractTitle(String html) {
    // 匹配 <title> 标签
    final titleRegex = RegExp(r'<title[^>]*>(.*?)</title>', dotAll: true);
    final match = titleRegex.firstMatch(html);
    if (match != null) {
      return _decodeHtmlEntities(match.group(1)?.trim() ?? '');
    }
    return '';
  }

  /// 从HTML中提取纯文本内容
  String _extractTextContent(String html) {
    // 移除 script 和 style 标签及其内容
    var text = html.replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'<noscript[^>]*>[\s\S]*?</noscript>', caseSensitive: false), '');

    // 将块级标签替换为换行
    text = text.replaceAll(RegExp(r'<br\s*/?\s*>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'</?(p|div|h[1-6]|li|tr|blockquote|pre|section|article|header|footer|nav|aside)[^>]*>', caseSensitive: false), '\n');

    // 移除所有剩余HTML标签
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');

    // 解码HTML实体
    text = _decodeHtmlEntities(text);

    // 清理多余空白
    text = text.replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n');
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');

    return text.trim();
  }

  /// 从HTML中提取图片URL
  List<String> _extractImageUrls(String baseUrl, String html) {
    final imageUrls = <String>[];
    final imgRegex = RegExp(r'''<img[^>]+src\s*=\s*["']([^"']+)["']''', caseSensitive: false);
    final matches = imgRegex.allMatches(html);

    for (final match in matches) {
      var imgUrl = match.group(1)?.trim() ?? '';
      if (imgUrl.isEmpty) continue;

      // 跳过 data URI 和 base64 图片
      if (imgUrl.startsWith('data:')) continue;

      // 处理相对路径
      if (imgUrl.startsWith('//')) {
        imgUrl = 'https:$imgUrl';
      } else if (imgUrl.startsWith('/')) {
        final uri = Uri.parse(baseUrl);
        imgUrl = '${uri.scheme}://${uri.host}$imgUrl';
      } else if (!imgUrl.startsWith('http://') && !imgUrl.startsWith('https://')) {
        final uri = Uri.parse(baseUrl);
        imgUrl = '${uri.scheme}://${uri.host}/${imgUrl}';
      }

      imageUrls.add(imgUrl);
    }

    return imageUrls;
  }

  /// 解码HTML实体
  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
      final code = int.tryParse(match.group(1) ?? '');
      if (code != null && code > 0 && code < 0x10FFFF) {
        return String.fromCharCode(code);
      }
      return match.group(0) ?? '';
    });
  }

  /// 保存为知识点
  Future<void> _saveAsKnowledgePoint() async {
    if (_fetchResult == null) return;

    String? selectedSubject = kSubjectNames.first;

    await showDialog(
      context: context,
      builder: (ctx) {
        String? tempSubject = kSubjectNames.first;
        return AlertDialog(
          title: const Text('保存为知识点'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('选择学科分类：'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: tempSubject,
                decoration: const InputDecoration(
                  labelText: '学科',
                  border: OutlineInputBorder(),
                ),
                items: kSubjectNames
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => tempSubject = v,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                selectedSubject = tempSubject;
                Navigator.of(ctx).pop();
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (selectedSubject == null) return;

    try {
      final uuid = const Uuid().v4();
      await _db.insertKnowledgePoint({
        'uuid': uuid,
        'title': _fetchResult!.title,
        'content': _fetchResult!.textContent,
        'subject': selectedSubject,
        'tags': '网络知识',
        'category': '网络知识',
        'difficulty': 0,
        'mastery_level': 0,
        'review_count': 0,
        'parent_id': null,
        'sort_order': 0,
        'is_favorite': 0,
        'attachment_paths': _fetchResult!.imageUrls.isNotEmpty
            ? jsonEncode(_fetchResult!.imageUrls)
            : null,
      });

      // 同时保存一条学习记录
      await _db.insertStudyRecord({
        'uuid': const Uuid().v4(),
        'record_type': 'web_knowledge',
        'title': _fetchResult!.title,
        'description': '来源: ${_fetchResult!.sourceUrl}',
        'subject': selectedSubject,
        'duration': 0,
        'related_id': null,
        'related_type': 'knowledge_point',
        'is_completed': 1,
      });

      if (mounted) {
        showSnackBar(context, '已保存为知识点');
        _loadSavedItems();
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '保存失败: $e', isError: true);
      }
    }
  }

  /// 保存为笔记
  Future<void> _saveAsNote() async {
    if (_fetchResult == null) return;

    String? selectedSubject = kSubjectNames.first;

    await showDialog(
      context: context,
      builder: (ctx) {
        String? tempSubject = kSubjectNames.first;
        return AlertDialog(
          title: const Text('保存为笔记'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('选择学科分类：'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: tempSubject,
                decoration: const InputDecoration(
                  labelText: '学科',
                  border: OutlineInputBorder(),
                ),
                items: kSubjectNames
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => tempSubject = v,
              ),
            ],
          ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              selectedSubject = tempSubject;
              Navigator.of(ctx).pop();
            },
            child: const Text('保存'),
          ),
        ],
      );
      },
    );

    if (selectedSubject == null) return;

    try {
      final uuid = const Uuid().v4();
      await _db.insertNote({
        'uuid': uuid,
        'title': _fetchResult!.title,
        'content': _fetchResult!.textContent,
        'subject': selectedSubject,
        'tags': '网络知识',
        'note_type': 'text',
        'knowledge_point_id': null,
        'is_favorite': 0,
        'attachment_paths': _fetchResult!.imageUrls.isNotEmpty
            ? jsonEncode(_fetchResult!.imageUrls)
            : null,
        'color': null,
      });

      // 同时保存一条学习记录
      await _db.insertStudyRecord({
        'uuid': const Uuid().v4(),
        'record_type': 'web_knowledge',
        'title': _fetchResult!.title,
        'description': '来源: ${_fetchResult!.sourceUrl}',
        'subject': selectedSubject,
        'duration': 0,
        'related_id': null,
        'related_type': 'note',
        'is_completed': 1,
      });

      if (mounted) {
        showSnackBar(context, '已保存为笔记');
        _loadSavedItems();
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '保存失败: $e', isError: true);
      }
    }
  }

  /// 复制文本内容到剪贴板
  Future<void> _copyTextContent() async {
    if (_fetchResult == null) return;
    await Clipboard.setData(ClipboardData(text: _fetchResult!.textContent));
    if (mounted) {
      showSnackBar(context, '文本内容已复制到剪贴板');
    }
  }

  /// 选取内容打印
  Future<void> _printSelectedContent() async {
    if (_fetchResult == null) return;

    final text = _fetchResult!.textContent;
    String printText;

    if (_printSelectionEnd > _printSelectionStart) {
      printText = text.substring(_printSelectionStart, _printSelectionEnd);
    } else {
      printText = text;
    }

    if (printText.trim().isEmpty) {
      showSnackBar(context, '没有可打印的内容', isError: true);
      return;
    }

    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
            pw.Header(
              level: 0,
              text: _fetchResult!.title,
            ),
            pw.Paragraph(text: '来源: ${_fetchResult!.sourceUrl}'),
            pw.Paragraph(text: '打印时间: ${formatDateTime(DateTime.now())}'),
            pw.SizedBox(height: 20),
            pw.Paragraph(text: printText),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: _fetchResult!.title,
      );
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '打印失败: $e', isError: true);
      }
    }
  }

  /// 显示选取打印内容的对话框
  void _showPrintSelectionDialog() {
    if (_fetchResult == null) return;
    final text = _fetchResult!.textContent;

    showDialog(
      context: context,
      builder: (ctx) {
        int start = _printSelectionStart;
        int end = _printSelectionEnd < 0 ? text.length : _printSelectionEnd;
        final startController = TextEditingController(text: start.toString());
        final endController = TextEditingController(text: end.toString());

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('选取打印内容'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '文本总长度: ${text.length} 字符',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: startController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '起始位置',
                      hintText: '从第几个字符开始',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      start = int.tryParse(v) ?? 0;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: endController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '结束位置',
                      hintText: '到第几个字符结束（留空或-1表示全部）',
                      border: const OutlineInputBorder(),
                      suffixText: '共 ${text.length} 字符',
                    ),
                    onChanged: (v) {
                      end = int.tryParse(v) ?? -1;
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '预览: ${truncateText(text.substring(start.clamp(0, text.length), (end < 0 ? text.length : end).clamp(0, text.length)), 100)}',
                      style: const TextStyle(fontSize: 12),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('取消'),
                ),
                OutlinedButton(
                  onPressed: () {
                    // 打印全部
                    Navigator.of(ctx).pop();
                    setState(() {
                      _printSelectionStart = 0;
                      _printSelectionEnd = -1;
                    });
                    _printSelectedContent();
                  },
                  child: const Text('打印全部'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    setState(() {
                      _printSelectionStart = start.clamp(0, text.length);
                      _printSelectionEnd = end.clamp(0, text.length);
                    });
                    _printSelectedContent();
                  },
                  child: const Text('打印选中'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 查看已保存的网络知识详情
  void _viewSavedItemDetail(Map<String, dynamic> item) {
    final title = item['title'] as String? ?? '';
    final description = item['description'] as String? ?? '';
    final subject = item['subject'] as String? ?? '';
    final createdAt = item['created_at'] as String? ?? '';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (subject.isNotEmpty)
                  Row(
                    children: [
                      const Text('学科: ', style: TextStyle(fontWeight: FontWeight.w600)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: getSubjectColor(subject).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(subject, style: TextStyle(color: getSubjectColor(subject), fontSize: 12)),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                if (description.isNotEmpty) ...[
                  const Text('来源:', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(description, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                ],
                const Text('保存时间:', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  createdAt,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  /// 删除已保存的网络知识
  Future<void> _deleteSavedItem(int id) async {
    final confirmed = await AppDialog.showConfirmDelete(
      context: context,
      title: '删除记录',
      message: '确定要删除这条网络知识记录吗？',
    );

    if (confirmed == true) {
      try {
        await _db.deleteStudyRecord(id);
        showSnackBar(context, '已删除');
        _loadSavedItems();
      } catch (e) {
        showSnackBar(context, '删除失败', isError: true);
      }
    }
  }

  /// 查看大图
  void _viewImageFullScreen(String imageUrl, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            title: Text('图片 ${index + 1}', style: const TextStyle(color: Colors.white)),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Image.network(
                imageUrl,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image, color: Colors.white54, size: 64),
                        SizedBox(height: 8),
                        Text('图片加载失败', style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('网络知识'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索',
            onPressed: () {
              Navigator.of(context).pushNamed('/search');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '抓取内容'),
            Tab(text: '已保存'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ==================== 抓取内容标签 ====================
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // URL输入栏
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '输入网页地址',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _urlController,
                                keyboardType: TextInputType.url,
                                decoration: InputDecoration(
                                  hintText: 'https://example.com',
                                  prefixIcon: const Icon(Icons.language),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                ),
                                onSubmitted: (_) => _fetchWebContent(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              height: 48,
                              child: FilledButton.icon(
                                onPressed: _isFetching ? null : _fetchWebContent,
                                icon: _isFetching
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.download, size: 20),
                                label: Text(_isFetching ? '抓取中' : '抓取'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 错误信息
                if (_errorMessage != null)
                  Card(
                    color: AppColors.error.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.error),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => setState(() => _errorMessage = null),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 抓取结果
                if (_fetchResult != null) ...[
                  // 网页标题
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.article, color: theme.colorScheme.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '网页标题',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _fetchResult!.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '来源: ${_fetchResult!.sourceUrl}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '抓取时间: ${formatDateTime(_fetchResult!.fetchTime)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 操作按钮
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.auto_stories, size: 18, color: Colors.blue),
                            label: const Text('保存为知识点'),
                            onPressed: _saveAsKnowledgePoint,
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.edit_note, size: 18, color: Colors.green),
                            label: const Text('保存为笔记'),
                            onPressed: _saveAsNote,
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.copy, size: 18, color: Colors.orange),
                            label: const Text('复制文本'),
                            onPressed: _copyTextContent,
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.print, size: 18, color: Colors.purple),
                            label: const Text('选取打印'),
                            onPressed: _showPrintSelectionDialog,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 主要文本内容
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.text_fields, color: theme.colorScheme.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '文本内容',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_fetchResult!.textContent.length} 字符',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 8),
                          SelectableText(
                            _fetchResult!.textContent,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.8,
                              color: isDark ? Colors.grey[200] : Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 图片列表
                  if (_fetchResult!.imageUrls.isNotEmpty) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.image, color: theme.colorScheme.primary, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '图片列表',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${_fetchResult!.imageUrls.length} 张',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemCount: _fetchResult!.imageUrls.length,
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  onTap: () => _viewImageFullScreen(
                                    _fetchResult!.imageUrls[index],
                                    index,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      _fetchResult!.imageUrls[index],
                                      fit: BoxFit.cover,
                                      height: 100,
                                      width: double.infinity,
                                      loadingBuilder: (context, child, progress) {
                                        if (progress == null) return child;
                                        return Container(
                                          height: 100,
                                          color: isDark
                                              ? Colors.grey[800]
                                              : Colors.grey[200],
                                          child: const Center(
                                            child: SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          height: 100,
                                          color: isDark
                                              ? Colors.grey[800]
                                              : Colors.grey[200],
                                          child: const Center(
                                            child: Icon(Icons.broken_image, color: AppColors.textHint),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],

                // 空状态提示（未抓取时）
                if (_fetchResult == null && !_isFetching && _errorMessage == null)
                  AppEmptyState(
                    icon: Icons.public,
                    message: '输入网址并点击"抓取"按钮\n获取网页知识内容',
                  ),
              ],
            ),
          ),

          // ==================== 已保存标签 ====================
          _isLoadingSaved
              ? const Center(child: CircularProgressIndicator())
              : _savedItems.isEmpty
                  ? AppEmptyState(
                      icon: Icons.bookmark_border,
                      message: '暂无已保存的网络知识',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _savedItems.length,
                      itemBuilder: (context, index) {
                        final item = _savedItems[index];
                        final title = item['title'] as String? ?? '无标题';
                        final description = item['description'] as String? ?? '';
                        final subject = item['subject'] as String? ?? '';
                        final createdAt = item['created_at'] as String? ?? '';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () => _viewSavedItemDetail(item),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.teal.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          '网络知识',
                                          style: TextStyle(
                                            color: Colors.teal,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      if (subject.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: getSubjectColor(subject).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            subject,
                                            style: TextStyle(
                                              color: getSubjectColor(subject),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 20),
                                        color: AppColors.error,
                                        onPressed: () => _deleteSavedItem(item['id'] as int),
                                        tooltip: '删除',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    title,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (description.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      description,
                                      style: TextStyle(
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    createdAt,
                                    style: TextStyle(
                                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ],
      ),
    );
  }
}
