// lib/arc/chat/services/active_window_detector.dart
// Learns user's natural reflection windows from app usage patterns

import 'dart:math' as math;
import 'package:my_app/arc/internal/mira/journal_repository.dart';
import '../models/notification_models.dart';

/// Detects user's active reflection windows from journal entry timestamps
class ActiveWindowDetector {
  final JournalRepository _journalRepository;
  static const int _minEntriesForReliability = 10;
  static const int _observationPeriodDays = 60; // 1-2 months

  ActiveWindowDetector(this._journalRepository);

  /// Detect active windows from journal entry patterns
  Future<List<ActiveWindow>> detectActiveWindows() async {
    final allEntries = await _journalRepository.getAllJournalEntries();
    
    if (allEntries.length < _minEntriesForReliability) {
      return [];
    }

    // Filter to recent entries (last 60 days)
    final cutoffDate = DateTime.now().subtract(const Duration(days: _observationPeriodDays));
    final recentEntries = allEntries.where((e) => 
      e.createdAt.isAfter(cutoffDate)
    ).toList();

    if (recentEntries.isEmpty) {
      return [];
    }

    // Build hourly activity histogram
    final hourlyActivity = List<int>.filled(24, 0);
    for (final entry in recentEntries) {
      final hour = entry.createdAt.hour;
      hourlyActivity[hour]++;
    }

    // Find peak hours (top 2 hours with most activity)
    final hourScores = <int, int>{};
    for (int i = 0; i < 24; i++) {
      hourScores[i] = hourlyActivity[i];
    }

    final sortedHours = hourScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final windows = <ActiveWindow>[];

    // Create windows around top 2 peak hours
    for (int i = 0; i < math.min(2, sortedHours.length); i++) {
      final peakHour = sortedHours[i].key;
      final activity = sortedHours[i].value;

      // Only consider if there's meaningful activity (at least 3 entries)
      if (activity < 3) continue;

      // Create 2-hour window around peak
      final startHour = (peakHour - 1) % 24;
      final endHour = (peakHour + 1) % 24;

      // Calculate confidence based on activity level
      final totalActivity = recentEntries.length;
      final confidence = (activity / totalActivity).clamp(0.0, 1.0);

      windows.add(ActiveWindow(
        startTime: DateTime(2000, 1, 1, startHour, 0),
        endTime: DateTime(2000, 1, 1, endHour, 0),
        confidence: confidence,
        observationDays: _observationPeriodDays,
      ));
    }

    return windows;
  }

  /// Update active windows based on recent behavior
  Future<List<ActiveWindow>> updateActiveWindows(
    List<ActiveWindow> currentWindows,
  ) async {
    final detected = await detectActiveWindows();
    
    if (detected.isEmpty) {
      return currentWindows;
    }

    // Merge with existing windows (gradual shift, not drastic jumps)
    final merged = <ActiveWindow>[];
    
    for (final newWindow in detected) {
      // Find closest existing window
      ActiveWindow? closest;
      double? minDiff;
      
      for (final existing in currentWindows) {
        final diff = (existing.startTime.hour - newWindow.startTime.hour).abs();
        if (minDiff == null || diff < minDiff) {
          minDiff = diff.toDouble();
          closest = existing;
        }
      }

      if (closest != null && minDiff! < 3) {
        // Gradual shift: average the times
        final avgStartHour = ((closest.startTime.hour + newWindow.startTime.hour) / 2).round();
        final avgEndHour = ((closest.endTime.hour + newWindow.endTime.hour) / 2).round();
        
        merged.add(ActiveWindow(
          startTime: DateTime(2000, 1, 1, avgStartHour, 0),
          endTime: DateTime(2000, 1, 1, avgEndHour, 0),
          confidence: (closest.confidence + newWindow.confidence) / 2,
          observationDays: math.max(closest.observationDays, newWindow.observationDays),
        ));
      } else {
        // New window
        merged.add(newWindow);
      }
    }

    return merged.take(2).toList(); // Max 2 windows
  }
}

