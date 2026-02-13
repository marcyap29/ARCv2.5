// lib/arc/chat/services/lumara_notification_service.dart
// Main notification service for LUMARA guidance and reminders

import 'dart:async';
import 'package:my_app/arc/internal/mira/journal_repository.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/arc/internal/aurora/active_window_detector.dart';
import 'package:my_app/arc/internal/aurora/sleep_protection_service.dart';
import 'package:my_app/arc/chat/models/notification_models.dart';
import 'package:my_app/aurora/services/circadian_profile_service.dart';
import 'package:intl/intl.dart';

/// Main notification service for LUMARA
/// Coordinates Time Echo reminders, Active Window reminders, and sleep protection
class LumaraNotificationService {
  final JournalRepository _journalRepository;
  final ActiveWindowDetector _windowDetector;
  final SleepProtectionService _sleepProtection;
  final CircadianProfileService _circadianService;

  LumaraNotificationService({
    required JournalRepository journalRepository,
    ActiveWindowDetector? windowDetector,
    SleepProtectionService? sleepProtection,
    CircadianProfileService? circadianService,
  }) : _journalRepository = journalRepository,
       _windowDetector = windowDetector ?? ActiveWindowDetector(journalRepository),
       _sleepProtection = sleepProtection ?? SleepProtectionService(journalRepository),
       _circadianService = circadianService ?? CircadianProfileService();

  /// Schedule Time Echo reminders for all intervals
  Future<List<TimeEchoNotification>> scheduleTimeEchoReminders({
    required DateTime baseDate,
    JournalEntry? sourceEntry,
  }) async {
    final reminders = <TimeEchoNotification>[];
    final intervals = TimeEchoInterval.values;

    for (final interval in intervals) {
      final targetDate = _calculateTargetDate(baseDate, interval);
      final content = await _generateTimeEchoContent(sourceEntry, interval, targetDate);
      
      // Schedule for the target date, but respect active windows
      final scheduledTime = await _scheduleInActiveWindow(targetDate);
      
      reminders.add(TimeEchoNotification(
        interval: interval,
        targetDate: targetDate,
        content: content,
        sourceEntry: sourceEntry,
        scheduledFor: scheduledTime,
      ));
    }

    return reminders;
  }

  /// Schedule daily active window reminders
  Future<List<ActiveWindowNotification>> scheduleActiveWindowReminders({
    required DateTime startDate,
    required int daysAhead,
  }) async {
    final reminders = <ActiveWindowNotification>[];
    final windows = await _windowDetector.detectActiveWindows();

    if (windows.isEmpty) {
      return reminders;
    }

    for (int day = 0; day < daysAhead; day++) {
      final targetDate = startDate.add(Duration(days: day));
      
      for (final window in windows) {
        // Schedule reminder at start of active window
        final scheduledTime = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          window.startTime.hour,
          window.startTime.minute,
        );

        // Check if we should suppress (sleep/abstinence)
        final sleepWindow = await _sleepProtection.detectSleepWindow();
        if (_sleepProtection.shouldSuppressNotification(
          scheduledTime,
          sleepWindow: sleepWindow,
        )) {
          continue;
        }

        final content = await _generateActiveWindowContent(window, targetDate);
        
        reminders.add(ActiveWindowNotification(
          window: window,
          content: content,
          scheduledFor: scheduledTime,
        ));
      }
    }

