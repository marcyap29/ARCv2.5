import 'dart:math' as math;
import 'package:my_app/atlas/phase_detection/phase_scoring.dart';
import 'package:my_app/atlas/phase_detection/phase_history_repository.dart';
import 'package:my_app/models/user_profile_model.dart';

/// Configuration constants for phase tracking
class PhaseTrackerConfig {
  static const int windowEntries = 7; // EMA over last 7 entries
  static const Duration cooldown = Duration(days: 7); // 7 days cooldown
  static const double promoteThreshold = 0.62; // min smoothed score to consider phase change
  static const double hysteresisGap = 0.08; // newPhaseScore must exceed current by this margin
  static const double emaAlpha = 2.0 / (windowEntries + 1); // EMA smoothing factor
}

/// Result of a phase tracking update
class PhaseTrackingResult {
  final bool phaseChanged;
  final String? newPhase;
  final String? previousPhase;
  final Map<String, double> smoothedScores;
  final String reason;
  final bool cooldownActive;
  final bool hysteresisBlocked;

  const PhaseTrackingResult({
    required this.phaseChanged,
    this.newPhase,
    this.previousPhase,
    required this.smoothedScores,
    required this.reason,
    required this.cooldownActive,
    required this.hysteresisBlocked,
  });
}

/// Core phase tracking system with EMA smoothing, hysteresis, and cooldown
class PhaseTracker {
  final UserProfile _userProfile;

  PhaseTracker({
    required UserProfile userProfile,
  }) : _userProfile = userProfile;

  /// Update phase tracking with new entry scores
  /// Returns PhaseTrackingResult indicating if phase changed and why
  Future<PhaseTrackingResult> updatePhaseScores({
    required Map<String, double> phaseScores,
    required String journalEntryId,
    required String emotion,
    required String reason,
    required String text,
  }) async {
    // 1. Store the new entry in history
    final historyEntry = PhaseHistoryEntry(
      id: 'phase_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      phaseScores: phaseScores,
      journalEntryId: journalEntryId,
      emotion: emotion,
      reason: reason,
      text: text,
    );
    
    await PhaseHistoryRepository.addEntry(historyEntry);

    // 2. Get recent entries for EMA calculation
    final recentEntries = await PhaseHistoryRepository.getRecentEntries(PhaseTrackerConfig.windowEntries);
    
    // 3. Calculate EMA scores for all phases
    final smoothedScores = _calculateEMAScores(recentEntries);

    // 4. Find the best phase (highest EMA score)
    final bestPhase = _findBestPhase(smoothedScores);
    final bestPhaseScore = smoothedScores[bestPhase] ?? 0.0;
    final currentPhaseScore = smoothedScores[_userProfile.currentPhase] ?? 0.0;

    // 5. Check cooldown
    final cooldownActive = _isCooldownActive();
    if (cooldownActive) {
      return PhaseTrackingResult(
        phaseChanged: false,
        smoothedScores: smoothedScores,
        reason: 'Cooldown active - phase change blocked',
        cooldownActive: true,
        hysteresisBlocked: false,
      );
    }

    // 6. Check promotion threshold
    if (bestPhaseScore < PhaseTrackerConfig.promoteThreshold) {
      return PhaseTrackingResult(
        phaseChanged: false,
        smoothedScores: smoothedScores,
        reason: 'Best phase score (${bestPhaseScore.toStringAsFixed(3)}) below threshold (${PhaseTrackerConfig.promoteThreshold})',
        cooldownActive: false,
        hysteresisBlocked: false,
      );
    }

    // 7. Check hysteresis (if not changing to same phase)
    if (bestPhase != _userProfile.currentPhase) {
      final scoreDifference = bestPhaseScore - currentPhaseScore;
      if (scoreDifference < PhaseTrackerConfig.hysteresisGap) {
        return PhaseTrackingResult(
          phaseChanged: false,
          smoothedScores: smoothedScores,
          reason: 'Hysteresis blocked - score difference (${scoreDifference.toStringAsFixed(3)}) below gap (${PhaseTrackerConfig.hysteresisGap})',
          cooldownActive: false,
          hysteresisBlocked: true,
        );
      }
    }

    // 8. Phase change approved
    if (bestPhase != _userProfile.currentPhase) {
      return PhaseTrackingResult(
        phaseChanged: true,
        newPhase: bestPhase,
        previousPhase: _userProfile.currentPhase,
        smoothedScores: smoothedScores,
        reason: 'Phase changed from ${_userProfile.currentPhase} to $bestPhase (score: ${bestPhaseScore.toStringAsFixed(3)})',
        cooldownActive: false,
        hysteresisBlocked: false,
      );
    }

    // 9. No phase change needed
    return PhaseTrackingResult(
      phaseChanged: false,
      smoothedScores: smoothedScores,
      reason: 'No phase change needed - current phase remains optimal',
      cooldownActive: false,
      hysteresisBlocked: false,
    );
  }

  /// Calculate EMA scores for all phases based on recent entries
  Map<String, double> _calculateEMAScores(List<PhaseHistoryEntry> recentEntries) {
    final Map<String, double> emaScores = {
      for (final phase in PhaseScoring.allPhases) phase: 0.0,
    };

    if (recentEntries.isEmpty) {
      return emaScores;
    }

    // Initialize with first entry scores
    final firstEntry = recentEntries.first;
    for (final phase in PhaseScoring.allPhases) {
      emaScores[phase] = firstEntry.phaseScores[phase] ?? 0.0;
    }

    // Apply EMA smoothing for remaining entries
    for (int i = 1; i < recentEntries.length; i++) {
      final entry = recentEntries[i];
      for (final phase in PhaseScoring.allPhases) {
        final currentScore = entry.phaseScores[phase] ?? 0.0;
        final previousEMA = emaScores[phase]!;
        
        // EMA formula: EMA_t = α * current + (1 - α) * EMA_{t-1}
        emaScores[phase] = PhaseTrackerConfig.emaAlpha * currentScore + 
                          (1 - PhaseTrackerConfig.emaAlpha) * previousEMA;
      }
    }

    return emaScores;
  }

