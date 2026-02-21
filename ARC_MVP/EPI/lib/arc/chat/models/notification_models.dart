// lib/arc/chat/models/notification_models.dart
// Data models for LUMARA notifications

import 'package:my_app/models/journal_entry_model.dart';

/// Time Echo reminder intervals
enum TimeEchoInterval {
  oneMonth,
  threeMonths,
  sixMonths,
  oneYear,
  twoYears,
  fiveYears,
  tenYears,
}

/// Active window for user reflection patterns
class ActiveWindow {
  final DateTime startTime; // e.g., 07:00
  final DateTime endTime;   // e.g., 09:00
  final double confidence;   // 0-1, how confident we are in this pattern
  final int observationDays; // Days of data used to detect this

  const ActiveWindow({
    required this.startTime,
    required this.endTime,
    required this.confidence,
    required this.observationDays,
  });

  bool contains(DateTime time) {
    final timeOfDay = TimeOfDay.fromDateTime(time);
    final startOfDay = TimeOfDay.fromDateTime(startTime);
    final endOfDay = TimeOfDay.fromDateTime(endTime);
    
    if (startOfDay.hour < endOfDay.hour) {
      return timeOfDay.hour >= startOfDay.hour && timeOfDay.hour < endOfDay.hour;
    } else {
      // Handles overnight windows (e.g., 22:00-02:00)
      return timeOfDay.hour >= startOfDay.hour || timeOfDay.hour < endOfDay.hour;
    }
  }
}

/// Abstinence window configuration
class AbstinenceWindow {
  final DateTime startTime;
  final DateTime endTime;
  final List<int> daysOfWeek; // 0=Sunday, 1=Monday, etc. Empty = all days
  final bool enabled;

  const AbstinenceWindow({
    required this.startTime,
    required this.endTime,
    required this.daysOfWeek,
    this.enabled = false,
  });

  bool isActive(DateTime now) {
    if (!enabled) return false;
    
    if (daysOfWeek.isNotEmpty) {
      final dayOfWeek = now.weekday % 7; // Convert to 0-6 (Sunday=0)
      if (!daysOfWeek.contains(dayOfWeek)) return false;
    }
    
    final nowTime = TimeOfDay.fromDateTime(now);
    final start = TimeOfDay.fromDateTime(startTime);
    final end = TimeOfDay.fromDateTime(endTime);
    
    if (start.hour < end.hour) {
      return nowTime.hour >= start.hour && nowTime.hour < end.hour;
    } else {
      return nowTime.hour >= start.hour || nowTime.hour < end.hour;
    }
  }
}

/// Time Echo notification
class TimeEchoNotification {
  final TimeEchoInterval interval;
  final DateTime targetDate;
  final String content;
  final JournalEntry? sourceEntry;
  final String? theme;
  final DateTime scheduledFor;

  const TimeEchoNotification({
    required this.interval,
    required this.targetDate,
    required this.content,
    this.sourceEntry,
    this.theme,
    required this.scheduledFor,
  });
}

/// Active window reminder notification
class ActiveWindowNotification {
  final ActiveWindow window;
  final String content;
  final DateTime scheduledFor;
  final String? recentTheme;
  final String? openLoop;

  const ActiveWindowNotification({
    required this.window,
    required this.content,
    required this.scheduledFor,
    this.recentTheme,
    this.openLoop,
  });
}

/// Helper class for TimeOfDay
class TimeOfDay {
  final int hour;
  final int minute;

  const TimeOfDay({required this.hour, required this.minute});

  factory TimeOfDay.fromDateTime(DateTime dateTime) {
    return TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
  }
}

