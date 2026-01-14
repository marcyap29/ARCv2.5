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

    // Analyze text length across all responses (longer responses suggest consolidation)
    final allText = responses.values.join(' ').toLowerCase();
    _analyzeTextLength(allText, phaseScores);

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
    // Recovery: healing, getting better, comprehensive keyword set
    if (RegExp(r'\b(better|stronger|improving|healing|recovering|rest|resting|rested|heal|recover|recovery|gentle|gently|breathe|breathing|breathed|peace|peaceful|peacefully|calm|calmly|calmness|restore|restoring|restored|restoration|balance|balanced|balancing|equilibrium|harmony|harmonious|meditation|meditating|mindfulness|mindful|self-care|therapy|support|supported|comfort|comfortable|comforting|safe|safety|protected|protection|nurturing|nurture|caring|care|compassionate|compassion|kind|kindness|renewal|renew|renewing|renewed|recharge|recharging|recharged|reset|resetting|resetted|fresh start|beginning again|starting over|health|healthy|wellness|well|wholeness|whole|integration|integrated|acceptance|accept|accepting|accepted|forgiveness|forgive|forgiving|forgave|patience|patient)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.recovery] = (scores[PhaseLabel.recovery] ?? 0) + 1;
    }

    // Breakthrough: resolution, clarity, comprehensive keyword set
    if (RegExp(r'\b(clear|clearly|understood|realized|breakthrough|breakthroughs|insight|insights|epiphany|epiphanies|suddenly|sudden|realize|realization|clarity|understand|understanding|comprehend|comprehension|aha|eureka|revelation|revelations|transformation|transform|transforming|wisdom|wise|purpose|meaning|meaningful|threshold|thresholds|crossing|cross|crossed|momentum|coherent|coherence|unlock|unlocking|unlocked|path|paths|alive|lively|vibrant|crisp|landing|arrived|arrival|achieved|achievement|accomplished|accomplishment|fulfilled|fulfillment)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.breakthrough] =
          (scores[PhaseLabel.breakthrough] ?? 0) + 1;
    }

    // Discovery: uncertainty, curiosity, comprehensive keyword set
    if (RegExp(r'\b(uncertain|curious|wondering|questioning|unsure|explore|exploring|exploration|explored|new|newly|curiosity|wonder|wondered|question|questions|questioned|learn|learning|learned|study|studying|studied|discover|discovering|discovery|discovered|beginning|beginnings|begin|start|starting|started|fresh|first|initial|early|dawn|birth|genesis|origin|seed|sprout|bud|embryo|goals|dreams|aspirations|hopes|hopeful|hoping|optimistic|optimism|positive|positivity|excited|excitement|enthusiastic|enthusiasm|eager|eagerness|anticipation|anticipating|thrilled|inspired|inspiration|motivated|motivation|driven|ambitious|ambition|creativity|creative|imagination|imaginative|innovative|innovation|spirituality|spiritual|sacred|divine|transcendent|mystical|mystery|magic|magical|awe|amazement|fascination|fascinated|intrigue|intrigued|interest|interested|interesting)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.discovery] = (scores[PhaseLabel.discovery] ?? 0) + 1;
    }
  }

  void _analyzeDirectionWords(String text, Map<PhaseLabel, int> scores) {
    // Expansion: forward, building
    if (RegExp(r'\b(forward|building|growing|expanding|progress|reach|reaching|possibility|energy|outward|more|bigger|greater|increase|grateful|joyful|confident|vitality|dynamic|enthusiastic|passionate|opportunity|abundance|flourishing|thriving|prosperous|success|achievement|improvement|multiplying|amplifying|enhanced|rising|ascending|climbing|soaring|flowing)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.expansion] = (scores[PhaseLabel.expansion] ?? 0) + 1;
    }

    // Consolidation: comprehensive keyword set matching main app
    // Reflection and awareness
    if (RegExp(r'\b(reflection|reflecting|reflective|contemplation|contemplating|meditation|meditating|mindfulness|mindful|awareness|aware|conscious|consciousness|presence|present|attentive|attention|focus|focused|observation|observing|noticing|witnessing|witness)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.consolidation] =
          (scores[PhaseLabel.consolidation] ?? 0) + 1;
    }
    // Patterns and habits
    if (RegExp(r'\b(patterns|pattern|habits|habit|routine|routines|ritual|rituals|structure|structured|organization|organize|organizing|system|systems|order|ordered|orderly|systematic|methodical|disciplined|discipline)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.consolidation] =
          (scores[PhaseLabel.consolidation] ?? 0) + 1;
    }
    // Stability and grounding
    if (RegExp(r'\b(stable|stability|steadfast|steady|consistent|consistency|constant|reliable|reliability|dependable|dependability|trustworthy|trust|ground|grounded|grounding|rooted|rooting|anchored|anchoring|settle|settling|settled|establish|establishing|established|foundation|foundational|base|basis|core|center|centered)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.consolidation] =
          (scores[PhaseLabel.consolidation] ?? 0) + 1;
    }
    // Integration and weaving
    if (RegExp(r'\b(integrate|integrating|integration|integrated|unify|unifying|unity|unified|connect|connecting|connection|connected|link|linking|linked|weave|weaving|woven|interweave|interweaving|interwoven|blend|blending|blended|merge|merging|merged|combine|combining|combined|synthesize|synthesizing|synthesized|harmonize|harmonizing|harmonized|balance|balanced)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.consolidation] =
          (scores[PhaseLabel.consolidation] ?? 0) + 1;
    }
    // Home and relationships
    if (RegExp(r'\b(home|homely|homestead|dwelling|residence|residential|domestic|friendship|friendships|friend|friends|companionship|companion|companions|community|communities|belonging|belong|belonged|inclusion|included)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.consolidation] =
          (scores[PhaseLabel.consolidation] ?? 0) + 1;
    }
    // Consolidation-specific terms
    if (RegExp(r'\b(consolidate|consolidating|consolidation|consolidated|solidify|solidifying|solidified|strengthen|strengthening|strengthened|reinforce|reinforcing|reinforced|fortify|fortifying|fortified|secure|securing|secured|maintaining|holding)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.consolidation] =
          (scores[PhaseLabel.consolidation] ?? 0) + 1;
    }
  }

  void _analyzeQuestionVsProblem(String text, Map<PhaseLabel, int> scores) {
    // Discovery: questions, comprehensive keyword set
    if (RegExp(r'\b(what|why|how|when|where|question|questions|questioning|questioned|wondering|wondered|wonder|curious|curiosity|explore|exploring|exploration|explored|new|newly|learn|learning|learned|study|studying|studied|discover|discovering|discovery|discovered|beginning|beginnings|begin|start|starting|started|fresh|first|initial|early|goals|dreams|aspirations|hopes|hopeful|optimistic|positive|excited|enthusiastic|eager|thrilled|inspired|motivated|driven|ambitious|creativity|creative|imagination|innovative|spirituality|spiritual|mystery|magic|awe|fascination|intrigue|interest)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.discovery] = (scores[PhaseLabel.discovery] ?? 0) + 1;
    }

    // Recovery: problems being addressed, comprehensive keyword set
    if (RegExp(r'\b(problem|problems|issue|issues|difficulty|difficulties|challenge|challenges|struggling|struggle|rest|resting|heal|healing|recover|recovering|recovery|gentle|peace|peaceful|calm|restore|restoring|balance|harmony|meditation|mindfulness|self-care|therapy|support|comfort|safe|nurturing|caring|compassionate|kind|renewal|recharge|reset|health|wellness|wholeness|acceptance|forgiveness|patience)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.recovery] = (scores[PhaseLabel.recovery] ?? 0) + 1;
    }
  }

  void _analyzeNewVsOngoing(String text, Map<PhaseLabel, int> scores) {
    // Discovery: new, comprehensive keyword set
    if (RegExp(r'\b(new|newly|recent|just|started|beginning|beginnings|begin|fresh|first|initial|early|dawn|birth|genesis|origin|seed|sprout|bud|embryo|goals|dreams|aspirations|hopes|hopeful|hoping|optimistic|optimism|positive|positivity|explore|exploring|exploration|explored|curiosity|curious|wonder|wondering|wondered|question|questions|questioning|questioned|learn|learning|learned|study|studying|studied|discover|discovering|discovery|discovered|excited|excitement|enthusiastic|enthusiasm|eager|eagerness|anticipation|anticipating|thrilled|inspired|inspiration|motivated|motivation|driven|ambitious|ambition|creativity|creative|imagination|imaginative|innovative|innovation|spirituality|spiritual|sacred|divine|transcendent|mystical|mystery|magic|magical|awe|amazement|fascination|fascinated|intrigue|intrigued|interest|interested|interesting)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.discovery] = (scores[PhaseLabel.discovery] ?? 0) + 1;
    }

    // Consolidation: ongoing, established, comprehensive keyword set
    if (RegExp(r'\b(ongoing|always|usually|typically|established|settled|stable|consistent|maintaining|routine|routines|habit|habits|pattern|patterns|structure|structured|organization|organize|organizing|system|systems|order|ordered|foundation|foundational|base|basis|core|center|centered|grounded|rooted|anchored|integrate|integrating|integration|integrated|weave|weaving|consolidate|consolidating|consolidation|consolidated|solidify|solidified|strengthen|strengthened|reinforce|reinforced|fortify|fortified|secure|secured|home|friendship|friendships|community|communities|belonging|belong|reflection|reflecting|reflective|awareness|aware|conscious|consciousness|mindful|mindfulness|presence|present|focus|focused)\b')
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
    // Breakthrough: sudden, comprehensive keyword set
    if (RegExp(r'\b(suddenly|sudden|recently|just|quickly|fast|epiphany|epiphanies|breakthrough|breakthroughs|realized|realize|realization|clarity|clear|clearly|insight|insights|understand|understanding|aha|eureka|revelation|revelations|transformation|transform|transforming|wisdom|purpose|meaning|threshold|crossing|momentum|coherent|unlock|unlocked|path|alive|vibrant|crisp|landing|arrived|achieved|accomplished|fulfilled)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.breakthrough] =
          (scores[PhaseLabel.breakthrough] ?? 0) + 1;
    }

    // Recovery: gradual, comprehensive keyword set
    if (RegExp(r'\b(gradually|slowly|over time|for a while|long time|rest|resting|heal|healing|recover|recovering|recovery|gentle|gently|peace|peaceful|calm|restore|restoring|balance|harmony|meditation|mindfulness|self-care|therapy|support|comfort|safe|nurturing|caring|compassionate|kind|renewal|recharge|reset|health|wellness|wholeness|acceptance|forgiveness|patience|patient)\b')
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
    // Expansion: getting stronger, comprehensive keyword set
    if (RegExp(r'\b(stronger|growing|increasing|building|expanding|grow|growth|expand|expansion|reach|reaching|possibility|energy|energetic|energized|outward|more|bigger|greater|increase|grateful|joyful|confident|vitality|dynamic|enthusiastic|passionate|opportunity|progress|abundance|flourishing|thriving|prosperous|success|achievement|improvement|multiplying|amplifying|enhanced|rising|ascending|climbing|soaring|flowing)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.expansion] = (scores[PhaseLabel.expansion] ?? 0) + 1;
    }

    // Recovery: getting quieter/better, comprehensive keyword set
    if (RegExp(r'\b(quieter|calmer|better|improving|healing|rest|resting|heal|recover|recovering|recovery|gentle|peace|peaceful|calm|restore|restoring|balance|harmony|meditation|mindfulness|self-care|therapy|support|comfort|safe|nurturing|caring|compassionate|kind|renewal|recharge|reset|health|wellness|wholeness|acceptance|forgiveness|patience)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.recovery] = (scores[PhaseLabel.recovery] ?? 0) + 1;
    }

    // Transition: shifting, comprehensive keyword set
    if (RegExp(r'\b(shifting|changing|transforming|evolving|moving|change|transition|shift|transform|evolve|adapt|adjust|modify|uncertain|confused|mixed|between|limbo|uncomfortable|uneasy|restless|anxious|letting go|release|move|pivot|switch|crossroads|threshold|edge|boundary|neither|both|unknown|unclear)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.transition] = (scores[PhaseLabel.transition] ?? 0) + 1;
    }
  }

  void _analyzeMomentum(String text, Map<PhaseLabel, int> scores) {
    // Expansion: momentum, comprehensive keyword set
    if (RegExp(r'\b(momentum|flow|rolling|building|accelerating|grow|growing|growth|expand|expanding|expansion|reach|reaching|reached|possibility|possibilities|possible|energy|energetic|energized|outward|external|outside|beyond|further|more|bigger|larger|greater|increase|increasing|increased|grateful|gratitude|thankful|joyful|joy|happiness|happy|blessed|blessing|confident|confidence|vitality|vibrant|alive|lively|dynamic|active|enthusiastic|enthusiasm|passionate|passion|excited|excitement|opportunity|opportunities|progress|progressing|progressed|abundance|abundant|flourishing|flourish|thriving|thrive|thrived|prosperous|prosperity|success|successful|achievement|achieving|accomplishment|accomplishing|improvement|improving|improved|multiplying|amplifying|amplified|enhanced|enhancing|boosted|boosting|elevated|elevating|rising|ascending|climbing|soaring|flying|sailing|flowing)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.expansion] = (scores[PhaseLabel.expansion] ?? 0) + 1;
    }

    // Consolidation: stability, comprehensive keyword set
    if (RegExp(r'\b(stable|stability|steadfast|steady|consistent|consistency|constant|reliable|reliability|dependable|dependability|trustworthy|trust|maintaining|holding|settled|established|grounded|rooted|anchored|foundation|foundational|base|basis|core|center|centered|structure|structured|organization|organize|organizing|system|systems|order|ordered|orderly|systematic|methodical|disciplined|discipline|routine|routines|habit|habits|pattern|patterns|integrate|integrating|integration|integrated|weave|weaving|consolidate|consolidating|consolidation|consolidated|solidify|solidified|strengthen|strengthened|reinforce|reinforced|fortify|fortified|secure|secured|reflection|reflecting|reflective|awareness|aware|conscious|consciousness|mindful|mindfulness|presence|present|focus|focused)\b')
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
    // Expansion: pursuit, comprehensive keyword set
    if (RegExp(r'\b(pursuing|seeking|working toward|building|creating|grow|growing|growth|expand|expanding|expansion|reach|reaching|possibility|energy|outward|more|bigger|greater|increase|grateful|joyful|confident|vitality|dynamic|enthusiastic|passionate|opportunity|progress|abundance|flourishing|thriving|prosperous|success|achievement|improvement|multiplying|amplifying|enhanced|rising|ascending|climbing|soaring|flowing)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.expansion] = (scores[PhaseLabel.expansion] ?? 0) + 1;
    }

    // Recovery: protection, comprehensive keyword set
    if (RegExp(r'\b(protecting|preserving|maintaining|keeping|holding|rest|resting|rested|heal|healing|recover|recovering|recovery|gentle|gently|breathe|breathing|breathed|peace|peaceful|peacefully|calm|calmly|calmness|restore|restoring|restored|restoration|balance|balanced|balancing|equilibrium|harmony|harmonious|meditation|meditating|mindfulness|mindful|self-care|therapy|support|supported|comfort|comfortable|comforting|safe|safety|protected|protection|nurturing|nurture|caring|care|compassionate|compassion|kind|kindness|renewal|renew|renewing|renewed|recharge|recharging|recharged|reset|resetting|resetted|fresh start|beginning again|starting over|health|healthy|wellness|well|wholeness|whole|integration|integrated|acceptance|accept|accepting|accepted|forgiveness|forgive|forgiving|forgave|patience|patient)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.recovery] = (scores[PhaseLabel.recovery] ?? 0) + 1;
    }

    // Consolidation: also includes maintaining, preserving, protecting
    if (RegExp(r'\b(maintaining|preserving|protecting|keeping|holding|stable|steady|consistent|settled|established|grounded|foundation|structure|organized|system|order|routine|habit|pattern|integrate|weave|consolidate|strengthen|reinforce|secure|home|friendship|community|belonging|reflection|awareness|conscious|mindful|presence|focus)\b')
        .hasMatch(text)) {
      scores[PhaseLabel.consolidation] =
          (scores[PhaseLabel.consolidation] ?? 0) + 1;
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

  /// Analyze text length - longer responses suggest consolidation
  void _analyzeTextLength(String text, Map<PhaseLabel, int> scores) {
    final charCount = text.length;
    final wordCount = text.split(' ').where((w) => w.isNotEmpty).length;

    // Longer responses (> 100 chars or > 20 words) suggest consolidation
    // This matches the main app's logic where longer entries suggest deeper processing
    if (charCount > 100 || wordCount > 20) {
      scores[PhaseLabel.consolidation] =
          (scores[PhaseLabel.consolidation] ?? 0) + 1;
    }

    // Very short responses (< 20 chars or < 5 words) might suggest expansion (quick thoughts)
    if (charCount < 20 && wordCount < 5) {
      scores[PhaseLabel.expansion] = (scores[PhaseLabel.expansion] ?? 0) + 1;
    }

    // Medium length responses (20-100 chars, 5-20 words) might suggest discovery
    if (charCount >= 20 && charCount <= 100 && wordCount >= 5 && wordCount <= 20) {
      scores[PhaseLabel.discovery] = (scores[PhaseLabel.discovery] ?? 0) + 1;
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
