import 'dart:math' as math;
import 'rivet_models.dart';

/// Pure function reducer for RIVET state computation
/// 
/// This class provides a stateless way to recompute RIVET states from events,
/// useful for testing and historical analysis. It implements the same algorithms
/// as RivetService but in a functional style.
class RivetReducer {
  /// Recompute RIVET states from a list of events
  /// 
  /// Returns a list of states, one for each event in the input.
  /// The first state corresponds to the first event, etc.
  static List<RivetStateWithGate> recompute(List<RivetEvent> events, RivetConfig config) {
    if (events.isEmpty) {
      return [];
    }

    final List<RivetStateWithGate> states = [];
    RivetState? previousState;

    for (int i = 0; i < events.length; i++) {
      final event = events[i];
      final lastEvent = i > 0 ? events[i - 1] : null;

      // Calculate ALIGN with exponential smoothing
      final beta = 2.0 / (config.N + 1.0);
      final sample = _sampleALIGN(event.predPhase, event.refPhase, event.tolerance);
      final previousAlign = previousState?.align ?? 0.0;
      final newAlign = (1 - beta) * previousAlign + beta * sample;

      // Calculate TRACE with saturating accumulator
      const baseWeight = 1.0;
      final independenceBoost = _independenceMultiplier(event, lastEvent);
      final noveltyBoost = _noveltyMultiplier(event, lastEvent);
      final evidenceIncrement = baseWeight * independenceBoost * noveltyBoost;

      // Convert current TRACE back to accumulated mass, add increment, re-saturate
      final previousTrace = previousState?.trace ?? 0.0;
      final currentMass = -config.K * math.log(1 - previousTrace.clamp(0, 0.999999));
      final newMass = currentMass + evidenceIncrement;
      final newTrace = 1 - math.exp(-newMass / config.K);

      // Sustainment and independence tracking
      final meetsThresholds = (newAlign >= config.Athresh) && (newTrace >= config.Tthresh);
      final newSustainCount = meetsThresholds ? ((previousState?.sustainCount ?? 0) + 1) : 0;
      final sawIndependent = (previousState?.sawIndependentInWindow ?? false) || (independenceBoost > 1.0);

      // Reset independence flag if we broke the sustainment chain
      final updatedSawIndependent = meetsThresholds ? sawIndependent : false;

      // Gate decision: both dials green + sustainment + independence
      final gateOpen = (newSustainCount >= config.W) && updatedSawIndependent;

      final newState = RivetState(
        align: newAlign,
        trace: newTrace,
        sustainCount: newSustainCount,
        sawIndependentInWindow: updatedSawIndependent,
      );

      states.add(RivetStateWithGate(
        state: newState,
        gateOpen: gateOpen,
      ));

      previousState = newState;
    }

    return states;
  }

  /// Calculate sample ALIGN score: s_i = max(0, 1 - |ref - pred| / tol)
  /// For categorical phases, simplified to s_i = (ref==pred)?1:0
  static double _sampleALIGN(String pred, String ref, Map<String, double> tolerance) {
    // Categorical matching - could be enhanced with tolerance map later
    return (pred == ref) ? 1.0 : 0.0;
  }

  /// Independence multiplier based on different day or source from last event
  /// Boosts evidence weight when events come from independent contexts
  static double _independenceMultiplier(RivetEvent event, RivetEvent? lastEvent) {
    if (lastEvent == null) return 1.2;

    final bool differentDay = event.date.difference(lastEvent.date).inDays >= 1;
    final bool differentSource = event.source != lastEvent.source;

    return (differentDay || differentSource) ? 1.2 : 1.0;
  }

  /// Novelty multiplier via Jaccard distance over selected keywords
  /// Rewards keyword drift as additional evidence variety
  static double _noveltyMultiplier(RivetEvent event, RivetEvent? lastEvent) {
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
}

/// Extended RivetState that includes gateOpen property for reducer results
/// 
/// This is used by RivetReducer to return states with computed gate status
/// without modifying the base RivetState Hive model.
class RivetStateWithGate {
  final RivetState state;
  final bool gateOpen;

  RivetStateWithGate({
    required this.state,
    required this.gateOpen,
  });

  // Delegate properties to state for convenience
  double get align => state.align;
  double get trace => state.trace;
  int get sustainCount => state.sustainCount;
  bool get sawIndependentInWindow => state.sawIndependentInWindow;
}

