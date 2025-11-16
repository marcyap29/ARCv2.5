// lib/arc/arcform/share/lumara_share_service.dart
// LUMARA service adapter for generating Arcform sharing metadata
// Implements privacy and narrative dignity rules

import 'dart:convert';
import 'arcform_share_models.dart';
import '../../../services/llm_bridge_adapter.dart';
import '../../../services/gemini_send.dart';

/// Service for generating sharing metadata via LUMARA
/// Enforces privacy rules and narrative dignity
class LumaraShareService {
  final ArcLLM _arcLLM;

  LumaraShareService() : _arcLLM = provideArcLLM();

  /// Generate sharing metadata for an Arcform
  /// Returns an ArcformSharePayload with system-generated suggestions
  Future<ArcformSharePayload> generateShareMetadata({
    required ArcShareMode shareMode,
    required String arcformId,
    required String phase,
    required List<String> keywords,
    String? platform,
  }) async {
    try {
      // Build keywords JSON
      final keywordsJson = jsonEncode(keywords);

      // Build phase hint JSON
      final phaseHintJson = jsonEncode({
        'phase': phase,
        'arcformId': arcformId,
      });

      if (shareMode == ArcShareMode.direct) {
        return await _generateDirectShareMetadata(
          arcformId: arcformId,
          phase: phase,
          keywords: keywords,
          phaseHintJson: phaseHintJson,
          keywordsJson: keywordsJson,
        );
      } else {
        return await _generateSocialShareMetadata(
          arcformId: arcformId,
          phase: phase,
          keywords: keywords,
          platform: platform ?? 'instagram',
          phaseHintJson: phaseHintJson,
          keywordsJson: keywordsJson,
        );
      }
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

  /// Generate metadata for direct (in-app) sharing
  Future<ArcformSharePayload> _generateDirectShareMetadata({
    required String arcformId,
    required String phase,
    required List<String> keywords,
    required String phaseHintJson,
    required String keywordsJson,
  }) async {
    final userIntent = '''
Generate a short, warm message explaining this Arcform for sharing with another ARC user.
The message should:
- Briefly describe the phase and growth themes
- Use only the keywords and phase information provided
- Be encouraging and supportive
- Be 1-2 sentences maximum
- Never include personal details, journal content, or inferred attributes
''';

    try {
      final response = await _arcLLM.chat(
        userIntent: userIntent,
        entryText: '', // No journal content
        phaseHintJson: phaseHintJson,
        lastKeywordsJson: keywordsJson,
      );

      // Clean and validate response
      final systemMessage = _sanitizeMessage(response);

      return ArcformSharePayload(
        shareMode: ArcShareMode.direct,
        arcformId: arcformId,
        phase: phase,
        keywords: keywords,
        systemMessage: systemMessage,
        altText: _generateDefaultAltText(phase, keywords),
      );
    } catch (e) {
      print('LumaraShareService: Error in direct share: $e');
      return ArcformSharePayload(
        shareMode: ArcShareMode.direct,
        arcformId: arcformId,
        phase: phase,
        keywords: keywords,
        systemMessage: 'Sharing my $phase phase Arcform with you.',
        altText: _generateDefaultAltText(phase, keywords),
      );
    }
  }

  /// Generate metadata for social sharing
  Future<ArcformSharePayload> _generateSocialShareMetadata({
    required String arcformId,
    required String phase,
    required List<String> keywords,
    required String platform,
    required String phaseHintJson,
    required String keywordsJson,
  }) async {

    final userIntent = '''
Generate three caption options for sharing this Arcform on $platform:
1. Short: 1-2 sentences, engaging
2. Reflective: 2-3 sentences, thoughtful about growth
3. Technical: More detailed, suitable for professional platforms

All captions must:
- Use only the phase and keywords provided
- Be positive and growth-oriented
- Never include personal details, journal content, or inferred attributes
- Maintain narrative dignity (no self-punishing language)
- Be appropriate for $platform

Return as JSON: {"short": "...", "reflective": "...", "technical": "..."}
''';

    try {
      final response = await _arcLLM.chat(
        userIntent: userIntent,
        entryText: '', // No journal content
        phaseHintJson: phaseHintJson,
        lastKeywordsJson: keywordsJson,
      );

      // Parse JSON response
      final captions = _parseCaptions(response);

      return ArcformSharePayload(
        shareMode: ArcShareMode.social,
        arcformId: arcformId,
        phase: phase,
        keywords: keywords,
        platform: platform,
        systemCaptionShort: captions['short'] ?? '',
        systemCaptionReflective: captions['reflective'] ?? '',
        systemCaptionTechnical: captions['technical'] ?? '',
        altText: _generateDefaultAltText(phase, keywords),
        footerOptIn: true,
      );
    } catch (e) {
      print('LumaraShareService: Error in social share: $e');
      return ArcformSharePayload(
        shareMode: ArcShareMode.social,
        arcformId: arcformId,
        phase: phase,
        keywords: keywords,
        platform: platform,
        systemCaptionShort: 'Exploring my $phase phase journey.',
        altText: _generateDefaultAltText(phase, keywords),
        footerOptIn: true,
      );
    }
  }

  /// Parse captions from LUMARA response
  Map<String, String?> _parseCaptions(String response) {
    try {
      // Try to extract JSON from response
      final jsonMatch = RegExp(r'\{[^}]+\}').firstMatch(response);
      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(0);
        if (jsonStr != null) {
          final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
          return {
            'short': decoded['short'] as String?,
            'reflective': decoded['reflective'] as String?,
            'technical': decoded['technical'] as String?,
          };
        }
      }
    } catch (e) {
      print('LumaraShareService: Error parsing captions: $e');
    }

    // Fallback: use response as short caption
    return {
      'short': _sanitizeMessage(response),
      'reflective': null,
      'technical': null,
    };
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

