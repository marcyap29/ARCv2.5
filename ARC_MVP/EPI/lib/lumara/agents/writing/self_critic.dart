import 'package:my_app/lumara/agents/writing/writing_models.dart';
import 'package:my_app/lumara/agents/writing/voice_analyzer.dart';

/// Evaluates draft authenticity (voice match, theme alignment) and detects AI tells.
class SelfCritic {
  static const double voiceThreshold = 0.8;
  static const double themeThreshold = 0.7;

  final VoiceAnalyzer _voiceAnalyzer;

  SelfCritic({VoiceAnalyzer? voiceAnalyzer}) : _voiceAnalyzer = voiceAnalyzer ?? VoiceAnalyzer();

  /// Critique a draft against expected voice and themes.
  Future<CritiqueResult> critiqueDraft({
    required Draft draft,
    required VoiceProfile expectedVoice,
    required ThemeContext expectedThemes,
  }) async {
    final actualVoice = _voiceAnalyzer.analyzeVoiceFromText(draft.content);
    final voiceScore = _compareVoiceProfiles(expectedVoice, actualVoice);
    final themeScore = _evaluateThemeAlignment(draft.content, expectedThemes);
    final aiTells = _detectAITells(draft.content);
    final suggestions = _generateSuggestions(
      voiceScore: voiceScore,
      themeScore: themeScore,
      aiTells: aiTells,
      expectedVoice: expectedVoice,
      expectedThemes: expectedThemes,
    );
    final passesThreshold = voiceScore >= voiceThreshold && themeScore >= themeThreshold;

    return CritiqueResult(
      voiceScore: voiceScore,
      themeScore: themeScore,
      aiTells: aiTells,
      suggestions: suggestions,
      passesThreshold: passesThreshold,
    );
  }

  double _compareVoiceProfiles(VoiceProfile expected, VoiceProfile actual) {
    double score = 1.0;

    // Sentence length: compare average (allow some variance)
    final expAvg = expected.sentenceLength.averageLength;
    final actAvg = actual.sentenceLength.averageLength;
    if (expAvg > 0 && actAvg > 0) {
      final ratio = actAvg / expAvg;
      if (ratio < 0.5 || ratio > 2.0) {
        score -= 0.25;
      } else if (ratio < 0.7 || ratio > 1.4) {
        score -= 0.1;
      }
    }

    // Formality: close match
    final formalityDiff = (expected.formalityScore - actual.formalityScore).abs();
    if (formalityDiff > 0.3) {
      score -= 0.2;
    } else if (formalityDiff > 0.15) {
      score -= 0.1;
    }

    // Signature phrase overlap: at least one expected phrase present
    if (expected.signaturePhrases.isNotEmpty) {
      final lower = actual.signaturePhrases.map((s) => s.toLowerCase()).toSet();
      final found = expected.signaturePhrases.where((p) => lower.contains(p.toLowerCase())).length;
      if (found == 0) {
        score -= 0.15;
      } else if (found < expected.signaturePhrases.length / 2) {
        score -= 0.05;
      }
    }

    return score.clamp(0.0, 1.0);
  }

  double _evaluateThemeAlignment(String content, ThemeContext expectedThemes) {
    final lower = content.toLowerCase();
    if (expectedThemes.primaryThemes.isEmpty && expectedThemes.establishedPositions.isEmpty && expectedThemes.recurrentMetaphors.isEmpty) {
      return 0.85; // No strong theme requirement
    }
    int hits = 0;
    int total = 0;
    for (final theme in expectedThemes.primaryThemes) {
      total++;
      if (lower.contains(theme.toLowerCase())) hits++;
    }
    for (final key in expectedThemes.establishedPositions.keys) {
      total++;
      if (lower.contains(key.toLowerCase())) hits++;
    }
    for (final metaphor in expectedThemes.recurrentMetaphors) {
      total++;
      if (lower.contains(metaphor.toLowerCase())) hits++;
    }
    if (total == 0) return 0.85;
    return (hits / total).clamp(0.0, 1.0);
  }

  List<String> _detectAITells(String content) {
    final tells = <String>[];
    final lower = content.toLowerCase();

    const aiPhrases = [
      'delve into',
      'dive deep',
      'diving deep',
      'landscape',
      'game-changer',
      'exciting opportunity',
      'it\'s worth noting',
      'in conclusion',
      'in summary',
      'to summarize',
      'let\'s explore',
      'navigating the',
      'unlock the',
      'harness the',
      'leverage',
      'robust',
      'seamlessly',
      'comprehensive',
    ];
    for (final phrase in aiPhrases) {
      if (lower.contains(phrase)) tells.add(phrase);
    }

    final hedging = RegExp(r'\b(perhaps|might|possibly|could potentially|it may be)\b', caseSensitive: false);
    final hedgingCount = hedging.allMatches(lower).length;
    if (hedgingCount > 3) tells.add('Excessive hedging ($hedgingCount instances)');

    final bulletCount = RegExp(r'^[\s]*[-*•]\s', multiLine: true).allMatches(content).length;
    if (bulletCount > 8) tells.add('Overuse of bullet points');

    return tells;
  }

  List<String> _generateSuggestions({
    required double voiceScore,
    required double themeScore,
    required List<String> aiTells,
    required VoiceProfile expectedVoice,
    required ThemeContext expectedThemes,
  }) {
    final suggestions = <String>[];
    if (voiceScore < voiceThreshold) {
      suggestions.add('Match the user\'s voice more closely: ${expectedVoice.sentenceLength.description}.');
      if (expectedVoice.signaturePhrases.isNotEmpty) {
        suggestions.add('Consider using a signature phrase like: "${expectedVoice.signaturePhrases.first}"');
      }
    }
    if (themeScore < themeThreshold) {
      if (expectedThemes.primaryThemes.isNotEmpty) {
        suggestions.add('Reference or reinforce these themes: ${expectedThemes.primaryThemes.take(5).join(", ")}.');
      }
      if (expectedThemes.recurrentMetaphors.isNotEmpty) {
        suggestions.add('Weave in a recurring metaphor if relevant: ${expectedThemes.recurrentMetaphors.first}.');
      }
    }
    for (final tell in aiTells) {
      suggestions.add('Remove or rephrase AI-sounding language: "$tell"');
    }
    return suggestions;
  }
}
