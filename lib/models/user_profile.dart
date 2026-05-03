import 'dart:convert';
import 'package:uuid/uuid.dart';

/// 用户信息模型
class UserProfile {
  final String id;
  final String name;
  final String? avatar; // 本地路径
  final String? grade; // 年级
  final String? school;
  final List<String> subjects; // 学习的学科列表
  final int dailyGoal; // 每日目标分钟
  final int totalStudyDays;
  final int createdAt; // 时间戳
  final int updatedAt; // 时间戳

  UserProfile({
    String? id,
    required this.name,
    this.avatar,
    this.grade,
    this.school,
    List<String>? subjects,
    this.dailyGoal = 60,
    this.totalStudyDays = 0,
    int? createdAt,
    int? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        subjects = subjects ?? [],
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  /// 从JSON创建
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      avatar: json['avatar'] as String?,
      grade: json['grade'] as String?,
      school: json['school'] as String?,
      subjects: (json['subjects'] as List<dynamic>).cast<String>(),
      dailyGoal: json['dailyGoal'] as int? ?? 60,
      totalStudyDays: json['totalStudyDays'] as int? ?? 0,
      createdAt: json['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: json['updatedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'grade': grade,
      'school': school,
      'subjects': subjects,
      'dailyGoal': dailyGoal,
      'totalStudyDays': totalStudyDays,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  /// 复制并修改部分字段
  UserProfile copyWith({
    String? id,
    String? name,
    String? avatar,
    String? grade,
    String? school,
    List<String>? subjects,
    int? dailyGoal,
    int? totalStudyDays,
    int? createdAt,
    int? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      grade: grade ?? this.grade,
      school: school ?? this.school,
      subjects: subjects ?? this.subjects,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      totalStudyDays: totalStudyDays ?? this.totalStudyDays,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'UserProfile(id: $id, name: $name, grade: $grade, '
        'school: $school, subjects: $subjects, dailyGoal: ${dailyGoal}min, '
        'totalStudyDays: $totalStudyDays)';
  }
}
