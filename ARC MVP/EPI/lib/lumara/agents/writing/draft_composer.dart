import 'package:my_app/lumara/agents/services/timeline_context_service.dart';
import 'package:my_app/lumara/agents/writing/writing_models.dart';
import 'package:my_app/lumara/agents/writing/writing_prompts.dart';

/// Callback type for LLM generation (inject Groq/Gemini from app layer).
typedef WritingLlmGenerate = Future<String> Function({
  required String systemPrompt,
  required String userPrompt,
  int? maxTokens,
});

/// Generates draft content using timeline context, voice profile, theme context, and tone guidance.
/// Uses the enhanced system prompt (single longitudinal anchor, internal process, footer D).
class DraftComposer {
  final WritingLlmGenerate _generate;

  DraftComposer({required WritingLlmGenerate generate}) : _generate = generate;

  /// Compose a draft from the user prompt and context.
  /// [timelineContext] supplies timeline summary, recent entries, themes, patterns, and phase for the prompt.
  /// [systemPromptPrefix] optional LUMARA Agent OS + user context (from settings).
  /// [draftsAndArchiveSnippet] optional reference from Agents Drafts and Archive (swap file for writing).
  Future<Draft> composeDraft({
    required String prompt,
    required VoiceProfile voice,
    required ThemeContext themes,
    required ToneGuidance tone,
    required ContentType type,
    required WritingTimelineContext timelineContext,
    String? systemPromptPrefix,
    String? draftsAndArchiveSnippet,
    String? customContentTypeDescription,
  }) async {
    final systemPrompt = _buildSystemPromptFromTemplate(
      prompt: prompt,
      voice: voice,
      tone: tone,
      type: type,
      timelineContext: timelineContext,
      systemPromptPrefix: systemPromptPrefix,
      customContentTypeDescription: customContentTypeDescription,
    );
    int maxTokens = 800;
    switch (type) {
      case ContentType.linkedIn:
        maxTokens = 800;
        break;
      case ContentType.substack:
        maxTokens = 2500;
        break;
      case ContentType.technical:
        maxTokens = 2000;
        break;
      case ContentType.custom:
        maxTokens = 2000;
        break;
    }
    final userPrompt = (draftsAndArchiveSnippet != null && draftsAndArchiveSnippet.trim().isNotEmpty)
        ? '$prompt\n\n--- Reference (Drafts & Archive) ---\n$draftsAndArchiveSnippet'
        : prompt;
    final rawContent = await _generate(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      maxTokens: maxTokens,
    );
    final parsed = _parseResponse(rawContent.trim(), tone.phase);
    return Draft(
      content: parsed.body,
      metadata: DraftMetadata(
        phase: tone.phase,
        wordCount: parsed.wordCount,
        generatedAt: DateTime.now(),
        contextSignalsUsed: parsed.contextSignalsUsed,
        voiceMatchEstimate: parsed.voiceMatchEstimate,
        themeMatchEstimate: parsed.themeMatchEstimate,
      ),
    );
  }

