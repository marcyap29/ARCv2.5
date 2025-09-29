// lib/lumara/memory/pii_redaction_service.dart
// PII redaction service implementing pii.v2 policy

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'mcp_memory_models.dart';

/// Result of PII redaction operation
class RedactionResult {
  final String redactedContent;
  final List<PrivacyRedaction> redactions;
  final bool hasRedactions;

  RedactionResult({
    required this.redactedContent,
    required this.redactions,
  }) : hasRedactions = redactions.isNotEmpty;
}

/// PII redaction patterns and replacement logic
class PiiRedactionService {
  static const String _policy = 'pii.v2';

  // PII regex patterns
  static final Map<String, RegExp> _patterns = {
    'email': RegExp(
      r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
      caseSensitive: false,
    ),
    'phone': RegExp(
      r'(\+?1[-.\s]?)?(\(?\d{3}\)?[-.\s]?)?\d{3}[-.\s]?\d{4}\b',
    ),
    'ssn': RegExp(
      r'\b\d{3}[-\s]?\d{2}[-\s]?\d{4}\b',
    ),
    'credit_card': RegExp(
      r'\b(?:\d{4}[-\s]?){3}\d{4}\b',
    ),
    'address': RegExp(
      r'\b\d+\s+[A-Za-z0-9\s,]+\s+(Street|St|Avenue|Ave|Road|Rd|Drive|Dr|Boulevard|Blvd|Lane|Ln|Court|Ct|Circle|Cir|Way|Place|Pl)\b',
      caseSensitive: false,
    ),
    'api_key': RegExp(
      r'\b(?:sk-|pk_|api[_-]?key|token)[A-Za-z0-9_-]{20,}\b',
      caseSensitive: false,
    ),
    'url_with_token': RegExp(
      r'https?://[^\s]*[?&](token|key|secret|auth)[^&\s]*',
      caseSensitive: false,
    ),
  };

  // Replacement templates
  static const Map<String, String> _replacements = {
    'email': '[EMAIL_REDACTED]',
    'phone': '[PHONE_REDACTED]',
    'ssn': '[SSN_REDACTED]',
    'credit_card': '[CARD_REDACTED]',
    'address': '[ADDRESS_REDACTED]',
    'api_key': '[SECRET_REDACTED]',
    'url_with_token': '[URL_REDACTED]',
  };

  /// Redact PII from content and return redacted content with redaction records
  static RedactionResult redactContent({
    required String content,
    required String messageId,
    String field = 'content',
  }) {
    String redactedContent = content;
    List<PrivacyRedaction> redactions = [];

    for (String piiType in _patterns.keys) {
      final pattern = _patterns[piiType]!;
      final replacement = _replacements[piiType]!;

      final matches = pattern.allMatches(redactedContent);
      for (final match in matches) {
        final originalText = match.group(0)!;
        final redactionId = _generateRedactionId();

        // Create redaction record
        final redaction = PrivacyRedaction(
          id: redactionId,
          timestamp: DateTime.now(),
          policy: _policy,
          original: _encryptOriginal(originalText),
          replacement: replacement,
          scope: RedactionScope(
            messageId: messageId,
            field: field,
          ),
        );

        redactions.add(redaction);

        // Replace in content
        redactedContent = redactedContent.replaceFirst(originalText, replacement);
      }
    }

    return RedactionResult(
      redactedContent: redactedContent,
      redactions: redactions,
    );
  }

  /// Generate unique redaction ID
  static String _generateRedactionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999).toString().padLeft(6, '0');
    return 'red:${timestamp}_$random';
  }

  /// Encrypt original content for storage (simple base64 for now)
  /// In production, use proper encryption with user-specific keys
  static String _encryptOriginal(String content) {
    // TODO: Implement proper encryption with user-specific keys
    // For now, use base64 encoding as placeholder
    return base64Encode(utf8.encode(content));
  }

  /// Decrypt original content (simple base64 for now)
  static String _decryptOriginal(String encrypted) {
    // TODO: Implement proper decryption with user-specific keys
    try {
      return utf8.decode(base64Decode(encrypted));
    } catch (e) {
      return '[DECRYPTION_FAILED]';
    }
  }

  /// Check if content contains potential PII
  static bool containsPii(String content) {
    for (final pattern in _patterns.values) {
      if (pattern.hasMatch(content)) {
        return true;
      }
    }
    return false;
  }

  /// Get PII types found in content
  static List<String> detectPiiTypes(String content) {
    List<String> foundTypes = [];

    for (String piiType in _patterns.keys) {
      if (_patterns[piiType]!.hasMatch(content)) {
        foundTypes.add(piiType);
      }
    }

    return foundTypes;
  }

  /// Restore original content from redaction (requires decryption access)
  static String restoreContent({
    required String redactedContent,
    required List<PrivacyRedaction> redactions,
  }) {
    String restoredContent = redactedContent;

    // Apply redactions in reverse order to maintain positions
    final sortedRedactions = redactions
        .where((r) => r.scope.field == 'content')
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    for (final redaction in sortedRedactions) {
      final original = _decryptOriginal(redaction.original);
      restoredContent = restoredContent.replaceFirst(
        redaction.replacement,
        original,
      );
    }

    return restoredContent;
  }

  /// Validate redaction policy compliance
  static bool validateRedactionCompliance(String content) {
    return !containsPii(content);
  }

  /// Get redaction statistics
  static Map<String, int> getRedactionStats(List<PrivacyRedaction> redactions) {
    Map<String, int> stats = {};

    for (final redaction in redactions) {
      // Extract PII type from replacement
      String piiType = 'unknown';
      for (String type in _replacements.keys) {
        if (redaction.replacement == _replacements[type]) {
          piiType = type;
          break;
        }
      }

      stats[piiType] = (stats[piiType] ?? 0) + 1;
    }

    return stats;
  }
}