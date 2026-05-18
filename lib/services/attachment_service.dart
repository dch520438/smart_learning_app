import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'database_service.dart';

/// 附件服务
/// 管理图片附件的选择、保存和删除
class AttachmentService {
  // 单例模式
  static final AttachmentService _instance = AttachmentService._internal();
  factory AttachmentService() => _instance;
  AttachmentService._internal();

  final DatabaseService _db = DatabaseService();
  final ImagePicker _picker = ImagePicker();
  final _uuid = const Uuid();

  /// 从相册选择图片
  Future<String?> pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    return image?.path;
  }

  /// 拍照
  Future<String?> pickImageFromCamera() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    return image?.path;
  }

  /// 保存图片到应用目录
  Future<String> saveImage(String sourcePath, String parentId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final attachmentsDir = Directory('${appDir.path}/attachments/$parentId');
    if (!await attachmentsDir.exists()) {
      await attachmentsDir.create(recursive: true);
    }

    final fileName = '${_uuid.v4()}.jpg';
    final destPath = '${attachmentsDir.path}/$fileName';

    await File(sourcePath).copy(destPath);
    return destPath;
  }

  /// 添加附件记录
  Future<void> addAttachment({
    required String parentId,
    required String parentType,
    required String filePath,
    String? fileName,
    int? fileSize,
  }) async {
    final file = File(filePath);
    final size = fileSize ?? await file.length();
    final name = fileName ?? filePath.split('/').last;

    final attachment = {
      'uuid': _uuid.v4(),
      'parent_id': parentId,
      'parent_type': parentType,
      'file_path': filePath,
      'file_name': name,
      'file_size': size,
    };
    await _db.insertAttachment(attachment);
  }

  /// 获取父记录的所有附件
  Future<List<Map<String, dynamic>>> getAttachments(String parentId) async {
    return await _db.queryAttachmentsByParentId(parentId);
  }

  /// 删除附件（包括数据库记录和文件）
  Future<void> deleteAttachment(int attachmentId) async {
    final attachment = await _db.queryAttachmentById(attachmentId);
    if (attachment != null) {
      final filePath = attachment['file_path'] as String;
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      await _db.deleteAttachment(attachmentId);
    }
  }

  /// 删除父记录的所有附件
  Future<void> deleteAttachmentsByParentId(String parentId) async {
    final attachments = await _db.queryAttachmentsByParentId(parentId);
    for (final attachment in attachments) {
      final filePath = attachment['file_path'] as String;
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _db.deleteAttachmentsByParentId(parentId);
  }

  /// 获取附件文件大小
  Future<int> getFileSize(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }

  /// 检查附件文件是否存在
  Future<bool> fileExists(String filePath) async {
    final file = File(filePath);
    return await file.exists();
  }

  /// 获取实际可用的图片路径
  /// 如果原始路径不存在，尝试在应用附件目录中查找同名文件
  Future<String> getValidImagePath(String originalPath) async {
    final file = File(originalPath);
    if (await file.exists()) {
      return originalPath;
    }

    // 原始路径不存在，尝试从应用附件目录中查找
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final attachmentsDir = Directory('${appDir.path}/attachments');
      if (await attachmentsDir.exists()) {
        final fileName = originalPath.split('/').last;
        // 递归搜索附件目录
        final found = await _findFileInDirectory(attachmentsDir, fileName);
        if (found != null) {
          return found;
        }
      }
    } catch (e) {
      debugPrint('搜索附件目录失败: $e');
    }

    // 都找不到，返回原始路径（由调用方处理错误）
    return originalPath;
  }

  /// 递归在目录中查找指定文件名的文件
  Future<String?> _findFileInDirectory(Directory dir, String fileName) async {
    try {
      final entities = await dir.list().toList();
      for (final entity in entities) {
        if (entity is File && entity.path.split('/').last == fileName) {
          return entity.path;
        } else if (entity is Directory) {
          final found = await _findFileInDirectory(entity, fileName);
          if (found != null) return found;
        }
      }
    } catch (e) {
      debugPrint('搜索目录失败: ${dir.path}, $e');
    }
    return null;
  }

  /// 构建图片 Widget，自动处理路径问题
  /// 返回一个 Future<ImageProvider>，如果文件不存在则返回 null
  Future<FileImage?> resolveImageProvider(String filePath) async {
    final validPath = await getValidImagePath(filePath);
    final file = File(validPath);
    if (await file.exists()) {
      return FileImage(file);
    }
    return null;
  }
}