  String _buildSystemPromptFromTemplate({
    required String prompt,
    required VoiceProfile voice,
    required ToneGuidance tone,
    required ContentType type,
    required WritingTimelineContext timelineContext,
    String? systemPromptPrefix,
    String? customContentTypeDescription,
  }) {
    final voicePatterns = _formatVoicePatterns(voice);
    final syntaxPatterns = voice.sentenceLength.description;
    final vocabulary = voice.signaturePhrases.isEmpty
        ? voice.vocabularyLevel.description
        : '${voice.vocabularyLevel.description}; signature phrases: ${voice.signaturePhrases.join(", ")}';
    final toneAnalysis = '${tone.emotionalTone.description}. '
        'Ambition ${tone.ambitionLevel.toStringAsFixed(1)}/10, '
        'Future orientation ${tone.futureOrientation.toStringAsFixed(2)}, '
        'Vulnerability ${tone.vulnerability.toStringAsFixed(2)}. '
        'CTA: ${tone.callToAction.description}.';

    final platformGuidance = _getContentTypeGuidance(type, customContentTypeDescription);
    final contentTypeLabel = _contentTypeLabel(type, customContentTypeDescription);
    final platformLabel = _platformLabel(type, customContentTypeDescription);

    final avgSentenceLength = voice.sentenceLength.averageLength > 0
        ? '${voice.sentenceLength.averageLength.toStringAsFixed(0)} words'
        : 'see voice profile above';
    const avgParagraphLength = "match the user's typical paragraph length from the voice profile";
    const readingLevel = "match the user's natural complexity (see vocabulary and syntax above)";
    const firstPersonRatio = "match the user's first-person usage from the voice profile";

    final privateCalibration = 'Current phase for tone: ${timelineContext.currentPhase}. '
        '${timelineContext.phaseDescription}. '
        'Dominant themes (relevance only): ${timelineContext.dominantThemes}.';
    const publicContextWriting = 'Product documentation: [None provided]. '
        'Architecture specifications: [None]. Marketing positioning: [None]. '
        'Approved public narratives: [None]. Use the user request and voice calibration above to generate public-facing content only.';

    final agentPrompt = kWritingAgentSystemPromptTemplate
        .replaceAll('{{PRIVATE_CONTEXT_CALIBRATION}}', privateCalibration)
        .replaceAll('{{PUBLIC_CONTEXT_WRITING}}', publicContextWriting)
        .replaceAll('{{TIMELINE_SUMMARY}}', timelineContext.timelineSummary)
        .replaceAll('{{RECENT_ENTRIES}}', timelineContext.recentEntries)
        .replaceAll('{{DOMINANT_THEMES}}', timelineContext.dominantThemes)
        .replaceAll('{{PATTERNS}}', timelineContext.patterns)
        .replaceAll('{{CURRENT_PHASE}}', timelineContext.currentPhase)
        .replaceAll('{{PHASE_DESCRIPTION}}', timelineContext.phaseDescription)
        .replaceAll('{{VOICE_PATTERNS}}', voicePatterns)
        .replaceAll('{{SYNTAX_PATTERNS}}', syntaxPatterns)
        .replaceAll('{{VOCABULARY}}', vocabulary)
        .replaceAll('{{TONE_ANALYSIS}}', toneAnalysis)
        .replaceAll('{{PLATFORM_GUIDANCE}}', platformGuidance)
        .replaceAll('{{CONTENT_TYPE}}', contentTypeLabel)
        .replaceAll('{{USER_PROMPT}}', prompt)
        .replaceAll('{{PLATFORM}}', platformLabel)
        .replaceAll('{{AVG_SENTENCE_LENGTH}}', avgSentenceLength)
        .replaceAll('{{AVG_PARAGRAPH_LENGTH}}', avgParagraphLength)
        .replaceAll('{{READING_LEVEL}}', readingLevel)
        .replaceAll('{{FIRST_PERSON_RATIO}}', firstPersonRatio);
    final prefix = systemPromptPrefix?.trim();
    return (prefix != null && prefix.isNotEmpty ? '$prefix\n' : '') + agentPrompt;
  }

  String _formatVoicePatterns(VoiceProfile voice) {
    final parts = <String>[
      'Sentence structure: ${voice.sentenceLength.description}',
      'Vocabulary: ${voice.vocabularyLevel.description}',
      'Punctuation: ${voice.punctuationStyle.description}',
      'Formality: ${voice.formalityScore.toStringAsFixed(2)} (0=casual, 1=formal)',
    ];
    if (voice.openingPatterns.isNotEmpty) {
      parts.add('Typical openings: ${voice.openingPatterns.join(" | ")}');
    }
    return parts.join('\n');
  }

  String _contentTypeLabel(ContentType type, [String? customDescription]) {
    switch (type) {
      case ContentType.linkedIn:
        return 'LinkedIn';
      case ContentType.substack:
        return 'Substack';
      case ContentType.technical:
        return 'Technical';
      case ContentType.custom:
        return customDescription?.trim().isNotEmpty == true
            ? customDescription!
            : 'Custom (user-specified)';
    }
  }

