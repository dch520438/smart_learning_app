import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/attachment_service.dart';
import '../utils/constants.dart';

/// 图片附件组件
/// 用于在题目、笔记、知识点等录入时添加图片附件
class ImageAttachmentWidget extends StatefulWidget {
  final String parentId;
  final String parentType;
  final List<String> existingImages;
  final Function(List<String>) onImagesChanged;

  const ImageAttachmentWidget({
    super.key,
    required this.parentId,
    required this.parentType,
    this.existingImages = const [],
    required this.onImagesChanged,
  });

  @override
  State<ImageAttachmentWidget> createState() => _ImageAttachmentWidgetState();
}

class _ImageAttachmentWidgetState extends State<ImageAttachmentWidget> {
  final AttachmentService _attachmentService = AttachmentService();
  List<Map<String, dynamic>> _attachments = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAttachments();
  }

  Future<void> _loadAttachments() async {
    setState(() => _isLoading = true);
    try {
      final attachments = await _attachmentService.getAttachments(widget.parentId);
      setState(() {
        _attachments = attachments;
        _isLoading = false;
      });
      widget.onImagesChanged(_attachments.map((a) => a['file_path'] as String).toList());
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addImage(ImageSource source) async {
    String? pickedPath;
    if (source == ImageSource.gallery) {
      pickedPath = await _attachmentService.pickImageFromGallery();
    } else {
      pickedPath = await _attachmentService.pickImageFromCamera();
    }

    if (pickedPath != null) {
      try {
        final savedPath = await _attachmentService.saveImage(pickedPath, widget.parentId);
        final file = File(savedPath);
        await _attachmentService.addAttachment(
          parentId: widget.parentId,
          parentType: widget.parentType,
          filePath: savedPath,
          fileName: pickedPath.split('/').last,
          fileSize: await file.length(),
        );
        await _loadAttachments();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('添加图片失败: $e')),
          );
        }
      }
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('从相册选择'),
              onTap: () {
                Navigator.pop(context);
                _addImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(context);
                _addImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeImage(int index) async {
    if (index < 0 || index >= _attachments.length) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除图片'),
        content: const Text('确定要删除这张图片吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final attachmentId = _attachments[index]['id'] as int;
        await _attachmentService.deleteAttachment(attachmentId);
        await _loadAttachments();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除图片失败: $e')),
          );
        }
      }
    }
  }

  void _viewImage(int index) {
    if (index < 0 || index >= _attachments.length) return;

    final filePath = _attachments[index]['file_path'] as String;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).pop();
                  _removeImage(index);
                },
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(
                File(filePath),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.image, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              '图片附件',
              style: TextStyle(
                fontSize: AppFontSize.sm,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            if (_attachments.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_attachments.length}',
                  style: TextStyle(
                    fontSize: AppFontSize.xs,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              // 添加按钮
              InkWell(
                onTap: _showImagePickerOptions,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.textHint.withValues(alpha: 0.5),
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 28,
                        color: AppColors.textHint.withValues(alpha: 0.7),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '添加',
                        style: TextStyle(
                          fontSize: AppFontSize.xs,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 图片列表
              ..._attachments.asMap().entries.map((entry) {
                final index = entry.key;
                final attachment = entry.value;
                final filePath = attachment['file_path'] as String;

                return Stack(
                  children: [
                    InkWell(
                      onTap: () => _viewImage(index),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Image.file(
                          File(filePath),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey[200],
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removeImage(index),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
      ],
    );
  }
}

/// 图片附件展示组件（只读模式）
class ImageAttachmentViewer extends StatelessWidget {
  final List<String> imagePaths;
  final Function(int)? onImageTap;
  final Function(int)? onImageDelete;

  const ImageAttachmentViewer({
    super.key,
    required this.imagePaths,
    this.onImageTap,
    this.onImageDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (imagePaths.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.image, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              '图片附件',
              style: TextStyle(
                fontSize: AppFontSize.sm,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${imagePaths.length}',
                style: TextStyle(
                  fontSize: AppFontSize.xs,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: imagePaths.asMap().entries.map((entry) {
            final index = entry.key;
            final path = entry.value;

            return Stack(
              children: [
                InkWell(
                  onTap: () => onImageTap?.call(index),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Image.file(
                      File(path),
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (onImageDelete != null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => onImageDelete?.call(index),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}
