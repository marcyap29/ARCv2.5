// RIVET Module - Risk-Validation Evidence Tracker
// Provides ALIGN/TRACE validation system for evidence-based test reduction

// Models
export 'models/rivet_models.dart';

// Validation Services
export 'validation/rivet_service.dart';
export 'validation/rivet_storage.dart';
export 'validation/rivet_provider.dart';
export 'validation/rivet_telemetry.dart';

// Module Interface
abstract class RivetModuleInterface {
  /// Calculate ALIGN score (0-1) - agreement between model predictions and empirical results
  Future<double> calculateAlignScore(List<dynamic> predictions, List<dynamic> empiricalResults);

  /// Calculate TRACE score (0-1) - evidence sufficiency with independence and novelty weighting
  Future<double> calculateTraceScore(List<dynamic> evidenceEvents);

  /// Authorize test reduction based on ALIGN/TRACE thresholds and sustainment window
  Future<bool> authorizeTestReduction({
    required double alignThreshold,
    required double traceThreshold,
    required Duration sustainmentWindow,
  });
}