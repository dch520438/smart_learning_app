import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

// ============================================================
// SettingsScreen - 设置主页面
// ============================================================

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 主题设置卡片
          _buildSectionTitle('主题风格'),
          const SizedBox(height: 12),
          _buildThemeSettingsCard(),

          const SizedBox(height: 24),

          // 其他设置
          _buildSectionTitle('其他设置'),
          const SizedBox(height: 12),
          _buildOtherSettingsCard(),

          const SizedBox(height: 24),

          // 关于
          _buildSectionTitle('关于'),
          const SizedBox(height: 12),
          _buildAboutCard(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: AppFontSize.md,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildThemeSettingsCard() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return AppCard(
          child: Column(
            children: [
              // 主题色选择
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: themeProvider.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.color_lens,
                    color: themeProvider.primaryColor,
                  ),
                ),
                title: const Text('主题色'),
                subtitle: Text(ThemeProvider.getThemeColorName(themeProvider.themeColor)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showThemeColorPicker(themeProvider),
              ),
              const Divider(height: 1),

              // 字体大小
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.format_size,
                    color: AppColors.info,
                  ),
                ),
                title: const Text('字体大小'),
                subtitle: Text(ThemeProvider.getFontSizeName(themeProvider.fontSize)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showFontSizePicker(themeProvider),
              ),
              const Divider(height: 1),

              // 字体风格
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.font_download,
                    color: AppColors.success,
                  ),
                ),
                title: const Text('字体风格'),
                subtitle: Text(ThemeProvider.getFontFamilyName(themeProvider.fontFamily)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showFontFamilyPicker(themeProvider),
              ),
              const Divider(height: 1),

              // 圆角风格
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.rounded_corner,
                    color: AppColors.warning,
                  ),
                ),
                title: const Text('圆角风格'),
                subtitle: Text(ThemeProvider.getRadiusStyleName(themeProvider.radiusStyle)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showRadiusStylePicker(themeProvider),
              ),
              const Divider(height: 1),

              // 深色模式
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.dark_mode,
                    color: AppColors.textSecondary,
                  ),
                ),
                title: const Text('深色模式'),
                subtitle: Text(themeProvider.isDarkMode ? '已开启' : '已关闭'),
                trailing: Switch(
                  value: themeProvider.isDarkMode,
                  onChanged: (value) {
                    themeProvider.setThemeMode(
                      value ? ThemeMode.dark : ThemeMode.light,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOtherSettingsCard() {
    return AppCard(
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                Icons.notifications,
                color: AppColors.primary,
              ),
            ),
            title: const Text('通知提醒'),
            subtitle: const Text('学习提醒、复习提醒'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showSnackBar(context, '功能开发中...');
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                Icons.delete_sweep,
                color: AppColors.error,
              ),
            ),
            title: const Text('清理缓存'),
            subtitle: const Text('释放存储空间'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showSnackBar(context, '缓存已清理');
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                Icons.backup,
                color: AppColors.info,
              ),
            ),
            title: const Text('数据备份'),
            subtitle: const Text('导出/导入学习数据'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showSnackBar(context, '功能开发中...');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard() {
    return AppCard(
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                Icons.info,
                color: AppColors.primary,
              ),
            ),
            title: const Text('关于我们'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showAboutDialog();
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                Icons.star,
                color: AppColors.success,
              ),
            ),
            title: const Text('给个好评'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showSnackBar(context, '感谢您的支持！');
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                Icons.feedback,
                color: AppColors.warning,
              ),
            ),
            title: const Text('意见反馈'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showSnackBar(context, '功能开发中...');
            },
          ),
        ],
      ),
    );
  }

  // 显示主题色选择器
  void _showThemeColorPicker(ThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        return _ThemeColorPickerSheet(
          currentColor: themeProvider.themeColor,
          onColorSelected: (color) {
            themeProvider.setThemeColor(color);
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  // 显示字体大小选择器
  void _showFontSizePicker(ThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        return _FontSizePickerSheet(
          currentSize: themeProvider.fontSize,
          onSizeSelected: (size) {
            themeProvider.setFontSize(size);
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  // 显示字体风格选择器
  void _showFontFamilyPicker(ThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        return _FontFamilyPickerSheet(
          currentFamily: themeProvider.fontFamily,
          onFamilySelected: (family) {
            themeProvider.setFontFamily(family);
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  // 显示圆角风格选择器
  void _showRadiusStylePicker(ThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        return _RadiusStylePickerSheet(
          currentStyle: themeProvider.radiusStyle,
          onStyleSelected: (style) {
            themeProvider.setRadiusStyle(style);
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('关于智慧学习'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('智慧学习是一款专为学习者打造的知识管理工具。'),
              SizedBox(height: 12),
              Text('版本: 1.0.0'),
              SizedBox(height: 8),
              Text('开发者: Smart Learning Team'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================
// 主题色选择器底部弹窗
// ============================================================

class _ThemeColorPickerSheet extends StatelessWidget {
  final AppThemeColor currentColor;
  final ValueChanged<AppThemeColor> onColorSelected;

  const _ThemeColorPickerSheet({
    required this.currentColor,
    required this.onColorSelected,
  });

  Color _getColorValue(AppThemeColor color) {
    switch (color) {
      case AppThemeColor.blue:
        return const Color(0xFF1E88E5);
      case AppThemeColor.green:
        return const Color(0xFF43A047);
      case AppThemeColor.purple:
        return const Color(0xFF8E24AA);
      case AppThemeColor.orange:
        return const Color(0xFFFB8C00);
      case AppThemeColor.pink:
        return const Color(0xFFE91E63);
      case AppThemeColor.dark:
        return const Color(0xFF37474F);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '选择主题色',
                style: TextStyle(
                  fontSize: AppFontSize.xl,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: AppThemeColor.values.map((color) {
              final isSelected = color == currentColor;
              final colorValue = _getColorValue(color);
              return GestureDetector(
                onTap: () => onColorSelected(color),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: colorValue,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: colorValue.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 28)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ThemeProvider.getThemeColorName(color),
                      style: TextStyle(
                        fontSize: AppFontSize.sm,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? colorValue : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          // 实时预览
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '预览效果',
                  style: TextStyle(
                    fontSize: AppFontSize.sm,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        child: const Text('主要按钮'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {},
                        child: const Text('次要按钮'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ============================================================
// 字体大小选择器底部弹窗
// ============================================================

class _FontSizePickerSheet extends StatelessWidget {
  final AppFontSizeOption currentSize;
  final ValueChanged<AppFontSizeOption> onSizeSelected;

  const _FontSizePickerSheet({
    required this.currentSize,
    required this.onSizeSelected,
  });

  double _getScaleValue(AppFontSizeOption size) {
    switch (size) {
      case AppFontSizeOption.small:
        return 0.875;
      case AppFontSizeOption.medium:
        return 1.0;
      case AppFontSizeOption.large:
        return 1.125;
      case AppFontSizeOption.extraLarge:
        return 1.25;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '选择字体大小',
                style: TextStyle(
                  fontSize: AppFontSize.xl,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...AppFontSizeOption.values.map((size) {
            final isSelected = size == currentSize;
            final scale = _getScaleValue(size);
            return GestureDetector(
              onTap: () => onSizeSelected(size),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.divider,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ThemeProvider.getFontSizeName(size),
                            style: TextStyle(
                              fontSize: 16 * scale,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '示例文字: 智慧学习让知识管理更高效',
                            style: TextStyle(
                              fontSize: 14 * scale,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: AppColors.primary),
                  ],
                ),
              ),
            );
          }).toList(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ============================================================
// 字体风格选择器底部弹窗
// ============================================================

class _FontFamilyPickerSheet extends StatelessWidget {
  final AppFontFamily currentFamily;
  final ValueChanged<AppFontFamily> onFamilySelected;

  const _FontFamilyPickerSheet({
    required this.currentFamily,
    required this.onFamilySelected,
  });

  String? _getFontFamilyName(AppFontFamily family) {
    switch (family) {
      case AppFontFamily.system:
        return 'WQYMicroHei';
      case AppFontFamily.songti:
        return 'WQYMicroHei';
      case AppFontFamily.heiti:
        return 'WQYMicroHei';
      case AppFontFamily.kaiti:
        return 'WQYMicroHei';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '选择字体风格',
                style: TextStyle(
                  fontSize: AppFontSize.xl,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...AppFontFamily.values.map((family) {
            final isSelected = family == currentFamily;
            final fontFamily = _getFontFamilyName(family);
            return GestureDetector(
              onTap: () => onFamilySelected(family),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.divider,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ThemeProvider.getFontFamilyName(family),
                            style: TextStyle(
                              fontSize: AppFontSize.lg,
                              fontWeight: FontWeight.w600,
                              fontFamily: fontFamily,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '智慧学习让知识管理更高效',
                            style: TextStyle(
                              fontSize: AppFontSize.md,
                              fontFamily: fontFamily,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: AppColors.primary),
                  ],
                ),
              ),
            );
          }).toList(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ============================================================
// 圆角风格选择器底部弹窗
// ============================================================

class _RadiusStylePickerSheet extends StatelessWidget {
  final AppRadiusStyle currentStyle;
  final ValueChanged<AppRadiusStyle> onStyleSelected;

  const _RadiusStylePickerSheet({
    required this.currentStyle,
    required this.onStyleSelected,
  });

  double _getRadiusValue(AppRadiusStyle style) {
    switch (style) {
      case AppRadiusStyle.sharp:
        return 0;
      case AppRadiusStyle.small:
        return 8;
      case AppRadiusStyle.large:
        return 16;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '选择圆角风格',
                style: TextStyle(
                  fontSize: AppFontSize.xl,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...AppRadiusStyle.values.map((style) {
            final isSelected = style == currentStyle;
            final radius = _getRadiusValue(style);
            return GestureDetector(
              onTap: () => onStyleSelected(style),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.divider,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // 预览形状
                    Container(
                      width: 60,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(radius),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        ThemeProvider.getRadiusStyleName(style),
                        style: TextStyle(
                          fontSize: AppFontSize.lg,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: AppColors.primary),
                  ],
                ),
              ),
            );
          }).toList(),
          const SizedBox(height: 20),
          // 预览区域
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '预览效果',
                  style: TextStyle(
                    fontSize: AppFontSize.sm,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.folder),
                    title: const Text('卡片标题'),
                    subtitle: const Text('卡片内容预览'),
                    trailing: const Icon(Icons.more_vert),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_getRadiusValue(currentStyle)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
