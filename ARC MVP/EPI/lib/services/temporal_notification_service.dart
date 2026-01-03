// lib/services/temporal_notification_service.dart
// Service for scheduling and managing temporal notifications

import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/temporal_notifications/resonance_prompt.dart';
import '../models/temporal_notifications/thread_review.dart';
import '../models/temporal_notifications/arc_view.dart';
import '../models/temporal_notifications/becoming_summary.dart';
import '../models/temporal_notifications/notification_preferences.dart';
import 'notification_content_generator.dart';
import 'package:flutter/material.dart';
import '../app/app.dart' show navigatorKey;
import '../ui/journal/journal_screen.dart';
import '../shared/ui/home/home_view.dart';

/// Service for scheduling and managing temporal notifications
class TemporalNotificationService {
  static final TemporalNotificationService _instance = TemporalNotificationService._internal();
  factory TemporalNotificationService() => _instance;
  TemporalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final NotificationContentGenerator _contentGenerator = NotificationContentGenerator();
  bool _initialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/New_York')); // TODO: Get from user settings

    // Initialize Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Initialize iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );

    _initialized = true;
  }

  /// Schedule all notification cadences for a user
  Future<void> scheduleNotifications(String userId) async {
    await initialize();
    
    final prefs = await NotificationPreferences.load();
    
    if (prefs.dailyEnabled) {
      await _scheduleDailyNotifications(userId, prefs);
    }
    
    if (prefs.monthlyEnabled) {
      await _scheduleMonthlyNotification(userId, prefs);
    }
    
    if (prefs.sixMonthEnabled) {
      await _scheduleSixMonthNotification(userId, prefs);
    }
    
    if (prefs.yearlyEnabled) {
      await _scheduleYearlyNotification(userId, prefs);
    }
  }

  /// Schedule daily resonance prompts
  Future<void> _scheduleDailyNotifications(String userId, NotificationPreferences prefs) async {
    // Cancel existing daily notifications
    await _notifications.cancel(1);
    
    // Schedule daily notification at preferred time
    final scheduledTime = _getNextScheduledTime(prefs.dailyTime);
    
    await _notifications.zonedSchedule(
      1, // ID for daily notifications
      'ARC Resonance',
      null, // Title - will be set when generating content
      _tzDateTimeFromTimeOfDay(scheduledTime, prefs.dailyTime),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_resonance',
          'Daily Resonance Prompts',
          channelDescription: 'Personalized prompts based on your journal entries',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: jsonEncode({
        'type': 'daily_resonance',
        'userId': userId,
      }),
    );
    
    // Generate and update notification content immediately for today
    await _updateDailyNotificationContent(userId);
  }

  /// Update daily notification with generated content
  Future<void> _updateDailyNotificationContent(String userId) async {
    try {
      final prompt = await _contentGenerator.generateResonancePrompt(userId);
      
      // Update the scheduled notification with actual content
      await _notifications.zonedSchedule(
        1,
        'ARC Resonance',
        prompt.promptText,
        tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)), // Show soon for testing
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_resonance',
            'Daily Resonance Prompts',
            channelDescription: 'Personalized prompts based on your journal entries',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: jsonEncode({
          'type': 'daily_resonance',
          'userId': userId,
          'promptId': prompt.sourceEntryId,
        }),
      );
    } catch (e) {
      print('Error updating daily notification content: $e');
    }
  }

  /// Schedule monthly thread review
  Future<void> _scheduleMonthlyNotification(String userId, NotificationPreferences prefs) async {
    await _notifications.cancel(2);
    
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, prefs.monthlyDay);
    final scheduledTime = tz.TZDateTime.from(nextMonth, tz.local);
    
    await _notifications.zonedSchedule(
      2,
      'ARC Monthly Review',
      'Your monthly thread review is ready',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'monthly_review',
          'Monthly Thread Reviews',
          channelDescription: 'Monthly synthesis of your emotional threads',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({
        'type': 'monthly_review',
        'userId': userId,
      }),
    );
  }

  /// Schedule 6-month arc view
  Future<void> _scheduleSixMonthNotification(String userId, NotificationPreferences prefs) async {
    await _notifications.cancel(3);
    
    // Schedule for 6 months from now
    final now = DateTime.now();
    final sixMonthsFromNow = DateTime(now.year, now.month + 6, 1, 9, 0);
    final scheduledTime = tz.TZDateTime.from(sixMonthsFromNow, tz.local);
    
    await _notifications.zonedSchedule(
      3,
      'ARC 6-Month View',
      'Your developmental trajectory is ready',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'six_month_arc',
          '6-Month Arc Views',
          channelDescription: 'Your developmental trajectory over 6 months',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({
        'type': 'six_month_arc',
        'userId': userId,
      }),
    );
  }

  /// Schedule yearly becoming summary
  Future<void> _scheduleYearlyNotification(String userId, NotificationPreferences prefs) async {
    await _notifications.cancel(4);
    
    // Schedule for January 1st of next year
    final now = DateTime.now();
    final nextYear = DateTime(now.year + 1, 1, 1, 9, 0);
    final scheduledTime = tz.TZDateTime.from(nextYear, tz.local);
    
    await _notifications.zonedSchedule(
      4,
      'ARC Year in Review',
      'Your yearly becoming summary is ready',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'yearly_summary',
          'Yearly Becoming Summaries',
          channelDescription: 'Your year-long developmental narrative',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({
        'type': 'yearly_summary',
        'userId': userId,
        'year': now.year + 1,
      }),
    );
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications(String userId) async {
    await _notifications.cancelAll();
  }

  /// Update notification preferences and reschedule
  Future<void> updatePreferences(NotificationPreferences prefs) async {
    await prefs.save();
    // Reschedule with new preferences
    // Note: userId should be retrieved from auth service
    // For now, we'll need to pass it in
  }

  /// Handle notification tap with deep linking
  void _handleNotificationTap(NotificationResponse response) {
    if (response.payload == null) return;
    
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      final type = data['type'] as String;
      
      final navigator = navigatorKey.currentState;
      if (navigator == null) {
        print('Navigator not available for notification tap');
        return;
      }
      
      // Navigate to appropriate screen based on notification type
      switch (type) {
        case 'daily_resonance':
          // Navigate to journal screen, optionally with prompt
          final promptText = data['prompt'] as String?;
          navigator.push(
            MaterialPageRoute(
              builder: (context) => JournalScreen(
                initialContent: promptText,
              ),
            ),
          );
          break;
          
        case 'monthly_review':
          // Navigate to Phase tab (index 1) in HomeView
          // Since we can't directly control tabs, navigate to home and show a message
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeView(initialTab: 1)),
            (route) => false,
          );
          // TODO: Show monthly review dialog or bottom sheet when review screens are created
          break;
          
        case 'six_month_arc':
          // Navigate to Phase tab (index 1) in HomeView
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeView(initialTab: 1)),
            (route) => false,
          );
          // TODO: Show 6-month arc view when review screens are created
          break;
          
        case 'yearly_summary':
          // Navigate to Phase tab (index 1) in HomeView
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeView(initialTab: 1)),
            (route) => false,
          );
          // TODO: Show yearly summary when review screens are created
          break;
          
        default:
          print('Unknown notification type: $type');
      }
    } catch (e) {
      print('Error handling notification tap: $e');
    }
  }

  /// Generate content for each notification type (called when notification fires)
  Future<ResonancePrompt> generateDailyPrompt(String userId) async {
    return await _contentGenerator.generateResonancePrompt(userId);
  }

  Future<ThreadReview> generateMonthlyReview(String userId) async {
    return await _contentGenerator.generateThreadReview(userId);
  }

  Future<ArcView> generateSixMonthView(String userId) async {
    return await _contentGenerator.generateArcView(userId);
  }

  Future<BecomingSummary> generateYearlySummary(String userId) async {
    return await _contentGenerator.generateBecomingSummary(userId);
  }

  // Helper methods

  DateTime _getNextScheduledTime(TimeOfDay time) {
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    
    // If time has passed today, schedule for tomorrow
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    
    return scheduled;
  }

  tz.TZDateTime _tzDateTimeFromTimeOfDay(DateTime dateTime, TimeOfDay time) {
    return tz.TZDateTime(
      tz.local,
      dateTime.year,
      dateTime.month,
      dateTime.day,
      time.hour,
      time.minute,
    );
  }
}

