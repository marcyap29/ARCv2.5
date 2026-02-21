// Crossroads / ATLAS: Phase type alias and decision-sensitivity metadata.
// Uses the app's PhaseLabel enum as LumaraPhase for Crossroads and RIVET decision detection.

import 'package:my_app/models/phase_models.dart';

/// Alias for phase type used in Crossroads and RIVET decision signals.
typedef LumaraPhase = PhaseLabel;

/// Rationale for why Crossroads may surface in a given phase (optional transparency UI).
extension LumaraPhaseDecisionRationale on LumaraPhase {
  static const Map<PhaseLabel, String> decisionSensitivityRationale = {
    PhaseLabel.transition: "You're in a period of change - decisions made now tend to define the next chapter",
    PhaseLabel.breakthrough: "Breakthroughs often call for decisive action - worth capturing what you're choosing",
    PhaseLabel.consolidation: "Consolidation phases involve deciding what to keep - these choices shape who you become",
    PhaseLabel.expansion: "New territory means new choices - capturing your reasoning now will matter later",
    PhaseLabel.discovery: "You're still exploring - noting your options helps clarify what you actually want",
    PhaseLabel.recovery: "Even in recovery, small decisions compound - capturing them builds self-knowledge",
  };

  String get decisionSensitivityRationaleText =>
      decisionSensitivityRationale[this] ?? "This phase can be a meaningful time to capture decisions.";
}
