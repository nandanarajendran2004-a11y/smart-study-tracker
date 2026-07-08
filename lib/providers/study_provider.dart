import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/study_session_model.dart';
import '../models/subject_model.dart';
import '../models/goal_model.dart';
import '../models/exam_model.dart';
import '../models/badge_model.dart';
import '../services/firestore_service.dart';

class StudyProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final _uuid = const Uuid();

  List<StudySessionModel> _sessions = [];
  List<SubjectModel> _subjects = [];
  List<GoalModel> _goals = [];
  List<ExamModel> _exams = [];
  
  int _studyStreak = 0;
  int _xp = 0;
  int _level = 1;
  List<String> _unlockedBadgeIds = [];
  bool _isLoading = false;

  StreamSubscription? _authSubscription;
  StreamSubscription? _subjectsSubscription;
  StreamSubscription? _sessionsSubscription;
  StreamSubscription? _goalsSubscription;
  StreamSubscription? _examsSubscription;
  StreamSubscription? _userDocSubscription;

  String? _currentUid;

  List<StudySessionModel> get sessions => List.unmodifiable(_sessions);
  List<SubjectModel> get subjects => _subjects;
  List<GoalModel> get goals => _goals;
  List<ExamModel> get exams => _exams;
  int get studyStreak => _studyStreak;
  int get xp => _xp;
  int get level => _level;
  List<String> get unlockedBadgeIds => _unlockedBadgeIds;
  bool get isLoading => _isLoading;

  // Static Badge List representing all achievable rewards
  final List<BadgeModel> allBadges = [
    BadgeModel(
      id: 'badge_streak_7',
      title: '7-Day Streak',
      description: 'Study for 7 days consecutively',
      emoji: '🔥',
      requirement: 'Achieve a study streak of 7 days or more.',
    ),
    BadgeModel(
      id: 'badge_streak_30',
      title: '30-Day Streak',
      description: 'Study for 30 days consecutively',
      emoji: '👑',
      requirement: 'Achieve a study streak of 30 days or more.',
    ),
    BadgeModel(
      id: 'badge_hours_100',
      title: '100 Hours Studied',
      description: 'Study for a total of 100 hours',
      emoji: '🧠',
      requirement: 'Accumulate 6,000 minutes (100 hours) of study time.',
    ),
    BadgeModel(
      id: 'badge_goal_master',
      title: 'Goal Master',
      description: 'Complete 10 study goals',
      emoji: '🏆',
      requirement: 'Mark at least 10 daily or weekly goals complete.',
    ),
    BadgeModel(
      id: 'badge_perfect_week',
      title: 'Perfect Week',
      description: 'Complete 5 goals in a week',
      emoji: '⭐',
      requirement: 'Track daily study sessions on 5 different days in a single week.',
    ),
  ];

  StudyProvider() {
    _monitorAuthState();
  }

  void _monitorAuthState() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _setupUserListeners(user.uid);
      } else {
        _clearListeners();
      }
    });
  }

  void _setupUserListeners(String uid) {
    if (_currentUid == uid) return;
    _clearListeners();
    _currentUid = uid;
    _isLoading = true;
    notifyListeners();

    // 1. User document metadata listener (streak, xp, level, badges)
    _userDocSubscription = FirebaseFirestore.instance.collection("users").doc(uid).snapshots().listen((doc) {
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        _xp = data['xp'] ?? 0;
        _level = data['level'] ?? 1;
        _unlockedBadgeIds = List<String>.from(data['unlockedBadges'] ?? []);
        notifyListeners();
      }
    });

    // 2. Subjects Stream
    _subjectsSubscription = _firestoreService.getSubjectsStream(uid).listen((data) {
      _subjects = data.map((e) => SubjectModel.fromJson(e)).toList();
      notifyListeners();
    });

    // 3. Sessions Stream
    // _sessionsSubscription = _firestoreService.getSessionsStream(uid).listen((data) {
    //   _sessions = data.map((e) => StudySessionModel.fromJson(e)).toList();
    //   _calculateStreak();
    //   _isLoading = false;
    //   notifyListeners();
    // });
    _sessionsSubscription = _firestoreService.getSessionsStream(uid).listen(
  (data) {
    _sessions = data.map((e) => StudySessionModel.fromJson(e)).toList();

    // Sort newest session first
    _sessions.sort(
      (a, b) => b.startTime.compareTo(a.startTime),
    );

    _calculateStreak();
    _checkBadges();
    _isLoading = false;
    notifyListeners();
  },
  onError: (error) {
    debugPrint('Sessions stream error: $error');
    _isLoading = false;
    notifyListeners();
  },
);

    // 4. Goals Stream
    _goalsSubscription = _firestoreService.getGoalsStream(uid).listen((data) {
      _goals = data.map((e) => GoalModel.fromJson(e)).toList();
      notifyListeners();
    });

    // 5. Exams Stream
    // _examsSubscription = _firestoreService.getExamsStream(uid).listen((data) {
    //   _exams = data.map((e) => ExamModel.fromJson(e)).toList();
    //   notifyListeners();
    // });
    _examsSubscription = _firestoreService.getExamsStream(uid).listen(
  (data) {
    _exams = data.map((e) => ExamModel.fromJson(e)).toList();

    // Sort exams by upcoming date
    _exams.sort(
      (a, b) => a.date.compareTo(b.date),
    );

    notifyListeners();
  },
  onError: (error) {
    debugPrint('Exams stream error: $error');
    notifyListeners();
  },
);
  }

  void _clearListeners() {
    _subjectsSubscription?.cancel();
    _sessionsSubscription?.cancel();
    _goalsSubscription?.cancel();
    _examsSubscription?.cancel();
    _userDocSubscription?.cancel();
    _currentUid = null;
    _sessions = [];
    _subjects = [];
    _goals = [];
    _exams = [];
    _studyStreak = 0;
    _xp = 0;
    _level = 1;
    _unlockedBadgeIds = [];
    _isLoading = false;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _clearListeners();
    super.dispose();
  }

  // ── SESSIONS ─────────────────────────────────────────────

  Future<void> addSession({
    required String subjectId,
    required String subjectName,
    required DateTime startTime,
    required DateTime endTime,
    required int durationMinutes,
    String? notes,
    bool isPomodoroSession = false,
  }) async {
    if (_currentUid == null) return;

    final session = StudySessionModel(
      id: _uuid.v4(),
      subjectId: subjectId,
      subjectName: subjectName,
      startTime: startTime,
      endTime: endTime,
      durationMinutes: durationMinutes,
      notes: notes,
      isPomodoroSession: isPomodoroSession,
    );

    // Update goals locally/dynamically for progress
    _updateGoalsProgress(subjectId, durationMinutes);

    // Save to Firestore
    await _firestoreService.saveSession(_currentUid!, session.toJson());

    // Update Subject Study Time
    await _incrementSubjectTime(subjectId, durationMinutes);

    // Award XP: 10 XP per minute studied
    final xpEarned = durationMinutes * 10;
    await _awardXP(xpEarned);
  }

  Future<void> deleteSession(String sessionId) async {
    await _firestoreService.deleteSession(sessionId);
  }

  // ── SUBJECTS ─────────────────────────────────────────────

  Future<bool> addCustomSubject({
    required String name,
    required int colorValue,
    int targetHoursPerWeek = 4,
  }) async {
    if (_currentUid == null) return false;

    final subject = SubjectModel(
      id: _uuid.v4(),
      name: name,
      colorValue: colorValue,
      targetHoursPerWeek: targetHoursPerWeek,
    );

    _subjects = [..._subjects, subject];
    notifyListeners();

    try {
      await _firestoreService.saveSubject(_currentUid!, subject.toJson());
      return true;
    } catch (e) {
      _subjects.removeWhere((existing) => existing.id == subject.id);
      notifyListeners();
      debugPrint('Error adding subject: $e');
      return false;
    }
  }

  Future<bool> updateSubject(SubjectModel subject) async {
    if (_currentUid == null) return false;

    final existingIndex = _subjects.indexWhere((item) => item.id == subject.id);
    SubjectModel? previousSubject;
    if (existingIndex != -1) {
      previousSubject = _subjects[existingIndex];
      _subjects[existingIndex] = subject;
      notifyListeners();
    }

    try {
      await _firestoreService.saveSubject(_currentUid!, subject.toJson());
      return true;
    } catch (e) {
      if (existingIndex != -1 && previousSubject != null) {
        _subjects[existingIndex] = previousSubject;
        notifyListeners();
      }
      debugPrint('Error updating subject: $e');
      return false;
    }
  }

  Future<void> deleteSubject(String subjectId) async {
    await _firestoreService.deleteSubject(subjectId);
  }

  Future<void> _incrementSubjectTime(String subjectId, int minutes) async {
    if (_currentUid == null) return;
    try {
      final subIndex = _subjects.indexWhere((s) => s.id == subjectId);
      if (subIndex != -1) {
        final sub = _subjects[subIndex];
        sub.totalMinutesStudied += minutes;
        await _firestoreService.saveSubject(_currentUid!, sub.toJson());
      }
    } catch (e) {
      debugPrint("Error incrementing subject study minutes: $e");
    }
  }

  // ── GOALS ────────────────────────────────────────────────

  Future<void> addGoal({
    required String title,
    required int targetMinutes,
    required DateTime deadline,
    required String type,
    String? subjectId,
  }) async {
    if (_currentUid == null) return;

    final goal = GoalModel(
      id: _uuid.v4(),
      title: title,
      targetMinutes: targetMinutes,
      deadline: deadline,
      type: type,
      subjectId: subjectId,
    );

    await _firestoreService.saveGoal(_currentUid!, goal.toJson());
  }

  Future<void> updateGoal(GoalModel goal) async {
    if (_currentUid == null) return;
    await _firestoreService.saveGoal(_currentUid!, goal.toJson());
    _checkBadges();
  }

  Future<void> deleteGoal(String goalId) async {
    await _firestoreService.deleteGoal(goalId);
  }

  void _updateGoalsProgress(String subjectId, int minutesAdded) {
    for (final goal in _goals) {
      if (!goal.isActive || goal.isCompleted) continue;
      if (goal.type == 'daily' || goal.type == 'weekly') {
        goal.completedMinutes += minutesAdded;
        updateGoal(goal);
      }
      if (goal.type == 'subject' && goal.subjectId == subjectId) {
        goal.completedMinutes += minutesAdded;
        updateGoal(goal);
      }
    }
  }

  // ── EXAMS ────────────────────────────────────────────────

  Future<void> addExam({
    required String subject,
    required DateTime date,
    required String time,
    required String location,
    String? studyPlan,
  }) async {
    if (_currentUid == null) return;

    final exam = ExamModel(
      id: _uuid.v4(),
      subject: subject,
      date: date,
      time: time,
      location: location,
      studyPlan: studyPlan,
    );

    await _firestoreService.saveExam(_currentUid!, exam.toJson());
  }

  Future<void> updateExam(ExamModel exam) async {
    if (_currentUid == null) return;
    await _firestoreService.saveExam(_currentUid!, exam.toJson());
  }

  Future<void> deleteExam(String examId) async {
    await _firestoreService.deleteExam(examId);
  }

  // ── GAMIFICATION ──────────────────────────────────────────

  Future<void> _awardXP(int amount) async {
    if (_currentUid == null) return;
    final int newXp = _xp + amount;
    final int newLevel = (newXp / 500).floor() + 1; // 500 XP per level

    final updates = {
      'xp': newXp,
      'level': newLevel,
    };
    await _firestoreService.updateUser(_currentUid!, updates);
    _checkBadges();
  }

  void _calculateStreak() {
    if (_sessions.isEmpty) {
      _studyStreak = 0;
      return;
    }

    final today = DateTime.now();
    int streak = 0;
    
    // Convert session startTimes to Date-only comparators
    final sessionDates = _sessions.map((s) => 
      DateTime(s.startTime.year, s.startTime.month, s.startTime.day)
    ).toSet();

    for (int i = 0; i < 365; i++) {
      final checkDate = DateTime(today.year, today.month, today.day).subtract(Duration(days: i));
      if (sessionDates.contains(checkDate)) {
        streak++;
      } else {
        // If it's today and they haven't studied yet, check yesterday to keep streak alive
        if (i == 0) {
          final yesterday = checkDate.subtract(const Duration(days: 1));
          if (sessionDates.contains(yesterday)) {
            continue;
          }
        }
        break;
      }
    }
    _studyStreak = streak;

    // Sync streak with Firestore
    if (_currentUid != null) {
      _firestoreService.updateUser(_currentUid!, {'streak': _studyStreak});
    }
  }

  Future<void> _checkBadges() async {
    if (_currentUid == null) return;
    
    List<String> newBadges = List.from(_unlockedBadgeIds);
    final totalHours = totalStudyMinutesAllTime / 60.0;
    final completedGoalsCount = _goals.where((g) => g.isCompleted).length;

    // Badge 1: 7-day streak
    if (_studyStreak >= 7 && !newBadges.contains('badge_streak_7')) {
      newBadges.add('badge_streak_7');
    }
    // Badge 2: 30-day streak
    if (_studyStreak >= 30 && !newBadges.contains('badge_streak_30')) {
      newBadges.add('badge_streak_30');
    }
    // Badge 3: 100 hours studied
    if (totalHours >= 100.0 && !newBadges.contains('badge_hours_100')) {
      newBadges.add('badge_hours_100');
    }
    // Badge 4: Goal Master
    if (completedGoalsCount >= 10 && !newBadges.contains('badge_goal_master')) {
      newBadges.add('badge_goal_master');
    }
    // Badge 5: Perfect Week (study on 5 separate days this week)
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartClean = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final thisWeekDaysStudied = _sessions
        .where((s) => s.startTime.isAfter(weekStartClean))
        .map((s) => DateTime(s.startTime.year, s.startTime.month, s.startTime.day))
        .toSet()
        .length;
    if (thisWeekDaysStudied >= 5 && !newBadges.contains('badge_perfect_week')) {
      newBadges.add('badge_perfect_week');
    }

    if (newBadges.length != _unlockedBadgeIds.length) {
      await _firestoreService.updateUser(_currentUid!, {'unlockedBadges': newBadges});
    }
  }

  // ── ANALYTICS GETTERS (Dynamic from state list) ───────────

  int get totalStudyMinutesToday {
    final now = DateTime.now();
    return _sessions
        .where((s) =>
            s.startTime.year == now.year &&
            s.startTime.month == now.month &&
            s.startTime.day == now.day)
        .fold(0, (sum, s) => sum + s.durationMinutes);
  }

  int get totalStudyMinutesThisWeek {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartClean =
        DateTime(weekStart.year, weekStart.month, weekStart.day);
    return _sessions
        .where((s) => s.startTime.isAfter(weekStartClean))
        .fold(0, (sum, s) => sum + s.durationMinutes);
  }

  int get totalStudyMinutesAllTime =>
      _sessions.fold(0, (sum, s) => sum + s.durationMinutes);

  Map<String, int> get subjectWiseMinutes {
    final map = <String, int>{};
    for (final session in _sessions) {
      map[session.subjectName] =
          (map[session.subjectName] ?? 0) + session.durationMinutes;
    }
    return map;
  }

  List<int> get last7DaysMinutes {
    final result = List<int>.filled(7, 0);
    final now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final day = now.subtract(Duration(days: 6 - i));
      result[i] = _sessions
          .where((s) =>
              s.startTime.year == day.year &&
              s.startTime.month == day.month &&
              s.startTime.day == day.day)
          .fold(0, (sum, s) => sum + s.durationMinutes);
    }
    return result;
  }

  double get productivityScore {
    if (_sessions.isEmpty) return 0.0;
    final todayMinutes = totalStudyMinutesToday;
    const dailyTargetMinutes = 240;
    final baseScore = (todayMinutes / dailyTargetMinutes * 70).clamp(0, 70);
    final streakBonus = (_studyStreak * 2).clamp(0, 20);
    final consistencyBonus = _studyStreak >= 2 ? 10 : 0;
    return (baseScore + streakBonus + consistencyBonus)
        .clamp(0, 100)
        .toDouble();
  }

  String get recommendedStudyTime {
    if (_sessions.length < 3) return '8:00 AM - 10:00 AM';
    final hourMinutes = <int, int>{};
    for (final session in _sessions) {
      final hour = session.startTime.hour;
      hourMinutes[hour] =
          (hourMinutes[hour] ?? 0) + session.durationMinutes;
    }
    final bestHour = hourMinutes.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
    return '${_formatHour(bestHour)} - ${_formatHour(bestHour + 2)}';
  }

  String get subjectNeedingAttention {
    if (_subjects.isEmpty) return 'No subjects added';
    SubjectModel? weakest;
    double lowestRatio = double.infinity;
    for (final subject in _subjects) {
      final studied = subjectWiseMinutes[subject.name] ?? 0;
      final target = subject.targetHoursPerWeek * 60;
      if (target == 0) continue;
      final ratio = studied / target;
      if (ratio < lowestRatio) {
        lowestRatio = ratio;
        weakest = subject;
      }
    }
    return weakest?.name ?? 'All subjects on track';
  }

  String _formatHour(int hour) {
    final h = hour % 24;
    final period = h < 12 ? 'AM' : 'PM';
    final displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$displayHour:00 $period';
  }

  List<StudySessionModel> getSessionsForDate(DateTime date) =>
      _sessions
          .where((s) =>
              s.startTime.year == date.year &&
              s.startTime.month == date.month &&
              s.startTime.day == date.day)
          .toList();
}