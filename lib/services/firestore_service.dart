import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── USER OPERATIONS ───────────────────────────────────────
  
  Future<void> saveUser({
    required String uid,
    required String name,
    required String email,
    required String course,
    required String semester,
    String department = '',
    String profileImage = '',
  }) async {
    await _firestore.collection("users").doc(uid).set({
      "id": uid,
      "name": name,
      "email": email,
      "course": course,
      "semester": semester,
      "department": department,
      "profileImage": profileImage,
      "streak": 0,
      "xp": 0,
      "level": 1,
      "unlockedBadges": [],
      "createdAt": FieldValue.serverTimestamp(),
      "pomodoroPreferences": {
        "focusMinutes": 25,
        "shortBreakMinutes": 5,
        "longBreakMinutes": 15,
        "roundsBeforeLongBreak": 4
      },
      "schedulePreferences": {
        "availableHours": [8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22],
        "preferredSubjects": [],
        "dailyFreeTime": 4.0,
        "weeklySchedule": {}
      },
      "settings": {
        "darkMode": false,
        "notificationsEnabled": true,
        "language": "English",
        "privacySettings": {
          "shareProgress": true
        }
      }
    });
  }

  Future<DocumentSnapshot> getUser(String uid) async {
    return await _firestore.collection("users").doc(uid).get();
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _firestore.collection("users").doc(uid).update(data);
  }

  // ── SUBJECT OPERATIONS ────────────────────────────────────
  
  Future<void> saveSubject(String uid, Map<String, dynamic> data) async {
    final String subjectId = data['id'];
    await _firestore
        .collection("subjects")
        .doc(subjectId)
        .set({...data, 'uid': uid});
  }

  Future<void> deleteSubject(String subjectId) async {
    await _firestore.collection("subjects").doc(subjectId).delete();
  }

  Stream<List<Map<String, dynamic>>> getSubjectsStream(String uid) {
    return _firestore
        .collection("subjects")
        .where("uid", isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.data()).toList());
  }

  // ── STUDY SESSION OPERATIONS ──────────────────────────────
  
  Future<void> saveSession(String uid, Map<String, dynamic> data) async {
    final String sessionId = data['id'];
    await _firestore
        .collection("study_sessions")
        .doc(sessionId)
        .set({...data, 'uid': uid});
  }

  Future<void> deleteSession(String sessionId) async {
    await _firestore.collection("study_sessions").doc(sessionId).delete();
  }

  Stream<List<Map<String, dynamic>>> getSessionsStream(String uid) {
    return _firestore
        .collection("study_sessions")
        .where("uid", isEqualTo: uid)
        // .orderBy("startTime", descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.data()).toList());
  }

  // ── GOAL OPERATIONS ───────────────────────────────────────
  
  Future<void> saveGoal(String uid, Map<String, dynamic> data) async {
    final String goalId = data['id'];
    await _firestore
        .collection("goals")
        .doc(goalId)
        .set({...data, 'uid': uid});
  }

  Future<void> deleteGoal(String goalId) async {
    await _firestore.collection("goals").doc(goalId).delete();
  }

  Stream<List<Map<String, dynamic>>> getGoalsStream(String uid) {
    return _firestore
        .collection("goals")
        .where("uid", isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.data()).toList());
  }

  // ── EXAM OPERATIONS ───────────────────────────────────────
  
  Future<void> saveExam(String uid, Map<String, dynamic> data) async {
    final String examId = data['id'];
    await _firestore
        .collection("exams")
        .doc(examId)
        .set({...data, 'uid': uid});
  }

  Future<void> deleteExam(String examId) async {
    await _firestore.collection("exams").doc(examId).delete();
  }

  Stream<List<Map<String, dynamic>>> getExamsStream(String uid) {
    return _firestore
        .collection("exams")
        .where("uid", isEqualTo: uid)
        // .orderBy("date", descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.data()).toList());
  }

  // ── TIMETABLE OPERATIONS ──────────────────────────────────
  
  Future<void> saveTimetable(String uid, Map<String, dynamic> data) async {
    await _firestore.collection("timetables").doc(uid).set({
      ...data,
      'uid': uid,
      'generatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<DocumentSnapshot> getTimetable(String uid) async {
    return await _firestore.collection("timetables").doc(uid).get();
  }

  Stream<DocumentSnapshot> getTimetableStream(String uid) {
    return _firestore.collection("timetables").doc(uid).snapshots();
  }

  // ── QUIZ OPERATIONS ───────────────────────────────────────
  
  Future<void> saveQuiz(String uid, Map<String, dynamic> data) async {
    final String quizId = data['id'];
    await _firestore
        .collection("quizzes")
        .doc(quizId)
        .set({...data, 'uid': uid, 'createdAt': FieldValue.serverTimestamp()});
  }

  Stream<List<Map<String, dynamic>>> getQuizzesStream(String uid) {
    return _firestore
        .collection("quizzes")
        .where("uid", isEqualTo: uid)
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.data()).toList());
  }

  // ── STUDY MATERIAL OPERATIONS ─────────────────────────────
  
  Future<void> saveStudyMaterial(String uid, Map<String, dynamic> data) async {
    final String materialId = data['id'];
    await _firestore
        .collection("study_materials")
        .doc(materialId)
        .set({...data, 'uid': uid, 'createdAt': FieldValue.serverTimestamp()});
  }

  Future<void> deleteStudyMaterial(String materialId) async {
    await _firestore.collection("study_materials").doc(materialId).delete();
  }

  Stream<List<Map<String, dynamic>>> getStudyMaterialsStream(String uid) {
    return _firestore
        .collection("study_materials")
        .where("uid", isEqualTo: uid)
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.data()).toList());
  }
}