// lib/services/phase_service_registry.dart
// Centralized access for phase-related services (PhaseRegimeService, etc.).
// Prefer using this instead of ad-hoc PhaseRegimeService(analytics, rivet) in 15+ call sites.
// See CODE_SIMPLIFIER_CONSOLIDATION_PLAN.md P1-PHASE.

import 'analytics_service.dart';
import 'phase_regime_service.dart';
import 'rivet_sweep_service.dart';

/// Shared phase service access.
///
/// Use [phaseRegimeService] when you need PhaseRegimeService. The same instance
/// is returned and initialized on first access. In widgets with [BuildContext],
/// you can also use `context.read<PhaseRegimeService>()` if the app provides it
/// (see app.dart).
abstract final class PhaseServiceRegistry {
  PhaseServiceRegistry._();

  static PhaseRegimeService? _phaseRegimeService;

  /// Returns the shared [PhaseRegimeService], initializing it on first access.
  /// Prefer: `final service = await PhaseServiceRegistry.phaseRegimeService;`
  static Future<PhaseRegimeService> get phaseRegimeService async {
    if (_phaseRegimeService != null) {
      return _phaseRegimeService!;
    }
    final analytics = AnalyticsService();
    final rivet = RivetSweepService(analytics);
    _phaseRegimeService = PhaseRegimeService(analytics, rivet);
    await _phaseRegimeService!.initialize();
    return _phaseRegimeService!;
  }

  /// Synchronous access to the cached instance, or null if not yet created.
  /// Use only when you know the service has already been obtained (e.g. after
  /// app startup or a prior await [phaseRegimeService]).
  static PhaseRegimeService? get phaseRegimeServiceSync => _phaseRegimeService;
}
