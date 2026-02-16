import 'package:my_app/chronicle/core/chronicle_repos.dart';
import 'package:my_app/chronicle/storage/layer0_repository.dart';
import 'package:my_app/lumara/agents/writing/writing_models.dart';

/// Extracts the user's writing voice from CHRONICLE entries or a single text.
///
/// Used by WritingAgent for voice profile and by SelfCritic to compare draft to expected voice.
class VoiceAnalyzer {
  final Layer0Repository _layer0Repo;

  VoiceAnalyzer({Layer0Repository? layer0Repository})
      : _layer0Repo = layer0Repository ?? ChronicleRepos.layer0;

  /// Analyze voice from the user's recent CHRONICLE Layer 0 entries.
  Future<VoiceProfile> analyzeVoice({
    required String userId,
    int sampleSize = 20,
  }) async {
    await _layer0Repo.initialize();
    final entries = await _layer0Repo.getRecentEntries(userId, sampleSize);
    final texts = entries.map((e) => e.content).where((t) => t.trim().isNotEmpty).toList();
    if (texts.isEmpty) {
      return _defaultVoiceProfile();
    }
    return _analyzeTexts(texts);
  }

  /// Analyze voice from a single text (e.g. draft content for SelfCritic).
  VoiceProfile analyzeVoiceFromText(String text) {
    if (text.trim().isEmpty) return _defaultVoiceProfile();
    return _analyzeTexts([text]);
  }

  VoiceProfile _defaultVoiceProfile() {
    return const VoiceProfile(
      sentenceLength: SentencePattern(description: 'Medium length, moderate variance'),
      vocabularyLevel: VocabularyLevel(description: 'Accessible, mixed'),
      punctuationStyle: PunctuationPattern(description: 'Standard'),
      signaturePhrases: [],
      formalityScore: 0.5,
      openingPatterns: [],
    );
  }

  VoiceProfile _analyzeTexts(List<String> texts) {
    final combined = texts.join('\n\n');
    final sentences = _splitSentences(combined);
    final sentenceLength = _computeSentencePattern(sentences);
    final vocabularyLevel = _computeVocabularyLevel(combined);
    final punctuationStyle = _computePunctuationStyle(combined, sentences);
    final signaturePhrases = _extractSignaturePhrases(texts);
    final formalityScore = _computeFormality(combined, sentences);
    final openingPatterns = _extractOpeningPatterns(texts);

    return VoiceProfile(
      sentenceLength: sentenceLength,
      vocabularyLevel: vocabularyLevel,
      punctuationStyle: punctuationStyle,
      signaturePhrases: signaturePhrases,
      formalityScore: formalityScore,
      openingPatterns: openingPatterns,
    );
  }

