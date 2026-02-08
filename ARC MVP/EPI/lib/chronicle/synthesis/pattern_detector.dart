import '../storage/raw_entry_schema.dart';

/// Words that must not be treated as themes (pronouns, articles, fillers, generic verbs).
const _nonThemeWords = {
  'that', 'what', 'this', 'it', 'the', 'a', 'an', 'and', 'or', 'but',
  'is', 'are', 'was', 'were', 'have', 'has', 'had', 'do', 'does', 'did',
  'will', 'would', 'could', 'should', 'may', 'might', 'can', 'something',
  'things', 'how', 'when', 'why', 'where', 'which', 'who', 'them', 'their',
  'there', 'then', 'than', 'just', 'only', 'even', 'also', 'very', 'really',
  'over', 'makes', 'processing', 'slower', 'okay', 'make', 'made', 'getting',
  'being', 'going', 'like', 'into', 'with', 'from', 'for', 'about', 'some',
};

/// Pattern Detector for CHRONICLE synthesis
/// 
/// Detects themes, clusters entries, and identifies patterns
/// for use in monthly/yearly/multi-year aggregations.

class PatternDetector {
  /// Extract dominant themes from a list of raw entries
  /// 
  /// Returns themes with confidence scores and supporting entry IDs.
  /// Skips non-themes (e.g. "That", "What", pronouns, articles).
  Future<List<DetectedTheme>> extractThemes({
    required List<RawEntrySchema> entries,
    int maxThemes = 5,
  }) async {
    if (entries.isEmpty) return [];

    // Count theme frequencies (ignore non-theme words)
    final themeCounts = <String, int>{};
    final themeEntries = <String, List<String>>{};

    for (final entry in entries) {
      for (final theme in entry.analysis.extractedThemes) {
        final t = theme.trim();
        if (t.isEmpty || _isNonTheme(t)) continue;
        themeCounts[t] = (themeCounts[t] ?? 0) + 1;
        themeEntries.putIfAbsent(t, () => []).add(entry.entryId);
      }
    }

    // Sort by frequency and take top N
    final sortedThemes = themeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final themes = <DetectedTheme>[];
    for (final entry in sortedThemes.take(maxThemes)) {
      final frequency = entry.value / entries.length;
      final confidence = _calculateConfidence(frequency, entry.value);
      
      themes.add(DetectedTheme(
        name: entry.key,
        confidence: confidence,
        entryIds: themeEntries[entry.key] ?? [],
        frequency: frequency,
      ));
    }

    return themes;
  }

  static bool _isNonTheme(String name) {
    final lower = name.trim().toLowerCase();
    if (lower.isEmpty || lower.length < 2) return true;
    if (_nonThemeWords.contains(lower)) return true;
    if (RegExp(r'^[\d\s\W]+$').hasMatch(lower)) return true;
    return false;
  }

  /// Calculate confidence score based on frequency and count
  double _calculateConfidence(double frequency, int count) {
    // High confidence if appears in >30% of entries AND at least 3 times
    if (frequency > 0.3 && count >= 3) return 0.9;
    
    // Medium confidence if appears in >15% of entries AND at least 2 times
    if (frequency > 0.15 && count >= 2) return 0.7;
    
    // Low confidence otherwise
    return 0.5;
  }

  /// Calculate phase distribution from entries
  Map<String, double> calculatePhaseDistribution(List<RawEntrySchema> entries) {
    if (entries.isEmpty) return {};

    final phaseCounts = <String, int>{};
    for (final entry in entries) {
      final phase = entry.analysis.atlasPhase;
      if (phase != null) {
        phaseCounts[phase] = (phaseCounts[phase] ?? 0) + 1;
      }
    }

    return phaseCounts.map(
      (phase, count) => MapEntry(phase, count / entries.length),
    );
  }

