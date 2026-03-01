/// LUMARA Monthly Review data model.
///
/// Pulls from CHRONICLE Layer 1 (monthly aggregation) and Layer 0 (raw entries).
/// No phase/ATLAS references — developmental insights only.

class MonthlyReview {
  final String monthKey; // "2025-01"
  final DateTime generatedAt;
  final String narrativeSynthesis; // From CHRONICLE Layer 1
  final ThemeEvolution themeEvolution;
  final List<EmotionalDataPoint> emotionalTrajectory;
  final String emotionalTrajectoryDescriptor;
  final List<BreakthroughEntry> breakthroughHighlights;
  final List<PatternAlert> patternAlerts;
  final Map<String, int> wordCloudData; // keyword -> frequency
  final String seedForNextMonth;
  final MonthlyStats stats;

  const MonthlyReview({
    required this.monthKey,
    required this.generatedAt,
    required this.narrativeSynthesis,
    required this.themeEvolution,
    required this.emotionalTrajectory,
    required this.emotionalTrajectoryDescriptor,
    required this.breakthroughHighlights,
    required this.patternAlerts,
    required this.wordCloudData,
    required this.seedForNextMonth,
    required this.stats,
  });

  /// Format month for display (e.g. "January 2025")
  String get monthDisplayName {
    final parts = monthKey.split('-');
    if (parts.length != 2) return monthKey;
    final year = parts[0];
    final monthNum = int.tryParse(parts[1]);
    if (monthNum == null || monthNum < 1 || monthNum > 12) return monthKey;
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${monthNames[monthNum - 1]} $year';
  }
}

class ThemeEvolution {
  final List<String> emerged;
  final List<String> persisted;
  final List<String> faded;
  final List<String> intensified;
  final String? previousMonthKey;

  const ThemeEvolution({
    required this.emerged,
    required this.persisted,
    required this.faded,
    required this.intensified,
    this.previousMonthKey,
  });
}

class EmotionalDataPoint {
  final DateTime date;
  final double intensity; // 0.0 - 1.0

  const EmotionalDataPoint({
    required this.date,
    required this.intensity,
  });
}

class BreakthroughEntry {
  final String entryId;
  final DateTime date;
  final String previewSnippet;
  final String highlightReason;
  final double significanceScore;

  const BreakthroughEntry({
    required this.entryId,
    required this.date,
    required this.previewSnippet,
    required this.highlightReason,
    required this.significanceScore,
  });
}

class PatternAlert {
  final String description;
  final String patternType; // "frequency", "temporal", "loop"
  final Map<String, dynamic> supportingData;

  const PatternAlert({
    required this.description,
    required this.patternType,
    this.supportingData = const {},
  });
}

class MonthlyStats {
  final int totalEntries;
  final double avgEntriesPerWeek;
  final int longestStreak;
  final String mostActiveDay;

  const MonthlyStats({
    required this.totalEntries,
    required this.avgEntriesPerWeek,
    required this.longestStreak,
    required this.mostActiveDay,
  });
}
