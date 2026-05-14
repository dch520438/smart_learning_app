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
  static const int _databaseVersion = 7;

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
  static const String tableAttachments = 'attachments';

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
        chapter TEXT,
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
        chapter TEXT,
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
        chapter TEXT,
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
        chapter TEXT,
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
        chapter TEXT,
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

    // 附件表（图片附件）
    await db.execute('''
      CREATE TABLE $tableAttachments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        parent_id TEXT NOT NULL,
        parent_type TEXT NOT NULL,
        file_path TEXT NOT NULL,
        file_name TEXT,
        file_size INTEGER,
        created_at TEXT NOT NULL
      )
    ''');

    // 创建索引
    await _createIndexes(db);
    
    // 插入测试数据
    await _insertTestData(db);
  }

  /// 插入测试数据
  Future<void> _insertTestData(Database db) async {
    final now = DateTime.now();
    final nowStr = now.toIso8601String();
    
    // 测试知识点数据
    final testKnowledgePoints = [
      {
        'uuid': 'kp_test_1',
        'title': '一元二次方程的解法',
        'content': '一元二次方程的一般形式为 ax² + bx + c = 0 (a≠0)。解法包括：1. 因式分解法；2. 配方法；3. 公式法：x = (-b ± √(b²-4ac)) / 2a；4. 图像法。当判别式 Δ = b²-4ac > 0 时有两个不等实根，Δ = 0 时有两个相等实根，Δ < 0 时无实根。',
        'subject': '数学',
        'chapter': '方程与不等式',
        'difficulty': 2,
        'mastery_level': 75,
        'created_at': nowStr,
        'updated_at': nowStr,
      },
      {
        'uuid': 'kp_test_2',
        'title': '牛顿第二定律',
        'content': '牛顿第二定律：F = ma。物体的加速度与作用力成正比，与质量成反比。加速度的方向与作用力的方向相同。适用条件：1. 惯性参考系；2. 宏观低速物体；3. 质点模型。',
        'subject': '物理',
        'chapter': '力学',
        'difficulty': 2,
        'mastery_level': 60,
        'created_at': nowStr,
        'updated_at': nowStr,
      },
      {
        'uuid': 'kp_test_3',
        'title': '氧化还原反应',
        'content': '氧化还原反应的本质是电子的转移。氧化剂得到电子被还原，还原剂失去电子被氧化。氧化还原反应的特征是元素化合价发生变化。常用口诀：升失氧，降得还。',
        'subject': '化学',
        'chapter': '化学反应原理',
        'difficulty': 2,
        'mastery_level': 50,
        'created_at': nowStr,
        'updated_at': nowStr,
      },
      {
        'uuid': 'kp_test_4',
        'title': '古诗词鉴赏方法',
        'content': '古诗词鉴赏步骤：1. 知人论世，了解作者和时代背景；2. 分析意象，把握诗歌意境；3. 品味语言，体会修辞手法；4. 理解情感，把握主旨。常见意象：月亮（思乡）、柳树（离别）、菊花（隐逸）、梅花（高洁）。',
        'subject': '语文',
        'chapter': '古诗词',
        'difficulty': 2,
        'mastery_level': 80,
        'created_at': nowStr,
        'updated_at': nowStr,
      },
      {
        'uuid': 'kp_test_5',
        'title': '英语定语从句',
        'content': '定语从句是由关系词引导的修饰名词或代词的从句。关系代词：who（人，主格）、whom（人，宾格）、whose（人/物，所有格）、which（物）、that（人/物）。关系副词：when（时间）、where（地点）、why（原因）。',
        'subject': '英语',
        'chapter': '语法',
        'difficulty': 2,
        'mastery_level': 65,
        'created_at': nowStr,
        'updated_at': nowStr,
      },
    ];
    
    for (final kp in testKnowledgePoints) {
      await db.insert(tableKnowledgePoints, kp);
    }
    
    // 测试错题数据
    final testWrongQuestions = [
      {
        'uuid': 'wq_test_1',
        'title': '一元二次方程求解错误',
        'question_content': '解方程 x² - 5x + 6 = 0',
        'question_type': 'singleChoice',
        'options': '[{"label":"A","content":"x=2或x=3"},{"label":"B","content":"x=1或x=6"},{"label":"C","content":"x=-2或x=-3"},{"label":"D","content":"x=2或x=-3"}]',
        'correct_answer': 'A',
        'my_answer': 'B',
        'analysis': '使用因式分解法：x² - 5x + 6 = (x-2)(x-3) = 0，所以 x=2 或 x=3。答案选A。',
        'subject': '数学',
        'chapter': '方程与不等式',
        'error_type': 'method_error',
        'knowledge_point': '一元二次方程的解法',
        'difficulty': 2,
        'error_count': 2,
        'is_mastered': 0,
        'created_at': nowStr,
        'updated_at': nowStr,
      },
      {
        'uuid': 'wq_test_2',
        'title': '牛顿运动定律应用',
        'question_content': '一个质量为2kg的物体，受到10N的水平推力作用，在光滑水平面上运动，求物体的加速度。',
        'question_type': 'shortAnswer',
        'correct_answer': 'a = F/m = 10/2 = 5 m/s²',
        'my_answer': 'a = F/m = 10/2 = 10 m/s²',
        'analysis': '根据牛顿第二定律 F = ma，所以 a = F/m = 10/2 = 5 m/s²。计算时注意单位。',
        'subject': '物理',
        'chapter': '力学',
        'error_type': 'careless',
        'knowledge_point': '牛顿第二定律',
        'difficulty': 2,
        'error_count': 1,
        'is_mastered': 0,
        'created_at': nowStr,
        'updated_at': nowStr,
      },
      {
        'uuid': 'wq_test_3',
        'title': '氧化还原反应判断',
        'question_content': '下列反应中，属于氧化还原反应的是？',
        'question_type': 'singleChoice',
        'options': '[{"label":"A","content":"CaCO3 = CaO + CO2"},{"label":"B","content":"2Na + Cl2 = 2NaCl"},{"label":"C","content":"CaO + H2O = Ca(OH)2"},{"label":"D","content":"Na2CO3 + 2HCl = 2NaCl + H2O + CO2"}]',
        'correct_answer': 'B',
        'my_answer': 'D',
        'analysis': '氧化还原反应的特征是元素化合价发生变化。B选项中Na从0价变为+1价，Cl从0价变为-1价，发生了电子转移，是氧化还原反应。',
        'subject': '化学',
        'chapter': '化学反应原理',
        'error_type': 'knowledge_gap',
        'knowledge_point': '氧化还原反应',
        'difficulty': 3,
        'error_count': 1,
        'is_mastered': 0,
        'created_at': nowStr,
        'updated_at': nowStr,
      },
    ];
    
    for (final wq in testWrongQuestions) {
      await db.insert(tableWrongQuestions, wq);
    }
    
    // 测试母题数据
    final testMotherQuestions = [
      {
        'uuid': 'mq_test_1',
        'title': '一元二次方程根与系数的关系',
        'question_content': '已知一元二次方程 ax² + bx + c = 0 (a≠0) 的两根为 x₁, x₂，求证：x₁ + x₂ = -b/a，x₁ · x₂ = c/a',
        'question_type': 'proof',
        'correct_answer': '证明：设方程两根为 x₁, x₂，则 ax² + bx + c = a(x - x₁)(x - x₂) = ax² - a(x₁+x₂)x + ax₁x₂，比较系数得 x₁ + x₂ = -b/a，x₁ · x₂ = c/a',
        'analysis': '这是韦达定理的证明，关键是将一元二次方程写成两根式，然后比较系数。韦达定理是解决一元二次方程问题的重要工具。',
        'subject': '数学',
        'chapter': '方程与不等式',
        'difficulty': 2,
        'variant_count': 3,
        'mastery_level': 70,
        'created_at': nowStr,
        'updated_at': nowStr,
      },
      {
        'uuid': 'mq_test_2',
        'title': '牛顿第二定律的应用',
        'question_content': '质量为m的物体在倾角为θ的光滑斜面上由静止开始下滑，求物体下滑的加速度和滑到底端的时间。',
        'question_type': 'calculation',
        'correct_answer': '加速度 a = g·sinθ，时间 t = √(2L/(g·sinθ))，其中L为斜面长度',
        'analysis': '对物体进行受力分析：重力mg竖直向下，支持力N垂直斜面向上。将重力分解为沿斜面方向和垂直斜面方向的分力，沿斜面方向：mg·sinθ = ma，所以 a = g·sinθ。',
        'subject': '物理',
        'chapter': '力学',
        'difficulty': 2,
        'variant_count': 2,
        'mastery_level': 60,
        'created_at': nowStr,
        'updated_at': nowStr,
      },
    ];
    
    for (final mq in testMotherQuestions) {
      await db.insert(tableMotherQuestions, mq);
    }
    
    // 测试必记必背数据
    final testMustRemembers = [
      {
        'uuid': 'mr_test_1',
        'title': '勾股定理',
        'content': '直角三角形两直角边的平方和等于斜边的平方。即：a² + b² = c²（a、b为直角边，c为斜边）。常用勾股数：3-4-5、5-12-13、8-15-17、7-24-25。',
        'subject': '数学',
        'chapter': '几何',
        'category': '定理',
        'importance': 3,
        'memory_level': 80,
        'review_count': 3,
        'is_mastered': 0,
        'created_at': nowStr,
        'updated_at': nowStr,
      },
      {
        'uuid': 'mr_test_2',
        'title': '牛顿三定律',
        'content': '第一定律（惯性定律）：物体保持静止或匀速直线运动状态，直到有外力迫使它改变这种状态。第二定律：F = ma。第三定律：作用力与反作用力大小相等、方向相反、作用在同一直线上。',
        'subject': '物理',
        'chapter': '力学',
        'category': '定律',
        'importance': 3,
        'memory_level': 70,
        'review_count': 2,
        'is_mastered': 0,
        'created_at': nowStr,
        'updated_at': nowStr,
      },
      {
        'uuid': 'mr_test_3',
        'title': '元素周期表前20号元素',
        'content': 'H氢、He氦、Li锂、Be铍、B硼、C碳、N氮、O氧、F氟、Ne氖、Na钠、Mg镁、Al铝、Si硅、P磷、S硫、Cl氯、Ar氩、K钾、Ca钙。口诀：氢氦锂铍硼，碳氮氧氟氖，钠镁铝硅磷，硫氯氩钾钙。',
        'subject': '化学',
        'chapter': '原子结构',
        'category': '基础知识',
        'importance': 3,
        'memory_level': 90,
        'review_count': 5,
        'is_mastered': 1,
        'created_at': nowStr,
        'updated_at': nowStr,
      },
      {
        'uuid': 'mr_test_4',
        'title': '《静夜思》- 李白',
        'content': '床前明月光，疑是地上霜。举头望明月，低头思故乡。',
        'subject': '语文',
        'chapter': '古诗词',
        'category': '古诗词',
        'importance': 2,
        'memory_level': 100,
        'review_count': 10,
        'is_mastered': 1,
        'created_at': nowStr,
        'updated_at': nowStr,
      },
      {
        'uuid': 'mr_test_5',
        'title': '常用英语不规则动词表',
        'content': 'go - went - gone（去）；do - did - done（做）；see - saw - seen（看见）；take - took - taken（拿）；give - gave - given（给）；write - wrote - written（写）；speak - spoke - spoken（说）',
        'subject': '英语',
        'chapter': '语法',
        'category': '词汇',
        'importance': 3,
        'memory_level': 60,
        'review_count': 2,
        'is_mastered': 0,
        'created_at': nowStr,
        'updated_at': nowStr,
      },
    ];
    
    for (final mr in testMustRemembers) {
      await db.insert(tableMustRemembers, mr);
    }
    
    // 测试笔记数据
    final testNotes = [
      {
        'uuid': 'note_test_1',
        'title': '数学错题总结',
        'content': '本周数学错题主要集中在：1. 一元二次方程求根公式的应用；2. 函数图像的识别；3. 几何证明题的辅助线添加。需要重点复习这些内容。',
        'subject': '数学',
        'note_type': 'text',
        'is_favorite': 1,
        'created_at': nowStr,
        'updated_at': nowStr,
      },
      {
        'uuid': 'note_test_2',
        'title': '物理实验笔记',
        'content': '牛顿第二定律实验注意事项：1. 平衡摩擦力是关键步骤；2. 砂桶质量要远小于小车质量；3. 使用光电门计时更精确；4. 多次测量取平均值减小误差。',
        'subject': '物理',
        'note_type': 'text',
        'is_favorite': 0,
        'created_at': nowStr,
        'updated_at': nowStr,
      },
      {
        'uuid': 'note_test_3',
        'title': '英语语法笔记 - 虚拟语气',
        'content': '虚拟语气用法总结：\n1. 与现在事实相反：if + 过去式，would/could/should/might + 动词原形\n2. 与过去事实相反：if + had done，would/could/should/might + have done\n3. 与将来事实相反：if + were to/should + 动词原形，would + 动词原形',
        'subject': '英语',
        'note_type': 'text',
        'is_favorite': 1,
        'created_at': nowStr,
        'updated_at': nowStr,
      },
    ];
    
    for (final note in testNotes) {
      await db.insert(tableNotes, note);
    }

    // 测试学习记录数据
    final today = DateTime.now();
    final testStudyRecords = [
      {
        'uuid': 'sr_test_1',
        'record_type': 'study',
        'title': '数学学习',
        'description': '学习一元二次方程',
        'subject': '数学',
        'duration': 3600, // 60分钟
        'related_id': null,
        'related_type': null,
        'score': null,
        'is_completed': 1,
        'created_at': today.subtract(Duration(days: 1)).toIso8601String(),
      },
      {
        'uuid': 'sr_test_2',
        'record_type': 'study',
        'title': '物理学习',
        'description': '学习牛顿第二定律',
        'subject': '物理',
        'duration': 2700, // 45分钟
        'related_id': null,
        'related_type': null,
        'score': null,
        'is_completed': 1,
        'created_at': today.subtract(Duration(days: 2)).toIso8601String(),
      },
      {
        'uuid': 'sr_test_3',
        'record_type': 'study',
        'title': '英语学习',
        'description': '学习定语从句',
        'subject': '英语',
        'duration': 1800, // 30分钟
        'related_id': null,
        'related_type': null,
        'score': null,
        'is_completed': 1,
        'created_at': today.subtract(Duration(days: 3)).toIso8601String(),
      },
      {
        'uuid': 'sr_test_4',
        'record_type': 'study',
        'title': '化学学习',
        'description': '学习氧化还原反应',
        'subject': '化学',
        'duration': 2400, // 40分钟
        'related_id': null,
        'related_type': null,
        'score': null,
        'is_completed': 1,
        'created_at': today.subtract(Duration(days: 4)).toIso8601String(),
      },
      {
        'uuid': 'sr_test_5',
        'record_type': 'study',
        'title': '语文学习',
        'description': '古诗词鉴赏',
        'subject': '语文',
        'duration': 3000, // 50分钟
        'related_id': null,
        'related_type': null,
        'score': null,
        'is_completed': 1,
        'created_at': today.toIso8601String(),
      },
    ];

    for (final sr in testStudyRecords) {
      await db.insert(tableStudyRecords, sr);
    }

    // 测试APP使用记录数据
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final yesterdayStr = '${today.subtract(Duration(days: 1)).year}-${today.subtract(Duration(days: 1)).month.toString().padLeft(2, '0')}-${today.subtract(Duration(days: 1)).day.toString().padLeft(2, '0')}';

    final testUsageRecords = [
      {
        'uuid': 'ur_test_1',
        'start_time': today.subtract(Duration(hours: 2)).millisecondsSinceEpoch,
        'end_time': today.subtract(Duration(hours: 1)).millisecondsSinceEpoch,
        'duration': 3600,
        'date': todayStr,
        'device_info': 'Test Device',
        'app_version': '1.0.0',
        'created_at': today.toIso8601String(),
      },
      {
        'uuid': 'ur_test_2',
        'start_time': today.subtract(Duration(hours: 5)).millisecondsSinceEpoch,
        'end_time': today.subtract(Duration(hours: 4)).millisecondsSinceEpoch,
        'duration': 3600,
        'date': todayStr,
        'device_info': 'Test Device',
        'app_version': '1.0.0',
        'created_at': today.toIso8601String(),
      },
      {
        'uuid': 'ur_test_3',
        'start_time': yesterdayStr + ' 10:00:00',
        'end_time': yesterdayStr + ' 11:30:00',
        'duration': 5400,
        'date': yesterdayStr,
        'device_info': 'Test Device',
        'app_version': '1.0.0',
        'created_at': yesterdayStr,
      },
    ];

    for (final ur in testUsageRecords) {
      await db.insert(tableUsageRecords, ur);
    }

    // 测试考试结果数据
    final testExamResults = [
      {
        'uuid': 'er_test_1',
        'exam_id': 1,
        'score': 85.0,
        'correct_count': 17,
        'wrong_count': 3,
        'total_count': 20,
        'time_spent': 1800,
        'accuracy': 85.0,
        'answers': '{}',
        'is_passed': 1,
        'created_at': today.subtract(Duration(days: 2)).toIso8601String(),
      },
      {
        'uuid': 'er_test_2',
        'exam_id': 2,
        'score': 72.0,
        'correct_count': 18,
        'wrong_count': 7,
        'total_count': 25,
        'time_spent': 2400,
        'accuracy': 72.0,
        'answers': '{}',
        'is_passed': 1,
        'created_at': today.subtract(Duration(days: 5)).toIso8601String(),
      },
    ];

    for (final er in testExamResults) {
      await db.insert(tableExamResults, er);
    }

    // 测试试卷数据
    final testExamPapers = [
      {
        'uuid': 'ep_test_1',
        'name': '数学期中考试',
        'subject': '数学',
        'exam_date': today.subtract(Duration(days: 7)).millisecondsSinceEpoch,
        'total_score': 100,
        'obtained_score': 85,
        'questions': '[]',
        'images': '[]',
        'notes': '需要加强几何部分',
        'tags': '期中,数学',
        'source': 'school',
        'attachment_paths': null,
        'created_at': today.subtract(Duration(days: 7)).millisecondsSinceEpoch,
        'updated_at': today.subtract(Duration(days: 7)).millisecondsSinceEpoch,
      },
      {
        'uuid': 'ep_test_2',
        'name': '物理单元测试',
        'subject': '物理',
        'exam_date': today.subtract(Duration(days: 3)).millisecondsSinceEpoch,
        'total_score': 100,
        'obtained_score': 78,
        'questions': '[]',
        'images': '[]',
        'notes': '力学部分掌握不牢',
        'tags': '单元测试,物理',
        'source': 'mock',
        'attachment_paths': null,
        'created_at': today.subtract(Duration(days: 3)).millisecondsSinceEpoch,
        'updated_at': today.subtract(Duration(days: 3)).millisecondsSinceEpoch,
      },
    ];

    for (final ep in testExamPapers) {
      await db.insert(tableExamPapers, ep);
    }
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
    await db.execute(
      'CREATE INDEX idx_attachments_parent ON $tableAttachments (parent_id)',
    );
    await db.execute(
      'CREATE INDEX idx_attachments_type ON $tableAttachments (parent_type)',
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

    // 版本4 -> 版本5：添加 subject, source 列到 exam_results 表，添加 chapter 列到多个表
    if (oldVersion < 5) {
      await _addColumnSafe(db, tableExamResults, 'subject', 'TEXT');
      await _addColumnSafe(db, tableExamResults, 'source', 'TEXT');
      await _addColumnSafe(db, tableKnowledgePoints, 'chapter', 'TEXT');
      await _addColumnSafe(db, tableMustRemembers, 'chapter', 'TEXT');
      await _addColumnSafe(db, tableWrongQuestions, 'chapter', 'TEXT');
      await _addColumnSafe(db, tableMotherQuestions, 'chapter', 'TEXT');
      await _addColumnSafe(db, tableNotes, 'chapter', 'TEXT');
    }
    
    // 版本5 -> 版本6：插入测试数据
    if (oldVersion < 6) {
      await _insertTestData(db);
    }

    // 版本6 -> 版本7：添加附件表
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE $tableAttachments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          uuid TEXT NOT NULL UNIQUE,
          parent_id TEXT NOT NULL,
          parent_type TEXT NOT NULL,
          file_path TEXT NOT NULL,
          file_name TEXT,
          file_size INTEGER,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_attachments_parent ON $tableAttachments (parent_id)',
      );
      await db.execute(
        'CREATE INDEX idx_attachments_type ON $tableAttachments (parent_type)',
      );
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

  /// 按科目和标签查询必记必背（用于做题模式抽题）
  Future<List<Map<String, dynamic>>> queryMustRemembersBySubjectAndTags(
    String subject,
    List<String>? tags,
  ) async {
    final db = await database;
    if (tags == null || tags.isEmpty) {
      return await db.query(
        tableMustRemembers,
        where: 'subject = ?',
        whereArgs: [subject],
        orderBy: 'created_at DESC',
      );
    }
    final conditions = <String>['subject = ?'];
    final args = <dynamic>[subject];
    for (final tag in tags) {
      conditions.add('(tags LIKE ? OR category LIKE ? OR exam_methods LIKE ? OR key_points LIKE ?)');
      args.add('%$tag%');
      args.add('%$tag%');
      args.add('%$tag%');
      args.add('%$tag%');
    }
    final whereClause = conditions.join(' AND ');
    return await db.query(
      tableMustRemembers,
      where: whereClause,
      whereArgs: args,
      orderBy: 'created_at DESC',
    );
  }

  /// 获取必记必背的分类/章节列表（按科目）
  Future<List<String>> queryMustRememberCategoriesBySubject(String subject) async {
    final db = await database;
    final results = await db.rawQuery(
      "SELECT DISTINCT category FROM $tableMustRemembers WHERE subject = ? AND category IS NOT NULL AND category != ''",
      [subject],
    );
    final categories = <String>{};
    for (final row in results) {
      final cat = row['category'] as String?;
      if (cat != null && cat.trim().isNotEmpty) {
        categories.add(cat.trim());
      }
    }
    // 也从 tags 字段提取
    final tagResults = await db.rawQuery(
      "SELECT DISTINCT tags FROM $tableMustRemembers WHERE subject = ? AND tags IS NOT NULL AND tags != ''",
      [subject],
    );
    for (final row in tagResults) {
      final tags = row['tags'] as String?;
      if (tags != null && tags.isNotEmpty) {
        try {
          final tagList = jsonDecode(tags) as List;
          for (final t in tagList) {
            if (t.toString().trim().isNotEmpty) {
              categories.add(t.toString().trim());
            }
          }
        } catch (_) {}
      }
    }
    return categories.toList()..sort();
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

  /// 按科目和标签查询错题（用于做题模式抽题）
  Future<List<Map<String, dynamic>>> queryWrongQuestionsBySubjectAndTags(
    String subject,
    List<String>? tags,
  ) async {
    final db = await database;
    if (tags == null || tags.isEmpty) {
      return await db.query(
        tableWrongQuestions,
        where: 'subject = ?',
        whereArgs: [subject],
        orderBy: 'created_at DESC',
      );
    }
    // 使用 tags 字段进行模糊匹配
    final conditions = <String>['subject = ?'];
    final args = <dynamic>[subject];
    for (final tag in tags) {
      conditions.add('(tags LIKE ? OR exam_methods LIKE ? OR key_points LIKE ?)');
      args.add('%$tag%');
      args.add('%$tag%');
      args.add('%$tag%');
    }
    final whereClause = conditions.join(' AND ');
    return await db.query(
      tableWrongQuestions,
      where: whereClause,
      whereArgs: args,
      orderBy: 'created_at DESC',
    );
  }

  /// 获取错题的标签/章节列表（按科目）
  Future<List<String>> queryWrongQuestionTagsBySubject(String subject) async {
    final db = await database;
    final results = await db.rawQuery(
      "SELECT DISTINCT tags FROM $tableWrongQuestions WHERE subject = ? AND tags IS NOT NULL AND tags != ''",
      [subject],
    );
    final tagSet = <String>{};
    for (final row in results) {
      final tags = row['tags'] as String?;
      if (tags != null && tags.isNotEmpty) {
        try {
          final tagList = jsonDecode(tags) as List;
          for (final t in tagList) {
            if (t.toString().trim().isNotEmpty) {
              tagSet.add(t.toString().trim());
            }
          }
        } catch (_) {
          if (tags.trim().isNotEmpty) {
            tagSet.add(tags.trim());
          }
        }
      }
    }
    return tagSet.toList()..sort();
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

  /// 按科目和标签查询母题（用于做题模式抽题）
  Future<List<Map<String, dynamic>>> queryMotherQuestionsBySubjectAndTags(
    String subject,
    List<String>? tags,
  ) async {
    final db = await database;
    if (tags == null || tags.isEmpty) {
      return await db.query(
        tableMotherQuestions,
        where: 'subject = ?',
        whereArgs: [subject],
        orderBy: 'created_at DESC',
      );
    }
    final conditions = <String>['subject = ?'];
    final args = <dynamic>[subject];
    for (final tag in tags) {
      conditions.add('(tags LIKE ? OR category LIKE ? OR exam_methods LIKE ? OR key_points LIKE ?)');
      args.add('%$tag%');
      args.add('%$tag%');
      args.add('%$tag%');
      args.add('%$tag%');
    }
    final whereClause = conditions.join(' AND ');
    return await db.query(
      tableMotherQuestions,
      where: whereClause,
      whereArgs: args,
      orderBy: 'created_at DESC',
    );
  }

  /// 获取母题的分类/章节列表（按科目）
  Future<List<String>> queryMotherQuestionCategoriesBySubject(String subject) async {
    final db = await database;
    final results = await db.rawQuery(
      "SELECT DISTINCT category FROM $tableMotherQuestions WHERE subject = ? AND category IS NOT NULL AND category != ''",
      [subject],
    );
    final categories = <String>{};
    for (final row in results) {
      final cat = row['category'] as String?;
      if (cat != null && cat.trim().isNotEmpty) {
        categories.add(cat.trim());
      }
    }
    // 也从 tags 字段提取
    final tagResults = await db.rawQuery(
      "SELECT DISTINCT tags FROM $tableMotherQuestions WHERE subject = ? AND tags IS NOT NULL AND tags != ''",
      [subject],
    );
    for (final row in tagResults) {
      final tags = row['tags'] as String?;
      if (tags != null && tags.isNotEmpty) {
        try {
          final tagList = jsonDecode(tags) as List;
          for (final t in tagList) {
            if (t.toString().trim().isNotEmpty) {
              categories.add(t.toString().trim());
            }
          }
        } catch (_) {}
      }
    }
    return categories.toList()..sort();
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

  /// 按科目和日期范围查询学习记录
  Future<List<Map<String, dynamic>>> queryStudyRecordsBySubjectAndDateRange(
    String subject,
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    return await db.query(
      tableStudyRecords,
      where: 'subject = ? AND created_at >= ? AND created_at <= ?',
      whereArgs: [subject, startDate, endDate],
      orderBy: 'created_at DESC',
    );
  }

  /// 按日期范围查询错题
  Future<List<Map<String, dynamic>>> queryWrongQuestionsByDateRange(
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    return await db.query(
      tableWrongQuestions,
      where: 'created_at >= ? AND created_at <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'created_at DESC',
    );
  }

  /// 按科目和日期范围查询错题
  Future<List<Map<String, dynamic>>> queryWrongQuestionsBySubjectAndDateRange(
    String subject,
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    return await db.query(
      tableWrongQuestions,
      where: 'subject = ? AND created_at >= ? AND created_at <= ?',
      whereArgs: [subject, startDate, endDate],
      orderBy: 'created_at DESC',
    );
  }

  /// 按日期范围查询考试结果
  Future<List<Map<String, dynamic>>> queryExamResultsByDateRange(
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    return await db.query(
      tableExamResults,
      where: 'created_at >= ? AND created_at <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'created_at DESC',
    );
  }

  /// 按科目和日期范围查询考试结果
  Future<List<Map<String, dynamic>>> queryExamResultsBySubjectAndDateRange(
    String subject,
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    return await db.query(
      tableExamResults,
      where: 'subject = ? AND created_at >= ? AND created_at <= ?',
      whereArgs: [subject, startDate, endDate],
      orderBy: 'created_at DESC',
    );
  }

  /// 按日期范围查询试卷
  Future<List<Map<String, dynamic>>> queryExamPapersByTextDateRange(
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    // exam_papers 的 created_at 是 INTEGER 类型（毫秒时间戳）
    final startMs = DateTime.parse(startDate).millisecondsSinceEpoch;
    final endMs = DateTime.parse(endDate).millisecondsSinceEpoch;
    return await db.query(
      tableExamPapers,
      where: 'created_at >= ? AND created_at <= ?',
      whereArgs: [startMs, endMs],
      orderBy: 'exam_date DESC',
    );
  }

  /// 按科目和日期范围查询试卷
  Future<List<Map<String, dynamic>>> queryExamPapersBySubjectAndDateRange(
    String subject,
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    final startMs = DateTime.parse(startDate).millisecondsSinceEpoch;
    final endMs = DateTime.parse(endDate).millisecondsSinceEpoch;
    return await db.query(
      tableExamPapers,
      where: 'subject = ? AND created_at >= ? AND created_at <= ?',
      whereArgs: [subject, startMs, endMs],
      orderBy: 'exam_date DESC',
    );
  }

  /// 按科目查询知识点
  Future<List<Map<String, dynamic>>> queryKnowledgePointsBySubjectAndDateRange(
    String subject,
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    return await db.query(
      tableKnowledgePoints,
      where: 'subject = ? AND created_at >= ? AND created_at <= ?',
      whereArgs: [subject, startDate, endDate],
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

  // ==================== 附件 CRUD ====================

  /// 插入附件
  Future<int> insertAttachment(Map<String, dynamic> data) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    data['created_at'] = now;
    return await db.insert(tableAttachments, data);
  }

  /// 更新附件
  Future<int> updateAttachment(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      tableAttachments,
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除附件
  Future<int> deleteAttachment(int id) async {
    final db = await database;
    return await db.delete(
      tableAttachments,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 根据ID查询附件
  Future<Map<String, dynamic>?> queryAttachmentById(int id) async {
    final db = await database;
    final results = await db.query(
      tableAttachments,
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 根据UUID查询附件
  Future<Map<String, dynamic>?> queryAttachmentByUuid(String uuid) async {
    final db = await database;
    final results = await db.query(
      tableAttachments,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 根据父记录ID查询所有附件
  Future<List<Map<String, dynamic>>> queryAttachmentsByParentId(String parentId) async {
    final db = await database;
    return await db.query(
      tableAttachments,
      where: 'parent_id = ?',
      whereArgs: [parentId],
      orderBy: 'created_at ASC',
    );
  }

  /// 根据父记录类型查询所有附件
  Future<List<Map<String, dynamic>>> queryAttachmentsByParentType(String parentType) async {
    final db = await database;
    return await db.query(
      tableAttachments,
      where: 'parent_type = ?',
      whereArgs: [parentType],
      orderBy: 'created_at ASC',
    );
  }

  /// 查询所有附件
  Future<List<Map<String, dynamic>>> queryAllAttachments({
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      tableAttachments,
      orderBy: orderBy ?? 'created_at DESC',
      limit: limit,
      offset: offset,
    );
  }

  /// 删除父记录的所有附件
  Future<int> deleteAttachmentsByParentId(String parentId) async {
    final db = await database;
    return await db.delete(
      tableAttachments,
      where: 'parent_id = ?',
      whereArgs: [parentId],
    );
  }

  /// 获取附件数量
  Future<int> countAttachments({String? parentId, String? parentType}) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (parentId != null) {
      whereClause += 'parent_id = ?';
      whereArgs.add(parentId);
    }
    if (parentType != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'parent_type = ?';
      whereArgs.add(parentType);
    }

    if (whereClause.isNotEmpty) {
      final results = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableAttachments WHERE $whereClause',
        whereArgs,
      );
      return Sqflite.firstIntValue(results) ?? 0;
    }
    return Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) as count FROM $tableAttachments'),
    ) ?? 0;
  }
}
