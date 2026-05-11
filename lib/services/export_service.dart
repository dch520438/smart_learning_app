import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

import 'database_service.dart';
import 'storage_service.dart';

/// 数据导入导出服务
/// 支持将数据导出为 JSON 文件，从 JSON 文件导入，以及选择性导出和数据恢复
class ExportService {
  // 单例模式
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  final DatabaseService _dbService = DatabaseService();
  final StorageService _storageService = StorageService();

  // 日志输出
  void _log(String message) {
    // ignore: avoid_print
    print('[ExportService] $message');
  }

  // 模块名称常量
  static const String moduleKnowledgePoints = 'knowledge_points';
  static const String moduleNotes = 'notes';
  static const String moduleMustRemembers = 'must_remembers';
  static const String moduleWrongQuestions = 'wrong_questions';
  static const String moduleMotherQuestions = 'mother_questions';
  static const String moduleExams = 'exams';
  static const String moduleExamResults = 'exam_results';
  static const String moduleStudyRecords = 'study_records';
  static const String moduleUserProfiles = 'user_profiles';
  static const String moduleMindMapData = 'mind_map_data';

  /// 所有可用模块
  static const List<String> allModules = [
    moduleKnowledgePoints,
    moduleNotes,
    moduleMustRemembers,
    moduleWrongQuestions,
    moduleMotherQuestions,
    moduleExams,
    moduleExamResults,
    moduleStudyRecords,
    moduleUserProfiles,
    moduleMindMapData,
  ];

  /// 模块中文名称映射
  static const Map<String, String> moduleNames = {
    moduleKnowledgePoints: '知识点',
    moduleNotes: '笔记',
    moduleMustRemembers: '必记内容',
    moduleWrongQuestions: '错题本',
    moduleMotherQuestions: '母题集',
    moduleExams: '考试',
    moduleExamResults: '考试结果',
    moduleStudyRecords: '学习记录',
    moduleUserProfiles: '用户资料',
    moduleMindMapData: '思维导图',
  };

  /// 获取模块中文名称
  static String getModuleName(String module) {
    return moduleNames[module] ?? module;
  }

  // ==================== 导出功能 ====================

  /// 导出所有数据为JSON文件
  /// [fileName] 自定义文件名（可选）
  /// 返回导出文件的路径
  Future<ExportResult> exportAllToJson({String? fileName}) async {
    _log('开始导出所有数据...');
    try {
      // 获取所有数据
      final data = await _dbService.exportAllToJson();
      _log('成功获取数据，共 ${data.length} 个模块');

      // 生成文件名
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final finalFileName = fileName ?? 'smart_learning_backup_$timestamp.json';

      // 生成JSON字符串
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      _log('JSON数据生成完成，大小: ${jsonString.length} 字符');

      // 在 Linux 平台上使用文件选择器
      if (Platform.isLinux) {
        _log('Linux平台，使用文件选择器导出');
        return await _exportOnLinux(jsonString, finalFileName, allModules);
      }

      // 其他平台：保存到导出目录
      try {
        final filePath = await _storageService.getExportPath(fileName: finalFileName);
        await _storageService.saveFileFromString(
          jsonString,
          finalFileName,
        );
        _log('文件保存成功: $filePath');

        // 计算导出统计
        final stats = <String, int>{};
        for (final module in allModules) {
          if (data.containsKey(module)) {
            final list = data[module] as List;
            stats[module] = list.length;
          }
        }

        return ExportResult(
          success: true,
          filePath: filePath,
          fileName: finalFileName,
          stats: stats,
          totalRecords: stats.values.fold(0, (sum, count) => sum + count),
        );
      } catch (e) {
        _log('存储服务保存失败，尝试备用方案: $e');
        // 如果存储服务失败，尝试使用文件选择器保存
        return await _exportWithFilePicker(jsonString, finalFileName, allModules);
      }
    } catch (e, stackTrace) {
      _log('导出失败: $e');
      _log('堆栈: $stackTrace');
      return ExportResult(
        success: false,
        errorMessage: '导出失败: $e',
      );
    }
  }

