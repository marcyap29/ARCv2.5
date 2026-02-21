// lib/chronicle/dual/services/intelligence_summary_schedule_preferences.dart
//
// User preferences for when to auto-regenerate the Intelligence Summary
// (e.g. daily at 22:00, weekly on Sunday at 21:00). Only the user sees the summary.

import 'package:shared_preferences/shared_preferences.dart';

/// Cadence for Intelligence Summary refresh (like Claude's project memory).
enum IntelligenceSummaryCadence {
  daily,
  weekly,
  monthly,
}

extension IntelligenceSummaryCadenceExtension on IntelligenceSummaryCadence {
  String get label {
    switch (this) {
      case IntelligenceSummaryCadence.daily:
        return 'Daily';
      case IntelligenceSummaryCadence.weekly:
        return 'Weekly';
      case IntelligenceSummaryCadence.monthly:
        return 'Monthly';
    }
  }

  String get description {
    switch (this) {
      case IntelligenceSummaryCadence.daily:
        return 'Regenerate every day';
      case IntelligenceSummaryCadence.weekly:
        return 'Regenerate once a week';
      case IntelligenceSummaryCadence.monthly:
        return 'Regenerate once a month';
    }
  }

  Duration get interval {
    switch (this) {
      case IntelligenceSummaryCadence.daily:
        return const Duration(days: 1);
      case IntelligenceSummaryCadence.weekly:
        return const Duration(days: 7);
      case IntelligenceSummaryCadence.monthly:
        return const Duration(days: 30);
    }
  }
}

const String _kCadenceKey = 'intelligence_summary_cadence';
const String _kHourKey = 'intelligence_summary_hour';
const String _kMinuteKey = 'intelligence_summary_minute';
const String _kLastGeneratedAtKey = 'intelligence_summary_last_generated_at';

/// Default: daily at 22:00 (10 PM).
const int _defaultHour = 22;
const int _defaultMinute = 0;

/// Persists and reads Intelligence Summary refresh schedule.
/// Used by scheduler to decide when to run generation (only user sees the result).
class IntelligenceSummarySchedulePreferences {
  /// Get cadence (default: daily).
  static Future<IntelligenceSummaryCadence> getCadence() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_kCadenceKey);
    if (value == null) return IntelligenceSummaryCadence.daily;
    switch (value) {
      case 'daily':
        return IntelligenceSummaryCadence.daily;
      case 'weekly':
        return IntelligenceSummaryCadence.weekly;
      case 'monthly':
        return IntelligenceSummaryCadence.monthly;
      default:
        return IntelligenceSummaryCadence.daily;
    }
  }

  static Future<void> setCadence(IntelligenceSummaryCadence cadence) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCadenceKey, cadence.name);
  }

  /// Preferred hour (0–23). Default 22.
  static Future<int> getHour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kHourKey) ?? _defaultHour;
  }

  static Future<void> setHour(int hour) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kHourKey, hour.clamp(0, 23));
  }

  /// Preferred minute (0–59). Default 0.
  static Future<int> getMinute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kMinuteKey) ?? _defaultMinute;
  }

  static Future<void> setMinute(int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kMinuteKey, minute.clamp(0, 59));
  }

  /// Last time the summary was generated (any trigger). Used to compute next run.
  static Future<DateTime?> getLastGeneratedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kLastGeneratedAtKey);
    if (s == null) return null;
    return DateTime.tryParse(s);
  }

  static Future<void> setLastGeneratedAt(DateTime when) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastGeneratedAtKey, when.toUtc().toIso8601String());
  }

  /// Next scheduled run time (>= [now]). Uses preferred hour/minute and cadence.
  static Future<DateTime> getNextScheduledTime({
    DateTime? now,
    DateTime? lastGenerated,
  }) async {
    now ??= DateTime.now();
    final hour = await getHour();
    final minute = await getMinute();
    final cadence = await getCadence();

    DateTime next;
    switch (cadence) {
      case IntelligenceSummaryCadence.daily:
        next = DateTime(now.year, now.month, now.day, hour, minute);
        if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
        break;
      case IntelligenceSummaryCadence.weekly:
        final from = lastGenerated ?? now;
        next = DateTime(from.year, from.month, from.day, hour, minute).add(cadence.interval);
        while (!next.isAfter(now)) {
          next = next.add(const Duration(days: 7));
        }
        break;
      case IntelligenceSummaryCadence.monthly:
        final from = lastGenerated ?? now;
        next = DateTime(from.year, from.month, from.day, hour, minute).add(cadence.interval);
        while (!next.isAfter(now)) {
          next = DateTime(next.year, next.month + 1, next.day.clamp(1, 28), hour, minute);
        }
        break;
    }
    return next;
  }

  /// True if a run is due: now >= next scheduled time (or never run).
  static Future<bool> isRunDue({DateTime? now}) async {
    now ??= DateTime.now();
    final last = await getLastGeneratedAt();
    final next = await getNextScheduledTime(now: now, lastGenerated: last);
    return now.isAfter(next) || now.isAtSameMomentAs(next);
  }
}
