import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/batch_import_service.dart';
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
  final TextEditingController _dataController = TextEditingController();

  late TabController _tabController;

  // 导入类型
  String _selectedType = BatchImportService.typeKnowledgePoint;

  // 数据格式
  DataFormat _dataFormat = DataFormat.json;

  // 状态
  bool _isValidating = false;
  bool _isImporting = false;
  ValidationResult? _validationResult;
  ImportResult? _importResult;

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
    _tabController = TabController(length: 2, vsync: this);
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
        _dataFormat = _tabController.index == 0 ? DataFormat.json : DataFormat.csv;
        _validationResult = null;
        _importResult = null;
        _loadTemplate();
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
      showSnackBar(context, '请输入要导入的数据', isError: true);
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
        showSnackBar(context, '数据验证通过，共 ${result.validCount} 条记录');
      } else {
        showSnackBar(
          context,
          '数据验证完成，有效: ${result.validCount} 条，错误: ${result.errorCount} 条',
          isError: result.validCount == 0,
        );
      }
    } catch (e) {
      setState(() => _isValidating = false);
      showSnackBar(context, '验证失败: $e', isError: true);
    }
  }

  Future<void> _importData() async {
    if (_validationResult == null || _validationResult!.validData.isEmpty) {
      showSnackBar(context, '请先验证数据', isError: true);
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
        showSnackBar(context, '导入成功！共导入 ${result.successCount} 条数据');
      } else {
        showSnackBar(
          context,
          '导入完成：成功 ${result.successCount} 条，失败 ${result.failCount} 条',
          isError: result.successCount == 0,
        );
      }
    } catch (e) {
      setState(() => _isImporting = false);
      showSnackBar(context, '导入失败: $e', isError: true);
    }
  }

  void _copyTemplate() {
    final template = _dataFormat == DataFormat.json
        ? _importService.getJsonTemplate(_selectedType)
        : _importService.getCsvTemplate(_selectedType);

    Clipboard.setData(ClipboardData(text: template));
    showSnackBar(context, '模板已复制到剪贴板');
  }

  void _pasteData() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null) {
      _dataController.text = clipboardData!.text!;
      showSnackBar(context, '数据已粘贴');
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
          ],
        ),
      ),
      body: Column(
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
              showSnackBar(context, '模板已复制到剪贴板');
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