  /// 选择性导出指定模块的数据
  /// [modules] 要导出的模块列表
  /// [fileName] 自定义文件名（可选）
  /// 返回导出结果
  Future<ExportResult> exportModulesToJson(
    List<String> modules, {
    String? fileName,
  }) async {
    _log('开始选择性导出，模块: $modules');
    try {
      // 验证模块名称
      final validModules = modules.where((m) => allModules.contains(m)).toList();
      if (validModules.isEmpty) {
        _log('错误: 没有有效的模块可供导出');
        return ExportResult(
          success: false,
          errorMessage: '没有有效的模块可供导出',
        );
      }

      // 获取指定模块数据
      final data = await _dbService.exportModulesToJson(validModules);
      _log('成功获取数据，共 ${data.length} 个模块');

      // 生成文件名
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final moduleSuffix = validModules.length <= 3
          ? validModules.join('_')
          : '${validModules.length}_modules';
      final finalFileName =
          fileName ?? 'smart_learning_${moduleSuffix}_$timestamp.json';

      // 生成JSON字符串
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      _log('JSON数据生成完成，大小: ${jsonString.length} 字符');

      // 在 Linux 平台上使用文件选择器
      if (Platform.isLinux) {
        _log('Linux平台，使用文件选择器导出');
        return await _exportOnLinux(jsonString, finalFileName, validModules);
      }

      // 其他平台：尝试保存到导出目录，失败则使用文件选择器
      try {
        final filePath = await _storageService.getExportPath(fileName: finalFileName);
        await _storageService.saveFileFromString(
          jsonString,
          finalFileName,
        );
        _log('文件保存成功: $filePath');

        // 计算导出统计
        final stats = <String, int>{};
        for (final module in validModules) {
          if (data.containsKey(module)) {
            final list = data[module] as List;
            stats[module] = list.length;
          }
        }

        return ExportResult(
          success: true,
          filePath: filePath,
          fileName: finalFileName,
          stats: stats,
          totalRecords: stats.values.fold(0, (sum, count) => sum + count),
          exportedModules: validModules,
        );
      } catch (e) {
        _log('存储服务保存失败，尝试使用文件选择器: $e');
        return await _exportWithFilePicker(jsonString, finalFileName, validModules);
      }
    } catch (e, stackTrace) {
      _log('导出失败: $e');
      _log('堆栈: $stackTrace');
      return ExportResult(
        success: false,
        errorMessage: '导出失败: $e',
      );
    }
  }

