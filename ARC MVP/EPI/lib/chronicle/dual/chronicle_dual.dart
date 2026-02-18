// lib/chronicle/dual/chronicle_dual.dart
//
// LUMARA Dual-Chronicle Architecture - Public API
//
// THE USER'S CHRONICLE IS SACRED. System never writes to User Chronicle
// without explicit user approval.

export 'models/chronicle_models.dart';
export 'repositories/user_chronicle_repository.dart';
export 'repositories/lumara_chronicle_repository.dart';
export 'storage/chronicle_storage.dart';
export 'services/promotion_service.dart';
export 'services/dual_chronicle_services.dart';
export 'intelligence/gap/gap_analyzer.dart';
export 'intelligence/gap/gap_classifier.dart';
export 'intelligence/interrupt/interrupt_decision_engine.dart';
export 'intelligence/interrupt/clarification_processor.dart';
export 'intelligence/agentic_loop_orchestrator.dart';
