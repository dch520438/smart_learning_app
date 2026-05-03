import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

// ============================================================
// AppCard - 带阴影的卡片组件
// ============================================================

/// 按钮样式枚举
enum AppButtonStyle { primary, secondary, text, outlined }

/// AppCard: 带阴影的卡片组件，支持圆角、颜色自定义
class AppCard extends StatelessWidget {
  final Widget child;
  final double? borderRadius;
  final Color? color;
  final Color? shadowColor;
  final double elevation;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final BorderSide? border;

  const AppCard({
    super.key,
    required this.child,
    this.borderRadius,
    this.color,
    this.shadowColor,
    this.elevation = 2.0,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final effectiveBorderRadius = borderRadius ?? AppRadius.lg;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: screenWidth > 600 ? 32 : 16,
        vertical: 8,
      ),
      child: Material(
        color: color ?? theme.colorScheme.surface,
        elevation: elevation,
        shadowColor: shadowColor ?? AppColors.shadow,
        borderRadius: BorderRadius.circular(effectiveBorderRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(effectiveBorderRadius),
          child: Container(
            padding: padding,
            decoration: border != null
                ? BoxDecoration(
                    border: Border.fromBorderSide(border!),
                    borderRadius: BorderRadius.circular(effectiveBorderRadius),
                  )
                : null,
            child: child,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// AppButton - 统一按钮组件
// ============================================================

/// AppButton: 统一按钮组件，支持主要/次要/文字样式，支持loading状态
class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final bool isLoading;
  final IconData? icon;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final bool enabled;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.style = AppButtonStyle.primary,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height,
    this.padding,
    this.enabled = true,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size.width;
    final isSmallScreen = screenSize < 360;

    final effectiveWidth = widget.width ?? (isSmallScreen ? double.infinity : null);
    final effectiveHeight = widget.height ?? 48.0;
    final effectivePadding = widget.padding ??
        EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 16 : 24,
          vertical: 0,
        );

    final bool isDisabled = widget.isLoading || !widget.enabled;

    Widget buildChild() {
      if (widget.isLoading) {
        return SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: _getTextColor(theme),
          ),
        );
      }

      if (widget.icon != null) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 20, color: _getTextColor(theme)),
            const SizedBox(width: 8),
            Flexible(child: Text(widget.text, style: _getTextStyle(theme))),
          ],
        );
      }

      return Text(widget.text, style: _getTextStyle(theme));
    }

    Widget button;
    switch (widget.style) {
      case AppButtonStyle.primary:
        button = ElevatedButton(
          onPressed: isDisabled ? null : widget.onPressed,
          style: ElevatedButton.styleFrom(
            minimumSize: Size(effectiveWidth ?? double.infinity, effectiveHeight),
            padding: effectivePadding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          child: buildChild(),
        );
        break;
      case AppButtonStyle.secondary:
        button = FilledButton(
          onPressed: isDisabled ? null : widget.onPressed,
          style: FilledButton.styleFrom(
            minimumSize: Size(effectiveWidth ?? double.infinity, effectiveHeight),
            padding: effectivePadding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          child: buildChild(),
        );
        break;
      case AppButtonStyle.text:
        button = TextButton(
          onPressed: isDisabled ? null : widget.onPressed,
          style: TextButton.styleFrom(
            minimumSize: Size(effectiveWidth ?? double.infinity, effectiveHeight),
            padding: effectivePadding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          child: buildChild(),
        );
        break;
      case AppButtonStyle.outlined:
        button = OutlinedButton(
          onPressed: isDisabled ? null : widget.onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: Size(effectiveWidth ?? double.infinity, effectiveHeight),
            padding: effectivePadding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          child: buildChild(),
        );
        break;
    }

    return button;
  }

  Color _getTextColor(ThemeData theme) {
    switch (widget.style) {
      case AppButtonStyle.primary:
      case AppButtonStyle.secondary:
        return theme.colorScheme.onPrimary;
      case AppButtonStyle.text:
      case AppButtonStyle.outlined:
        return theme.colorScheme.primary;
    }
  }

  TextStyle _getTextStyle(ThemeData theme) {
    return TextStyle(
      fontSize: AppFontSize.md,
      fontWeight: FontWeight.w600,
      color: _getTextColor(theme),
    );
  }
}

// ============================================================
// AppInput - 输入框组件
// ============================================================

/// AppInput: 输入框组件，支持多行、标签、验证
class AppInput extends StatefulWidget {
  final String? label;
  final String? hintText;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final bool obscureText;
  final bool multiline;
  final int maxLines;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool readOnly;
  final VoidCallback? onTap;
  final String? initialValue;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;

  const AppInput({
    super.key,
    this.label,
    this.hintText,
    this.controller,
    this.validator,
    this.obscureText = false,
    this.multiline = false,
    this.maxLines = 1,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.onTap,
    this.initialValue,
    this.focusNode,
    this.textInputAction,
  });

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput> {
  late TextEditingController _controller;
  bool _obscureText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController(text: widget.initialValue ?? '');
    _obscureText = widget.obscureText;
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth > 600 ? 32 : 0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.label != null) ...[
                Text(
                  widget.label!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              TextFormField(
                controller: _controller,
                validator: widget.validator,
                obscureText: _obscureText,
                maxLines: widget.multiline ? null : widget.maxLines,
                minLines: widget.multiline ? 3 : 1,
                keyboardType: widget.multiline
                    ? TextInputType.multiline
                    : widget.keyboardType,
                onChanged: widget.onChanged,
                onFieldSubmitted: widget.onSubmitted,
                enabled: widget.enabled,
                readOnly: widget.readOnly,
                onTap: widget.onTap,
                focusNode: widget.focusNode,
                textInputAction: widget.textInputAction,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  prefixIcon: widget.prefixIcon != null
                      ? Icon(widget.prefixIcon)
                      : null,
                  suffixIcon: widget.obscureText
                      ? IconButton(
                          icon: Icon(
                            _obscureText
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureText = !_obscureText;
                            });
                          },
                        )
                      : widget.suffixIcon,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withOpacity(0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: AppColors.error),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(
                      color: AppColors.error,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// AppSearchBar - 搜索栏组件
// ============================================================

/// AppSearchBar: 搜索栏组件，带取消按钮
class AppSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onSearch;
  final ValueChanged<String>? onChanged;
  final String hintText;
  final bool autofocus;
  final bool showCancelButton;

  const AppSearchBar({
    super.key,
    this.controller,
    this.onSearch,
    this.onChanged,
    this.hintText = '搜索...',
    this.autofocus = false,
    this.showCancelButton = true,
  });

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late TextEditingController _controller;
  bool _showCancel = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _showCancel = widget.autofocus;
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth > 600 ? 32 : 16,
        vertical: 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: TextField(
                controller: _controller,
                autofocus: widget.autofocus,
                onChanged: (value) {
                  setState(() {
                    _showCancel = value.isNotEmpty;
                  });
                  widget.onChanged?.call(value);
                },
                onSubmitted: (value) {
                  widget.onSearch?.call(value);
                },
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _showCancel
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _controller.clear();
                            setState(() {
                              _showCancel = false;
                            });
                            widget.onChanged?.call('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          if (widget.showCancelButton && _showCancel) ...[
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              onPressed: () {
                _controller.clear();
                setState(() {
                  _showCancel = false;
                });
                widget.onChanged?.call('');
                FocusScope.of(context).unfocus();
              },
              child: const Text('取消'),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// AppTag - 标签组件
// ============================================================

/// AppTag: 标签组件，支持颜色自定义
class AppTag extends StatelessWidget {
  final String label;
  final Color? color;
  final VoidCallback? onTap;
  final bool selected;
  final IconData? icon;
  final double fontSize;
  final bool dense;

  const AppTag({
    super.key,
    required this.label,
    this.color,
    this.onTap,
    this.selected = false,
    this.icon,
    this.fontSize = AppFontSize.sm,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 8 : 12,
            vertical: dense ? 2 : 4,
          ),
          decoration: BoxDecoration(
            color: selected
                ? effectiveColor
                : effectiveColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: selected
                ? null
                : Border.all(color: effectiveColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: fontSize + 2,
                  color: selected
                      ? theme.colorScheme.onPrimary
                      : effectiveColor,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: selected
                      ? theme.colorScheme.onPrimary
                      : effectiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// AppDialog - 通用对话框组件
// ============================================================

/// AppDialog: 通用对话框组件
class AppDialog extends StatelessWidget {
  final String? title;
  final String? message;
  final Widget? content;
  final List<Widget>? actions;
  final IconData? icon;

  const AppDialog({
    super.key,
    this.title,
    this.message,
    this.content,
    this.actions,
    this.icon,
  });

  /// 显示对话框
  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    String? message,
    Widget? content,
    List<Widget>? actions,
    IconData? icon,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => AppDialog(
        title: title,
        message: message,
        content: content,
        actions: actions,
        icon: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      icon: icon != null ? Icon(icon, size: 32) : null,
      title: title != null ? Text(title!) : null,
      content: content ??
          (message != null ? Text(message!, style: theme.textTheme.bodyMedium) : null),
      actions: actions ??
          [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确定'),
            ),
          ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
    );
  }
}

// ============================================================
// AppEmptyState - 空状态占位组件
// ============================================================

/// AppEmptyState: 空状态占位组件
class AppEmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  final String? actionText;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    this.message = '暂无数据',
    this.icon = Icons.inbox_outlined,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth > 600 ? 64 : 32,
          vertical: 48,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: screenWidth > 600 ? 80 : 64,
              color: AppColors.textHint,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionText != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                text: actionText!,
                onPressed: onAction,
                style: AppButtonStyle.outlined,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// AppLoading - 加载中组件
// ============================================================

/// AppLoading: 加载中组件
class AppLoading extends StatelessWidget {
  final String? message;
  final double size;

  const AppLoading({
    super.key,
    this.message,
    this.size = 36,
  });

  /// 显示全屏加载
  static void show(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppLoading(message: message),
    );
  }

  /// 隐藏全屏加载
  static void hide(BuildContext context) {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: theme.colorScheme.primary,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              message!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// SubjectIcon - 学科图标组件
// ============================================================

/// SubjectIcon: 学科图标组件，根据学科名称显示对应图标和颜色
class SubjectIcon extends StatelessWidget {
  final String subjectName;
  final double size;
  final bool showLabel;
  final bool showBackground;

  const SubjectIcon({
    super.key,
    required this.subjectName,
    this.size = 40,
    this.showLabel = false,
    this.showBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = getSubjectColor(subjectName);
    final iconName = getSubjectIcon(subjectName);
    final iconSize = size * 0.5;

    IconData _getIconData(String iconName) {
      switch (iconName) {
        case 'book':
          return Icons.menu_book_rounded;
        case 'calculate':
          return Icons.calculate_rounded;
        case 'translate':
          return Icons.translate_rounded;
        case 'science':
          return Icons.science_rounded;
        case 'biotech':
          return Icons.biotech_rounded;
        case 'eco':
          return Icons.eco_rounded;
        case 'history_edu':
          return Icons.history_edu_rounded;
        case 'public':
          return Icons.public_rounded;
        case 'gavel':
          return Icons.gavel_rounded;
        default:
          return Icons.category_rounded;
      }
    }

    Widget iconWidget = Icon(
      _getIconData(iconName),
      size: iconSize,
      color: showBackground ? color : null,
    );

    if (!showBackground) {
      return iconWidget;
    }

    Widget container = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Center(child: iconWidget),
    );

    if (showLabel) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          container,
          const SizedBox(height: 4),
          Text(
            subjectName,
            style: TextStyle(
              fontSize: AppFontSize.xs,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return container;
  }
}

// ============================================================
// DifficultyStars - 难度星级显示组件
// ============================================================

/// DifficultyStars: 难度星级显示组件
class DifficultyStars extends StatelessWidget {
  final int difficulty; // 1-3
  final double iconSize;

  const DifficultyStars({
    super.key,
    required this.difficulty,
    this.iconSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    final color = getDifficultyColor(difficulty);
    final clampedDifficulty = difficulty.clamp(1, 3);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Icon(
          index < clampedDifficulty ? Icons.star_rounded : Icons.star_outline_rounded,
          size: iconSize,
          color: index < clampedDifficulty ? color : AppColors.textHint,
        );
      }),
    );
  }
}

// ============================================================
// MasteryProgressBar - 掌握度进度条组件
// ============================================================

/// MasteryProgressBar: 掌握度进度条组件
class MasteryProgressBar extends StatelessWidget {
  final int mastery; // 0-100
  final double height;
  final bool showLabel;
  final double? width;

  const MasteryProgressBar({
    super.key,
    required this.mastery,
    this.height = 8,
    this.showLabel = true,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clampedMastery = mastery.clamp(0, 100);
    final color = getMasteryColor(clampedMastery);
    final label = getMasteryLabel(clampedMastery);

    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveWidth = width ?? constraints.maxWidth;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showLabel) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: AppFontSize.sm,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '$clampedMastery%',
                    style: TextStyle(
                      fontSize: AppFontSize.sm,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            SizedBox(
              width: effectiveWidth,
              height: height,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(height / 2),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(height / 2),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                      width: effectiveWidth * (clampedMastery / 100),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(height / 2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================
// ConfirmDeleteDialog - 删除确认对话框
// ============================================================

/// ConfirmDeleteDialog: 删除确认对话框
class ConfirmDeleteDialog extends StatelessWidget {
  final String title;
  final String? message;
  final String confirmText;
  final String cancelText;
  final VoidCallback? onConfirm;

  const ConfirmDeleteDialog({
    super.key,
    this.title = '确认删除',
    this.message = '此操作不可撤销，确定要删除吗？',
    this.confirmText = '删除',
    this.cancelText = '取消',
    this.onConfirm,
  });

  /// 显示删除确认对话框
  static Future<bool?> show({
    required BuildContext context,
    String title = '确认删除',
    String? message,
    String confirmText = '删除',
    String cancelText = '取消',
    VoidCallback? onConfirm,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConfirmDeleteDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 32),
      title: Text(title),
      content: Text(
        message ?? '此操作不可撤销，确定要删除吗？',
        style: theme.textTheme.bodyMedium,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
          ),
          onPressed: () {
            onConfirm?.call();
            Navigator.of(context).pop(true);
          },
          child: Text(confirmText),
        ),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
    );
  }
}

// ============================================================
// BatchOperationBar - 批量操作工具栏
// ============================================================

/// BatchOperationBar: 批量操作工具栏（全选、删除、导出等）
class BatchOperationBar extends StatelessWidget {
  final int totalCount;
  final int selectedCount;
  final ValueChanged<bool>? onSelectAll;
  final VoidCallback? onDelete;
  final VoidCallback? onExport;
  final VoidCallback? onCancel;
  final bool isAllSelected;

  const BatchOperationBar({
    super.key,
    required this.totalCount,
    required this.selectedCount,
    this.onSelectAll,
    this.onDelete,
    this.onExport,
    this.onCancel,
    this.isAllSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth > 600 ? 32 : 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // 全选
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: isAllSelected,
                onChanged: (value) => onSelectAll?.call(value ?? false),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '已选 $selectedCount/$totalCount',
              style: TextStyle(
                fontSize: AppFontSize.md,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            // 取消
            if (onCancel != null) ...[
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onCancel,
                tooltip: '取消',
                iconSize: 22,
              ),
              const SizedBox(width: 4),
            ],
            // 导出
            if (onExport != null) ...[
              IconButton(
                icon: const Icon(Icons.file_download_outlined),
                onPressed: selectedCount > 0 ? onExport : null,
                tooltip: '导出',
                iconSize: 22,
                color: selectedCount > 0
                    ? theme.colorScheme.primary
                    : AppColors.textHint,
              ),
              const SizedBox(width: 4),
            ],
            // 删除
            if (onDelete != null) ...[
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: selectedCount > 0 ? onDelete : null,
                tooltip: '删除',
                iconSize: 22,
                color: selectedCount > 0
                    ? AppColors.error
                    : AppColors.textHint,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