  /// Linux 平台导出方法
  /// 使用文件选择器让用户选择保存位置
  Future<ExportResult> _exportOnLinux(
    String jsonString,
    String defaultFileName,
    List<String> modules,
  ) async {
    _log('Linux导出开始，文件名: $defaultFileName');
    try {
      // 获取默认下载目录
      String? defaultDirectory;
      try {
        // 尝试获取下载目录
        final home = Platform.environment['HOME'];
        if (home != null) {
          defaultDirectory = '$home/Downloads';
          // 检查下载目录是否存在
          final downloadDir = Directory(defaultDirectory);
          if (!await downloadDir.exists()) {
            _log('下载目录不存在，使用HOME目录');
            defaultDirectory = home;
          }
        }
      } catch (e) {
        _log('获取默认目录失败: $e');
        // 忽略错误，使用默认行为
      }

      _log('默认目录: $defaultDirectory');

      // 使用文件选择器让用户选择保存位置
      String? outputPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择保存位置',
        initialDirectory: defaultDirectory,
      );

      if (outputPath == null) {
        _log('用户取消了导出操作');
        return ExportResult(
          success: false,
          errorMessage: '用户取消了导出操作',
        );
      }

      _log('用户选择目录: $outputPath');

      // 构建完整文件路径
      final filePath = '$outputPath/$defaultFileName';
      _log('完整文件路径: $filePath');

      // 写入文件
      final result = await _writeFileWithRetry(filePath, jsonString);

      if (!result.success) {
        return result;
      }

      // 计算导出统计
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final stats = <String, int>{};
      for (final module in modules) {
        if (data.containsKey(module)) {
          final list = data[module] as List;
          stats[module] = list.length;
        }
      }

      return ExportResult(
        success: true,
        filePath: filePath,
        fileName: defaultFileName,
        stats: stats,
        totalRecords: stats.values.fold(0, (sum, count) => sum + count),
        exportedModules: modules,
      );
    } catch (e, stackTrace) {
      _log('Linux 导出失败: $e');
      _log('堆栈: $stackTrace');
      return ExportResult(
        success: false,
        errorMessage: '导出失败: $e',
      );
    }
  }

  /// 使用文件选择器保存文件（跨平台备用方案）
  Future<ExportResult> _exportWithFilePicker(
    String jsonString,
    String defaultFileName,
    List<String> modules,
  ) async {
    _log('使用文件选择器保存，文件名: $defaultFileName');
    try {
      // 使用文件选择器保存
      String? result = await FilePicker.platform.saveFile(
        dialogTitle: '保存导出文件',
        fileName: defaultFileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null) {
        _log('用户取消了保存操作');
        return ExportResult(
          success: false,
          errorMessage: '用户取消了导出操作',
        );
      }

      // 确保文件扩展名
      if (!result.endsWith('.json')) {
        result = '$result.json';
      }

      _log('用户选择路径: $result');

      // 写入文件
      final writeResult = await _writeFileWithRetry(result, jsonString);

      if (!writeResult.success) {
        return writeResult;
      }

      // 计算导出统计
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final stats = <String, int>{};
      for (final module in modules) {
        if (data.containsKey(module)) {
          final list = data[module] as List;
          stats[module] = list.length;
        }
      }

      return ExportResult(
        success: true,
        filePath: result,
        fileName: defaultFileName,
        stats: stats,
        totalRecords: stats.values.fold(0, (sum, count) => sum + count),
        exportedModules: modules,
      );
    } catch (e, stackTrace) {
      _log('文件选择器保存失败: $e');
      _log('堆栈: $stackTrace');
      return ExportResult(
        success: false,
        errorMessage: '保存失败: $e',
      );
    }
  }

  /// 带重试的文件写入方法
  Future<ExportResult> _writeFileWithRetry(
    String filePath,
    String content, {
    int maxRetries = 3,
  }) async {
    File? file;
    int retries = 0;

    while (retries < maxRetries) {
      try {
        file = File(filePath);

        // 确保目录存在
        final dir = file.parent;
        if (!await dir.exists()) {
          _log('创建目录: ${dir.path}');
          await dir.create(recursive: true);
        }

        // 写入文件
        _log('开始写入文件...');
        await file.writeAsString(content);
        _log('文件写入完成');

        // 验证文件是否写入成功
        if (await file.exists()) {
          final fileSize = await file.length();
          _log('文件验证成功，大小: $fileSize 字节');
          return ExportResult(
            success: true,
            filePath: filePath,
            fileName: file.uri.pathSegments.last,
          );
        } else {
          _log('警告: 文件写入后不存在');
          retries++;
          if (retries < maxRetries) {
            _log('重试写入... ($retries/$maxRetries)');
            await Future.delayed(Duration(milliseconds: 100 * retries));
          }
        }
      } catch (e) {
        _log('写入文件失败: $e');
        retries++;
        if (retries < maxRetries) {
          _log('重试写入... ($retries/$maxRetries)');
          await Future.delayed(Duration(milliseconds: 100 * retries));
        } else {
          return ExportResult(
            success: false,
            errorMessage: '写入文件失败: $e',
          );
        }
      }
    }

    return ExportResult(
      success: false,
      errorMessage: '文件写入失败，已重试 $maxRetries 次',
    );
  }

  /// 导出数据为JSON字符串（不保存文件）
  Future<String> exportAllToJsonString() async {
    final data = await _dbService.exportAllToJson();
    return jsonEncode(data);
  }

  /// 导出指定模块数据为JSON字符串
  Future<String> exportModulesToJsonString(List<String> modules) async {
    final data = await _dbService.exportModulesToJson(modules);
    return jsonEncode(data);
  }

  // ==================== 导入功能 ====================

  /// 从JSON文件导入数据
  /// [filePath] JSON文件路径
  /// [mode] 导入模式：merge（合并）或 replace（替换）
  /// 返回导入结果
  Future<ImportResult> importFromJsonFile(
    String filePath, {
    ImportMode mode = ImportMode.merge,
  }) async {
    try {
      // 读取文件
      final jsonString = await _storageService.readFileAsString(filePath);
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

      return await _importFromJsonData(jsonData, mode: mode);
    } on FileNotFoundException {
      return ImportResult(
        success: false,
        errorMessage: '文件不存在: $filePath',
      );
    } catch (e) {
      return ImportResult(
        success: false,
        errorMessage: '导入失败: $e',
      );
    }
  }

  /// 从JSON字符串导入数据
  /// [jsonString] JSON字符串
  /// [mode] 导入模式
  /// 返回导入结果
  Future<ImportResult> importFromJsonString(
    String jsonString, {
    ImportMode mode = ImportMode.merge,
  }) async {
    try {
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      return await _importFromJsonData(jsonData, mode: mode);
    } catch (e) {
      return ImportResult(
        success: false,
        errorMessage: '导入失败: $e',
      );
    }
  }

  /// 从JSON数据导入（内部方法）
  Future<ImportResult> _importFromJsonData(
    Map<String, dynamic> jsonData, {
    ImportMode mode = ImportMode.merge,
  }) async {
    try {
      Map<String, int> stats;

      if (mode == ImportMode.replace) {
        // 替换模式：先清空再导入
        stats = await _dbService.restoreFromJson(jsonData);
      } else {
        // 合并模式：直接导入（冲突时替换）
        stats = await _dbService.importFromJson(jsonData);
      }

      final totalRecords = stats.values.fold(0, (sum, count) => sum + count);

      return ImportResult(
        success: true,
        stats: stats,
        totalRecords: totalRecords,
        mode: mode,
      );
    } catch (e) {
      return ImportResult(
        success: false,
        errorMessage: '数据导入处理失败: $e',
      );
    }
  }

  /// Linux 平台选择文件并导入
  Future<ImportResult> importWithFilePicker({
    ImportMode mode = ImportMode.merge,
  }) async {
    try {
      // 使用文件选择器选择JSON文件
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: '选择要导入的JSON文件',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) {
        return ImportResult(
          success: false,
          errorMessage: '用户取消了导入操作',
        );
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        return ImportResult(
          success: false,
          errorMessage: '无法获取文件路径',
        );
      }

      return await importFromJsonFile(filePath, mode: mode);
    } catch (e) {
      return ImportResult(
        success: false,
        errorMessage: '导入失败: $e',
      );
    }
  }

  // ==================== 数据恢复 ====================

  /// 从备份文件恢复数据
  /// [backupPath] 备份文件路径
  /// 返回恢复结果
  Future<ImportResult> restoreFromBackup(String backupPath) async {
    try {
      // 读取备份数据
      final jsonString = await _storageService.readFileAsString(backupPath);
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

      // 验证备份格式
      if (!jsonData.containsKey('export_version')) {
        return ImportResult(
          success: false,
          errorMessage: '无效的备份文件格式',
        );
      }

      // 执行恢复（先清空再导入）
      final stats = await _dbService.restoreFromJson(jsonData);
      final totalRecords = stats.values.fold(0, (sum, count) => sum + count);

      return ImportResult(
        success: true,
        stats: stats,
        totalRecords: totalRecords,
        mode: ImportMode.replace,
        backupVersion: jsonData['export_version']?.toString(),
        backupTime: jsonData['export_time'] as String?,
      );
    } on FileNotFoundException {
      return ImportResult(
        success: false,
        errorMessage: '备份文件不存在: $backupPath',
      );
    } catch (e) {
      return ImportResult(
        success: false,
        errorMessage: '恢复失败: $e',
      );
    }
  }

  /// 创建完整备份
  /// [backupName] 备份名称（可选）
  /// 返回备份文件路径
  Future<String> createBackup({String? backupName}) async {
    final data = await _dbService.exportAllToJson();
    return await _storageService.createBackup(data, backupName: backupName);
  }

  /// 列出所有可用备份
  Future<List<BackupInfo>> listBackups() async {
    return await _storageService.listBackups();
  }

  /// 删除备份
  Future<bool> deleteBackup(String backupPath) async {
    return await _storageService.deleteBackup(backupPath);
  }

  // ==================== 数据验证 ====================

  /// 验证JSON文件是否为有效的备份文件
  Future<ValidationResult> validateBackupFile(String filePath) async {
    try {
      final jsonString = await _storageService.readFileAsString(filePath);
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

      // 检查必要字段
      if (!jsonData.containsKey('export_version')) {
        return ValidationResult(
          isValid: false,
          errorMessage: '缺少版本信息',
        );
      }

      if (!jsonData.containsKey('export_time')) {
        return ValidationResult(
          isValid: false,
          errorMessage: '缺少导出时间',
        );
      }

      // 统计各模块数据量
      final moduleStats = <String, int>{};
      for (final module in allModules) {
        if (jsonData.containsKey(module)) {
          final list = jsonData[module] as List;
          moduleStats[module] = list.length;
        }
      }

      final totalRecords =
          moduleStats.values.fold(0, (sum, count) => sum + count);

      return ValidationResult(
        isValid: true,
        version: jsonData['export_version']?.toString(),
        exportTime: jsonData['export_time'] as String?,
        appVersion: jsonData['app_version'] as String?,
        moduleStats: moduleStats,
        totalRecords: totalRecords,
      );
    } on FileNotFoundException {
      return ValidationResult(
        isValid: false,
        errorMessage: '文件不存在',
      );
    } catch (e) {
      return ValidationResult(
        isValid: false,
        errorMessage: '文件格式无效: $e',
      );
    }
  }

  /// 获取导出文件大小
  Future<int> getExportFileSize(String filePath) async {
    return await _storageService.getFileSize(filePath);
  }

  /// 获取格式化的文件大小
  Future<String> getFormattedFileSize(String filePath) async {
    final size = await getExportFileSize(filePath);
    return _storageService.formatFileSize(size);
  }

  // ==================== 工具方法 ====================

  /// 格式化导入统计信息
  String formatImportStats(Map<String, int> stats) {
    final buffer = StringBuffer();
    for (final entry in stats.entries) {
      final moduleName = getModuleName(entry.key);
      buffer.writeln('$moduleName: ${entry.value} 条');
    }
    return buffer.toString().trim();
  }

  /// 获取各模块数据统计
  Future<Map<String, int>> getModuleStats() async {
    return await _dbService.getDatabaseStats();
  }

  /// 清理过期备份
  /// [keepDays] 保留最近几天的备份
  Future<int> cleanOldBackups({int keepDays = 30}) async {
    return await _storageService.cleanOldBackups(keepDays: keepDays);
  }

  /// 获取导出目录路径
  Future<String> getExportDirectoryPath() async {
    return await _storageService.getExportDir();
  }

  /// 获取导入目录路径
  Future<String> getImportDirectoryPath() async {
    return await _storageService.getImportDir();
  }

  /// 检查当前平台是否支持 share_plus 分享
  bool get isShareSupported {
    // Linux 不支持 share_plus
    return !Platform.isLinux;
  }
}

