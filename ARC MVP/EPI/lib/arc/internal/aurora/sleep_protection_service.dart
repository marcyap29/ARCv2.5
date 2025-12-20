// lib/arc/chat/services/sleep_protection_service.dart
// Manages sleep windows and abstinence periods

import 'package:my_app/arc/internal/mira/journal_repository.dart';
import '../models/notification_models.dart';

/// Service for detecting and managing sleep/abstinence windows
class SleepProtectionService {
  final JournalRepository _journalRepository;
  
  // Default sleep window (22:00-07:00)
  static const int _defaultSleepStart = 22;
  static const int _defaultSleepEnd = 7;

  SleepProtectionService(this._journalRepository);

  /// Detect user's sleep window from journal entry patterns
  Future<SleepWindow> detectSleepWindow() async {
    final allEntries = await _journalRepository.getAllJournalEntries();
    
    if (allEntries.isEmpty) {
      return _getDefaultSleepWindow();
    }

    // Analyze entry timestamps to find quiet periods
    final hourlyActivity = List<int>.filled(24, 0);
    for (final entry in allEntries) {
      final hour = entry.createdAt.hour;
      hourlyActivity[hour]++;
    }

    // Find the longest quiet period (lowest activity)
    int quietStart = _defaultSleepStart;
    int quietEnd = _defaultSleepEnd;
    int minActivity = hourlyActivity[_defaultSleepStart];

    // Check all possible sleep windows
    for (int start = 0; start < 24; start++) {
      int windowActivity = 0;
      int windowLength = 0;
      
      // Calculate activity for a 9-hour window starting at 'start'
      for (int i = 0; i < 9; i++) {
        final hour = (start + i) % 24;
        windowActivity += hourlyActivity[hour];
        windowLength++;
      }
      
      final avgActivity = windowActivity / windowLength;
      if (avgActivity < minActivity) {
        minActivity = avgActivity.toInt();
        quietStart = start;
        quietEnd = (start + 9) % 24;
      }
    }

    return SleepWindow(
      startHour: quietStart,
      endHour: quietEnd,
      confidence: 1.0 - (minActivity / allEntries.length).clamp(0.0, 1.0),
    );
  }

  /// Check if current time is in sleep window
  bool isSleepTime(DateTime now, SleepWindow? sleepWindow) {
    final window = sleepWindow ?? _getDefaultSleepWindow();
    final hour = now.hour;
    
    if (window.startHour < window.endHour) {
      return hour >= window.startHour && hour < window.endHour;
    } else {
      // Overnight window (e.g., 22:00-07:00)
      return hour >= window.startHour || hour < window.endHour;
    }
  }

  /// Check if time is in abstinence window
  bool isAbstinenceTime(DateTime now, AbstinenceWindow? abstinenceWindow) {
    if (abstinenceWindow == null || !abstinenceWindow.enabled) {
      return false;
    }
    return abstinenceWindow.isActive(now);
  }

  /// Check if notification should be suppressed
  bool shouldSuppressNotification(
    DateTime scheduledTime, {
    SleepWindow? sleepWindow,
    AbstinenceWindow? abstinenceWindow,
  }) {
    return isSleepTime(scheduledTime, sleepWindow) ||
           isAbstinenceTime(scheduledTime, abstinenceWindow);
  }

  SleepWindow _getDefaultSleepWindow() {
    return SleepWindow(
      startHour: _defaultSleepStart,
      endHour: _defaultSleepEnd,
      confidence: 0.5,
    );
  }
}

/// Represents a sleep window
class SleepWindow {
  final int startHour; // 0-23
  final int endHour;   // 0-23
  final double confidence; // 0-1

  const SleepWindow({
    required this.startHour,
    required this.endHour,
    required this.confidence,
  });
}

