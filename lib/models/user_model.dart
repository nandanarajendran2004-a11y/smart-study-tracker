import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String course;
  final String semester;
  final String department;
  final String profileImage;
  final List<String> subjects;
  final DateTime createdAt;

  // Gamification & Settings Fields
  final int streak;
  final int xp;
  final int level;
  final List<String> unlockedBadges;
  final Map<String, dynamic> settings;
  final Map<String, dynamic> pomodoroPreferences;
  final Map<String, dynamic> schedulePreferences;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.course = '',
    this.semester = '',
    this.department = '',
    this.profileImage = '',
    this.subjects = const [],
    required this.createdAt,
    this.streak = 0,
    this.xp = 0,
    this.level = 1,
    this.unlockedBadges = const [],
    this.settings = const {},
    this.pomodoroPreferences = const {},
    this.schedulePreferences = const {},
  });

  // Convert to Map for saving to SharedPreferences
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'course': course,
    'semester': semester,
    'department': department,
    'profileImage': profileImage,
    'subjects': subjects,
    'createdAt': createdAt.toIso8601String(),
    'streak': streak,
    'xp': xp,
    'level': level,
    'unlockedBadges': unlockedBadges,
    'settings': settings,
    'pomodoroPreferences': pomodoroPreferences,
    'schedulePreferences': schedulePreferences,
  };

  // Convert to Firestore Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'course': course,
      'semester': semester,
      'department': department,
      'profileImage': profileImage,
      'subjects': subjects,
      'createdAt': createdAt,
      'streak': streak,
      'xp': xp,
      'level': level,
      'unlockedBadges': unlockedBadges,
      'settings': settings,
      'pomodoroPreferences': pomodoroPreferences,
      'schedulePreferences': schedulePreferences,
    };
  }

  // Create UserModel from Firestore
  factory UserModel.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate;
    if (map['createdAt'] is Timestamp) {
      parsedDate = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is String) {
      parsedDate = DateTime.parse(map['createdAt']);
    } else {
      parsedDate = DateTime.now();
    }
    
    return UserModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      course: map['course'] ?? '',
      semester: map['semester'] ?? '',
      department: map['department'] ?? '',
      profileImage: map['profileImage'] ?? '',
      subjects: List<String>.from(map['subjects'] ?? []),
      createdAt: parsedDate,
      streak: map['streak'] ?? 0,
      xp: map['xp'] ?? 0,
      level: map['level'] ?? 1,
      unlockedBadges: List<String>.from(map['unlockedBadges'] ?? []),
      settings: Map<String, dynamic>.from(map['settings'] ?? {}),
      pomodoroPreferences: Map<String, dynamic>.from(map['pomodoroPreferences'] ?? {}),
      schedulePreferences: Map<String, dynamic>.from(map['schedulePreferences'] ?? {}),
    );
  }

  // Create UserModel from saved Map
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      course: json['course'] ?? '',
      semester: json['semester'] ?? '',
      department: json['department'] ?? '',
      profileImage: json['profileImage'] ?? '',
      subjects: List<String>.from(json['subjects'] ?? []),
      createdAt: DateTime.parse(json['createdAt']),
      streak: json['streak'] ?? 0,
      xp: json['xp'] ?? 0,
      level: json['level'] ?? 1,
      unlockedBadges: List<String>.from(json['unlockedBadges'] ?? []),
      settings: Map<String, dynamic>.from(json['settings'] ?? {}),
      pomodoroPreferences: Map<String, dynamic>.from(json['pomodoroPreferences'] ?? {}),
      schedulePreferences: Map<String, dynamic>.from(json['schedulePreferences'] ?? {}),
    );
  }

  // Create a copy with updated fields
  UserModel copyWith({
    String? name,
    String? course,
    String? semester,
    String? department,
    String? profileImage,
    List<String>? subjects,
    int? streak,
    int? xp,
    int? level,
    List<String>? unlockedBadges,
    Map<String, dynamic>? settings,
    Map<String, dynamic>? pomodoroPreferences,
    Map<String, dynamic>? schedulePreferences,
  }) =>
    UserModel(
      id: id,
      name: name ?? this.name,
      email: email,
      course: course ?? this.course,
      semester: semester ?? this.semester,
      department: department ?? this.department,
      profileImage: profileImage ?? this.profileImage,
      subjects: subjects ?? this.subjects,
      createdAt: createdAt,
      streak: streak ?? this.streak,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      unlockedBadges: unlockedBadges ?? this.unlockedBadges,
      settings: settings ?? this.settings,
      pomodoroPreferences: pomodoroPreferences ?? this.pomodoroPreferences,
      schedulePreferences: schedulePreferences ?? this.schedulePreferences,
    );
}