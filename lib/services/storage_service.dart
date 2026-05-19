import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// 文件存储服务
/// 管理应用附件文件的存储、读取、删除，以及备份文件的创建和恢复
class StorageService {
  // 单例模式
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // 目录名称常量
  static const String _attachmentDir = 'attachments';
  static const String _imageDir = 'images';
  static const String _documentDir = 'documents';
  static const String _backupDir = 'backups';
  static const String _exportDir = 'exports';
  static const String _importDir = 'imports';
  static const String _tempDir = 'temp';
  static const String _ocrDir = 'ocr';

  // 支持的图片格式
  static const List<String> _imageExtensions = [
    '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp',
  ];

  // 支持的文档格式
  static const List<String> _documentExtensions = [
    '.pdf', '.doc', '.docx', '.txt', '.md', '.csv', '.xlsx',
  ];

  // 缓存根目录
  String? _rootDir;

  // 缓存外部存储目录
  String? _externalStorageDir;

  // 日志输出
  void _log(String message) {
    // ignore: avoid_print
    print('[StorageService] $message');
  }

  /// 获取Android SDK版本
  Future<int> _getAndroidSdkVersion() async {
    if (!Platform.isAndroid) return 0;
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.version.sdkInt;
    } catch (e) {
      _log('获取Android SDK版本失败: $e');
      return 0;
    }
  }

  /// 请求存储权限
  /// 返回是否已获得权限
  Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    final sdkVersion = await _getAndroidSdkVersion();
    _log('Android SDK版本: $sdkVersion');

    // Android 13+ (SDK 33+) 使用新的媒体权限
    if (sdkVersion >= 33) {
      // Android 13+ 不需要 WRITE_EXTERNAL_STORAGE 权限来保存到Downloads
      // 使用 MediaStore API 或文件选择器
      _log('Android 13+，使用MediaStore或文件选择器');
      return true;
    }

    // Android 10-12 (SDK 29-32)
    if (sdkVersion >= 29) {
      // 检查是否有存储权限
      var status = await Permission.storage.status;
      if (status.isGranted) {
        _log('存储权限已授予');
        return true;
      }

      // 请求权限
      status = await Permission.storage.request();
      _log('存储权限请求结果: $status');
      return status.isGranted;
    }

    // Android 9及以下 (SDK < 29)
    var status = await Permission.storage.status;
    if (status.isGranted) {
      return true;
    }

    status = await Permission.storage.request();
    return status.isGranted;
  }

  /// 获取外部存储目录（公共目录）
  /// 在Android上返回外部存储根目录或Downloads目录
  Future<String?> getPublicStorageDirectory() async {
    try {
      if (Platform.isAndroid) {
        // 尝试获取外部存储目录
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          // 返回外部存储的根目录（通常是 /storage/emulated/0）
          final path = externalDir.path;
          // 向上导航到外部存储根目录
          final rootPath = path.substring(0, path.indexOf('/Android'));
          _log('外部存储根目录: $rootPath');
          return rootPath;
        }
      }
      return null;
    } catch (e) {
      _log('获取公共存储目录失败: $e');
      return null;
    }
  }

  /// 获取Downloads目录路径
  Future<String?> getDownloadsDirectory() async {
    try {
      if (Platform.isAndroid) {
        final publicDir = await getPublicStorageDirectory();
        if (publicDir != null) {
          final downloadsPath = '$publicDir/Download';
          final dir = Directory(downloadsPath);
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          return downloadsPath;
        }
      } else if (Platform.isLinux) {
        final home = Platform.environment['HOME'];
        if (home != null) {
          return '$home/Downloads';
        }
      } else if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null) {
          return '$userProfile\\Downloads';
        }
      } else if (Platform.isMacOS) {
        final home = Platform.environment['HOME'];
        if (home != null) {
          return '$home/Downloads';
        }
      }
      return null;
    } catch (e) {
      _log('获取Downloads目录失败: $e');
      return null;
    }
  }

  /// 获取Documents目录路径
  Future<String?> getDocumentsDirectory() async {
    try {
      if (Platform.isAndroid) {
        final publicDir = await getPublicStorageDirectory();
        if (publicDir != null) {
          final documentsPath = '$publicDir/Documents';
          final dir = Directory(documentsPath);
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          return documentsPath;
        }
      } else if (Platform.isLinux || Platform.isMacOS) {
        final home = Platform.environment['HOME'];
        if (home != null) {
          return '$home/Documents';
        }
      } else if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null) {
          return '$userProfile\\Documents';
        }
      }
      return null;
    } catch (e) {
      _log('获取Documents目录失败: $e');
      return null;
    }
  }

  /// 获取应用根目录
  Future<String> getRootDir() async {
    if (_rootDir != null) return _rootDir!;
    final appDir = await getApplicationDocumentsDirectory();
    _rootDir = appDir.path;
    return _rootDir!;
  }

  /// 获取附件目录
  Future<String> getAttachmentDir() async {
    try {
      final root = await getRootDir();
      final dir = Directory('$root/$_attachmentDir');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir.path;
    } catch (e) {
      throw StorageException('创建附件目录失败: $e');
    }
  }

  /// 获取图片目录
  Future<String> getImageDir() async {
    try {
      final root = await getRootDir();
      final dir = Directory('$root/$_attachmentDir/$_imageDir');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir.path;
    } catch (e) {
      throw StorageException('创建图片目录失败: $e');
    }
  }

  /// 获取文档目录
  Future<String> getDocumentDir() async {
    final root = await getRootDir();
    final dir = Directory('$root/$_attachmentDir/$_documentDir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  /// 获取备份目录
  Future<String> getBackupDir() async {
    final root = await getRootDir();
    final dir = Directory('$root/$_backupDir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  /// 获取导出目录
  /// [usePublicDir] 是否使用公共目录，默认为false（使用应用私有目录）
  Future<String> getExportDir({bool usePublicDir = false}) async {
    if (usePublicDir && Platform.isAndroid) {
      // 尝试使用Downloads目录
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        final appDir = '$downloadsDir/SmartLearning/Exports';
        final dir = Directory(appDir);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return appDir;
      }
    }

    // 默认使用应用私有目录
    final root = await getRootDir();
    final dir = Directory('$root/$_exportDir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  /// 获取公共导出目录（用户可访问）
  Future<String?> getPublicExportDir() async {
    if (Platform.isAndroid) {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        final appDir = '$downloadsDir/SmartLearning/Exports';
        final dir = Directory(appDir);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return appDir;
      }
    } else if (Platform.isLinux || Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        final dir = Directory('$home/Downloads/SmartLearning');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir.path;
      }
    } else if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final dir = Directory('$userProfile\\Downloads\\SmartLearning');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir.path;
      }
    }
    return null;
  }

  /// 获取导入目录
  Future<String> getImportDir() async {
    final root = await getRootDir();
    final dir = Directory('$root/$_importDir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  /// 获取临时目录
  Future<String> getTempDir() async {
    final root = await getRootDir();
    final dir = Directory('$root/$_tempDir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  /// 获取OCR目录
  Future<String> getOcrDir() async {
    final root = await getRootDir();
    final dir = Directory('$root/$_ocrDir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  /// 获取导出文件路径
  Future<String> getExportPath({
    required String fileName,
    String? subDir,
  }) async {
    final exportDir = await getExportDir();
    if (subDir != null) {
      final dir = Directory('$exportDir/$subDir');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return '$exportDir/$subDir/$fileName';
    }
    return '$exportDir/$fileName';
  }

  /// 获取导入文件路径
  Future<String> getImportPath({
    required String fileName,
    String? subDir,
  }) async {
    final importDir = await getImportDir();
    if (subDir != null) {
      final dir = Directory('$importDir/$subDir');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return '$importDir/$subDir/$fileName';
    }
    return '$importDir/$fileName';
  }

  /// 保存文件
  /// [sourcePath] 源文件路径
  /// [subDir] 子目录名称（如 'images', 'documents'）
  /// [fileName] 自定义文件名（可选，不提供则使用原文件名）
  /// 返回保存后的文件路径
  Future<String> saveFile(
    String sourcePath, {
    String? subDir,
    String? fileName,
  }) async {
    try {
      final File sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        throw FileNotFoundException('源文件不存在: $sourcePath');
      }

      // 确定目标目录
      String targetDir;
      if (subDir != null) {
        final attachmentDir = await getAttachmentDir();
        targetDir = '$attachmentDir/$subDir';
      } else {
        // 根据文件扩展名自动选择目录
        final ext = _getFileExtension(sourcePath).toLowerCase();
        if (_imageExtensions.contains(ext)) {
          targetDir = await getImageDir();
        } else if (_documentExtensions.contains(ext)) {
          targetDir = await getDocumentDir();
        } else {
          targetDir = await getAttachmentDir();
        }
      }

      // 确保目录存在
      final dir = Directory(targetDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // 确定文件名
      final finalFileName = fileName ?? _generateFileName(sourcePath);
      final targetPath = '$targetDir/$finalFileName';

      // 复制文件
      final targetFile = File(targetPath);
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await sourceFile.copy(targetPath);

      return targetPath;
    } on FileNotFoundException {
      rethrow;
    } catch (e) {
      throw StorageException('保存文件失败: $e');
    }
  }

  /// 保存字节数据为文件
  Future<String> saveFileFromBytes(
    List<int> bytes,
    String fileName, {
    String? subDir,
  }) async {
    String targetDir;
    if (subDir != null) {
      final attachmentDir = await getAttachmentDir();
      targetDir = '$attachmentDir/$subDir';
    } else {
      final ext = _getFileExtension(fileName).toLowerCase();
      if (_imageExtensions.contains(ext)) {
        targetDir = await getImageDir();
      } else if (_documentExtensions.contains(ext)) {
        targetDir = await getDocumentDir();
      } else {
        targetDir = await getAttachmentDir();
      }
    }

    final dir = Directory(targetDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final targetPath = '$targetDir/$fileName';
    final file = File(targetPath);
    await file.writeAsBytes(bytes);

    return targetPath;
  }

  /// 保存字符串内容为文件
  Future<String> saveFileFromString(
    String content,
    String fileName, {
    String? subDir,
  }) async {
    String targetDir;
    if (subDir != null) {
      final attachmentDir = await getAttachmentDir();
      targetDir = '$attachmentDir/$subDir';
    } else {
      targetDir = await getAttachmentDir();
    }

    final dir = Directory(targetDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final targetPath = '$targetDir/$fileName';
    final file = File(targetPath);
    await file.writeAsString(content);

    return targetPath;
  }

  /// 获取文件
  /// [filePath] 文件路径
  /// 返回文件对象
  Future<File> getFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileNotFoundException('文件不存在: $filePath');
    }
    return file;
  }

  /// 读取文件内容为字符串
  Future<String> readFileAsString(String filePath) async {
    final file = await getFile(filePath);
    return await file.readAsString();
  }

  /// 读取文件内容为字节
  Future<List<int>> readFileAsBytes(String filePath) async {
    final file = await getFile(filePath);
    return await file.readAsBytes();
  }

  /// 删除文件
  /// [filePath] 文件路径
  /// 返回是否删除成功
  Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// 批量删除文件
  Future<int> batchDeleteFiles(List<String> filePaths) async {
    int count = 0;
    for (final path in filePaths) {
      if (await deleteFile(path)) {
        count++;
      }
    }
    return count;
  }

  /// 检查文件是否存在
  Future<bool> fileExists(String filePath) async {
    final file = File(filePath);
    return await file.exists();
  }

  /// 获取文件大小
  Future<int> getFileSize(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return 0;
    return await file.length();
  }

  /// 获取文件信息
  Future<FileMetadata> getFileInfo(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileNotFoundException('文件不存在: $filePath');
    }
    final stat = await file.stat();
    return FileMetadata(
      path: filePath,
      name: filePath.split('/').last,
      size: stat.size,
      lastModified: stat.modified,
      extension: _getFileExtension(filePath),
    );
  }

  /// 列出目录中的所有文件
  Future<List<FileMetadata>> listFiles(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return [];

    final files = <FileMetadata>[];
    await for (final entity in dir.list(recursive: false)) {
      if (entity is File) {
        final stat = await entity.stat();
        files.add(FileMetadata(
          path: entity.path,
          name: entity.path.split('/').last,
          size: stat.size,
          lastModified: stat.modified,
          extension: _getFileExtension(entity.path),
        ));
      }
    }
    return files;
  }

  /// 列出目录中的所有子目录
  Future<List<String>> listDirectories(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return [];

    final dirs = <String>[];
    await for (final entity in dir.list(recursive: false)) {
      if (entity is Directory) {
        dirs.add(entity.path);
      }
    }
    return dirs;
  }

  // ==================== 备份相关 ====================

  /// 创建备份
  /// [data] 要备份的JSON数据
  /// [backupName] 备份名称（可选）
  /// [usePublicDir] 是否使用公共目录（Downloads），默认为true
  /// 返回备份文件路径
  Future<String> createBackup(
    Map<String, dynamic> data, {
    String? backupName,
    bool usePublicDir = true,
  }) async {
    // 请求存储权限
    if (Platform.isAndroid && usePublicDir) {
      await requestStoragePermission();
    }

    String targetDir;
    if (usePublicDir) {
      // 尝试使用公共Downloads目录
      final publicDir = await getDownloadsDirectory();
      if (publicDir != null) {
        // 在Downloads下创建应用专属子目录
        targetDir = '$publicDir/SmartLearning';
        final dir = Directory(targetDir);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        _log('使用公共Downloads目录: $targetDir');
      } else {
        // 回退到应用私有目录
        targetDir = await getBackupDir();
        _log('公共目录不可用，使用应用私有目录: $targetDir');
      }
    } else {
      targetDir = await getBackupDir();
    }

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = backupName != null
        ? '${backupName}_$timestamp.json'
        : 'smart_learning_backup_$timestamp.json';
    final filePath = '$targetDir/$fileName';

    final file = File(filePath);
    await file.writeAsString(jsonEncode(data));

    _log('备份文件创建成功: $filePath');
    return filePath;
  }

  /// 创建备份到用户选择的目录
  /// [data] 要备份的JSON数据
  /// [backupName] 备份名称（可选）
  /// 返回备份文件路径，用户取消则返回null
  Future<String?> createBackupWithPicker(
    Map<String, dynamic> data, {
    String? backupName,
  }) async {
    _log('使用文件选择器创建备份');

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final defaultFileName = backupName != null
        ? '${backupName}_$timestamp.json'
        : 'smart_learning_backup_$timestamp.json';

    try {
      // 使用文件选择器让用户选择保存位置
      String? result = await FilePicker.platform.saveFile(
        dialogTitle: '选择备份保存位置',
        fileName: defaultFileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null) {
        _log('用户取消了备份操作');
        return null;
      }

      // 确保文件扩展名
      if (!result.endsWith('.json')) {
        result = '$result.json';
      }

      _log('用户选择路径: $result');

      // 写入文件
      final file = File(result);
      await file.writeAsString(jsonEncode(data));

      _log('备份文件创建成功: $result');
      return result;
    } catch (e) {
      _log('使用文件选择器创建备份失败: $e');
      return null;
    }
  }

  /// 从备份恢复
  /// [backupPath] 备份文件路径
  /// 返回备份的JSON数据
  Future<Map<String, dynamic>> restoreBackup(String backupPath) async {
    final file = await getFile(backupPath);
    final content = await file.readAsString();
    return jsonDecode(content) as Map<String, dynamic>;
  }

  /// 列出所有备份文件
  Future<List<BackupInfo>> listBackups() async {
    final backupDir = await getBackupDir();
    final files = await listFiles(backupDir);

    final backups = <BackupInfo>[];
    for (final file in files) {
      if (file.extension == '.json') {
        try {
          final content = await readFileAsString(file.path);
          final data = jsonDecode(content) as Map<String, dynamic>;
          backups.add(BackupInfo(
            path: file.path,
            name: file.name,
            size: file.size,
            exportTime: data['export_time'] as String?,
            version: data['export_version']?.toString(),
          ));
        } catch (e) {
          backups.add(BackupInfo(
            path: file.path,
            name: file.name,
            size: file.size,
          ));
        }
      }
    }

    // 按时间倒序排列
    backups.sort((a, b) {
      if (a.exportTime != null && b.exportTime != null) {
        return b.exportTime!.compareTo(a.exportTime!);
      }
      return b.name.compareTo(a.name);
    });

    return backups;
  }

  /// 删除备份
  Future<bool> deleteBackup(String backupPath) async {
    return await deleteFile(backupPath);
  }

  /// 清理过期备份
  /// [keepDays] 保留最近几天的备份
  Future<int> cleanOldBackups({int keepDays = 30}) async {
    final backups = await listBackups();
    final cutoffDate = DateTime.now().subtract(Duration(days: keepDays));
    int deletedCount = 0;

    for (final backup in backups) {
      if (backup.exportTime != null) {
        try {
          final backupDate = DateTime.parse(backup.exportTime!);
          if (backupDate.isBefore(cutoffDate)) {
            await deleteBackup(backup.path);
            deletedCount++;
          }
        } catch (e) {
          // 跳过无法解析时间的备份
        }
      }
    }

    return deletedCount;
  }

  // ==================== 清理方法 ====================

  /// 清理临时文件
  Future<int> cleanTempFiles() async {
    final tempDir = await getTempDir();
    final files = await listFiles(tempDir);
    int count = 0;
    for (final file in files) {
      if (await deleteFile(file.path)) {
        count++;
      }
    }
    return count;
  }

  /// 获取存储使用情况
  Future<StorageUsage> getStorageUsage() async {
    final root = await getRootDir();
    final rootDir = Directory(root);

    int totalSize = 0;
    await for (final entity in rootDir.list(recursive: true)) {
      if (entity is File) {
        try {
          final stat = await entity.stat();
          totalSize += stat.size;
        } catch (e) {
          // 跳过无法访问的文件
        }
      }
    }

    return StorageUsage(totalBytes: totalSize);
  }

  /// 复制文件
  Future<String> copyFile(String sourcePath, String targetPath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw FileNotFoundException('源文件不存在: $sourcePath');
    }

    // 确保目标目录存在
    final targetDir = Directory(targetPath.substring(0, targetPath.lastIndexOf('/')));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    await sourceFile.copy(targetPath);
    return targetPath;
  }

  /// 移动文件
  Future<String> moveFile(String sourcePath, String targetPath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw FileNotFoundException('源文件不存在: $sourcePath');
    }

    // 确保目标目录存在
    final targetDir = Directory(targetPath.substring(0, targetPath.lastIndexOf('/')));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final targetFile = await sourceFile.rename(targetPath);
    return targetFile.path;
  }

  // ==================== 工具方法 ====================

  /// 生成唯一文件名
  String _generateFileName(String originalPath) {
    final ext = _getFileExtension(originalPath);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = timestamp % 10000;
    return '${timestamp}_$random$ext';
  }

  /// 获取文件扩展名
  String _getFileExtension(String filePath) {
    final dotIndex = filePath.lastIndexOf('.');
    if (dotIndex == -1) return '';
    return filePath.substring(dotIndex);
  }

  /// 判断是否为图片文件
  bool isImageFile(String filePath) {
    final ext = _getFileExtension(filePath).toLowerCase();
    return _imageExtensions.contains(ext);
  }

  /// 判断是否为文档文件
  bool isDocumentFile(String filePath) {
    final ext = _getFileExtension(filePath).toLowerCase();
    return _documentExtensions.contains(ext);
  }

  /// 格式化文件大小
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// 文件元数据
class FileMetadata {
  final String path;
  final String name;
  final int size;
  final DateTime lastModified;
  final String extension;

  const FileMetadata({
    required this.path,
    required this.name,
    required this.size,
    required this.lastModified,
    required this.extension,
  });

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// 备份信息
class BackupInfo {
  final String path;
  final String name;
  final int size;
  final String? exportTime;
  final String? version;

  const BackupInfo({
    required this.path,
    required this.name,
    required this.size,
    this.exportTime,
    this.version,
  });

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// 存储使用情况
class StorageUsage {
  final int totalBytes;

  const StorageUsage({required this.totalBytes});

  String get formattedSize {
    if (totalBytes < 1024) return '$totalBytes B';
    if (totalBytes < 1024 * 1024) {
      return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (totalBytes < 1024 * 1024 * 1024) {
      return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// 文件未找到异常
class FileNotFoundException implements Exception {
  final String message;
  const FileNotFoundException(this.message);

  @override
  String toString() => 'FileNotFoundException: $message';
}

/// 存储异常
class StorageException implements Exception {
  final String message;
  const StorageException(this.message);

  @override
  String toString() => 'StorageException: $message';
}
