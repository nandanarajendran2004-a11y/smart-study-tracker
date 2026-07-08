class GoalModel {
  final String id;
  final String title;
  final int targetMinutes;
  int completedMinutes;
  final DateTime deadline;
  final String type; // 'daily', 'weekly', 'subject'
  final String? subjectId;

  GoalModel({
    required this.id,
    required this.title,
    required this.targetMinutes,
    this.completedMinutes = 0,
    required this.deadline,
    required this.type,
    this.subjectId,
  });

  double get progress => completedMinutes / targetMinutes;
  bool get isCompleted => completedMinutes >= targetMinutes;
  bool get isActive => DateTime.now().isBefore(deadline);

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'targetMinutes': targetMinutes,
    'completedMinutes': completedMinutes,
    'deadline': deadline.toIso8601String(),
    'type': type,
    'subjectId': subjectId,
  };

  factory GoalModel.fromJson(Map<String, dynamic> json) => GoalModel(
    id: json['id'],
    title: json['title'],
    targetMinutes: json['targetMinutes'],
    completedMinutes: json['completedMinutes'] ?? 0,
    deadline: DateTime.parse(json['deadline']),
    type: json['type'],
    subjectId: json['subjectId'],
  );
}