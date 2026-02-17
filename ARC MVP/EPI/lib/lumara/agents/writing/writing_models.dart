// Shared DTOs for the LUMARA Writing Agent.
// Used by VoiceAnalyzer, ThemeTracker, ToneCalibrator, DraftComposer,
// SelfCritic, and WritingAgent.

/// Content type for generated drafts.
enum ContentType {
  linkedIn,
  substack,
  technical,
}

/// Sentence structure description (from voice analysis).
class SentencePattern {
  final String description;
  final double averageLength;
  final double variance;

  const SentencePattern({
    required this.description,
    this.averageLength = 0,
    this.variance = 0,
  });
}

/// Vocabulary level description.
class VocabularyLevel {
  final String description;

  const VocabularyLevel({required this.description});
}

/// Punctuation style description.
class PunctuationPattern {
  final String description;

  const PunctuationPattern({required this.description});
}

/// Emotional tone for tone guidance.
enum EmotionalTone {
  vulnerable,
  confident,
  challenging,
  reflective,
  exploratory,
  curious,
  integrative,
  gentle,
}

extension EmotionalToneExtension on EmotionalTone {
  String get description {
    switch (this) {
      case EmotionalTone.vulnerable:
        return 'Vulnerable, honest about uncertainty';
      case EmotionalTone.confident:
        return 'Confident, growth-oriented';
      case EmotionalTone.challenging:
        return 'Bold, market-challenging';
      case EmotionalTone.reflective:
        return 'Reflective, process-focused';
      case EmotionalTone.exploratory:
        return 'Exploratory, honest about uncertainty';
      case EmotionalTone.curious:
        return 'Curious, learning-focused, questioning';
      case EmotionalTone.integrative:
        return 'Integrative, synthesis-focused, grounded';
      case EmotionalTone.gentle:
        return 'Gentle, reflective, process-focused';
    }
  }
}

/// Call-to-action style.
enum CTAStyle {
  gentleInvite,
  strongChallenge,
  question,
  none,
}

extension CTAStyleExtension on CTAStyle {
  String get description {
    switch (this) {
      case CTAStyle.gentleInvite:
        return 'Gentle invitation or question';
      case CTAStyle.strongChallenge:
        return 'Strong challenge or call to action';
      case CTAStyle.question:
        return 'End with an invitation question';
      case CTAStyle.none:
        return 'No explicit CTA';
    }
  }
}

/// Extracted voice profile from CHRONICLE entries or a single text.
class VoiceProfile {
  final SentencePattern sentenceLength;
  final VocabularyLevel vocabularyLevel;
  final PunctuationPattern punctuationStyle;
  final List<String> signaturePhrases;
  final double formalityScore; // 0.0 = very casual, 1.0 = very formal
  final List<String> openingPatterns;

  const VoiceProfile({
    required this.sentenceLength,
    required this.vocabularyLevel,
    required this.punctuationStyle,
    this.signaturePhrases = const [],
    this.formalityScore = 0.5,
    this.openingPatterns = const [],
  });
}

/// A biographical moment to reference in content.
class BiographicalMoment {
  final String summary;
  final DateTime date;
  final String? entryId;

  const BiographicalMoment({
    required this.summary,
    required this.date,
    this.entryId,
  });
}

/// Thematic context from CHRONICLE aggregations and Layer0.
class ThemeContext {
  final List<String> primaryThemes;
  final List<BiographicalMoment> relatedMoments;
  final Map<String, String> establishedPositions; // topic -> stance
  final List<String> recurrentMetaphors;

  const ThemeContext({
    this.primaryThemes = const [],
    this.relatedMoments = const [],
    this.establishedPositions = const {},
    this.recurrentMetaphors = const [],
  });
}

/// Phase-aware tone guidance for draft composition.
class ToneGuidance {
  final EmotionalTone emotionalTone;
  final double ambitionLevel; // 0-10 scale
  final double futureOrientation; // 0 = past-focused, 1 = future-focused
  final double vulnerability; // how much uncertainty to show
  final CTAStyle callToAction;
  final String phase; // display name of current phase

  const ToneGuidance({
    required this.emotionalTone,
    this.ambitionLevel = 5,
    this.futureOrientation = 0.5,
    this.vulnerability = 0.5,
    this.callToAction = CTAStyle.gentleInvite,
    this.phase = 'Discovery',
  });
}

/// Metadata for a generated draft.
class DraftMetadata {
  final String phase;
  final int wordCount;
  final DateTime generatedAt;
  /// Parsed from agent footer: "Context signals used" block (for display).
  final String? contextSignalsUsed;
  /// Parsed from agent footer: Voice Match Estimate % (0-100).
  final double? voiceMatchEstimate;
  /// Parsed from agent footer: Theme Match Estimate % (0-100).
  final double? themeMatchEstimate;

  const DraftMetadata({
    this.phase = 'Discovery',
    this.wordCount = 0,
    required this.generatedAt,
    this.contextSignalsUsed,
    this.voiceMatchEstimate,
    this.themeMatchEstimate,
  });

  DraftMetadata copyWith({
    String? phase,
    int? wordCount,
    DateTime? generatedAt,
    String? contextSignalsUsed,
    double? voiceMatchEstimate,
    double? themeMatchEstimate,
  }) {
    return DraftMetadata(
      phase: phase ?? this.phase,
      wordCount: wordCount ?? this.wordCount,
      generatedAt: generatedAt ?? this.generatedAt,
      contextSignalsUsed: contextSignalsUsed ?? this.contextSignalsUsed,
      voiceMatchEstimate: voiceMatchEstimate ?? this.voiceMatchEstimate,
      themeMatchEstimate: themeMatchEstimate ?? this.themeMatchEstimate,
    );
  }
}

/// A composed draft (before or after critique).
class Draft {
  final String content;
  final double? voiceScore;
  final double? themeAlignment;
  final DraftMetadata metadata;

  const Draft({
    required this.content,
    this.voiceScore,
    this.themeAlignment,
    required this.metadata,
  });

  Draft copyWith({
    String? content,
    double? voiceScore,
    double? themeAlignment,
    DraftMetadata? metadata,
  }) {
    return Draft(
      content: content ?? this.content,
      voiceScore: voiceScore ?? this.voiceScore,
      themeAlignment: themeAlignment ?? this.themeAlignment,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Result of self-critique (voice/theme scores, AI tells, suggestions).
class CritiqueResult {
  final double voiceScore;
  final double themeScore;
  final List<String> aiTells;
  final List<String> suggestions;
  final bool passesThreshold;

  const CritiqueResult({
    required this.voiceScore,
    required this.themeScore,
    this.aiTells = const [],
    this.suggestions = const [],
    required this.passesThreshold,
  });
}

/// Final composed content returned to the user.
class ComposedContent {
  final Draft draft;
  final double? voiceScore;
  final double? themeAlignment;
  final List<String> suggestedEdits;

  const ComposedContent({
    required this.draft,
    this.voiceScore,
    this.themeAlignment,
    this.suggestedEdits = const [],
  });
}

/// Optional storage for composed drafts (e.g. for history or reference).
abstract class WritingDraftRepository {
  Future<void> storeDraft({
    required String userId,
    required Draft draft,
    required DraftMetadata metadata,
  });
}
