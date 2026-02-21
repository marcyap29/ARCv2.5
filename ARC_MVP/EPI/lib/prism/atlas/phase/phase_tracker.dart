import 'dart:math' as math;
import 'package:my_app/prism/atlas/phase/phase_scoring.dart';
import 'package:my_app/prism/atlas/phase/phase_history_repository.dart';
import 'package:my_app/services/phase_history_access_control.dart';
import 'package:my_app/models/user_profile_model.dart';

/// Configuration constants for phase tracking
///
/// These constants control the phase transition detection algorithm to prevent
/// rapid oscillation between phases while ensuring accurate phase detection.
///
/// ## Algorithm Components
/// - **EMA Smoothing**: Exponential Moving Average over last N entries to reduce noise
/// - **Cooldown Period**: Prevents phase changes within 7 days of last change
/// - **Promote Threshold**: Minimum smoothed score (0.62) required to consider a phase
/// - **Hysteresis Gap**: Prevents rapid switching by requiring new phase to exceed current by 0.08
class PhaseTrackerConfig {
  /// Number of recent entries used for EMA smoothing
  /// EMA provides gradual weighting: recent entries have more influence
  static const int windowEntries = 7;
  
  /// Cooldown period after phase change
  /// Prevents rapid phase oscillation by blocking changes within 7 days
  static const Duration cooldown = Duration(days: 7);
  
  /// Minimum smoothed EMA score required to consider a phase change
  /// Acts as quality gate: only confident phase detections trigger transitions
  static const double promoteThreshold = 0.62;
  
  /// Hysteresis gap for phase transitions
  /// New phase must exceed current phase score by this margin to prevent rapid switching
  static const double hysteresisGap = 0.08;
  
  /// EMA smoothing factor (alpha)
  /// Formula: α = 2/(N+1) where N is window size
  /// Higher alpha = more weight on recent entries
  static const double emaAlpha = 2.0 / (windowEntries + 1);
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
///
/// Tracks user's emotional/developmental phase over time using exponential moving
/// average (EMA) smoothing to reduce noise and prevent rapid phase oscillation.
///
/// ## Algorithm Overview
/// 1. **Score Storage**: Store raw phase scores for each journal entry
/// 2. **EMA Calculation**: Calculate smoothed scores using exponential moving average
/// 3. **Cooldown Check**: Block phase changes if within cooldown period
/// 4. **Threshold Check**: Only consider phases above promote threshold
/// 5. **Hysteresis Check**: Require new phase to exceed current by hysteresis gap
/// 6. **Phase Change**: Update user profile if all checks pass
///
/// ## Architecture Context
/// Part of PRISM ATLAS module. Processes journal entries to determine phase
/// transitions, which are then used by RIVET for gating and ARCForm for visualization.
///
/// ## Data Flow
/// ```
/// Journal Entry → PhaseScoring.score() → Raw Phase Scores
///   → PhaseTracker.updatePhaseScores() → EMA Smoothing
///   → Cooldown/Hysteresis Checks → Phase Transition Decision
///   → UserProfile Update (if phase changed)
/// ```
class PhaseTracker {
  final UserProfile _userProfile;

  PhaseTracker({
    required UserProfile userProfile,
  }) : _userProfile = userProfile;

  /// Update phase tracking with new entry scores
  ///
  /// This is the main entry point for phase tracking. Called after each journal
  /// entry is processed to update phase state and potentially trigger a phase transition.
  ///
  /// ## Process Flow
  /// 1. Store entry in phase history repository
  /// 2. Calculate EMA scores over recent entries
  /// 3. Check cooldown period (blocks if within 7 days of last change)
  /// 4. Check promotion threshold (requires score ≥ 0.62)
  /// 5. Check hysteresis gap (requires new phase to exceed current by 0.08)
  /// 6. Return result indicating if phase changed and why
  ///
  /// Returns PhaseTrackingResult with detailed information about the tracking decision,
  /// including whether phase changed, smoothed scores, and blocking reasons.
  /// Optionally pass [operationalReadinessScore] and [healthData] to persist with the entry
  /// for Health & Readiness views (Rating History, Phase Transitions, Health Correlation).
  Future<PhaseTrackingResult> updatePhaseScores({
    required Map<String, double> phaseScores,
    required String journalEntryId,
    required String emotion,
    required String reason,
    required String text,
    int? operationalReadinessScore,
    Map<String, dynamic>? healthData,
  }) async {
    // 1. Store the new entry in history (with optional readiness and health for biometric UI)
    final historyEntry = PhaseHistoryEntry(
      id: 'phase_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      phaseScores: phaseScores,
      journalEntryId: journalEntryId,
      emotion: emotion,
      reason: reason,
      text: text,
      operationalReadinessScore: operationalReadinessScore,
      healthData: healthData,
    );
    
    await PhaseHistoryRepository.addEntry(historyEntry);

    // 2. Get recent entries for EMA calculation
    final recentEntries = await PhaseHistoryAccessControl.instance.getRecentEntries(PhaseTrackerConfig.windowEntries);
    
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
    final recentEntries = await PhaseHistoryAccessControl.instance.getRecentEntries(PhaseTrackerConfig.windowEntries);
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
    final recentEntries = await PhaseHistoryAccessControl.instance.getRecentEntries(PhaseTrackerConfig.windowEntries);
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
    final recentEntries = await PhaseHistoryAccessControl.instance.getRecentEntries(PhaseTrackerConfig.windowEntries);
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
