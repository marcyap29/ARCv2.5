/// VEIL-EDGE — Phase-Reactive Restorative Layer
/// 
/// A fast, cloud-orchestrated variant of VEIL that maintains restorative rhythm
/// without on-device fine-tuning. Functions as a prompt-switching policy layer,
/// routing user context through ATLAS → RIVET → SENTINEL to select phase-pair playbooks.
/// 
/// This library provides:
/// - Phase group routing and selection
/// - Prompt registry and rendering
/// - RIVET policy engine for alignment tracking
/// - LUMARA integration for chat responses
/// - Complete API for cloud deployment
library;

// Core models
export 'models/veil_edge_models.dart';

// Core services
export 'core/veil_edge_router.dart';
export 'core/rivet_policy_engine.dart';

// Registry
export 'registry/prompt_registry.dart';

// Services
export 'services/veil_edge_service.dart';

// Integration
export 'integration/lumara_veil_edge_integration.dart';
