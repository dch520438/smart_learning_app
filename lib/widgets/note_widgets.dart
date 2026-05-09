import 'package:flutter/material.dart';
import '../screens/notes/notes_screen.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'common_widgets.dart';

// ============================================================
// ColorPicker - 颜色选择器
// ============================================================

/// ColorPicker: 颜色选择器组件
class ColorPicker extends StatelessWidget {
  final List<Color> colors;
  final Color? selectedColor;
  final ValueChanged<Color>? onColorChanged;
  final double circleSize;
  final double spacing;

  const ColorPicker({
    super.key,
    this.colors = const [
      Color(0xFFE53935),
      Color(0xFFFB8C00),
      Color(0xFFFDD835),
      Color(0xFF43A047),
      Color(0xFF1E88E5),
      Color(0xFF8E24AA),
      Color(0xFF00ACC1),
      Color(0xFF6D4C41),
      Color(0xFFD81B60),
      Color(0xFF3949AB),
    ],
    this.selectedColor,
    this.onColorChanged,
    this.circleSize = 32,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: colors.map((color) {
        final isSelected = selectedColor == color;
        return GestureDetector(
          onTap: () => onColorChanged?.call(color),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isSelected ? circleSize + 4 : circleSize,
            height: isSelected ? circleSize + 4 : circleSize,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(
                      color: AppColors.textPrimary,
                      width: 2,
                    )
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 18,
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }
}

// ============================================================
// NoteCard - 笔记卡片
// ============================================================

/// NoteCard: 笔记卡片组件
class NoteCard extends StatelessWidget {
  final String id;
  final String title;
  final String? content;
  final String? subject;
  final Color? noteColor;
  final DateTime? updatedAt;
  final List<String>? tags;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onFavorite;
  final bool isFavorited;
  final bool isSelected;
  final ValueChanged<bool>? onSelectionChanged;

  const NoteCard({
    super.key,
    required this.id,
    required this.title,
    this.content,
    this.subject,
    this.noteColor,
    this.updatedAt,
    this.tags,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onFavorite,
    this.isFavorited = false,
    this.isSelected = false,
    this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = noteColor ?? AppColors.primary;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return AppCard(
      onTap: onTap,
      margin: EdgeInsets.symmetric(
        horizontal: isWideScreen ? 32 : 16,
        vertical: 8,
      ),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧颜色条 + 内容
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧颜色指示条
              Container(
                width: 4,
                height: 80,
                decoration: BoxDecoration(
                  color: effectiveColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.lg),
                    bottomLeft: Radius.circular(AppRadius.lg),
                  ),
                ),
              ),
              // 内容区域
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 标题行
                      Row(
                        children: [
                          // 选择框
                          if (onSelectionChanged != null) ...[
                            SizedBox(
                              height: 20,
                              width: 20,
                              child: Checkbox(
                                value: isSelected,
                                onChanged: (value) =>
                                    onSelectionChanged?.call(value ?? false),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // 收藏按钮
                          if (onFavorite != null)
                            IconButton(
                              icon: Icon(
                                isFavorited
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                                size: 18,
                                color: isFavorited
                                    ? AppColors.warning
                                    : AppColors.textHint,
                              ),
                              onPressed: onFavorite,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          // 更多操作
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            onSelected: (value) {
                              switch (value) {
                                case 'edit':
                                  onEdit?.call();
                                  break;
                                case 'delete':
                                  onDelete?.call();
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 18),
                                    SizedBox(width: 8),
                                    Text('编辑'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, size: 18,
                                        color: AppColors.error),
                                    SizedBox(width: 8),
                                    Text('删除',
                                        style:
                                            TextStyle(color: AppColors.error)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // 学科标签
                      if (subject != null) ...[
                        AppTag(
                          label: subject!,
                          color: getSubjectColor(subject!),
                          dense: true,
                          fontSize: AppFontSize.xs,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => NotesScreen(
                                  initialFilterTag: subject,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                      ],
                      // 内容预览
                      if (content != null && content!.isNotEmpty) ...[
                        Text(
                          content!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                      ],
                      // 标签
                      if (tags != null && tags!.isNotEmpty) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: tags!
                              .take(3)
                              .map((tag) => GestureDetector(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => NotesScreen(
                                            initialFilterTag: tag,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      '#$tag',
                                      style: TextStyle(
                                        fontSize: AppFontSize.xs,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 6),
                      ],
                      // 时间
                      if (updatedAt != null)
                        Text(
                          formatFriendlyTime(updatedAt!),
                          style: TextStyle(
                            fontSize: AppFontSize.xs,
                            color: AppColors.textHint,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// NoteEditor - 笔记编辑器（支持Markdown预览）
// ============================================================

/// NoteEditor: 笔记编辑器（支持Markdown预览）
class NoteEditor extends StatefulWidget {
  final String? initialTitle;
  final String? initialContent;
  final String? initialSubject;
  final Color? initialColor;
  final List<String>? initialTags;
  final ValueChanged<String>? onTitleChanged;
  final ValueChanged<String>? onContentChanged;
  final ValueChanged<String?>? onSubjectChanged;
  final ValueChanged<Color>? onColorChanged;
  final ValueChanged<List<String>>? onTagsChanged;
  final VoidCallback? onSave;
  final bool readOnly;

  const NoteEditor({
    super.key,
    this.initialTitle,
    this.initialContent,
    this.initialSubject,
    this.initialColor,
    this.initialTags,
    this.onTitleChanged,
    this.onContentChanged,
    this.onSubjectChanged,
    this.onColorChanged,
    this.onTagsChanged,
    this.onSave,
    this.readOnly = false,
  });

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _tagController;
  String? _selectedSubject;
  Color _selectedColor = AppColors.primary;
  List<String> _tags = const [];
  bool _isPreviewMode = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _contentController =
        TextEditingController(text: widget.initialContent ?? '');
    _tagController = TextEditingController();
    _selectedSubject = widget.initialSubject;
    _selectedColor = widget.initialColor ?? AppColors.primary;
    _tags = List.from(widget.initialTags ?? []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
      });
      widget.onTagsChanged?.call(_tags);
      _tagController.clear();
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
    widget.onTagsChanged?.call(_tags);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Column(
      children: [
        // 工具栏
        if (!widget.readOnly)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                bottom: BorderSide(color: AppColors.divider),
              ),
            ),
            child: Row(
              children: [
                // 学科选择
                PopupMenuButton<String>(
                  icon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _selectedSubject != null
                            ? Icons.book_rounded
                            : Icons.book_outlined,
                        size: 20,
                        color: _selectedSubject != null
                            ? getSubjectColor(_selectedSubject!)
                            : AppColors.textSecondary,
                      ),
                      if (_selectedSubject != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          _selectedSubject!,
                          style: TextStyle(
                            fontSize: AppFontSize.sm,
                            color: getSubjectColor(_selectedSubject!),
                          ),
                        ),
                      ],
                    ],
                  ),
                  onSelected: (subject) {
                    setState(() {
                      _selectedSubject = subject;
                    });
                    widget.onSubjectChanged?.call(subject);
                  },
                  itemBuilder: (context) => kSubjectNames
                      .map((subject) => PopupMenuItem(
                            value: subject,
                            child: Row(
                              children: [
                                SubjectIcon(
                                  subjectName: subject,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(subject),
                              ],
                            ),
                          ))
                      .toList(),
                ),
                const Spacer(),
                // 颜色选择
                IconButton(
                  icon: Icon(
                    Icons.palette_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () {
                    _showColorPicker(context);
                  },
                  tooltip: '选择颜色',
                ),
                // 预览/编辑切换
                IconButton(
                  icon: Icon(
                    _isPreviewMode
                        ? Icons.edit_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPreviewMode = !_isPreviewMode;
                    });
                  },
                  tooltip: _isPreviewMode ? '编辑' : '预览',
                ),
                // 保存按钮
                if (widget.onSave != null)
                  IconButton(
                    icon: const Icon(
                      Icons.save_outlined,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    onPressed: widget.onSave,
                    tooltip: '保存',
                  ),
              ],
            ),
          ),

        // 编辑区域
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isWideScreen ? 48 : 16,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题输入
                if (!widget.readOnly || _isPreviewMode)
                  TextField(
                    controller: _titleController,
                    readOnly: widget.readOnly,
                    onChanged: widget.onTitleChanged,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      hintText: '输入标题...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    maxLines: null,
                  )
                else
                  Text(
                    _titleController.text,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                const SizedBox(height: 16),

                // 内容区域
                if (_isPreviewMode) ...[
                  // Markdown预览模式
                  _buildMarkdownPreview(theme),
                ] else ...[
                  // 编辑模式
                  TextField(
                    controller: _contentController,
                    readOnly: widget.readOnly,
                    onChanged: widget.onContentChanged,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.8,
                    ),
                    decoration: InputDecoration(
                      hintText: '开始记录笔记...\n\n支持Markdown语法：\n# 标题\n**粗体** *斜体*\n- 列表项\n> 引用',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintStyle: TextStyle(
                        color: AppColors.textHint,
                        height: 1.8,
                      ),
                    ),
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                  ),
                ],

                const SizedBox(height: 24),

                // 标签区域
                if (!widget.readOnly) ...[
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                    '标签',
                    style: TextStyle(
                      fontSize: AppFontSize.sm,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._tags.map((tag) => Chip(
                            label: Text(tag),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () => _removeTag(tag),
                            visualDensity: VisualDensity.compact,
                          )),
                      // 添加标签
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _tagController,
                          decoration: InputDecoration(
                            hintText: '添加标签',
                            isDense: true,
                            prefixIcon: const Icon(Icons.add, size: 16),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.xl),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                          style: TextStyle(fontSize: AppFontSize.sm),
                          onSubmitted: (_) => _addTag(),
                        ),
                      ),
                    ],
                  ),
                ],

                // 底部安全区域
                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 简单的Markdown预览渲染
  Widget _buildMarkdownPreview(ThemeData theme) {
    final content = _contentController.text;
    if (content.isEmpty) {
      return Text(
        '暂无内容',
        style: TextStyle(
          fontSize: AppFontSize.md,
          color: AppColors.textHint,
        ),
      );
    }

    final lines = content.split('\n');
    final List<Widget> widgets = [];

    for (final line in lines) {
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      // 标题
      if (line.startsWith('# ')) {
        widgets.add(Text(
          line.substring(2),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ));
        widgets.add(const SizedBox(height: 8));
      } else if (line.startsWith('## ')) {
        widgets.add(Text(
          line.substring(3),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ));
        widgets.add(const SizedBox(height: 6));
      } else if (line.startsWith('### ')) {
        widgets.add(Text(
          line.substring(4),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ));
        widgets.add(const SizedBox(height: 4));
      }
      // 引用
      else if (line.startsWith('> ')) {
        widgets.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border(
              left: BorderSide(
                color: theme.colorScheme.primary,
                width: 3,
              ),
            ),
          ),
          child: Text(
            line.substring(2),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ));
      }
      // 无序列表
      else if (line.startsWith('- ') || line.startsWith('* ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 16, top: 2, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInlineFormattedText(
                  line.substring(2),
                  theme,
                ),
              ),
            ],
          ),
        ));
      }
      // 有序列表
      else if (RegExp(r'^\d+\.\s').hasMatch(line)) {
        final match = RegExp(r'^(\d+\.\s)(.*)').firstMatch(line);
        if (match != null) {
          widgets.add(Padding(
            padding: const EdgeInsets.only(left: 16, top: 2, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  match.group(1)!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: _buildInlineFormattedText(
                    match.group(2)!,
                    theme,
                  ),
                ),
              ],
            ),
          ));
        }
      }
      // 分割线
      else if (line.trim() == '---') {
        widgets.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(),
        ));
      }
      // 普通段落
      else {
        widgets.add(_buildInlineFormattedText(line, theme));
        widgets.add(const SizedBox(height: 4));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// 内联格式化文本（处理粗体、斜体、行内代码）
  Widget _buildInlineFormattedText(String text, ThemeData theme) {
    // 简单处理：粗体 **text** 和斜体 *text*
    final spans = <TextSpan>[];
    final buffer = StringBuffer();
    var i = 0;

    while (i < text.length) {
      // 粗体
      if (i + 1 < text.length &&
          text[i] == '*' &&
          text[i + 1] == '*') {
        if (buffer.isNotEmpty) {
          spans.add(TextSpan(text: buffer.toString()));
          buffer.clear();
        }
        final end = text.indexOf('**', i + 2);
        if (end != -1) {
          spans.add(TextSpan(
            text: text.substring(i + 2, end),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ));
          i = end + 2;
        } else {
          buffer.write(text[i]);
          i++;
        }
      }
      // 斜体
      else if (text[i] == '*' && (i == 0 || text[i - 1] != '*')) {
        if (buffer.isNotEmpty) {
          spans.add(TextSpan(text: buffer.toString()));
          buffer.clear();
        }
        final end = text.indexOf('*', i + 1);
        if (end != -1 && end + 1 < text.length && text[end + 1] != '*') {
          spans.add(TextSpan(
            text: text.substring(i + 1, end),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ));
          i = end + 1;
        } else {
          buffer.write(text[i]);
          i++;
        }
      }
      // 行内代码
      else if (text[i] == '`') {
        if (buffer.isNotEmpty) {
          spans.add(TextSpan(text: buffer.toString()));
          buffer.clear();
        }
        final end = text.indexOf('`', i + 1);
        if (end != -1) {
          spans.add(TextSpan(
            text: text.substring(i + 1, end),
            style: TextStyle(
              fontFamily: 'monospace',
              backgroundColor:
                  theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              fontSize: AppFontSize.sm,
            ),
          ));
          i = end + 1;
        } else {
          buffer.write(text[i]);
          i++;
        }
      } else {
        buffer.write(text[i]);
        i++;
      }
    }

    if (buffer.isNotEmpty) {
      spans.add(TextSpan(text: buffer.toString()));
    }

    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
          height: 1.8,
        ),
        children: spans,
      ),
    );
  }

  /// 显示颜色选择器
  void _showColorPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '选择笔记颜色',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),
            ColorPicker(
              selectedColor: _selectedColor,
              onColorChanged: (color) {
                setState(() {
                  _selectedColor = color;
                });
                widget.onColorChanged?.call(color);
                Navigator.of(context).pop();
              },
              circleSize: 40,
              spacing: 16,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
