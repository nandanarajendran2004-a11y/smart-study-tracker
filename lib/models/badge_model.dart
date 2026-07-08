class BadgeModel {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final String requirement;   // What unlocks this badge
  bool isUnlocked;
  DateTime? unlockedAt;

  BadgeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.requirement,
    this.isUnlocked = false,
    this.unlockedAt,
  });
}