/// Production-ready Transition Policy and SENTINEL integration for ARC/EPI MVP
/// 
/// This module encodes a single, explicit decision policy that aligns:
/// - ATLAS (inference) - phase scores and EMA/hysteresis
/// - RIVET (advancement gate) - ALIGN, TRACE, sustainment, independence
/// - SENTINEL (risk gate) - risk band, pattern severity, sustainment
/// 
/// The policy unifies sustainment semantics, finalizes thresholds, completes
/// independence checks, caps novelty, wires risk into ingest, and provides
/// full telemetry for debugging and transparency.

import 'dart:math' as math;
import 'package:my_app/atlas/phase_detection/phase_tracker.dart';
import 'package:my_app/atlas/rivet/rivet_models.dart';
import 'package:my_app/prism/extractors/sentinel_risk_detector.dart';

/// Transition decision outcomes
enum TransitionDecision {
  hold,    // Do not advance phase - conditions not met
  promote, // Advance to next phase - all conditions satisfied
}

/// Complete transition outcome with reasoning and telemetry
class TransitionOutcome {
  final TransitionDecision decision;
  final String reason; // One-line explanation of decision
  final Map<String, dynamic> telemetry; // Full audit payload for debugging

  const TransitionOutcome({
    required this.decision,
    required this.reason,
    required this.telemetry,
  });

  @override
  String toString() => 'TransitionOutcome(${decision.name}: $reason)';

  Map<String, dynamic> toJson() => {
    'decision': decision.name,
    'reason': reason,
    'telemetry': telemetry,
  };
}

/// Configuration for the unified transition policy
class TransitionPolicyConfig {
  // ATLAS thresholds
  final double atlasMargin;      // Minimum margin for phase change (e.g., 0.62)
  final double atlasHysteresis;  // Hysteresis gap to prevent oscillation (e.g., 0.08)
  
  // RIVET thresholds
  final double rivetAlign;       // ALIGN threshold (e.g., 0.60)
  final double rivetTrace;       // TRACE threshold (e.g., 0.60)
  final int sustainW;            // Sustainment window size (e.g., 2)
  final int sustainGrace;        // Grace period for independence (e.g., 1)
  
  // Novelty and independence
  final double noveltyCap;       // Maximum novelty multiplier (e.g., 0.20)
  final double independenceBoost; // Independence multiplier (e.g., 1.2)
  
  // SENTINEL risk thresholds
  final double riskThreshold;    // Maximum risk score for promotion (e.g., 0.3)
  final double riskDecayRate;    // Risk decay rate per day (e.g., 0.1)
  
  // Cooldown and timing
  final Duration cooldown;       // Minimum time between phase changes (e.g., 7 days)
  final Duration riskWindow;     // Risk analysis window (e.g., 14 days)

  const TransitionPolicyConfig({
    this.atlasMargin = 0.62,
    this.atlasHysteresis = 0.08,
    this.rivetAlign = 0.60,
    this.rivetTrace = 0.60,
    this.sustainW = 2,
    this.sustainGrace = 1,
    this.noveltyCap = 0.20,
    this.independenceBoost = 1.2,
    this.riskThreshold = 0.3,
    this.riskDecayRate = 0.1,
    this.cooldown = const Duration(days: 7),
    this.riskWindow = const Duration(days: 14),
  });

  /// Default production configuration
  static const TransitionPolicyConfig production = TransitionPolicyConfig();

  /// Conservative configuration for sensitive users
  static const TransitionPolicyConfig conservative = TransitionPolicyConfig(
    atlasMargin: 0.65,
    rivetAlign: 0.65,
    rivetTrace: 0.65,
    sustainW: 3,
    riskThreshold: 0.2,
  );

  /// Aggressive configuration for rapid advancement
  static const TransitionPolicyConfig aggressive = TransitionPolicyConfig(
    atlasMargin: 0.58,
    rivetAlign: 0.55,
    rivetTrace: 0.55,
    sustainW: 1,
    riskThreshold: 0.4,
  );
}

/// Snapshot of ATLAS state for policy evaluation
class AtlasSnapshot {
  final Map<String, double> posteriorScores; // Phase probability scores
  final double margin;                       // Margin between best and current phase
  final String currentPhase;                 // Current user phase
  final DateTime lastChangeAt;               // When phase last changed
  final bool cooldownActive;                 // Whether cooldown is active
  final bool hysteresisBlocked;              // Whether hysteresis blocks change

