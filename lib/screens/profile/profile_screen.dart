import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/theme_provider.dart';
import '../../services/database_service.dart';
import '../../services/export_service.dart';
import '../../services/storage_service.dart';
import '../../utils/constants.dart';
import '../knowledge/knowledge_screen.dart';
import '../notes/notes_screen.dart';
import '../wrong_questions/wrong_questions_screen.dart';
import '../mother_questions/mother_questions_screen.dart';
import '../must_remember/must_remember_screen.dart';
import '../history/history_screen.dart';
import '../analysis/analysis_screen.dart';
import '../mind_map/mind_map_screen.dart';
import '../habits/habits_screen.dart';
import '../exam_papers/exam_papers_screen.dart';
import '../settings/settings_screen.dart';
import '../print/print_combination_screen.dart';

/// 个人中心页面
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // 用户信息
  String _userName = '学习者';
  String _userGrade = '';
  String _userSchool = '';
  String? _avatarPath;

  // 学习统计
  int _totalStudyDays = 0;
  int _totalStudyMinutes = 0;
  int _knowledgeCount = 0;
  int _noteCount = 0;
  int _wrongQuestionCount = 0;
  int _examCount = 0;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = DatabaseService();

    // 加载用户资料
    final profile = await db.getCurrentUserProfile();
    if (profile != null) {
      setState(() {
        _userName = profile['nickname'] as String? ?? '学习者';
        _userGrade = profile['grade'] as String? ?? '';
        _userSchool = profile['school'] as String? ?? '';
        _avatarPath = profile['avatar_path'] as String?;
        _totalStudyDays = profile['total_study_days'] as int? ?? 0;
        _totalStudyMinutes = profile['total_study_time'] as int? ?? 0;
      });
    }

    // 加载统计数据
    final knowledgeCount = await db.countKnowledgePoints();
    final noteCount = await db.countNotes();
    final wrongCount = await db.countWrongQuestions();
    final examCount = await db.countExams();
    final totalStudyTime = await db.getTotalStudyTime();

    setState(() {
      _knowledgeCount = knowledgeCount;
      _noteCount = noteCount;
      _wrongQuestionCount = wrongCount;
      _examCount = examCount;
      _totalStudyMinutes = totalStudyTime ~/ 60; // 秒转分钟
      _isLoading = false;
    });
  }

  /// 格式化学习时长
  String _formatStudyDuration(int minutes) {
    if (minutes < 60) return '$minutes分钟';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '$hours小时';
    return '$hours小时$mins分钟';
  }

  /// 编辑个人信息
  Future<void> _showEditProfileDialog() async {
    final nameController = TextEditingController(text: _userName);
    final gradeController = TextEditingController(text: _userGrade);
    final schoolController = TextEditingController(text: _userSchool);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑个人信息'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '姓名',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: gradeController,
                decoration: const InputDecoration(
                  labelText: '年级',
                  prefixIcon: Icon(Icons.school),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: schoolController,
                decoration: const InputDecoration(
                  labelText: '学校',
                  prefixIcon: Icon(Icons.location_city),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == true) {
      final db = DatabaseService();
      final profile = await db.getCurrentUserProfile();
      if (profile != null) {
        await db.updateUserProfile(profile['id'] as int, {
          'nickname': nameController.text.trim().isEmpty
              ? '学习者'
              : nameController.text.trim(),
          'grade': gradeController.text.trim(),
          'school': schoolController.text.trim(),
        });
      } else {
        await db.insertUserProfile({
          'uuid': DateTime.now().millisecondsSinceEpoch.toString(),
          'nickname': nameController.text.trim().isEmpty
              ? '学习者'
              : nameController.text.trim(),
          'grade': gradeController.text.trim(),
          'school': schoolController.text.trim(),
        });
      }
      _loadData();
    }
  }

  /// 数据导出 - 选择模块
  Future<void> _showExportDialog() async {
    final selectedModules = <String>{};

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('选择导出模块'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  title: const Text('全选'),
                  value: selectedModules.length ==
                      ExportService.allModules.length,
                  onChanged: (value) {
                    setDialogState(() {
                      if (value == true) {
                        selectedModules.clear();
                        selectedModules
                            .addAll(ExportService.allModules);
                      } else {
                        selectedModules.clear();
                      }
                    });
                  },
                ),
                const Divider(),
                ...ExportService.allModules.map((module) => CheckboxListTile(
                      title: Text(ExportService.getModuleName(module)),
                      value: selectedModules.contains(module),
                      onChanged: (value) {
                        setDialogState(() {
                          if (value == true) {
                            selectedModules.add(module);
                          } else {
                            selectedModules.remove(module);
                          }
                        });
                      },
                    )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: selectedModules.isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('导出'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedModules.isNotEmpty) {
      _doExport(selectedModules.toList());
    }
  }

  Future<void> _doExport(List<String> modules) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在导出数据...')),
    );

    try {
      final exportService = ExportService();
      final isAll = modules.length == ExportService.allModules.length;

      final result = isAll
          ? await exportService.exportAllToJson()
          : await exportService.exportModulesToJson(modules);

      if (result.success && result.filePath != null) {
        // 分享文件
        await Share.shareXFiles([XFile(result.filePath!)],
            text: '智慧学习 - 数据导出');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '导出成功！共 ${result.totalRecords} 条记录\n${result.formattedStats}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? '导出失败'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 数据导入
  Future<void> _doImport() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('正在导入数据...')),
        );

        final exportService = ExportService();
        final importResult = await exportService.importFromJsonFile(
          result.files.single.path!,
          mode: ImportMode.merge,
        );

        if (mounted) {
          if (importResult.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    '导入成功！共导入 ${importResult.totalRecords} 条记录'),
                backgroundColor: Colors.green,
              ),
            );
            _loadData();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(importResult.errorMessage ?? '导入失败'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 数据备份
  Future<void> _doBackup() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在创建备份...')),
      );

      final exportService = ExportService();
      final backupPath = await exportService.createBackup();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('备份成功！\n路径: $backupPath'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('备份失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 数据恢复 - 选择备份文件
  Future<void> _showRestoreDialog() async {
    try {
      final exportService = ExportService();
      final backups = await exportService.listBackups();

      if (backups.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('没有可用的备份文件')),
          );
        }
        return;
      }

      final result = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('选择备份文件恢复'),
          children: backups.map((backup) {
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(context, backup.path),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    backup.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${backup.exportTime ?? "未知时间"} | ${backup.formattedSize}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      );

      if (result != null) {
        _doRestore(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('获取备份列表失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _doRestore(String backupPath) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认恢复'),
        content: const Text(
            '恢复数据将清除当前所有数据并替换为备份数据，此操作不可撤销。\n\n确定要继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认恢复'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在恢复数据...')),
      );

      final exportService = ExportService();
      final restoreResult = await exportService.restoreFromBackup(backupPath);

      if (mounted) {
        if (restoreResult.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '恢复成功！共恢复 ${restoreResult.totalRecords} 条记录'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(restoreResult.errorMessage ?? '恢复失败'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('恢复失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 清除所有数据
  Future<void> _clearAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除所有数据'),
        content: const Text(
            '此操作将永久删除所有学习数据，包括知识点、笔记、错题、考试记录等。\n\n此操作不可撤销！\n\n建议先备份数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认清除'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 二次确认
    final doubleConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('最终确认'),
        content: const Text('请输入"确认删除"以继续清除操作：'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('我已了解风险'),
          ),
        ],
      ),
    );

    if (doubleConfirm != true) return;

    try {
      final db = DatabaseService();
      await db.clearAllData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('所有数据已清除'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('清除失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 显示关于对话框
  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: '智慧学习',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.school,
          color: Colors.white,
          size: 32,
        ),
      ),
      children: [
        const SizedBox(height: 8),
        const Text('全平台学习助手'),
        const SizedBox(height: 16),
        const Text(
          '功能特性：',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const Text('- 知识点管理与复习'),
        const Text('- 智能错题本'),
        const Text('- 母题集与变式练习'),
        const Text('- 必记必背内容管理'),
        const Text('- 学习记录与数据分析'),
        const Text('- 思维导图'),
        const Text('- 数据导入导出与备份'),
        const SizedBox(height: 16),
        const Text(
          '开源许可',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const Text('本应用使用了以下开源库：'),
        const Text('Flutter, Provider, SQFlite, Fl Chart,'),
        const Text('Google ML Kit, Syncfusion Charts 等'),
      ],
    );
  }

  /// 导航到子页面
  void _navigateTo(String route) {
    Widget? targetPage;
    
    switch (route) {
      case '/knowledge':
        targetPage = const KnowledgeScreen();
        break;
      case '/notes':
        targetPage = const NotesScreen();
        break;
      case '/wrong_questions':
        targetPage = const WrongQuestionsScreen();
        break;
      case '/mother_questions':
        targetPage = const MotherQuestionsScreen();
        break;
      case '/must_remember':
        targetPage = const MustRememberScreen();
        break;
      case '/history':
        targetPage = const HistoryScreen();
        break;
      case '/analysis':
        targetPage = const AnalysisScreen();
        break;
      case '/mind_map':
        targetPage = const MindMapScreen();
        break;
      case '/habits':
        targetPage = const HabitsScreen();
        break;
      case '/exam_papers':
        targetPage = const ExamPapersScreen();
        break;
      case '/settings':
        targetPage = const SettingsScreen();
        break;
      case '/print_combination':
        targetPage = const PrintCombinationScreen();
        break;
      case '/exam':
        // 考试模块暂时显示提示
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('考试功能开发中...')),
        );
        return;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('页面 $route 开发中...')),
        );
        return;
    }
    
    if (targetPage != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => targetPage!),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _navigateTo('/settings'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ========== 用户头像区域 ==========
                    _buildUserHeader(theme, colorScheme),
                    const SizedBox(height: 16),

                    // ========== 学习统计卡片 ==========
                    _buildStatsCard(theme, colorScheme),
                    const SizedBox(height: 16),

                    // ========== 功能入口列表 ==========
                    _buildFeatureList(theme, colorScheme),
                    const SizedBox(height: 16),

                    // ========== 数据管理区域 ==========
                    _buildDataManagement(theme, colorScheme),
                    const SizedBox(height: 16),

                    // ========== 设置与关于 ==========
                    _buildSettingsAndAbout(theme, colorScheme),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  /// 构建用户头像区域
  Widget _buildUserHeader(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: _showEditProfileDialog,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // 大圆形头像
              GestureDetector(
                onTap: () {
                  // TODO: 实现更换头像功能（使用 image_picker）
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('头像更换功能开发中')),
                  );
                },
                child: Stack(
                  children: [
                    _avatarPath != null && _avatarPath!.isNotEmpty
                        ? CircleAvatar(
                            radius: 40,
                            backgroundImage: FileImage(File(_avatarPath!)),
                          )
                        : CircleAvatar(
                            radius: 40,
                            backgroundColor: colorScheme.primary,
                            child: Text(
                              _userName.isNotEmpty ? _userName[0] : '学',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.cardTheme.color ?? Colors.white,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          size: 12,
                          color: theme.brightness == Brightness.dark
                              ? Colors.white
                              : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // 用户信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_userGrade.isNotEmpty || _userSchool.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (_userGrade.isNotEmpty) ...[
                            Icon(Icons.school,
                                size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              _userGrade,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                          if (_userGrade.isNotEmpty && _userSchool.isNotEmpty)
                            const SizedBox(width: 12),
                          if (_userSchool.isNotEmpty) ...[
                            Icon(Icons.location_city,
                                size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              _userSchool,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 28,
                      child: OutlinedButton.icon(
                        onPressed: _showEditProfileDialog,
                        icon: const Icon(Icons.edit, size: 14),
                        label: const Text('编辑信息', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 右侧箭头
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建学习统计卡片
  Widget _buildStatsCard(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  '学习统计',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 第一行统计
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.calendar_today,
                    iconColor: Colors.blue,
                    value: '$_totalStudyDays',
                    label: '学习天数',
                    onTap: () => _navigateTo('/history'),
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.timer,
                    iconColor: Colors.orange,
                    value: _formatStudyDuration(_totalStudyMinutes),
                    label: '学习时长',
                    onTap: () => _navigateTo('/analysis'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 第二行统计
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.lightbulb,
                    iconColor: Colors.amber,
                    value: '$_knowledgeCount',
                    label: '知识点',
                    onTap: () => _navigateTo('/knowledge'),
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.note,
                    iconColor: Colors.green,
                    value: '$_noteCount',
                    label: '笔记',
                    onTap: () => _navigateTo('/notes'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 第三行统计
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.error_outline,
                    iconColor: Colors.red,
                    value: '$_wrongQuestionCount',
                    label: '错题',
                    onTap: () => _navigateTo('/wrong_questions'),
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.quiz,
                    iconColor: Colors.purple,
                    value: '$_examCount',
                    label: '测试次数',
                    onTap: () => _navigateTo('/exam'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建功能入口列表
  Widget _buildFeatureList(ThemeData theme, ColorScheme colorScheme) {
    final featureItems = [
      _FeatureItem(
        icon: Icons.library_books,
        iconColor: Colors.blue,
        title: '我的知识库',
        subtitle: '查看和管理所有知识点',
        route: '/knowledge',
      ),
      _FeatureItem(
        icon: Icons.note,
        iconColor: Colors.green,
        title: '我的笔记',
        subtitle: '查看和管理学习笔记',
        route: '/notes',
      ),
      _FeatureItem(
        icon: Icons.error_outline,
        iconColor: Colors.red,
        title: '错题本',
        subtitle: '查看和管理错题记录',
        route: '/wrong_questions',
      ),
      _FeatureItem(
        icon: Icons.psychology,
        iconColor: Colors.purple,
        title: '母题集',
        subtitle: '查看和管理母题与变式',
        route: '/mother_questions',
      ),
      _FeatureItem(
        icon: Icons.star,
        iconColor: Colors.orange,
        title: '必记必背',
        subtitle: '查看和管理必记必背内容',
        route: '/must_remember',
      ),
      _FeatureItem(
        icon: Icons.history,
        iconColor: Colors.teal,
        title: '学习历史',
        subtitle: '查看学习记录与时间线',
        route: '/history',
      ),
      _FeatureItem(
        icon: Icons.bar_chart,
        iconColor: Colors.indigo,
        title: '学习分析',
        subtitle: '查看学习数据分析报告',
        route: '/analysis',
      ),
      _FeatureItem(
        icon: Icons.account_tree,
        iconColor: Colors.cyan,
        title: '思维导图',
        subtitle: '查看和管理思维导图',
        route: '/mind_map',
      ),
      _FeatureItem(
        icon: Icons.local_fire_department,
        iconColor: Colors.deepOrange,
        title: '习惯打卡',
        subtitle: '培养学习习惯，坚持每日打卡',
        route: '/habits',
      ),
      _FeatureItem(
        icon: Icons.description,
        iconColor: Colors.blueGrey,
        title: '试卷收集',
        subtitle: '整理试卷、OCR识别',
        route: '/exam_papers',
      ),
      _FeatureItem(
        icon: Icons.post_add,
        iconColor: Colors.amber,
        title: '组合打印',
        subtitle: '选择多个内容合并打印',
        route: '/print_combination',
      ),
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: featureItems.map((item) {
          final index = featureItems.indexOf(item);
          return Column(
            children: [
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: item.iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: item.iconColor, size: 22),
                ),
                title: Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  item.subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => _navigateTo(item.route),
              ),
              if (index < featureItems.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(height: 1),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// 构建数据管理区域
  Widget _buildDataManagement(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.storage, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  '数据管理',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file, color: Colors.blue),
            title: const Text('数据导出'),
            subtitle: const Text('选择模块导出为JSON文件'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: _showExportDialog,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1),
          ),
          ListTile(
            leading: const Icon(Icons.download, color: Colors.green),
            title: const Text('数据导入'),
            subtitle: const Text('从JSON文件导入数据'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: _doImport,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1),
          ),
          ListTile(
            leading: const Icon(Icons.backup, color: Colors.orange),
            title: const Text('数据备份'),
            subtitle: const Text('创建完整数据备份'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: _doBackup,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1),
          ),
          ListTile(
            leading: const Icon(Icons.restore, color: Colors.teal),
            title: const Text('数据恢复'),
            subtitle: const Text('从备份文件恢复数据'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: _showRestoreDialog,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('清除所有数据'),
            subtitle: const Text('删除所有学习数据（不可撤销）'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: _clearAllData,
          ),
        ],
      ),
    );
  }

  /// 构建设置与关于
  Widget _buildSettingsAndAbout(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.palette, color: Colors.deepPurple),
            title: const Text('主题设置'),
            subtitle: const Text('主题色、字体大小、深色模式'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const SettingsScreen(),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1),
          ),
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.grey),
            title: const Text('设置'),
            subtitle: const Text('学习目标、通知等'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => _navigateTo('/settings'),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.grey),
            title: const Text('关于'),
            subtitle: const Text('版本信息与开源许可'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: _showAboutDialog,
          ),
        ],
      ),
    );
  }
}

/// 功能入口项数据模型
class _FeatureItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String route;

  const _FeatureItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.route,
  });
}