/// 导出结果
class ExportResult {
  /// 是否成功
  final bool success;

  /// 导出文件路径
  final String? filePath;

  /// 导出文件名
  final String? fileName;

  /// 各模块导出统计
  final Map<String, int>? stats;

  /// 总导出记录数
  final int totalRecords;

  /// 导出的模块列表
  final List<String>? exportedModules;

  /// 错误信息
  final String? errorMessage;

  const ExportResult({
    required this.success,
    this.filePath,
    this.fileName,
    this.stats,
    this.totalRecords = 0,
    this.exportedModules,
    this.errorMessage,
  });

  /// 获取格式化的统计信息
  String get formattedStats {
    if (stats == null || stats!.isEmpty) return '无数据';
    final buffer = StringBuffer();
    for (final entry in stats!.entries) {
      final moduleName = ExportService.getModuleName(entry.key);
      buffer.writeln('$moduleName: ${entry.value} 条');
    }
    buffer.writeln('总计: $totalRecords 条');
    return buffer.toString().trim();
  }
}

/// 导入结果
class ImportResult {
  /// 是否成功
  final bool success;

  /// 各模块导入统计
  final Map<String, int>? stats;

  /// 总导入记录数
  final int totalRecords;

  /// 导入模式
  final ImportMode mode;

  /// 备份版本
  final String? backupVersion;