  const AtlasSnapshot({
    required this.posteriorScores,
    required this.margin,
    required this.currentPhase,
    required this.lastChangeAt,
    required this.cooldownActive,
    required this.hysteresisBlocked,
  });

  /// Create from PhaseTrackingResult
  factory AtlasSnapshot.fromPhaseResult(
    PhaseTrackingResult result,
    String currentPhase,
    DateTime lastChangeAt,
  ) {
    final scores = result.smoothedScores;
    final bestPhase = scores.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
    final bestScore = scores[bestPhase] ?? 0.0;
    final currentScore = scores[currentPhase] ?? 0.0;
    final margin = bestScore - currentScore;

    return AtlasSnapshot(
      posteriorScores: scores,
      margin: margin,
      currentPhase: currentPhase,
      lastChangeAt: lastChangeAt,
      cooldownActive: result.cooldownActive,
      hysteresisBlocked: result.hysteresisBlocked,
    );
  }
}

/// Snapshot of RIVET state for policy evaluation
class RivetSnapshot {
  final double align;                        // Current ALIGN score [0,1]
  final double trace;                        // Current TRACE score [0,1]
  final int sustainCount;                    // Consecutive threshold meetings
  final bool sawIndependentInWindow;         // Independence flag
  final Set<String> independenceSet;         // Set of independent sources/days
  final double noveltyScore;                 // Current novelty score [0,1]
  final bool gateOpen;                       // Whether RIVET gate is open

  const RivetSnapshot({
    required this.align,
    required this.trace,
    required this.sustainCount,
    required this.sawIndependentInWindow,
    required this.independenceSet,
    required this.noveltyScore,
    required this.gateOpen,
  });

  /// Create from RivetState and RivetGateDecision
  factory RivetSnapshot.fromRivetState(
    RivetState state,
    RivetGateDecision decision, {
    Set<String> independenceSet = const {},
    double noveltyScore = 0.0,
  }) {
    return RivetSnapshot(
      align: state.align,
      trace: state.trace,
      sustainCount: state.sustainCount,
      sawIndependentInWindow: state.sawIndependentInWindow,
      independenceSet: independenceSet,
      noveltyScore: noveltyScore,
      gateOpen: decision.open,
    );
  }
}

/// Snapshot of SENTINEL state for policy evaluation
class SentinelSnapshot {
  final RiskLevel riskBand;                  // Current risk level
  final double patternSeverity;              // Pattern severity score [0,1]
  final bool sustainOk;                      // Whether risk is sustained
  final List<RiskPattern> activePatterns;    // Currently active risk patterns
  final double riskScore;                    // Overall risk score [0,1]
  final DateTime lastAnalysisAt;             // When risk was last analyzed

  const SentinelSnapshot({
    required this.riskBand,
    required this.patternSeverity,
    required this.sustainOk,
    required this.activePatterns,
    required this.riskScore,
    required this.lastAnalysisAt,
  });

  /// Create from SentinelAnalysis
  factory SentinelSnapshot.fromAnalysis(SentinelAnalysis analysis) {
    return SentinelSnapshot(
      riskBand: analysis.riskLevel,
      patternSeverity: analysis.patterns
          .map((p) => p.severity)
          .fold(0.0, (a, b) => math.max(a, b)),
      sustainOk: analysis.riskLevel.index <= RiskLevel.moderate.index,
      activePatterns: analysis.patterns,
      riskScore: analysis.riskScore,
      lastAnalysisAt: DateTime.now(),
    );
  }
}

/// Main transition policy implementation
class TransitionPolicy {
  final TransitionPolicyConfig config;

  TransitionPolicy(this.config);

