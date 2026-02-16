import 'package:my_app/models/phase_models.dart';
import 'package:my_app/lumara/agents/writing/writing_models.dart';

/// Maps ATLAS phase and readiness to tone guidance for draft composition.
class ToneCalibrator {
  /// Calibrate tone from current phase, readiness (0-100), and content type.
  ToneGuidance calibrateTone({
    required PhaseLabel currentPhase,
    required double readinessScore,
    required ContentType contentType,
  }) {
    EmotionalTone emotionalTone;
    double ambitionLevel;
    double futureOrientation;
    double vulnerability;
    CTAStyle callToAction;
    final phaseName = _phaseDisplayName(currentPhase);

    switch (currentPhase) {
      case PhaseLabel.recovery:
        emotionalTone = EmotionalTone.gentle;
        ambitionLevel = (readinessScore / 100 * 4).clamp(1.0, 5.0);
        futureOrientation = 0.3;
        vulnerability = 0.7;
        callToAction = CTAStyle.gentleInvite;
        break;
      case PhaseLabel.transition:
        emotionalTone = EmotionalTone.exploratory;
        ambitionLevel = 4.0 + (readinessScore / 100 * 2);
        futureOrientation = 0.5;
        vulnerability = 0.5;
        callToAction = CTAStyle.question;
        break;
      case PhaseLabel.discovery:
        emotionalTone = EmotionalTone.curious;
        ambitionLevel = 4.0 + (readinessScore / 100 * 2.5);
        futureOrientation = 0.6;
        vulnerability = 0.5;
        callToAction = CTAStyle.gentleInvite;
        break;
      case PhaseLabel.expansion:
        emotionalTone = EmotionalTone.confident;
        ambitionLevel = 6.0 + (readinessScore / 100 * 2);
        futureOrientation = 0.8;
        vulnerability = 0.3;
        callToAction = CTAStyle.question;
        break;
      case PhaseLabel.breakthrough:
        emotionalTone = EmotionalTone.challenging;
        ambitionLevel = 8.0 + (readinessScore / 100 * 2);
        futureOrientation = 0.9;
        vulnerability = 0.2;
        callToAction = CTAStyle.strongChallenge;
        break;
      case PhaseLabel.consolidation:
        emotionalTone = EmotionalTone.integrative;
        ambitionLevel = 5.0 + (readinessScore / 100 * 2);
        futureOrientation = 0.5;
        vulnerability = 0.4;
        callToAction = CTAStyle.gentleInvite;
        break;
    }

    ambitionLevel = ambitionLevel.clamp(1.0, 10.0);
    futureOrientation = futureOrientation.clamp(0.0, 1.0);
    vulnerability = vulnerability.clamp(0.0, 1.0);

    return ToneGuidance(
      emotionalTone: emotionalTone,
      ambitionLevel: ambitionLevel,
      futureOrientation: futureOrientation,
      vulnerability: vulnerability,
      callToAction: callToAction,
      phase: phaseName,
    );
  }

  String _phaseDisplayName(PhaseLabel p) {
    switch (p) {
      case PhaseLabel.discovery:
        return 'Discovery';
      case PhaseLabel.expansion:
        return 'Expansion';
      case PhaseLabel.transition:
        return 'Transition';
      case PhaseLabel.consolidation:
        return 'Consolidation';
      case PhaseLabel.recovery:
        return 'Recovery';
      case PhaseLabel.breakthrough:
        return 'Breakthrough';
    }
  }
}
