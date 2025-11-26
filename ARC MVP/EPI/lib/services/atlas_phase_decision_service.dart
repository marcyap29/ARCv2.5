// lib/services/atlas_phase_decision_service.dart
// ATLAS Phase Decision Logic - Dart Implementation
// Converted from Python spec to eliminate Discovery bias and add hysteresis

import 'dart:math';
import '../models/phase_models.dart';

/// ATLAS Phase Decision Service
/// Implements score-based phase decisions with hysteresis and timeline smoothing
/// No Discovery bias - all phases treated symmetrically
class AtlasPhaseDecisionService {
  // Configuration constants from spec
  static const double defaultMinScore = 0.35;
  static const double defaultMinMargin = 0.10;
  static const double defaultStickinessBonus = 0.05;
  static const int defaultWindowSize = 3;

  /// Decide the ATLAS phase for a single entry given phase scores and the previous phase
  ///
  /// Rules:
  /// - If the top score is below MIN_SCORE, keep prevPhase (or null if no previous)
  /// - If the margin between top 2 phases is smaller than MIN_MARGIN, keep prevPhase
  /// - If switching away from prevPhase, require extra advantage STICKINESS_BONUS
  /// Discovery is not a default. It is only chosen when it wins under these rules.
  static PhaseLabel? decidePhaseForEntry({
    required Map<PhaseLabel, double> scores,
    PhaseLabel? prevPhase,
    double minScore = defaultMinScore,
    double minMargin = defaultMinMargin,
    double stickinessBonus = defaultStickinessBonus,
  }) {
    if (scores.isEmpty) {
      return prevPhase;
    }

    // 1. Sort phases by score: highest first
    final sortedEntries = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topPhase = sortedEntries[0].key;
    final topScore = sortedEntries[0].value;

    // If there is only one phase somehow, treat it as both top and second
    final secondScore = sortedEntries.length > 1 ? sortedEntries[1].value : 0.0;

    // 2. Reject weak signal
    if (topScore < minScore) {
      return prevPhase;
    }

    // 3. Reject ambiguous winners
    final margin = topScore - secondScore;
    if (margin < minMargin) {
      return prevPhase;
    }

    // 4. Hysteresis: protect against rapid flipping
    if (prevPhase != null && topPhase != prevPhase) {
      final prevScore = scores[prevPhase] ?? 0.0;
      if ((topScore - prevScore) < (minMargin + stickinessBonus)) {
        // Not enough advantage to override the existing phase
        return prevPhase;
      }
    }

    // 5. If we reach here, topPhase is a confident winner
    return topPhase;
  }

  /// Decide the smoothed timeline phase using a sliding window of recent entries
  ///
  /// recentEntryScores should be ordered oldest -> newest
  /// currentPhase is the current global ATLAS phase on the timeline
  ///
  /// The function:
  /// - Applies decidePhaseForEntry across the window
  /// - Performs a majority vote over the resulting phases (ignoring null)
  /// - Only changes the global phase if the new phase has a non-trivial majority
  static PhaseLabel? smoothedPhaseDecision({
    required List<Map<PhaseLabel, double>> recentEntryScores,
    PhaseLabel? currentPhase,
    int windowSize = defaultWindowSize,
    double minScore = defaultMinScore,
    double minMargin = defaultMinMargin,
    double stickinessBonus = defaultStickinessBonus,
  }) {
    if (recentEntryScores.isEmpty) {
      return currentPhase;
    }

    // Use only the last windowSize entries
    final scoresWindow = recentEntryScores.length <= windowSize
        ? recentEntryScores
        : recentEntryScores.sublist(recentEntryScores.length - windowSize);

    final rawPhases = <PhaseLabel?>[];
    PhaseLabel? prev = currentPhase;

    for (final scores in scoresWindow) {
      final phase = decidePhaseForEntry(
        scores: scores,
        prevPhase: prev,
        minScore: minScore,
        minMargin: minMargin,
        stickinessBonus: stickinessBonus,
      );
      rawPhases.add(phase);
      prev = phase;
    }

    // Count non-null phases
    final counter = <PhaseLabel, int>{};
    for (final phase in rawPhases) {
      if (phase != null) {
        counter[phase] = (counter[phase] ?? 0) + 1;
      }
    }

    if (counter.isEmpty) {
      return currentPhase;
    }

    // Find the phase with the highest count
    final sortedCounts = counter.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final newPhase = sortedCounts[0].key;
    final count = sortedCounts[0].value;

    // If no current phase, adopt the new consensus directly
    if (currentPhase == null) {
      return newPhase;
    }

    // Only flip if there is at least a small majority
    if (newPhase != currentPhase && count >= 2) {
      return newPhase;
    }

    return currentPhase;
  }

