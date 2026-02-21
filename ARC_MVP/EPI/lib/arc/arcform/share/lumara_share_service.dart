// lib/arc/arcform/share/lumara_share_service.dart
// LUMARA service adapter for generating Arcform sharing metadata
// Implements privacy and narrative dignity rules

import 'dart:convert';
import 'arcform_share_models.dart';
import '../../../services/llm_bridge_adapter.dart';

/// Service for generating sharing metadata via LUMARA
/// Enforces privacy rules and narrative dignity
class LumaraShareService {
  final ArcLLM _arcLLM;

  LumaraShareService() : _arcLLM = _deprecatedArcLLM();
  
  // PRIORITY 2: Lumara Share Service uses local API
  // This is a secondary feature that needs Firebase Function migration
  static ArcLLM _deprecatedArcLLM() {
    throw UnimplementedError(
      'Lumara Share Service not available in Firebase-only mode. '
      'Needs migration to Firebase Functions.'
    );
  }

  /// Generate sharing metadata for an Arcform
  /// Returns an ArcformSharePayload with system-generated suggestions
  Future<ArcformSharePayload> generateShareMetadata({
    required ArcShareMode shareMode,
    required String arcformId,
    required String phase,
    required List<String> keywords,
    SocialPlatform? platform,
  }) async {
    try {
      // Build keywords JSON
      final keywordsJson = jsonEncode(keywords);

      // Build phase hint JSON
      final phaseHintJson = jsonEncode({
        'phase': phase,
        'arcformId': arcformId,
      });

      // For quiet mode, no caption needed
      if (shareMode == ArcShareMode.quiet) {
        return ArcformSharePayload(
          shareMode: shareMode,
          arcformId: arcformId,
          phase: phase,
          keywords: keywords,
          platform: platform,
          altText: _generateDefaultAltText(phase, keywords),
        );
      }

      // For reflective or signal modes, generate caption template
      return await _generateCaptionTemplate(
        arcformId: arcformId,
        phase: phase,
        keywords: keywords,
        shareMode: shareMode,
        platform: platform ?? SocialPlatform.instagramStory,
        phaseHintJson: phaseHintJson,
        keywordsJson: keywordsJson,
      );
    } catch (e) {
      print('LumaraShareService: Error generating metadata: $e');
      // Return payload with minimal metadata on error
      return ArcformSharePayload(
        shareMode: shareMode,
        arcformId: arcformId,
        phase: phase,
        keywords: keywords,
        platform: platform,
        altText: _generateDefaultAltText(phase, keywords),
      );
    }
  }

  /// Generate caption template for reflective or signal modes
  Future<ArcformSharePayload> _generateCaptionTemplate({
    required String arcformId,
    required String phase,
    required List<String> keywords,
    required ArcShareMode shareMode,
    required SocialPlatform platform,
    required String phaseHintJson,
    required String keywordsJson,
  }) async {
    final platformName = _getPlatformName(platform);
    final modeDescription = shareMode == ArcShareMode.reflective
        ? 'reflective and personal'
        : 'professional and growth-oriented';

    final userIntent = '''
Generate a caption template for sharing this Arcform on $platformName.
The caption should be $modeDescription and:
- Use only the phase and keywords provided
- Be positive and growth-oriented
- Never include personal details, journal content, or inferred attributes
- Maintain narrative dignity (no self-punishing language)
- Be 10-200 characters
- Be appropriate for $platformName

Return only the caption text, no explanation.
''';

    try {
      final response = await _arcLLM.chat(
        userIntent: userIntent,
        entryText: '', // No journal content
        phaseHintJson: phaseHintJson,
        lastKeywordsJson: keywordsJson,
      );

      // Clean and validate response
      final captionTemplate = _sanitizeMessage(response);

      return ArcformSharePayload(
        shareMode: shareMode,
        arcformId: arcformId,
        phase: phase,
        keywords: keywords,
        platform: platform,
        systemCaptionTemplate: captionTemplate,
        altText: _generateDefaultAltText(phase, keywords),
      );
    } catch (e) {
      print('LumaraShareService: Error generating caption: $e');
      // Fallback template
      final fallback = shareMode == ArcShareMode.reflective
          ? 'Entered $phase phase'
          : 'Tracking cognitive states over time revealed patterns I couldn\'t see day-to-day';
      
      return ArcformSharePayload(
        shareMode: shareMode,
        arcformId: arcformId,
        phase: phase,
        keywords: keywords,
        platform: platform,
        systemCaptionTemplate: fallback,
        altText: _generateDefaultAltText(phase, keywords),
      );
    }
  }

  String _getPlatformName(SocialPlatform platform) {
    switch (platform) {
      case SocialPlatform.instagramStory:
        return 'Instagram Story';
      case SocialPlatform.instagramFeed:
        return 'Instagram Feed';
      case SocialPlatform.linkedinFeed:
        return 'LinkedIn';
      case SocialPlatform.linkedinCarousel:
        return 'LinkedIn Carousel';
    }
  }


  /// Sanitize message to enforce privacy rules
  String _sanitizeMessage(String message) {
    // Remove any potential personal identifiers or journal content
    // This is a basic sanitization - more sophisticated rules can be added
    var sanitized = message.trim();

    // Remove common patterns that might leak journal content
    sanitized = sanitized.replaceAll(RegExp(r'\b(I wrote|I journaled|my entry|my journal)\b', caseSensitive: false), '');

    // Limit length
    if (sanitized.length > 500) {
      sanitized = sanitized.substring(0, 497) + '...';
    }

    return sanitized;
  }

  /// Generate default alt text for accessibility
  String _generateDefaultAltText(String phase, List<String> keywords) {
    final keywordStr = keywords.take(5).join(', ');
    return 'Arcform visualization showing $phase phase with themes: $keywordStr';
  }

  /// Validate that payload respects privacy rules
  /// Returns true if valid, false if privacy rules violated
  bool validatePrivacyRules(ArcformSharePayload payload) {
    // Check that no raw journal content is included
    final finalMessage = payload.getFinalMessage();
    
    // Check for patterns that might indicate journal content leakage
    final journalPatterns = [
      RegExp(r'\b(I wrote|I journaled|my entry|my journal|today I)\b', caseSensitive: false),
      RegExp(r'\b(race|religion|medical|diagnosis|political)\b', caseSensitive: false),
    ];

    for (final pattern in journalPatterns) {
      if (pattern.hasMatch(finalMessage)) {
        return false;
      }
    }

    return true;
  }

  /// Offer a kinder alternative if user text contains harsh self-language
  Future<String?> offerKinderAlternative(String userText) async {
    final harshPatterns = [
      RegExp(r'\b(failure|loser|worthless|stupid|hate myself)\b', caseSensitive: false),
    ];

    bool needsAlternative = false;
    for (final pattern in harshPatterns) {
      if (pattern.hasMatch(userText)) {
        needsAlternative = true;
        break;
      }
    }

    if (!needsAlternative) return null;

    try {
      final userIntent = '''
The user wrote: "$userText"

Offer a kinder, more compassionate alternative that:
- Maintains the same meaning but with gentler language
- Is supportive and growth-oriented
- Does not invalidate their feelings
- Is 1-2 sentences maximum

Return only the alternative text, no explanation.
''';

      final response = await _arcLLM.chat(
        userIntent: userIntent,
        entryText: '',
        phaseHintJson: null,
        lastKeywordsJson: null,
      );

      return _sanitizeMessage(response);
    } catch (e) {
      print('LumaraShareService: Error generating kinder alternative: $e');
      return null;
    }
  }
}