  /// Make a transition decision based on all three systems
  Future<TransitionOutcome> decide({
    required AtlasSnapshot atlas,
    required RivetSnapshot rivet,
    required SentinelSnapshot sentinel,
    required bool cooldownActive,
  }) async {
    final telemetry = <String, dynamic>{};
    final reasons = <String>[];

    // Start with full telemetry
    telemetry['timestamp'] = DateTime.now().toIso8601String();
    telemetry['config'] = _configToJson();
    telemetry['atlas'] = _atlasToJson(atlas);
    telemetry['rivet'] = _rivetToJson(rivet);
    telemetry['sentinel'] = _sentinelToJson(sentinel);

    // 1. Check cooldown first (hard block)
    if (cooldownActive || atlas.cooldownActive) {
      reasons.add('Cooldown active');
      telemetry['blocked_by'] = 'cooldown';
      return TransitionOutcome(
        decision: TransitionDecision.hold,
        reason: 'Cooldown active - phase change blocked',
        telemetry: telemetry,
      );
    }

    // 2. Check ATLAS margin threshold
    if (atlas.margin < config.atlasMargin) {
      reasons.add('ATLAS margin insufficient (${atlas.margin.toStringAsFixed(3)} < ${config.atlasMargin})');
    }

    // 3. Check ATLAS hysteresis
    if (atlas.hysteresisBlocked) {
      reasons.add('ATLAS hysteresis blocks change');
    }

    // 4. Check RIVET thresholds
    if (rivet.align < config.rivetAlign) {
      reasons.add('RIVET ALIGN insufficient (${rivet.align.toStringAsFixed(3)} < ${config.rivetAlign})');
    }

    if (rivet.trace < config.rivetTrace) {
      reasons.add('RIVET TRACE insufficient (${rivet.trace.toStringAsFixed(3)} < ${config.rivetTrace})');
    }

    // 5. Check RIVET sustainment
    if (rivet.sustainCount < config.sustainW) {
      reasons.add('RIVET sustainment insufficient (${rivet.sustainCount} < ${config.sustainW})');
    }

    // 6. Check RIVET independence
    if (!rivet.sawIndependentInWindow && rivet.sustainCount >= config.sustainGrace) {
      reasons.add('RIVET independence not satisfied');
    }

    // 7. Check novelty cap
    if (rivet.noveltyScore > config.noveltyCap) {
      reasons.add('Novelty score too high (${rivet.noveltyScore.toStringAsFixed(3)} > ${config.noveltyCap})');
    }

    // 8. Check SENTINEL risk threshold
    final adjustedRiskScore = applyRiskDecay(sentinel.riskScore, sentinel.lastAnalysisAt);
    if (adjustedRiskScore > config.riskThreshold) {
      reasons.add('SENTINEL risk too high (${adjustedRiskScore.toStringAsFixed(3)} > ${config.riskThreshold})');
    }

    // 9. Check SENTINEL risk band
    if (sentinel.riskBand.index > RiskLevel.moderate.index) {
      reasons.add('SENTINEL risk band too high (${sentinel.riskBand.name})');
    }

    // 10. Check SENTINEL pattern severity
    if (sentinel.patternSeverity > config.riskThreshold) {
      reasons.add('SENTINEL pattern severity too high (${sentinel.patternSeverity.toStringAsFixed(3)} > ${config.riskThreshold})');
    }

    // 11. Check SENTINEL sustainment
    if (!sentinel.sustainOk) {
      reasons.add('SENTINEL risk not sustained');
    }

    // Decision logic
    final allConditionsMet = reasons.isEmpty;
    final decision = allConditionsMet ? TransitionDecision.promote : TransitionDecision.hold;
    final reason = allConditionsMet 
        ? 'All conditions satisfied - promoting phase'
        : 'Blocked by: ${reasons.join(', ')}';

    // Add decision metadata
    telemetry['decision'] = decision.name;
    telemetry['all_conditions_met'] = allConditionsMet;
    telemetry['blocking_reasons'] = reasons;
    telemetry['adjusted_risk_score'] = adjustedRiskScore;

    return TransitionOutcome(
      decision: decision,
      reason: reason,
      telemetry: telemetry,
    );
  }

  /// Apply risk decay based on time since last analysis
  double applyRiskDecay(double riskScore, DateTime lastAnalysisAt) {
    final daysSinceAnalysis = DateTime.now().difference(lastAnalysisAt).inDays;
    final decayFactor = math.exp(-config.riskDecayRate * daysSinceAnalysis);
    return riskScore * decayFactor;
  }