  /// 备份时间
  final String? backupTime;

  /// 错误信息
  final String? errorMessage;

  const ImportResult({
    required this.success,
    this.stats,
    this.totalRecords = 0,
    this.mode = ImportMode.merge,
    this.backupVersion,
    this.backupTime,
    this.errorMessage,
  });

  /// 获取格式化的统计信息
  String get formattedStats {
    if (stats == null || stats!.isEmpty) return '无数据导入';
    final buffer = StringBuffer();
    buffer.writeln('导入模式: ${mode == ImportMode.merge ? '合并' : '替换'}');
    for (final entry in stats!.entries) {
      final moduleName = ExportService.getModuleName(entry.key);
      buffer.writeln('$moduleName: ${entry.value} 条');
    }
    buffer.writeln('总计: $totalRecords 条');
    return buffer.toString().trim();
  }
}

/// 导入模式
enum ImportMode {
  /// 合并模式：保留现有数据，冲突时替换
  merge,

  /// 替换模式：清空现有数据后导入
  replace,
}

/// 验证结果
class ValidationResult {
  /// 是否有效
  final bool isValid;

  /// 错误信息
  final String? errorMessage;

  /// 备份版本
  final String? version;

  /// 导出时间
  final String? exportTime;

  /// 应用版本
  final String? appVersion;

  /// 各模块数据统计
  final Map<String, int>? moduleStats;

  /// 总记录数
  final int totalRecords;

  const ValidationResult({
    required this.isValid,
    this.errorMessage,
    this.version,
    this.exportTime,
    this.appVersion,
    this.moduleStats,
    this.totalRecords = 0,
  });

  /// 获取格式化的验证信息
  String get formattedInfo {
    if (!isValid) return '无效: $errorMessage';
    final buffer = StringBuffer();
    buffer.writeln('备份验证通过');
    if (version != null) buffer.writeln('版本: $version');
    if (appVersion != null) buffer.writeln('应用版本: $appVersion');
    if (exportTime != null) buffer.writeln('导出时间: $exportTime');
    if (moduleStats != null && moduleStats!.isNotEmpty) {
      buffer.writeln('数据统计:');
      for (final entry in moduleStats!.entries) {
        final moduleName = ExportService.getModuleName(entry.key);
        buffer.writeln('  $moduleName: ${entry.value} 条');
      }
      buffer.writeln('  总计: $totalRecords 条');
    }
    return buffer.toString().trim();
  }
}
