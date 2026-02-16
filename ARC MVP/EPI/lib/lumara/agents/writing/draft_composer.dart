import 'package:my_app/lumara/agents/writing/writing_models.dart';

/// Callback type for LLM generation (inject Groq/Gemini from app layer).
typedef WritingLlmGenerate = Future<String> Function({
  required String systemPrompt,
  required String userPrompt,
  int? maxTokens,
});

/// Generates draft content using voice profile, theme context, and tone guidance.
///
/// Builds the system prompt from spec and calls the injected LLM.
class DraftComposer {
  final WritingLlmGenerate _generate;

  DraftComposer({required WritingLlmGenerate generate}) : _generate = generate;

  /// Compose a draft from the user prompt and context.
  Future<Draft> composeDraft({
    required String prompt,
    required VoiceProfile voice,
    required ThemeContext themes,
    required ToneGuidance tone,
    required ContentType type,
  }) async {
    final systemPrompt = _buildWritingSystemPrompt(
      voice: voice,
      themes: themes,
      tone: tone,
      type: type,
    );
    int maxTokens = 800;
    switch (type) {
      case ContentType.linkedIn:
        maxTokens = 600;
        break;
      case ContentType.substack:
        maxTokens = 2500;
        break;
      case ContentType.technical:
        maxTokens = 2000;
        break;
    }
    final content = await _generate(
      systemPrompt: systemPrompt,
      userPrompt: prompt,
      maxTokens: maxTokens,
    );
    final trimmed = content.trim();
    final wordCount = trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return Draft(
      content: trimmed,
      metadata: DraftMetadata(
        phase: tone.phase,
        wordCount: wordCount,
        generatedAt: DateTime.now(),
      ),
    );
  }

  String _buildWritingSystemPrompt({
    required VoiceProfile voice,
    required ThemeContext themes,
    required ToneGuidance tone,
    required ContentType type,
  }) {
    final momentsBlock = themes.relatedMoments.isEmpty
        ? 'None specified.'
        : themes.relatedMoments
            .map((m) => '- ${m.summary} (${m.date.year}-${m.date.month.toString().padLeft(2, '0')})')
            .join('\n');
    final positionsStr = themes.establishedPositions.isEmpty
        ? 'None specified.'
        : themes.establishedPositions.entries.map((e) => '${e.key}: ${e.value}').join('; ');

    return '''
You are composing content for a user with a specific voice and thematic consistency.

## VOICE PATTERNS (from CHRONICLE analysis)
- Sentence structure: ${voice.sentenceLength.description}
- Vocabulary level: ${voice.vocabularyLevel.description}
- Signature phrases: ${voice.signaturePhrases.isEmpty ? 'None identified' : voice.signaturePhrases.join(', ')}
- Punctuation style: ${voice.punctuationStyle.description}
- Formality: ${voice.formalityScore.toStringAsFixed(2)} (0=casual, 1=formal)
- Typical openings: ${voice.openingPatterns.isEmpty ? 'Statement' : voice.openingPatterns.join(' | ')}

## THEMATIC CONTEXT
Primary themes to reinforce: ${themes.primaryThemes.isEmpty ? 'Use the user\'s prompt to guide themes.' : themes.primaryThemes.join(', ')}
Established positions: $positionsStr
Recurring metaphors: ${themes.recurrentMetaphors.isEmpty ? 'None specified' : themes.recurrentMetaphors.join(', ')}

## BIOGRAPHICAL MOMENTS TO REFERENCE (if relevant)
$momentsBlock

## TONE GUIDANCE (Current Phase: ${tone.phase})
- Emotional tone: ${tone.emotionalTone.description}
- Ambition level: ${tone.ambitionLevel.toStringAsFixed(1)}/10
- Future orientation: ${tone.futureOrientation.toStringAsFixed(2)} (0=past-focused, 1=future-focused)
- Vulnerability: ${tone.vulnerability.toStringAsFixed(2)} (show uncertainty appropriately)
- Call to action: ${tone.callToAction.description}

## CONTENT TYPE: ${type.name}
${_getContentTypeGuidance(type)}

## CRITICAL REQUIREMENTS
1. Write in the user's authentic voice - match their patterns exactly.
2. Reference biographical journey when relevant (not forced).
3. Reinforce established themes without repeating verbatim.
4. Adapt tone to current phase - avoid inappropriate ambition/vulnerability.
5. Sound like a human with a story, not an AI assistant.

Generate content that this person would actually write themselves.
''';
  }

  String _getContentTypeGuidance(ContentType type) {
    switch (type) {
      case ContentType.linkedIn:
        return '''
- Length: 200-400 words
- Structure: Hook → insight/story → takeaway
- Tone: Professional but personal, conversational authority
- Opening line must grab attention
- Include one biographical reference if relevant
- End with gentle CTA (question or invitation)
- Avoid corporate jargon
''';
      case ContentType.substack:
        return '''
- Length: 800-1500 words
- Structure: Intro → 3-4 main sections → conclusion
- Tone: Thoughtful, exploratory, essay-like personal narrative
- Can be more vulnerable/reflective
- Deeper exploration of themes, multiple biographical touchpoints
- Technical depth where relevant
''';
      case ContentType.technical:
        return '''
- Length: Variable (typically 500-2000 words)
- Structure: Overview → details → examples → summary
- Tone: Clear, precise, authoritative but not sterile
- Technical accuracy paramount
- Clear explanations with examples
- Can reference development journey
- Avoid marketing speak
''';
    }
  }
}
