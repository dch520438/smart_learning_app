import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../services/ocr_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

/// 录入方式类型
enum InputMethod {
  keyboard,   // 键盘输入
  voice,      // 语音输入
  camera,     // 拍照识别
  gallery,    // 相册选择
  handwriting,// 手写输入
}

/// 录入方式选择器
/// 
/// 功能：
/// - 底部弹出选择菜单
/// - 选项：键盘输入、语音输入、拍照识别、相册选择
/// - 根据选择进入对应录入界面
class InputMethodSelector {
  /// 显示录入方式选择器
  static Future<InputMethod?> show(BuildContext context) async {
    return await showModalBottomSheet<InputMethod>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const _InputMethodSelectorWidget(),
    );
  }

  /// 获取录入方式的图标
  static IconData getIcon(InputMethod method) {
    switch (method) {
      case InputMethod.keyboard:
        return Icons.keyboard;
      case InputMethod.voice:
        return Icons.mic;
      case InputMethod.camera:
        return Icons.camera_alt;
      case InputMethod.gallery:
        return Icons.photo_library;
      case InputMethod.handwriting:
        return Icons.gesture;
    }
  }

  /// 获取录入方式的标题
  static String getTitle(InputMethod method) {
    switch (method) {
      case InputMethod.keyboard:
        return '键盘输入';
      case InputMethod.voice:
        return '语音输入';
      case InputMethod.camera:
        return '拍照识别';
      case InputMethod.gallery:
        return '相册选择';
      case InputMethod.handwriting:
        return '手写输入';
    }
  }

  /// 获取录入方式的描述
  static String getDescription(InputMethod method) {
    switch (method) {
      case InputMethod.keyboard:
        return '使用键盘输入文字内容';
      case InputMethod.voice:
        return '语音转文字快速录入';
      case InputMethod.camera:
        return '拍照后OCR识别文字';
      case InputMethod.gallery:
        return '从相册选择图片识别';
      case InputMethod.handwriting:
        return '手写板输入（需支持设备）';
    }
  }

  /// 获取录入方式的颜色
  static Color getColor(InputMethod method) {
    switch (method) {
      case InputMethod.keyboard:
        return AppColors.primary;
      case InputMethod.voice:
        return Colors.red;
      case InputMethod.camera:
        return Colors.blue;
      case InputMethod.gallery:
        return Colors.green;
      case InputMethod.handwriting:
        return Colors.purple;
    }
  }
}

/// 录入方式选择器组件
class _InputMethodSelectorWidget extends StatelessWidget {
  const _InputMethodSelectorWidget();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final methods = [
      InputMethod.keyboard,
      InputMethod.voice,
      if (!Platform.isLinux) InputMethod.camera,
      InputMethod.gallery,
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部拖动条
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // 标题
            Text(
              '选择录入方式',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '选择适合您的方式录入内容',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // 录入方式列表
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: methods.map((method) => _buildMethodItem(context, method)).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // 取消按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '取消',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodItem(BuildContext context, InputMethod method) {
    final color = InputMethodSelector.getColor(method);
    final icon = InputMethodSelector.getIcon(method);
    final title = InputMethodSelector.getTitle(method);
    final description = InputMethodSelector.getDescription(method);

    return InkWell(
      onTap: () => Navigator.of(context).pop(method),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: (MediaQuery.of(context).size.width - 64) / 2,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// 录入方式处理器
/// 
/// 提供统一的录入方式处理逻辑
class InputMethodHandler {
  final BuildContext context;
  final OcrService _ocrService = OcrService();

  InputMethodHandler(this.context);

  /// 处理选择的录入方式
  /// 
  /// 返回：
  /// - keyboard: 返回 null，表示使用键盘输入
  /// - voice: 返回语音识别结果
  /// - camera/gallery: 返回 OCR 识别结果
  Future<String?> handleInputMethod(InputMethod method) async {
    switch (method) {
      case InputMethod.keyboard:
        return null;
      case InputMethod.voice:
        return await _handleVoiceInput();
      case InputMethod.camera:
        return await _handleCameraInput();
      case InputMethod.gallery:
        return await _handleGalleryInput();
      case InputMethod.handwriting:
        return await _handleHandwritingInput();
    }
  }

  /// 处理语音输入
  Future<String?> _handleVoiceInput() async {
    // 显示语音输入对话框
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const _VoiceInputDialog(),
    );
    return result;
  }

  /// 处理拍照输入
  Future<String?> _handleCameraInput() async {
    // Linux平台不支持相机功能
    if (Platform.isLinux) {
      if (context.mounted) {
        showSnackBar(context, 'Linux平台暂不支持拍照功能，请使用相册选择', isError: true);
      }
      return null;
    }
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile == null) return null;

      // 显示加载对话框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // OCR 识别
      final text = await _ocrService.recognizeText(pickedFile.path);

      // 关闭加载对话框
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      return text;
    } catch (e) {
      // 确保关闭加载对话框
      if (context.mounted) {
        try {
          Navigator.of(context).pop();
        } catch (_) {}
        showSnackBar(context, '拍照识别失败: $e', isError: true);
      }
      return null;
    }
  }

  /// 处理相册选择
  Future<String?> _handleGalleryInput() async {
    try {
      // Linux平台使用 file_picker 替代 image_picker
      if (Platform.isLinux) {
        return await _handleGalleryInputOnLinux();
      }
      
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile == null) return null;

      // 显示加载对话框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // OCR 识别
      final text = await _ocrService.recognizeText(pickedFile.path);

      // 关闭加载对话框
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      return text;
    } catch (e) {
      // 确保关闭加载对话框
      if (context.mounted) {
        try {
          Navigator.of(context).pop();
        } catch (_) {}
        showSnackBar(context, '图片识别失败: $e', isError: true);
      }
      return null;
    }
  }

