import 'dart:math' as math;
import 'rivet_models.dart';

/// Core RIVET service implementing ALIGN and TRACE calculations with sustainment gating
/// 
/// Formulas from RIVET specification:
/// - ALIGN_t = (1-β)ALIGN_{t-1} + β*s_t, with β = 2/(N+1)
/// - TRACE_t = 1 - exp(- Σ e_i / K)
/// - Gate opens when (ALIGN≥A* ∧ TRACE≥T*) sustained for W entries with ≥1 independent event
class RivetService {
  RivetState state;
  final double Athresh; // ALIGN threshold (A*)
  final double Tthresh; // TRACE threshold (T*)
  final int W; // sustainment window size
  final int N; // smoothing parameter for ALIGN
  final double K; // saturation parameter for TRACE

  RivetService({
    RivetState? initial,
    this.Athresh = 0.6,
    this.Tthresh = 0.6,
    this.W = 2,
    this.N = 10,
    this.K = 20,
  }) : state = initial ?? 
        const RivetState(
          align: 0,
          trace: 0,
          sustainCount: 0,
          sawIndependentInWindow: false,
        );

  /// Calculate sample ALIGN score: s_i = max(0, 1 - |ref - pred| / tol)
  /// For categorical phases, simplified to s_i = (ref==pred)?1:0
  double _sampleALIGN(String pred, String ref, Map<String, double> tolerance) {
    // Categorical matching - could be enhanced with tolerance map later
    return (pred == ref) ? 1.0 : 0.0;
  }

  /// Independence multiplier based on different day or source from last event
  /// Boosts evidence weight when events come from independent contexts
  double _independenceMultiplier(RivetEvent event, RivetEvent? lastEvent) {
    if (lastEvent == null) return 1.2;
    
    final bool differentDay = event.date.difference(lastEvent.date).inDays >= 1;
    final bool differentSource = event.source != lastEvent.source;
    
    return (differentDay || differentSource) ? 1.2 : 1.0;
  }

  /// Novelty multiplier via Jaccard distance over selected keywords
  /// Rewards keyword drift as additional evidence variety
  double _noveltyMultiplier(RivetEvent event, RivetEvent? lastEvent) {
    if (lastEvent == null) return 1.1;
    
    final a = event.keywords;
    final b = lastEvent.keywords;
    
    if (a.isEmpty && b.isEmpty) return 1.0;
    
    final intersection = a.intersection(b).length.toDouble();
    final union = a.union(b).length.toDouble();
    
    if (union == 0) return 1.0;
    
    final jaccard = intersection / union;
    final drift = 1.0 - jaccard;
    
    return 1.0 + 0.5 * drift; // Range: 1.0 to 1.5
  }

  /// Core RIVET ingestion: update ALIGN/TRACE and evaluate gate
  RivetGateDecision ingest(RivetEvent event, {RivetEvent? lastEvent}) {
    // Update ALIGN with exponential smoothing
    final beta = 2.0 / (N + 1.0);
    final sample = _sampleALIGN(event.predPhase, event.refPhase, event.tolerance);
    final newAlign = (1 - beta) * state.align + beta * sample;

    // Update TRACE with saturating accumulator
    const baseWeight = 1.0;
    final independenceBoost = _independenceMultiplier(event, lastEvent);
    final noveltyBoost = _noveltyMultiplier(event, lastEvent);
    final evidenceIncrement = baseWeight * independenceBoost * noveltyBoost;

    // Convert current TRACE back to accumulated mass, add increment, re-saturate
    final currentMass = -K * math.log(1 - state.trace.clamp(0, 0.999999));
    final newMass = currentMass + evidenceIncrement;
    final newTrace = 1 - math.exp(-newMass / K);

    // Sustainment and independence tracking
    final meetsThresholds = (newAlign >= Athresh) && (newTrace >= Tthresh);
    final newSustainCount = meetsThresholds ? (state.sustainCount + 1) : 0;
    final sawIndependent = state.sawIndependentInWindow || (independenceBoost > 1.0);

    // Reset independence flag if we broke the sustainment chain
    final updatedSawIndependent = meetsThresholds ? sawIndependent : false;

    final updatedState = RivetState(
      align: newAlign,
      trace: newTrace,
      sustainCount: newSustainCount,
      sawIndependentInWindow: updatedSawIndependent,
    );

    // Gate decision: both dials green + sustainment + independence
    final gateOpen = (updatedState.sustainCount >= W) && updatedState.sawIndependentInWindow;

    String? whyNot;
    if (!gateOpen) {
      if (!meetsThresholds) {
        whyNot = "Needs ALIGN≥${Athresh.toStringAsFixed(1)} and TRACE≥${Tthresh.toStringAsFixed(1)} together";
      } else if (!updatedState.sawIndependentInWindow) {
        whyNot = "Need at least one independent event in window";
      } else {
        whyNot = "Needs sustainment ${updatedState.sustainCount}/$W";
      }
    }

    // Update internal state
    state = updatedState;

    // Log gate decision for debugging
    print('DEBUG RIVET: ALIGN=${newAlign.toStringAsFixed(3)}, '
          'TRACE=${newTrace.toStringAsFixed(3)}, '
          'Sustain=$newSustainCount/$W, '
          'Independent=$updatedSawIndependent, '
          'Gate=${gateOpen ? "OPEN" : "CLOSED"}${whyNot != null ? " ($whyNot)" : ""}');

    return RivetGateDecision(
      open: gateOpen,
      stateAfter: updatedState,
      whyNot: whyNot,
    );
  }

  /// Get current RIVET state (read-only)
  RivetState getCurrentState() => state;

  /// Reset RIVET state (for testing or user-initiated reset)
  void reset() {
    state = const RivetState(
      align: 0,
      trace: 0,
      sustainCount: 0,
      sawIndependentInWindow: false,
    );
  }

  /// Update state from external source (e.g., loaded from storage)
  void updateState(RivetState newState) {
    state = newState;
  }

  /// Check if current state would allow gate to open
  bool wouldGateOpen() {
    return (state.align >= Athresh) && 
           (state.trace >= Tthresh) && 
           (state.sustainCount >= W) && 
           state.sawIndependentInWindow;
  }

  /// Get human-readable status summary
  String getStatusSummary() {
    final alignStatus = state.align >= Athresh ? "✓" : "✗";
    final traceStatus = state.trace >= Tthresh ? "✓" : "✗";
    final sustainStatus = state.sustainCount >= W ? "✓" : "✗";
    final independentStatus = state.sawIndependentInWindow ? "✓" : "✗";
    
    return "ALIGN $alignStatus${(state.align * 100).toStringAsFixed(0)}% "
           "TRACE $traceStatus${(state.trace * 100).toStringAsFixed(0)}% "
           "Sustain $sustainStatus${state.sustainCount}/$W "
           "Independent $independentStatus";
  }
}