import 'package:cloud_firestore/cloud_firestore.dart';

class ExamModel {
  final String id;
  final String subject;
  final DateTime date;
  final String time;
  final String location;
  final String? studyPlan;

  ExamModel({
    required this.id,
    required this.subject,
    required this.date,
    required this.time,
    required this.location,
    this.studyPlan,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'subject': subject,
    'date': date.toIso8601String(),
    'time': time,
    'location': location,
    'studyPlan': studyPlan,
  };

  factory ExamModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    if (json['date'] is Timestamp) {
      parsedDate = (json['date'] as Timestamp).toDate();
    } else if (json['date'] is String) {
      parsedDate = DateTime.parse(json['date']);
    } else {
      parsedDate = DateTime.now();
    }
    return ExamModel(
      id: json['id'],
      subject: json['subject'],
      date: parsedDate,
      time: json['time'] ?? '',
      location: json['location'] ?? '',
      studyPlan: json['studyPlan'],
    );
  }
}
