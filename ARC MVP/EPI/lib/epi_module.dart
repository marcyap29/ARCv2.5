// EPI Module: Evolving Personal Intelligence
// Main orchestrator for all EPI modules

export 'arc/arc_module.dart';
export 'prism/prism_module.dart';
export 'atlas/atlas_module.dart' hide RivetConfig;
export 'mira/mira_integration.dart';
export 'aurora/aurora_module.dart';
export 'veil/veil_module.dart';
export 'privacy_core/privacy_core_module.dart';

/// EPI Module Orchestrator
/// Coordinates all six core modules of the Evolving Personal Intelligence system
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
