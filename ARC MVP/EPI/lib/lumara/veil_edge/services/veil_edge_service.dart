/// VEIL-EDGE Service
/// 
/// Main orchestration service that coordinates routing, prompt generation,
/// and RIVET policy management for the VEIL-EDGE system.

import '../models/veil_edge_models.dart';
import '../core/veil_edge_router.dart';
import '../core/rivet_policy_engine.dart';
import '../registry/prompt_registry.dart';

/// Main VEIL-EDGE service for phase-reactive restorative layer
class VeilEdgeService {
  final VeilEdgeRouter _router;
  final RivetPolicyEngine _rivetEngine;
  final VeilEdgePromptRenderer _promptRenderer;
  final PromptRegistry _registry;

  VeilEdgeService({
    VeilEdgeRouter? router,
    RivetPolicyEngine? rivetEngine,
    VeilEdgePromptRenderer? promptRenderer,
    PromptRegistry? registry,
  }) : _router = router ?? VeilEdgeRouter(),
       _rivetEngine = rivetEngine ?? RivetPolicyEngine(),
       _promptRenderer = promptRenderer ?? VeilEdgePromptRenderer(),
       _registry = registry ?? VeilEdgePromptRegistry.getDefault();

  /// Route user context through ATLAS → RIVET → SENTINEL
  /// Returns phase group, variant, and blocks for prompt generation
  VeilEdgeRouteResult route({
    required UserSignals signals,
    required AtlasState atlas,
    required SentinelState sentinel,
    required RivetState rivet,
  }) {
    try {
      return _router.route(
        signals: signals,
        atlas: atlas,
        sentinel: sentinel,
        rivet: rivet,
      );
    } catch (e) {
      // Fallback to safe mode on error
      return VeilEdgeRouteResult(
        phaseGroup: 'R-T', // Recovery-Transition as safe fallback
        variant: ':safe',
        blocks: ['Mirror', 'Safeguard', 'Log'],
        metadata: {'error': e.toString()},
      );
    }
  }

  /// Generate a complete LLM prompt from routing result
  String generatePrompt({
    required VeilEdgeRouteResult routeResult,
    required UserSignals signals,
    Map<String, String>? additionalVariables,
  }) {
    final variables = _promptRenderer.extractVariables(signals);
    if (additionalVariables != null) {
      variables.addAll(additionalVariables);
    }

    return _promptRenderer.renderPrompt(
      phaseGroup: routeResult.phaseGroup,
      variant: routeResult.variant,
      blocks: routeResult.blocks,
      variables: variables,
    );
  }

  /// Process a log entry and update RIVET state
  RivetUpdate processLog(LogSchema log) {
    return _rivetEngine.processLog(log);
  }

  /// Get the current prompt registry
  PromptRegistry getRegistry() {
    return _registry;
  }

  /// Get registry as JSON string
  String getRegistryJson() {
    return VeilEdgePromptRegistry.toJsonString();
  }

  /// Load registry from JSON string
  void loadRegistryFromJson(String jsonString) {
    // This would update the internal registry
    // For now, we use the default registry
  }

  /// Check if phase change is currently allowed
  bool canChangePhase() {
    return _rivetEngine.canChangePhase();
  }

  /// Get current RIVET state
  RivetState getCurrentRivetState() {
    return _rivetEngine.getCurrentState();
  }

  /// Clean up old history data
  void cleanupHistory({int maxLogs = 100}) {
    _rivetEngine.cleanupHistory(maxLogs: maxLogs);
  }

  /// Get service status and diagnostics
  Map<String, dynamic> getStatus() {
    final rivetState = getCurrentRivetState();
    return {
      'service': 'veil_edge',
      'version': _registry.version,
      'rivet_state': rivetState.toJson(),
      'can_change_phase': canChangePhase(),
      'available_phase_groups': _registry.availablePhaseGroups,
      'log_count': _rivetEngine.logHistory.length,
    };
  }
}

/// API endpoints for VEIL-EDGE service
class VeilEdgeApi {
  final VeilEdgeService _service;

  VeilEdgeApi({VeilEdgeService? service}) 
      : _service = service ?? VeilEdgeService();

  /// POST /veil-edge/route
  /// Input: {signals, atlas, sentinel, rivet} → Output: {phase_group, variant, blocks[]}
  Map<String, dynamic> route(Map<String, dynamic> request) {
    try {
      final signals = UserSignals.fromJson(request['signals'] as Map<String, dynamic>);
      final atlas = AtlasState.fromJson(request['atlas'] as Map<String, dynamic>);
      final sentinel = SentinelState.fromJson(request['sentinel'] as Map<String, dynamic>);
      final rivet = RivetState.fromJson(request['rivet'] as Map<String, dynamic>);

      final result = _service.route(
        signals: signals,
        atlas: atlas,
        sentinel: sentinel,
        rivet: rivet,
      );

      return result.toJson();
    } catch (e) {
      return {
        'error': 'Routing failed: $e',
        'phase_group': 'R-T',
        'variant': ':safe',
        'blocks': ['Mirror', 'Safeguard', 'Log'],
      };
    }
  }

  /// POST /veil-edge/log
  /// Accepts LogSchema → {ack, rivet_updates}
  Map<String, dynamic> log(Map<String, dynamic> request) {
    try {
      final logSchema = LogSchema.fromJson(request);
      final update = _service.processLog(logSchema);
      return update.toJson();
    } catch (e) {
      return {
        'error': 'Log processing failed: $e',
        'ack': false,
        'rivet_updates': {},
      };
    }
  }

  /// GET /veil-edge/registry?version=0.1
  /// Retrieve prompt registry
  Map<String, dynamic> getRegistry({String version = '0.1'}) {
    try {
      final registry = _service.getRegistry();
      return {
        'version': version,
        'registry': registry.toJson(),
      };
    } catch (e) {
      return {
        'error': 'Registry retrieval failed: $e',
        'version': version,
        'registry': null,
      };
    }
  }

  /// GET /veil-edge/status
  /// Get service status and diagnostics
  Map<String, dynamic> getStatus() {
    return _service.getStatus();
  }
}

/// Factory for creating VEIL-EDGE services
class VeilEdgeServiceFactory {
  static VeilEdgeService createDefault() {
    return VeilEdgeService();
  }

  static VeilEdgeService createWithCustomRegistry(PromptRegistry registry) {
    return VeilEdgeService(registry: registry);
  }

  static VeilEdgeApi createApi({VeilEdgeService? service}) {
    return VeilEdgeApi(service: service);
  }
}
