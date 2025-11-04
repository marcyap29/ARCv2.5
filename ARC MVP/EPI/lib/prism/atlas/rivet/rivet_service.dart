import 'dart:math' as math;
import 'rivet_models.dart';

/// Core RIVET service implementing ALIGN and TRACE calculations with sustainment gating
///
/// RIVET (Risk-Validation Evidence Tracker) validates keyword evidence before allowing
/// phase transitions. It uses two metrics to ensure phase changes are well-supported:
///
/// ## Core Metrics
/// - **ALIGN**: Alignment score measuring consistency between predicted and actual phase
///   - Formula: ALIGN_t = (1-β)ALIGN_{t-1} + β*s_t
///   - β = 2/(N+1) where N is smoothing parameter (default: 10)
///   - s_t is sample alignment for current entry
/// - **TRACE**: Evidence accumulation score tracking keyword evidence over time
///   - Formula: TRACE_t = 1 - exp(- Σ e_i / K)
///   - e_i is evidence weight for keyword i
///   - K is saturation parameter (default: 20)
///
/// ## Gate Opening Conditions
/// The gate opens when ALL of the following are true:
/// 1. ALIGN ≥ A* (ALIGN threshold, default: 0.6)
/// 2. TRACE ≥ T* (TRACE threshold, default: 0.6)
/// 3. Conditions sustained for W entries (sustainment window, default: 2)
/// 4. At least one independent event observed in the window
///
/// ## Architecture Context
/// Part of PRISM ATLAS module. Works in conjunction with PhaseTracker:
/// - PhaseTracker identifies candidate phase changes
/// - RIVET validates the change is well-supported by evidence
/// - Only validated changes are applied to user profile
///
/// ## Data Flow
/// ```
/// Journal Entry → Keyword Extraction → RIVET Event
///   → ALIGN/TRACE Update → Gate Status Check
///   → Phase Change Allowed (if gate open)
/// ```
class RivetService {
  RivetState state;
  final double Athresh; // ALIGN threshold (A*)
  final double Tthresh; // TRACE threshold (T*)
  final int W; // sustainment window size
  final int N; // smoothing parameter for ALIGN
  final double K; // saturation parameter for TRACE
  
  // History tracking
  final List<RivetEvent> _eventHistory = [];
  final List<RivetState> _stateHistory = [];
  
  /// Get event history
  List<RivetEvent> get eventHistory => List.unmodifiable(_eventHistory);
  
  /// Get state history
  List<RivetState> get stateHistory => List.unmodifiable(_stateHistory);
  
  /// Get current state (alias for getCurrentState())
  RivetState get currentState => state;

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
    lastEvent ??= _eventHistory.isNotEmpty ? _eventHistory.last : null;
    
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
    
    // Track history
    _eventHistory.add(event);
    _stateHistory.add(updatedState);

