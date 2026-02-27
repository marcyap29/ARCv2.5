/// PRISM Adapter for Voice Journal
/// 
/// Thin adapter that wraps the existing PRISM PII scrubber.
/// IMPORTANT: 
/// - Only scrubbed text should ever be sent to external services (Gemini)
/// - Raw transcript stays LOCAL ONLY
/// - This module performs local PII detection and masking
/// - Now includes correlation-resistant transformation layer
library;

import '../../../../services/lumara/pii_scrub.dart';
import 'correlation_resistant_transformer.dart';

/// Result of PRISM scrubbing with metadata
class PrismResult {
  /// The scrubbed (safe) text with PII replaced by tokens
  final String scrubbedText;
  
  /// Map of masked tokens to original values (for local restoration only)
  /// SECURITY: This map must NEVER leave the device
  final Map<String, String> reversibleMap;
  
  /// List of PII types that were found and redacted
  final List<String> findings;
  
  /// Number of PII items redacted
  int get redactionCount => reversibleMap.length;
  
  /// Whether any PII was found
  bool get hadPII => reversibleMap.isNotEmpty;

  const PrismResult({
    required this.scrubbedText,
    required this.reversibleMap,
    required this.findings,
  });

  @override
  String toString() => 
    'PRISM: $redactionCount redactions [${findings.join(", ")}]';
}

/// PRISM Adapter - wraps existing PII scrubber for voice pipeline
/// 
/// Usage:
/// ```dart
/// final adapter = PrismAdapter();
/// final result = adapter.scrub(rawTranscript);
/// // Send only result.scrubbedText to Gemini
/// // Keep result.reversibleMap local for restoration
/// ```
class PrismAdapter {
  /// Scrub PII from text
  /// 
  /// Returns a [PrismResult] containing:
  /// - scrubbedText: Safe to send to external services
  /// - reversibleMap: LOCAL ONLY - for restoring original values
  /// - findings: List of PII types detected
  /// 
  /// SECURITY INVARIANT: Only scrubbedText should ever leave the device
  PrismResult scrub(String rawText) {
    if (rawText.trim().isEmpty) {
      return const PrismResult(
        scrubbedText: '',
        reversibleMap: {},
        findings: [],
      );
    }

    // Use existing PiiScrubber service
    final result = PiiScrubber.rivetScrubWithMapping(rawText);
    
    return PrismResult(
      scrubbedText: result.scrubbedText,
      reversibleMap: result.reversibleMap,
      findings: result.findings,
    );
  }

  /// Restore original PII from scrubbed text
  /// 
  /// Use this to restore PII in LUMARA's response after it comes back
  /// from Gemini, so the user sees the original names/data.
  /// 
  /// SECURITY: This should only be used for LOCAL display
  String restore(String scrubbedText, Map<String, String> reversibleMap) {
    if (reversibleMap.isEmpty) return scrubbedText;
    return PiiScrubber.restore(scrubbedText, reversibleMap);
  }

  /// Check if text contains potential PII
  /// 
  /// Quick check without full scrubbing - useful for validation
  bool containsPII(String text) {
    return PiiScrubber.containsPii(text);
  }

  // ─────────────────────────────────────────────────────────────────────
  // PRISM CONTEXT COMPRESSION
  //
  // Extracts key sentences from a journal entry and scrubs PII from the
  // result.  The AI receives compact, anonymised context that preserves
  // emotional + relational meaning while protecting identity.  PRISM uses
  // token replacement (not deletion), so "John at Disneyland" becomes
  // "[PERSON_1] at [PLACE_1]" — full context, zero identification.
  // ─────────────────────────────────────────────────────────────────────

  /// Extract the most contextually important sentences from a journal entry,
  /// then scrub PII from the result.
  ///
  /// [content]    Raw journal entry text.
  /// [maxChars]   Hard cap on the output (default 400 chars).
  /// [maxSentences] Maximum number of sentences to keep (default 4).
  ///
  /// Returns a [PrismResult] whose [scrubbedText] is safe to send to cloud
  /// APIs, and whose [reversibleMap] stays on-device for response restoration.
  PrismResult compressAndScrub(
    String content, {
    int maxChars = 400,
    int maxSentences = 4,
  }) {
    final excerpt = _extractKeyPoints(content, maxChars: maxChars, maxSentences: maxSentences);
    return scrub(excerpt);
  }

  /// Extract key points without scrubbing (useful when the caller applies
  /// a single PRISM pass over the whole payload later).
  static String extractKeyPoints(
    String content, {
    int maxChars = 400,
    int maxSentences = 4,
  }) {
    return _extractKeyPoints(content, maxChars: maxChars, maxSentences: maxSentences);
  }

  /// Internal sentence-extraction heuristic.
  ///
  /// Priority order:
  ///   1. First sentence (sets the scene / main topic)
  ///   2. Any sentence containing high-signal emotional or decision words
  ///   3. Last non-empty sentence (often a resolution or forward-looking thought)
  ///
  /// Sentences are de-duplicated and the result is hard-capped at [maxChars].
  static String _extractKeyPoints(
    String content, {
    required int maxChars,
    required int maxSentences,
  }) {
    if (content.trim().isEmpty) return '';

    // Split into sentences on common terminators.
    final rawSentences = content
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.length > 15) // skip fragments
        .toList();