  /// Find the phase with the highest EMA score
  String _findBestPhase(Map<String, double> scores) {
    String bestPhase = PhaseScoring.allPhases.first;
    double bestScore = scores[bestPhase] ?? 0.0;

    for (final phase in PhaseScoring.allPhases) {
      final score = scores[phase] ?? 0.0;
      if (score > bestScore) {
        bestScore = score;
        bestPhase = phase;
      }
    }

    return bestPhase;
  }

  /// Check if cooldown is currently active
  bool _isCooldownActive() {
    if (_userProfile.lastPhaseChangeAt == null) {
      return false;
    }

    final timeSinceLastChange = DateTime.now().difference(_userProfile.lastPhaseChangeAt!);
    return timeSinceLastChange < PhaseTrackerConfig.cooldown;
  }

  /// Get current phase tracking status
  Future<Map<String, dynamic>> getTrackingStatus() async {
    final recentEntries = await PhaseHistoryRepository.getRecentEntries(PhaseTrackerConfig.windowEntries);
    final smoothedScores = _calculateEMAScores(recentEntries);
    final bestPhase = _findBestPhase(smoothedScores);
    final cooldownActive = _isCooldownActive();
    
    final timeSinceLastChange = _userProfile.lastPhaseChangeAt != null
        ? DateTime.now().difference(_userProfile.lastPhaseChangeAt!)
        : null;

    return {
      'currentPhase': _userProfile.currentPhase,
      'bestPhase': bestPhase,
      'smoothedScores': smoothedScores,
      'cooldownActive': cooldownActive,
      'timeSinceLastChange': timeSinceLastChange?.inDays,
      'cooldownRemainingDays': cooldownActive 
          ? (PhaseTrackerConfig.cooldown - timeSinceLastChange!).inDays
          : 0,
      'recentEntriesCount': recentEntries.length,
      'promoteThreshold': PhaseTrackerConfig.promoteThreshold,
      'hysteresisGap': PhaseTrackerConfig.hysteresisGap,
    };
  }

  /// Get phase trend over time
  Future<Map<String, double>> getPhaseTrends({int lookbackDays = 7}) async {
    final trends = <String, double>{};
    
    for (final phase in PhaseScoring.allPhases) {
      final trend = await PhaseHistoryRepository.getPhaseTrend(phase, lookbackDays: lookbackDays);
      trends[phase] = trend;
    }
    
    return trends;
  }

  /// Get phase stability metrics
  Future<Map<String, dynamic>> getStabilityMetrics() async {
    final recentEntries = await PhaseHistoryRepository.getRecentEntries(PhaseTrackerConfig.windowEntries);
    final smoothedScores = _calculateEMAScores(recentEntries);
    
    // Calculate variance in scores (lower = more stable)
    final scores = smoothedScores.values.toList();
    final mean = scores.reduce((a, b) => a + b) / scores.length;
    final variance = scores.map((s) => math.pow(s - mean, 2)).reduce((a, b) => a + b) / scores.length;
    
    // Calculate how much the best phase leads by
    final bestPhase = _findBestPhase(smoothedScores);
    final bestScore = smoothedScores[bestPhase] ?? 0.0;
    final secondBestScore = smoothedScores.values
        .where((s) => s != bestScore)
        .fold(0.0, (a, b) => a > b ? a : b);
    final lead = bestScore - secondBestScore;
    
    return {
      'variance': variance,
      'stability': 1.0 - variance, // Higher stability = lower variance
      'bestPhaseLead': lead,
      'isStable': variance < 0.1 && lead > 0.1,
      'smoothedScores': smoothedScores,
    };
  }

  /// Force a phase change (for testing or manual override)
  Future<PhaseTrackingResult> forcePhaseChange(String newPhase) async {
    final recentEntries = await PhaseHistoryRepository.getRecentEntries(PhaseTrackerConfig.windowEntries);
    final smoothedScores = _calculateEMAScores(recentEntries);
    
    return PhaseTrackingResult(
      phaseChanged: true,
      newPhase: newPhase,
      previousPhase: _userProfile.currentPhase,
      smoothedScores: smoothedScores,
      reason: 'Phase change forced to $newPhase',
      cooldownActive: false,
      hysteresisBlocked: false,
    );
  }

  /// Reset phase tracking (clear history and reset to Discovery)
  Future<void> resetPhaseTracking() async {
    await PhaseHistoryRepository.clearAll();
    // Note: UserProfile update should be handled by the calling service
  }

  /// Get configuration constants
  static Map<String, dynamic> getConfig() {
    return {
      'windowEntries': PhaseTrackerConfig.windowEntries,
      'cooldownDays': PhaseTrackerConfig.cooldown.inDays,
      'promoteThreshold': PhaseTrackerConfig.promoteThreshold,
      'hysteresisGap': PhaseTrackerConfig.hysteresisGap,
      'emaAlpha': PhaseTrackerConfig.emaAlpha,
    };
  }
}
