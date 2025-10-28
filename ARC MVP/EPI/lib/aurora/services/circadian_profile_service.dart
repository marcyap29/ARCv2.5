/// AURORA - Circadian Profile Service
/// 
/// Service for computing circadian context from journal entry timestamps

import 'dart:math';
import 'package:collection/collection.dart';
import '../../models/journal_entry_model.dart';
import '../models/circadian_context.dart';

/// Service for computing circadian context and chronotype from journal entries
class CircadianProfileService {
  static const double _smoothFactor = 0.25;
  static const int _minEntriesForReliability = 8;

  /// Compute circadian context from journal entries
  Future<CircadianContext> compute(List<JournalEntry> entries) async {
    if (entries.isEmpty) {
      return _getDefaultContext();
    }

    // Sort entries by creation time
    final sortedEntries = List<JournalEntry>.from(entries)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Compute hourly activity histogram
    final hourlyActivity = _computeHourlyActivity(sortedEntries);
    
    // Compute chronotype from peak activity
    final chronotype = _computeChronotype(hourlyActivity);
    
    // Compute rhythm score (concentration measure)
    final rhythmScore = _computeRhythmScore(hourlyActivity);
    
    // Get current time window
    final window = _getCurrentWindow();

    return CircadianContext(
      window: window,
      chronotype: chronotype,
      rhythmScore: rhythmScore,
    );
  }

  /// Compute circadian profile with detailed hourly activity curve
  Future<CircadianProfile> computeProfile(List<JournalEntry> entries) async {
    if (entries.isEmpty) {
      return _getDefaultProfile();
    }

    final sortedEntries = List<JournalEntry>.from(entries)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final hourlyActivity = _computeHourlyActivity(sortedEntries);
    final chronotype = _computeChronotype(hourlyActivity);
    final rhythmScore = _computeRhythmScore(hourlyActivity);

    return CircadianProfile(
      chronotype: chronotype,
      hourlyActivity: hourlyActivity,
      rhythmScore: rhythmScore,
      lastUpdated: DateTime.now(),
      entryCount: entries.length,
    );
  }

  /// Compute hourly activity histogram from journal entries
  List<double> _computeHourlyActivity(List<JournalEntry> entries) {
    final hourly = List<double>.filled(24, 0.0);
    
    for (final entry in entries) {
      // Convert to local time if needed
      final localTime = entry.createdAt.toLocal();
      hourly[localTime.hour] += 1.0;
    }
    
    // Normalize by total entries
    final total = hourly.sum;
    if (total == 0) return hourly;
    
    return hourly.map((count) => count / total).toList();
  }

  /// Apply smoothing to hourly activity curve
  List<double> _applySmoothing(List<double> hourly) {
    final smoothed = List<double>.from(hourly);
    
    // Apply exponential smoothing
    for (int i = 1; i < 24; i++) {
      smoothed[i] = _smoothFactor * hourly[i] + (1 - _smoothFactor) * smoothed[i - 1];
    }
    
    return smoothed;
  }

  /// Compute chronotype from peak activity hour
  String _computeChronotype(List<double> hourlyActivity) {
    final smoothed = _applySmoothing(hourlyActivity);
    
    // Find peak hour
    double maxActivity = smoothed[0];
    int peakHour = 0;
    
    for (int i = 1; i < smoothed.length; i++) {
      if (smoothed[i] > maxActivity) {
        maxActivity = smoothed[i];
        peakHour = i;
      }
    }
    
    // Classify chronotype based on peak hour
    if (peakHour < 11) {
      return 'morning';
    } else if (peakHour < 17) {
      return 'balanced';
    } else {
      return 'evening';
    }
  }

  /// Compute rhythm score (concentration measure)
  double _computeRhythmScore(List<double> hourlyActivity) {
    final smoothed = _applySmoothing(hourlyActivity);
    
    // Find peak activity
    final peakActivity = smoothed.reduce(max);
    
    // Calculate mean activity
    final meanActivity = smoothed.sum / 24.0;
    
    // Rhythm score is based on how much peak exceeds mean
    // Higher peak relative to mean = more concentrated activity = higher rhythm score
    final concentration = (peakActivity - meanActivity) * 2.0;
    
    return concentration.clamp(0.0, 1.0);
  }

  /// Get current time window
  String _getCurrentWindow() {
    final now = DateTime.now();
    final hour = now.hour;
    
    if (hour < 11) {
      return 'morning';
    } else if (hour < 17) {
      return 'afternoon';
    } else {
      return 'evening';
    }
  }

  /// Get default context when no entries are available
  CircadianContext _getDefaultContext() {
    return CircadianContext(
      window: _getCurrentWindow(),
      chronotype: 'balanced',
      rhythmScore: 0.5,
    );
  }

  /// Get default profile when no entries are available
  CircadianProfile _getDefaultProfile() {
    return CircadianProfile(
      chronotype: 'balanced',
      hourlyActivity: List.filled(24, 1.0 / 24.0), // Uniform distribution
      rhythmScore: 0.5,
      lastUpdated: DateTime.now(),
      entryCount: 0,
    );
  }

  /// Check if entries provide sufficient data for reliable analysis
  bool hasSufficientData(List<JournalEntry> entries) {
    return entries.length >= _minEntriesForReliability;
  }

  /// Get chronotype description
  String getChronotypeDescription(String chronotype) {
    switch (chronotype) {
      case 'morning':
        return 'Morning person - most active before 11 AM';
      case 'evening':
        return 'Evening person - most active after 5 PM';
      case 'balanced':
        return 'Balanced chronotype - consistent activity throughout day';
      default:
        return 'Unknown chronotype';
    }
  }

  /// Get window description
  String getWindowDescription(String window) {
    switch (window) {
      case 'morning':
        return 'Morning window - 6 AM to 11 AM';
      case 'afternoon':
        return 'Afternoon window - 11 AM to 5 PM';
      case 'evening':
        return 'Evening window - 5 PM to 6 AM';
      default:
        return 'Unknown window';
    }
  }
}