    // Calculate phase transition insights
    final transitionInsights = _calculatePhaseTransitionInsights(
      currentPhase: event.refPhase,
      eventHistory: _eventHistory,
      updatedState: updatedState,
    );

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
      transitionInsights: transitionInsights,
    );
  }
  
  /// Apply event (alias for ingest, for test compatibility)
  Future<RivetGateDecision> apply(RivetEvent event) async {
    return ingest(event);
  }
  
  /// Edit an event in history
  Future<RivetGateDecision> edit(RivetEvent editedEvent) async {
    final index = _eventHistory.indexWhere((e) => e.eventId == editedEvent.eventId);
    if (index == -1) {
      // Event not found, treat as new
      return apply(editedEvent);
    }
    
    // Replace event in history
    _eventHistory[index] = editedEvent;
    
    // Rebuild state history from beginning
    _stateHistory.clear();
    state = const RivetState(
      align: 0,
      trace: 0,
      sustainCount: 0,
      sawIndependentInWindow: false,
    );
    
    // Re-apply all events
    for (final event in _eventHistory) {
      ingest(event);
    }
    
    return RivetGateDecision(
      open: wouldGateOpen(),
      stateAfter: state,
      whyNot: wouldGateOpen() ? null : "State not meeting gate requirements",
    );
  }
  
  /// Delete an event from history
  Future<RivetGateDecision> delete(String eventId) async {
    final index = _eventHistory.indexWhere((e) => e.eventId == eventId);
    if (index == -1) {
      // Event not found, return current state
      return RivetGateDecision(
        open: wouldGateOpen(),
        stateAfter: state,
        whyNot: wouldGateOpen() ? null : "Event not found",
      );
    }
    
    // Remove event from history
    _eventHistory.removeAt(index);
    
    // Rebuild state history from beginning
    _stateHistory.clear();
    state = const RivetState(
      align: 0,
      trace: 0,
      sustainCount: 0,
      sawIndependentInWindow: false,
    );
    
    // Re-apply all remaining events
    for (final event in _eventHistory) {
      ingest(event);
    }
    
    return RivetGateDecision(
      open: wouldGateOpen(),
      stateAfter: state,
      whyNot: wouldGateOpen() ? null : "State not meeting gate requirements",
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
    final gateStatus = wouldGateOpen() ? 'OPEN' : 'CLOSED';
    return 'ALIGN=${state.align.toStringAsFixed(2)}, '
           'TRACE=${state.trace.toStringAsFixed(2)}, '
           'Sustain=${state.sustainCount}/$W, '
           'Independent=${state.sawIndependentInWindow ? "Yes" : "No"}, '
           'Gate=$gateStatus';
  }

  /// Get gate explanation (alias for getStatusSummary)
  String getGateExplanation() {
    return getStatusSummary();
  }

  /// Calculate phase transition insights from event history
  PhaseTransitionInsights? _calculatePhaseTransitionInsights({
    required String currentPhase,
    required List<RivetEvent> eventHistory,
    required RivetState updatedState,
  }) {
    if (eventHistory.length < 3) {
      // Need at least a few events to detect transitions
      return null;
    }

    // Analyze phase distribution in recent events
    final recentEvents = eventHistory.length > 10 
        ? eventHistory.sublist(eventHistory.length - 10) 
        : eventHistory;
    
    final phaseCounts = <String, int>{};
    final phaseConfidences = <String, List<double>>{};
    
    for (final event in recentEvents) {
      final pred = event.predPhase;
      phaseCounts[pred] = (phaseCounts[pred] ?? 0) + 1;
      
      // Calculate confidence based on alignment with ref phase
      final confidence = (pred == event.refPhase) ? 1.0 : 0.5;
      phaseConfidences[pred] = (phaseConfidences[pred] ?? [])..add(confidence);
    }

    // Find most common approaching phase (different from current)
    String? approachingPhase;
    double maxApproachConfidence = 0.0;
    
    for (final entry in phaseCounts.entries) {
      if (entry.key != currentPhase) {
        final avgConfidence = phaseConfidences[entry.key] != null
            ? phaseConfidences[entry.key]!.reduce((a, b) => a + b) / phaseConfidences[entry.key]!.length
            : 0.5;
        final approachScore = (entry.value / recentEvents.length) * avgConfidence;
        
        if (approachScore > maxApproachConfidence) {
          maxApproachConfidence = approachScore;
          approachingPhase = entry.key;
        }
      }
    }

    // Calculate shift percentage based on recent trends
    double shiftPercentage = 0.0;
    TransitionDirection direction = TransitionDirection.stable;
    
    if (approachingPhase != null) {
      // Compare early vs recent events in window
      final midPoint = recentEvents.length ~/ 2;
      final earlyPhases = recentEvents.sublist(0, midPoint).map((e) => e.predPhase).toList();
      final recentPhases = recentEvents.sublist(midPoint).map((e) => e.predPhase).toList();
      
      final earlyApproachCount = earlyPhases.where((p) => p == approachingPhase).length;
      final recentApproachCount = recentPhases.where((p) => p == approachingPhase).length;
      
      final earlyPercent = earlyPhases.isEmpty ? 0.0 : (earlyApproachCount / earlyPhases.length) * 100;
      final recentPercent = recentPhases.isEmpty ? 0.0 : (recentApproachCount / recentPhases.length) * 100;
      
      shiftPercentage = (recentPercent - earlyPercent).abs();
      direction = recentPercent > earlyPercent 
          ? TransitionDirection.toward 
          : (recentPercent < earlyPercent ? TransitionDirection.away : TransitionDirection.stable);
    }

    // Generate measurable signs
    final measurableSigns = _generateMeasurableSigns(
      currentPhase: currentPhase,
      approachingPhase: approachingPhase,
      shiftPercentage: shiftPercentage,
      direction: direction,
      updatedState: updatedState,
      phaseCounts: phaseCounts,
    );

    // Calculate contributing metrics
    final contributingMetrics = <String, double>{
      'align_score': updatedState.align,
      'trace_score': updatedState.trace,
      'sustainment': updatedState.sustainCount / W.toDouble(),
      'phase_diversity': phaseCounts.length.toDouble(),
      'transition_momentum': shiftPercentage / 100.0,
    };

    // Transition confidence based on ALIGN, TRACE, and phase consistency
    final transitionConfidence = (updatedState.align * 0.4 + 
                                  updatedState.trace * 0.3 + 
                                  (approachingPhase != null ? maxApproachConfidence : 0.0) * 0.3).clamp(0.0, 1.0);

    return PhaseTransitionInsights(
      currentPhase: currentPhase,
      approachingPhase: approachingPhase,
      shiftPercentage: shiftPercentage,
      measurableSigns: measurableSigns,
      transitionConfidence: transitionConfidence,
      direction: direction,
      contributingMetrics: contributingMetrics,
    );
  }

  /// Generate measurable signs of intelligence growing
  List<String> _generateMeasurableSigns({
    required String currentPhase,
    String? approachingPhase,
    required double shiftPercentage,
    required TransitionDirection direction,
    required RivetState updatedState,
    required Map<String, int> phaseCounts,
  }) {
    final signs = <String>[];
    
    // Primary shift sign (respect direction)
    if (approachingPhase != null && shiftPercentage > 5.0) {
      final percentage = shiftPercentage.toStringAsFixed(0);
      switch (direction) {
        case TransitionDirection.toward:
      signs.add('Your reflection patterns have shifted $percentage% toward $approachingPhase.');
          break;
        case TransitionDirection.away:
          signs.add('Your reflection patterns have shifted $percentage% away from $approachingPhase.');
          break;
        case TransitionDirection.stable:
          // Don't add a shift message if stable
          break;
      }
    }

    // ALIGN-based signs
    if (updatedState.align > 0.7) {
      final alignPercent = (updatedState.align * 100).toStringAsFixed(0);
      signs.add('Phase predictions align $alignPercent% with your confirmed experiences.');
    }

    // TRACE-based signs
    if (updatedState.trace > 0.6) {
      final tracePercent = (updatedState.trace * 100).toStringAsFixed(0);
      signs.add('Evidence accumulation is $tracePercent% complete for phase validation.');
    }

    // Phase diversity signs
    if (phaseCounts.length >= 3) {
      signs.add('Your patterns show engagement across ${phaseCounts.length} different phase contexts.');
    }

    // Sustainment signs
    if (updatedState.sustainCount >= W - 1) {
      signs.add('Phase indicators have been consistent across ${updatedState.sustainCount} recent entries.');
    }

    // Keyword novelty (if we can track it)
    if (updatedState.sawIndependentInWindow) {
      signs.add('Recent reflections show independent validation across different contexts.');
    }

    // Transition momentum (only for toward direction to avoid redundancy with primary sign)
    if (direction == TransitionDirection.toward && shiftPercentage > 10.0) {
      signs.add('Transition momentum toward $approachingPhase is building with ${shiftPercentage.toStringAsFixed(0)}% shift.');
    }

    return signs;
  }
}