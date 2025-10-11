import 'dart:math' as math;
import 'rivet_models.dart';

/// Pure reducer for RIVET state computation
/// Provides deterministic recompute pipeline for undo-on-delete behavior
class RivetReducer {
  /// Recompute RIVET state from a complete event history
  /// This is the core deterministic function that enables undo-on-delete
  static List<RivetState> recompute(
    List<RivetEvent> events, 
    RivetConfig config,
  ) {
    // Sort events by date to ensure deterministic processing
    final sortedEvents = [...events]..sort((a, b) => a.date.compareTo(b.date));
    
    // Initialize state variables
    double align = 0.0;                 // bounded [0,1]
    double trace = 0.0;                 // bounded [0,1]
    double sumEvidenceSoFar = 0.0;      // cumulative evidence for TRACE
    int sustainCount = 0;               // consecutive threshold meetings
    final window = <RivetEvent>[];      // rolling window for independence
    bool sawIndependentInWindow = false;
    final states = <RivetState>[];

    for (final event in sortedEvents) {
      // Calculate ALIGN score (EMA smoothing)
      final sampleAlign = _calculateSampleAlign(event, config);
      final beta = 2.0 / (config.N + 1.0);
      align = (1.0 - beta) * align + beta * sampleAlign;
      align = align.clamp(0.0, 1.0); // Ensure boundedness

      // Calculate TRACE increment (saturating accumulator)
      final evidenceIncrement = _calculateEvidenceIncrement(
        event, 
        window.isNotEmpty ? window.last : null,
        config,
      );
      sumEvidenceSoFar += evidenceIncrement;
      trace = 1.0 - math.exp(-sumEvidenceSoFar / config.K);
      trace = trace.clamp(0.0, 1.0); // Ensure boundedness

      // Maintain rolling window for sustainment/independence
      window.add(event);
      while (window.length > config.W) {
        window.removeAt(0);
      }
      
      // Check independence in current window
      sawIndependentInWindow = _checkIndependenceInWindow(window);

      // Update sustainment counter
      final meetsThresholds = (align >= config.Athresh) && (trace >= config.Tthresh);
      sustainCount = meetsThresholds ? (sustainCount + 1).clamp(0, config.W) : 0;

      // Determine gate status
      final gateOpen = meetsThresholds && 
                      sustainCount >= config.W && 
                      sawIndependentInWindow;

      // Create state for this event
      final state = RivetState(
        align: align,
        trace: trace,
        sustainCount: sustainCount,
        sawIndependentInWindow: sawIndependentInWindow,
        eventId: event.eventId,
        date: event.date,
        gateOpen: gateOpen,
      );

      states.add(state);
    }

    return states;
  }

  /// Calculate sample ALIGN score for an event
  /// For categorical phases: s_i = (pred==ref)?1:0
  static double _calculateSampleAlign(RivetEvent event, RivetConfig config) {
    // Categorical matching - could be enhanced with tolerance map later
    return (event.predPhase == event.refPhase) ? 1.0 : 0.0;
  }

  /// Calculate evidence increment for TRACE
  /// Includes independence and novelty multipliers
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
  /// Boosts evidence weight when events come from independent contexts
  static double _calculateIndependenceMultiplier(RivetEvent event, RivetEvent? lastEvent) {
    if (lastEvent == null) return 1.2;
    
    final differentDay = event.date.difference(lastEvent.date).inDays >= 1;
    final differentSource = event.source != lastEvent.source;
    
    return (differentDay || differentSource) ? 1.2 : 1.0;
  }

  /// Calculate novelty multiplier via Jaccard distance over keywords
  /// Rewards keyword drift as additional evidence variety
  static double _calculateNoveltyMultiplier(RivetEvent event, RivetEvent? lastEvent) {
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

  /// Check if any event in the window is independent
  static bool _checkIndependenceInWindow(List<RivetEvent> window) {
    if (window.isEmpty) return false;
    
    for (int i = 1; i < window.length; i++) {
      final current = window[i];
      final previous = window[i - 1];
      
      final differentDay = current.date.difference(previous.date).inDays >= 1;
      final differentSource = current.source != previous.source;
      
      if (differentDay || differentSource) {
        return true;
      }
    }
    
    return false;
  }

  /// Generate gate decision with transparency
  static RivetGateDecision generateGateDecision(
    RivetState state,
    RivetConfig config,
  ) {
    final meetsThresholds = (state.align >= config.Athresh) && (state.trace >= config.Tthresh);
    final gateOpen = meetsThresholds && 
                    state.sustainCount >= config.W && 
                    state.sawIndependentInWindow;

    String? whyNot;
    if (!gateOpen) {
      if (!meetsThresholds) {
        whyNot = "Needs ALIGN≥${config.Athresh.toStringAsFixed(1)} and TRACE≥${config.Tthresh.toStringAsFixed(1)} together";
      } else if (!state.sawIndependentInWindow) {
        whyNot = "Need at least one independent event in window";
      } else {
        whyNot = "Needs sustainment ${state.sustainCount}/${config.W}";
      }
    }

    return RivetGateDecision(
      open: gateOpen,
      stateAfter: state,
      whyNot: whyNot,
    );
  }
}
