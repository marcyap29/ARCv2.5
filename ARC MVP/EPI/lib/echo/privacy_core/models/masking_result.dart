// Masking Result Models
// Defines the result structures for PII masking

import 'pii_types.dart';

/// Result of PII masking operation
class MaskingResult {
  final String maskedText;
  final Map<String, String> tokenMapping;
  final List<PIIItem> maskedItems;
  final Duration processingTime;
  final bool structurePreserved;

  const MaskingResult({
    required this.maskedText,
    required this.tokenMapping,
    required this.maskedItems,
    required this.processingTime,
    required this.structurePreserved,
  });

  /// Returns the count of masked PII items
  int get maskedItemCount => maskedItems.length;

  /// Returns the count of unique tokens used
  int get tokenCount => tokenMapping.length;

  /// Returns true if any PII was masked
  bool get hasMaskedPII => maskedItems.isNotEmpty;

  /// Returns the original text for a given token
  String? getOriginalText(String token) {
    return tokenMapping[token];
  }

  /// Returns the token for a given original text
  String? getToken(String originalText) {
    return tokenMapping.entries
        .where((entry) => entry.value == originalText)
        .map((entry) => entry.key)
        .firstOrNull;
  }

  @override
  String toString() => 'MaskingResult(items: $maskedItemCount, tokens: $tokenCount)';
}