  /// Generate phase scores from entry content, emotion, and keywords
  /// This replaces the old keyword-based detection with a scoring approach
  static Map<PhaseLabel, double> generatePhaseScores({
    required String content,
    required List<String> keywords,
    String? emotion,
    String? emotionReason,
  }) {
    final scores = <PhaseLabel, double>{};

    // Initialize all phases to base score
    for (final phase in PhaseLabel.values) {
      scores[phase] = 0.1; // Small base probability for all phases
    }

    final lowerContent = content.toLowerCase();
    final lowerKeywords = keywords.map((k) => k.toLowerCase()).toList();

    // Content length factor
    final contentLength = content.length;
    final normalizedLength = (contentLength / 500.0).clamp(0.0, 2.0);

    // Discovery indicators - curiosity, questions, exploration
    double discoveryScore = 0.1;
    if (lowerContent.contains('new') || lowerContent.contains('discover') ||
        lowerContent.contains('learn') || lowerContent.contains('explore') ||
        lowerContent.contains('wonder') || lowerContent.contains('curious') ||
        content.contains('?')) {
      discoveryScore += 0.3;
    }
    if (lowerKeywords.any((k) => k.contains('learning') || k.contains('explore') ||
                              k.contains('question') || k.contains('wonder'))) {
      discoveryScore += 0.2;
    }
    if (contentLength < 200) discoveryScore += 0.1; // Short entries often exploratory

    // Expansion indicators - growth, building, development
    double expansionScore = 0.1;
    if (lowerContent.contains('grow') || lowerContent.contains('expand') ||
        lowerContent.contains('build') || lowerContent.contains('develop') ||
        lowerContent.contains('progress') || lowerContent.contains('increase')) {
      expansionScore += 0.3;
    }
    if (lowerKeywords.any((k) => k.contains('growth') || k.contains('building') ||
                              k.contains('develop') || k.contains('progress'))) {
      expansionScore += 0.2;
    }
    if (normalizedLength > 1.0) expansionScore += 0.1; // Longer entries suggest expansion

    // Transition indicators - change, movement, transformation
    double transitionScore = 0.1;
    if (lowerContent.contains('change') || lowerContent.contains('transition') ||
        lowerContent.contains('shift') || lowerContent.contains('move') ||
        lowerContent.contains('transform') || lowerContent.contains('adjust')) {
      transitionScore += 0.3;
    }
    if (lowerKeywords.any((k) => k.contains('change') || k.contains('shift') ||
                              k.contains('transform') || k.contains('adjust'))) {
      transitionScore += 0.2;
    }

    // Consolidation indicators - stability, organization, integration
    double consolidationScore = 0.1;
    if (lowerContent.contains('consolidate') || lowerContent.contains('stable') ||
        lowerContent.contains('organize') || lowerContent.contains('integrate') ||
        lowerContent.contains('strengthen') || lowerContent.contains('establish')) {
      consolidationScore += 0.3;
    }
    if (lowerKeywords.any((k) => k.contains('stable') || k.contains('solid') ||
                              k.contains('organize') || k.contains('integrate'))) {
      consolidationScore += 0.2;
    }
    if (contentLength > 400) consolidationScore += 0.1; // Detailed reflection suggests consolidation

    // Recovery indicators - healing, restoration, rest
    double recoveryScore = 0.1;
    if (lowerContent.contains('recover') || lowerContent.contains('heal') ||
        lowerContent.contains('rest') || lowerContent.contains('restore') ||
        lowerContent.contains('repair') || lowerContent.contains('rejuvenate')) {
      recoveryScore += 0.3;
    }
    if (lowerKeywords.any((k) => k.contains('recovery') || k.contains('healing') ||
                              k.contains('rest') || k.contains('restore'))) {
      recoveryScore += 0.2;
    }
    if (lowerContent.contains('feel') || lowerContent.contains('emotion') ||
        lowerContent.contains('mood')) {
      recoveryScore += 0.1; // Emotional processing
    }

    // Breakthrough indicators - insights, achievements, realizations
    double breakthroughScore = 0.1;
    if (lowerContent.contains('breakthrough') || lowerContent.contains('insight') ||
        lowerContent.contains('achieve') || lowerContent.contains('accomplish') ||
        lowerContent.contains('realize') || lowerContent.contains('understand')) {
      breakthroughScore += 0.3;
    }
    if (lowerKeywords.any((k) => k.contains('breakthrough') || k.contains('insight') ||
                              k.contains('achieve') || k.contains('realize'))) {
      breakthroughScore += 0.2;
    }

    // Emotion-based adjustments
    if (emotion != null) {
      final lowerEmotion = emotion.toLowerCase();
      if (lowerEmotion.contains('curious') || lowerEmotion.contains('excited')) {
        discoveryScore += 0.1;
      }
      if (lowerEmotion.contains('confident') || lowerEmotion.contains('motivated')) {
        expansionScore += 0.1;
      }
      if (lowerEmotion.contains('anxious') || lowerEmotion.contains('uncertain')) {
        transitionScore += 0.1;
      }
      if (lowerEmotion.contains('calm') || lowerEmotion.contains('stable')) {
        consolidationScore += 0.1;
      }
      if (lowerEmotion.contains('tired') || lowerEmotion.contains('overwhelmed')) {
        recoveryScore += 0.1;
      }
      if (lowerEmotion.contains('amazed') || lowerEmotion.contains('enlightened')) {
        breakthroughScore += 0.1;
      }
    }

    // Assign calculated scores (clamped to [0, 1])
    scores[PhaseLabel.discovery] = discoveryScore.clamp(0.0, 1.0);
    scores[PhaseLabel.expansion] = expansionScore.clamp(0.0, 1.0);
    scores[PhaseLabel.transition] = transitionScore.clamp(0.0, 1.0);
    scores[PhaseLabel.consolidation] = consolidationScore.clamp(0.0, 1.0);
    scores[PhaseLabel.recovery] = recoveryScore.clamp(0.0, 1.0);
    scores[PhaseLabel.breakthrough] = breakthroughScore.clamp(0.0, 1.0);

    // Normalize scores to sum to 1.0
    final totalScore = scores.values.reduce((a, b) => a + b);
    if (totalScore > 0) {
      scores.updateAll((phase, score) => score / totalScore);
    }

    return scores;
  }

  /// Convert PhaseLabel to string for debugging
  static String phaseToString(PhaseLabel? phase) {
    if (phase == null) return 'None';
    return phase.name.substring(0, 1).toUpperCase() + phase.name.substring(1);
  }

  /// Debug method to print phase scores
  static void debugPrintScores(Map<PhaseLabel, double> scores, String context) {
    print('DEBUG: Phase scores for $context:');
    final sortedEntries = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedEntries) {
      print('  ${phaseToString(entry.key)}: ${(entry.value * 100).toStringAsFixed(1)}%');
    }
  }
}