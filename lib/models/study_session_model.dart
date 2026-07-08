class StudySessionModel {
  final String id;
  final String subjectId;
  final String subjectName;
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;
  final String? notes;
  final int focusScore;     // 0 to 100
  final bool isPomodoroSession;

  StudySessionModel({
    required this.id,
    required this.subjectId,
    required this.subjectName,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    this.notes,
    this.focusScore = 80,
    this.isPomodoroSession = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'subjectId': subjectId,
    'subjectName': subjectName,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'durationMinutes': durationMinutes,
    'notes': notes,
    'focusScore': focusScore,
    'isPomodoroSession': isPomodoroSession,
  };

  factory StudySessionModel.fromJson(Map<String, dynamic> json) =>
    StudySessionModel(
      id: json['id'],
      subjectId: json['subjectId'],
      subjectName: json['subjectName'],
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      durationMinutes: json['durationMinutes'],
      notes: json['notes'],
      focusScore: json['focusScore'] ?? 80,
      isPomodoroSession: json['isPomodoroSession'] ?? false,
    );
}