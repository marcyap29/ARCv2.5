import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Privacy redactor for chat message content
class ChatPrivacyRedactor {
  /// Basic PII patterns to detect and potentially redact
  static final List<RegExp> _piiPatterns = [
    RegExp(r'\b\d{3}-\d{2}-\d{4}\b'), // SSN pattern
    RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'), // Email
    RegExp(r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b'), // Phone number
    RegExp(r'\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b'), // Credit card
    RegExp(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b'), // IP address
  ];

  /// Redaction settings
  final bool enabled;
  final bool maskPii;
  final bool preserveHashes;

  const ChatPrivacyRedactor({
    this.enabled = false,
    this.maskPii = true,
    this.preserveHashes = true,
  });

  /// Process message content for privacy
  ChatPrivacyResult processContent(String content) {
    if (!enabled) {
      return ChatPrivacyResult(
        content: content,
        containsPii: false,
        originalHash: preserveHashes ? _hashContent(content) : null,
      );
    }

    bool containsPii = false;
    String processedContent = content;
    final List<String> detectedPii = [];

    // Check for PII patterns
    for (final pattern in _piiPatterns) {
      final matches = pattern.allMatches(content);
      if (matches.isNotEmpty) {
        containsPii = true;
        for (final match in matches) {
          detectedPii.add(match.group(0) ?? '');
          if (maskPii) {
            final replacement = '[REDACTED-${detectedPii.length}]';
            processedContent = processedContent.replaceFirst(match.group(0)!, replacement);
          }
        }
      }
    }

    return ChatPrivacyResult(
      content: processedContent,
      containsPii: containsPii,
      detectedPatterns: detectedPii,
      originalHash: preserveHashes ? _hashContent(content) : null,
    );
  }

  /// Generate SHA-256 hash of content
  String _hashContent(String content) {
    final bytes = utf8.encode(content);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}

/// Result of privacy processing
class ChatPrivacyResult {
  final String content;
  final bool containsPii;
  final List<String> detectedPatterns;
  final String? originalHash;

  const ChatPrivacyResult({
    required this.content,
    required this.containsPii,
    this.detectedPatterns = const [],
    this.originalHash,
  });

  /// Get privacy metadata for export
  Map<String, dynamic> getPrivacyMetadata() {
    return {
      'contains_pii': containsPii,
      'redacted_fields': detectedPatterns.isNotEmpty ? ['content'] : [],
      'detected_patterns': detectedPatterns.length,
      'original_hash': originalHash,
    };
  }
}