import 'package:flutter/material.dart';
import '../../services/ai_config_service.dart';
import '../../utils/constants.dart';
import '../../widgets/common_widgets.dart';

// ============================================================
// AI 设置页面
// ============================================================

/// AI设置页面 - 配置AI模型
class AISettingsScreen extends StatefulWidget {
  const AISettingsScreen({super.key});

  @override
  State<AISettingsScreen> createState() => _AISettingsScreenState();
}

class _AISettingsScreenState extends State<AISettingsScreen> {
  final AIService _aiService = AIService();
  late List<AIModelConfig> _models;

  // 当前选中的模型
  AIModelConfig? _selectedModel;
  bool _isTesting = false;
  bool? _connectionStatus;
  String? _errorMessage;

  // API Key控制器
  final Map<String, TextEditingController> _apiKeyControllers = {};

  @override
  void initState() {
    super.initState();
    _models = _aiService.availableModels;
    _selectedModel = _aiService.currentConfig;
    _initApiKeyControllers();
  }

  void _initApiKeyControllers() {
    for (final model in _models) {
      _apiKeyControllers[model.id] = TextEditingController(
        text: model.apiKey ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _apiKeyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI设置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelp,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 当前状态卡片
          _buildStatusCard(),

          const SizedBox(height: 24),

          // 模型选择
          _buildSectionTitle('选择AI模型'),
          const SizedBox(height: 12),
          _buildModelList(),

          const SizedBox(height: 24),

          // API Key配置（如果是在线模型）
          if (_selectedModel?.type == AIModelType.online) ...[
            _buildSectionTitle('API Key配置'),
            const SizedBox(height: 12),
            _buildApiKeySection(),
          ],

          // 本地模型提示
          if (_selectedModel?.type == AIModelType.local) ...[
            _buildSectionTitle('本地模型说明'),
            const SizedBox(height: 12),
            _buildLocalModelInfo(),
          ],

          const SizedBox(height: 24),

          // 测试连接
          _buildTestSection(),

          const SizedBox(height: 32),

          // 保存按钮
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: AppFontSize.md,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildStatusCard() {
    final isConfigured = _aiService.isConfigured;
    final currentModel = _aiService.currentConfig;

    return AppCard(
      color: isConfigured
          ? AppColors.success.withOpacity(0.1)
          : AppColors.warning.withOpacity(0.1),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isConfigured
                  ? AppColors.success.withOpacity(0.2)
                  : AppColors.warning.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              isConfigured ? Icons.check_circle : Icons.warning_amber,
              color: isConfigured ? AppColors.success : AppColors.warning,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConfigured ? 'AI已配置' : 'AI未配置',
                  style: TextStyle(
                    fontSize: AppFontSize.lg,
                    fontWeight: FontWeight.w600,
                    color: isConfigured ? AppColors.success : AppColors.warning,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentModel != null
                      ? '当前模型: ${currentModel.name}'
                      : '请选择并配置AI模型',
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

  Widget _buildModelList() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: _models.asMap().entries.map((entry) {
          final index = entry.key;
          final model = entry.value;
          final isSelected = _selectedModel?.id == model.id;

          return Column(
            children: [
              ListTile(
                leading: _buildModelLogo(model),
                title: Text(
                  model.name,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (model.description != null)
                      Text(
                        model.description!,
                        style: TextStyle(
                          fontSize: AppFontSize.xs,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildModelBadge(
                          model.type == AIModelType.local ? '本地' : '在线',
                          model.type == AIModelType.local
                              ? AppColors.info
                              : AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        if (model.isFree)
                          _buildModelBadge('免费', AppColors.success),
                      ],
                    ),
                  ],
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: AppColors.primary)
                    : const Icon(Icons.circle_outlined, color: AppColors.divider),
                onTap: () {
                  setState(() {
                    _selectedModel = model;
                    _connectionStatus = null;
                    _errorMessage = null;
                  });
                },
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              if (index < _models.length - 1) const Divider(height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildModelLogo(AIModelConfig model) {
    IconData icon;
    Color color;

    switch (model.logoIcon) {
      case 'gem':
        icon = Icons.auto_awesome;
        color = const Color(0xFF4285F4);
        break;
      case 'groq':
        icon = Icons.bolt;
        color = const Color(0xFF00D4AA);
        break;
      case 'cohere':
        icon = Icons.hub;
        color = const Color(0xFF0F9D58);
        break;
      case 'zhipu':
        icon = Icons.psychology;
        color = const Color(0xFFE91E63);
        break;
      case 'qwen':
        icon = Icons.smart_toy;
        color = const Color(0xFFFF6B00);
        break;
      case 'ollama':
        icon = Icons.computer;
        color = const Color(0xFF7B68EE);
        break;
      default:
        icon = Icons.cloud;
        color = AppColors.primary;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildModelBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: AppFontSize.xs,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildApiKeySection() {
    if (_selectedModel == null) return const SizedBox.shrink();

    final controller = _apiKeyControllers[_selectedModel!.id];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_selectedModel!.name} API Key',
            style: const TextStyle(
              fontSize: AppFontSize.md,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getApiKeyHint(_selectedModel!.id),
            style: TextStyle(
              fontSize: AppFontSize.sm,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            obscureText: true,
            decoration: InputDecoration(
              hintText: '请输入API Key',
              prefixIcon: const Icon(Icons.key),
              suffixIcon: controller!.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        controller.clear();
                        setState(() {});
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            onChanged: (value) {
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  String _getApiKeyHint(String modelId) {
    switch (modelId) {
      case 'gemini':
        return '从 Google AI Studio (https://aistudio.google.com/app/apikey) 获取免费API Key';
      case 'groq':
        return '从 Groq Console (https://console.groq.com/keys) 获取免费API Key';
      case 'cohere':
        return '从 Cohere Dashboard (https://dashboard.cohere.com/api-keys) 获取免费API Key';
      case 'zhipu':
        return '从 智谱AI开放平台 (https://open.bigmodel.cn/) 获取免费Token';
      case 'qwen':
        return '从 阿里云百炼 (https://bailian.console.aliyun.com/) 获取免费API Key';
      default:
        return '请输入API Key';
    }
  }

  Widget _buildLocalModelInfo() {
    return AppCard(
      color: AppColors.info.withOpacity(0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.info, size: 20),
              const SizedBox(width: 8),
              Text(
                'Ollama本地模型说明',
                style: TextStyle(
                  fontSize: AppFontSize.md,
                  fontWeight: FontWeight.w600,
                  color: AppColors.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoItem('1. 下载安装 Ollama', 'https://ollama.com'),
          const SizedBox(height: 8),
          _buildInfoItem('2. 下载模型', 'ollama pull llama3.2'),
          const SizedBox(height: 8),
          _buildInfoItem('3. 启动服务', 'ollama serve'),
          const SizedBox(height: 12),
          Text(
            '本地模型完全免费，支持离线使用，但需要您有足够的本地计算资源。',
            style: TextStyle(
              fontSize: AppFontSize.sm,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String title, String command) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: AppFontSize.sm),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.textPrimary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            command,
            style: const TextStyle(
              fontSize: AppFontSize.xs,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTestSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('连接测试'),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            children: [
              if (_connectionStatus != null) ...[
                Row(
                  children: [
                    Icon(
                      _connectionStatus! ? Icons.check_circle : Icons.error,
                      color: _connectionStatus!
                          ? AppColors.success
                          : AppColors.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _connectionStatus!
                            ? '连接成功！'
                            : '连接失败: ${_errorMessage ?? "未知错误"}',
                        style: TextStyle(
                          color: _connectionStatus!
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  text: '测试连接',
                  icon: Icons.wifi_tethering,
                  isLoading: _isTesting,
                  onPressed: _canTest() ? _testConnection : null,
                  style: _connectionStatus == true
                      ? AppButtonStyle.secondary
                      : AppButtonStyle.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _canTest() {
    if (_selectedModel == null) return false;
    if (_selectedModel!.type == AIModelType.local) return true;
    final controller = _apiKeyControllers[_selectedModel!.id];
    return controller != null && controller.text.isNotEmpty;
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _connectionStatus = null;
      _errorMessage = null;
    });

    try {
      // 如果是在线模型，先更新API Key
      if (_selectedModel!.type == AIModelType.online) {
        final controller = _apiKeyControllers[_selectedModel!.id];
        if (controller != null) {
          await _aiService.updateApiKey(_selectedModel!.id, controller.text);
          _selectedModel = _selectedModel!.copyWith(apiKey: controller.text);
        }
      }

      final success = await _aiService.testConnection(_selectedModel);

      setState(() {
        _connectionStatus = success;
        if (!success) {
          _errorMessage = '无法连接到服务器，请检查网络或配置';
        }
      });
    } catch (e) {
      setState(() {
        _connectionStatus = false;
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: AppButton(
          text: '保存配置',
          icon: Icons.save,
          onPressed: _selectedModel != null ? _saveConfig : null,
        ),
      ),
    );
  }

  Future<void> _saveConfig() async {
    if (_selectedModel == null) return;

    // 如果是在线模型，先更新API Key
    if (_selectedModel!.type == AIModelType.online) {
      final controller = _apiKeyControllers[_selectedModel!.id];
      if (controller != null && controller.text.isNotEmpty) {
        _selectedModel = _selectedModel!.copyWith(apiKey: controller.text);
      }
    }

    try {
      await _aiService.setConfig(_selectedModel!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('配置已保存'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showHelp() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => _buildHelpSheet(),
    );
  }

  Widget _buildHelpSheet() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AI设置帮助',
                style: TextStyle(
                  fontSize: AppFontSize.xl,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildHelpItem(
            Icons.cloud_outlined,
            '在线模型',
            '使用云端AI服务，需要配置API Key，部分服务提供免费额度',
          ),
          const SizedBox(height: 12),
          _buildHelpItem(
            Icons.computer_outlined,
            '本地模型 (Ollama)',
            '在本地运行AI模型，完全免费且支持离线，但需要较高的硬件配置',
          ),
          const SizedBox(height: 12),
          _buildHelpItem(
            Icons.security_outlined,
            '隐私安全',
            'API Key仅存储在本地设备，不会上传到任何服务器',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHelpItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: AppFontSize.md,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: AppFontSize.sm,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
