import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/mind_map_data.dart';
import '../models/knowledge_point.dart';
import '../models/wrong_question.dart';
import '../models/note.dart';
import '../models/must_remember.dart';
import 'database_service.dart';

/// ============================================================
/// MindMapService - 思维导图服务
/// ============================================================
/// 
/// 提供思维导图的自动生成、关联分析、导出等功能

class MindMapService {
  final DatabaseService _dbService = DatabaseService();

  /// 生成思维导图数据
  /// 
  /// [type] - 导图类型: 'all'(全部), 'subject'(按学科), 'tag'(按标签)
  /// [filterValue] - 过滤值（如学科名称或标签）
  Future<MindMapData> generateMindMap({
    String type = 'all',
    String? filterValue,
  }) async {
    // 加载所有数据
    final knowledgePoints = await _loadKnowledgePoints();
    final wrongQuestions = await _loadWrongQuestions();
    final notes = await _loadNotes();
    final mustRemember = await _loadMustRemember();

    // 根据类型过滤
    List<MindMapNode> allNodes = [];
    
    switch (type) {
      case 'subject':
        allNodes = await _generateBySubject(
          knowledgePoints,
          wrongQuestions,
          notes,
          mustRemember,
          filterValue,
        );
        break;
      case 'tag':
        allNodes = await _generateByTag(
          knowledgePoints,
          wrongQuestions,
          notes,
          mustRemember,
          filterValue,
        );
        break;
      case 'exam_method':
        allNodes = await _generateByExamMethod(
          knowledgePoints,
          wrongQuestions,
          notes,
          mustRemember,
          filterValue,
        );
        break;
      case 'key_point':
        allNodes = await _generateByKeyPoint(
          knowledgePoints,
          wrongQuestions,
          notes,
          mustRemember,
          filterValue,
        );
        break;
      default:
        allNodes = await _generateAll(
          knowledgePoints,
          wrongQuestions,
          notes,
          mustRemember,
        );
    }

    // 自动分析关联
    final connections = _analyzeConnections(allNodes);

    return MindMapData(
      nodes: allNodes,
      connections: connections,
      title: _getMindMapTitle(type, filterValue),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// 加载知识点数据
  Future<List<KnowledgePoint>> _loadKnowledgePoints() async {
    final rows = await _dbService.queryAllKnowledgePoints(limit: 1000);
    return rows.map((r) => _rowToKnowledgePoint(r)).toList();
  }

  /// 加载错题数据
  Future<List<WrongQuestion>> _loadWrongQuestions() async {
    final rows = await _dbService.queryAllWrongQuestions(limit: 1000);
    return rows.map((r) => _rowToWrongQuestion(r)).toList();
  }

  /// 加载笔记数据
  Future<List<Note>> _loadNotes() async {
    final rows = await _dbService.queryAllNotes(limit: 1000);
    return rows.map((r) => _rowToNote(r)).toList();
  }

  /// 加载必记必背数据
  Future<List<MustRemember>> _loadMustRemember() async {
    final rows = await _dbService.queryAllMustRemembers(limit: 1000);
    return rows.map((r) => _rowToMustRemember(r)).toList();
  }

  /// 安全解析 JSON 字符串为 List<String>
  List<String> _safeParseJsonList(dynamic value) {
    if (value == null) return [];
    
    try {
      if (value is String) {
        // 检查是否为空字符串
        if (value.trim().isEmpty) return [];
        
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
        }
        return [];
      } else if (value is List) {
        return value.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
      }
    } catch (e) {
      debugPrint('JSON 解析失败: $e, 原始值: $value');
    }
    return [];
  }

  /// 将数据库行转换为 KnowledgePoint
  KnowledgePoint _rowToKnowledgePoint(Map<String, dynamic> r) {
    List<String> tags = _safeParseJsonList(r['tags']);

    List<String> examMethods = _safeParseJsonList(r['exam_methods']);

    List<String> keyPoints = _safeParseJsonList(r['key_points']);

    int createdAt = DateTime.now().millisecondsSinceEpoch;
    if (r['created_at'] != null) {
      if (r['created_at'] is int) {
        createdAt = r['created_at'] as int;
      } else {
        createdAt = DateTime.tryParse(r['created_at'].toString())
                ?.millisecondsSinceEpoch ??
            createdAt;
      }
    }

    int updatedAt = DateTime.now().millisecondsSinceEpoch;
    if (r['updated_at'] != null) {
      if (r['updated_at'] is int) {
        updatedAt = r['updated_at'] as int;
      } else {
        updatedAt = DateTime.tryParse(r['updated_at'].toString())
                ?.millisecondsSinceEpoch ??
            updatedAt;
      }
    }

    return KnowledgePoint(
      id: r['uuid']?.toString() ?? r['id'].toString(),
      title: r['title']?.toString() ?? '',
      content: r['content']?.toString() ?? '',
      subject: r['subject']?.toString() ?? '其他',
      tags: tags,
      categoryId: r['category']?.toString(),
      difficulty: r['difficulty'] is int ? r['difficulty'] as int : int.tryParse(r['difficulty']?.toString() ?? '') ?? 1,
      masteryLevel: r['mastery_level'] is int ? r['mastery_level'] as int : int.tryParse(r['mastery_level']?.toString() ?? '') ?? 0,
      reviewCount: r['review_count'] is int ? r['review_count'] as int : int.tryParse(r['review_count']?.toString() ?? '') ?? 0,
      isFavorite: (r['is_favorite'] is int ? r['is_favorite'] as int : 0) == 1,
      createdAt: createdAt,
      updatedAt: updatedAt,
      examMethods: examMethods,
      keyPoints: keyPoints,
    );
  }

  /// 将数据库行转换为 WrongQuestion
  WrongQuestion _rowToWrongQuestion(Map<String, dynamic> r) {
    // 安全解析 options 字段
    List<Map<String, dynamic>> options = [];
    if (r['options'] != null) {
      try {
        if (r['options'] is String) {
          if ((r['options'] as String).trim().isNotEmpty) {
            final decoded = jsonDecode(r['options'] as String);
            if (decoded is List) {
              options = decoded.map((e) {
                if (e is Map) {
                  return Map<String, dynamic>.from(e);
                }
                return <String, dynamic>{};
              }).toList();
            }
          }
        } else if (r['options'] is List) {
          options = (r['options'] as List).map((e) {
            if (e is Map) {
              return Map<String, dynamic>.from(e);
            }
            return <String, dynamic>{};
          }).toList();
        }
      } catch (e) {
        debugPrint('解析 options 失败: $e');
      }
    }

    List<String> examMethods = _safeParseJsonList(r['exam_methods']);

    List<String> keyPoints = _safeParseJsonList(r['key_points']);

    List<String> tags = _safeParseJsonList(r['tags']);

    int createdAt = DateTime.now().millisecondsSinceEpoch;
    if (r['created_at'] != null) {
      if (r['created_at'] is int) {
        createdAt = r['created_at'] as int;
      } else {
        createdAt = DateTime.tryParse(r['created_at'].toString())
                ?.millisecondsSinceEpoch ??
            createdAt;
      }
    }

    int updatedAt = DateTime.now().millisecondsSinceEpoch;
    if (r['updated_at'] != null) {
      if (r['updated_at'] is int) {
        updatedAt = r['updated_at'] as int;
      } else {
        updatedAt = DateTime.tryParse(r['updated_at'].toString())
                ?.millisecondsSinceEpoch ??
            updatedAt;
      }
    }

    return WrongQuestion(
      id: r['uuid']?.toString() ?? r['id'].toString(),
      title: r['question_content']?.toString() ?? r['title']?.toString() ?? '',
      content: r['question_content']?.toString() ?? '',
      options: options,
      correctAnswer: r['correct_answer']?.toString() ?? '',
      userAnswer: r['my_answer']?.toString(),
      analysis: r['analysis']?.toString() ?? '',
      subject: r['subject']?.toString() ?? '其他',
      errorType: r['error_type']?.toString() ?? '知识盲区',
      errorCount: r['error_count'] is int ? r['error_count'] as int : int.tryParse(r['error_count']?.toString() ?? '') ?? 1,
      isResolved: (r['is_mastered'] is int ? r['is_mastered'] as int : 0) == 1,
      createdAt: createdAt,
      updatedAt: updatedAt,
      examMethods: examMethods,
      keyPoints: keyPoints,
      tags: tags,
    );
  }

  /// 将数据库行转换为 Note
  Note _rowToNote(Map<String, dynamic> r) {
    List<String> tags = _safeParseJsonList(r['tags']);

    List<String> examMethods = _safeParseJsonList(r['exam_methods']);

    List<String> keyPoints = _safeParseJsonList(r['key_points']);

    int createdAt = DateTime.now().millisecondsSinceEpoch;
    if (r['created_at'] != null) {
      if (r['created_at'] is int) {
        createdAt = r['created_at'] as int;
      } else {
        createdAt = DateTime.tryParse(r['created_at'].toString())
                ?.millisecondsSinceEpoch ??
            createdAt;
      }
    }

    int updatedAt = DateTime.now().millisecondsSinceEpoch;
    if (r['updated_at'] != null) {
      if (r['updated_at'] is int) {
        updatedAt = r['updated_at'] as int;
      } else {
        updatedAt = DateTime.tryParse(r['updated_at'].toString())
                ?.millisecondsSinceEpoch ??
            updatedAt;
      }
    }

    return Note(
      id: r['uuid']?.toString() ?? r['id'].toString(),
      title: r['title']?.toString() ?? '',
      content: r['content']?.toString() ?? '',
      subject: r['subject']?.toString() ?? '其他',
      tags: tags,
      color: r['color']?.toString() ?? '#FFFFFF',
      isFavorite: (r['is_favorite'] is int ? r['is_favorite'] as int : 0) == 1,
      createdAt: createdAt,
      updatedAt: updatedAt,
      examMethods: examMethods,
      keyPoints: keyPoints,
    );
  }

  /// 将数据库行转换为 MustRemember
  MustRemember _rowToMustRemember(Map<String, dynamic> r) {
    List<String> examMethods = _safeParseJsonList(r['exam_methods']);

    List<String> keyPoints = _safeParseJsonList(r['key_points']);

    int createdAt = DateTime.now().millisecondsSinceEpoch;
    if (r['created_at'] != null) {
      if (r['created_at'] is int) {
        createdAt = r['created_at'] as int;
      } else {
        createdAt = DateTime.tryParse(r['created_at'].toString())
                ?.millisecondsSinceEpoch ??
            createdAt;
      }
    }

    int updatedAt = DateTime.now().millisecondsSinceEpoch;
    if (r['updated_at'] != null) {
      if (r['updated_at'] is int) {
        updatedAt = r['updated_at'] as int;
      } else {
        updatedAt = DateTime.tryParse(r['updated_at'].toString())
                ?.millisecondsSinceEpoch ??
            updatedAt;
      }
    }

    int? nextReviewTime;
    if (r['next_review_time'] != null) {
      if (r['next_review_time'] is int) {
        nextReviewTime = r['next_review_time'] as int;
      } else if (r['next_review_time'] is String) {
        nextReviewTime = DateTime.tryParse(r['next_review_time'] as String)
                ?.millisecondsSinceEpoch;
      }
    }

    return MustRemember(
      id: r['uuid']?.toString() ?? r['id'].toString(),
      title: r['title']?.toString() ?? '',
      content: r['content']?.toString() ?? '',
      subject: r['subject']?.toString() ?? '其他',
      category: r['category']?.toString() ?? '其他',
      memoryLevel: r['memory_level'] is int ? r['memory_level'] as int : int.tryParse(r['memory_level']?.toString() ?? '') ?? 0,
      nextReviewTime: nextReviewTime,
      reviewInterval: r['review_interval'] is int ? r['review_interval'] as int : int.tryParse(r['review_interval']?.toString() ?? '') ?? 0,
      reviewCount: r['review_count'] is int ? r['review_count'] as int : int.tryParse(r['review_count']?.toString() ?? '') ?? 0,
      isMastered: (r['is_mastered'] is int ? r['is_mastered'] as int : 0) == 1,
      createdAt: createdAt,
      updatedAt: updatedAt,
      examMethods: examMethods,
      keyPoints: keyPoints,
    );
  }

  /// 生成全部内容的思维导图
  Future<List<MindMapNode>> _generateAll(
    List<KnowledgePoint> knowledgePoints,
    List<WrongQuestion> wrongQuestions,
    List<Note> notes,
    List<MustRemember> mustRemember,
  ) async {
    final List<MindMapNode> nodes = [];
    final centerX = 0.0;
    final centerY = 0.0;

    // 创建根节点
    nodes.add(MindMapNode(
      id: 'root',
      label: '学习知识图谱',
      type: NodeType.root,
      x: centerX,
      y: centerY,
    ));

    // 按学科分组
    final subjects = _groupBySubject(
      knowledgePoints,
      wrongQuestions,
      notes,
      mustRemember,
    );

    // 为每个学科创建分支
    final subjectNames = subjects.keys.toList();
    final angleStep = 2 * pi / subjectNames.length;
    
    for (int i = 0; i < subjectNames.length; i++) {
      final subject = subjectNames[i];
      final angle = i * angleStep - pi / 2;
      final distance = 200.0;
      
      final subjectNode = MindMapNode(
        id: 'subject_$subject',
        label: subject,
        type: NodeType.subject,
        x: centerX + cos(angle) * distance,
        y: centerY + sin(angle) * distance,
        parentId: 'root',
        data: {'subject': subject},
      );
      nodes.add(subjectNode);

      // 添加学科下的内容
      final content = subjects[subject]!;
      nodes.addAll(_createContentNodes(
        content,
        subjectNode.id,
        subjectNode.x,
        subjectNode.y,
        angle,
      ));
    }

    return nodes;
  }

  /// 按学科生成思维导图
  Future<List<MindMapNode>> _generateBySubject(
    List<KnowledgePoint> knowledgePoints,
    List<WrongQuestion> wrongQuestions,
    List<Note> notes,
    List<MustRemember> mustRemember,
    String? subject,
  ) async {
    final List<MindMapNode> nodes = [];
    final centerX = 0.0;
    final centerY = 0.0;

    if (subject == null) {
      return _generateAll(knowledgePoints, wrongQuestions, notes, mustRemember);
    }

    // 创建根节点
    nodes.add(MindMapNode(
      id: 'root',
      label: subject,
      type: NodeType.root,
      x: centerX,
      y: centerY,
    ));

    // 过滤该学科的内容
    final filtered = _filterBySubject(
      knowledgePoints,
      wrongQuestions,
      notes,
      mustRemember,
      subject,
    );

    // 按类型分组
    final types = ['知识点', '错题', '笔记', '必记必背'];
    final typeData = {
      '知识点': filtered['knowledgePoints']!,
      '错题': filtered['wrongQuestions']!,
      '笔记': filtered['notes']!,
      '必记必背': filtered['mustRemember']!,
    };

    final angleStep = 2 * pi / types.length;
    
    for (int i = 0; i < types.length; i++) {
      final type = types[i];
      final items = typeData[type]!;
      
      if (items.isEmpty) continue;

      final angle = i * angleStep - pi / 2;
      final distance = 200.0;
      
      final typeNode = MindMapNode(
        id: 'type_$type',
        label: '$type (${items.length})',
        type: NodeType.category,
        x: centerX + cos(angle) * distance,
        y: centerY + sin(angle) * distance,
        parentId: 'root',
        data: {'type': type},
      );
      nodes.add(typeNode);

      // 添加具体内容节点
      nodes.addAll(_createContentNodes(
        {type: items},
        typeNode.id,
        typeNode.x,
        typeNode.y,
        angle,
      ));
    }

    return nodes;
  }

  /// 按标签生成思维导图
  Future<List<MindMapNode>> _generateByTag(
    List<KnowledgePoint> knowledgePoints,
    List<WrongQuestion> wrongQuestions,
    List<Note> notes,
    List<MustRemember> mustRemember,
    String? tag,
  ) async {
    final List<MindMapNode> nodes = [];
    final centerX = 0.0;
    final centerY = 0.0;

    if (tag == null) {
      // 显示所有标签
      final allTags = _extractAllTags(
        knowledgePoints,
        wrongQuestions,
        notes,
        mustRemember,
      );

      nodes.add(MindMapNode(
        id: 'root',
        label: '标签分类',
        type: NodeType.root,
        x: centerX,
        y: centerY,
      ));

      final angleStep = 2 * pi / allTags.length;
      for (int i = 0; i < allTags.length; i++) {
        final t = allTags[i];
        final angle = i * angleStep - pi / 2;
        final distance = 200.0;
        
        nodes.add(MindMapNode(
          id: 'tag_$t',
          label: t,
          type: NodeType.tag,
          x: centerX + cos(angle) * distance,
          y: centerY + sin(angle) * distance,
          parentId: 'root',
          data: {'tag': t},
        ));
      }
      return nodes;
    }

    // 显示特定标签的内容
    nodes.add(MindMapNode(
      id: 'root',
      label: '标签: $tag',
      type: NodeType.root,
      x: centerX,
      y: centerY,
    ));

    final filtered = _filterByTag(
      knowledgePoints,
      wrongQuestions,
      notes,
      mustRemember,
      tag,
    );

    // 按类型分组显示
    final types = ['知识点', '错题', '笔记', '必记必背'];
    final typeData = {
      '知识点': filtered['knowledgePoints']!,
      '错题': filtered['wrongQuestions']!,
      '笔记': filtered['notes']!,
      '必记必背': filtered['mustRemember']!,
    };

    final angleStep = 2 * pi / types.length;
    
    for (int i = 0; i < types.length; i++) {
      final type = types[i];
      final items = typeData[type]!;
      
      if (items.isEmpty) continue;

      final angle = i * angleStep - pi / 2;
      final distance = 200.0;
      
      final typeNode = MindMapNode(
        id: 'type_$type',
        label: '$type (${items.length})',
        type: NodeType.category,
        x: centerX + cos(angle) * distance,
        y: centerY + sin(angle) * distance,
        parentId: 'root',
        data: {'type': type},
      );
      nodes.add(typeNode);

      nodes.addAll(_createContentNodes(
        {type: items},
        typeNode.id,
        typeNode.x,
        typeNode.y,
        angle,
      ));
    }

    return nodes;
  }

  /// 按考法生成思维导图
  Future<List<MindMapNode>> _generateByExamMethod(
    List<KnowledgePoint> knowledgePoints,
    List<WrongQuestion> wrongQuestions,
    List<Note> notes,
    List<MustRemember> mustRemember,
    String? examMethod,
  ) async {
    final List<MindMapNode> nodes = [];
    final centerX = 0.0;
    final centerY = 0.0;

    // 提取所有考法
    final allExamMethods = _extractAllExamMethods(
      knowledgePoints,
      wrongQuestions,
      notes,
      mustRemember,
    );

    if (examMethod == null) {
      // 显示所有考法
      nodes.add(MindMapNode(
        id: 'root',
        label: '考法分类',
        type: NodeType.root,
        x: centerX,
        y: centerY,
      ));

      final angleStep = allExamMethods.isEmpty ? 0 : 2 * pi / allExamMethods.length;
      for (int i = 0; i < allExamMethods.length; i++) {
        final em = allExamMethods[i];
        final angle = i * angleStep - pi / 2;
        final distance = 200.0;
        
        nodes.add(MindMapNode(
          id: 'exam_method_$em',
          label: em,
          type: NodeType.examMethod,
          x: centerX + cos(angle) * distance,
          y: centerY + sin(angle) * distance,
          parentId: 'root',
          data: {'examMethod': em},
        ));
      }
      return nodes;
    }

    // 显示特定考法的内容
    nodes.add(MindMapNode(
      id: 'root',
      label: '考法: $examMethod',
      type: NodeType.root,
      x: centerX,
      y: centerY,
    ));

    final filtered = _filterByExamMethod(
      knowledgePoints,
      wrongQuestions,
      notes,
      mustRemember,
      examMethod,
    );

    // 按学科分组
    final subjects = filtered.keys.toList();
    final angleStep = subjects.isEmpty ? 0 : 2 * pi / subjects.length;
    
    for (int i = 0; i < subjects.length; i++) {
      final subject = subjects[i];
      final items = filtered[subject]!;
      
      if (items.isEmpty) continue;

      final angle = i * angleStep - pi / 2;
      final distance = 200.0;
      
      final subjectNode = MindMapNode(
        id: 'subject_$subject',
        label: '$subject (${items.length})',
        type: NodeType.subject,
        x: centerX + cos(angle) * distance,
        y: centerY + sin(angle) * distance,
        parentId: 'root',
        data: {'subject': subject},
      );
      nodes.add(subjectNode);

      nodes.addAll(_createContentNodes(
        {subject: items},
        subjectNode.id,
        subjectNode.x,
        subjectNode.y,
        angle,
      ));
    }

    return nodes;
  }

  /// 按考点生成思维导图
  Future<List<MindMapNode>> _generateByKeyPoint(
    List<KnowledgePoint> knowledgePoints,
    List<WrongQuestion> wrongQuestions,
    List<Note> notes,
    List<MustRemember> mustRemember,
    String? keyPoint,
  ) async {
    // 与考法逻辑类似
    final allKeyPoints = _extractAllKeyPoints(
      knowledgePoints,
      wrongQuestions,
      notes,
      mustRemember,
    );

    final List<MindMapNode> nodes = [];
    final centerX = 0.0;
    final centerY = 0.0;

    if (keyPoint == null) {
      nodes.add(MindMapNode(
        id: 'root',
        label: '考点分类',
        type: NodeType.root,
        x: centerX,
        y: centerY,
      ));

      final angleStep = allKeyPoints.isEmpty ? 0 : 2 * pi / allKeyPoints.length;
      for (int i = 0; i < allKeyPoints.length; i++) {
        final kp = allKeyPoints[i];
        final angle = i * angleStep - pi / 2;
        final distance = 200.0;
        
        nodes.add(MindMapNode(
          id: 'key_point_$kp',
          label: kp,
          type: NodeType.keyPoint,
          x: centerX + cos(angle) * distance,
          y: centerY + sin(angle) * distance,
          parentId: 'root',
          data: {'keyPoint': kp},
        ));
      }
      return nodes;
    }

    nodes.add(MindMapNode(
      id: 'root',
      label: '考点: $keyPoint',
      type: NodeType.root,
      x: centerX,
      y: centerY,
    ));

    final filtered = _filterByKeyPoint(
      knowledgePoints,
      wrongQuestions,
      notes,
      mustRemember,
      keyPoint,
    );

    final subjects = filtered.keys.toList();
    final angleStep = subjects.isEmpty ? 0 : 2 * pi / subjects.length;
    
    for (int i = 0; i < subjects.length; i++) {
      final subject = subjects[i];
      final items = filtered[subject]!;
      
      if (items.isEmpty) continue;

      final angle = i * angleStep - pi / 2;
      final distance = 200.0;
      
      final subjectNode = MindMapNode(
        id: 'subject_$subject',
        label: '$subject (${items.length})',
        type: NodeType.subject,
        x: centerX + cos(angle) * distance,
        y: centerY + sin(angle) * distance,
        parentId: 'root',
        data: {'subject': subject},
      );
      nodes.add(subjectNode);

      nodes.addAll(_createContentNodes(
        {subject: items},
        subjectNode.id,
        subjectNode.x,
        subjectNode.y,
        angle,
      ));
    }

    return nodes;
  }

  /// 创建内容节点
  List<MindMapNode> _createContentNodes(
    Map<String, List<dynamic>> content,
    String parentId,
    double parentX,
    double parentY,
    double baseAngle,
  ) {
    final List<MindMapNode> nodes = [];
    final allItems = content.values.expand((x) => x).toList();
    
    if (allItems.isEmpty) return nodes;

    final itemAngleStep = pi / 3 / max(allItems.length, 1);
    final startAngle = baseAngle - pi / 6;
    final distance = 150.0;

    for (int i = 0; i < allItems.length; i++) {
      final item = allItems[i];
      final angle = startAngle + i * itemAngleStep;
      
      String id, label, itemType;
      NodeType nodeType;
      Map<String, dynamic> data = {};

      if (item is KnowledgePoint) {
        id = 'kp_${item.id}';
        label = item.title;
        itemType = 'knowledgePoint';
        nodeType = NodeType.knowledgePoint;
        data = {'knowledgePoint': item.toJson()};
      } else if (item is WrongQuestion) {
        id = 'wq_${item.id}';
        label = item.title.isNotEmpty ? item.title : '错题';
        itemType = 'wrongQuestion';
        nodeType = NodeType.wrongQuestion;
        data = {'wrongQuestion': item.toJson()};
      } else if (item is Note) {
        id = 'note_${item.id}';
        label = item.title;
        itemType = 'note';
        nodeType = NodeType.note;
        data = {'note': item.toJson()};
      } else if (item is MustRemember) {
        id = 'mr_${item.id}';
        label = item.title;
        itemType = 'mustRemember';
        nodeType = NodeType.mustRemember;
        data = {'mustRemember': item.toJson()};
      } else {
        continue;
      }

      nodes.add(MindMapNode(
        id: id,
        label: label.length > 15 ? '${label.substring(0, 15)}...' : label,
        type: nodeType,
        x: parentX + cos(angle) * distance,
        y: parentY + sin(angle) * distance,
        parentId: parentId,
        data: data,
      ));
    }

    return nodes;
  }

  /// 分析节点关联
  List<MindMapConnection> _analyzeConnections(List<MindMapNode> nodes) {
    final List<MindMapConnection> connections = [];
    final Set<String> connectionIds = {};

    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final node1 = nodes[i];
        final node2 = nodes[j];

        // 跳过根节点之间的连接
        if (node1.type == NodeType.root || node2.type == NodeType.root) {
          continue;
        }

        // 检查关联
        final relation = _checkRelation(node1, node2);
        if (relation != null) {
          final connId = '${node1.id}_${node2.id}';
          final reverseConnId = '${node2.id}_${node1.id}';
          
          if (!connectionIds.contains(connId) && 
              !connectionIds.contains(reverseConnId)) {
            connections.add(MindMapConnection(
              sourceId: node1.id,
              targetId: node2.id,
              relation: relation,
              strength: _calculateRelationStrength(node1, node2),
            ));
            connectionIds.add(connId);
          }
        }
      }
    }