  /// Linux平台使用 file_picker 处理相册选择
  Future<String?> _handleGalleryInputOnLinux() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        dialogTitle: '选择图片',
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        if (context.mounted) {
          showSnackBar(context, '无法获取文件路径', isError: true);
        }
        return null;
      }

      // 显示加载对话框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // OCR 识别
      final text = await _ocrService.recognizeText(filePath);

      // 关闭加载对话框
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      return text;
    } catch (e) {
      // 确保关闭加载对话框
      if (context.mounted) {
        try {
          Navigator.of(context).pop();
        } catch (_) {}
        showSnackBar(context, '图片选择失败: $e', isError: true);
      }
      return null;
    }
  }

  /// 处理手写输入
  Future<String?> _handleHandwritingInput() async {
    // 显示手写输入对话框
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const _HandwritingInputDialog(),
    );
    return result;
  }
}

/// 语音输入对话框
class _VoiceInputDialog extends StatefulWidget {
  const _VoiceInputDialog();

  @override
  State<_VoiceInputDialog> createState() => _VoiceInputDialogState();
}

class _VoiceInputDialogState extends State<_VoiceInputDialog> {
  bool _isListening = false;
  String _recognizedText = '';

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    setState(() {
      _isListening = true;
    });
    // TODO: 实现语音识别
    // 这里需要集成语音识别服务，如百度语音、讯飞语音等
    // 模拟语音识别
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isListening = false;
          _recognizedText = '（语音输入功能需要集成语音识别服务）';
        });
      }
    });
  }

  void _stopListening() {
    setState(() {
      _isListening = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('语音输入'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _isListening ? Colors.red.withOpacity(0.1) : Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: _isListening ? Colors.red : Colors.grey,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _isListening ? '正在聆听...' : '点击麦克风开始说话',
            style: TextStyle(
              color: _isListening ? Colors.red : AppColors.textSecondary,
            ),
          ),
          if (_recognizedText.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_recognizedText),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        if (_recognizedText.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.of(context).pop(_recognizedText),
            child: const Text('使用'),
          ),
      ],
    );
  }
}

/// 手写输入对话框
class _HandwritingInputDialog extends StatefulWidget {
  const _HandwritingInputDialog();

  @override
  State<_HandwritingInputDialog> createState() => _HandwritingInputDialogState();
}

class _HandwritingInputDialogState extends State<_HandwritingInputDialog> {
  final List<Offset?> _points = [];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('手写输入'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _points.add(details.localPosition);
                });
              },
              onPanEnd: (_) {
                setState(() {
                  _points.add(null);
                });
              },
              child: CustomPaint(
                painter: _HandwritingPainter(points: _points),
                size: const Size(double.infinity, 200),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '在手写区域书写文字',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _points.clear();
            });
          },
          child: const Text('清除'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            // TODO: 实现手写识别
            Navigator.of(context).pop('（手写输入功能需要集成手写识别服务）');
          },
          child: const Text('识别'),
        ),
      ],
    );
  }
}

/// 手写绘制器
class _HandwritingPainter extends CustomPainter {
  final List<Offset?> points;

  _HandwritingPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
