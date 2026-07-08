import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReminderService {
  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;
  ReminderService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _reminderEnabledKey = 'study_reminder_enabled';
  static const String _reminderHourKey = 'study_reminder_hour';
  static const String _reminderMinuteKey = 'study_reminder_minute';

  /// Initialize the reminder service
  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(initSettings);
  }

  /// Get saved reminder preferences
  Future<Map<String, dynamic>> getReminderPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'enabled': prefs.getBool(_reminderEnabledKey) ?? false,
      'hour': prefs.getInt(_reminderHourKey) ?? 20, // Default 8 PM
      'minute': prefs.getInt(_reminderMinuteKey) ?? 0,
    };
  }

  /// Save reminder preferences and schedule/cancel accordingly
  Future<void> setReminderPreferences({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reminderEnabledKey, enabled);
    await prefs.setInt(_reminderHourKey, hour);
    await prefs.setInt(_reminderMinuteKey, minute);

    if (enabled) {
      await _scheduleDailyReminder(hour, minute);
    } else {
      await cancelReminder();
    }
  }

  /// Schedule a daily study reminder notification
  Future<void> _scheduleDailyReminder(int hour, int minute) async {
    // Cancel any existing reminders first
    await cancelReminder();

    // Calculate the next occurrence of the reminder time
    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);

    // If the time has already passed today, schedule for tomorrow
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    // Show a one-time notification as a reminder
    // (For true recurring, platform-specific scheduling like Android AlarmManager is needed)
    final delay = scheduledTime.difference(now);

    // We'll use a simple delayed future approach for the current session
    // In production, you'd use android_alarm_manager_plus or workmanager
    Future.delayed(delay, () async {
      await _showReminderNotification();
    });

    debugPrint(
      'Study reminder scheduled for ${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')} '
      '(in ${delay.inMinutes} minutes)',
    );
  }

  /// Show the study reminder notification
  Future<void> _showReminderNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'study_reminder_channel',
      'Study Reminders',
      channelDescription: 'Daily study reminder notifications',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      1001, // Fixed ID for study reminder
      'Time to Study! 📚',
      'Your daily study session awaits. Stay consistent and keep your streak going! 🔥',
      platformDetails,
      payload: 'study_reminder',
    );
  }

  /// Cancel all scheduled reminders
  Future<void> cancelReminder() async {
    await _localNotifications.cancel(1001);
  }

  /// Format time for display
  static String formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }
}
