import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class FCMService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  Future<void> init() async {
    if (kIsWeb) {
      // Notification settings for Web
      await _requestPermissions();
      return;
    }

    // Android/iOS initialization
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint("Notification clicked: ${details.payload}");
      },
    );

    // Request permissions
    await _requestPermissions();

    // Foreground listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("FCM Foreground message: ${message.notification?.title}");
      _showLocalNotification(
        id: message.hashCode,
        title: message.notification?.title ?? "Notification",
        body: message.notification?.body ?? "",
      );
    });

    // Background listener setup is handled in main.dart if required,
    // but the system will automatically deliver notification messages when app is closed.
  }

  Future<void> _requestPermissions() async {
    try {
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('User notification permission status: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
  }

  Future<String?> getToken() async {
    try {
      if (kIsWeb) {
        // VAPID key is required for Web notifications. The public key can be configured in firebase.json.
        return await _fcm.getToken();
      }
      return await _fcm.getToken();
    } catch (e) {
      debugPrint('Error fetching FCM Token: $e');
      return null;
    }
  }

  // Local Notification triggers (e.g. Pomodoro/Countdown Timer completions)
  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) {
      // Browser notification API fallback
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'study_tracker_channel',
      'Study Tracker Reminders',
      channelDescription: 'Notifications for timers, study reminders, and exams',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const platformDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      id,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  Future<void> triggerTimerNotification({
    required String title,
    required String body,
  }) async {
    await _showLocalNotification(
      id: DateTime.now().millisecond,
      title: title,
      body: body,
      payload: 'timer_complete',
    );
  }

  Future<void> triggerExamReminderNotification({
    required String subject,
    required int daysLeft,
  }) async {
    await _showLocalNotification(
      id: subject.hashCode,
      title: 'Exam Countdown: $subject',
      body: 'Only $daysLeft days left until your $subject exam! Keep studying! 📚',
      payload: 'exam_reminder',
    );
  }
}