  List<String> _splitSentences(String text) {
    return text
        .split(RegExp(r'[.!?]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  SentencePattern _computeSentencePattern(List<String> sentences) {
    if (sentences.isEmpty) {
      return const SentencePattern(description: 'Insufficient data');
    }
    final lengths = sentences.map((s) => s.split(RegExp(r'\s+')).length).toList();
    final avg = lengths.reduce((a, b) => a + b) / lengths.length;
    final variance = lengths.map((l) => (l - avg) * (l - avg)).reduce((a, b) => a + b) / lengths.length;
    final stdDev = variance > 0 ? variance : 0.0;

    String desc;
    if (avg < 12) {
      desc = 'Short sentences (avg ${avg.toStringAsFixed(0)} words)';
    } else if (avg > 22) {
      desc = 'Longer sentences (avg ${avg.toStringAsFixed(0)} words)';
    } else {
      desc = 'Medium length (avg ${avg.toStringAsFixed(0)} words)';
    }
    if (stdDev > 8) {
      desc += ', varied length';
    } else {
      desc += ', consistent length';
    }
    return SentencePattern(description: desc, averageLength: avg, variance: variance);
  }

  VocabularyLevel _computeVocabularyLevel(String text) {
    final words = text.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 1).toList();
    if (words.isEmpty) return const VocabularyLevel(description: 'Accessible');
    final avgLen = words.map((w) => w.length).reduce((a, b) => a + b) / words.length;
    // Simple heuristic: longer avg word + jargon-like tokens → technical
    final jargonLike = RegExp(r'\b(architecture|implementation|algorithm|integration|api|framework|metadata|schema)\b', caseSensitive: false);
    final jargonCount = jargonLike.allMatches(text).length;
    final wordCount = words.length;
    final jargonDensity = wordCount > 0 ? jargonCount / (wordCount / 100) : 0.0;

    if (avgLen > 5.5 || jargonDensity > 2) {
      return const VocabularyLevel(description: 'Technical, precise');
    }
    if (avgLen < 4.2) {
      return const VocabularyLevel(description: 'Accessible, conversational');
    }
    return const VocabularyLevel(description: 'Mixed, accessible with some depth');
  }

  PunctuationPattern _computePunctuationStyle(String text, List<String> sentences) {
    final emDashCount = RegExp(r'—|--').allMatches(text).length;
    final parenCount = RegExp(r'\([^)]+\)').allMatches(text).length;
    final fragmentCount = sentences.where((s) {
      final words = s.split(RegExp(r'\s+'));
      return words.length <= 4 && !s.endsWith('?');
    }).length;
    final totalSentences = sentences.length;
    final fragmentRatio = totalSentences > 0 ? fragmentCount / totalSentences : 0.0;

    final parts = <String>[];
    if (emDashCount > 2) parts.add('uses em-dashes');
    if (parenCount > 1) parts.add('parenthetical asides');
    if (fragmentRatio > 0.15) parts.add('sentence fragments');
    if (parts.isEmpty) parts.add('Standard punctuation');
    return PunctuationPattern(description: parts.join(', '));
  }

  List<String> _extractSignaturePhrases(List<String> texts) {
    final phraseCount = <String, int>{};
    const candidates = [
      "Here's the thing",
      "That said",
      "The reality:",
      "Here's the thing:",
      "What I mean is",
      "The thing is",
      "To be honest",
      "In other words",
      "At the end of the day",
      "Bottom line",
    ];
    for (final text in texts) {
      final lower = text.toLowerCase();
      for (final phrase in candidates) {
        if (lower.contains(phrase.toLowerCase())) {
          phraseCount[phrase] = (phraseCount[phrase] ?? 0) + 1;
        }
      }
    }
    return phraseCount.entries.where((e) => e.value >= 2).map((e) => e.key).toList();
  }

  double _computeFormality(String text, List<String> sentences) {
    double score = 0.5;
    final lower = text.toLowerCase();
    final contractions = RegExp(r"\b(don't|can't|won't|it's|that's|here's|there's|what's|isn't|aren't)\b").allMatches(lower).length;
    final wordCount = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final contractionRatio = wordCount > 0 ? contractions / (wordCount / 100) : 0;
    if (contractionRatio > 3) score -= 0.2;
    if (contractionRatio < 1) score += 0.15;

    final avgSentenceWords = sentences.isEmpty ? 15 : text.split(RegExp(r'\s+')).length / sentences.length;
    if (avgSentenceWords > 25) score += 0.1;
    if (avgSentenceWords < 10) score -= 0.1;

    return score.clamp(0.0, 1.0);
  }

  List<String> _extractOpeningPatterns(List<String> texts) {
    final patterns = <String>[];
    final boldOpeners = RegExp(r"^(Here's|The|That|This is|What)");
    for (final text in texts) {
      final parts = text.trim().split(RegExp(r'[.!?\n]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      final first = parts.isEmpty ? null : parts.first;
      if (first == null || first.length < 10) continue;
      if (first.endsWith('?')) {
        if (!patterns.contains('Question')) {
          patterns.add('Question');
        }
      } else if (first.length < 60 && boldOpeners.hasMatch(first)) {
        if (!patterns.contains('Bold claim or statement')) {
          patterns.add('Bold claim or statement');
        }
      } else {
        if (!patterns.contains('Statement')) {
          patterns.add('Statement');
        }
      }
    }
    return patterns.isEmpty ? ['Statement'] : patterns;
  }
}
