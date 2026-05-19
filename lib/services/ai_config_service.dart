import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// AI 模型类型枚举
// ============================================================

/// AI模型类型
enum AIModelType {
  local,   // 本地模型 (Ollama)
  online,  // 在线模型
}

// ============================================================
// AI 模型配置类
// ============================================================

/// AI模型配置
class AIModelConfig {
  final String id;
  final String name;
  final AIModelType type;
  final String baseUrl;
  final String? apiKey;
  final String defaultModel;
  final bool isFree;
  final String? description;
  final String? logoIcon;

  const AIModelConfig({
    required this.id,
    required this.name,
    required this.type,
    required this.baseUrl,
    this.apiKey,
    required this.defaultModel,
    required this.isFree,
    this.description,
    this.logoIcon,
  });

  /// 从JSON创建配置
  factory AIModelConfig.fromJson(Map<String, dynamic> json) {
    return AIModelConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      type: AIModelType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AIModelType.online,
      ),
      baseUrl: json['baseUrl'] as String,
      apiKey: json['apiKey'] as String?,
      defaultModel: json['defaultModel'] as String,
      isFree: json['isFree'] as bool? ?? false,
      description: json['description'] as String?,
      logoIcon: json['logoIcon'] as String?,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'baseUrl': baseUrl,
      'apiKey': apiKey,
      'defaultModel': defaultModel,
      'isFree': isFree,
      'description': description,
      'logoIcon': logoIcon,
    };
  }

  /// 复制配置并更新部分字段
  AIModelConfig copyWith({
    String? id,
    String? name,
    AIModelType? type,
    String? baseUrl,
    String? apiKey,
    String? defaultModel,
    bool? isFree,
    String? description,
    String? logoIcon,
  }) {
    return AIModelConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      defaultModel: defaultModel ?? this.defaultModel,
      isFree: isFree ?? this.isFree,
      description: description ?? this.description,
      logoIcon: logoIcon ?? this.logoIcon,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AIModelConfig && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// ============================================================
// AI 服务类
// ============================================================

/// AI服务 - 管理AI模型配置和调用
class AIService {
  // 单例
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  // 当前配置
  AIModelConfig? _currentConfig;
  String? _currentModel;

  // 存储键
  static const String _configKey = 'ai_model_config';
  static const String _modelKey = 'ai_current_model';

  // ============================================================
  // 预设免费在线模型
  // ============================================================

  /// 预设免费在线模型列表
  static final List<AIModelConfig> freeOnlineModels = [
    AIModelConfig(
      id: 'gemini',
      name: 'Google Gemini',
      type: AIModelType.online,
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
      apiKey: '',
      defaultModel: 'gemini-1.5-flash',
      isFree: true,
      description: 'Google免费模型，支持中文，响应快速',
      logoIcon: 'gem',
    ),
    AIModelConfig(
      id: 'groq',
      name: 'Groq (Llama)',
      type: AIModelType.online,
      baseUrl: 'https://api.groq.com/openai/v1',
      apiKey: '',
      defaultModel: 'llama-3.1-8b-instant',
      isFree: true,
      description: 'Groq免费API，支持Llama等模型，速度极快',
      logoIcon: 'groq',
    ),
    AIModelConfig(
      id: 'cohere',
      name: 'Cohere',
      type: AIModelType.online,
      baseUrl: 'https://api.cohere.ai/v1',
      apiKey: '',
      defaultModel: 'command-r-plus-08-2024',
      isFree: true,
      description: 'Cohere免费额度，支持多语言',
      logoIcon: 'cohere',
    ),
    AIModelConfig(
      id: 'zhipu',
      name: '智谱AI',
      type: AIModelType.online,
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      apiKey: '',
      defaultModel: 'glm-4-flash',
      isFree: true,
      description: '智谱AI免费Token，中文理解能力强',
      logoIcon: 'zhipu',
    ),
    AIModelConfig(
      id: 'qwen',
      name: '通义千问',
      type: AIModelType.online,
      baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      apiKey: '',
      defaultModel: 'qwen-turbo',
      isFree: true,
      description: '阿里云免费Token，中文优化',
      logoIcon: 'qwen',
    ),
  ];

  // ============================================================
  // 本地Ollama模型配置
  // ============================================================

  /// Ollama本地模型配置
  static AIModelConfig ollamaConfig = AIModelConfig(
    id: 'ollama',
    name: 'Ollama (本地)',
    type: AIModelType.local,
    baseUrl: 'http://localhost:11434',
    defaultModel: 'llama3.2',
    isFree: true,
    description: '本地开源模型，需安装Ollama，完全免费离线可用',
    logoIcon: 'ollama',
  );

  /// 获取所有可用模型（包括预设和自定义）
  List<AIModelConfig> get availableModels {
    final List<AIModelConfig> models = [...freeOnlineModels];
    if (!_isOllamaInList(models)) {
      models.add(ollamaConfig);
    }
    return models;
  }

  bool _isOllamaInList(List<AIModelConfig> models) {
    return models.any((m) => m.id == 'ollama');
  }

  // ============================================================
  // Getter 方法
  // ============================================================

  /// 获取当前配置
  AIModelConfig? get currentConfig => _currentConfig;

  /// 获取当前模型
  String? get currentModel => _currentModel ?? _currentConfig?.defaultModel;

  /// 检查是否已配置
  bool get isConfigured {
    if (_currentConfig == null) return false;
    if (_currentConfig!.type == AIModelType.local) return true;
    return _currentConfig!.apiKey != null && _currentConfig!.apiKey!.isNotEmpty;
  }

  /// 检查是否有可用的免费模型
  bool get hasFreeModelConfigured {
    for (final model in freeOnlineModels) {
      if (model.apiKey != null && model.apiKey!.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  // ============================================================
  // 配置管理方法
  // ============================================================

  /// 从SharedPreferences加载配置
  Future<void> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 加载模型配置
      final configJson = prefs.getString(_configKey);
      if (configJson != null) {
        final configMap = json.decode(configJson) as Map<String, dynamic>;

        // 合并预设模型的API Key（如果用户已保存）
        final modelId = configMap['id'] as String?;
        if (modelId != null) {
          final presetModel = freeOnlineModels.firstWhere(
            (m) => m.id == modelId,
            orElse: () => ollamaConfig,
          );

          // 使用保存的配置，但保留预设模型的默认URL等
          _currentConfig = AIModelConfig(
            id: presetModel.id,
            name: presetModel.name,
            type: presetModel.type,
            baseUrl: configMap['baseUrl'] as String? ?? presetModel.baseUrl,
            apiKey: configMap['apiKey'] as String?,
            defaultModel: configMap['defaultModel'] as String? ?? presetModel.defaultModel,
            isFree: presetModel.isFree,
            description: presetModel.description,
            logoIcon: presetModel.logoIcon,
          );
        }
      }

      // 加载当前模型
      _currentModel = prefs.getString(_modelKey);
    } catch (e) {
      // 配置加载失败，使用默认值
      _currentConfig = null;
      _currentModel = null;
    }
  }

  /// 保存配置到SharedPreferences
  Future<void> saveConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_currentConfig != null) {
        await prefs.setString(_configKey, json.encode(_currentConfig!.toJson()));
      }

      if (_currentModel != null) {
        await prefs.setString(_modelKey, _currentModel!);
      }
    } catch (e) {
      // 保存失败
      rethrow;
    }
  }

  /// 设置当前模型配置
  Future<void> setConfig(AIModelConfig config) async {
    _currentConfig = config;
    _currentModel = config.defaultModel;
    await saveConfig();
  }

  /// 更新API Key
  Future<void> updateApiKey(String modelId, String apiKey) async {
    // 查找预设模型
    final index = freeOnlineModels.indexWhere((m) => m.id == modelId);
    if (index != -1) {
      final updatedModel = freeOnlineModels[index].copyWith(apiKey: apiKey);
      freeOnlineModels[index] = updatedModel;

      // 如果当前配置是此模型，更新API Key
      if (_currentConfig?.id == modelId) {
        _currentConfig = _currentConfig!.copyWith(apiKey: apiKey);
        await saveConfig();
      }
    }
  }

  /// 清除配置
  Future<void> clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_configKey);
    await prefs.remove(_modelKey);
    _currentConfig = null;
    _currentModel = null;
  }

  // ============================================================
  // 连接测试
  // ============================================================

  /// 测试AI连接
  Future<bool> testConnection(AIModelConfig? config) async {
    final targetConfig = config ?? _currentConfig;
    if (targetConfig == null) return false;

    try {
      if (targetConfig.type == AIModelType.local) {
        return await _testOllamaConnection(targetConfig);
      } else {
        return await _testOnlineConnection(targetConfig);
      }
    } catch (e) {
      return false;
    }
  }

  /// 测试Ollama连接
  Future<bool> _testOllamaConnection(AIModelConfig config) async {
    try {
      final response = await http.get(
        Uri.parse('${config.baseUrl}/api/tags'),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// 测试在线模型连接
  Future<bool> _testOnlineConnection(AIModelConfig config) async {
    if (config.apiKey == null || config.apiKey!.isEmpty) {
      return false;
    }

    try {
      final headers = {
        'Authorization': 'Bearer ${config.apiKey}',
        'Content-Type': 'application/json',
      };

      final body = {
        'model': config.defaultModel,
        'messages': [
          {'role': 'user', 'content': 'Hello'}
        ],
        'max_tokens': 5,
      };

      final response = await http.post(
        Uri.parse('${config.baseUrl}/chat/completions'),
        headers: headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 30));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // 核心对话方法
  // ============================================================

  /// 发送对话请求
  Future<String> chat(String prompt, {String? model}) async {
    final targetModel = model ?? _currentModel ?? _currentConfig?.defaultModel;
    if (_currentConfig == null) {
      throw Exception('请先配置AI模型');
    }

    if (_currentConfig!.type == AIModelType.local) {
      return await _chatOllama(prompt, targetModel!);
    } else {
      return await _chatOnline(prompt, targetModel!);
    }
  }

  /// Ollama对话
  Future<String> _chatOllama(String prompt, String model) async {
    try {
      final response = await http.post(
        Uri.parse('${_currentConfig!.baseUrl}/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'model': model,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'stream': false,
        }),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['message']?['content'] as String? ?? '';
      } else {
        throw Exception('请求失败: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// 在线模型对话
  Future<String> _chatOnline(String prompt, String model) async {
    if (_currentConfig!.apiKey == null || _currentConfig!.apiKey!.isEmpty) {
      throw Exception('请先配置API Key');
    }

    try {
      // Google Gemini 使用不同的API格式
      if (_currentConfig!.id == 'gemini') {
        return await _chatGemini(prompt, model);
      }

      final headers = {
        'Authorization': 'Bearer ${_currentConfig!.apiKey}',
        'Content-Type': 'application/json',
      };

      final body = {
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'max_tokens': 2048,
      };

      final response = await http.post(
        Uri.parse('${_currentConfig!.baseUrl}/chat/completions'),
        headers: headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          return choices[0]['message']?['content'] as String? ?? '';
        }
        return '';
      } else {
        throw Exception('请求失败: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Google Gemini 对话
  Future<String> _chatGemini(String prompt, String model) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
      };

      final body = {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'maxOutputTokens': 2048,
          'temperature': 0.7,
        },
      };

      final response = await http.post(
        Uri.parse('${_currentConfig!.baseUrl}/models/$model:generateContent?key=${_currentConfig!.apiKey}'),
        headers: headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final candidates = data['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            return parts[0]['text'] as String? ?? '';
          }
        }
        return '';
      } else {
        throw Exception('请求失败: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ============================================================
  // AI 应用功能
  // ============================================================

  /// 生成题目
  /// [topic] 题目主题
  /// [count] 题目数量
  /// [type] 题目类型 (single_choice, multiple_choice, fill_blank, true_false)
  Future<List<Map<String, dynamic>>> generateQuestions(
    String topic, {
    int count = 5,
    String type = 'single_choice',
  }) async {
    final prompt = '''
请为"$topic"生成$count道$type类型的题目。

请以JSON数组格式返回，数组中每个元素包含：
- content: 题目内容
- options: 选项数组（如果是选择题）
- answer: 正确答案
- analysis: 解析内容
- type: 题目类型

示例格式：
[
  {
    "content": "以下关于...的说法正确的是？",
    "options": ["A. 选项1", "B. 选项2", "C. 选项3", "D. 选项4"],
    "answer": "A",
    "analysis": "解析：...",
    "type": "single_choice"
  }
]

只返回JSON数组，不要添加任何说明文字。''';

    try {
      final response = await chat(prompt);
      return _parseJsonArray(response);
    } catch (e) {
      rethrow;
    }
  }

  /// 检查答案
  /// [question] 原题目
  /// [userAnswer] 用户答案
  /// [correctAnswer] 正确答案
  Future<Map<String, dynamic>> checkAnswer({
    required String question,
    required String userAnswer,
    required String correctAnswer,
  }) async {
    final prompt = '''
请判断用户的答案是否正确。

题目：$question
正确答案：$correctAnswer
用户答案：$userAnswer

请以JSON格式返回判断结果：
{
  "isCorrect": true或false,
  "score": 0-100的分数,
  "feedback": "详细的反馈内容，指出错误原因或正确之处"
}

只返回JSON，不要添加任何说明文字。''';

    try {
      final response = await chat(prompt);
      final result = _parseJsonObject(response);
      return {
        'isCorrect': result['isCorrect'] as bool? ?? false,
        'score': result['score'] as int? ?? 0,
        'feedback': result['feedback'] as String? ?? '',
      };
    } catch (e) {
      return {
        'isCorrect': false,
        'score': 0,
        'feedback': '答案检查失败',
      };
    }
  }

  /// 生成思维导图
  /// [topic] 主题
  /// 返回Mermaid格式的思维导图
  Future<String> generateMindMap(String topic) async {
    final prompt = '''
请为"$topic"生成一个思维导图。

请以Mermaid思维导图格式返回，使用mindmap语法。

示例格式：
mindmap
  root((主题))
    分支1
      子节点1
      子节点2
    分支2
      子节点3
      子节点4

请生成一个完整且有逻辑层次的思维导图，包含主要概念和子概念。
只返回Mermaid代码，不要添加任何说明文字。''';

    try {
      return await chat(prompt);
    } catch (e) {
      rethrow;
    }
  }

  /// 生成JSON格式思维导图
  Future<List<Map<String, dynamic>>> generateMindMapJson(String topic) async {
    final prompt = '''
请为"$topic"生成一个思维导图。

请以JSON数组格式返回，每个节点包含：
- text: 节点文本
- children: 子节点数组（如果有）

示例格式：
[
  {
    "text": "主题",
    "children": [
      {"text": "分支1", "children": [{"text": "子节点1"}, {"text": "子节点2"}]},
      {"text": "分支2", "children": [{"text": "子节点3"}, {"text": "子节点4"}]}
    ]
  }
]

请生成一个完整且有逻辑层次的思维导图。
只返回JSON数组，不要添加任何说明文字。''';

    try {
      final response = await chat(prompt);
      return _parseJsonArray(response);
    } catch (e) {
      rethrow;
    }
  }

  /// 学情分析
  /// [data] 学习数据（可以是JSON字符串或文本描述）
  Future<Map<String, dynamic>> analyzeLearning(String data) async {
    final prompt = '''
请分析以下学习数据，并给出学情分析和建议。

学习数据：
$data

请以JSON格式返回分析结果：
{
  "summary": "学习概况总结",
  "strengths": ["优势1", "优势2", ...],
  "weaknesses": ["薄弱点1", "薄弱点2", ...],
  "suggestions": ["建议1", "建议2", ...],
  "studyPlan": "学习计划建议"
}

请给出具体、有针对性的分析和建议。
只返回JSON，不要添加任何说明文字。''';

    try {
      final response = await chat(prompt);
      final result = _parseJsonObject(response);
      return {
        'summary': result['summary'] as String? ?? '分析完成',
        'strengths': (result['strengths'] as List<dynamic>?)?.cast<String>() ?? [],
        'weaknesses': (result['weaknesses'] as List<dynamic>?)?.cast<String>() ?? [],
        'suggestions': (result['suggestions'] as List<dynamic>?)?.cast<String>() ?? [],
        'studyPlan': result['studyPlan'] as String? ?? '',
      };
    } catch (e) {
      return {
        'summary': '学情分析失败',
        'strengths': <String>[],
        'weaknesses': <String>[],
        'suggestions': <String>[],
        'studyPlan': '',
      };
    }
  }

  /// 内容拆分（批量录入）
  /// [content] 要拆分的长文本
  /// [type] 拆分类型 (questions, knowledge_points, notes)
  Future<List<String>> splitContent(String content, {String type = 'questions'}) async {
    String prompt;
    switch (type) {
      case 'knowledge_points':
        prompt = '''
请将以下内容拆分成独立的知识点条目。每个条目应该是一个完整的知识点。

内容：
$content

请以JSON数组格式返回，每个元素是一个知识点的标题或简短描述：
["知识点1", "知识点2", "知识点3", ...]

只返回JSON数组，不要添加任何说明文字。''';
        break;
      case 'notes':
        prompt = '''
请将以下内容拆分成独立的笔记条目。

内容：
$content

请以JSON数组格式返回，每个元素是一条独立的笔记：
["笔记1", "笔记2", "笔记3", ...]

只返回JSON数组，不要添加任何说明文字。''';
        break;
      case 'questions':
      default:
        prompt = '''
请将以下内容拆分成独立的题目。每道题目应该包含完整的题干和选项（如果有）。

内容：
$content

请以JSON数组格式返回，每个元素是一道题目（包含题干和选项）：
[
  {"content": "题目1题干", "options": ["A. ...", "B. ...", ...]},
  {"content": "题目2题干", "options": ["A. ...", "B. ...", ...]}
]

只返回JSON数组，不要添加任何说明文字。''';
    }

    try {
      final response = await chat(prompt);
      // 尝试解析为字符串数组
      try {
        final list = json.decode(response) as List<dynamic>;
        return list.map((e) => e.toString()).toList();
      } catch (_) {
        // 如果不是纯字符串数组，可能是对象数组
        final list = _parseJsonArray(response);
        return list.map((e) {
          if (e is Map<String, dynamic>) {
            return e['content']?.toString() ?? e.toString();
          }
          return e.toString();
        }).toList();
      }
    } catch (e) {
      rethrow;
    }
  }

  /// 生成学习建议
  Future<Map<String, dynamic>> generateLearningSuggestions({
    required String subject,
    required List<String> weakTopics,
    required int studyTimePerDay,
  }) async {
    final topicsStr = weakTopics.join('、');

    final prompt = '''
请为学习"$subject"科目的用户生成学习建议。

用户情况：
- 薄弱知识点：$topicsStr
- 每天学习时间：${studyTimePerDay}小时

请以JSON格式返回：
{
  "dailyPlan": "每日学习计划",
  "weeklyPlan": "每周复习计划",
  "tips": ["建议1", "建议2", ...],
  "resources": "推荐学习资源"
}

只返回JSON，不要添加任何说明文字。''';

    try {
      final response = await chat(prompt);
      final result = _parseJsonObject(response);
      return {
        'dailyPlan': result['dailyPlan'] as String? ?? '',
        'weeklyPlan': result['weeklyPlan'] as String? ?? '',
        'tips': (result['tips'] as List<dynamic>?)?.cast<String>() ?? [],
        'resources': result['resources'] as String? ?? '',
      };
    } catch (e) {
      return {
        'dailyPlan': '',
        'weeklyPlan': '',
        'tips': <String>[],
        'resources': '',
      };
    }
  }

  // ============================================================
  // 辅助方法
  // ============================================================

  /// 解析JSON数组
  List<Map<String, dynamic>> _parseJsonArray(String response) {
    try {
      // 尝试提取JSON数组
      final jsonStr = _extractJson(response);
      final list = json.decode(jsonStr) as List<dynamic>;
      return list.map((e) => (e as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  /// 解析JSON对象
  Map<String, dynamic> _parseJsonObject(String response) {
    try {
      final jsonStr = _extractJson(response);
      return json.decode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  /// 从响应中提取JSON字符串
  String _extractJson(String response) {
    // 尝试找到JSON数组/对象的开始和结束
    var start = response.indexOf('[');
    var end = response.lastIndexOf(']');

    if (start != -1 && end != -1 && end > start) {
      return response.substring(start, end + 1);
    }

    start = response.indexOf('{');
    end = response.lastIndexOf('}');

    if (start != -1 && end != -1 && end > start) {
      return response.substring(start, end + 1);
    }

    throw FormatException('无法解析JSON: $response');
  }
}

// ============================================================
// AI 消息类型
// ============================================================

/// AI对话消息
class AIMessage {
  final String role;
  final String content;
  final DateTime timestamp;

  AIMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
  };

  factory AIMessage.fromJson(Map<String, dynamic> json) => AIMessage(
    role: json['role'] as String,
    content: json['content'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}