    return reminders;
  }

  /// Generate Time Echo notification content
  Future<String> _generateTimeEchoContent(
    JournalEntry? sourceEntry,
    TimeEchoInterval interval,
    DateTime targetDate,
  ) async {
    final intervalText = _formatInterval(interval);
    final dateText = DateFormat('MMMM d, yyyy').format(targetDate);

    if (sourceEntry != null) {
      // Use entry content
      final preview = sourceEntry.content.length > 100
          ? sourceEntry.content.substring(0, 100) + '...'
          : sourceEntry.content;

      return 'Time Echo: $intervalText ago, you wrote:\n\n"$preview"\n\n'
          'Would you like to reflect on how this has changed?';
    } else {
      // Generic reminder
      return 'Time Echo: $intervalText ago ($dateText), you were reflecting on something. '
          'Would you like to see what you were thinking about then?';
    }
  }

  /// Generate Active Window reminder content
  Future<String> _generateActiveWindowContent(
    ActiveWindow window,
    DateTime targetDate,
  ) async {
    // Check for recent themes or open loops
    final allEntries = await _journalRepository.getAllJournalEntries();
    final recentEntries = allEntries
        .where((e) => e.createdAt.isAfter(
          DateTime.now().subtract(const Duration(days: 7))
        ))
        .toList();

    String? recentTheme;
    if (recentEntries.isNotEmpty) {
      final keywords = recentEntries
          .expand((e) => e.keywords)
          .toList();
      if (keywords.isNotEmpty) {
        // Get most common keyword
        final counts = <String, int>{};
        for (final kw in keywords) {
          counts[kw] = (counts[kw] ?? 0) + 1;
        }
        final sorted = counts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        if (sorted.isNotEmpty) {
          recentTheme = sorted.first.key;
        }
      }
    }

    if (recentTheme != null) {
      return 'Your reflection window is open. You\'ve been thinking about "$recentTheme" recently. '
          'Would you like to continue that thread?';
    } else {
      return 'Your reflection window is open. Would you like to check in with yourself?';
    }
  }

  /// Calculate target date for Time Echo interval
  DateTime _calculateTargetDate(DateTime baseDate, TimeEchoInterval interval) {
    switch (interval) {
      case TimeEchoInterval.oneMonth:
        return DateTime(baseDate.year, baseDate.month + 1, baseDate.day);
      case TimeEchoInterval.threeMonths:
        return DateTime(baseDate.year, baseDate.month + 3, baseDate.day);
      case TimeEchoInterval.sixMonths:
        return DateTime(baseDate.year, baseDate.month + 6, baseDate.day);
      case TimeEchoInterval.oneYear:
        return DateTime(baseDate.year + 1, baseDate.month, baseDate.day);
      case TimeEchoInterval.twoYears:
        return DateTime(baseDate.year + 2, baseDate.month, baseDate.day);
      case TimeEchoInterval.fiveYears:
        return DateTime(baseDate.year + 5, baseDate.month, baseDate.day);
      case TimeEchoInterval.tenYears:
        return DateTime(baseDate.year + 10, baseDate.month, baseDate.day);
    }
  }

  /// Format interval as text
  String _formatInterval(TimeEchoInterval interval) {
    switch (interval) {
      case TimeEchoInterval.oneMonth:
        return '1 month';
      case TimeEchoInterval.threeMonths:
        return '3 months';
      case TimeEchoInterval.sixMonths:
        return '6 months';
      case TimeEchoInterval.oneYear:
        return '1 year';
      case TimeEchoInterval.twoYears:
        return '2 years';
      case TimeEchoInterval.fiveYears:
        return '5 years';
      case TimeEchoInterval.tenYears:
        return '10 years';
    }
  }

  /// Schedule notification in an active window
  Future<DateTime> _scheduleInActiveWindow(DateTime targetDate) async {
    final windows = await _windowDetector.detectActiveWindows();
    
    if (windows.isEmpty) {
      // Default to 9 AM if no windows detected
      return DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        9,
        0,
      );
    }

    // Use the most confident window
    windows.sort((a, b) => b.confidence.compareTo(a.confidence));
    final bestWindow = windows.first;

    return DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      bestWindow.startTime.hour,
      bestWindow.startTime.minute,
    );
  }

  /// Check if notification should be sent (respects sleep/abstinence)
  Future<bool> shouldSendNotification(DateTime scheduledTime) async {
    final sleepWindow = await _sleepProtection.detectSleepWindow();
    
    if (_sleepProtection.shouldSuppressNotification(
      scheduledTime,
      sleepWindow: sleepWindow,
    )) {
      return false;
    }

    // Check circadian context
    final allEntries = await _journalRepository.getAllJournalEntries();
    final circadianContext = await _circadianService.compute(allEntries);
    
    // Don't send during evening if user is in low-energy phase
    if (circadianContext.window == 'evening' && 
        scheduledTime.hour >= 20) {
      return false;
    }

    return true;
  }
}

