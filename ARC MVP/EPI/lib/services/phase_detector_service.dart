// lib/services/phase_detector_service.dart
// Real-time Phase Detection from Recent Entries

import 'dart:math';
import '../models/phase_models.dart';
import 'package:my_app/models/journal_entry_model.dart';

/// Real-time phase detection service that analyzes recent journal entries
/// to suggest the user's current phase based on keyword patterns
class PhaseDetectorService {
  // Configuration
  static const int _minEntriesToAnalyze = 10;
  static const int _maxEntriesToAnalyze = 20;
  static const int _lookbackDays = 28; // 4 weeks

  // Comprehensive phase-specific keyword sets
  static const Map<PhaseLabel, List<String>> _phaseKeywords = {
    PhaseLabel.discovery: [
      // Core discovery terms
      'new', 'discover', 'explore', 'learning', 'first', 'start', 'begin',
      'curious', 'wonder', 'question', 'try', 'experiment', 'unfamiliar',
      // Emotional markers
      'excited', 'nervous', 'uncertain', 'adventurous', 'open',
      // Activities
      'research', 'study', 'read', 'watch', 'listen', 'observe',
      'journey', 'path', 'seeking', 'searching', 'finding',
    ],

    PhaseLabel.expansion: [
      // Core expansion terms
      'grow', 'growing', 'expand', 'expanding', 'growth', 'building',
      'develop', 'progress', 'advance', 'increase', 'more',
      // Emotional markers
      'confident', 'capable', 'strong', 'powerful', 'energized',
      // Activities
      'improve', 'enhance', 'optimize', 'scale', 'multiply',
      'success', 'winning', 'achieving', 'accomplishing',
      'momentum', 'flow', 'stride', 'rolling',
    ],

    PhaseLabel.transition: [
      // Core transition terms
      'change', 'changing', 'transition', 'shift', 'shifting',
      'transform', 'evolve', 'adapt', 'adjust', 'modify',
      // Emotional markers
      'uncertain', 'confused', 'mixed', 'between', 'limbo',
      'uncomfortable', 'uneasy', 'restless', 'anxious',
      // Activities
      'letting go', 'release', 'move', 'pivot', 'switch',
      'crossroads', 'threshold', 'edge', 'boundary',
      'neither', 'both', 'unknown', 'unclear',
    ],

    PhaseLabel.consolidation: [
      // Core consolidation terms
      'consolidate', 'consolidating', 'stable', 'stability', 'solid',
      'grounded', 'settled', 'established', 'foundation', 'structure',
      // Emotional markers
      'calm', 'peaceful', 'balanced', 'centered', 'steady',
      'secure', 'safe', 'comfortable', 'content',
      // Activities
      'organize', 'integrate', 'combine', 'unify', 'merge',
      'maintain', 'sustain', 'preserve', 'protect',
      'routine', 'rhythm', 'pattern', 'system', 'order',
    ],

    PhaseLabel.recovery: [
      // Core recovery terms
      'recover', 'recovering', 'heal', 'healing', 'rest', 'resting',
      'restore', 'recharge', 'recuperate', 'repair', 'mend',
      // Emotional markers
      'tired', 'exhausted', 'drained', 'weak', 'fragile',
      'gentle', 'soft', 'slow', 'quiet', 'withdrawn',
      // Activities
      'pause', 'break', 'stop', 'retreat', 'withdraw',
      'sleep', 'nap', 'relax', 'unwind', 'decompress',
      'care', 'nurture', 'tend', 'support', 'comfort',
    ],

    PhaseLabel.breakthrough: [
      // Core breakthrough terms
      'breakthrough', 'break', 'insight', 'revelation', 'epiphany',
      'realize', 'understand', 'clarity', 'clear', 'aha',
      // Emotional markers
      'amazed', 'shocked', 'surprised', 'thrilled', 'elated',
      'liberated', 'free', 'released', 'unburdened',
      // Activities
      'see', 'realize', 'recognize', 'grasp', 'get it',
      'transform', 'radical', 'sudden', 'instant', 'flash',
      'unlock', 'open', 'reveal', 'unveil', 'expose',
    ],
  };

  /// Detect current phase from recent journal entries
  PhaseDetectionResult detectCurrentPhase(List<JournalEntry> allEntries) {
    // Get recent entries (last N entries or last N days, whichever is smaller)
    final recentEntries = _getRecentEntries(allEntries);

    if (recentEntries.length < _minEntriesToAnalyze) {
      return PhaseDetectionResult(
        suggestedPhase: PhaseLabel.discovery,
        confidence: 0.0,
        phaseScores: {},
        matchedKeywords: {},
        analyzedEntryCount: recentEntries.length,
        message: 'Not enough entries to analyze. Need at least $_minEntriesToAnalyze entries.',
      );
    }

    // Extract all keywords from recent entries
    final allKeywords = <String>[];
    final allContent = StringBuffer();

    for (final entry in recentEntries) {
      allKeywords.addAll(entry.keywords);
      allContent.writeln(entry.content);
    }

    // Score each phase based on keyword matches
    final phaseScores = <PhaseLabel, double>{};
    final matchedKeywords = <PhaseLabel, List<String>>{};

    for (final phase in PhaseLabel.values) {
      final result = _scorePhase(
        phase,
        allKeywords,
        allContent.toString(),
      );
      phaseScores[phase] = result.score;
      matchedKeywords[phase] = result.matches;
    }

    // Find highest scoring phase
    PhaseLabel suggestedPhase = PhaseLabel.discovery;
    double maxScore = 0.0;

    for (final entry in phaseScores.entries) {
      if (entry.value > maxScore) {
        maxScore = entry.value;
        suggestedPhase = entry.key;
      }
    }

    // Calculate confidence (0.0 - 1.0)
    // Confidence is higher when:
    // 1. The top score is significantly higher than others
    // 2. We have enough entries to analyze
    // 3. Multiple keywords matched
    final confidence = _calculateConfidence(
      phaseScores,
      suggestedPhase,
      recentEntries.length,
      matchedKeywords[suggestedPhase]?.length ?? 0,
    );

    return PhaseDetectionResult(
      suggestedPhase: suggestedPhase,
      confidence: confidence,
      phaseScores: phaseScores,
      matchedKeywords: matchedKeywords,
      analyzedEntryCount: recentEntries.length,
      message: _generateMessage(confidence, recentEntries.length),
    );
  }

