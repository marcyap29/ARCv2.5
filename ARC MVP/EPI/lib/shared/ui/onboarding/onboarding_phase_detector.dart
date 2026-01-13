// lib/shared/ui/onboarding/onboarding_phase_detector.dart
// Phase Detection Algorithm for Onboarding Responses

import 'package:my_app/models/phase_models.dart';
import 'package:my_app/shared/ui/onboarding/arc_onboarding_state.dart';

class OnboardingPhaseDetector {
  /// Analyze onboarding responses to detect user phase
  Future<PhaseAnalysis> analyzeOnboardingResponses({
    required Map<int, String> responses,
    required DateTime timestamp,
  }) async {
    // Phase detection markers
    final phaseScores = <PhaseLabel, int>{};
    for (final phase in PhaseLabel.values) {
      phaseScores[phase] = 0;
    }

    // Q1: Temporal markers, emotional valence, direction words
    final q1 = responses[0]?.toLowerCase() ?? '';
    _analyzeTemporalMarkers(q1, phaseScores);
    _analyzeEmotionalValence(q1, phaseScores);
    _analyzeDirectionWords(q1, phaseScores);

    // Q2: Question vs problem, new vs ongoing, energy level
    final q2 = responses[1]?.toLowerCase() ?? '';
    _analyzeQuestionVsProblem(q2, phaseScores);
    _analyzeNewVsOngoing(q2, phaseScores);
    _analyzeEnergyLevel(q2, phaseScores);

    // Q3: Sudden vs gradual, recent vs longstanding, triggered vs emergent
    final q3 = responses[2]?.toLowerCase() ?? '';
    _analyzeTemporalPattern(q3, phaseScores);
    _analyzeTriggeredVsEmergent(q3, phaseScores);

    // Q4: Trajectory, momentum, stability vs change
    final q4 = responses[3]?.toLowerCase() ?? '';
    _analyzeTrajectory(q4, phaseScores);
    _analyzeMomentum(q4, phaseScores);

    // Q5: What they're protecting or pursuing, stakes level
    final q5 = responses[4]?.toLowerCase() ?? '';
    _analyzeStakes(q5, phaseScores);
    _analyzeProtectionVsPursuit(q5, phaseScores);

    // Find highest scoring phase
    PhaseLabel detectedPhase = PhaseLabel.discovery;
    int maxScore = 0;
    for (final entry in phaseScores.entries) {
      if (entry.value > maxScore) {
        maxScore = entry.value;
        detectedPhase = entry.key;
      }
    }

    // Calculate confidence
    final totalMarkers = phaseScores.values.fold(0, (a, b) => a + b);
    ConfidenceLevel confidence;
    if (maxScore >= 3 && totalMarkers >= 5) {
      confidence = ConfidenceLevel.high;
    } else if (maxScore >= 2 && totalMarkers >= 3) {
      confidence = ConfidenceLevel.medium;
    } else {
      confidence = ConfidenceLevel.low;
    }

    // Generate recognition statement and tracking question
    final recognitionStatement = _generateRecognitionStatement(
      detectedPhase,
      responses,
      maxScore,
    );
    final trackingQuestion = _generateTrackingQuestion(
      detectedPhase,
      responses,
    );
    final reasoning = _generateReasoning(
      detectedPhase,
      phaseScores,
      confidence,
    );

    return PhaseAnalysis(
      phase: detectedPhase,
      confidence: confidence,
      recognitionStatement: recognitionStatement,
      trackingQuestion: trackingQuestion,
      reasoning: reasoning,
    );
  }

