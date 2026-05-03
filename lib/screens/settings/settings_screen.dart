import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/theme_provider.dart';
import '../../services/storage_service.dart';
import '../../utils/constants.dart';

/// 设置页面
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // SharedPreferences 实例
  late SharedPreferences _prefs;

  // ========== 外观设置 ==========
  ThemeMode _themeMode = ThemeMode.system;
  Color _themeColor = const Color(0xFF4A90D9);
  double _fontSizeScale = 1.0; // 0.85=小, 1.0=中, 1.15=大, 1.3=特大

  // ========== 学习设置 ==========
  double _dailyGoalMinutes = 60;
  String _defaultSubject = '未设置';
  bool _reviewReminder = true;

  // ========== 数据设置 ==========
  bool _autoBackup = false;
  String _backupFrequency = '每周';
  String _storageUsage = '计算中...';

  // ========== 导航设置 ==========
  String _navBarMode = '滑动隐藏';
  String _startPage = '首页';

  // 预设主题色列表
  static const List<Color> _presetColors = [
    Color(0xFF4A90D9), // 蓝色（默认）
    Color(0xFFE53935), // 红色
    Color(0xFF43A047), // 绿色
    Color(0xFFFB8C00), // 橙色
    Color(0xFF8E24AA), // 紫色
    Color(0xFF00ACC1), // 青色
    Color(0xFF5C6BC0), // 靛蓝
    Color(0xFFD81B60), // 粉色
    Color(0xFF6D4C41), // 棕色
    Color(0xFF3949AB), // 深蓝
  ];

  // 字体大小选项
  static const List<Map<String, dynamic>> _fontSizeOptions = [
    {'label': '小', 'scale': 0.85},
    {'label': '中', 'scale': 1.0},
    {'label': '大', 'scale': 1.15},
    {'label': '特大', 'scale': 1.3},
  ];

  // 导航栏模式选项
  static const List<String> _navBarModes = [
    '始终显示',
    '滑动隐藏',
    '自动隐藏',
  ];

  // 起始页面选项
  static const List<String> _startPages = [
    '首页',
    '知识库',
    '笔记',
    '考试',
    '我的',
  ];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();

    setState(() {
      // 外观设置
      final themeValue = _prefs.getString('theme_mode');
      switch (themeValue) {
        case 'dark':
          _themeMode = ThemeMode.dark;
          break;
        case 'light':
          _themeMode = ThemeMode.light;
          break;
        default:
          _themeMode = ThemeMode.system;
      }

      final colorValue = _prefs.getInt('theme_color');
      if (colorValue != null && colorValue < _presetColors.length) {
        _themeColor = _presetColors[colorValue];
      }

      _fontSizeScale = _prefs.getDouble('font_size_scale') ?? 1.0;

      // 学习设置
      _dailyGoalMinutes = _prefs.getInt('daily_goal_minutes') ?? 60;
      _defaultSubject = _prefs.getString('default_subject') ?? '未设置';
      _reviewReminder = _prefs.getBool('review_reminder') ?? true;

      // 数据设置
      _autoBackup = _prefs.getBool('auto_backup') ?? false;
      _backupFrequency = _prefs.getString('backup_frequency') ?? '每周';

      // 导航设置
      _navBarMode = _prefs.getString('nav_bar_mode') ?? '滑动隐藏';
      _startPage = _prefs.getString('start_page') ?? '首页';

      _isLoading = false;
    });

    // 异步加载存储空间
    _loadStorageUsage();
  }

  Future<void> _loadStorageUsage() async {
    try {
      final storageService = StorageService();
      final usage = await storageService.getStorageUsage();
      if (mounted) {
        setState(() {
          _storageUsage = usage.formattedSize;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _storageUsage = '未知';
        });
      }
    }
  }

  // ========== 设置保存方法 ==========

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    await _prefs.setString('theme_mode', mode.name);
    context.read<ThemeProvider>().setThemeMode(mode);
  }

  Future<void> _setThemeColor(int colorIndex) async {
    setState(() => _themeColor = _presetColors[colorIndex]);
    await _prefs.setInt('theme_color', colorIndex);
  }

  Future<void> _setFontSizeScale(double scale) async {
    setState(() => _fontSizeScale = scale);
    await _prefs.setDouble('font_size_scale', scale);
  }

  Future<void> _setDailyGoal(int minutes) async {
    setState(() => _dailyGoalMinutes = minutes);
    await _prefs.setInt('daily_goal_minutes', minutes);
  }

  Future<void> _setDefaultSubject(String subject) async {
    setState(() => _defaultSubject = subject);
    await _prefs.setString('default_subject', subject);
  }

  Future<void> _setReviewReminder(bool value) async {
    setState(() => _reviewReminder = value);
    await _prefs.setBool('review_reminder', value);
  }

  Future<void> _setAutoBackup(bool value) async {
    setState(() => _autoBackup = value);
    await _prefs.setBool('auto_backup', value);
  }

  Future<void> _setBackupFrequency(String frequency) async {
    setState(() => _backupFrequency = frequency);
    await _prefs.setString('backup_frequency', frequency);
  }

  Future<void> _setNavBarMode(String mode) async {
    setState(() => _navBarMode = mode);
    await _prefs.setString('nav_bar_mode', mode);
  }

  Future<void> _setStartPage(String page) async {
    setState(() => _startPage = page);
    await _prefs.setString('start_page', page);
  }

  // ========== 获取字体大小标签 ==========
  String _getFontSizeLabel() {
    for (final option in _fontSizeOptions) {
      if ((option['scale'] as double) == _fontSizeScale) {
        return option['label'] as String;
      }
    }
    return '中';
  }

  // ========== 显示主题色选择器 ==========
  void _showThemeColorPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '选择主题色',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: _presetColors.asMap().entries.map((entry) {
                  final index = entry.key;
                  final color = entry.value;
                  final isSelected = _themeColor == color;
                  return GestureDetector(
                    onTap: () {
                      _setThemeColor(index);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(context)
                                        .brightness ==
                                    Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                                width: 3,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 24,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ========== 显示字体大小选择器 ==========
  void _showFontSizePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '字体大小',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              ..._fontSizeOptions.map((option) {
                final label = option['label'] as String;
                final scale = option['scale'] as double;
                final isSelected = _fontSizeScale == scale;
                return RadioListTile<double>(
                  title: Text(
                    label,
                    style: TextStyle(fontSize: 14 * scale),
                  ),
                  subtitle: Text(
                    '预览文字 AaBbCc',
                    style: TextStyle(fontSize: 12 * scale, color: Colors.grey),
                  ),
                  value: scale,
                  groupValue: _fontSizeScale,
                  activeColor: _themeColor,
                  onChanged: (value) {
                    if (value != null) {
                      _setFontSizeScale(value);
                      Navigator.pop(context);
                    }
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ========== 显示默认学科选择器 ==========
  void _showSubjectPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '默认学科',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              RadioListTile<String>(
                title: const Text('未设置'),
                value: '未设置',
                groupValue: _defaultSubject,
                activeColor: _themeColor,
                onChanged: (value) {
                  if (value != null) {
                    _setDefaultSubject(value);
                    Navigator.pop(context);
                  }
                },
              ),
              ...kSubjectNames.map((subject) {
                return RadioListTile<String>(
                  title: Text(subject),
                  value: subject,
                  groupValue: _defaultSubject,
                  activeColor: _themeColor,
                  secondary: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: kSubjectColors[subject] ?? Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      _setDefaultSubject(value);
                      Navigator.pop(context);
                    }
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ========== 显示备份频率选择器 ==========
  void _showBackupFrequencyPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '备份频率',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              ...['每天', '每周'].map((frequency) {
                return RadioListTile<String>(
                  title: Text(frequency),
                  subtitle: Text(frequency == '每天' ? '每天自动备份一次' : '每周自动备份一次'),
                  value: frequency,
                  groupValue: _backupFrequency,
                  activeColor: _themeColor,
                  onChanged: (value) {
                    if (value != null) {
                      _setBackupFrequency(value);
                      Navigator.pop(context);
                    }
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ========== 显示导航栏模式选择器 ==========
  void _showNavBarModePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '导航栏显示模式',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              ..._navBarModes.map((mode) {
                return RadioListTile<String>(
                  title: Text(mode),
                  subtitle: Text(_getNavBarModeDescription(mode)),
                  value: mode,
                  groupValue: _navBarMode,
                  activeColor: _themeColor,
                  onChanged: (value) {
                    if (value != null) {
                      _setNavBarMode(value);
                      Navigator.pop(context);
                    }
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _getNavBarModeDescription(String mode) {
    switch (mode) {
      case '始终显示':
        return '导航栏始终可见';
      case '滑动隐藏':
        return '向上滑动隐藏，向下滑动显示';
      case '自动隐藏':
        return '滚动时自动隐藏，停止滚动后显示';
      default:
        return '';
    }
  }

  // ========== 显示起始页面选择器 ==========
  void _showStartPagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '起始页面',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              ..._startPages.map((page) {
                return RadioListTile<String>(
                  title: Text(page),
                  value: page,
                  groupValue: _startPage,
                  activeColor: _themeColor,
                  onChanged: (value) {
                    if (value != null) {
                      _setStartPage(value);
                      Navigator.pop(context);
                    }
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ========== 显示隐私政策 ==========
  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('隐私政策'),
        content: const SingleChildScrollView(
          child: Text(
            '智慧学习 隐私政策\n\n'
            '最后更新日期：2024年1月1日\n\n'
            '1. 信息收集\n'
            '本应用仅收集和使用您主动提供的学习相关数据，包括但不限于：\n'
            '- 个人信息（姓名、年级、学校）\n'
            '- 学习记录（学习时长、学习内容）\n'
            '- 知识点、笔记、错题等学习资料\n'
            '- 考试记录和成绩\n\n'
            '2. 数据存储\n'
            '所有数据均存储在您的设备本地，不会上传至任何远程服务器。\n'
            '我们不会通过任何方式将您的数据传输给第三方。\n\n'
            '3. 数据安全\n'
            '我们采用行业标准的加密措施保护您的数据安全。\n'
            '数据备份和导出功能完全由您自主控制。\n\n'
            '4. 数据删除\n'
            '您可以随时通过"清除所有数据"功能删除所有本地数据。\n'
            '数据删除后不可恢复，请谨慎操作。\n\n'
            '5. 权限使用\n'
            '- 相机权限：用于拍照识别题目（OCR功能）\n'
            '- 存储权限：用于导入导出数据和保存附件\n'
            '- 麦克风权限：用于语音输入功能\n\n'
            '6. 儿童隐私保护\n'
            '本应用重视儿童隐私保护，不会收集14岁以下儿童的个人信息。\n\n'
            '7. 政策更新\n'
            '我们可能会不时更新本隐私政策，更新后的政策将在应用内公布。\n\n'
            '如有任何问题，请通过应用内反馈功能联系我们。',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  // ========== 显示使用帮助 ==========
  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('使用帮助'),
        content: const SingleChildScrollView(
          child: Text(
            '欢迎使用智慧学习！\n\n'
            '快速入门：\n\n'
            '1. 知识库\n'
            '   - 点击底部导航栏"知识库"进入\n'
            '   - 按学科分类管理知识点\n'
            '   - 支持添加标签、难度等级、掌握程度\n\n'
            '2. 笔记\n'
            '   - 点击底部导航栏"笔记"进入\n'
            '   - 支持富文本编辑\n'
            '   - 可关联知识点和附件\n\n'
            '3. 错题本\n'
            '   - 从个人中心"错题本"进入\n'
            '   - 记录错题、分析错误原因\n'
            '   - 支持标记已掌握\n\n'
            '4. 母题集\n'
            '   - 从个人中心"母题集"进入\n'
            '   - 记录典型题目和解题方法\n'
            '   - 支持变式练习\n\n'
            '5. 必记必背\n'
            '   - 从个人中心"必记必背"进入\n'
            '   - 记录公式、定理等必记内容\n'
            '   - 支持艾宾浩斯复习提醒\n\n'
            '6. 数据管理\n'
            '   - 支持数据导出为JSON文件\n'
            '   - 支持从JSON文件导入\n'
            '   - 支持自动备份和手动备份\n\n'
            '如有更多问题，欢迎反馈！',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('设置')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ========== 外观设置 ==========
          _buildSectionHeader('外观'),
          _buildSectionCard([
            // 主题模式切换
            ListTile(
              leading: const Icon(Icons.brightness_6),
              title: const Text('主题模式'),
              subtitle: Text(_getThemeModeLabel(_themeMode)),
              trailing: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('系统', style: TextStyle(fontSize: 12)),
                    icon: Icon(Icons.brightness_auto, size: 16),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('亮色', style: TextStyle(fontSize: 12)),
                    icon: Icon(Icons.light_mode, size: 16),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('暗色', style: TextStyle(fontSize: 12)),
                    icon: Icon(Icons.dark_mode, size: 16),
                  ),
                ],
                selected: {_themeMode},
                onSelectionChanged: (selected) {
                  _setThemeMode(selected.first);
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),

            // 主题色选择
            ListTile(
              leading: const Icon(Icons.palette),
              title: const Text('主题色'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _themeColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _themeColor.withOpacity(0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
              onTap: _showThemeColorPicker,
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),

            // 字体大小
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('字体大小'),
              subtitle: Text('当前: ${_getFontSizeLabel()}'),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: _showFontSizePicker,
            ),
          ]),

          const SizedBox(height: 8),

          // ========== 学习设置 ==========
          _buildSectionHeader('学习'),
          _buildSectionCard([
            // 每日学习目标
            ListTile(
              leading: const Icon(Icons.flag),
              title: const Text('每日学习目标'),
              subtitle: Text('$_dailyGoalMinutes 分钟/天'),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => _showDailyGoalSlider(),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),

            // 默认学科设置
            ListTile(
              leading: const Icon(Icons.menu_book),
              title: const Text('默认学科'),
              subtitle: Text(_defaultSubject),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: _showSubjectPicker,
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),

            // 艾宾浩斯复习提醒
            SwitchListTile(
              secondary: const Icon(Icons.notifications_active),
              title: const Text('艾宾浩斯复习提醒'),
              subtitle: Text(_reviewReminder ? '已开启' : '已关闭'),
              value: _reviewReminder,
              activeColor: _themeColor,
              onChanged: _setReviewReminder,
            ),
          ]),

          const SizedBox(height: 8),

          // ========== 数据设置 ==========
          _buildSectionHeader('数据'),
          _buildSectionCard([
            // 自动备份
            SwitchListTile(
              secondary: const Icon(Icons.cloud_upload),
              title: const Text('自动备份'),
              subtitle: Text(_autoBackup ? '已开启' : '已关闭'),
              value: _autoBackup,
              activeColor: _themeColor,
              onChanged: _setAutoBackup,
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),

            // 备份频率
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('备份频率'),
              subtitle: Text(_backupFrequency),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: _autoBackup ? _showBackupFrequencyPicker : null,
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),

            // 存储空间
            ListTile(
              leading: const Icon(Icons.storage),
              title: const Text('存储空间'),
              subtitle: Text('已使用: $_storageUsage'),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {
                _loadStorageUsage();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('存储空间: $_storageUsage')),
                );
              },
            ),
          ]),

          const SizedBox(height: 8),

          // ========== 导航设置 ==========
          _buildSectionHeader('导航'),
          _buildSectionCard([
            // 导航栏显示模式
            ListTile(
              leading: const Icon(Icons.navigation),
              title: const Text('导航栏显示模式'),
              subtitle: Text(_navBarMode),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: _showNavBarModePicker,
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),

            // 起始页面
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('起始页面'),
              subtitle: Text(_startPage),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: _showStartPagePicker,
            ),
          ]),

          const SizedBox(height: 8),

          // ========== 关于 ==========
          _buildSectionHeader('关于'),
          _buildSectionCard([
            // 版本号
            const ListTile(
              leading: Icon(Icons.info),
              title: Text('版本号'),
              subtitle: Text('1.0.0 (Build 1)'),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),

            // 检查更新
            ListTile(
              leading: const Icon(Icons.system_update),
              title: const Text('检查更新'),
              subtitle: const Text('当前已是最新版本'),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('当前已是最新版本')),
                );
              },
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),

            // 隐私政策
            ListTile(
              leading: const Icon(Icons.privacy_tip),
              title: const Text('隐私政策'),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: _showPrivacyPolicy,
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),

            // 使用帮助
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('使用帮助'),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: _showHelp,
            ),
          ]),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// 构建分区标题
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 构建分区卡片
  Widget _buildSectionCard(List<Widget> children) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }

  /// 获取主题模式标签
  String _getThemeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return '跟随系统';
      case ThemeMode.light:
        return '亮色模式';
      case ThemeMode.dark:
        return '暗色模式';
    }
  }

  /// 显示每日学习目标滑块
  void _showDailyGoalSlider() {
    int tempValue = _dailyGoalMinutes;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('每日学习目标'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$tempValue 分钟/天',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _themeColor,
                ),
              ),
              const SizedBox(height: 16),
              Slider(
                value: tempValue.toDouble(),
                min: 10,
                max: 300,
                divisions: 29,
                activeColor: _themeColor,
                label: '$tempValue 分钟',
                onChanged: (value) {
                  setDialogState(() {
                    tempValue = value.round();
                  });
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('10分钟', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  Text('300分钟', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '建议每天至少学习30分钟',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                _setDailyGoal(tempValue);
                Navigator.pop(context);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }
}
