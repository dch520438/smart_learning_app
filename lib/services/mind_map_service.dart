import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/mind_map_data.dart';
import '../models/knowledge_point.dart';
import '../models/wrong_question.dart';
import '../models/note.dart';
import '../models/must_remember.dart';
import 'database_service.dart';

/// ============================================================
/// MindMapService - 思维导图服务 (重构版)
/// ============================================================
///
/// 提供思维导图的自动生成、手动创建、编辑等功能
/// 按学科->章节->内容的层次结构组织

class MindMapService {
  final DatabaseService _dbService = DatabaseService();

  /// 生成思维导图数据
  ///
  /// [type] - 导图类型: 'all'(全部), 'subject'(按学科)
  /// [filterValue] - 过滤值（如学科名称）
  Future<MindMapData> generateMindMap({
    String type = 'all',
    String? filterValue,
  }) async {
    // 加载所有数据
    final knowledgePoints = await _loadKnowledgePoints();
    final wrongQuestions = await _loadWrongQuestions();
    final notes = await _loadNotes();
    final mustRemember = await _loadMustRemember();

    // 根据类型生成不同的结构
    MindMapNode rootNode;

    switch (type) {
      case 'subject':
        rootNode = await _generateBySubject(
          knowledgePoints,
          wrongQuestions,
          notes,
          mustRemember,
          filterValue,
        );
        break;
      default:
        rootNode = await _generateAll(
          knowledgePoints,
          wrongQuestions,
          notes,
          mustRemember,
        );
    }

    // 分析节点间的关联
    final connections = _analyzeConnections(rootNode.getAllNodes());

    return MindMapData(
      rootNode: rootNode,
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
        if (value.trim().isEmpty) return [];

        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded
              .map((e) => e?.toString() ?? '')
              .where((e) => e.isNotEmpty)
              .toList();
        }
        return [];
      } else if (value is List) {
        return value
            .map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList();
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
      chapter: r['chapter']?.toString(),
      tags: tags,
      categoryId: r['category']?.toString(),
      difficulty: r['difficulty'] is int
          ? r['difficulty'] as int
          : int.tryParse(r['difficulty']?.toString() ?? '') ?? 1,
      masteryLevel: r['mastery_level'] is int
          ? r['mastery_level'] as int
          : int.tryParse(r['mastery_level']?.toString() ?? '') ?? 0,
      reviewCount: r['review_count'] is int
          ? r['review_count'] as int
          : int.tryParse(r['review_count']?.toString() ?? '') ?? 0,
      isFavorite:
          (r['is_favorite'] is int ? r['is_favorite'] as int : 0) == 1,
      createdAt: createdAt,
      updatedAt: updatedAt,
      examMethods: examMethods,
      keyPoints: keyPoints,
    );
  }

  /// 将数据库行转换为 WrongQuestion
  WrongQuestion _rowToWrongQuestion(Map<String, dynamic> r) {
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
      chapter: r['chapter']?.toString(),
      errorType: r['error_type']?.toString() ?? '知识盲区',
      errorCount: r['error_count'] is int
          ? r['error_count'] as int
          : int.tryParse(r['error_count']?.toString() ?? '') ?? 1,
      isResolved:
          (r['is_mastered'] is int ? r['is_mastered'] as int : 0) == 1,
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
      chapter: r['chapter']?.toString(),
      tags: tags,
      color: r['color']?.toString() ?? '#FFFFFF',
      isFavorite:
          (r['is_favorite'] is int ? r['is_favorite'] as int : 0) == 1,
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
        nextReviewTime =
            DateTime.tryParse(r['next_review_time'] as String)
                ?.millisecondsSinceEpoch;
      }
    }

    return MustRemember(
      id: r['uuid']?.toString() ?? r['id'].toString(),
      title: r['title']?.toString() ?? '',
      content: r['content']?.toString() ?? '',
      subject: r['subject']?.toString() ?? '其他',
      chapter: r['chapter']?.toString(),
      category: r['category']?.toString() ?? '其他',
      memoryLevel: r['memory_level'] is int
          ? r['memory_level'] as int
          : int.tryParse(r['memory_level']?.toString() ?? '') ?? 0,
      nextReviewTime: nextReviewTime,
      reviewInterval: r['review_interval'] is int
          ? r['review_interval'] as int
          : int.tryParse(r['review_interval']?.toString() ?? '') ?? 0,
      reviewCount: r['review_count'] is int
          ? r['review_count'] as int
          : int.tryParse(r['review_count']?.toString() ?? '') ?? 0,
      isMastered:
          (r['is_mastered'] is int ? r['is_mastered'] as int : 0) == 1,
      createdAt: createdAt,
      updatedAt: updatedAt,
      examMethods: examMethods,
      keyPoints: keyPoints,
    );
  }

  /// 生成全部内容的思维导图
  /// 结构：根节点 -> 学科 -> 章节 -> 内容
  Future<MindMapNode> _generateAll(
    List<KnowledgePoint> knowledgePoints,
    List<WrongQuestion> wrongQuestions,
    List<Note> notes,
    List<MustRemember> mustRemember,
  ) async {
    // 创建根节点
    final rootNode = MindMapNode(
      id: 'root',
      title: '学习知识图谱',
      type: NodeType.root,
      subject: '全部',
      x: 0,
      y: 0,
    );

    // 按学科分组
    final subjects = _groupBySubject(
      knowledgePoints,
      wrongQuestions,
      notes,
      mustRemember,
    );

    // 为每个学科创建分支
    final subjectNames = subjects.keys.toList();
    final angleStep = 2 * pi / max(subjectNames.length, 1);

    for (int i = 0; i < subjectNames.length; i++) {
      final subject = subjectNames[i];
      final angle = i * angleStep - pi / 2;
      const distance = 250.0;

      final subjectNode = MindMapNode(
        id: 'subject_$subject',
        title: subject,
        content: '学科：$subject',
        type: NodeType.subject,
        subject: subject,
        x: cos(angle) * distance,
        y: sin(angle) * distance,
        parentId: rootNode.id,
      );
      rootNode.addChild(subjectNode);

      // 获取该学科下的所有内容
      final content = subjects[subject]!;

      // 按章节分组
      final chapters = _groupByChapter(content);

      // 为每个章节创建子节点
      final chapterNames = chapters.keys.toList();
      final chapterAngleStep = (2 * pi / 6) / max(chapterNames.length, 1);
      final chapterBaseAngle = angle - (2 * pi / 12);

      for (int j = 0; j < chapterNames.length; j++) {
        final chapter = chapterNames[j];
        final chapterAngle = chapterBaseAngle + j * chapterAngleStep;
        const chapterDistance = 180.0;

        final chapterNode = MindMapNode(
          id: 'chapter_${subject}_$chapter',
          title: chapter,
          content: '章节：$chapter',
          type: NodeType.chapter,
          subject: subject,
          chapter: chapter,
          x: subjectNode.x + cos(chapterAngle) * chapterDistance,
          y: subjectNode.y + sin(chapterAngle) * chapterDistance,
          parentId: subjectNode.id,
        );
        subjectNode.addChild(chapterNode);

        // 添加章节下的内容节点
        final chapterContent = chapters[chapter]!;
        chapterNode.children.addAll(
          _createContentNodesForChapter(
            chapterContent,
            chapterNode.x,
            chapterNode.y,
            chapterAngle,
            subject,
            chapter,
          ),
        );
      }

      // 如果没有章节，直接添加内容
      if (chapterNames.isEmpty) {
        subjectNode.children.addAll(
          _createContentNodesForChapter(
            content,
            subjectNode.x,
            subjectNode.y,
            angle,
            subject,
            null,
          ),
        );
      }
    }

    return rootNode;
  }

  /// 按学科生成思维导图
  Future<MindMapNode> _generateBySubject(
    List<KnowledgePoint> knowledgePoints,
    List<WrongQuestion> wrongQuestions,
    List<Note> notes,
    List<MustRemember> mustRemember,
    String? subject,
  ) async {
    if (subject == null) {
      return _generateAll(
          knowledgePoints, wrongQuestions, notes, mustRemember);
    }

    // 创建根节点
    final rootNode = MindMapNode(
      id: 'root',
      title: subject,
      content: '学科知识图谱：$subject',
      type: NodeType.root,
      subject: subject,
      x: 0,
      y: 0,
    );

    // 过滤该学科的内容
    final filtered = _filterBySubject(
      knowledgePoints,
      wrongQuestions,
      notes,
      mustRemember,
      subject,
    );

    // 按章节分组
    final chapters = _groupByChapter(filtered);

    // 为每个章节创建节点
    final chapterNames = chapters.keys.toList();
    final angleStep = 2 * pi / max(chapterNames.length, 1);

    for (int i = 0; i < chapterNames.length; i++) {
      final chapter = chapterNames[i];
      final angle = i * angleStep - pi / 2;
      const distance = 200.0;

      final chapterNode = MindMapNode(
        id: 'chapter_$chapter',
        title: chapter,
        content: '章节：$chapter',
        type: NodeType.chapter,
        subject: subject,
        chapter: chapter,
        x: cos(angle) * distance,
        y: sin(angle) * distance,
        parentId: rootNode.id,
      );
      rootNode.addChild(chapterNode);

      // 添加章节下的内容节点
      final chapterContent = chapters[chapter]!;
      chapterNode.children.addAll(
        _createContentNodesForChapter(
          chapterContent,
          chapterNode.x,
          chapterNode.y,
          angle,
          subject,
          chapter,
        ),
      );
    }

    return rootNode;
  }

  /// 按学科分组
  Map<String, Map<String, List<dynamic>>> _groupBySubject(
    List<KnowledgePoint> knowledgePoints,
    List<WrongQuestion> wrongQuestions,
    List<Note> notes,
    List<MustRemember> mustRemember,
  ) {
    final Map<String, Map<String, List<dynamic>>> result = {};

    void addToSubject(String subject, String type, dynamic item) {
      result.putIfAbsent(subject, () => {});
      result[subject]!.putIfAbsent(type, () => []);
      result[subject]![type]!.add(item);
    }

    for (final kp in knowledgePoints) {
      addToSubject(kp.subject, 'knowledgePoints', kp);
    }
    for (final wq in wrongQuestions) {
      addToSubject(wq.subject, 'wrongQuestions', wq);
    }
    for (final note in notes) {
      addToSubject(note.subject, 'notes', note);
    }
    for (final mr in mustRemember) {
      addToSubject(mr.subject, 'mustRemember', mr);
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
      'knowledgePoints':
          knowledgePoints.where((kp) => kp.subject == subject).toList(),
      'wrongQuestions':
          wrongQuestions.where((wq) => wq.subject == subject).toList(),
      'notes': notes.where((n) => n.subject == subject).toList(),
      'mustRemember':
          mustRemember.where((mr) => mr.subject == subject).toList(),
    };
  }

  /// 按章节分组
  Map<String, Map<String, List<dynamic>>> _groupByChapter(
    Map<String, List<dynamic>> content,
  ) {
    final Map<String, Map<String, List<dynamic>>> result = {};

    void addItem(String? chapter, String type, dynamic item) {
      final key = chapter ?? '未分类';
      result.putIfAbsent(key, () => {});
      result[key]!.putIfAbsent(type, () => []);
      result[key]![type]!.add(item);
    }

    for (final kp in content['knowledgePoints'] ?? []) {
      addItem((kp as KnowledgePoint).chapter, 'knowledgePoints', kp);
    }
    for (final wq in content['wrongQuestions'] ?? []) {
      addItem((wq as WrongQuestion).chapter, 'wrongQuestions', wq);
    }
    for (final note in content['notes'] ?? []) {
      addItem((note as Note).chapter, 'notes', note);
    }
    for (final mr in content['mustRemember'] ?? []) {
      addItem((mr as MustRemember).chapter, 'mustRemember', mr);
    }

    return result;
  }

  /// 为章节创建内容节点
  List<MindMapNode> _createContentNodesForChapter(
    Map<String, List<dynamic>> content,
    double parentX,
    double parentY,
    double baseAngle,
    String subject,
    String? chapter,
  ) {
    final List<MindMapNode> nodes = [];
    final allItems = content.values.expand((x) => x).toList();

    if (allItems.isEmpty) return nodes;

    // 按类型分组
    final typeOrder = ['knowledgePoints', 'wrongQuestions', 'notes', 'mustRemember'];
    final typeNames = {
      'knowledgePoints': '知识点',
      'wrongQuestions': '错题',
      'notes': '笔记',
      'mustRemember': '必记必背',
    };

    final angleStep = pi / 4 / max(allItems.length, 1);
    var currentAngle = baseAngle - pi / 8;
    const distance = 120.0;

    for (final type in typeOrder) {
      final items = content[type] ?? [];
      for (final item in items) {
        String id, title, content;
        NodeType nodeType;
        Map<String, dynamic> data = {};

        if (item is KnowledgePoint) {
          id = 'kp_${item.id}';
          title = item.title;
          content = item.content.length > 50
              ? '${item.content.substring(0, 50)}...'
              : item.content;
          nodeType = NodeType.knowledgePoint;
          data = {'knowledgePoint': item.toJson()};
        } else if (item is WrongQuestion) {
          id = 'wq_${item.id}';
          title = item.title.isNotEmpty ? item.title : '错题';
          content = '错误类型：${item.errorType}';
          nodeType = NodeType.wrongQuestion;
          data = {'wrongQuestion': item.toJson()};
        } else if (item is Note) {
          id = 'note_${item.id}';
          title = item.title;
          content = item.content.length > 50
              ? '${item.content.substring(0, 50)}...'
              : item.content;
          nodeType = NodeType.note;
          data = {'note': item.toJson()};
        } else if (item is MustRemember) {
          id = 'mr_${item.id}';
          title = item.title;
          content = item.content.length > 50
              ? '${item.content.substring(0, 50)}...'
              : item.content;
          nodeType = NodeType.mustRemember;
          data = {'mustRemember': item.toJson()};
        } else {
          continue;
        }

        nodes.add(MindMapNode(
          id: id,
          title: title.length > 12 ? '${title.substring(0, 12)}...' : title,
          content: content,
          type: nodeType,
          subject: subject,
          chapter: chapter,
          sourceId: item.id,
          x: parentX + cos(currentAngle) * distance,
          y: parentY + sin(currentAngle) * distance,
          parentId: chapter != null ? 'chapter_$chapter' : 'subject_$subject',
          data: data,
        ));

        currentAngle += angleStep;
      }
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
    // 同章节关联
    if (node1.chapter != null &&
        node2.chapter != null &&
        node1.chapter == node2.chapter) {
      return '同章节';
    }

    // 同主题关联
    if (node1.subject == node2.subject) {
      return '同学科';
    }

    // 从data中检查考法和考点
    final examMethods1 = _extractExamMethodsFromNodeData(node1);
    final examMethods2 = _extractExamMethodsFromNodeData(node2);
    final commonExamMethods =
        examMethods1.where((em) => examMethods2.contains(em)).toList();
    if (commonExamMethods.isNotEmpty) {
      return '同考法';
    }

    final keyPoints1 = _extractKeyPointsFromNodeData(node1);
    final keyPoints2 = _extractKeyPointsFromNodeData(node2);
    final commonKeyPoints =
        keyPoints1.where((kp) => keyPoints2.contains(kp)).toList();
    if (commonKeyPoints.isNotEmpty) {
      return '同考点';
    }

    return null;
  }

  /// 计算关联强度
  double _calculateRelationStrength(MindMapNode node1, MindMapNode node2) {
    double strength = 0.0;

    // 同章节 +0.5
    if (node1.chapter != null &&
        node2.chapter != null &&
        node1.chapter == node2.chapter) {
      strength += 0.5;
    }

    // 同学科 +0.3
    if (node1.subject == node2.subject) {
      strength += 0.3;
    }

    // 同考法 +0.2
    final examMethods1 = _extractExamMethodsFromNodeData(node1);
    final examMethods2 = _extractExamMethodsFromNodeData(node2);
    final commonExamMethods =
        examMethods1.where((em) => examMethods2.contains(em)).length;
    strength += 0.2 * commonExamMethods;

    // 同考点 +0.2
    final keyPoints1 = _extractKeyPointsFromNodeData(node1);
    final keyPoints2 = _extractKeyPointsFromNodeData(node2);
    final commonKeyPoints =
        keyPoints1.where((kp) => keyPoints2.contains(kp)).length;
    strength += 0.2 * commonKeyPoints;

    return strength.clamp(0.0, 1.0);
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

  /// 获取思维导图标题
  String _getMindMapTitle(String type, String? filterValue) {
    switch (type) {
      case 'subject':
        return filterValue != null ? '$filterValue 知识图谱' : '学科知识图谱';
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

  /// 获取所有章节列表
  Future<List<String>> getAllChapters(String subject) async {
    final knowledgePoints = await _loadKnowledgePoints();
    final wrongQuestions = await _loadWrongQuestions();
    final notes = await _loadNotes();
    final mustRemember = await _loadMustRemember();

    final Set<String> chapters = {};
    for (final kp in knowledgePoints.where((kp) => kp.subject == subject)) {
      if (kp.chapter != null) chapters.add(kp.chapter!);
    }
    for (final wq in wrongQuestions.where((wq) => wq.subject == subject)) {
      if (wq.chapter != null) chapters.add(wq.chapter!);
    }
    for (final note in notes.where((n) => n.subject == subject)) {
      if (note.chapter != null) chapters.add(note.chapter!);
    }
    for (final mr in mustRemember.where((mr) => mr.subject == subject)) {
      if (mr.chapter != null) chapters.add(mr.chapter!);
    }

    return chapters.toList()..sort();
  }

  /// 获取所有考法列表
  Future<List<String>> getAllExamMethods() async {
    final knowledgePoints = await _loadKnowledgePoints();
    final wrongQuestions = await _loadWrongQuestions();
    final notes = await _loadNotes();
    final mustRemember = await _loadMustRemember();

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

  /// 获取所有考点列表
  Future<List<String>> getAllKeyPoints() async {
    final knowledgePoints = await _loadKnowledgePoints();
    final wrongQuestions = await _loadWrongQuestions();
    final notes = await _loadNotes();
    final mustRemember = await _loadMustRemember();

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

  /// 手动创建节点
  Future<MindMapNode> createManualNode({
    required String title,
    required String content,
    required NodeType type,
    required String subject,
    String? chapter,
    String? parentId,
    double? x,
    double? y,
  }) async {
    return MindMapNode(
      title: title,
      content: content,
      type: type,
      subject: subject,
      chapter: chapter,
      parentId: parentId,
      x: x ?? 0,
      y: y ?? 0,
    );
  }

  /// 添加手动关联
  Future<void> addManualConnection(
    MindMapData mindMapData,
    String sourceId,
    String targetId,
    String relation,
  ) async {
    // 检查节点是否存在
    final sourceNode = mindMapData.findNodeById(sourceId);
    final targetNode = mindMapData.findNodeById(targetId);

    if (sourceNode == null || targetNode == null) {
      throw Exception('节点不存在');
    }

    // 检查是否已存在连接
    final existingConn = mindMapData.connections.any(
      (c) =>
          (c.sourceId == sourceId && c.targetId == targetId) ||
          (c.sourceId == targetId && c.targetId == sourceId),
    );

    if (existingConn) {
      throw Exception('关联已存在');
    }

    mindMapData.addConnection(MindMapConnection(
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
    mindMapData.removeConnection(sourceId, targetId);
  }

  /// 保存思维导图到数据库
  Future<void> saveMindMap(MindMapData mindMapData) async {
    final db = await _dbService.database;
    await db.insert(
      DatabaseService.tableMindMapData,
      {
        'uuid': mindMapData.id,
        'title': mindMapData.title,
        'data': jsonEncode(mindMapData.toJson()),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 从数据库加载思维导图
  Future<MindMapData?> loadMindMap(String id) async {
    final db = await _dbService.database;
    final rows = await db.query(
      DatabaseService.tableMindMapData,
      where: 'uuid = ?',
      whereArgs: [id],
    );

    if (rows.isEmpty) return null;

    final data = jsonDecode(rows.first['data'] as String)
        as Map<String, dynamic>;
    return MindMapData.fromJson(data);
  }

  /// 获取所有保存的思维导图
  Future<List<MindMapData>> getAllSavedMindMaps() async {
    final db = await _dbService.database;
    final rows = await db.query(
      DatabaseService.tableMindMapData,
      orderBy: 'updated_at DESC',
    );

    return rows.map((row) {
      final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
      return MindMapData.fromJson(data);
    }).toList();
  }

  /// 删除保存的思维导图
  Future<void> deleteSavedMindMap(String id) async {
    final db = await _dbService.database;
    await db.delete(
      DatabaseService.tableMindMapData,
      where: 'uuid = ?',
      whereArgs: [id],
    );
  }
}
