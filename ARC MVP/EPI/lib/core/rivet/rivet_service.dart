import 'rivet_models.dart';
import 'rivet_reducer.dart';

/// Core RIVET service implementing ALIGN and TRACE calculations with sustainment gating
/// 
/// Now supports deterministic recompute for delete/edit operations using RivetReducer
class RivetService {
  RivetState state;
  final RivetConfig config;
  List<RivetEvent> _eventHistory = [];

  RivetService({
    RivetState? initial,
    RivetConfig? config,
  }) : state = initial ?? 
        const RivetState(
          align: 0,
          trace: 0,
          sustainCount: 0,
          sawIndependentInWindow: false,
        ),
        config = config ?? const RivetConfig();

  /// Get current configuration
  RivetConfig get currentConfig => config;


  /// Apply a new event and recompute state
  RivetGateDecision apply(RivetEvent event) {
    // Add event to history
    _eventHistory.add(event);
    
    // Recompute all states from scratch
    final states = RivetReducer.recompute(_eventHistory, config);
    
    if (states.isNotEmpty) {
      state = states.last;
    }
    
    // Get gate decision
    final decision = RivetReducer.getLatestGateDecision(states, config);
    
    // Log gate decision for debugging
    print('DEBUG RIVET: ALIGN=${state.align.toStringAsFixed(3)}, '
          'TRACE=${state.trace.toStringAsFixed(3)}, '
          'Sustain=${state.sustainCount}/${config.W}, '
          'Independent=${state.sawIndependentInWindow}, '
          'Gate=${decision.open ? "OPEN" : "CLOSED"}${decision.whyNot != null ? " (${decision.whyNot})" : ""}');

    return decision;
  }

  /// Delete an event by ID and recompute state
  RivetGateDecision delete(String eventId) {
    // Remove event from history
    _eventHistory.removeWhere((event) => event.eventId == eventId);
    
    // Recompute all states from scratch
    final states = RivetReducer.recompute(_eventHistory, config);
    
    if (states.isNotEmpty) {
      state = states.last;
    } else {
      // Reset to initial state if no events remain
      state = const RivetState(
        align: 0,
        trace: 0,
        sustainCount: 0,
        sawIndependentInWindow: false,
      );
    }
    
    // Get gate decision
    final decision = RivetReducer.getLatestGateDecision(states, config);
    
    // Log recompute for debugging
    print('DEBUG RIVET RECOMPUTE after delete: events=${_eventHistory.length}, '
          'ALIGN=${state.align.toStringAsFixed(3)}, '
          'TRACE=${state.trace.toStringAsFixed(3)}, '
          'Gate=${decision.open ? "OPEN" : "CLOSED"}${decision.whyNot != null ? " (${decision.whyNot})" : ""}');

    return decision;
  }

  /// Edit an event by replacing it with updated version and recompute state
  RivetGateDecision edit(RivetEvent updatedEvent) {
    // Find and replace event in history
    final index = _eventHistory.indexWhere((event) => event.eventId == updatedEvent.eventId);
    if (index != -1) {
      _eventHistory[index] = updatedEvent.copyWith(version: _eventHistory[index].version + 1);
    } else {
      // If not found, add as new event
      _eventHistory.add(updatedEvent);
    }
    
    // Recompute all states from scratch
    final states = RivetReducer.recompute(_eventHistory, config);
    
    if (states.isNotEmpty) {
      state = states.last;
    }
    
    // Get gate decision
    final decision = RivetReducer.getLatestGateDecision(states, config);
    
    // Log recompute for debugging
    print('DEBUG RIVET RECOMPUTE after edit: events=${_eventHistory.length}, '
          'ALIGN=${state.align.toStringAsFixed(3)}, '
          'TRACE=${state.trace.toStringAsFixed(3)}, '
          'Gate=${decision.open ? "OPEN" : "CLOSED"}${decision.whyNot != null ? " (${decision.whyNot})" : ""}');

    return decision;
  }

  /// Get the complete event history
  List<RivetEvent> get eventHistory => List.unmodifiable(_eventHistory);

  /// Set event history (for loading from storage)
  void setEventHistory(List<RivetEvent> events) {
    _eventHistory = List.from(events);
    
    // Recompute state from the loaded history
    final states = RivetReducer.recompute(_eventHistory, config);
    if (states.isNotEmpty) {
      state = states.last;
    }
  }

  /// Get current RIVET state (read-only)
  RivetState getCurrentState() => state;

  /// Reset RIVET state (for testing or user-initiated reset)
  void reset() {
    _eventHistory.clear();
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
    return (state.align >= config.Athresh) && 
           (state.trace >= config.Tthresh) && 
           (state.sustainCount >= config.W) && 
           state.sawIndependentInWindow;
  }

  /// Get human-readable status summary
  String getStatusSummary() {
    final alignStatus = state.align >= config.Athresh ? "✓" : "✗";
    final traceStatus = state.trace >= config.Tthresh ? "✓" : "✗";
    final sustainStatus = state.sustainCount >= config.W ? "✓" : "✗";
    final independentStatus = state.sawIndependentInWindow ? "✓" : "✗";
    
    return "ALIGN $alignStatus${(state.align * 100).toStringAsFixed(0)}% "
           "TRACE $traceStatus${(state.trace * 100).toStringAsFixed(0)}% "
           "Sustain $sustainStatus${state.sustainCount}/${config.W} "
           "Independent $independentStatus";
  }
}