  /// Calculate SENTINEL trend (average emotional intensity over time)
  SentinelTrend calculateSentinelTrend(List<RawEntrySchema> entries) {
    if (entries.isEmpty) {
      return SentinelTrend(
        average: 0.0,
        peak: 0.0,
        low: 0.0,
        trend: 0.0, // neutral
      );
    }

    final scores = entries
        .where((e) => e.analysis.sentinelScore != null)
        .map((e) => e.analysis.sentinelScore!.density)
        .toList();

    if (scores.isEmpty) {
      return SentinelTrend(
        average: 0.0,
        peak: 0.0,
        low: 0.0,
        trend: 0.0,
      );
    }

    final average = scores.reduce((a, b) => a + b) / scores.length;
    final peak = scores.reduce((a, b) => a > b ? a : b);
    final low = scores.reduce((a, b) => a < b ? a : b);

    // Calculate trend (comparing first half to second half)
    double trend = 0.0;
    if (scores.length >= 4) {
      final firstHalf = scores.sublist(0, scores.length ~/ 2);
      final secondHalf = scores.sublist(scores.length ~/ 2);
      final firstAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
      final secondAvg = secondHalf.reduce((a, b) => a + b) / secondHalf.length;
      trend = secondAvg - firstAvg; // Positive = increasing, negative = decreasing
    }

    return SentinelTrend(
      average: average,
      peak: peak,
      low: low,
      trend: trend,
    );
  }

  /// Identify significant events (outliers in SENTINEL, phase transitions)
  List<SignificantEvent> identifySignificantEvents(List<RawEntrySchema> entries) {
    if (entries.isEmpty) return [];

    final events = <SignificantEvent>[];

    // Sort by timestamp
    final sortedEntries = List<RawEntrySchema>.from(entries)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Detect phase transitions
    String? previousPhase;
    for (final entry in sortedEntries) {
      final currentPhase = entry.analysis.atlasPhase;
      if (currentPhase != null && previousPhase != null && currentPhase != previousPhase) {
        events.add(SignificantEvent(
          date: entry.timestamp,
          type: EventType.phaseTransition,
          description: 'Phase transition: $previousPhase → $currentPhase',
          entryId: entry.entryId,
        ));
      }
      previousPhase = currentPhase;
    }

    // Detect high SENTINEL scores (top 10%)
    final sentinelScores = sortedEntries
        .where((e) => e.analysis.sentinelScore != null)
        .map((e) => MapEntry(e, e.analysis.sentinelScore!.density))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topCount = (sentinelScores.length * 0.1).ceil();
    for (int i = 0; i < topCount && i < sentinelScores.length; i++) {
      final entry = sentinelScores[i].key;
      final score = sentinelScores[i].value;
      
      // Only add if not already added as phase transition
      if (!events.any((e) => e.entryId == entry.entryId)) {
        events.add(SignificantEvent(
          date: entry.timestamp,
          type: EventType.highEmotionalIntensity,
          description: 'High emotional intensity (SENTINEL: ${score.toStringAsFixed(2)})',
          entryId: entry.entryId,
        ));
      }
    }

    // Sort events by date
    events.sort((a, b) => a.date.compareTo(b.date));

    return events;
  }
}

/// Detected theme with metadata
class DetectedTheme {
  final String name;
  final double confidence; // 0.0-1.0
  final List<String> entryIds;
  final double frequency; // 0.0-1.0 (percentage of entries)
  /// Optional narrative description from LLM (what this theme actually represents)
  final String? patternDescription;
  /// Optional emotional arc from LLM
  final String? emotionalArc;

  const DetectedTheme({
    required this.name,
    required this.confidence,
    required this.entryIds,
    required this.frequency,
    this.patternDescription,
    this.emotionalArc,
  });
}

/// SENTINEL trend analysis
class SentinelTrend {
  final double average;
  final double peak;
  final double low;
  final double trend; // Positive = increasing, negative = decreasing

  const SentinelTrend({
    required this.average,
    required this.peak,
    required this.low,
    required this.trend,
  });
}

/// Significant event detected in entries
class SignificantEvent {
  final DateTime date;
  final EventType type;
  final String description;
  final String entryId;

  const SignificantEvent({
    required this.date,
    required this.type,
    required this.description,
    required this.entryId,
  });
}

enum EventType {
  phaseTransition,
  highEmotionalIntensity,
  other,
}