  /// Get recent entries for analysis
  List<JournalEntry> _getRecentEntries(List<JournalEntry> allEntries) {
    if (allEntries.isEmpty) return [];

    // Sort by date descending
    final sorted = List<JournalEntry>.from(allEntries)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Get entries from last N days
    final cutoffDate = DateTime.now().subtract(Duration(days: _lookbackDays));
    final recentByDate = sorted.where(
      (entry) => entry.createdAt.isAfter(cutoffDate)
    ).toList();

    // Take up to maxEntriesToAnalyze, but at least minEntriesToAnalyze if available
    if (recentByDate.length >= _minEntriesToAnalyze) {
      return recentByDate.take(_maxEntriesToAnalyze).toList();
    }

    // If not enough recent entries, fall back to most recent N entries
    return sorted.take(_maxEntriesToAnalyze).toList();
  }

  /// Score a specific phase based on keyword and content matches
  _PhaseScoreResult _scorePhase(
    PhaseLabel phase,
    List<String> keywords,
    String content,
  ) {
    final phaseKeywordSet = _phaseKeywords[phase] ?? [];
    final lowerKeywords = keywords.map((k) => k.toLowerCase()).toList();
    final lowerContent = content.toLowerCase();
    final matches = <String>[];

    double score = 0.0;

    // Score based on keyword matches
    for (final phaseKeyword in phaseKeywordSet) {
      final lowerPhaseKeyword = phaseKeyword.toLowerCase();

      // Exact keyword match (weight: 1.0)
      if (lowerKeywords.contains(lowerPhaseKeyword)) {
        score += 1.0;
        matches.add(phaseKeyword);
      }
      // Partial keyword match (weight: 0.5)
      else if (lowerKeywords.any((k) => k.contains(lowerPhaseKeyword))) {
        score += 0.5;
        matches.add('~$phaseKeyword');
      }
      // Content contains keyword (weight: 0.3)
      else if (lowerContent.contains(lowerPhaseKeyword)) {
        score += 0.3;
      }
    }

    // Normalize score by number of phase keywords to make phases comparable
    final normalizedScore = score / phaseKeywordSet.length;

    return _PhaseScoreResult(
      score: normalizedScore,
      matches: matches,
    );
  }

  /// Calculate confidence in the detection
  double _calculateConfidence(
    Map<PhaseLabel, double> phaseScores,
    PhaseLabel topPhase,
    int entryCount,
    int matchCount,
  ) {
    final topScore = phaseScores[topPhase] ?? 0.0;

    // Find second highest score
    double secondScore = 0.0;
    for (final entry in phaseScores.entries) {
      if (entry.key != topPhase && entry.value > secondScore) {
        secondScore = entry.value;
      }
    }

    // Confidence factors:

    // 1. Separation: How much better is top phase vs second? (0.0 - 0.5)
    final separation = min((topScore - secondScore) * 2.0, 0.5);

    // 2. Entry count: Do we have enough data? (0.0 - 0.3)
    final entryConfidence = min(entryCount / _maxEntriesToAnalyze, 1.0) * 0.3;

    // 3. Match count: Did we find enough keywords? (0.0 - 0.2)
    final matchConfidence = min(matchCount / 5.0, 1.0) * 0.2;

    return separation + entryConfidence + matchConfidence;
  }

  /// Generate human-readable message about the detection
  String _generateMessage(double confidence, int entryCount) {
    if (entryCount < _minEntriesToAnalyze) {
      return 'Not enough entries to analyze. Keep journaling!';
    }

    if (confidence >= 0.8) {
      return 'High confidence detection based on $entryCount recent entries';
    } else if (confidence >= 0.6) {
      return 'Moderate confidence detection based on $entryCount recent entries';
    } else if (confidence >= 0.4) {
      return 'Low confidence detection based on $entryCount recent entries';
    } else {
      return 'Uncertain detection - consider journaling more to improve accuracy';
    }
  }
}

/// Result of phase detection
class PhaseDetectionResult {
  final PhaseLabel suggestedPhase;
  final double confidence; // 0.0 - 1.0
  final Map<PhaseLabel, double> phaseScores;
  final Map<PhaseLabel, List<String>> matchedKeywords;
  final int analyzedEntryCount;
  final String message;

  const PhaseDetectionResult({
    required this.suggestedPhase,
    required this.confidence,
    required this.phaseScores,
    required this.matchedKeywords,
    required this.analyzedEntryCount,
    required this.message,
  });

  /// Get top N phases by score
  List<MapEntry<PhaseLabel, double>> getTopPhases(int n) {
    final sorted = phaseScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(n).toList();
  }
}

/// Internal class for phase scoring
class _PhaseScoreResult {
  final double score;
  final List<String> matches;

  const _PhaseScoreResult({
    required this.score,
    required this.matches,
  });
}
