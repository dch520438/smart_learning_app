import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/wrong_question.dart';
import '../../models/mother_question.dart';
import '../../services/ai_document_parser_service.dart' hide QuestionType;
import '../../services/database_service.dart';
import '../../utils/constants.dart';
import '../../widgets/common_widgets.dart';

// ============================================================
// AI 文档题目拆分页面
// ============================================================

class AIDocumentParserScreen extends StatefulWidget {
  const AIDocumentParserScreen({super.key});

  @override
  State<AIDocumentParserScreen> createState() => _AIDocumentParserScreenState();
}

class _AIDocumentParserScreenState extends State<AIDocumentParserScreen>
    with SingleTickerProviderStateMixin {
  final AIDocumentParserService _parserService = AIDocumentParserService();
  final DatabaseService _databaseService = DatabaseService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _textController = TextEditingController();

  late TabController _tabController;

  // 状态变量
  bool _isParsing = false;
  String? _errorMessage;
  ParseResult? _parseResult;
  List<ParsedQuestion> _selectedQuestions = [];
  ImportTarget _importTarget = ImportTarget.wrongQuestionBook;
  bool _isImporting = false;
  int _importProgress = 0;

  // 图片预览
  String? _selectedImagePath;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('文档题目拆分'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.image), text: '图片识别'),
            Tab(icon: Icon(Icons.text_fields), text: '文本粘贴'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildImageTab(),
          _buildTextTab(),
        ],
      ),
    );
  }

  // ============================================================
  // 图片识别标签页
  // ============================================================

  Widget _buildImageTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图片选择区域
          _buildImageSelector(),

          const SizedBox(height: 16),

          // 解析按钮
          if (_selectedImagePath != null)
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: '开始识别并拆分题目',
                icon: Icons.auto_fix_high,
                isLoading: _isParsing,
                onPressed: _parseFromImage,
              ),
            ),

          // 错误提示
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _buildErrorCard(),
          ],

          // 解析结果
          if (_parseResult != null && _parseResult!.success) ...[
            const SizedBox(height: 24),
            _buildResultSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildImageSelector() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '选择试卷/文档图片',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          if (_selectedImagePath == null)
            Row(
              children: [
                Expanded(
                  child: _buildImageSourceButton(
                    icon: Icons.camera_alt,
                    label: '拍照',
                    onTap: _takePhoto,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildImageSourceButton(
                    icon: Icons.photo_library,
                    label: '从相册选择',
                    onTap: _pickFromGallery,
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                // 图片预览
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Image.file(
                    File(_selectedImagePath!),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedImagePath = null;
                          _parseResult = null;
                          _errorMessage = null;
                          _selectedQuestions = [];
                        });
                      },
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('移除图片'),
                    ),
                    const SizedBox(width: 16),
                    TextButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text('更换图片'),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildImageSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.primary.withOpacity(0.1),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Icon(icon, size: 32, color: AppColors.primary),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 文本粘贴标签页
  // ============================================================

  Widget _buildTextTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '粘贴试卷/文档内容',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  '将试卷或练习题的文本内容粘贴到下方',
                  style: TextStyle(
                    fontSize: AppFontSize.sm,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    hintText: '在此粘贴题目内容...\n\n例如：\n1. 以下关于函数的说法正确的是？\nA. 选项一\nB. 选项二\nC. 选项三\nD. 选项四',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  maxLines: 10,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        _textController.clear();
                      },
                      icon: const Icon(Icons.clear, size: 18),
                      label: const Text('清空'),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data?.text != null) {
                          _textController.text = data!.text!;
                        }
                      },
                      icon: const Icon(Icons.paste, size: 18),
                      label: const Text('粘贴'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 解析按钮
          SizedBox(
            width: double.infinity,
            child: AppButton(
              text: '开始拆分题目',
              icon: Icons.auto_fix_high,
              isLoading: _isParsing,
              onPressed: _parseFromText,
            ),
          ),

          // 错误提示
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _buildErrorCard(),
          ],

          // 解析结果
          if (_parseResult != null && _parseResult!.success) ...[
            const SizedBox(height: 24),
            _buildResultSection(),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // 错误提示卡片
  // ============================================================

  Widget _buildErrorCard() {
    return AppCard(
      color: AppColors.error.withOpacity(0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: AppColors.error),
              const SizedBox(width: 8),
              Text(
                '解析失败',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            style: TextStyle(color: AppColors.error),
          ),
          if (_parseResult?.rawText != null &&
              _parseResult!.rawText!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              '识别的原始文本：',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                _parseResult!.rawText!,
                style: const TextStyle(fontSize: AppFontSize.sm),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // 解析结果区域
  // ============================================================

  Widget _buildResultSection() {
    final questions = _parseResult!.questions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 结果统计
        _buildResultStats(questions.length),

        const SizedBox(height: 16),

        // 录入目标选择
        _buildImportTargetSelector(),

        const SizedBox(height: 16),

        // 批量操作按钮
        _buildBatchActions(),

        const SizedBox(height: 16),

        // 题目列表
        ...questions.asMap().entries.map((entry) {
          final index = entry.key;
          final question = entry.value;
          return _buildQuestionCard(index + 1, question);
        }),

        const SizedBox(height: 24),

        // 底部导入按钮
        if (_selectedQuestions.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: AppButton(
              text: '导入选中的 ${_selectedQuestions.length} 道题目到${_importTarget.displayName}',
              icon: Icons.save,
              isLoading: _isImporting,
              onPressed: _importSelectedQuestions,
            ),
          ),
      ],
    );
  }

  Widget _buildResultStats(int count) {
    return AppCard(
      color: AppColors.success.withOpacity(0.1),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.check_circle, color: AppColors.success),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '解析成功',
                  style: TextStyle(
                    fontSize: AppFontSize.lg,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '共识别到 $count 道题目',
                  style: TextStyle(
                    fontSize: AppFontSize.sm,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportTargetSelector() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '选择录入目标',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTargetOption(
                  title: '错题本',
                  icon: Icons.error_outline,
                  color: AppColors.error,
                  isSelected: _importTarget == ImportTarget.wrongQuestionBook,
                  onTap: () => setState(() {
                    _importTarget = ImportTarget.wrongQuestionBook;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTargetOption(
                  title: '母题库',
                  icon: Icons.library_books,
                  color: AppColors.primary,
                  isSelected: _importTarget == ImportTarget.motherQuestionBank,
                  onTap: () => setState(() {
                    _importTarget = ImportTarget.motherQuestionBank;
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTargetOption({
    required String title,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? color : AppColors.textHint.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : AppColors.textSecondary),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? color : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBatchActions() {
    final allSelected = _selectedQuestions.length == _parseResult!.questions.length;

    return Row(
      children: [
        TextButton.icon(
          onPressed: () {
            setState(() {
              if (allSelected) {
                _selectedQuestions = [];
              } else {
                _selectedQuestions = List.from(_parseResult!.questions);
              }
            });
          },
          icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
          label: Text(allSelected ? '取消全选' : '全选'),
        ),
        const Spacer(),
        Text(
          '已选择 ${_selectedQuestions.length}/${_parseResult!.questions.length} 题',
          style: TextStyle(
            fontSize: AppFontSize.sm,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(int index, ParsedQuestion question) {
    final isSelected = _selectedQuestions.contains(question);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      color: isSelected ? AppColors.primary.withOpacity(0.05) : null,
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedQuestions.remove(question);
          } else {
            _selectedQuestions.add(question);
          }
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部信息
          Row(
            children: [
              // 选择框
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.textHint,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),

              // 题号
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  '第$index题',
                  style: TextStyle(
                    fontSize: AppFontSize.sm,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // 题型
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getTypeColor(question.type).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  question.type.displayName,
                  style: TextStyle(
                    fontSize: AppFontSize.xs,
                    color: _getTypeColor(question.type),
                  ),
                ),
              ),

              const Spacer(),

              // 学科
              if (question.subject != null)
                Text(
                  question.subject!,
                  style: TextStyle(
                    fontSize: AppFontSize.xs,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // 题目内容
          Text(
            question.content,
            style: const TextStyle(fontSize: AppFontSize.md),
          ),

          // 选项
          if (question.options != null && question.options!.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...question.options!.map((option) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: AppFontSize.sm,
                    color: AppColors.textSecondary,
                  ),
                ),
              );
            }),
          ],

          // 答案和解析
          if (question.answer != null || question.analysis != null) ...[
            const SizedBox(height: 12),
            const Divider(),
            if (question.answer != null)
              Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    '答案: ${question.answer}',
                    style: TextStyle(
                      fontSize: AppFontSize.sm,
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            if (question.analysis != null) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb, size: 16, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '解析: ${question.analysis}',
                      style: TextStyle(
                        fontSize: AppFontSize.sm,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],

          // 知识点
          if (question.knowledgePoint != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.local_offer, size: 14, color: AppColors.info),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    question.knowledgePoint!,
                    style: TextStyle(
                      fontSize: AppFontSize.xs,
                      color: AppColors.info,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getTypeColor(QuestionType type) {
    switch (type) {
      case QuestionType.singleChoice:
        return const Color(0xFF4CAF50);
      case QuestionType.multipleChoice:
        return const Color(0xFF2196F3);
      case QuestionType.fillBlank:
        return const Color(0xFFFF9800);
      case QuestionType.shortAnswer:
        return const Color(0xFF9C27B0);
      case QuestionType.trueFalse:
        return const Color(0xFFE91E63);
      case QuestionType.proof:
        return const Color(0xFF00BCD4);
      case QuestionType.essay:
        return const Color(0xFF795548);
    }
  }

  // ============================================================
  // 操作方法
  // ============================================================

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (photo != null) {
        setState(() {
          _selectedImagePath = photo.path;
          _parseResult = null;
          _errorMessage = null;
          _selectedQuestions = [];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('拍照失败: $e')),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _selectedImagePath = image.path;
          _parseResult = null;
          _errorMessage = null;
          _selectedQuestions = [];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择图片失败: $e')),
      );
    }
  }

  Future<void> _parseFromImage() async {
    if (_selectedImagePath == null) return;

    setState(() {
      _isParsing = true;
      _errorMessage = null;
      _parseResult = null;
      _selectedQuestions = [];
    });

    try {
      final result = await _parserService.parseDocumentFromImage(_selectedImagePath!);

      setState(() {
        _parseResult = result;
        if (!result.success) {
          _errorMessage = result.errorMessage ?? '解析失败';
        } else {
          // 默认全选
          _selectedQuestions = List.from(result.questions);
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = '解析失败: $e';
      });
    } finally {
      setState(() {
        _isParsing = false;
      });
    }
  }

  Future<void> _parseFromText() async {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入题目内容')),
      );
      return;
    }

    setState(() {
      _isParsing = true;
      _errorMessage = null;
      _parseResult = null;
      _selectedQuestions = [];
    });

    try {
      final result = await _parserService.parseDocumentFromText(_textController.text);

      setState(() {
        _parseResult = result;
        if (!result.success) {
          _errorMessage = result.errorMessage ?? '解析失败';
        } else {
          // 默认全选
          _selectedQuestions = List.from(result.questions);
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = '解析失败: $e';
      });
    } finally {
      setState(() {
        _isParsing = false;
      });
    }
  }

  Future<void> _importSelectedQuestions() async {
    if (_selectedQuestions.isEmpty) return;

    setState(() {
      _isImporting = true;
      _importProgress = 0;
    });

    try {
      int successCount = 0;
      int failCount = 0;

      for (int i = 0; i < _selectedQuestions.length; i++) {
        final question = _selectedQuestions[i];

        try {
          if (_importTarget == ImportTarget.wrongQuestionBook) {
            // 导入到错题本
            await _databaseService.insertWrongQuestion(question.toWrongQuestionJson());
          } else {
            // 导入到母题库
            await _databaseService.insertMotherQuestion(question.toMotherQuestionJson());
          }
          successCount++;
        } catch (e) {
          failCount++;
          debugPrint('导入题目失败: $e');
        }

        setState(() {
          _importProgress = i + 1;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入完成: 成功 $successCount 题，失败 $failCount 题'),
            backgroundColor: failCount == 0 ? AppColors.success : AppColors.warning,
          ),
        );

        // 导入成功后清空选择
        if (successCount > 0) {
          setState(() {
            _selectedQuestions = [];
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }
}
