/// PRISM ATLAS - Unified Phase Detection, RIVET, and SENTINEL
///
/// This module provides the perception layer's analytical capabilities:
/// - Phase detection and tracking: Identifies user's emotional/developmental phase
/// - RIVET (Risk-Validation Evidence Tracker): Keyword-based gating for phase transitions
/// - SENTINEL: Severity evaluation and negative trend identification
///
/// ## Architecture Context
/// All components are unified under PRISM as the perception layer. Previously
/// these were separate modules (ATLAS, RIVET, SENTINEL), but have been consolidated
/// to improve cohesion and reduce inter-module dependencies.
///
/// ## Data Flow
/// 1. Journal entries → PRISM extractors → ATLAS phase detection
/// 2. Phase scores → RIVET gating → Phase transition decision
/// 3. Keyword patterns → SENTINEL risk analysis → Risk level assessment
///
/// ## Usage
/// ```dart
/// import 'package:my_app/prism/atlas/index.dart' as atlas;
///
/// // Phase tracking
/// final tracker = PhaseTracker(userProfile: profile);
/// final result = await tracker.updatePhaseScores(...);
///
/// // RIVET gating
/// final rivet = RivetProvider().getService();
/// final gateOpen = rivet.isGateOpen();
///
/// // SENTINEL risk analysis
/// final risk = await SentinelRiskDetector.analyzeRisk(...);
/// ```

// Phase detection exports
// Handles phase identification, scoring, and transition tracking
export 'phase/phase_change_notifier.dart';
export 'phase/phase_history_repository.dart';
export 'phase/phase_scoring.dart';
export 'phase/phase_tracker.dart';
export 'phase/pattern_analysis_service.dart';
export 'phase/your_patterns_view.dart';

// RIVET system exports
// Risk-Validation Evidence Tracker: validates keyword evidence before phase changes
// Uses ALIGN (alignment score) and TRACE (evidence accumulation) metrics
export 'rivet/rivet_models.dart';
export 'rivet/rivet_provider.dart';
export 'rivet/rivet_reducer.dart';
export 'rivet/rivet_service.dart';
export 'rivet/rivet_storage.dart';
export 'rivet/rivet_telemetry.dart';

// SENTINEL risk detection exports
// Severity Evaluation and Negative Trend Identification
// Monitors keyword patterns over time to detect escalating risk levels
export 'sentinel/sentinel_risk_detector.dart';