    if (rawSentences.isEmpty) {
      // No sentence boundaries — take the first maxChars chars.
      return content.length <= maxChars
          ? content
          : '${content.substring(0, maxChars - 3)}...';
    }

    // High-signal emotional / decision keywords.
    const signals = [
      'feel', 'felt', 'feeling', 'emotion', 'scared', 'afraid', 'excited',
      'happy', 'sad', 'anxious', 'overwhelm', 'relief', 'proud', 'frustrated',
      'confus', 'worried', 'grateful', 'disappoint', 'hopeful', 'nervous',
      'decided', 'decision', 'realized', 'realise', 'noticed', 'learned',
      'thought', 'wonder', 'struggling', 'difficult', 'important', 'need to',
      'want to', 'going to', 'plan', 'goal', 'hope', 'wish',
    ];

    bool isHighSignal(String s) {
      final lower = s.toLowerCase();
      return signals.any((kw) => lower.contains(kw));
    }

    final selected = <String>[];
    final seen = <String>{};

    void add(String s) {
      if (selected.length >= maxSentences) return;
      if (seen.contains(s)) return;
      selected.add(s);
      seen.add(s);
    }

    // 1. Always include the first sentence.
    add(rawSentences.first);

    // 2. High-signal sentences (skip if already added as first/last).
    for (final s in rawSentences.skip(1).take(rawSentences.length - 1)) {
      if (isHighSignal(s)) add(s);
      if (selected.length >= maxSentences - 1) break;
    }

    // 3. Last sentence (if not already included).
    if (rawSentences.length > 1) add(rawSentences.last);

    // Join and cap at maxChars.
    var result = selected.join(' ');
    if (result.length > maxChars) {
      result = '${result.substring(0, maxChars - 3)}...';
    }
    return result;
  }

  /// Validate that text is properly scrubbed (contains no raw PII)
  /// 
  /// Use this as a guardrail before sending to external services
  bool isSafeToSend(String text) {
    return !PiiScrubber.containsPii(text);
  }

  /// Transform PRISM-scrubbed text to correlation-resistant payload
  /// 
  /// This adds an additional layer of protection by:
  /// - Replacing PRISM tokens with rotating aliases
  /// - Creating structured JSON abstraction instead of verbatim text
  /// - Implementing session-based rotation to prevent cross-call linkage
  /// 
  /// Returns both local audit block and cloud payload
  Future<TransformationResult> transformToCorrelationResistant({
    required String prismScrubbedText,
    required String intent,
    required PrismResult prismResult,
    RotationWindow rotationWindow = RotationWindow.session,
  }) async {
    final transformer = CorrelationResistantTransformer(
      rotationWindow: rotationWindow,
      prism: this,
    );
    
    return await transformer.transform(
      prismScrubbedText: prismScrubbedText,
      intent: intent,
      prismResult: prismResult,
    );
  }
}

/// Security guardrails for voice journal pipeline
class VoiceJournalSecurityGuard {
  static final PrismAdapter _adapter = PrismAdapter();
  static CorrelationResistantTransformer? _transformer;

  /// GUARDRAIL: Validate text before sending to Gemini
  /// 
  /// Throws [SecurityException] if text appears to contain unscrubbed PII
  /// 
  /// Enhanced validation: checks both raw PII and PRISM token format
  static void validateBeforeGemini(String text) {
    // Check 1: No raw PII
    if (_adapter.containsPII(text)) {
      throw const SecurityException(
        'SECURITY VIOLATION: Attempted to send unscrubbed PII to Gemini. '
        'Text must be processed through PRISM before sending.'
      );
    }
    
    // Check 2: If using transformer, validate alias format
    if (_transformer != null) {
      if (!_transformer!.isSafeToSendEnhanced(text)) {
        throw const SecurityException(
          'SECURITY VIOLATION: Text contains PRISM tokens that should have been '
          'transformed to rotating aliases. Use transformToCorrelationResistant() first.'
        );
      }
    }
  }

  /// Set transformer for enhanced validation
  static void setTransformer(CorrelationResistantTransformer transformer) {
    _transformer = transformer;
  }

  /// GUARDRAIL: Ensure raw transcript is never logged
  /// 
  /// Returns a safe version of the text for logging purposes
  static String safeForLogging(String text) {
    final result = _adapter.scrub(text);
    return result.scrubbedText;
  }

  /// GUARDRAIL: Create audit log entry (without sensitive data)
  static Map<String, dynamic> createAuditEntry({
    required String operation,
    required bool hadPII,
    required int redactionCount,
    required List<String> redactionTypes,
  }) {
    return {
      'operation': operation,
      'timestamp': DateTime.now().toIso8601String(),
      'had_pii': hadPII,
      'redaction_count': redactionCount,
      'redaction_types': redactionTypes,
      // NEVER include actual PII or raw text in audit logs
    };
  }
}

/// Exception for security violations
class SecurityException implements Exception {
  final String message;
  const SecurityException(this.message);
  
  @override
  String toString() => 'SecurityException: $message';
}

