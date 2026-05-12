import 'dart:convert';
import 'dart:math';
import 'database_service.dart';

/// 学习分析服务
/// 提供各种学习数据分析功能
class AnalysisService {
  final DatabaseService _db = DatabaseService();

  /// 获取整体学习情况数据
  Future<Map<String, dynamic>> getOverallAnalysis({
    List<String>? subjects,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final results = <String, dynamic>{};

    // 1. 获取错题统计数据
    List<Map<String, dynamic>> wrongQuestions;
    if (subjects != null && subjects.isNotEmpty && startDate != null && endDate != null) {
      // 多学科 + 时间范围：分别查询后合并
      wrongQuestions = [];
      for (final subject in subjects) {
        wrongQuestions.addAll(await _db.queryWrongQuestionsBySubjectAndDateRange(
          subject, startDate.toIso8601String(), endDate.toIso8601String(),
        ));
      }
    } else if (subjects != null && subjects.isNotEmpty) {
      // 仅学科筛选
      wrongQuestions = [];
      for (final subject in subjects) {
        wrongQuestions.addAll(await _db.queryWrongQuestionsBySubject(subject));
      }
    } else if (startDate != null && endDate != null) {
      // 仅时间范围
      wrongQuestions = await _db.queryWrongQuestionsByDateRange(
        startDate.toIso8601String(), endDate.toIso8601String(),
      );
    } else {
      wrongQuestions = await _db.queryAllWrongQuestions();
    }

    final wrongBySubject = <String, int>{};
    final wrongByType = <String, int>{};
    final wrongByErrorType = <String, int>{
      'careless': 0,
      'knowledge_gap': 0,
      'method_error': 0,
      'other': 0,
    };

    for (final q in wrongQuestions) {
      final subject = q['subject'] as String? ?? '其他';
      wrongBySubject[subject] = (wrongBySubject[subject] ?? 0) + 1;

      final type = q['question_type'] as String? ?? 'unknown';
      wrongByType[type] = (wrongByType[type] ?? 0) + 1;

      final errorType = q['error_type'] as String? ?? 'other';
      wrongByErrorType[errorType] = (wrongByErrorType[errorType] ?? 0) + 1;
    }

    results['wrongQuestions'] = {
      'total': wrongQuestions.length,
      'bySubject': wrongBySubject,
      'byType': wrongByType,
      'byErrorType': wrongByErrorType,
    };

    // 2. 获取考试结果数据
    List<Map<String, dynamic>> examResults;
    if (subjects != null && subjects.isNotEmpty && startDate != null && endDate != null) {
      examResults = [];
      for (final subject in subjects) {
        examResults.addAll(await _db.queryExamResultsBySubjectAndDateRange(
          subject, startDate.toIso8601String(), endDate.toIso8601String(),
        ));
      }
    } else if (subjects != null && subjects.isNotEmpty) {
      examResults = [];
      for (final subject in subjects) {
        examResults.addAll(await _db.queryExamResultsBySubject(subject));
      }
    } else if (startDate != null && endDate != null) {
      examResults = await _db.queryExamResultsByDateRange(
        startDate.toIso8601String(), endDate.toIso8601String(),
      );
    } else {
      examResults = await _db.queryAllExamResults();
    }

    double totalScore = 0;
    double totalAccuracy = 0;
    int resultCount = 0;
    final scoreBySubject = <String, List<double>>{};
    final scoreBySource = <String, List<double>>{
      'mock': [],
      'school': [],
      'offline': [],
    };

    for (final r in examResults) {
      final score = (r['score'] as num?)?.toDouble() ?? 0;
      final accuracy = (r['accuracy'] as num?)?.toDouble() ?? 0;
      final subject = r['subject'] as String? ?? '其他';
      final source = r['source'] as String? ?? 'mock';

      totalScore += score;
      totalAccuracy += accuracy;
      resultCount++;

      scoreBySubject.putIfAbsent(subject, () => []);
      scoreBySubject[subject]!.add(score);

      if (scoreBySource.containsKey(source)) {
        scoreBySource[source]!.add(score);
      }
    }

    results['examResults'] = {
      'total': examResults.length,
      'averageScore': resultCount > 0 ? totalScore / resultCount : 0,
      'averageAccuracy': resultCount > 0 ? totalAccuracy / resultCount : 0,
      'bySubject': scoreBySubject.map((k, v) => MapEntry(k, v.isNotEmpty ? v.reduce((a, b) => a + b) / v.length : 0)),
      'bySource': scoreBySource.map((k, v) => MapEntry(k, v.isNotEmpty ? v.reduce((a, b) => a + b) / v.length : 0)),
    };

    // 3. 获取学习时长数据
    List<Map<String, dynamic>> studyRecords;
    if (subjects != null && subjects.isNotEmpty && startDate != null && endDate != null) {
      studyRecords = [];
      for (final subject in subjects) {
        studyRecords.addAll(await _db.queryStudyRecordsBySubjectAndDateRange(
          subject, startDate.toIso8601String(), endDate.toIso8601String(),
        ));
      }
    } else if (subjects != null && subjects.isNotEmpty) {
      studyRecords = [];
      for (final subject in subjects) {
        studyRecords.addAll(await _db.queryStudyRecordsBySubject(subject));
      }
    } else if (startDate != null && endDate != null) {
      studyRecords = await _db.queryStudyRecordsByDateRange(
        startDate.toIso8601String(), endDate.toIso8601String(),
      );
    } else {
      studyRecords = await _db.queryAllStudyRecords();
    }

    int totalDuration = 0;
    final durationBySubject = <String, int>{};
    final durationByDate = <String, int>{};

    for (final r in studyRecords) {
      final duration = (r['duration'] as int?) ?? 0;
      final subject = r['subject'] as String? ?? '其他';
      final dateStr = (r['created_at'] as String?)?.substring(0, 10) ?? '';

      totalDuration += duration;
      durationBySubject[subject] = (durationBySubject[subject] ?? 0) + duration;
      if (dateStr.isNotEmpty) {
        durationByDate[dateStr] = (durationByDate[dateStr] ?? 0) + duration;
      }
    }

    results['studyTime'] = {
      'totalMinutes': totalDuration ~/ 60,
      'bySubject': durationBySubject.map((k, v) => MapEntry(k, v ~/ 60)),
      'byDate': durationByDate.map((k, v) => MapEntry(k, v ~/ 60)),
    };

    // 4. 获取试卷数据
    List<Map<String, dynamic>> examPapers;
    if (subjects != null && subjects.isNotEmpty && startDate != null && endDate != null) {
      examPapers = [];
      for (final subject in subjects) {
        examPapers.addAll(await _db.queryExamPapersBySubjectAndDateRange(
          subject, startDate.toIso8601String(), endDate.toIso8601String(),
        ));
      }
    } else if (subjects != null && subjects.isNotEmpty) {
      examPapers = [];
      for (final subject in subjects) {
        examPapers.addAll(await _db.queryExamPapersBySubject(subject));
      }
    } else if (startDate != null && endDate != null) {
      examPapers = await _db.queryExamPapersByTextDateRange(
        startDate.toIso8601String(), endDate.toIso8601String(),
      );
    } else {
      examPapers = await _db.queryAllExamPapers();
    }

    double totalPaperScore = 0;
    int paperCount = 0;
    final paperBySubject = <String, List<double>>{};

    for (final p in examPapers) {
      final score = (p['obtained_score'] as num?)?.toDouble();
      final total = (p['total_score'] as num?)?.toDouble() ?? 100;
      final subject = p['subject'] as String? ?? '其他';

      if (score != null) {
        final rate = score / total * 100;
        totalPaperScore += rate;
        paperCount++;

        paperBySubject.putIfAbsent(subject, () => []);
        paperBySubject[subject]!.add(rate);
      }
    }

    results['examPapers'] = {
      'total': examPapers.length,
      'averageScoreRate': paperCount > 0 ? totalPaperScore / paperCount : 0,
      'bySubject': paperBySubject.map((k, v) => MapEntry(k, v.isNotEmpty ? v.reduce((a, b) => a + b) / v.length : 0)),
    };

    return results;
  }

  /// 获取知识点掌握情况
  Future<Map<String, dynamic>> getKnowledgePointMastery({
    List<String>? subjects,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final results = <String, dynamic>{};

    // 获取知识点
    List<Map<String, dynamic>> knowledgePoints;
    if (subjects != null && subjects.isNotEmpty && startDate != null && endDate != null) {
      knowledgePoints = [];
      for (final subject in subjects) {
        knowledgePoints.addAll(await _db.queryKnowledgePointsBySubjectAndDateRange(
          subject, startDate.toIso8601String(), endDate.toIso8601String(),
        ));
      }
    } else if (subjects != null && subjects.isNotEmpty) {
      knowledgePoints = [];
      for (final subject in subjects) {
        knowledgePoints.addAll(await _db.queryKnowledgePointsBySubject(subject));
      }
    } else {
      knowledgePoints = await _db.queryAllKnowledgePoints();
    }

    final masteryData = <String, Map<String, dynamic>>{};

    for (final kp in knowledgePoints) {
      final subject = kp['subject'] as String? ?? '其他';
      final mastery = (kp['mastery_level'] as num?)?.toDouble() ?? 0;
      final importance = (kp['importance'] as num?)?.toInt() ?? 1;

      masteryData.putIfAbsent(subject, () => {
        'total': 0,
        'mastered': 0,
        'learning': 0,
        'weak': 0,
        'points': <Map<String, dynamic>>[],
      });

      masteryData[subject]!['total'] = (masteryData[subject]!['total'] as int) + 1;
      masteryData[subject]!['points'].add({
        'name': kp['title'],
        'mastery': mastery,
        'importance': importance,
      });

      if (mastery >= 80) {
        masteryData[subject]!['mastered'] = (masteryData[subject]!['mastered'] as int) + 1;
      } else if (mastery >= 50) {
        masteryData[subject]!['learning'] = (masteryData[subject]!['learning'] as int) + 1;
      } else {
        masteryData[subject]!['weak'] = (masteryData[subject]!['weak'] as int) + 1;
      }
    }

    results['bySubject'] = masteryData;

    // 计算整体掌握度
    int totalPoints = 0;
    double totalMastery = 0;
    for (final subjectData in masteryData.values) {
      for (final point in subjectData['points'] as List) {
        totalPoints++;
        totalMastery += (point['mastery'] as num).toDouble();
      }
    }

    results['overallMastery'] = totalPoints > 0 ? totalMastery / totalPoints : 0;
    results['totalPoints'] = totalPoints;

    return results;
  }

  /// 获取学科强弱分析
  Future<Map<String, dynamic>> getSubjectStrengthAnalysis({
    List<String>? subjects,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final results = <String, Map<String, dynamic>>{};

    // 确定要分析的学科列表
    final allSubjects = ['语文', '数学', '英语', '物理', '化学', '生物', '历史', '地理', '政治'];
    final targetSubjects = subjects != null && subjects.isNotEmpty ? subjects : allSubjects;

    // 获取各学科的数据
    for (final subject in targetSubjects) {
      // 考试成绩
      List<Map<String, dynamic>> examResults;
      if (startDate != null && endDate != null) {
        examResults = await _db.queryExamResultsBySubjectAndDateRange(
          subject, startDate.toIso8601String(), endDate.toIso8601String(),
        );
      } else {
        examResults = await _db.queryExamResultsBySubject(subject);
      }
      double totalScore = 0;
      int count = 0;
      for (final r in examResults) {
        final score = (r['score'] as num?)?.toDouble();
        if (score != null) {
          totalScore += score;
          count++;
        }
      }
      final avgScore = count > 0 ? totalScore / count : 0;

      // 错题数量
      List<Map<String, dynamic>> wrongQuestions;
      if (startDate != null && endDate != null) {
        wrongQuestions = await _db.queryWrongQuestionsBySubjectAndDateRange(
          subject, startDate.toIso8601String(), endDate.toIso8601String(),
        );
      } else {
        wrongQuestions = await _db.queryWrongQuestionsBySubject(subject);
      }
      final wrongCount = wrongQuestions.length;

      // 学习时长
      List<Map<String, dynamic>> studyRecords;
      if (startDate != null && endDate != null) {
        studyRecords = await _db.queryStudyRecordsBySubjectAndDateRange(
          subject, startDate.toIso8601String(), endDate.toIso8601String(),
        );
      } else {
        studyRecords = await _db.queryStudyRecordsBySubject(subject);
      }
      int totalDuration = 0;
      for (final r in studyRecords) {
        totalDuration += (r['duration'] as int?) ?? 0;
      }

      // 试卷得分率
      List<Map<String, dynamic>> examPapers;
      if (startDate != null && endDate != null) {
        examPapers = await _db.queryExamPapersBySubjectAndDateRange(
          subject, startDate.toIso8601String(), endDate.toIso8601String(),
        );
      } else {
        examPapers = await _db.queryExamPapersBySubject(subject);
      }
      double totalRate = 0;
      int paperCount = 0;
      for (final p in examPapers) {
        final score = (p['obtained_score'] as num?)?.toDouble();
        final total = (p['total_score'] as num?)?.toDouble() ?? 100;
        if (score != null) {
          totalRate += (score / total * 100);
          paperCount++;
        }
      }
      final avgRate = paperCount > 0 ? totalRate / paperCount : 0;

      // 计算综合得分（满分100）
      final compositeScore = (avgScore * 0.4 + (100 - wrongCount * 2).clamp(0, 100) * 0.3 + avgRate * 0.3);

      results[subject] = {
        'averageScore': avgScore,
        'wrongCount': wrongCount,
        'studyMinutes': totalDuration ~/ 60,
        'paperScoreRate': avgRate,
        'compositeScore': compositeScore,
        'strength': compositeScore >= 70 ? 'strong' : compositeScore >= 50 ? 'medium' : 'weak',
      };
    }

    return results;
  }

  /// 获取学习时间分布
  Future<Map<String, dynamic>> getStudyTimeDistribution({
    List<String>? subjects,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final results = <String, dynamic>{};

    // 获取学习记录
    List<Map<String, dynamic>> studyRecords;
    if (subjects != null && subjects.isNotEmpty && startDate != null && endDate != null) {
      studyRecords = [];
      for (final subject in subjects) {
        studyRecords.addAll(await _db.queryStudyRecordsBySubjectAndDateRange(
          subject, startDate.toIso8601String(), endDate.toIso8601String(),
        ));
      }
    } else if (subjects != null && subjects.isNotEmpty) {
      studyRecords = [];
      for (final subject in subjects) {
        studyRecords.addAll(await _db.queryStudyRecordsBySubject(subject));
      }
    } else if (startDate != null && endDate != null) {
      studyRecords = await _db.queryStudyRecordsByDateRange(
        startDate.toIso8601String(), endDate.toIso8601String(),
      );
    } else {
      studyRecords = await _db.queryAllStudyRecords();
    }

    // 按时段分布（0-6, 6-12, 12-18, 18-24）
    final timeSlots = {
      '凌晨 (0-6点)': 0,
      '上午 (6-12点)': 0,
      '下午 (12-18点)': 0,
      '晚上 (18-24点)': 0,
    };

    // 按星期分布
    final weekDays = {
      '周一': 0,
      '周二': 0,
      '周三': 0,
      '周四': 0,
      '周五': 0,
      '周六': 0,
      '周日': 0,
    };

    for (final r in studyRecords) {
      final createdAt = r['created_at'] as String?;
      final duration = (r['duration'] as int?) ?? 0;

      if (createdAt != null) {
        try {
          final date = DateTime.parse(createdAt);
          final hour = date.hour;
          final weekDay = date.weekday;

          // 时段统计
          if (hour >= 0 && hour < 6) {
            timeSlots['凌晨 (0-6点)'] = timeSlots['凌晨 (0-6点)']! + duration;
          } else if (hour >= 6 && hour < 12) {
            timeSlots['上午 (6-12点)'] = timeSlots['上午 (6-12点)']! + duration;
          } else if (hour >= 12 && hour < 18) {
            timeSlots['下午 (12-18点)'] = timeSlots['下午 (12-18点)']! + duration;
          } else {
            timeSlots['晚上 (18-24点)'] = timeSlots['晚上 (18-24点)']! + duration;
          }

          // 星期统计
          final weekDayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
          weekDays[weekDayNames[weekDay - 1]] = weekDays[weekDayNames[weekDay - 1]]! + duration;
        } catch (e) {
          // 忽略解析错误
        }
      }
    }

    results['byTimeSlot'] = timeSlots.map((k, v) => MapEntry(k, v ~/ 60));
    results['byWeekDay'] = weekDays.map((k, v) => MapEntry(k, v ~/ 60));

    return results;
  }

  /// 获取错题类型分析
  Future<Map<String, dynamic>> getWrongQuestionAnalysis({
    List<String>? subjects,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final results = <String, dynamic>{};

    // 获取错题
    List<Map<String, dynamic>> wrongQuestions;
    if (subjects != null && subjects.isNotEmpty && startDate != null && endDate != null) {
      wrongQuestions = [];
      for (final subject in subjects) {
        wrongQuestions.addAll(await _db.queryWrongQuestionsBySubjectAndDateRange(
          subject, startDate.toIso8601String(), endDate.toIso8601String(),
        ));
      }
    } else if (subjects != null && subjects.isNotEmpty) {
      wrongQuestions = [];
      for (final subject in subjects) {
        wrongQuestions.addAll(await _db.queryWrongQuestionsBySubject(subject));
      }
    } else if (startDate != null && endDate != null) {
      wrongQuestions = await _db.queryWrongQuestionsByDateRange(
        startDate.toIso8601String(), endDate.toIso8601String(),
      );
    } else {
      wrongQuestions = await _db.queryAllWrongQuestions();
    }

    // 按错误类型统计
    final errorTypes = {
      'careless': {'label': '粗心大意', 'count': 0, 'color': '#FFB74D'},
      'knowledge_gap': {'label': '知识盲区', 'count': 0, 'color': '#EF5350'},
      'method_error': {'label': '方法错误', 'count': 0, 'color': '#42A5F5'},
      'other': {'label': '其他', 'count': 0, 'color': '#BDBDBD'},
    };

    // 按难度统计
    final difficultyStats = {
      'easy': 0,
      'medium': 0,
      'hard': 0,
    };

    // 高频错题知识点
    final knowledgePointFreq = <String, int>{};

    for (final q in wrongQuestions) {
      final errorType = q['error_type'] as String? ?? 'other';
      final difficulty = q['difficulty'] as String? ?? 'medium';
      final knowledgePoint = q['knowledge_point'] as String?;

      if (errorTypes.containsKey(errorType)) {
        errorTypes[errorType]!['count'] = (errorTypes[errorType]!['count'] as int) + 1;
      }

      if (difficultyStats.containsKey(difficulty)) {
        difficultyStats[difficulty] = difficultyStats[difficulty]! + 1;
      }

      if (knowledgePoint != null && knowledgePoint.isNotEmpty) {
        knowledgePointFreq[knowledgePoint] = (knowledgePointFreq[knowledgePoint] ?? 0) + 1;
      }
    }

    // 排序高频知识点
    final sortedKnowledgePoints = knowledgePointFreq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    results['byErrorType'] = errorTypes;
    results['byDifficulty'] = difficultyStats;
    results['topKnowledgePoints'] = sortedKnowledgePoints.take(10).map((e) => {
      'name': e.key,
      'count': e.value,
    }).toList();

    return results;
  }

  /// 获取学习趋势数据
  Future<Map<String, dynamic>> getLearningTrend({
    int days = 30,
    List<String>? subjects,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final results = <String, dynamic>{};

    final now = DateTime.now();
    // 如果指定了自定义时间范围，使用自定义范围；否则使用 days 参数
    final effectiveStart = startDate ?? now.subtract(Duration(days: days));
    final effectiveEnd = endDate ?? now;
    final totalDays = effectiveEnd.difference(effectiveStart).inDays;

    // 生成日期列表
    final dateList = <String>[];
    for (int i = totalDays; i >= 0; i--) {
      final date = effectiveEnd.subtract(Duration(days: i));
      dateList.add('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}');
    }

    // 获取学习记录
    List<Map<String, dynamic>> studyRecords;
    if (subjects != null && subjects.isNotEmpty) {
      studyRecords = [];
      for (final subject in subjects) {
        studyRecords.addAll(await _db.queryStudyRecordsBySubjectAndDateRange(
          subject, effectiveStart.toIso8601String(), effectiveEnd.toIso8601String(),
        ));
      }
    } else {
      studyRecords = await _db.queryStudyRecordsByDateRange(
        effectiveStart.toIso8601String(),
        effectiveEnd.toIso8601String(),
      );
    }

    // 按日期聚合
    final dailyData = <String, Map<String, dynamic>>{};
    for (final date in dateList) {
      dailyData[date] = {
        'duration': 0,
        'questions': 0,
        'accuracy': 0.0,
        'count': 0,
      };
    }

    for (final r in studyRecords) {
      final createdAt = r['created_at'] as String?;
      if (createdAt != null) {
        final dateStr = createdAt.substring(0, 10);
        if (dailyData.containsKey(dateStr)) {
          dailyData[dateStr]!['duration'] = (dailyData[dateStr]!['duration'] as int) + ((r['duration'] as int?) ?? 0);
          dailyData[dateStr]!['questions'] = (dailyData[dateStr]!['questions'] as int) + ((r['question_count'] as int?) ?? 0);

          final accuracy = (r['accuracy'] as num?)?.toDouble();
          if (accuracy != null && accuracy > 0) {
            final currentAcc = dailyData[dateStr]!['accuracy'] as double;
            final currentCount = dailyData[dateStr]!['count'] as int;
            dailyData[dateStr]!['accuracy'] = (currentAcc * currentCount + accuracy) / (currentCount + 1);
            dailyData[dateStr]!['count'] = currentCount + 1;
          }
        }
      }
    }

    results['dailyData'] = dailyData;
    results['dates'] = dateList;

    return results;
  }

  /// 生成个性化学习建议
  Future<List<Map<String, dynamic>>> generateLearningSuggestions({
    List<String>? subjects,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final suggestions = <Map<String, dynamic>>[];

    // 1. 分析薄弱学科
    final subjectStrength = await getSubjectStrengthAnalysis(
      subjects: subjects,
      startDate: startDate,
      endDate: endDate,
    );
    final weakSubjects = subjectStrength.entries
        .where((e) => e.value['strength'] == 'weak')
        .toList();

    if (weakSubjects.isNotEmpty) {
      for (final subject in weakSubjects.take(2)) {
        suggestions.add({
          'type': 'weak_subject',
          'priority': 'high',
          'title': '加强${subject.key}学习',
          'description': '你在${subject.key}方面的表现相对较弱，建议增加该学科的学习时间，重点复习基础知识。',
          'action': '开始${subject.key}专项练习',
        });
      }
    }

    // 2. 分析错题类型
    final wrongAnalysis = await getWrongQuestionAnalysis(
      subjects: subjects,
      startDate: startDate,
      endDate: endDate,
    );
    final errorTypes = wrongAnalysis['byErrorType'] as Map<String, dynamic>;

    final carelessCount = (errorTypes['careless'] as Map<String, dynamic>)['count'] as int;
    final knowledgeGapCount = (errorTypes['knowledge_gap'] as Map<String, dynamic>)['count'] as int;

    if (carelessCount > 5) {
      suggestions.add({
        'type': 'careless',
        'priority': 'medium',
        'title': '减少粗心错误',
        'description': '你有较多因粗心导致的错误，建议做题时更加仔细，养成检查的习惯。',
        'action': '查看粗心错题',
      });
    }

    if (knowledgeGapCount > 3) {
      suggestions.add({
        'type': 'knowledge_gap',
        'priority': 'high',
        'title': '填补知识盲区',
        'description': '发现你在某些知识点上存在盲区，建议系统性地复习相关内容。',
        'action': '查看知识盲区',
      });
    }

    // 3. 分析学习时长
    final timeDistribution = await getStudyTimeDistribution(
      subjects: subjects,
      startDate: startDate,
      endDate: endDate,
    );
    final byTimeSlot = timeDistribution['byTimeSlot'] as Map<String, int>;
    final totalMinutes = byTimeSlot.values.fold<int>(0, (a, b) => a + b);

    if (totalMinutes < 300) { // 少于5小时
      suggestions.add({
        'type': 'study_time',
        'priority': 'medium',
        'title': '增加学习时间',
        'description': '最近的学习时间较少，建议每天保持至少1小时的学习时间。',
        'action': '制定学习计划',
      });
    }

    // 4. 分析高频错题知识点
    final topKnowledgePoints = wrongAnalysis['topKnowledgePoints'] as List<dynamic>;
    if (topKnowledgePoints.isNotEmpty) {
      final topPoint = topKnowledgePoints.first;
      suggestions.add({
        'type': 'knowledge_review',
        'priority': 'high',
        'title': '复习${topPoint['name']}',
        'description': '${topPoint['name']}是你出错最多的知识点，建议重点复习。',
        'action': '开始针对性练习',
      });
    }

    // 5. 分析试卷得分率
    final overallAnalysis = await getOverallAnalysis(
      subjects: subjects,
      startDate: startDate,
      endDate: endDate,
    );
    final examPapers = overallAnalysis['examPapers'] as Map<String, dynamic>;
    final avgScoreRate = (examPapers['averageScoreRate'] as num?)?.toDouble() ?? 0;

    if (avgScoreRate < 60) {
      suggestions.add({
        'type': 'exam_practice',
        'priority': 'high',
        'title': '加强考试练习',
        'description': '你的试卷平均得分率较低，建议多做模拟测试，熟悉考试节奏。',
        'action': '开始模拟测试',
      });
    }

    // 按优先级排序
    suggestions.sort((a, b) {
      final priorityOrder = {'high': 0, 'medium': 1, 'low': 2};
      return priorityOrder[a['priority']]!.compareTo(priorityOrder[b['priority']]!);
    });

    return suggestions;
  }

  /// 获取雷达图数据
  Future<Map<String, double>> getRadarChartData({
    List<String>? subjects,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final data = <String, double>{};

    // 1. 知识掌握度
    final knowledgeMastery = await getKnowledgePointMastery(
      subjects: subjects,
      startDate: startDate,
      endDate: endDate,
    );
    data['知识掌握'] = (knowledgeMastery['overallMastery'] as num?)?.toDouble() ?? 0;

    // 2. 考试成绩
    final overallAnalysis = await getOverallAnalysis(
      subjects: subjects,
      startDate: startDate,
      endDate: endDate,
    );
    final examResults = overallAnalysis['examResults'] as Map<String, dynamic>;
    data['考试成绩'] = (examResults['averageAccuracy'] as num?)?.toDouble() ?? 0;

    // 3. 学习时长
    final studyTime = overallAnalysis['studyTime'] as Map<String, dynamic>;
    final totalMinutes = studyTime['totalMinutes'] as int? ?? 0;
    // 根据时间范围动态计算满分基准
    int referenceDays = 30;
    if (startDate != null && endDate != null) {
      referenceDays = endDate.difference(startDate).inDays;
      if (referenceDays <= 0) referenceDays = 1;
    }
    // 假设每天学习2小时为满分
    data['学习时长'] = (totalMinutes / (referenceDays * 120) * 100).clamp(0, 100);

    // 4. 错题改进率
    final wrongAnalysis = await getWrongQuestionAnalysis(
      subjects: subjects,
      startDate: startDate,
      endDate: endDate,
    );
    final byErrorType = wrongAnalysis['byErrorType'] as Map<String, dynamic>;
    int wrongCount = 0;
    for (final entry in byErrorType.entries) {
      wrongCount += ((entry.value as Map<String, dynamic>)['count'] as int?) ?? 0;
    }
    // 错题越少越好，假设50道为0分，0道为100分
    data['错题控制'] = ((1 - wrongCount / 50) * 100).clamp(0, 100);

    // 5. 试卷得分率
    final examPapers = overallAnalysis['examPapers'] as Map<String, dynamic>;
    data['试卷得分'] = examPapers['averageScoreRate'] as double? ?? 0;

    return data;
  }

  /// 获取推荐复习内容
  Future<List<Map<String, dynamic>>> getRecommendedReview({
    List<String>? subjects,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final recommendations = <Map<String, dynamic>>[];

    // 1. 获取掌握度低的知识点
    final knowledgeMastery = await getKnowledgePointMastery(
      subjects: subjects,
      startDate: startDate,
      endDate: endDate,
    );
    final bySubject = knowledgeMastery['bySubject'] as Map<String, dynamic>;

    for (final entry in bySubject.entries) {
      final subject = entry.key;
      final subjectData = entry.value as Map<String, dynamic>;
      final points = subjectData['points'] as List<dynamic>;

      // 找出掌握度低于50%的知识点
      final weakPoints = points.where((p) => (p['mastery'] as num) < 50).toList();
      for (final point in weakPoints.take(3)) {
        recommendations.add({
          'type': 'knowledge_point',
          'subject': subject,
          'name': point['name'],
          'mastery': point['mastery'],
          'priority': 'high',
        });
      }
    }

    // 2. 获取高频错题
    final wrongAnalysis = await getWrongQuestionAnalysis(
      subjects: subjects,
      startDate: startDate,
      endDate: endDate,
    );
    final topKnowledgePoints = wrongAnalysis['topKnowledgePoints'] as List<dynamic>;

    for (final point in topKnowledgePoints.take(5)) {
      // 避免重复
      if (!recommendations.any((r) => r['name'] == point['name'])) {
        recommendations.add({
          'type': 'wrong_question',
          'name': point['name'],
          'count': point['count'],
          'priority': 'high',
        });
      }
    }

    // 按优先级排序
    recommendations.sort((a, b) {
      final priorityOrder = {'high': 0, 'medium': 1, 'low': 2};
      return priorityOrder[a['priority']]!.compareTo(priorityOrder[b['priority']]!);
    });

    return recommendations.take(10).toList();
  }
}
