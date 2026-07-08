import 'package:flutter/material.dart';

class SubjectModel {
  final String id;
  final String name;
  final int colorValue;       // Store color as int
  final int targetHoursPerWeek;
  int totalMinutesStudied;

  SubjectModel({
    required this.id,
    required this.name,
    required this.colorValue,
    this.targetHoursPerWeek = 5,
    this.totalMinutesStudied = 0,
  });

  // Helper to get Flutter Color from stored int
  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'colorValue': colorValue,
    'targetHoursPerWeek': targetHoursPerWeek,
    'totalMinutesStudied': totalMinutesStudied,
  };

  factory SubjectModel.fromJson(Map<String, dynamic> json) => SubjectModel(
    id: json['id'],
    name: json['name'],
    colorValue: json['colorValue'],
    targetHoursPerWeek: json['targetHoursPerWeek'] ?? 5,
    totalMinutesStudied: json['totalMinutesStudied'] ?? 0,
  );
}