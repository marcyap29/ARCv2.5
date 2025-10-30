/// VEIL-EDGE Service
/// 
/// Main orchestration service that coordinates routing, prompt generation,
/// and RIVET policy management for the VEIL-EDGE system with AURORA integration.

import '../models/veil_edge_models.dart';
import '../core/veil_edge_router.dart';
import '../core/rivet_policy_engine.dart';
import '../registry/prompt_registry.dart';
import '../../../aurora/services/circadian_profile_service.dart';
import '../../../aurora/models/circadian_context.dart';
import 'package:my_app/arc/core/journal_repository.dart';

/// Main VEIL-EDGE service for phase-reactive restorative layer with AURORA integration
class VeilEdgeService {
  final VeilEdgeRouter _router;
  final RivetPolicyEngine _rivetEngine;
  final VeilEdgePromptRenderer _promptRenderer;
  final PromptRegistry _registry;
  final CircadianProfileService _aurora;
  final JournalRepository _journalRepo;

  VeilEdgeService({
    VeilEdgeRouter? router,
    RivetPolicyEngine? rivetEngine,
    VeilEdgePromptRenderer? promptRenderer,
    PromptRegistry? registry,
    CircadianProfileService? aurora,
    JournalRepository? journalRepo,
  }) : _router = router ?? VeilEdgeRouter(),
       _rivetEngine = rivetEngine ?? RivetPolicyEngine(),
       _promptRenderer = promptRenderer ?? VeilEdgePromptRenderer(),
       _registry = registry ?? VeilEdgePromptRegistry.getDefault(),
       _aurora = aurora ?? CircadianProfileService(),
       _journalRepo = journalRepo ?? JournalRepository();

  /// Route user context through ATLAS → RIVET → SENTINEL → AURORA
  /// Returns phase group, variant, and blocks for prompt generation
  Future<VeilEdgeRouteResult> route({
    required UserSignals signals,
    required AtlasState atlas,
    required SentinelState sentinel,
    required RivetState rivet,
  }) async {
    try {
      // Get recent journal entries for circadian analysis
      final recentEntries = _journalRepo.getAllJournalEntries();
      
      // Compute circadian context
      final circadianContext = await _aurora.compute(recentEntries);
      
      // Create VEIL-EDGE input with circadian context
      final input = VeilEdgeInput(
        atlas: atlas,
        rivet: rivet,
        sentinel: sentinel,
        signals: SignalExtraction(signals: signals),
        circadianWindow: circadianContext.window,
        circadianChronotype: circadianContext.chronotype,
        rhythmScore: circadianContext.rhythmScore,
      );

      return _router.route(input);
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

  /// Route with explicit circadian context (for testing or external integration)
  VeilEdgeRouteResult routeWithCircadian({
    required UserSignals signals,
    required AtlasState atlas,
    required SentinelState sentinel,
    required RivetState rivet,
    required CircadianContext circadianContext,
  }) {
    try {
      final input = VeilEdgeInput(
        atlas: atlas,
        rivet: rivet,
        sentinel: sentinel,
        signals: SignalExtraction(signals: signals),
        circadianWindow: circadianContext.window,
        circadianChronotype: circadianContext.chronotype,
        rhythmScore: circadianContext.rhythmScore,
      );

      return _router.route(input);
    } catch (e) {
      return VeilEdgeRouteResult(
        phaseGroup: 'R-T',
        variant: ':safe',
        blocks: ['Mirror', 'Safeguard', 'Log'],
        metadata: {'error': e.toString()},
      );
    }
  }

  /// Generate a complete LLM prompt from routing result with circadian context
  String generatePrompt({
    required VeilEdgeRouteResult routeResult,
    required UserSignals signals,
    Map<String, String>? additionalVariables,
    String? circadianWindow,
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
      circadianWindow: circadianWindow,
    );
  }

  /// Generate prompt with full circadian context
  String generatePromptWithCircadian({
    required VeilEdgeRouteResult routeResult,
    required UserSignals signals,
    required CircadianContext circadianContext,
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
      circadianWindow: circadianContext.window,
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

  /// Get current circadian context
  Future<CircadianContext> getCurrentCircadianContext() async {
    final recentEntries = _journalRepo.getAllJournalEntries();
    return await _aurora.compute(recentEntries);
  }

  /// Get circadian profile with detailed analysis
  Future<CircadianProfile> getCircadianProfile() async {
    final recentEntries = _journalRepo.getAllJournalEntries();
    return await _aurora.computeProfile(recentEntries);
  }

  /// Check if journal entries provide sufficient data for reliable circadian analysis
  bool hasSufficientCircadianData() {
    final entries = _journalRepo.getAllJournalEntries();
    return _aurora.hasSufficientData(entries);
  }

  /// Get service status and diagnostics including circadian context
  Future<Map<String, dynamic>> getStatus() async {
    final rivetState = getCurrentRivetState();
    final circadianContext = await getCurrentCircadianContext();
    final hasData = hasSufficientCircadianData();

    return {
      'service': 'veil_edge',
      'version': _registry.version,
      'rivet_state': rivetState.toJson(),
      'can_change_phase': canChangePhase(),
      'available_phase_groups': _registry.availablePhaseGroups,
      'log_count': _rivetEngine.logHistory.length,
        'circadian_context': (await circadianContext).toJson(),
      'circadian_data_sufficient': hasData,
      'aurora_integration': true,
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
  Future<Map<String, dynamic>> route(Map<String, dynamic> request) async {
    try {
      final signals = UserSignals.fromJson(request['signals'] as Map<String, dynamic>);
      final atlas = AtlasState.fromJson(request['atlas'] as Map<String, dynamic>);
      final sentinel = SentinelState.fromJson(request['sentinel'] as Map<String, dynamic>);
      final rivet = RivetState.fromJson(request['rivet'] as Map<String, dynamic>);

      final result = await _service.route(
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
  /// Get service status and diagnostics including circadian context
  Future<Map<String, dynamic>> getStatus() async {
    return await _service.getStatus();
  }

  /// GET /veil-edge/circadian
  /// Get current circadian context
  Future<Map<String, dynamic>> getCircadianContext() async {
    try {
      final context = await _service.getCurrentCircadianContext();
      return {
        'circadian_context': context.toJson(),
        'data_sufficient': _service.hasSufficientCircadianData(),
      };
    } catch (e) {
      return {
        'error': 'Circadian context retrieval failed: $e',
        'circadian_context': null,
        'data_sufficient': false,
      };
    }
  }

  /// GET /veil-edge/circadian/profile
  /// Get detailed circadian profile
  Future<Map<String, dynamic>> getCircadianProfile() async {
    try {
      final profile = await _service.getCircadianProfile();
      return {
        'circadian_profile': profile.toJson(),
        'data_sufficient': _service.hasSufficientCircadianData(),
      };
    } catch (e) {
      return {
        'error': 'Circadian profile retrieval failed: $e',
        'circadian_profile': null,
        'data_sufficient': false,
      };
    }
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