  /// Convert config to JSON for telemetry
  Map<String, dynamic> _configToJson() => {
    'atlas_margin': config.atlasMargin,
    'atlas_hysteresis': config.atlasHysteresis,
    'rivet_align': config.rivetAlign,
    'rivet_trace': config.rivetTrace,
    'sustain_w': config.sustainW,
    'sustain_grace': config.sustainGrace,
    'novelty_cap': config.noveltyCap,
    'independence_boost': config.independenceBoost,
    'risk_threshold': config.riskThreshold,
    'risk_decay_rate': config.riskDecayRate,
    'cooldown_days': config.cooldown.inDays,
    'risk_window_days': config.riskWindow.inDays,
  };

  /// Convert ATLAS snapshot to JSON
  Map<String, dynamic> _atlasToJson(AtlasSnapshot atlas) => {
    'posterior_scores': atlas.posteriorScores,
    'margin': atlas.margin,
    'current_phase': atlas.currentPhase,
    'last_change_at': atlas.lastChangeAt.toIso8601String(),
    'cooldown_active': atlas.cooldownActive,
    'hysteresis_blocked': atlas.hysteresisBlocked,
  };

  /// Convert RIVET snapshot to JSON
  Map<String, dynamic> _rivetToJson(RivetSnapshot rivet) => {
    'align': rivet.align,
    'trace': rivet.trace,
    'sustain_count': rivet.sustainCount,
    'saw_independent_in_window': rivet.sawIndependentInWindow,
    'independence_set': rivet.independenceSet.toList(),
    'novelty_score': rivet.noveltyScore,
    'gate_open': rivet.gateOpen,
  };

  /// Convert SENTINEL snapshot to JSON
  Map<String, dynamic> _sentinelToJson(SentinelSnapshot sentinel) => {
    'risk_band': sentinel.riskBand.name,
    'pattern_severity': sentinel.patternSeverity,
    'sustain_ok': sentinel.sustainOk,
    'active_patterns': sentinel.activePatterns.map((p) => p.toJson()).toList(),
    'risk_score': sentinel.riskScore,
    'last_analysis_at': sentinel.lastAnalysisAt.toIso8601String(),
  };
}

/// Factory for creating policy instances with different configurations
class TransitionPolicyFactory {
  /// Create production policy
  static TransitionPolicy createProduction() => 
      TransitionPolicy(TransitionPolicyConfig.production);

  /// Create conservative policy
  static TransitionPolicy createConservative() => 
      TransitionPolicy(TransitionPolicyConfig.conservative);

  /// Create aggressive policy
  static TransitionPolicy createAggressive() => 
      TransitionPolicy(TransitionPolicyConfig.aggressive);

  /// Create custom policy
  static TransitionPolicy createCustom(TransitionPolicyConfig config) => 
      TransitionPolicy(config);
}

/// Utility class for policy validation and testing
class TransitionPolicyValidator {
  /// Validate that all thresholds are in valid ranges
  static List<String> validateConfig(TransitionPolicyConfig config) {
    final errors = <String>[];

    if (config.atlasMargin < 0.0 || config.atlasMargin > 1.0) {
      errors.add('ATLAS margin must be between 0.0 and 1.0');
    }

    if (config.rivetAlign < 0.0 || config.rivetAlign > 1.0) {
      errors.add('RIVET ALIGN threshold must be between 0.0 and 1.0');
    }

    if (config.rivetTrace < 0.0 || config.rivetTrace > 1.0) {
      errors.add('RIVET TRACE threshold must be between 0.0 and 1.0');
    }

    if (config.sustainW < 1) {
      errors.add('Sustainment window must be at least 1');
    }

    if (config.riskThreshold < 0.0 || config.riskThreshold > 1.0) {
      errors.add('Risk threshold must be between 0.0 and 1.0');
    }

    if (config.riskDecayRate < 0.0 || config.riskDecayRate > 1.0) {
      errors.add('Risk decay rate must be between 0.0 and 1.0');
    }

    return errors;
  }

  /// Check if a configuration is safe for production
  static bool isProductionSafe(TransitionPolicyConfig config) {
    final errors = validateConfig(config);
    if (errors.isNotEmpty) return false;

    // Additional safety checks
    if (config.atlasMargin < 0.5) return false; // Too permissive
    if (config.rivetAlign < 0.5) return false; // Too permissive
    if (config.riskThreshold > 0.5) return false; // Too restrictive
    if (config.sustainW < 2) return false; // Too permissive

    return true;
  }
}
