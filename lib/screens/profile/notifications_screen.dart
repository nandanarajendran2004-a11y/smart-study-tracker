import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifications = [
      {
        "icon": Icons.alarm,
        "title": "Study Reminder",
        "subtitle": "It's time for your evening study session.",
        "color": Colors.blue,
      },
      {
        "icon": Icons.emoji_events,
        "title": "Badge Unlocked",
        "subtitle": "Congratulations! You earned the Focused Learner badge.",
        "color": Colors.orange,
      },
      {
        "icon": Icons.flag,
        "title": "Goal Completed",
        "subtitle": "You completed your Daily Study Goal.",
        "color": Colors.green,
      },
      {
        "icon": Icons.calendar_today,
        "title": "Upcoming Deadline",
        "subtitle": "Database Systems assignment due tomorrow.",
        "color": Colors.red,
      },
      {
        "icon": Icons.update,
        "title": "Weekly Report Ready",
        "subtitle": "Your weekly study report is available.",
        "color": Colors.purple,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Notifications",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final item = notifications[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: CircleAvatar(
                radius: 24,
                backgroundColor:
                    (item["color"] as Color).withValues(alpha: 0.15),
                child: Icon(
                  item["icon"] as IconData,
                  color: item["color"] as Color,
                ),
              ),
              title: Text(
                item["title"] as String,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  item["subtitle"] as String,
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          );
        },
      ),
    );
  }
}