  String _platformLabel(ContentType type, [String? customDescription]) {
    switch (type) {
      case ContentType.linkedIn:
        return 'LinkedIn';
      case ContentType.substack:
        return 'Substack';
      case ContentType.technical:
        return 'Technical docs';
      case ContentType.custom:
        return customDescription?.trim().isNotEmpty == true
            ? customDescription!
            : 'User-specified format';
    }
  }

  String _getContentTypeGuidance(ContentType type, [String? customDescription]) {
    switch (type) {
      case ContentType.linkedIn:
        return 'Length: 200-400 words. Structure: Hook → insight/story → takeaway. '
            'Tone: Professional but personal. Opening line must grab attention. '
            'End with gentle CTA (question or invitation). Avoid corporate jargon.';
      case ContentType.substack:
        return 'Length: 800-1500 words. Structure: Intro → 3-4 main sections → conclusion. '
            'Tone: Thoughtful, exploratory, essay-like personal narrative. '
            'Can be more vulnerable/reflective. Technical depth where relevant.';
      case ContentType.technical:
        return 'Length: typically 500-2000 words. Structure: Overview → details → examples → summary. '
            'Tone: Clear, precise, authoritative but not sterile. '
            'Technical accuracy paramount. Clear explanations with examples. Avoid marketing speak.';
      case ContentType.custom:
        return customDescription?.trim().isNotEmpty == true
            ? 'User-specified format and requirements: $customDescription'
            : 'Follow the user\'s prompt for format, length, and tone.';
    }
  }

  static final RegExp _footerMetadata = RegExp(
    r'Voice Match Estimate:\s*(\d+)%[\s\S]*?Theme Match Estimate:\s*(\d+)%',
    dotAll: true,
  );

  _ParsedResponse _parseResponse(String raw, String phase) {
    // Split on first "---" that starts the "Context signals used" block.
    // We want: body = everything before that; then parse the two blocks.
    const contextSignalsMarker = '---\nContext signals used:';

    String body = raw;
    String? contextSignalsUsed;
    double? voiceMatchEstimate;
    double? themeMatchEstimate;

    final contextIdx = raw.indexOf(contextSignalsMarker);
    if (contextIdx >= 0) {
      body = raw.substring(0, contextIdx).trim();
      final afterContext = raw.substring(contextIdx + contextSignalsMarker.length);
      final endContext = afterContext.indexOf('---');
      if (endContext >= 0) {
        contextSignalsUsed = 'Context signals used:'
            + afterContext.substring(0, endContext).trim();
      }
      final metaMatch = _footerMetadata.firstMatch(raw);
      if (metaMatch != null) {
        voiceMatchEstimate = double.tryParse(metaMatch.group(1) ?? '');
        themeMatchEstimate = double.tryParse(metaMatch.group(2) ?? '');
      }
    } else {
      // Try to strip any trailing --- ... --- block (legacy single block)
      final lastDash = raw.lastIndexOf('---');
      if (lastDash > raw.length ~/ 2) {
        final before = raw.substring(0, lastDash).trim();
        final possibleMeta = raw.substring(lastDash);
        if (possibleMeta.contains('Voice Match') ||
            possibleMeta.contains('Theme Match')) {
          body = before;
          final metaMatch = _footerMetadata.firstMatch(raw);
          if (metaMatch != null) {
            voiceMatchEstimate = double.tryParse(metaMatch.group(1) ?? '');
            themeMatchEstimate = double.tryParse(metaMatch.group(2) ?? '');
          }
        }
      }
    }

    final wordCount =
        body.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return _ParsedResponse(
      body: body,
      wordCount: wordCount,
      contextSignalsUsed: contextSignalsUsed,
      voiceMatchEstimate: voiceMatchEstimate,
      themeMatchEstimate: themeMatchEstimate,
    );
  }
}

class _ParsedResponse {
  final String body;
  final int wordCount;
  final String? contextSignalsUsed;
  final double? voiceMatchEstimate;
  final double? themeMatchEstimate;

  _ParsedResponse({
    required this.body,
    required this.wordCount,
    this.contextSignalsUsed,
    this.voiceMatchEstimate,
    this.themeMatchEstimate,
  });
}
