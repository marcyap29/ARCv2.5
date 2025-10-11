import 'rivet_models.dart';
import 'rivet_reducer.dart';

/// Core RIVET service implementing deterministic reducer pattern with undo-on-delete
/// 
/// Uses RivetReducer for deterministic recompute pipeline:
/// - ALIGN_t = (1-β)ALIGN_{t-1} + β*s_t, with β = 2/(N+1)
/// - TRACE_t = 1 - exp(- Σ e_i / K)
/// - Gate opens when (ALIGN≥A* ∧ TRACE≥T*) sustained for W entries with ≥1 independent event
class RivetService {
  final RivetConfig config;
  final List<RivetEvent> _eventHistory = [];
  final List<RivetState> _stateHistory = [];
  RivetState? _currentState;

  RivetService({
    RivetConfig? config,
  }) : config = config ?? const RivetConfig();

  /// Get current RIVET state (read-only)
  RivetState? get currentState => _currentState;

  /// Get complete event history (read-only)
  List<RivetEvent> get eventHistory => List.unmodifiable(_eventHistory);

  /// Get complete state history (read-only)
  List<RivetState> get stateHistory => List.unmodifiable(_stateHistory);

  /// Apply a new event to the RIVET system
  /// This is the primary method for adding events
  Future<RivetGateDecision> apply(RivetEvent event) async {
    // Add event to history
    _eventHistory.add(event);
    
    // Recompute all states from scratch (deterministic)
    await _recomputeStates();
    
    // Return the latest gate decision
    return _getLatestGateDecision();
  }

  /// Delete an event by ID and recompute
  /// This enables true undo-on-delete behavior
  Future<RivetGateDecision> delete(String eventId) async {
    // Remove event from history
    _eventHistory.removeWhere((event) => event.eventId == eventId);
    
    // Recompute all states from scratch
    await _recomputeStates();
    
    // Return the latest gate decision
    return _getLatestGateDecision();
  }

  /// Edit an event by replacing it with updated version
  /// This enables true undo-on-edit behavior
  Future<RivetGateDecision> edit(RivetEvent updatedEvent) async {
    // Find and replace the event
    final index = _eventHistory.indexWhere((event) => event.eventId == updatedEvent.eventId);
    if (index != -1) {
      _eventHistory[index] = updatedEvent.copyWith(version: _eventHistory[index].version + 1);
    } else {
      // If not found, treat as new event
      _eventHistory.add(updatedEvent);
    }
    
    // Recompute all states from scratch
    await _recomputeStates();
    
    // Return the latest gate decision
    return _getLatestGateDecision();
  }

  /// Recompute all states using the deterministic reducer
  Future<void> _recomputeStates() async {
    // Use the pure reducer for deterministic computation
    _stateHistory.clear();
    _stateHistory.addAll(RivetReducer.recompute(_eventHistory, config));
    
    // Update current state to the latest
    _currentState = _stateHistory.isNotEmpty ? _stateHistory.last : null;
  }

  /// Get the latest gate decision
  RivetGateDecision _getLatestGateDecision() {
    if (_currentState == null) {
      return RivetGateDecision(
        open: false,
        stateAfter: const RivetState(
          align: 0,
          trace: 0,
          sustainCount: 0,
          sawIndependentInWindow: false,
        ),
        whyNot: "No events processed yet",
      );
    }
    
    return RivetReducer.generateGateDecision(_currentState!, config);
  }

  /// Reset RIVET state (for testing or user-initiated reset)
  void reset() {
    _eventHistory.clear();
    _stateHistory.clear();
    _currentState = null;
  }

  /// Load state from external source (e.g., loaded from storage)
  Future<void> loadFromHistory(List<RivetEvent> events) async {
    _eventHistory.clear();
    _eventHistory.addAll(events);
    await _recomputeStates();
  }

  /// Check if current state would allow gate to open
  bool wouldGateOpen() {
    if (_currentState == null) return false;
    
    return (_currentState!.align >= config.Athresh) && 
           (_currentState!.trace >= config.Tthresh) && 
           (_currentState!.sustainCount >= config.W) && 
           _currentState!.sawIndependentInWindow;
  }

  /// Get human-readable status summary
  String getStatusSummary() {
    if (_currentState == null) {
      return "No events processed yet";
    }
    
    final state = _currentState!;
    final alignStatus = state.align >= config.Athresh ? "✓" : "✗";
    final traceStatus = state.trace >= config.Tthresh ? "✓" : "✗";
    final sustainStatus = state.sustainCount >= config.W ? "✓" : "✗";
    final independentStatus = state.sawIndependentInWindow ? "✓" : "✗";
    
    return "ALIGN $alignStatus${(state.align * 100).toStringAsFixed(0)}% "
           "TRACE $traceStatus${(state.trace * 100).toStringAsFixed(0)}% "
           "Sustain $sustainStatus${state.sustainCount}/${config.W} "
           "Independent $independentStatus";
  }

  /// Get detailed gate decision explanation
  String getGateExplanation() {
    if (_currentState == null) {
      return "No events processed yet";
    }
    
    final state = _currentState!;
    final meetsThresholds = (state.align >= config.Athresh) && (state.trace >= config.Tthresh);
    final gateOpen = meetsThresholds && 
                    state.sustainCount >= config.W && 
                    state.sawIndependentInWindow;

    if (gateOpen) {
      return "Gate OPEN: All conditions met (ALIGN≥${config.Athresh.toStringAsFixed(1)}, TRACE≥${config.Tthresh.toStringAsFixed(1)}, Sustain≥${config.W}, Independent)";
    } else {
      String reason = "Gate CLOSED: ";
      if (!meetsThresholds) {
        reason += "Needs ALIGN≥${config.Athresh.toStringAsFixed(1)} and TRACE≥${config.Tthresh.toStringAsFixed(1)} together";
      } else if (!state.sawIndependentInWindow) {
        reason += "Need at least one independent event in window";
      } else {
        reason += "Needs sustainment ${state.sustainCount}/${config.W}";
      }
      return reason;
    }
  }

  /// Legacy method for backward compatibility
  /// @deprecated Use apply() instead
  Future<RivetGateDecision> ingest(RivetEvent event, {RivetEvent? lastEvent}) async {
    return await apply(event);
  }

  /// Legacy method for backward compatibility
  /// @deprecated Use currentState instead
  RivetState getCurrentState() {
    return _currentState ?? const RivetState(
      align: 0,
      trace: 0,
      sustainCount: 0,
      sawIndependentInWindow: false,
    );
  }
}