import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/batch_import_service.dart';
import '../../services/document_import_service.dart';
import '../../widgets/common_widgets.dart';

// ============================================================
// BatchImportScreen - 批量导入页面
// ============================================================

class BatchImportScreen extends StatefulWidget {
  final String? initialType;

  const BatchImportScreen({super.key, this.initialType});

  @override
  State<BatchImportScreen> createState() => _BatchImportScreenState();
}

class _BatchImportScreenState extends State<BatchImportScreen>
    with SingleTickerProviderStateMixin {
  final BatchImportService _importService = BatchImportService();
  final DocumentImportService _documentService = DocumentImportService();
  final TextEditingController _dataController = TextEditingController();
  final TextEditingController _markerController = TextEditingController(text: '【题目');

  late TabController _tabController;

  // 导入类型
  String _selectedType = BatchImportService.typeKnowledgePoint;

  // 数据格式
  DataFormat _dataFormat = DataFormat.json;

  // 文档拆分方式
  SplitMode _splitMode = SplitMode.byMarker;

  // 状态
  bool _isValidating = false;
  bool _isImporting = false;
  bool _isLoadingDocument = false;
  ValidationResult? _validationResult;
  ImportResult? _importResult;

  // 文档导入结果
  DocumentImportResult? _documentResult;

  // 可用的导入类型
  final List<Map<String, String>> _importTypes = [
    {'value': BatchImportService.typeKnowledgePoint, 'label': '知识点'},
    {'value': BatchImportService.typeMustRemember, 'label': '必记必背'},
    {'value': BatchImportService.typeWrongQuestion, 'label': '错题'},
    {'value': BatchImportService.typeMotherQuestion, 'label': '母题'},
    {'value': BatchImportService.typeNote, 'label': '学习笔记'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);

    if (widget.initialType != null) {
      _selectedType = widget.initialType!;
    }

    _loadTemplate();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _dataController.dispose();
    _markerController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      setState(() {
        if (_tabController.index == 0) {
          _dataFormat = DataFormat.json;
        } else if (_tabController.index == 1) {
          _dataFormat = DataFormat.csv;
        }
        _validationResult = null;
        _importResult = null;
        if (_tabController.index < 2) {
          _loadTemplate();
        }
      });
    }
  }

  void _loadTemplate() {
    if (_dataFormat == DataFormat.json) {
      _dataController.text = _importService.getJsonTemplate(_selectedType);
    } else {
      _dataController.text = _importService.getCsvTemplate(_selectedType);
    }
  }

  void _onTypeChanged(String? value) {
    if (value != null) {
      setState(() {
        _selectedType = value;
        _validationResult = null;
        _importResult = null;
        _loadTemplate();
      });
    }
  }

  // ==================== 验证和导入 ====================

  Future<void> _validateData() async {
    if (_dataController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入要导入的数据')),
      );
      return;
    }

    setState(() {
      _isValidating = true;
      _validationResult = null;
      _importResult = null;
    });

    try {
      List<Map<String, dynamic>> data;

      if (_tabController.index == 2) {
        // 文档 tab：直接解析为 JSON 格式
        data = _importService.parseJsonData(_dataController.text, _selectedType);
      } else if (_dataFormat == DataFormat.json) {
        data = _importService.parseJsonData(_dataController.text, _selectedType);
      } else {
        data = _importService.parseCsvData(_dataController.text, _selectedType);
      }

      final result = _importService.validateData(data, _selectedType);

      setState(() {
        _validationResult = result;
        _isValidating = false;
      });

      if (result.isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('验证通过，共 ${result.validCount} 条记录，可以导入')),
        );
      } else if (result.validCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('有效: ${result.validCount} 条，错误: ${result.errorCount} 条，可导入有效数据')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('验证失败，请检查数据格式'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      setState(() => _isValidating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('验证失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _importData() async {
    if (_validationResult == null || _validationResult!.validData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先验证数据')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认导入'),
        content: Text(
          '确定要导入 ${_validationResult!.validCount} 条${BatchImportService.getTypeDisplayName(_selectedType)}数据吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认导入'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isImporting = true);

    try {
      final result = await _importService.importData(
        _validationResult!.validData,
        _selectedType,
      );

      setState(() {
        _importResult = result;
        _isImporting = false;
      });

      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入成功！共导入 ${result.successCount} 条数据')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入完成：成功 ${result.successCount} 条，失败 ${result.failCount} 条'),
            backgroundColor: result.successCount == 0 ? Colors.red : null,
          ),
        );
      }
    } catch (e) {
      setState(() => _isImporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ==================== 文档导入 ====================

  Future<void> _pickDocument() async {
    setState(() => _isLoadingDocument = true);
    try {
      final result = await _documentService.pickAndReadDocument();
      if (result != null) {
        setState(() {
          _documentResult = result;
          _dataController.text = result.content;
          _validationResult = null;
          _importResult = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('读取文档失败: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoadingDocument = false);
    }
  }

  void _parseDocumentToQuestions() {
    if (_dataController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文档内容为空')),
      );
      return;
    }

    final customMarker = _markerController.text.trim().isNotEmpty
        ? _markerController.text.trim()
        : null;

    final questions = _documentService.parseDocumentContent(
      _dataController.text,
      type: _selectedType,
      splitMode: _splitMode,
      customMarker: customMarker,
    );

    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未能解析出题目，请检查格式或更换拆分方式'), backgroundColor: Colors.red),
      );
      return;
    }

    // 将文档解析结果转换为 batch_import_service 兼容的格式
    final compatibleData = questions.map((q) {
      final Map<String, dynamic> item = {};
      item['title'] = q['title'] ?? '';
      item['content'] = q['content'] ?? '';
      item['subject'] = _selectedType == BatchImportService.typeKnowledgePoint ? '数学' : '数学';
      item['chapter'] = '';
      item['tags'] = [];
      item['examMethods'] = [];
      item['keyPoints'] = [];

      // 根据导入类型设置特定字段
      if (_selectedType == BatchImportService.typeWrongQuestion ||
          _selectedType == BatchImportService.typeMotherQuestion) {
        item['correctAnswer'] = q['answer'] ?? '';
        item['analysis'] = q['analysis'] ?? '';
        // 转换选项格式
        final rawOptions = q['options'];
        if (rawOptions is List && rawOptions.isNotEmpty) {
          item['options'] = rawOptions.map((o) {
            if (o is Map) return o;
            return {'label': '', 'content': o.toString()};
          }).toList();
        }
      }

      if (_selectedType == BatchImportService.typeMustRemember) {
        item['category'] = '公式';
      }

      return item;
    }).toList();

    final jsonContent = JsonEncoder.withIndent('  ').convert(compatibleData);
    setState(() {
      _dataController.text = jsonContent;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已解析出 ${questions.length} 条数据，请点击"验证数据"后导入')),
    );
  }

  void _loadDocumentTemplate() {
    final template = DocumentImportService.getDocumentTemplate();
    setState(() {
      _dataController.text = template;
      _documentResult = DocumentImportResult(
        fileName: '模板.txt',
        extension: 'txt',
        content: template,
        size: template.length,
      );
      _validationResult = null;
      _importResult = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已加载文档模板，可直接编辑内容')),
    );
  }

  // ==================== 工具方法 ====================

  void _copyTemplate() {
    final template = _dataFormat == DataFormat.json
        ? _importService.getJsonTemplate(_selectedType)
        : _importService.getCsvTemplate(_selectedType);
    Clipboard.setData(ClipboardData(text: template));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('模板已复制到剪贴板')),
    );
  }

  void _pasteData() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null) {
      _dataController.text = clipboardData!.text!;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('数据已粘贴')),
      );
    }
  }

  void _clearData() {
    setState(() {
      _dataController.clear();
      _documentResult = null;
      _validationResult = null;
      _importResult = null;
    });
  }

  // ==================== UI 构建 ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('批量导入'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.code), text: 'JSON'),
            Tab(icon: Icon(Icons.table_chart), text: 'CSV'),
            Tab(icon: Icon(Icons.upload_file), text: '文档'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildJsonCsvTab(),
          _buildJsonCsvTab(),
          _buildDocumentTab(),
        ],
      ),
    );
  }

  /// JSON/CSV Tab
  Widget _buildJsonCsvTab() {
    return Column(
      children: [
        _buildTypeSelector(),
        Expanded(child: _buildDataInputArea()),
        if (_validationResult != null) _buildValidationResult(),
        if (_importResult != null) _buildImportResult(),
        _buildActionButtons(),
      ],
    );
  }

  /// 文档 Tab - 使用 SingleChildScrollView 防止遮挡
  Widget _buildDocumentTab() {
    return Column(
      children: [
        _buildTypeSelector(),
        // 拆分方式选择 - 始终可见，不被遮挡
        _buildSplitOptions(),
        // 文档内容区域 - 可滚动
        Expanded(child: _buildDocumentContentArea()),
        if (_validationResult != null) _buildValidationResult(),
        if (_importResult != null) _buildImportResult(),
        _buildActionButtons(),
      ],
    );
  }

  /// 拆分方式选择 - 紧凑布局
  Widget _buildSplitOptions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('拆分：', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: SplitMode.values.map((mode) {
                  final isSelected = _splitMode == mode;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        DocumentImportService.getSplitModeDescription(mode),
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: isSelected,
                      visualDensity: VisualDensity.compact,
                      onSelected: (selected) {
                        if (selected) setState(() => _splitMode = mode);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // 自定义标识输入
          if (_splitMode == SplitMode.byMarker)
            SizedBox(
              width: 120,
              child: TextField(
                controller: _markerController,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  hintText: '如：【题目】',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 文档内容区域
  Widget _buildDocumentContentArea() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 工具栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.folder_open, size: 18),
                  tooltip: '选择文档',
                  onPressed: _isLoadingDocument ? null : _pickDocument,
                  visualDensity: VisualDensity.compact,
                ),
                if (_isLoadingDocument)
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                IconButton(
                  icon: const Icon(Icons.description, size: 18),
                  tooltip: '加载模板',
                  onPressed: _loadDocumentTemplate,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.auto_fix_high, size: 18),
                  tooltip: '智能解析',
                  onPressed: _parseDocumentToQuestions,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.content_paste, size: 18),
                  tooltip: '粘贴',
                  onPressed: _pasteData,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  tooltip: '清空',
                  onPressed: _clearData,
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                if (_documentResult != null)
                  Text(
                    _documentResult!.fileName,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          // 文本输入区域
          Expanded(
            child: TextField(
              controller: _dataController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: '在此粘贴或编辑文档内容...\n\n也可以点击上方"选择文档"导入文件，\n或点击"加载模板"查看示例格式。',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(12),
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /// 类型选择器
  Widget _buildTypeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          const Text('类型：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              items: _importTypes.map((type) {
                return DropdownMenuItem(
                  value: type['value'],
                  child: Text(type['label']!),
                );
              }).toList(),
              onChanged: _onTypeChanged,
            ),
          ),
        ],
      ),
    );
  }

  /// JSON/CSV 数据输入区域
  Widget _buildDataInputArea() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.content_paste, size: 18),
                  tooltip: '粘贴',
                  onPressed: _pasteData,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: '复制模板',
                  onPressed: _copyTemplate,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  tooltip: '清空',
                  onPressed: _clearData,
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.help_outline, size: 16),
                  label: const Text('查看模板'),
                  onPressed: () => _showTemplateDialog(),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
              ],
            ),
          ),
          Expanded(
            child: TextField(
              controller: _dataController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: _dataFormat == DataFormat.json
                    ? '在此粘贴 JSON 数据...'
                    : '在此粘贴 CSV 数据...',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(12),
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /// 验证结果
  Widget _buildValidationResult() {
    final result = _validationResult!;
    final hasErrors = result.errorCount > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: hasErrors
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            hasErrors ? Icons.warning : Icons.check_circle,
            color: hasErrors
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            '验证：有效 ${result.validCount} 条',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          if (hasErrors) ...[
            const SizedBox(width: 8),
            Text('错误 ${result.errorCount} 条', style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13)),
            const SizedBox(width: 4),
            InkWell(
              onTap: () => _showErrorDetails(),
              child: Text('详情', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 13, decoration: TextDecoration.underline)),
            ),
          ],
        ],
      ),
    );
  }

  /// 导入结果
  Widget _buildImportResult() {
    final result = _importResult!;
    final hasErrors = result.failCount > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: hasErrors
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            hasErrors ? Icons.info : Icons.check_circle,
            color: hasErrors
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.tertiary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            '导入：成功 ${result.successCount} 条',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          if (hasErrors) ...[
            const SizedBox(width: 8),
            Text('失败 ${result.failCount} 条', style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  /// 底部操作按钮
  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isValidating ? null : _validateData,
                icon: _isValidating
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check_circle, size: 18),
                label: Text(_isValidating ? '验证中...' : '验证数据'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton.icon(
                onPressed: (_isImporting || _validationResult == null || _validationResult!.validData.isEmpty)
                    ? null
                    : _importData,
                icon: _isImporting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload, size: 18),
                label: Text(_isImporting ? '导入中...' : '确认导入'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTemplateDialog() {
    final template = _dataFormat == DataFormat.json
        ? _importService.getJsonTemplate(_selectedType)
        : _importService.getCsvTemplate(_selectedType);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_dataFormat == DataFormat.json ? 'JSON' : 'CSV'} 模板'),
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 400),
          child: SingleChildScrollView(
            child: SelectableText(
              template,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
          FilledButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: template));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('模板已复制到剪贴板')));
            },
            child: const Text('复制'),
          ),
        ],
      ),
    );
  }

  void _showErrorDetails() {
    if (_validationResult == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('验证错误详情'),
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 400),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _validationResult!.errors.length,
            itemBuilder: (context, index) {
              final error = _validationResult!.errors[index];
              return ListTile(
                dense: true,
                leading: CircleAvatar(radius: 12, child: Text('${error.rowNum}')),
                title: Text(error.message, style: const TextStyle(fontSize: 13)),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
        ],
      ),
    );
  }

  void _showImportErrorDetails() {
    if (_importResult == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入错误详情'),
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 400),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _importResult!.errors.length,
            itemBuilder: (context, index) {
              return ListTile(
                dense: true,
                leading: const Icon(Icons.error, color: Colors.red, size: 18),
                title: Text(_importResult!.errors[index], style: const TextStyle(fontSize: 12)),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
        ],
      ),
    );
  }
}

enum DataFormat { json, csv }
