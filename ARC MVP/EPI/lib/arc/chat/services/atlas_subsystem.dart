// lib/arc/chat/services/atlas_subsystem.dart
// ATLAS subsystem: developmental phase context for LUMARA (wraps UserPhaseService).

import 'package:my_app/lumara/models/command_intent.dart';
import 'package:my_app/lumara/models/subsystem_result.dart';
import 'package:my_app/lumara/models/intent_type.dart';
import 'package:my_app/lumara/subsystems/subsystem.dart';
import '../../../services/user_phase_service.dart';

/// LUMARA subsystem that provides current developmental phase context.
///
/// Delegates to [UserPhaseService]; returns a short summary for prompt injection.
class AtlasSubsystem implements Subsystem {
  @override
  String get name => 'ATLAS';

  @override
  bool canHandle(CommandIntent intent) {
    switch (intent.type) {
      case IntentType.temporalQuery:
      case IntentType.patternAnalysis:
      case IntentType.developmentalArc:
      case IntentType.historicalParallel:
      case IntentType.comparison:
      case IntentType.recentContext:
      case IntentType.decisionSupport:
      case IntentType.specificRecall:
        return true;
      default:
        return false;
    }
  }

  @override
  Future<SubsystemResult> query(CommandIntent intent) async {
    try {
      final phase = await UserPhaseService.getCurrentPhase();
      final rationale = await UserPhaseService.getCurrentPhaseRationale();
      final description = UserPhaseService.getPhaseDescription(phase);

      final parts = <String>[];
      if (phase.isNotEmpty) {
        parts.add('Current developmental phase: $phase.');
        parts.add(description);
        if (rationale != null && rationale.isNotEmpty) {
          parts.add('Rationale: $rationale');
        }
      }
      final summary = parts.isEmpty ? '' : parts.join(' ');

      return SubsystemResult(
        source: name,
        data: {'aggregations': summary},
        metadata: {'phase': phase},
      );
    } catch (e) {
      return SubsystemResult.error(
        source: name,
        message: 'ATLAS query failed: $e',
      );
    }
  }
}
