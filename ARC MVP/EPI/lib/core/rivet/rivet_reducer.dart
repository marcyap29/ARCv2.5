import 'dart:math' as math;
import 'rivet_models.dart';

/// Pure reducer for RIVET state computation
/// Provides deterministic recompute functionality for delete/edit operations
class RivetReducer {
  /// Recompute RIVET states from a complete event history
  /// This is the core pure function that ensures deterministic results
  static List<RivetState> recompute(
    List<RivetEvent> events, 
    RivetConfig config,
  ) {
    if (events.isEmpty) {
      return [];
    }

    // Sort events by date to ensure chronological order
    final sortedEvents = [...events]..sort((a, b) => a.date.compareTo(b.date));
    
    // Initialize state variables
    double align = 0.0;
    double trace = 0.0;
    double sumEvidenceSoFar = 0.0;
    int sustainCount = 0;
    final window = <RivetEvent>[];
    bool sawIndependentInWindow = false;
    final states = <RivetState>[];

    for (int i = 0; i < sortedEvents.length; i++) {
      final event = sortedEvents[i];
      
      // Calculate ALIGN score using EMA smoothing
      final sampleAlign = _calculateSampleAlign(event, config);
      final beta = 2.0 / (config.N + 1.0);
      align = (1.0 - beta) * align + beta * sampleAlign;
      
      // Ensure ALIGN stays bounded in [0,1]
      align = align.clamp(0.0, 1.0);

      // Calculate TRACE score using saturator
      final evidenceIncrement = _calculateEvidenceIncrement(
        event, 
        i > 0 ? sortedEvents[i - 1] : null,
        config,
      );
      sumEvidenceSoFar += evidenceIncrement;
      trace = 1.0 - math.exp(-sumEvidenceSoFar / config.K);
      
      // Ensure TRACE stays bounded in [0,1]
      trace = trace.clamp(0.0, 1.0);

      // Maintain rolling window for sustainment/independence
      window.add(event);
      while (window.length > config.W) {
        window.removeAt(0);
      }
      
      // Check for independence in current window
      sawIndependentInWindow = window.any((e) => _isIndependent(e, window));

      // Update sustainment counter
      final meetsThresholds = (align >= config.Athresh) && (trace >= config.Tthresh);
      sustainCount = meetsThresholds ? (sustainCount + 1).clamp(0, config.W) : 0;

      // Create state for this event
      final state = RivetState(
        align: align,
        trace: trace,
        sustainCount: sustainCount,
        sawIndependentInWindow: sawIndependentInWindow,
        eventId: event.eventId,
        date: event.date,
      );
      
      states.add(state);
    }

    return states;
  }

  /// Calculate sample ALIGN score for a single event
  /// For categorical phases: s_i = (pred==ref)?1:0
  static double _calculateSampleAlign(RivetEvent event, RivetConfig config) {
    // Categorical matching - could be enhanced with tolerance map later
    return (event.predPhase == event.refPhase) ? 1.0 : 0.0;
  }

  /// Calculate evidence increment for TRACE calculation
  static double _calculateEvidenceIncrement(
    RivetEvent event, 
    RivetEvent? lastEvent,
    RivetConfig config,
  ) {
    const baseWeight = 1.0;
    final independenceMultiplier = _calculateIndependenceMultiplier(event, lastEvent);
    final noveltyMultiplier = _calculateNoveltyMultiplier(event, lastEvent);
    
    return baseWeight * independenceMultiplier * noveltyMultiplier;
  }

  /// Calculate independence multiplier based on different day or source
  static double _calculateIndependenceMultiplier(
    RivetEvent event, 
    RivetEvent? lastEvent,
  ) {
    if (lastEvent == null) return 1.2;
    
    final differentDay = event.date.difference(lastEvent.date).inDays >= 1;
    final differentSource = event.source != lastEvent.source;
    
    return (differentDay || differentSource) ? 1.2 : 1.0;
  }

  /// Calculate novelty multiplier via Jaccard distance over keywords
  static double _calculateNoveltyMultiplier(
    RivetEvent event, 
    RivetEvent? lastEvent,
  ) {
    if (lastEvent == null) return 1.1;
    
    final currentKeywords = event.keywords;
    final lastKeywords = lastEvent.keywords;
    
    if (currentKeywords.isEmpty && lastKeywords.isEmpty) return 1.0;
    
    final intersection = currentKeywords.intersection(lastKeywords).length.toDouble();
    final union = currentKeywords.union(lastKeywords).length.toDouble();
    
    if (union == 0) return 1.0;
    
    final jaccard = intersection / union;
    final drift = 1.0 - jaccard;
    
    return 1.0 + 0.5 * drift; // Range: 1.0 to 1.5
  }

  /// Check if an event is independent within its window
  static bool _isIndependent(RivetEvent event, List<RivetEvent> window) {
    if (window.length <= 1) return true;
    
    final otherEvents = window.where((e) => e.eventId != event.eventId).toList();
    if (otherEvents.isEmpty) return true;
    
    for (final other in otherEvents) {
      final differentDay = event.date.difference(other.date).inDays >= 1;
      final differentSource = event.source != other.source;
      
      if (differentDay || differentSource) {
        return true;
      }
    }
    
    return false;
  }

  /// Create a checkpoint snapshot for efficient recompute
  static RivetSnapshot createSnapshot(
    String eventId,
    DateTime date,
    double align,
    double trace,
    double sumEvidenceSoFar,
    int eventCount,
  ) {
    return RivetSnapshot(
      eventId: eventId,
      date: date,
      align: align,
      trace: trace,
      sumEvidenceSoFar: sumEvidenceSoFar,
      eventCount: eventCount,
    );
  }

  /// Get the latest gate decision from a state sequence
  static RivetGateDecision getLatestGateDecision(
    List<RivetState> states,
    RivetConfig config,
  ) {
    if (states.isEmpty) {
      return RivetGateDecision(
        open: false,
        stateAfter: const RivetState(
          align: 0,
          trace: 0,
          sustainCount: 0,
          sawIndependentInWindow: false,
        ),
        whyNot: "No events processed",
      );
    }

    final latestState = states.last;
    final gateOpen = _evaluateGate(latestState, config);
    
    String? whyNot;
    if (!gateOpen) {
      if (latestState.align < config.Athresh) {
        whyNot = "ALIGN below threshold (${(latestState.align * 100).toStringAsFixed(1)}% < ${(config.Athresh * 100).toStringAsFixed(1)}%)";
      } else if (latestState.trace < config.Tthresh) {
        whyNot = "TRACE below threshold (${(latestState.trace * 100).toStringAsFixed(1)}% < ${(config.Tthresh * 100).toStringAsFixed(1)}%)";
      } else if (latestState.sustainCount < config.W) {
        whyNot = "Needs sustainment ${latestState.sustainCount}/${config.W}";
      } else if (!latestState.sawIndependentInWindow) {
        whyNot = "Need at least one independent event in window";
      }
    }

    return RivetGateDecision(
      open: gateOpen,
      stateAfter: latestState,
      whyNot: whyNot,
    );
  }

  /// Evaluate gate condition for a state
  static bool _evaluateGate(RivetState state, RivetConfig config) {
    return (state.align >= config.Athresh) &&
           (state.trace >= config.Tthresh) &&
           (state.sustainCount >= config.W) &&
           state.sawIndependentInWindow;
  }
}