    return connections;
  }

  /// 检查两个节点之间的关联
  String? _checkRelation(MindMapNode node1, MindMapNode node2) {
    // 同主题关联
    final subject1 = node1.data?['subject'] ?? 
        _extractSubjectFromNodeData(node1);
    final subject2 = node2.data?['subject'] ?? 
        _extractSubjectFromNodeData(node2);
    
    if (subject1 != null && subject2 != null && subject1 == subject2) {
      return '同主题';
    }

    // 同标签关联
    final tags1 = _extractTagsFromNodeData(node1);
    final tags2 = _extractTagsFromNodeData(node2);
    final commonTags = tags1.where((t) => tags2.contains(t)).toList();
    if (commonTags.isNotEmpty) {
      return '同标签: ${commonTags.first}';
    }

    // 同考法关联
    final examMethods1 = _extractExamMethodsFromNodeData(node1);
    final examMethods2 = _extractExamMethodsFromNodeData(node2);
    final commonExamMethods = examMethods1.where((em) => examMethods2.contains(em)).toList();
    if (commonExamMethods.isNotEmpty) {
      return '同考法: ${commonExamMethods.first}';
    }

    // 同考点关联
    final keyPoints1 = _extractKeyPointsFromNodeData(node1);
    final keyPoints2 = _extractKeyPointsFromNodeData(node2);
    final commonKeyPoints = keyPoints1.where((kp) => keyPoints2.contains(kp)).toList();
    if (commonKeyPoints.isNotEmpty) {
      return '同考点: ${commonKeyPoints.first}';
    }

    return null;
  }

  /// 计算关联强度
  double _calculateRelationStrength(MindMapNode node1, MindMapNode node2) {
    double strength = 0.0;

    // 同主题 +0.3
    final subject1 = _extractSubjectFromNodeData(node1);
    final subject2 = _extractSubjectFromNodeData(node2);
    if (subject1 != null && subject2 != null && subject1 == subject2) {
      strength += 0.3;
    }

    // 同标签 +0.2 * 共同标签数
    final tags1 = _extractTagsFromNodeData(node1);
    final tags2 = _extractTagsFromNodeData(node2);
    final commonTags = tags1.where((t) => tags2.contains(t)).length;
    strength += 0.2 * commonTags;

    // 同考法 +0.25 * 共同考法数
    final examMethods1 = _extractExamMethodsFromNodeData(node1);
    final examMethods2 = _extractExamMethodsFromNodeData(node2);
    final commonExamMethods = examMethods1.where((em) => examMethods2.contains(em)).length;
    strength += 0.25 * commonExamMethods;

    // 同考点 +0.25 * 共同考点数
    final keyPoints1 = _extractKeyPointsFromNodeData(node1);
    final keyPoints2 = _extractKeyPointsFromNodeData(node2);
    final commonKeyPoints = keyPoints1.where((kp) => keyPoints2.contains(kp)).length;
    strength += 0.25 * commonKeyPoints;

    return strength.clamp(0.0, 1.0);
  }

  /// 从节点数据中提取学科
  String? _extractSubjectFromNodeData(MindMapNode node) {
    final data = node.data;
    if (data == null) return null;
    
    if (data.containsKey('knowledgePoint')) {
      return data['knowledgePoint']['subject'] as String?;
    } else if (data.containsKey('wrongQuestion')) {
      return data['wrongQuestion']['subject'] as String?;
    } else if (data.containsKey('note')) {
      return data['note']['subject'] as String?;
    } else if (data.containsKey('mustRemember')) {
      return data['mustRemember']['subject'] as String?;
    }
    return null;
  }

  /// 从节点数据中提取标签
  List<String> _extractTagsFromNodeData(MindMapNode node) {
    final data = node.data;
    if (data == null) return [];
    
    List<dynamic>? tags;
    if (data.containsKey('knowledgePoint')) {
      tags = data['knowledgePoint']['tags'] as List<dynamic>?;
    } else if (data.containsKey('wrongQuestion')) {
      // 错题没有标签字段
      return [];
    } else if (data.containsKey('note')) {
      tags = data['note']['tags'] as List<dynamic>?;
    } else if (data.containsKey('mustRemember')) {
      // 必记必背没有标签字段
      return [];
    }
    return tags?.map((t) => t.toString()).toList() ?? [];
  }

  /// 从节点数据中提取考法
  List<String> _extractExamMethodsFromNodeData(MindMapNode node) {
    final data = node.data;
    if (data == null) return [];
    
    List<dynamic>? examMethods;
    if (data.containsKey('knowledgePoint')) {
      examMethods = data['knowledgePoint']['examMethods'] as List<dynamic>?;
    } else if (data.containsKey('wrongQuestion')) {
      examMethods = data['wrongQuestion']['examMethods'] as List<dynamic>?;
    } else if (data.containsKey('note')) {
      examMethods = data['note']['examMethods'] as List<dynamic>?;
    } else if (data.containsKey('mustRemember')) {
      examMethods = data['mustRemember']['examMethods'] as List<dynamic>?;
    }
    return examMethods?.map((e) => e.toString()).toList() ?? [];
  }

  /// 从节点数据中提取考点
  List<String> _extractKeyPointsFromNodeData(MindMapNode node) {
    final data = node.data;
    if (data == null) return [];
    
    List<dynamic>? keyPoints;
    if (data.containsKey('knowledgePoint')) {
      keyPoints = data['knowledgePoint']['keyPoints'] as List<dynamic>?;
    } else if (data.containsKey('wrongQuestion')) {
      keyPoints = data['wrongQuestion']['keyPoints'] as List<dynamic>?;
    } else if (data.containsKey('note')) {
      keyPoints = data['note']['keyPoints'] as List<dynamic>?;
    } else if (data.containsKey('mustRemember')) {
      keyPoints = data['mustRemember']['keyPoints'] as List<dynamic>?;
    }
    return keyPoints?.map((k) => k.toString()).toList() ?? [];
  }

  /// 按学科分组
  Map<String, Map<String, List<dynamic>>> _groupBySubject(
    List<KnowledgePoint> knowledgePoints,
    List<WrongQuestion> wrongQuestions,
    List<Note> notes,
    List<MustRemember> mustRemember,
  ) {
    final Map<String, Map<String, List<dynamic>>> result = {};

    for (final kp in knowledgePoints) {
      result.putIfAbsent(kp.subject, () => {});
      result[kp.subject]!.putIfAbsent('knowledgePoints', () => []);
      result[kp.subject]!['knowledgePoints']!.add(kp);
    }

    for (final wq in wrongQuestions) {
      result.putIfAbsent(wq.subject, () => {});
      result[wq.subject]!.putIfAbsent('wrongQuestions', () => []);
      result[wq.subject]!['wrongQuestions']!.add(wq);
    }

    for (final note in notes) {
      result.putIfAbsent(note.subject, () => {});
      result[note.subject]!.putIfAbsent('notes', () => []);
      result[note.subject]!['notes']!.add(note);
    }

    for (final mr in mustRemember) {
      result.putIfAbsent(mr.subject, () => {});
      result[mr.subject]!.putIfAbsent('mustRemember', () => []);
      result[mr.subject]!['mustRemember']!.add(mr);
    }

    return result;
  }

  /// 按学科过滤
  Map<String, List<dynamic>> _filterBySubject(
    List<KnowledgePoint> knowledgePoints,
    List<WrongQuestion> wrongQuestions,
    List<Note> notes,
    List<MustRemember> mustRemember,
    String subject,
  ) {
    return {
      'knowledgePoints': knowledgePoints.where((kp) => kp.subject == subject).toList(),
      'wrongQuestions': wrongQuestions.where((wq) => wq.subject == subject).toList(),
      'notes': notes.where((n) => n.subject == subject).toList(),
      'mustRemember': mustRemember.where((mr) => mr.subject == subject).toList(),
    };
  }

  /// 按标签过滤
  Map<String, List<dynamic>> _filterByTag(
    List<KnowledgePoint> knowledgePoints,
    List<WrongQuestion> wrongQuestions,
    List<Note> notes,
    List<MustRemember> mustRemember,
    String tag,
  ) {
    return {
      'knowledgePoints': knowledgePoints.where((kp) => kp.tags.contains(tag)).toList(),
      'wrongQuestions': [], // 错题没有标签
      'notes': notes.where((n) => n.tags.contains(tag)).toList(),
      'mustRemember': [], // 必记必背没有标签
    };
  }

  /// 按考法过滤
  Map<String, List<dynamic>> _filterByExamMethod(
    List<KnowledgePoint> knowledgePoints,
    List<WrongQuestion> wrongQuestions,
    List<Note> notes,
    List<MustRemember> mustRemember,
    String examMethod,
  ) {
    final Map<String, List<dynamic>> result = {};

    for (final kp in knowledgePoints.where((kp) => kp.examMethods.contains(examMethod))) {
      result.putIfAbsent(kp.subject, () => []);
      result[kp.subject]!.add(kp);
    }

    for (final wq in wrongQuestions.where((wq) => wq.examMethods.contains(examMethod))) {
      result.putIfAbsent(wq.subject, () => []);
      result[wq.subject]!.add(wq);
    }

    for (final note in notes.where((n) => n.examMethods.contains(examMethod))) {
      result.putIfAbsent(note.subject, () => []);
      result[note.subject]!.add(note);
    }

    for (final mr in mustRemember.where((mr) => mr.examMethods.contains(examMethod))) {
      result.putIfAbsent(mr.subject, () => []);
      result[mr.subject]!.add(mr);
    }

    return result;
  }

  /// 按考点过滤
  Map<String, List<dynamic>> _filterByKeyPoint(
    List<KnowledgePoint> knowledgePoints,
    List<WrongQuestion> wrongQuestions,
    List<Note> notes,
    List<MustRemember> mustRemember,
    String keyPoint,
  ) {
    final Map<String, List<dynamic>> result = {};

    for (final kp in knowledgePoints.where((kp) => kp.keyPoints.contains(keyPoint))) {
      result.putIfAbsent(kp.subject, () => []);
      result[kp.subject]!.add(kp);
    }

    for (final wq in wrongQuestions.where((wq) => wq.keyPoints.contains(keyPoint))) {
      result.putIfAbsent(wq.subject, () => []);
      result[wq.subject]!.add(wq);
    }

    for (final note in notes.where((n) => n.keyPoints.contains(keyPoint))) {
      result.putIfAbsent(note.subject, () => []);
      result[note.subject]!.add(note);
    }

    for (final mr in mustRemember.where((mr) => mr.keyPoints.contains(keyPoint))) {
      result.putIfAbsent(mr.subject, () => []);
      result[mr.subject]!.add(mr);
    }

    return result;
  }

  /// 提取所有标签
  List<String> _extractAllTags(
    List<KnowledgePoint> knowledgePoints,
    List<WrongQuestion> wrongQuestions,
    List<Note> notes,
    List<MustRemember> mustRemember,
  ) {
    final Set<String> tags = {};
    for (final kp in knowledgePoints) {
      tags.addAll(kp.tags);
    }
    for (final note in notes) {
      tags.addAll(note.tags);
    }
    return tags.toList()..sort();
  }

  /// 提取所有考法
  List<String> _extractAllExamMethods(
    List<KnowledgePoint> knowledgePoints,
    List<WrongQuestion> wrongQuestions,
    List<Note> notes,
    List<MustRemember> mustRemember,
  ) {
    final Set<String> examMethods = {};
    for (final kp in knowledgePoints) {
      examMethods.addAll(kp.examMethods);
    }
    for (final wq in wrongQuestions) {
      examMethods.addAll(wq.examMethods);
    }
    for (final note in notes) {
      examMethods.addAll(note.examMethods);
    }
    for (final mr in mustRemember) {
      examMethods.addAll(mr.examMethods);
    }
    return examMethods.toList()..sort();
  }

  /// 提取所有考点
  List<String> _extractAllKeyPoints(
    List<KnowledgePoint> knowledgePoints,
    List<WrongQuestion> wrongQuestions,
    List<Note> notes,
    List<MustRemember> mustRemember,
  ) {
    final Set<String> keyPoints = {};
    for (final kp in knowledgePoints) {
      keyPoints.addAll(kp.keyPoints);
    }
    for (final wq in wrongQuestions) {
      keyPoints.addAll(wq.keyPoints);
    }
    for (final note in notes) {
      keyPoints.addAll(note.keyPoints);
    }
    for (final mr in mustRemember) {
      keyPoints.addAll(mr.keyPoints);
    }
    return keyPoints.toList()..sort();
  }

  /// 获取思维导图标题
  String _getMindMapTitle(String type, String? filterValue) {
    switch (type) {
      case 'subject':
        return filterValue != null ? '$filterValue 知识图谱' : '学科知识图谱';
      case 'tag':
        return filterValue != null ? '标签: $filterValue' : '标签分类图谱';
      case 'exam_method':
        return filterValue != null ? '考法: $filterValue' : '考法分类图谱';
      case 'key_point':
        return filterValue != null ? '考点: $filterValue' : '考点分类图谱';
      default:
        return '学习知识图谱';
    }
  }

  /// 获取所有学科列表
  Future<List<String>> getAllSubjects() async {
    final knowledgePoints = await _loadKnowledgePoints();
    final wrongQuestions = await _loadWrongQuestions();
    final notes = await _loadNotes();
    final mustRemember = await _loadMustRemember();

    final Set<String> subjects = {};
    subjects.addAll(knowledgePoints.map((kp) => kp.subject));
    subjects.addAll(wrongQuestions.map((wq) => wq.subject));
    subjects.addAll(notes.map((n) => n.subject));
    subjects.addAll(mustRemember.map((mr) => mr.subject));

    return subjects.toList()..sort();
  }

  /// 获取所有考法列表
  Future<List<String>> getAllExamMethods() async {
    final knowledgePoints = await _loadKnowledgePoints();
    final wrongQuestions = await _loadWrongQuestions();
    final notes = await _loadNotes();
    final mustRemember = await _loadMustRemember();

    return _extractAllExamMethods(
      knowledgePoints,
      wrongQuestions,
      notes,
      mustRemember,
    );
  }

  /// 获取所有考点列表
  Future<List<String>> getAllKeyPoints() async {
    final knowledgePoints = await _loadKnowledgePoints();
    final wrongQuestions = await _loadWrongQuestions();
    final notes = await _loadNotes();
    final mustRemember = await _loadMustRemember();

    return _extractAllKeyPoints(
      knowledgePoints,
      wrongQuestions,
      notes,
      mustRemember,
    );
  }

  /// 获取所有标签列表
  Future<List<String>> getAllTags() async {
    final knowledgePoints = await _loadKnowledgePoints();
    final notes = await _loadNotes();

    final Set<String> tags = {};
    for (final kp in knowledgePoints) {
      tags.addAll(kp.tags);
    }
    for (final note in notes) {
      tags.addAll(note.tags);
    }
    return tags.toList()..sort();
  }

  /// 手动添加关联
  Future<void> addManualConnection(
    MindMapData mindMapData,
    String sourceId,
    String targetId,
    String relation,
  ) async {
    // 检查节点是否存在
    final sourceExists = mindMapData.nodes.any((n) => n.id == sourceId);
    final targetExists = mindMapData.nodes.any((n) => n.id == targetId);
    
    if (!sourceExists || !targetExists) {
      throw Exception('节点不存在');
    }

    // 检查是否已存在连接
    final existingConn = mindMapData.connections.any(
      (c) => (c.sourceId == sourceId && c.targetId == targetId) ||
             (c.sourceId == targetId && c.targetId == sourceId),
    );

    if (existingConn) {
      throw Exception('关联已存在');
    }

    mindMapData.connections.add(MindMapConnection(
      sourceId: sourceId,
      targetId: targetId,
      relation: relation,
      strength: 1.0,
      isManual: true,
    ));
  }

  /// 删除关联
  Future<void> removeConnection(
    MindMapData mindMapData,
    String sourceId,
    String targetId,
  ) async {
    mindMapData.connections.removeWhere(
      (c) => (c.sourceId == sourceId && c.targetId == targetId) ||
             (c.sourceId == targetId && c.targetId == sourceId),
    );
  }
}