  void _analyzeTemporalMarkers(String text, Map<PhaseLabel, int> scores) {
    // Recovery: past difficulty references
    if (RegExp(r'\b(was|were|had|before|past|ago|used to|recovering|healing)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.recovery] = (scores[PhaseLabel.recovery] ?? 0) + 1;
    }

    // Discovery: present exploration
    if (RegExp(r'\b(now|currently|exploring|learning|trying|figuring out)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.discovery] = (scores[PhaseLabel.discovery] ?? 0) + 1;
    }

    // Transition: between states
    if (RegExp(r'\b(between|changing|shifting|moving|transition)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.transition] = (scores[PhaseLabel.transition] ?? 0) + 1;
    }
  }

  void _analyzeEmotionalValence(String text, Map<PhaseLabel, int> scores) {
    // Recovery: healing, getting better
    if (RegExp(r'\b(better|stronger|improving|healing|recovering)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.recovery] = (scores[PhaseLabel.recovery] ?? 0) + 1;
    }

    // Breakthrough: resolution, clarity
    if (RegExp(r'\b(clear|understood|realized|breakthrough|insight)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.breakthrough] =
          (scores[PhaseLabel.breakthrough] ?? 0) + 1;
    }

    // Discovery: uncertainty, curiosity
    if (RegExp(r'\b(uncertain|curious|wondering|questioning|unsure)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.discovery] = (scores[PhaseLabel.discovery] ?? 0) + 1;
    }
  }

  void _analyzeDirectionWords(String text, Map<PhaseLabel, int> scores) {
    // Expansion: forward, building
    if (RegExp(r'\b(forward|building|growing|expanding|progress)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.expansion] = (scores[PhaseLabel.expansion] ?? 0) + 1;
    }

    // Consolidation: stable, maintaining
    if (RegExp(r'\b(stable|maintaining|consistent|settled|established)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.consolidation] =
          (scores[PhaseLabel.consolidation] ?? 0) + 1;
    }
  }

  void _analyzeQuestionVsProblem(String text, Map<PhaseLabel, int> scores) {
    // Discovery: questions
    if (RegExp(r'\b(what|why|how|when|where|question|wondering)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.discovery] = (scores[PhaseLabel.discovery] ?? 0) + 1;
    }

    // Recovery: problems being addressed
    if (RegExp(r'\b(problem|issue|difficulty|challenge|struggling)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.recovery] = (scores[PhaseLabel.recovery] ?? 0) + 1;
    }
  }

  void _analyzeNewVsOngoing(String text, Map<PhaseLabel, int> scores) {
    // Discovery: new
    if (RegExp(r'\b(new|recent|just|started|beginning)\b').hasMatch(text)) {
      scores[PhaseLabel.discovery] = (scores[PhaseLabel.discovery] ?? 0) + 1;
    }

    // Consolidation: ongoing, established
    if (RegExp(r'\b(ongoing|always|usually|typically|established)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.consolidation] =
          (scores[PhaseLabel.consolidation] ?? 0) + 1;
    }
  }

  void _analyzeEnergyLevel(String text, Map<PhaseLabel, int> scores) {
    // Expansion: high energy
    if (RegExp(r'\b(energized|excited|motivated|driven|active)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.expansion] = (scores[PhaseLabel.expansion] ?? 0) + 1;
    }

    // Recovery: low energy, rebuilding
    if (RegExp(r'\b(tired|exhausted|drained|rebuilding|resting)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.recovery] = (scores[PhaseLabel.recovery] ?? 0) + 1;
    }
  }

  void _analyzeTemporalPattern(String text, Map<PhaseLabel, int> scores) {
    // Breakthrough: sudden
    if (RegExp(r'\b(suddenly|recently|just|quickly|fast)\b').hasMatch(text)) {
      scores[PhaseLabel.breakthrough] =
          (scores[PhaseLabel.breakthrough] ?? 0) + 1;
    }

    // Recovery: gradual
    if (RegExp(r'\b(gradually|slowly|over time|for a while|long time)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.recovery] = (scores[PhaseLabel.recovery] ?? 0) + 1;
    }
  }

  void _analyzeTriggeredVsEmergent(String text, Map<PhaseLabel, int> scores) {
    // Breakthrough: triggered
    if (RegExp(r'\b(triggered|caused by|because of|result of)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.breakthrough] =
          (scores[PhaseLabel.breakthrough] ?? 0) + 1;
    }

    // Discovery: emergent
    if (RegExp(r'\b(emerged|developed|grew|naturally|organically)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.discovery] = (scores[PhaseLabel.discovery] ?? 0) + 1;
    }
  }

  void _analyzeTrajectory(String text, Map<PhaseLabel, int> scores) {
    // Expansion: getting stronger
    if (RegExp(r'\b(stronger|growing|increasing|building|expanding)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.expansion] = (scores[PhaseLabel.expansion] ?? 0) + 1;
    }

    // Recovery: getting quieter/better
    if (RegExp(r'\b(quieter|calmer|better|improving|healing)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.recovery] = (scores[PhaseLabel.recovery] ?? 0) + 1;
    }

    // Transition: shifting
    if (RegExp(r'\b(shifting|changing|transforming|evolving|moving)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.transition] = (scores[PhaseLabel.transition] ?? 0) + 1;
    }
  }

  void _analyzeMomentum(String text, Map<PhaseLabel, int> scores) {
    // Expansion: momentum
    if (RegExp(r'\b(momentum|flow|rolling|building|accelerating)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.expansion] = (scores[PhaseLabel.expansion] ?? 0) + 1;
    }

    // Consolidation: stability
    if (RegExp(r'\b(stable|steady|consistent|maintaining|holding)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.consolidation] =
          (scores[PhaseLabel.consolidation] ?? 0) + 1;
    }
  }

  void _analyzeStakes(String text, Map<PhaseLabel, int> scores) {
    // Breakthrough: high stakes
    if (RegExp(r'\b(important|crucial|critical|significant|major)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.breakthrough] =
          (scores[PhaseLabel.breakthrough] ?? 0) + 1;
    }

    // Discovery: exploring stakes
    if (RegExp(r'\b(exploring|figuring out|understanding|learning about)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.discovery] = (scores[PhaseLabel.discovery] ?? 0) + 1;
    }
  }

  void _analyzeProtectionVsPursuit(String text, Map<PhaseLabel, int> scores) {
    // Expansion: pursuit
    if (RegExp(r'\b(pursuing|seeking|working toward|building|creating)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.expansion] = (scores[PhaseLabel.expansion] ?? 0) + 1;
    }

    // Recovery: protection
    if (RegExp(r'\b(protecting|preserving|maintaining|keeping|holding)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.recovery] = (scores[PhaseLabel.recovery] ?? 0) + 1;
    }
  }

  String _generateRecognitionStatement(
    PhaseLabel phase,
    Map<int, String> responses,
    int score,
  ) {
    switch (phase) {
      case PhaseLabel.discovery:
        return "You're exploring new territory, asking questions about where you are and what comes next.";
      case PhaseLabel.expansion:
        return "You're building momentum, actively growing and expanding what you've started.";
      case PhaseLabel.transition:
        return "You're in motion, shifting between what was and what's emerging.";
      case PhaseLabel.consolidation:
        return "You're integrating and stabilizing, making what you've learned part of your foundation.";
      case PhaseLabel.recovery:
        return "You're healing and rebuilding, moving forward from a difficult place.";
      case PhaseLabel.breakthrough:
        return "You've reached a moment of clarity, seeing something that changes how you understand your situation.";
    }
  }

  String _generateTrackingQuestion(
    PhaseLabel phase,
    Map<int, String> responses,
  ) {
    final q5 = responses[4] ?? '';
    // Extract the core concern from Q5
    if (q5.isNotEmpty) {
      // Try to extract a meaningful question from their response
      return q5.length > 50 ? q5.substring(0, 50) + '...' : q5;
    }

    // Default questions by phase
    switch (phase) {
      case PhaseLabel.discovery:
        return "What are you discovering?";
      case PhaseLabel.expansion:
        return "What are you building?";
      case PhaseLabel.transition:
        return "What are you moving toward?";
      case PhaseLabel.consolidation:
        return "What are you integrating?";
      case PhaseLabel.recovery:
        return "What are you healing?";
      case PhaseLabel.breakthrough:
        return "What did you realize?";
    }
  }

  String _generateReasoning(
    PhaseLabel phase,
    Map<PhaseLabel, int> scores,
    ConfidenceLevel confidence,
  ) {
    final phaseName = phase.name;
    final phaseScore = scores[phase] ?? 0;
    final confidenceStr = confidence.name;

    return 'Detected $phaseName phase with score $phaseScore and $confidenceStr confidence. '
        'Scores: ${scores.toString()}';
  }
}
