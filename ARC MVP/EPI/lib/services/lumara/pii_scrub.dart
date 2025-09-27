import '../../state/feature_flags.dart';

/// PII scrubbing service for protecting user privacy in external API calls
class PiiScrubber {
  static final List<RegExp> _patterns = [
    // Email addresses
    RegExp(r'\b[\w\.-]+@[\w\.-]+\.\w+\b'),
    // Phone numbers (various formats)
    RegExp(r'\+?\d[\d \-\(\)]{7,}\d'),
    // Social Security Numbers (US format)
    RegExp(r'\b\d{3}-\d{2}-\d{4}\b'),
    // Credit card numbers (basic pattern)
    RegExp(r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b'),
    // Addresses (basic street address pattern)
    RegExp(r'\b\d+\s+[A-Za-z\s]+(?:Street|St|Avenue|Ave|Road|Rd|Drive|Dr|Lane|Ln|Boulevard|Blvd)\b'),
    // Names (basic pattern - very conservative)
    RegExp(r'\b[A-Z][a-z]+\s+[A-Z][a-z]+\b'),
  ];

  /// Scrub PII from text using deterministic placeholders
  static String rivetScrub(String text) {
    if (!FeatureFlags.piiScrubbing) return text;
    
    var scrubbed = text;
    
    for (int i = 0; i < _patterns.length; i++) {
      final pattern = _patterns[i];
      final placeholder = _getPlaceholder(i);
      scrubbed = scrubbed.replaceAll(pattern, placeholder);
    }
    
    return scrubbed.trim();
  }

  /// Get deterministic placeholder for pattern index
  static String _getPlaceholder(int patternIndex) {
    const placeholders = [
      '[EMAIL]',
      '[PHONE]',
      '[SSN]',
      '[CARD]',
      '[ADDRESS]',
      '[NAME]',
    ];
    return placeholders[patternIndex % placeholders.length];
  }

  /// Check if text contains potential PII
  static bool containsPii(String text) {
    return _patterns.any((pattern) => pattern.hasMatch(text));
  }

  /// Get metadata for external API calls
  static Map<String, dynamic> getApiMetadata() {
    return {
      'origin': 'ARC-JOURNAL',
      'mode': 'inline',
      'pii': 'scrubbed',
      'user_opt_in': true,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }
}
