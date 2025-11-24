import 'package:my_app/models/phase_models.dart';
import 'package:my_app/models/user_profile_model.dart';
import 'package:my_app/prism/atlas/phase/phase_tracker.dart';
import 'package:my_app/services/phase_regime_service.dart';

/// Service that bridges PhaseTracker and PhaseRegimeService
/// 
/// When PhaseTracker approves a phase change, this service:
/// - Creates/updates Phase Regimes via PhaseRegimeService
/// - Sets regime source to RIVET with confidence from PhaseTracker
/// - Updates regime anchors with entry IDs that contributed
/// - Updates UserProfile phase
class PhaseRegimeTracker {
  final PhaseTracker _phaseTracker;
  final PhaseRegimeService _phaseRegimeService;
  final UserProfile _userProfile;

  PhaseRegimeTracker({
    required PhaseTracker phaseTracker,
    required PhaseRegimeService phaseRegimeService,
    required UserProfile userProfile,
  })  : _phaseTracker = phaseTracker,
        _phaseRegimeService = phaseRegimeService,
        _userProfile = userProfile;

  /// Update phase tracking and create/update regimes when phase changes
  /// 
  /// This wraps PhaseTracker.updatePhaseScores() and creates regimes
  /// when a phase change is approved.
  /// 
  /// Returns the PhaseTrackingResult and the created/updated regime (if any)
  Future<PhaseRegimeUpdateResult> updatePhaseScoresAndRegimes({
    required Map<String, double> phaseScores,
    required String journalEntryId,
    required String emotion,
    required String reason,
    required String text,
    List<String>? contributingEntryIds,
  }) async {
    // Update phase tracking
    final result = await _phaseTracker.updatePhaseScores(
      phaseScores: phaseScores,
      journalEntryId: journalEntryId,
      emotion: emotion,
      reason: reason,
      text: text,
    );

    PhaseRegime? createdRegime;

    // If phase changed, create/update regime
    if (result.phaseChanged && result.newPhase != null) {
      // Convert string phase to PhaseLabel enum
      final newPhaseLabel = _stringToPhaseLabel(result.newPhase!);
      
      if (newPhaseLabel != null) {
        // Get confidence from smoothed scores
        final confidence = result.smoothedScores[result.newPhase!] ?? 0.0;
        
        // Collect entry IDs that contributed to this change
        final anchors = <String>[
          journalEntryId,
          if (contributingEntryIds != null) ...contributingEntryIds,
        ];

        // Get current regime
        final currentRegime = _phaseRegimeService.phaseIndex.currentRegime;
        final now = DateTime.now();

        // End current regime if it exists and is ongoing
        if (currentRegime != null && currentRegime.isOngoing) {
          final endedRegime = currentRegime.copyWith(
            end: now,
            updatedAt: now,
          );
          await _phaseRegimeService.updateRegime(endedRegime);
        }

        // Create new regime with RIVET source
        createdRegime = await _phaseRegimeService.createRegime(
          label: newPhaseLabel,
          start: now,
          source: PhaseSource.rivet,
          confidence: confidence,
          anchors: anchors,
        );

        print('INFO: PhaseRegimeTracker - Created regime: ${createdRegime.label} (confidence: ${confidence.toStringAsFixed(3)})');
      }
    }

    return PhaseRegimeUpdateResult(
      phaseTrackingResult: result,
      createdRegime: createdRegime,
    );
  }

  /// Convert string phase name to PhaseLabel enum
  PhaseLabel? _stringToPhaseLabel(String phase) {
    final normalized = phase.toLowerCase().trim();
    switch (normalized) {
      case 'discovery':
        return PhaseLabel.discovery;
      case 'expansion':
        return PhaseLabel.expansion;
      case 'transition':
        return PhaseLabel.transition;
      case 'consolidation':
        return PhaseLabel.consolidation;
      case 'recovery':
        return PhaseLabel.recovery;
      case 'breakthrough':
        return PhaseLabel.breakthrough;
      default:
        print('WARNING: Unknown phase string: $phase');
        return null;
    }
  }
}

/// Result of phase regime update operation
class PhaseRegimeUpdateResult {
  final PhaseTrackingResult phaseTrackingResult;
  final PhaseRegime? createdRegime;

  const PhaseRegimeUpdateResult({
    required this.phaseTrackingResult,
    this.createdRegime,
  });

  bool get phaseChanged => phaseTrackingResult.phaseChanged;
  String? get newPhase => phaseTrackingResult.newPhase;
  String? get previousPhase => phaseTrackingResult.previousPhase;
}

