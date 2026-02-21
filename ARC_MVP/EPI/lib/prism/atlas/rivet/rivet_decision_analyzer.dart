// RIVET decision trigger detection (Crossroads).
// Runs alongside existing transition detection; analyzes message text for decision phrases.

import 'rivet_models.dart';

/// Phase-based sensitivity for decision detection (phase name -> weight)
const Map<String, double> decisionPhaseWeights = {
  'transition': 0.90,
  'breakthrough': 0.85,
  'consolidation': 0.80,
  'expansion': 0.75,
  'discovery': 0.45,
  'recovery': 0.35,
};

/// Phrase patterns per category (lowercase)
const Map<DecisionPhraseCategory, List<String>> decisionPhrasePatterns = {
  DecisionPhraseCategory.consideration: [
    "i'm thinking about",
    "i've been considering",
    "i'm wondering if",
    "i keep thinking about",
    "i've been thinking",
  ],
  DecisionPhraseCategory.activeChoice: [
    "torn between",
    "going back and forth",
    "i don't know whether",
    "i can't decide",
    "i keep going back and forth",
    "part of me wants",
  ],
  DecisionPhraseCategory.seekingOpinion: [
    "what do you think",
    "should i",
    "do you think i should",
    "would you",
    "what would you do",
  ],
  DecisionPhraseCategory.actionFraming: [
    "i've decided to",
    "i'm going to",
    "i think i'll",
    "i've made up my mind",
    "i decided",
  ],
  DecisionPhraseCategory.futureWeighing: [
    "trying to figure out",
    "weighing",
    "not sure if i should",
    "thinking through",
    "pros and cons",
  ],
};

/// Phrase category weights for confidence
const Map<DecisionPhraseCategory, double> _phraseWeights = {
  DecisionPhraseCategory.activeChoice: 0.90,
  DecisionPhraseCategory.seekingOpinion: 0.85,
  DecisionPhraseCategory.consideration: 0.75,
  DecisionPhraseCategory.futureWeighing: 0.70,
  DecisionPhraseCategory.actionFraming: 0.65,
};

/// Minimum confidence to emit a decision trigger (avoid false positives)
const double decisionTriggerThreshold = 0.65;

/// Analyzes message text for decision triggers. Independent of RivetService.ingest().
class RivetDecisionAnalyzer {
  RivetDecisionAnalyzer();

  /// Combine phase weight and phrase weight into confidence (phase 40%, phrase 60%).
  double calculateDecisionConfidence({
    required String currentPhase,
    required DecisionPhraseCategory phraseCategory,
    required String messageText,
  }) {
    final phaseWeight = decisionPhaseWeights[currentPhase.toLowerCase()] ?? 0.5;
    final phraseWeight = _phraseWeights[phraseCategory] ?? 0.5;
    return (phaseWeight * 0.4) + (phraseWeight * 0.6);
  }

  /// Analyze message for decision trigger only. Returns 0 or 1 output; does not run transition detection.
  List<RivetOutput> analyzeMessage({
    required String messageText,
    required String currentPhase,
    DateTime? detectedAt,
  }) {
    final now = detectedAt ?? DateTime.now();
    final lower = messageText.trim().toLowerCase();
    if (lower.isEmpty) return [];

    DecisionPhraseCategory? bestCategory;
    String bestPhrase = '';
    double bestConfidence = 0.0;
    double bestPhaseWeight = 0.5;
    double bestPhraseWeight = 0.5;

    for (final entry in decisionPhrasePatterns.entries) {
      for (final pattern in entry.value) {
        if (lower.contains(pattern)) {
          final phaseWeight = decisionPhaseWeights[currentPhase.toLowerCase()] ?? 0.5;
          final phraseWeight = _phraseWeights[entry.key] ?? 0.5;
          final confidence = (phaseWeight * 0.4) + (phraseWeight * 0.6);
          if (confidence >= decisionTriggerThreshold && confidence > bestConfidence) {
            bestConfidence = confidence;
            bestCategory = entry.key;
            bestPhrase = pattern;
            bestPhaseWeight = phaseWeight;
            bestPhraseWeight = phraseWeight;
          }
        }
      }
    }

    if (bestCategory == null || bestConfidence < decisionTriggerThreshold) {
      return [];
    }

    final contextStart = messageText.length > 100 ? 100 : messageText.length;
    final rawMessageContext = messageText.trim().substring(0, contextStart);

    final signal = DecisionTriggerSignal(
      phraseCategory: bestCategory,
      detectedPhrase: bestPhrase,
      currentPhase: currentPhase,
      phaseWeight: bestPhaseWeight,
      phraseWeight: bestPhraseWeight,
      rawMessageContext: rawMessageContext,
    );

    return [
      RivetOutput(
        type: RivetOutputType.decisionTrigger,
        confidenceScore: bestConfidence,
        decisionSignal: signal,
        detectedAt: now,
      ),
    ];
  }
}
