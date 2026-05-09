import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// SQLite 数据库服务
/// 管理应用所有本地数据的持久化存储
class DatabaseService {
  // 单例模式
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  // 数据库名称和版本
  static const String _databaseName = 'smart_learning.db';
  static const int _databaseVersion = 4;

  // 表名常量
  static const String tableKnowledgePoints = 'knowledge_points';
  static const String tableNotes = 'notes';
  static const String tableMustRemembers = 'must_remembers';
  static const String tableWrongQuestions = 'wrong_questions';
  static const String tableMotherQuestions = 'mother_questions';
  static const String tableExams = 'exams';
  static const String tableExamResults = 'exam_results';
  static const String tableStudyRecords = 'study_records';
  static const String tableUserProfiles = 'user_profiles';
  static const String tableMindMapData = 'mind_map_data';
  static const String tableHabits = 'habits';
  static const String tableHabitCheckIns = 'habit_check_ins';
  static const String tableExamPapers = 'exam_papers';
  static const String tableUsageRecords = 'usage_records';

  /// 获取数据库实例，如果不存在则创建
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// 初始化数据库
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// 创建所有表
  Future<void> _onCreate(Database db, int version) async {
    // 知识点表
    await db.execute('''
      CREATE TABLE $tableKnowledgePoints (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        content TEXT,
        subject TEXT,
        category TEXT,
        tags TEXT,
        exam_methods TEXT,
        key_points TEXT,
        difficulty INTEGER DEFAULT 0,
        mastery_level INTEGER DEFAULT 0,
        review_count INTEGER DEFAULT 0,
        last_review_time TEXT,
        parent_id INTEGER,
        sort_order INTEGER DEFAULT 0,
        is_favorite INTEGER DEFAULT 0,
        attachment_paths TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 笔记表
    await db.execute('''
      CREATE TABLE $tableNotes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        content TEXT,
        subject TEXT,
        tags TEXT,
        exam_methods TEXT,
        key_points TEXT,
        note_type TEXT DEFAULT 'text',
        knowledge_point_id INTEGER,
        is_favorite INTEGER DEFAULT 0,
        attachment_paths TEXT,
        color TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (knowledge_point_id) REFERENCES $tableKnowledgePoints (id) ON DELETE SET NULL
      )
    ''');

    // 必记内容表
    await db.execute('''
      CREATE TABLE $tableMustRemembers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        subject TEXT,
        category TEXT,
        tags TEXT,
        exam_methods TEXT,
        key_points TEXT,
        importance INTEGER DEFAULT 0,
        memory_level INTEGER DEFAULT 0,
        review_count INTEGER DEFAULT 0,
        review_interval INTEGER DEFAULT 0,
        next_review_time TEXT,
        last_review_time TEXT,
        is_mastered INTEGER DEFAULT 0,
        is_favorite INTEGER DEFAULT 0,
        attachment_paths TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 错题表
    await db.execute('''
      CREATE TABLE $tableWrongQuestions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        title TEXT,
        question_content TEXT NOT NULL,
        question_type TEXT,
        options TEXT,
        correct_answer TEXT,
        my_answer TEXT,
        analysis TEXT,
        subject TEXT,
        error_type TEXT,
        knowledge_point_id INTEGER,
        error_count INTEGER DEFAULT 1,
        correct_count INTEGER DEFAULT 0,
        difficulty INTEGER DEFAULT 0,
        is_mastered INTEGER DEFAULT 0,
        last_error_time TEXT,
        last_correct_time TEXT,
        exam_methods TEXT,
        key_points TEXT,
        tags TEXT,
        attachment_paths TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (knowledge_point_id) REFERENCES $tableKnowledgePoints (id) ON DELETE SET NULL
      )
    ''');

    // 母题表
    await db.execute('''
      CREATE TABLE $tableMotherQuestions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        question_content TEXT NOT NULL,
        question_type TEXT,
        options TEXT,
        correct_answer TEXT,
        analysis TEXT,
        subject TEXT,
        category TEXT,
        tags TEXT,
        exam_methods TEXT,
        key_points TEXT,
        difficulty INTEGER DEFAULT 0,
        knowledge_point_id INTEGER,
        variant_count INTEGER DEFAULT 0,
        mastery_level INTEGER DEFAULT 0,
        practice_count INTEGER DEFAULT 0,
        is_favorite INTEGER DEFAULT 0,
        attachment_paths TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (knowledge_point_id) REFERENCES $tableKnowledgePoints (id) ON DELETE SET NULL
      )
    ''');

    // 考试表
    await db.execute('''
      CREATE TABLE $tableExams (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        description TEXT,
        subject TEXT,
        exam_type TEXT DEFAULT 'practice',
        total_questions INTEGER DEFAULT 0,
        total_score REAL DEFAULT 100.0,
        time_limit INTEGER,
        passing_score REAL DEFAULT 60.0,
        question_ids TEXT,
        is_completed INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 考试结果表
    await db.execute('''
      CREATE TABLE $tableExamResults (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        exam_id INTEGER NOT NULL,
        score REAL,
        correct_count INTEGER DEFAULT 0,
        wrong_count INTEGER DEFAULT 0,
        total_count INTEGER DEFAULT 0,
        time_spent INTEGER,
        accuracy REAL DEFAULT 0.0,
        answers TEXT,
        is_passed INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (exam_id) REFERENCES $tableExams (id) ON DELETE CASCADE
      )
    ''');

    // 学习记录表
    await db.execute('''
      CREATE TABLE $tableStudyRecords (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        record_type TEXT NOT NULL,
        title TEXT,
        description TEXT,
        subject TEXT,
        duration INTEGER DEFAULT 0,
        related_id INTEGER,
        related_type TEXT,
        score REAL,
        is_completed INTEGER DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    // 用户资料表
    await db.execute('''
      CREATE TABLE $tableUserProfiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        nickname TEXT,
        avatar_path TEXT,
        school TEXT,
        grade TEXT,
        class_name TEXT,
        target_score REAL,
        daily_study_goal INTEGER DEFAULT 60,
        motto TEXT,
        study_streak INTEGER DEFAULT 0,
        total_study_days INTEGER DEFAULT 0,
        total_study_time INTEGER DEFAULT 0,
        settings TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 思维导图数据表
    await db.execute('''
      CREATE TABLE $tableMindMapData (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        subject TEXT,
        map_data TEXT NOT NULL,
        thumbnail_path TEXT,
        is_favorite INTEGER DEFAULT 0,
        knowledge_point_id INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (knowledge_point_id) REFERENCES $tableKnowledgePoints (id) ON DELETE SET NULL
      )
    ''');

    // 习惯表
    await db.execute('''
      CREATE TABLE $tableHabits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        description TEXT,
        target_days INTEGER NOT NULL,
        current_streak INTEGER DEFAULT 0,
        total_completed_days INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        completed_at TEXT,
        is_active INTEGER DEFAULT 1,
        icon TEXT,
        color INTEGER,
        reminder_hour INTEGER,
        reminder_minute INTEGER,
        reminder_enabled INTEGER DEFAULT 0
      )
    ''');

    // 习惯打卡记录表
    await db.execute('''
      CREATE TABLE $tableHabitCheckIns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        habit_uuid TEXT NOT NULL,
        check_in_time TEXT NOT NULL,
        note TEXT,
        mood INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY (habit_uuid) REFERENCES $tableHabits (uuid) ON DELETE CASCADE
      )
    ''');

    // 试卷表
    await db.execute('''
      CREATE TABLE $tableExamPapers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        subject TEXT NOT NULL,
        exam_date INTEGER NOT NULL,
        total_score INTEGER NOT NULL,
        obtained_score INTEGER,
        questions TEXT,
        images TEXT,
        notes TEXT,
        tags TEXT,
        source TEXT DEFAULT 'mock',
        attachment_paths TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // APP使用记录表
    await db.execute('''
      CREATE TABLE $tableUsageRecords (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        start_time INTEGER NOT NULL,
        end_time INTEGER,
        duration INTEGER,
        date TEXT NOT NULL,
        device_info TEXT,
        app_version TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // 创建索引
    await _createIndexes(db);
  }

  /// 创建索引以提高查询性能
  Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX idx_kp_subject ON $tableKnowledgePoints (subject)',
    );
    await db.execute(
      'CREATE INDEX idx_kp_category ON $tableKnowledgePoints (category)',
    );
    await db.execute(
      'CREATE INDEX idx_notes_subject ON $tableNotes (subject)',
    );
    await db.execute(
      'CREATE INDEX idx_mr_subject ON $tableMustRemembers (subject)',
    );
    await db.execute(
      'CREATE INDEX idx_wq_subject ON $tableWrongQuestions (subject)',
    );
    await db.execute(
      'CREATE INDEX idx_wq_mastered ON $tableWrongQuestions (is_mastered)',
    );
    await db.execute(
      'CREATE INDEX idx_mq_subject ON $tableMotherQuestions (subject)',
    );
    await db.execute(
      'CREATE INDEX idx_exam_subject ON $tableExams (subject)',
    );
    await db.execute(
      'CREATE INDEX idx_er_exam ON $tableExamResults (exam_id)',
    );
    await db.execute(
      'CREATE INDEX idx_sr_type ON $tableStudyRecords (record_type)',
    );
    await db.execute(
      'CREATE INDEX idx_sr_date ON $tableStudyRecords (created_at)',
    );
    await db.execute(
      'CREATE INDEX idx_mm_subject ON $tableMindMapData (subject)',
    );
    await db.execute(
      'CREATE INDEX idx_habit_active ON $tableHabits (is_active)',
    );
    await db.execute(
      'CREATE INDEX idx_habit_checkin_habit ON $tableHabitCheckIns (habit_uuid)',
    );
    await db.execute(
      'CREATE INDEX idx_habit_checkin_time ON $tableHabitCheckIns (check_in_time)',
    );
    await db.execute(
      'CREATE INDEX idx_exam_paper_subject ON $tableExamPapers (subject)',
    );
    await db.execute(
      'CREATE INDEX idx_exam_paper_date ON $tableExamPapers (exam_date)',
    );
    await db.execute(
      'CREATE INDEX idx_exam_paper_source ON $tableExamPapers (source)',
    );
    await db.execute(
      'CREATE INDEX idx_usage_records_date ON $tableUsageRecords (date)',
    );
    await db.execute(
      'CREATE INDEX idx_usage_records_start_time ON $tableUsageRecords (start_time)',
    );
  }

  /// 数据库升级
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 版本1 -> 版本2：添加缺失的列
    if (oldVersion < 2) {
      // knowledge_points 表：添加 exam_methods, key_points
      await _addColumnSafe(db, tableKnowledgePoints, 'exam_methods', 'TEXT');
      await _addColumnSafe(db, tableKnowledgePoints, 'key_points', 'TEXT');

      // notes 表：添加 exam_methods, key_points
      await _addColumnSafe(db, tableNotes, 'exam_methods', 'TEXT');
      await _addColumnSafe(db, tableNotes, 'key_points', 'TEXT');

      // wrong_questions 表：添加 title, error_type, exam_methods, key_points
      await _addColumnSafe(db, tableWrongQuestions, 'title', 'TEXT');
      await _addColumnSafe(db, tableWrongQuestions, 'error_type', 'TEXT');
      await _addColumnSafe(db, tableWrongQuestions, 'exam_methods', 'TEXT');
      await _addColumnSafe(db, tableWrongQuestions, 'key_points', 'TEXT');

      // mother_questions 表：添加 exam_methods, key_points
      await _addColumnSafe(db, tableMotherQuestions, 'exam_methods', 'TEXT');
      await _addColumnSafe(db, tableMotherQuestions, 'key_points', 'TEXT');

      // must_remembers 表：添加 exam_methods, key_points, review_interval
      await _addColumnSafe(db, tableMustRemembers, 'exam_methods', 'TEXT');
      await _addColumnSafe(db, tableMustRemembers, 'key_points', 'TEXT');
      await _addColumnSafe(db, tableMustRemembers, 'review_interval', 'INTEGER DEFAULT 0');
    }

    // 版本2 -> 版本3：添加 tags 列
    if (oldVersion < 3) {
      await _addColumnSafe(db, tableWrongQuestions, 'tags', 'TEXT');
      await _addColumnSafe(db, tableExamPapers, 'tags', 'TEXT');
    }

    // 版本3 -> 版本4：添加 attachment_paths 列到试卷表
    if (oldVersion < 4) {
      await _addColumnSafe(db, tableExamPapers, 'attachment_paths', 'TEXT');
    }
  }

  /// 安全地添加列（如果列不存在才添加）
  Future<void> _addColumnSafe(Database db, String table, String column, String type) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    } catch (e) {
      // 列已存在时忽略错误
      // ignore: avoid_print
      print('列 $table.$column 已存在，跳过添加');
    }
  }

  /// 关闭数据库
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  // ==================== 知识点 CRUD ====================

  /// 插入知识点
  Future<int> insertKnowledgePoint(Map<String, dynamic> data) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    data['created_at'] = now;
    data['updated_at'] = now;
    return await db.insert(tableKnowledgePoints, data);
  }

  /// 更新知识点
  Future<int> updateKnowledgePoint(int id, Map<String, dynamic> data) async {
    final db = await database;
    data['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      tableKnowledgePoints,
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除知识点
  Future<int> deleteKnowledgePoint(int id) async {
    final db = await database;
    return await db.delete(
      tableKnowledgePoints,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 根据ID查询知识点
  Future<Map<String, dynamic>?> queryKnowledgePointById(int id) async {
    final db = await database;
    final results = await db.query(
      tableKnowledgePoints,
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 根据UUID查询知识点
  Future<Map<String, dynamic>?> queryKnowledgePointByUuid(String uuid) async {
    final db = await database;
    final results = await db.query(
      tableKnowledgePoints,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 查询所有知识点
  Future<List<Map<String, dynamic>>> queryAllKnowledgePoints({
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      tableKnowledgePoints,
      orderBy: orderBy ?? 'created_at DESC',
      limit: limit,
      offset: offset,
    );
  }

  /// 按科目查询知识点
  Future<List<Map<String, dynamic>>> queryKnowledgePointsBySubject(
    String subject,
  ) async {
    final db = await database;
    return await db.query(
      tableKnowledgePoints,
      where: 'subject = ?',
      whereArgs: [subject],
      orderBy: 'created_at DESC',
    );
  }

  /// 按分类查询知识点
  Future<List<Map<String, dynamic>>> queryKnowledgePointsByCategory(
    String category,
  ) async {
    final db = await database;
    return await db.query(
      tableKnowledgePoints,
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'sort_order ASC',
    );
  }

  /// 查询收藏的知识点
  Future<List<Map<String, dynamic>>> queryFavoriteKnowledgePoints() async {
    final db = await database;
    return await db.query(
      tableKnowledgePoints,
      where: 'is_favorite = ?',
      whereArgs: [1],
      orderBy: 'updated_at DESC',
    );
  }

  /// 查询子知识点
  Future<List<Map<String, dynamic>>> queryChildKnowledgePoints(
    int parentId,
  ) async {
    final db = await database;
    return await db.query(
      tableKnowledgePoints,
      where: 'parent_id = ?',
      whereArgs: [parentId],
      orderBy: 'sort_order ASC',
    );
  }

  /// 知识点计数
  Future<int> countKnowledgePoints({String? subject}) async {
    final db = await database;
    if (subject != null) {
      final results = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableKnowledgePoints WHERE subject = ?',
        [subject],
      );
      return Sqflite.firstIntValue(results) ?? 0;
    }
    return Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) as count FROM $tableKnowledgePoints'),
    ) ?? 0;
  }

  // ==================== 笔记 CRUD ====================

  /// 插入笔记
  Future<int> insertNote(Map<String, dynamic> data) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    data['created_at'] = now;
    data['updated_at'] = now;
    return await db.insert(tableNotes, data);
  }

  /// 更新笔记
  Future<int> updateNote(int id, Map<String, dynamic> data) async {
    final db = await database;
    data['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      tableNotes,
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除笔记
  Future<int> deleteNote(int id) async {
    final db = await database;
    return await db.delete(
      tableNotes,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 根据ID查询笔记
  Future<Map<String, dynamic>?> queryNoteById(int id) async {
    final db = await database;
    final results = await db.query(
      tableNotes,
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 根据UUID查询笔记
  Future<Map<String, dynamic>?> queryNoteByUuid(String uuid) async {
    final db = await database;
    final results = await db.query(
      tableNotes,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 查询所有笔记
  Future<List<Map<String, dynamic>>> queryAllNotes({
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      tableNotes,
      orderBy: orderBy ?? 'created_at DESC',
      limit: limit,
      offset: offset,
    );
  }

  /// 按科目查询笔记
  Future<List<Map<String, dynamic>>> queryNotesBySubject(String subject) async {
    final db = await database;
    return await db.query(
      tableNotes,
      where: 'subject = ?',
      whereArgs: [subject],
      orderBy: 'created_at DESC',
    );
  }

  /// 按知识点查询笔记
  Future<List<Map<String, dynamic>>> queryNotesByKnowledgePoint(
    int knowledgePointId,
  ) async {
    final db = await database;
    return await db.query(
      tableNotes,
      where: 'knowledge_point_id = ?',
      whereArgs: [knowledgePointId],
      orderBy: 'created_at DESC',
    );
  }

  /// 查询收藏的笔记
  Future<List<Map<String, dynamic>>> queryFavoriteNotes() async {
    final db = await database;
    return await db.query(
      tableNotes,
      where: 'is_favorite = ?',
      whereArgs: [1],
      orderBy: 'updated_at DESC',
    );
  }

  /// 笔记计数
  Future<int> countNotes({String? subject}) async {
    final db = await database;
    if (subject != null) {
      final results = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableNotes WHERE subject = ?',
        [subject],
      );
      return Sqflite.firstIntValue(results) ?? 0;
    }
    return Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) as count FROM $tableNotes'),
    ) ?? 0;
  }

  // ==================== 必记内容 CRUD ====================

  /// 插入必记内容
  Future<int> insertMustRemember(Map<String, dynamic> data) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    data['created_at'] = now;
    data['updated_at'] = now;
    return await db.insert(tableMustRemembers, data);
  }

  /// 更新必记内容
  Future<int> updateMustRemember(int id, Map<String, dynamic> data) async {
    final db = await database;
    data['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      tableMustRemembers,
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除必记内容
  Future<int> deleteMustRemember(int id) async {
    final db = await database;
    return await db.delete(
      tableMustRemembers,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 根据ID查询必记内容
  Future<Map<String, dynamic>?> queryMustRememberById(int id) async {
    final db = await database;
    final results = await db.query(
      tableMustRemembers,
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 根据UUID查询必记内容
  Future<Map<String, dynamic>?> queryMustRememberByUuid(String uuid) async {
    final db = await database;
    final results = await db.query(
      tableMustRemembers,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 查询所有必记内容
  Future<List<Map<String, dynamic>>> queryAllMustRemembers({
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      tableMustRemembers,
      orderBy: orderBy ?? 'created_at DESC',
      limit: limit,
      offset: offset,
    );
  }

  /// 按科目查询必记内容
  Future<List<Map<String, dynamic>>> queryMustRemembersBySubject(
    String subject,
  ) async {
    final db = await database;
    return await db.query(
      tableMustRemembers,
      where: 'subject = ?',
      whereArgs: [subject],
      orderBy: 'created_at DESC',
    );
  }

  /// 查询待复习的必记内容
  Future<List<Map<String, dynamic>>> queryMustRemembersForReview() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return await db.query(
      tableMustRemembers,
      where: 'is_mastered = ? AND (next_review_time IS NULL OR next_review_time <= ?)',
      whereArgs: [0, now],
      orderBy: 'importance DESC, next_review_time ASC',
    );
  }

  /// 查询已掌握的必记内容
  Future<List<Map<String, dynamic>>> queryMasteredMustRemembers() async {
    final db = await database;
    return await db.query(
      tableMustRemembers,
      where: 'is_mastered = ?',
      whereArgs: [1],
      orderBy: 'updated_at DESC',
    );
  }

  /// 查询收藏的必记内容
  Future<List<Map<String, dynamic>>> queryFavoriteMustRemembers() async {
    final db = await database;
    return await db.query(
      tableMustRemembers,
      where: 'is_favorite = ?',
      whereArgs: [1],
      orderBy: 'updated_at DESC',
    );
  }

  /// 必记内容计数
  Future<int> countMustRemembers({String? subject, bool? mastered}) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (subject != null) {
      whereClause += 'subject = ?';
      whereArgs.add(subject);
    }
    if (mastered != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'is_mastered = ?';
      whereArgs.add(mastered ? 1 : 0);
    }

    if (whereClause.isNotEmpty) {
      final results = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableMustRemembers WHERE $whereClause',
        whereArgs,
      );
      return Sqflite.firstIntValue(results) ?? 0;
    }
    return Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) as count FROM $tableMustRemembers'),
    ) ?? 0;
  }

  // ==================== 错题 CRUD ====================

  /// 插入错题
  Future<int> insertWrongQuestion(Map<String, dynamic> data) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    data['created_at'] = now;
    data['updated_at'] = now;
    data['last_error_time'] = now;
    return await db.insert(tableWrongQuestions, data);
  }

  /// 更新错题
  Future<int> updateWrongQuestion(int id, Map<String, dynamic> data) async {
    final db = await database;
    data['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      tableWrongQuestions,
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除错题
  Future<int> deleteWrongQuestion(int id) async {
    final db = await database;
    return await db.delete(
      tableWrongQuestions,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 根据ID查询错题
  Future<Map<String, dynamic>?> queryWrongQuestionById(int id) async {
    final db = await database;
    final results = await db.query(
      tableWrongQuestions,
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 根据UUID查询错题
  Future<Map<String, dynamic>?> queryWrongQuestionByUuid(String uuid) async {
    final db = await database;
    final results = await db.query(
      tableWrongQuestions,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 查询所有错题
  Future<List<Map<String, dynamic>>> queryAllWrongQuestions({
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      tableWrongQuestions,
      orderBy: orderBy ?? 'created_at DESC',
      limit: limit,
      offset: offset,
    );
  }

  /// 按科目查询错题
  Future<List<Map<String, dynamic>>> queryWrongQuestionsBySubject(
    String subject,
  ) async {
    final db = await database;
    return await db.query(
      tableWrongQuestions,
      where: 'subject = ?',
      whereArgs: [subject],
      orderBy: 'created_at DESC',
    );
  }

  /// 查询未掌握的错题
  Future<List<Map<String, dynamic>>> queryUnmasteredWrongQuestions() async {
    final db = await database;
    return await db.query(
      tableWrongQuestions,
      where: 'is_mastered = ?',
      whereArgs: [0],
      orderBy: 'error_count DESC, last_error_time DESC',
    );
  }

  /// 查询已掌握的错题
  Future<List<Map<String, dynamic>>> queryMasteredWrongQuestions() async {
    final db = await database;
    return await db.query(
      tableWrongQuestions,
      where: 'is_mastered = ?',
      whereArgs: [1],
      orderBy: 'last_correct_time DESC',
    );
  }

  /// 按知识点查询错题
  Future<List<Map<String, dynamic>>> queryWrongQuestionsByKnowledgePoint(
    int knowledgePointId,
  ) async {
    final db = await database;
    return await db.query(
      tableWrongQuestions,
      where: 'knowledge_point_id = ?',
      whereArgs: [knowledgePointId],
      orderBy: 'created_at DESC',
    );
  }

  /// 错题计数
  Future<int> countWrongQuestions({String? subject, bool? mastered}) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (subject != null) {
      whereClause += 'subject = ?';
      whereArgs.add(subject);
    }
    if (mastered != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'is_mastered = ?';
      whereArgs.add(mastered ? 1 : 0);
    }

    if (whereClause.isNotEmpty) {
      final results = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableWrongQuestions WHERE $whereClause',
        whereArgs,
      );
      return Sqflite.firstIntValue(results) ?? 0;
    }
    return Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) as count FROM $tableWrongQuestions'),
    ) ?? 0;
  }

  // ==================== 母题 CRUD ====================

  /// 插入母题
  Future<int> insertMotherQuestion(Map<String, dynamic> data) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    data['created_at'] = now;
    data['updated_at'] = now;
    return await db.insert(tableMotherQuestions, data);
  }

  /// 更新母题
  Future<int> updateMotherQuestion(int id, Map<String, dynamic> data) async {
    final db = await database;
    data['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      tableMotherQuestions,
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除母题
  Future<int> deleteMotherQuestion(int id) async {
    final db = await database;
    return await db.delete(
      tableMotherQuestions,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 根据ID查询母题
  Future<Map<String, dynamic>?> queryMotherQuestionById(int id) async {
    final db = await database;
    final results = await db.query(
      tableMotherQuestions,
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 根据UUID查询母题
  Future<Map<String, dynamic>?> queryMotherQuestionByUuid(String uuid) async {
    final db = await database;
    final results = await db.query(
      tableMotherQuestions,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 查询所有母题
  Future<List<Map<String, dynamic>>> queryAllMotherQuestions({
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      tableMotherQuestions,
      orderBy: orderBy ?? 'created_at DESC',
      limit: limit,
      offset: offset,
    );
  }

  /// 按科目查询母题
  Future<List<Map<String, dynamic>>> queryMotherQuestionsBySubject(
    String subject,
  ) async {
    final db = await database;
    return await db.query(
      tableMotherQuestions,
      where: 'subject = ?',
      whereArgs: [subject],
      orderBy: 'created_at DESC',
    );
  }

  /// 按分类查询母题
  Future<List<Map<String, dynamic>>> queryMotherQuestionsByCategory(
    String category,
  ) async {
    final db = await database;
    return await db.query(
      tableMotherQuestions,
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'created_at DESC',
    );
  }

  /// 查询收藏的母题
  Future<List<Map<String, dynamic>>> queryFavoriteMotherQuestions() async {
    final db = await database;
    return await db.query(
      tableMotherQuestions,
      where: 'is_favorite = ?',
      whereArgs: [1],
      orderBy: 'updated_at DESC',
    );
  }

  /// 母题计数
  Future<int> countMotherQuestions({String? subject}) async {
    final db = await database;
    if (subject != null) {
      final results = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableMotherQuestions WHERE subject = ?',
        [subject],
      );
      return Sqflite.firstIntValue(results) ?? 0;
    }
    return Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) as count FROM $tableMotherQuestions'),
    ) ?? 0;
  }

  // ==================== 考试 CRUD ====================

  /// 插入考试
  Future<int> insertExam(Map<String, dynamic> data) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    data['created_at'] = now;
    data['updated_at'] = now;
    return await db.insert(tableExams, data);
  }

  /// 更新考试
  Future<int> updateExam(int id, Map<String, dynamic> data) async {
    final db = await database;
    data['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      tableExams,
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除考试
  Future<int> deleteExam(int id) async {
    final db = await database;
    return await db.delete(
      tableExams,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 根据ID查询考试
  Future<Map<String, dynamic>?> queryExamById(int id) async {
    final db = await database;
    final results = await db.query(
      tableExams,
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 根据UUID查询考试
  Future<Map<String, dynamic>?> queryExamByUuid(String uuid) async {
    final db = await database;
    final results = await db.query(
      tableExams,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 查询所有考试
  Future<List<Map<String, dynamic>>> queryAllExams({
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      tableExams,
      orderBy: orderBy ?? 'created_at DESC',
      limit: limit,
      offset: offset,
    );
  }

  /// 按科目查询考试
  Future<List<Map<String, dynamic>>> queryExamsBySubject(String subject) async {
    final db = await database;
    return await db.query(
      tableExams,
      where: 'subject = ?',
      whereArgs: [subject],
      orderBy: 'created_at DESC',
    );
  }

  /// 按类型查询考试
  Future<List<Map<String, dynamic>>> queryExamsByType(String examType) async {
    final db = await database;
    return await db.query(
      tableExams,
      where: 'exam_type = ?',
      whereArgs: [examType],
      orderBy: 'created_at DESC',
    );
  }

  /// 查询已完成的考试
  Future<List<Map<String, dynamic>>> queryCompletedExams() async {
    final db = await database;
    return await db.query(
      tableExams,
      where: 'is_completed = ?',
      whereArgs: [1],
      orderBy: 'updated_at DESC',
    );
  }

  /// 考试计数
  Future<int> countExams({String? subject, String? examType}) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (subject != null) {
      whereClause += 'subject = ?';
      whereArgs.add(subject);
    }
    if (examType != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'exam_type = ?';
      whereArgs.add(examType);
    }

    if (whereClause.isNotEmpty) {
      final results = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableExams WHERE $whereClause',
        whereArgs,
      );
      return Sqflite.firstIntValue(results) ?? 0;
    }
    return Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) as count FROM $tableExams'),
    ) ?? 0;
  }

  // ==================== 考试结果 CRUD ====================

  /// 插入考试结果
  Future<int> insertExamResult(Map<String, dynamic> data) async {
    final db = await database;
    data['created_at'] = DateTime.now().toIso8601String();
    return await db.insert(tableExamResults, data);
  }

  /// 更新考试结果
  Future<int> updateExamResult(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      tableExamResults,
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除考试结果
  Future<int> deleteExamResult(int id) async {
    final db = await database;
    return await db.delete(
      tableExamResults,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 根据ID查询考试结果
  Future<Map<String, dynamic>?> queryExamResultById(int id) async {
    final db = await database;
    final results = await db.query(
      tableExamResults,
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 根据UUID查询考试结果
  Future<Map<String, dynamic>?> queryExamResultByUuid(String uuid) async {
    final db = await database;
    final results = await db.query(
      tableExamResults,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 查询所有考试结果
  Future<List<Map<String, dynamic>>> queryAllExamResults({
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      tableExamResults,
      orderBy: orderBy ?? 'created_at DESC',
      limit: limit,
      offset: offset,
    );
  }

  /// 根据考试ID查询结果
  Future<List<Map<String, dynamic>>> queryExamResultsByExamId(
    int examId,
  ) async {
    final db = await database;
    return await db.query(
      tableExamResults,
      where: 'exam_id = ?',
      whereArgs: [examId],
      orderBy: 'created_at DESC',
    );
  }

  /// 按学科查询考试结果
  Future<List<Map<String, dynamic>>> queryExamResultsBySubject(
    String subject,
  ) async {
    final db = await database;
    return await db.query(
      tableExamResults,
      where: 'subject = ?',
      whereArgs: [subject],
      orderBy: 'created_at DESC',
    );
  }

  /// 查询通过的考试结果
  Future<List<Map<String, dynamic>>> queryPassedExamResults() async {
    final db = await database;
    return await db.query(
      tableExamResults,
      where: 'is_passed = ?',
      whereArgs: [1],
      orderBy: 'created_at DESC',
    );
  }

  /// 考试结果计数
  Future<int> countExamResults({int? examId, bool? passed}) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (examId != null) {
      whereClause += 'exam_id = ?';
      whereArgs.add(examId);
    }
    if (passed != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'is_passed = ?';
      whereArgs.add(passed ? 1 : 0);
    }

    if (whereClause.isNotEmpty) {
      final results = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableExamResults WHERE $whereClause',
        whereArgs,
      );
      return Sqflite.firstIntValue(results) ?? 0;
    }
    return Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) as count FROM $tableExamResults'),
    ) ?? 0;
  }

  /// 获取平均分
  Future<double> getAverageScore({int? examId}) async {
    final db = await database;
    if (examId != null) {
      final results = await db.rawQuery(
        'SELECT AVG(score) as avg_score FROM $tableExamResults WHERE exam_id = ?',
        [examId],
      );
      return (results.first['avg_score'] as num?)?.toDouble() ?? 0.0;
    }
    final results = await db.rawQuery(
      'SELECT AVG(score) as avg_score FROM $tableExamResults',
    );
    return (results.first['avg_score'] as num?)?.toDouble() ?? 0.0;
  }

  // ==================== 学习记录 CRUD ====================

  /// 插入学习记录
  Future<int> insertStudyRecord(Map<String, dynamic> data) async {
    final db = await database;
    data['created_at'] = DateTime.now().toIso8601String();
    return await db.insert(tableStudyRecords, data);
  }

  /// 更新学习记录
  Future<int> updateStudyRecord(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      tableStudyRecords,
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除学习记录
  Future<int> deleteStudyRecord(int id) async {
    final db = await database;
    return await db.delete(
      tableStudyRecords,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 根据ID查询学习记录
  Future<Map<String, dynamic>?> queryStudyRecordById(int id) async {
    final db = await database;
    final results = await db.query(
      tableStudyRecords,
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 根据UUID查询学习记录
  Future<Map<String, dynamic>?> queryStudyRecordByUuid(String uuid) async {
    final db = await database;
    final results = await db.query(
      tableStudyRecords,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 查询所有学习记录
  Future<List<Map<String, dynamic>>> queryAllStudyRecords({
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      tableStudyRecords,
      orderBy: orderBy ?? 'created_at DESC',
      limit: limit,
      offset: offset,
    );
  }

  /// 按类型查询学习记录
  Future<List<Map<String, dynamic>>> queryStudyRecordsByType(
    String recordType,
  ) async {
    final db = await database;
    return await db.query(
      tableStudyRecords,
      where: 'record_type = ?',
      whereArgs: [recordType],
      orderBy: 'created_at DESC',
    );
  }

  /// 按日期范围查询学习记录
  Future<List<Map<String, dynamic>>> queryStudyRecordsByDateRange(
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    return await db.query(
      tableStudyRecords,
      where: 'created_at >= ? AND created_at <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'created_at DESC',
    );
  }

  /// 按科目查询学习记录
  Future<List<Map<String, dynamic>>> queryStudyRecordsBySubject(
    String subject,
  ) async {
    final db = await database;
    return await db.query(
      tableStudyRecords,
      where: 'subject = ?',
      whereArgs: [subject],
      orderBy: 'created_at DESC',
    );
  }

  /// 学习记录计数
  Future<int> countStudyRecords({String? recordType, String? subject}) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (recordType != null) {
      whereClause += 'record_type = ?';
      whereArgs.add(recordType);
    }
    if (subject != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'subject = ?';
      whereArgs.add(subject);
    }

    if (whereClause.isNotEmpty) {
      final results = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableStudyRecords WHERE $whereClause',
        whereArgs,
      );
      return Sqflite.firstIntValue(results) ?? 0;
    }
    return Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) as count FROM $tableStudyRecords'),
    ) ?? 0;
  }

  /// 获取总学习时长（秒）
  Future<int> getTotalStudyTime({String? subject}) async {
    final db = await database;
    if (subject != null) {
      final results = await db.rawQuery(
        'SELECT COALESCE(SUM(duration), 0) as total FROM $tableStudyRecords WHERE subject = ?',
        [subject],
      );
      return (results.first['total'] as num?)?.toInt() ?? 0;
    }
    final results = await db.rawQuery(
      'SELECT COALESCE(SUM(duration), 0) as total FROM $tableStudyRecords',
    );
    return (results.first['total'] as num?)?.toInt() ?? 0;
  }

  // ==================== 用户资料 CRUD ====================

  /// 插入用户资料
  Future<int> insertUserProfile(Map<String, dynamic> data) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    data['created_at'] = now;
    data['updated_at'] = now;
    return await db.insert(tableUserProfiles, data);
  }

  /// 更新用户资料
  Future<int> updateUserProfile(int id, Map<String, dynamic> data) async {
    final db = await database;
    data['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      tableUserProfiles,
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除用户资料
  Future<int> deleteUserProfile(int id) async {
    final db = await database;
    return await db.delete(
      tableUserProfiles,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 根据ID查询用户资料
  Future<Map<String, dynamic>?> queryUserProfileById(int id) async {
    final db = await database;
    final results = await db.query(
      tableUserProfiles,
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 根据UUID查询用户资料
  Future<Map<String, dynamic>?> queryUserProfileByUuid(String uuid) async {
    final db = await database;
    final results = await db.query(
      tableUserProfiles,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 查询所有用户资料
  Future<List<Map<String, dynamic>>> queryAllUserProfiles() async {
    final db = await database;
    return await db.query(
      tableUserProfiles,
      orderBy: 'created_at DESC',
    );
  }

  /// 获取当前用户资料（第一条记录）
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final db = await database;
    final results = await db.query(
      tableUserProfiles,
      orderBy: 'created_at ASC',
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 用户资料计数
  Future<int> countUserProfiles() async {
    final db = await database;
    return Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) as count FROM $tableUserProfiles'),
    ) ?? 0;
  }

  // ==================== 思维导图 CRUD ====================

  /// 插入思维导图
  Future<int> insertMindMap(Map<String, dynamic> data) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    data['created_at'] = now;
    data['updated_at'] = now;
    return await db.insert(tableMindMapData, data);
  }

  /// 更新思维导图
  Future<int> updateMindMap(int id, Map<String, dynamic> data) async {
    final db = await database;
    data['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      tableMindMapData,
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除思维导图
  Future<int> deleteMindMap(int id) async {
    final db = await database;
    return await db.delete(
      tableMindMapData,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 根据ID查询思维导图
  Future<Map<String, dynamic>?> queryMindMapById(int id) async {
    final db = await database;
    final results = await db.query(
      tableMindMapData,
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 根据UUID查询思维导图
  Future<Map<String, dynamic>?> queryMindMapByUuid(String uuid) async {
    final db = await database;
    final results = await db.query(
      tableMindMapData,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 查询所有思维导图
  Future<List<Map<String, dynamic>>> queryAllMindMaps({
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      tableMindMapData,
      orderBy: orderBy ?? 'created_at DESC',
      limit: limit,
      offset: offset,
    );
  }

  /// 按科目查询思维导图
  Future<List<Map<String, dynamic>>> queryMindMapsBySubject(
    String subject,
  ) async {
    final db = await database;
    return await db.query(
      tableMindMapData,
      where: 'subject = ?',
      whereArgs: [subject],
      orderBy: 'created_at DESC',
    );
  }

  /// 查询收藏的思维导图
  Future<List<Map<String, dynamic>>> queryFavoriteMindMaps() async {
    final db = await database;
    return await db.query(
      tableMindMapData,
      where: 'is_favorite = ?',
      whereArgs: [1],
      orderBy: 'updated_at DESC',
    );
  }

  /// 按知识点查询思维导图
  Future<List<Map<String, dynamic>>> queryMindMapsByKnowledgePoint(
    int knowledgePointId,
  ) async {
    final db = await database;
    return await db.query(
      tableMindMapData,
      where: 'knowledge_point_id = ?',
      whereArgs: [knowledgePointId],
      orderBy: 'created_at DESC',
    );
  }

  /// 思维导图计数
  Future<int> countMindMaps({String? subject}) async {
    final db = await database;
    if (subject != null) {
      final results = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableMindMapData WHERE subject = ?',
        [subject],
      );
      return Sqflite.firstIntValue(results) ?? 0;
    }
    return Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) as count FROM $tableMindMapData'),
    ) ?? 0;
  }

  // ==================== 批量操作 ====================

  /// 批量插入
  Future<List<int>> batchInsert(String table, List<Map<String, dynamic>> dataList) async {
    final db = await database;
    final ids = <int>[];
    await db.transaction((txn) async {
      for (final data in dataList) {
        if (table == tableKnowledgePoints ||
            table == tableNotes ||
            table == tableMustRemembers ||
            table == tableWrongQuestions ||
            table == tableMotherQuestions ||
            table == tableExams) {
          data['created_at'] ??= DateTime.now().toIso8601String();
          data['updated_at'] ??= DateTime.now().toIso8601String();
        }
        if (table == tableStudyRecords || table == tableExamResults) {
          data['created_at'] ??= DateTime.now().toIso8601String();
        }
        if (table == tableUserProfiles) {
          data['created_at'] ??= DateTime.now().toIso8601String();
          data['updated_at'] ??= DateTime.now().toIso8601String();
        }
        if (table == tableMindMapData) {
          data['created_at'] ??= DateTime.now().toIso8601String();
          data['updated_at'] ??= DateTime.now().toIso8601String();
        }
        final id = await txn.insert(table, data);
        ids.add(id);
      }
    });
    return ids;
  }

  /// 批量删除
  Future<int> batchDelete(String table, List<int> ids) async {
    final db = await database;
    int count = 0;
    await db.transaction((txn) async {
      for (final id in ids) {
        count += await txn.delete(table, where: 'id = ?', whereArgs: [id]);
      }
    });
    return count;
  }

  /// 批量更新
  Future<int> batchUpdate(
    String table,
    List<int> ids,
    Map<String, dynamic> data,
  ) async {
    final db = await database;
    int count = 0;
    await db.transaction((txn) async {
      for (final id in ids) {
        count += await txn.update(table, data, where: 'id = ?', whereArgs: [id]);
      }
    });
    return count;
  }

  /// 批量按条件删除
  Future<int> batchDeleteByCondition(
    String table,
    String whereClause,
    List<dynamic> whereArgs,
  ) async {
    final db = await database;
    return await db.delete(table, where: whereClause, whereArgs: whereArgs);
  }

  /// 批量按条件更新
  Future<int> batchUpdateByCondition(
    String table,
    Map<String, dynamic> data,
    String whereClause,
    List<dynamic> whereArgs,
  ) async {
    final db = await database;
    return await db.update(table, data, where: whereClause, whereArgs: whereArgs);
  }

  // ==================== 搜索方法 ====================

  /// 按关键词搜索（跨表搜索）
  Future<Map<String, List<Map<String, dynamic>>>> searchByKeyword(
    String keyword,
  ) async {
    final db = await database;
    final likePattern = '%$keyword%';
    final results = <String, List<Map<String, dynamic>>>{};

    // 搜索知识点
    results[tableKnowledgePoints] = await db.query(
      tableKnowledgePoints,
      where: 'title LIKE ? OR content LIKE ? OR tags LIKE ?',
      whereArgs: [likePattern, likePattern, likePattern],
      orderBy: 'updated_at DESC',
    );

    // 搜索笔记
    results[tableNotes] = await db.query(
      tableNotes,
      where: 'title LIKE ? OR content LIKE ? OR tags LIKE ?',
      whereArgs: [likePattern, likePattern, likePattern],
      orderBy: 'updated_at DESC',
    );

    // 搜索必记内容
    results[tableMustRemembers] = await db.query(
      tableMustRemembers,
      where: 'title LIKE ? OR content LIKE ? OR tags LIKE ?',
      whereArgs: [likePattern, likePattern, likePattern],
      orderBy: 'updated_at DESC',
    );

    // 搜索错题
    results[tableWrongQuestions] = await db.query(
      tableWrongQuestions,
      where: 'question_content LIKE ? OR analysis LIKE ?',
      whereArgs: [likePattern, likePattern],
      orderBy: 'updated_at DESC',
    );

    // 搜索母题
    results[tableMotherQuestions] = await db.query(
      tableMotherQuestions,
      where: 'title LIKE ? OR question_content LIKE ? OR analysis LIKE ? OR tags LIKE ?',
      whereArgs: [likePattern, likePattern, likePattern, likePattern],
      orderBy: 'updated_at DESC',
    );

    return results;
  }

  /// 按关键词搜索指定表
  Future<List<Map<String, dynamic>>> searchTableByKeyword(
    String table,
    String keyword, {
    List<String> searchFields = const [],
  }) async {
    final db = await database;

    // 根据表名确定默认搜索字段
    List<String> fields = searchFields.isNotEmpty
        ? searchFields
        : _getDefaultSearchFields(table);

    if (fields.isEmpty) return [];

    final whereParts = <String>[];
    final whereArgs = <dynamic>[];
    final likePattern = '%$keyword%';

    for (final field in fields) {
      whereParts.add('$field LIKE ?');
      whereArgs.add(likePattern);
    }

    return await db.query(
      table,
      where: whereParts.join(' OR '),
      whereArgs: whereArgs,
      orderBy: 'updated_at DESC',
    );
  }

  /// 按科目搜索（跨表搜索）
  Future<Map<String, List<Map<String, dynamic>>>> searchBySubject(
    String subject,
  ) async {
    final results = <String, List<Map<String, dynamic>>>{};

    results[tableKnowledgePoints] =
        await queryKnowledgePointsBySubject(subject);
    results[tableNotes] = await queryNotesBySubject(subject);
    results[tableMustRemembers] =
        await queryMustRemembersBySubject(subject);
    results[tableWrongQuestions] =
        await queryWrongQuestionsBySubject(subject);
    results[tableMotherQuestions] =
        await queryMotherQuestionsBySubject(subject);
    results[tableExams] = await queryExamsBySubject(subject);
    results[tableStudyRecords] = await queryStudyRecordsBySubject(subject);
    results[tableMindMapData] = await queryMindMapsBySubject(subject);

    return results;
  }

  /// 获取表的默认搜索字段
  List<String> _getDefaultSearchFields(String table) {
    switch (table) {
      case tableKnowledgePoints:
        return ['title', 'content', 'tags'];
      case tableNotes:
        return ['title', 'content', 'tags'];
      case tableMustRemembers:
        return ['title', 'content', 'tags'];
      case tableWrongQuestions:
        return ['question_content', 'analysis'];
      case tableMotherQuestions:
        return ['title', 'question_content', 'analysis', 'tags'];
      case tableExams:
        return ['title', 'description'];
      case tableStudyRecords:
        return ['title', 'description'];
      case tableMindMapData:
        return ['title'];
      default:
        return [];
    }
  }

  // ==================== 数据导入导出 ====================

  /// 导出所有数据为JSON
  Future<Map<String, dynamic>> exportAllToJson() async {
    final db = await database;
    final exportData = <String, dynamic>{
      'export_version': _databaseVersion,
      'export_time': DateTime.now().toIso8601String(),
      'app_version': '1.0.0',
    };

    // 导出所有表数据
    exportData[tableKnowledgePoints] =
        await db.query(tableKnowledgePoints);
    exportData[tableNotes] = await db.query(tableNotes);
    exportData[tableMustRemembers] = await db.query(tableMustRemembers);
    exportData[tableWrongQuestions] =
        await db.query(tableWrongQuestions);
    exportData[tableMotherQuestions] =
        await db.query(tableMotherQuestions);
    exportData[tableExams] = await db.query(tableExams);
    exportData[tableExamResults] = await db.query(tableExamResults);
    exportData[tableStudyRecords] = await db.query(tableStudyRecords);
    exportData[tableUserProfiles] = await db.query(tableUserProfiles);
    exportData[tableMindMapData] = await db.query(tableMindMapData);

    return exportData;
  }

  /// 按模块选择性导出为JSON
  Future<Map<String, dynamic>> exportModulesToJson(
    List<String> modules,
  ) async {
    final db = await database;
    final exportData = <String, dynamic>{
      'export_version': _databaseVersion,
      'export_time': DateTime.now().toIso8601String(),
      'app_version': '1.0.0',
      'modules': modules,
    };

    for (final module in modules) {
      if (_isValidTable(module)) {
        exportData[module] = await db.query(module);
      }
    }

    return exportData;
  }

  /// 从JSON导入数据
  Future<Map<String, int>> importFromJson(Map<String, dynamic> jsonData) async {
    final db = await database;
    final importStats = <String, int>{};

    await db.transaction((txn) async {
      final tables = [
        tableKnowledgePoints,
        tableNotes,
        tableMustRemembers,
        tableWrongQuestions,
        tableMotherQuestions,
        tableExams,
        tableExamResults,
        tableStudyRecords,
        tableUserProfiles,
        tableMindMapData,
      ];

      for (final table in tables) {
        if (jsonData.containsKey(table)) {
          final data = jsonData[table] as List;
          int count = 0;
          for (final item in data) {
            try {
              final map = Map<String, dynamic>.from(item as Map);
              // 移除自增ID，让数据库自动生成
              map.remove('id');
              await txn.insert(table, map,
                  conflictAlgorithm: ConflictAlgorithm.replace);
              count++;
            } catch (e) {
              // 跳过导入失败的记录
            }
          }
          importStats[table] = count;
        }
      }
    });

    return importStats;
  }

  /// 从JSON恢复数据（先清空再导入）
  Future<Map<String, int>> restoreFromJson(Map<String, dynamic> jsonData) async {
    final db = await database;
    final restoreStats = <String, int>{};

    await db.transaction((txn) async {
      final tables = [
        tableKnowledgePoints,
        tableNotes,
        tableMustRemembers,
        tableWrongQuestions,
        tableMotherQuestions,
        tableExams,
        tableExamResults,
        tableStudyRecords,
        tableUserProfiles,
        tableMindMapData,
      ];

      // 先清空所有表
      for (final table in tables) {
        await txn.delete(table);
      }

      // 再导入数据
      for (final table in tables) {
        if (jsonData.containsKey(table)) {
          final data = jsonData[table] as List;
          int count = 0;
          for (final item in data) {
            try {
              final map = Map<String, dynamic>.from(item as Map);
              map.remove('id');
              await txn.insert(table, map);
              count++;
            } catch (e) {
              // 跳过导入失败的记录
            }
          }
          restoreStats[table] = count;
        }
      }
    });

    return restoreStats;
  }

  /// 将导出数据转为JSON字符串
  Future<String> exportAllToJsonString() async {
    final data = await exportAllToJson();
    return jsonEncode(data);
  }

  /// 从JSON字符串导入数据
  Future<Map<String, int>> importFromJsonString(String jsonString) async {
    final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
    return await importFromJson(jsonData);
  }

  /// 验证表名是否有效
  bool _isValidTable(String tableName) {
    const validTables = [
      tableKnowledgePoints,
      tableNotes,
      tableMustRemembers,
      tableWrongQuestions,
      tableMotherQuestions,
      tableExams,
      tableExamResults,
      tableStudyRecords,
      tableUserProfiles,
      tableMindMapData,
    ];
    return validTables.contains(tableName);
  }

  // ==================== 统计方法 ====================

  /// 获取数据库总大小（估算，返回记录数）
  Future<Map<String, int>> getDatabaseStats() async {
    return {
      tableKnowledgePoints: await countKnowledgePoints(),
      tableNotes: await countNotes(),
      tableMustRemembers: await countMustRemembers(),
      tableWrongQuestions: await countWrongQuestions(),
      tableMotherQuestions: await countMotherQuestions(),
      tableExams: await countExams(),
      tableExamResults: await countExamResults(),
      tableStudyRecords: await countStudyRecords(),
      tableUserProfiles: await countUserProfiles(),
      tableMindMapData: await countMindMaps(),
    };
  }

  /// 清空所有数据
  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(tableKnowledgePoints);
      await txn.delete(tableNotes);
      await txn.delete(tableMustRemembers);
      await txn.delete(tableWrongQuestions);
      await txn.delete(tableMotherQuestions);
      await txn.delete(tableExams);
      await txn.delete(tableExamResults);
      await txn.delete(tableStudyRecords);
      await txn.delete(tableUserProfiles);
      await txn.delete(tableMindMapData);
    });
  }

  /// 清空指定表数据
  Future<int> clearTable(String table) async {
    if (!_isValidTable(table)) return 0;
    final db = await database;
    return await db.delete(table);
  }

  /// 执行自定义SQL查询
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? arguments,
  ]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }

  /// 执行自定义SQL命令
  Future<void> rawExecute(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    await db.execute(sql, arguments);
  }

  // ==================== 习惯 CRUD ====================

  /// 插入习惯
  Future<int> insertHabit(Map<String, dynamic> data) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    data['created_at'] = now;
    return await db.insert(tableHabits, data);
  }

  /// 更新习惯
  Future<int> updateHabit(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      tableHabits,
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除习惯
  Future<int> deleteHabit(int id) async {
    final db = await database;
    return await db.delete(
      tableHabits,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 根据ID查询习惯
  Future<Map<String, dynamic>?> queryHabitById(int id) async {
    final db = await database;
    final results = await db.query(
      tableHabits,
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 根据UUID查询习惯
  Future<Map<String, dynamic>?> queryHabitByUuid(String uuid) async {
    final db = await database;
    final results = await db.query(
      tableHabits,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 查询所有习惯
  Future<List<Map<String, dynamic>>> queryAllHabits({
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      tableHabits,
      orderBy: orderBy ?? 'created_at DESC',
      limit: limit,
      offset: offset,
    );
  }

  /// 查询进行中的习惯
  Future<List<Map<String, dynamic>>> queryActiveHabits() async {
    final db = await database;
    return await db.query(
      tableHabits,
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'created_at DESC',
    );
  }

  /// 查询已完成的习惯
  Future<List<Map<String, dynamic>>> queryCompletedHabits() async {
    final db = await database;
    return await db.query(
      tableHabits,
      where: 'is_active = ? AND total_completed_days >= target_days',
      whereArgs: [1],
      orderBy: 'completed_at DESC',
    );
  }

  /// 习惯计数
  Future<int> countHabits({bool? active}) async {
    final db = await database;
    if (active != null) {
      final results = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableHabits WHERE is_active = ?',
        [active ? 1 : 0],
      );
      return Sqflite.firstIntValue(results) ?? 0;
    }
    return Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) as count FROM $tableHabits'),
    ) ?? 0;
  }

  // ==================== 习惯打卡记录 CRUD ====================

  /// 插入打卡记录
  Future<int> insertHabitCheckIn(Map<String, dynamic> data) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    data['created_at'] = now;
    return await db.insert(tableHabitCheckIns, data);
  }

  /// 更新打卡记录
  Future<int> updateHabitCheckIn(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      tableHabitCheckIns,
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除打卡记录
  Future<int> deleteHabitCheckIn(int id) async {
    final db = await database;
    return await db.delete(
      tableHabitCheckIns,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 根据ID查询打卡记录
  Future<Map<String, dynamic>?> queryHabitCheckInById(int id) async {
    final db = await database;
    final results = await db.query(
      tableHabitCheckIns,
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 根据UUID查询打卡记录
  Future<Map<String, dynamic>?> queryHabitCheckInByUuid(String uuid) async {
    final db = await database;
    final results = await db.query(
      tableHabitCheckIns,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 查询习惯的所有打卡记录
  Future<List<Map<String, dynamic>>> queryHabitCheckInsByHabitUuid(
    String habitUuid, {
    String? orderBy,
  }) async {
    final db = await database;
    return await db.query(
      tableHabitCheckIns,
      where: 'habit_uuid = ?',
      whereArgs: [habitUuid],
      orderBy: orderBy ?? 'check_in_time DESC',
    );
  }

  /// 查询今日打卡记录
  Future<List<Map<String, dynamic>>> queryTodayCheckIns() async {
    final db = await database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    return await db.query(
      tableHabitCheckIns,
      where: 'check_in_time >= ? AND check_in_time < ?',
      whereArgs: [today.toIso8601String(), tomorrow.toIso8601String()],
      orderBy: 'check_in_time DESC',
    );
  }

  /// 查询某习惯的今日打卡记录
  Future<Map<String, dynamic>?> queryTodayCheckInByHabit(String habitUuid) async {
    final db = await database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final results = await db.query(
      tableHabitCheckIns,
      where: 'habit_uuid = ? AND check_in_time >= ? AND check_in_time < ?',
      whereArgs: [habitUuid, today.toIso8601String(), tomorrow.toIso8601String()],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 查询某日期范围内的打卡记录
  Future<List<Map<String, dynamic>>> queryCheckInsByDateRange(
    String habitUuid,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    return await db.query(
      tableHabitCheckIns,
      where: 'habit_uuid = ? AND check_in_time >= ? AND check_in_time <= ?',
      whereArgs: [
        habitUuid,
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ],
      orderBy: 'check_in_time DESC',
    );
  }

  /// 打卡记录计数
  Future<int> countHabitCheckIns(String habitUuid) async {
    final db = await database;
    final results = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableHabitCheckIns WHERE habit_uuid = ?',
      [habitUuid],
    );
    return Sqflite.firstIntValue(results) ?? 0;
  }

  /// 删除习惯的所有打卡记录
  Future<int> deleteHabitCheckInsByHabitUuid(String habitUuid) async {
    final db = await database;
    return await db.delete(
      tableHabitCheckIns,
      where: 'habit_uuid = ?',
      whereArgs: [habitUuid],
    );
  }

  // ==================== 试卷 CRUD ====================

  /// 插入试卷
  Future<int> insertExamPaper(Map<String, dynamic> data) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    data['created_at'] = now;
    data['updated_at'] = now;
    return await db.insert(tableExamPapers, data);
  }

  /// 更新试卷
  Future<int> updateExamPaper(int id, Map<String, dynamic> data) async {
    final db = await database;
    data['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    return await db.update(
      tableExamPapers,
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除试卷
  Future<int> deleteExamPaper(int id) async {
    final db = await database;
    return await db.delete(
      tableExamPapers,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 根据ID查询试卷
  Future<Map<String, dynamic>?> queryExamPaperById(int id) async {
    final db = await database;
    final results = await db.query(
      tableExamPapers,
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 根据UUID查询试卷
  Future<Map<String, dynamic>?> queryExamPaperByUuid(String uuid) async {
    final db = await database;
    final results = await db.query(
      tableExamPapers,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 查询所有试卷
  Future<List<Map<String, dynamic>>> queryAllExamPapers({
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      tableExamPapers,
      orderBy: orderBy ?? 'exam_date DESC',
      limit: limit,
      offset: offset,
    );
  }

  /// 按科目查询试卷
  Future<List<Map<String, dynamic>>> queryExamPapersBySubject(
    String subject,
  ) async {
    final db = await database;
    return await db.query(
      tableExamPapers,
      where: 'subject = ?',
      whereArgs: [subject],
      orderBy: 'exam_date DESC',
    );
  }

  /// 按来源查询试卷
  Future<List<Map<String, dynamic>>> queryExamPapersBySource(
    String source,
  ) async {
    final db = await database;
    return await db.query(
      tableExamPapers,
      where: 'source = ?',
      whereArgs: [source],
      orderBy: 'exam_date DESC',
    );
  }

  /// 按日期范围查询试卷
  Future<List<Map<String, dynamic>>> queryExamPapersByDateRange(
    int startDate,
    int endDate,
  ) async {
    final db = await database;
    return await db.query(
      tableExamPapers,
      where: 'exam_date >= ? AND exam_date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'exam_date DESC',
    );
  }

  /// 试卷计数
  Future<int> countExamPapers({String? subject, String? source}) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (subject != null) {
      whereClause += 'subject = ?';
      whereArgs.add(subject);
    }
    if (source != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'source = ?';
      whereArgs.add(source);
    }

    if (whereClause.isNotEmpty) {
      final results = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableExamPapers WHERE $whereClause',
        whereArgs,
      );
      return Sqflite.firstIntValue(results) ?? 0;
    }
    return Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) as count FROM $tableExamPapers'),
    ) ?? 0;
  }

  /// 获取试卷平均分
  Future<double> getExamPaperAverageScore({String? subject}) async {
    final db = await database;
    if (subject != null) {
      final results = await db.rawQuery(
        'SELECT AVG(CAST(obtained_score AS REAL) / total_score * 100) as avg_score '
        'FROM $tableExamPapers WHERE subject = ? AND obtained_score IS NOT NULL',
        [subject],
      );
      return (results.first['avg_score'] as num?)?.toDouble() ?? 0.0;
    }
    final results = await db.rawQuery(
      'SELECT AVG(CAST(obtained_score AS REAL) / total_score * 100) as avg_score '
      'FROM $tableExamPapers WHERE obtained_score IS NOT NULL',
    );
    return (results.first['avg_score'] as num?)?.toDouble() ?? 0.0;
  }

  // ==================== APP使用记录 CRUD ====================

  /// 插入使用记录
  Future<int> insertUsageRecord(Map<String, dynamic> data) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    data['created_at'] = now;
    return await db.insert(tableUsageRecords, data);
  }

  /// 更新使用记录
  Future<int> updateUsageRecord(String uuid, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      tableUsageRecords,
      data,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  /// 删除使用记录
  Future<int> deleteUsageRecord(int id) async {
    final db = await database;
    return await db.delete(
      tableUsageRecords,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 根据ID查询使用记录
  Future<Map<String, dynamic>?> queryUsageRecordById(String uuid) async {
    final db = await database;
    final results = await db.query(
      tableUsageRecords,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 查询所有使用记录
  Future<List<Map<String, dynamic>>> queryAllUsageRecords({
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      tableUsageRecords,
      orderBy: orderBy ?? 'start_time DESC',
      limit: limit,
      offset: offset,
    );
  }

  /// 按日期查询使用记录
  Future<List<Map<String, dynamic>>> queryUsageRecordsByDate(String date) async {
    final db = await database;
    return await db.query(
      tableUsageRecords,
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'start_time DESC',
    );
  }

  /// 按日期范围查询使用记录
  Future<List<Map<String, dynamic>>> queryUsageRecordsByDateRange(
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    return await db.query(
      tableUsageRecords,
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date ASC, start_time ASC',
    );
  }

  /// 获取指定日期的总使用时长（秒）
  Future<int> getTotalUsageTimeByDate(String date) async {
    final db = await database;
    final results = await db.rawQuery(
      'SELECT SUM(duration) as total FROM $tableUsageRecords WHERE date = ? AND duration IS NOT NULL',
      [date],
    );
    return (results.first['total'] as num?)?.toInt() ?? 0;
  }

  /// 获取指定日期范围的总使用时长（秒）
  Future<int> getTotalUsageTimeByDateRange(String startDate, String endDate) async {
    final db = await database;
    final results = await db.rawQuery(
      'SELECT SUM(duration) as total FROM $tableUsageRecords WHERE date >= ? AND date <= ? AND duration IS NOT NULL',
      [startDate, endDate],
    );
    return (results.first['total'] as num?)?.toInt() ?? 0;
  }

  /// 获取使用记录数量
  Future<int> countUsageRecords() async {
    final db = await database;
    return Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) as count FROM $tableUsageRecords'),
    ) ?? 0;
  }

  /// 删除指定日期之前的使用记录（用于清理旧数据）
  Future<int> deleteUsageRecordsBeforeDate(String date) async {
    final db = await database;
    return await db.delete(
      tableUsageRecords,
      where: 'date < ?',
      whereArgs: [date],
    );
  }
}
