/// PRISM Adapter for Voice Journal
/// 
/// Thin adapter that wraps the existing PRISM PII scrubber.
/// IMPORTANT: 
/// - Only scrubbed text should ever be sent to external services (Gemini)
/// - Raw transcript stays LOCAL ONLY
/// - This module performs local PII detection and masking

import '../../../../services/lumara/pii_scrub.dart';

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
    'PRISM: ${redactionCount} redactions [${findings.join(", ")}]';
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

  /// Validate that text is properly scrubbed (contains no raw PII)
  /// 
  /// Use this as a guardrail before sending to external services
  bool isSafeToSend(String text) {
    return !PiiScrubber.containsPii(text);
  }
}

/// Security guardrails for voice journal pipeline
class VoiceJournalSecurityGuard {
  static final PrismAdapter _adapter = PrismAdapter();

  /// GUARDRAIL: Validate text before sending to Gemini
  /// 
  /// Throws [SecurityException] if text appears to contain unscrubbed PII
  static void validateBeforeGemini(String text) {
    if (_adapter.containsPII(text)) {
      throw SecurityException(
        'SECURITY VIOLATION: Attempted to send unscrubbed PII to Gemini. '
        'Text must be processed through PRISM before sending.'
      );
    }
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

