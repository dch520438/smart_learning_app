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

  late TabController _tabController;

  // 导入类型
  String _selectedType = BatchImportService.typeKnowledgePoint;

  // 数据格式
  DataFormat _dataFormat = DataFormat.json;

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

    // 加载模板
    _loadTemplate();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _dataController.dispose();
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

      if (_dataFormat == DataFormat.json) {
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
          SnackBar(content: Text('数据验证通过，共 ${result.validCount} 条记录')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('数据验证完成，有效: ${result.validCount} 条，错误: ${result.errorCount} 条'),
            backgroundColor: result.validCount == 0 ? Colors.red : null,
          ),
        );
      }
    } catch (e) {
      setState(() => _isValidating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('验证失败: $e')),
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

    // 确认对话框
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
        SnackBar(content: Text('导入失败: $e')),
      );
    }
  }

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
      _validationResult = null;
      _importResult = null;
    });
  }

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
          // JSON Tab
          _buildJsonCsvTab(),
          // CSV Tab
          _buildJsonCsvTab(),
          // 文档 Tab
          _buildDocumentTab(),
        ],
      ),
    );
  }

  Widget _buildJsonCsvTab() {
    return Column(
      children: [
        // 类型选择
        _buildTypeSelector(),

        // 数据输入区域
        Expanded(
          child: _buildDataInputArea(),
        ),

        // 验证结果
        if (_validationResult != null) _buildValidationResult(),

        // 导入结果
        if (_importResult != null) _buildImportResult(),

        // 操作按钮
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildDocumentTab() {
    return Column(
      children: [
        // 类型选择
        _buildTypeSelector(),

        // 文档导入区域
        Expanded(
          child: _buildDocumentImportArea(),
        ),

        // 验证结果
        if (_validationResult != null) _buildValidationResult(),

        // 导入结果
        if (_importResult != null) _buildImportResult(),

        // 操作按钮
        _buildDocumentActionButtons(),
      ],
    );
  }

  Widget _buildDocumentImportArea() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 说明卡片
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.upload_file,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '支持导入 Word、Excel、PDF、TXT 等文档',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DocumentImportService.getSupportedTypesDescription(),
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isLoadingDocument ? null : _pickDocument,
                    icon: _isLoadingDocument
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.folder_open),
                    label: Text(_isLoadingDocument ? '读取中...' : '选择文档'),
                  ),
                ],
              ),
            ),
          ),

          // 已选择的文档信息
          if (_documentResult != null) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.description),
                title: Text(_documentResult!.fileName),
                subtitle: Text('大小: ${_documentResult!.formattedSize}'),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _documentResult = null;
                      _dataController.clear();
                      _validationResult = null;
                    });
                  },
                ),
              ),
            ),
          ],

          // 文档内容编辑区域
          if (_documentResult != null) ...[
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            '文档内容（可编辑）',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _parseDocumentToQuestions,
                            icon: const Icon(Icons.auto_fix_high, size: 16),
                            label: const Text('智能解析'),
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
                        decoration: const InputDecoration(
                          hintText: '文档内容将显示在这里，您可以编辑后导入...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

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
        SnackBar(content: Text('导入失败: $e')),
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

    final questions = _documentService.parseDocumentContent(
      _dataController.text,
      type: _selectedType,
    );

    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未能从文档中解析出题目，请检查格式')),
      );
      return;
    }

    // 转换为JSON格式显示
    final jsonContent = const JsonEncoder.withIndent('  ').convert(questions);
    setState(() {
      _dataController.text = jsonContent;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已解析出 ${questions.length} 道题目，请验证后导入')),
    );
  }

  Widget _buildDocumentActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isValidating || _documentResult == null ? null : _validateData,
                icon: _isValidating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle),
                label: const Text('验证数据'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton.icon(
                onPressed: _isImporting || _validationResult == null || !_validationResult!.isValid
                    ? null
                    : _importData,
                icon: _isImporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload),
                label: const Text('确认导入'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Row(
        children: [
          const Text('导入类型：', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          // 工具栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.content_paste),
                  tooltip: '粘贴',
                  onPressed: _pasteData,
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: '复制模板',
                  onPressed: _copyTemplate,
                ),
                IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: '清空',
                  onPressed: _clearData,
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.help_outline, size: 16),
                  label: const Text('查看模板'),
                  onPressed: () => _showTemplateDialog(),
                ),
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
              decoration: InputDecoration(
                hintText: _dataFormat == DataFormat.json
                    ? '在此粘贴 JSON 数据...'
                    : '在此粘贴 CSV 数据...',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(12),
              ),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationResult() {
    final result = _validationResult!;
    final hasErrors = result.errorCount > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasErrors
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasErrors ? Icons.warning : Icons.check_circle,
                color: hasErrors
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '验证结果',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: hasErrors
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('有效数据: ${result.validCount} 条'),
          if (hasErrors) Text('错误数据: ${result.errorCount} 条'),
          if (hasErrors && result.errors.isNotEmpty)
            TextButton(
              onPressed: () => _showErrorDetails(),
              child: const Text('查看错误详情'),
            ),
        ],
      ),
    );
  }

  Widget _buildImportResult() {
    final result = _importResult!;
    final hasErrors = result.failCount > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasErrors
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasErrors ? Icons.info : Icons.check_circle,
                color: hasErrors
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.tertiary,
              ),
              const SizedBox(width: 8),
              Text(
                '导入结果',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: hasErrors
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('成功: ${result.successCount} 条'),
          Text('失败: ${result.failCount} 条'),
          Text('成功率: ${result.successRate.toStringAsFixed(1)}%'),
          if (hasErrors && result.errors.isNotEmpty)
            TextButton(
              onPressed: () => _showImportErrorDetails(),
              child: const Text('查看错误详情'),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isValidating ? null : _validateData,
                icon: _isValidating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(_isValidating ? '验证中...' : '验证数据'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton.icon(
                onPressed: (_isImporting ||
                        _validationResult == null ||
                        _validationResult!.validData.isEmpty)
                    ? null
                    : _importData,
                icon: _isImporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          FilledButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: template));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('模板已复制到剪贴板')),
              );
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
                leading: CircleAvatar(
                  radius: 12,
                  child: Text('${error.rowNum}'),
                ),
                title: Text(error.message),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
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
                leading: const Icon(Icons.error, color: Colors.red),
                title: Text(
                  _importResult!.errors[index],
                  style: const TextStyle(fontSize: 12),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

enum DataFormat { json, csv }
