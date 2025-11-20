// EPI Module: Evolving Personal Intelligence
// Main orchestrator for all EPI modules

export 'arc/arc_module.dart';
export 'prism/prism_module.dart';
// ATLAS is now part of PRISM, accessed via prism/atlas/
export 'mira/mira_integration.dart';
export 'aurora/aurora_module.dart';
// VEIL is now part of AURORA, accessed via aurora/regimens/veil/
export 'echo/echo_module.dart';
// Privacy Core is now part of ECHO, accessed via echo/privacy_core/

/// EPI Module Orchestrator
/// Coordinates all five core modules of the Evolving Personal Intelligence system:
/// - ARC: Journaling app & main UX (includes LUMARA + ARCFORM)
/// - PRISM: Multimodal perception & analysis (includes ATLAS)
/// - MIRA: Memory graph, recall, encryption, data container (includes MCP + ARCX)
/// - AURORA: Circadian orchestration & job scheduling (includes VEIL)
/// - ECHO: Response control, LLM interface, safety & privacy (includes Privacy Core)
class EPIModule {
  static void initialize() {
    // Initialize all EPI modules
    // This will be expanded as modules are implemented
  }
  
  static void shutdown() {
    // Cleanup all EPI modules
    // This will be expanded as modules are implemented
  }
}
