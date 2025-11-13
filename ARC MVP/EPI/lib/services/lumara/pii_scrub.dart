import '../../state/feature_flags.dart';
import 'package:my_app/echo/privacy_core/pii_detection_service.dart';
import 'package:my_app/echo/privacy_core/pii_masking_service.dart' show PIIMaskingService, MaskingOptions;
import 'package:my_app/echo/privacy_core/models/pii_types.dart' show PIIType;

/// Result of PII scrubbing with reversible mapping
class ScrubbingResult {
  final String scrubbedText;
  final Map<String, String> reversibleMap; // masked token -> original value
  final List<String> findings; // List of PII types found

  const ScrubbingResult({
    required this.scrubbedText,
    required this.reversibleMap,
    required this.findings,
  });
}

/// PII scrubbing service for protecting user privacy in external API calls
/// Uses unified PIIMaskingService for consistent PII handling
class PiiScrubber {
  static final PIIDetectionService _detectionService = PIIDetectionService();
  static final PIIMaskingService _maskingService = PIIMaskingService(_detectionService);

  /// Scrub PII from text using unified masking service
  /// Uses deterministic placeholders compatible with RIVET requirements
  /// Returns only the scrubbed text (backward compatible)
  static String rivetScrub(String text) {
    final result = rivetScrubWithMapping(text);
    return result.scrubbedText;
  }

  /// Scrub PII from text with reversible mapping for restoration
  /// Returns ScrubbingResult with scrubbed text and mapping for restoration
  static ScrubbingResult rivetScrubWithMapping(String text) {
    if (!FeatureFlags.piiScrubbing) {
      return ScrubbingResult(
        scrubbedText: text,
        reversibleMap: {},
        findings: [],
      );
    }
    
    // Use unified masking service with reversible masking enabled
    const options = MaskingOptions(
      preserveStructure: false, // Simple placeholders for RIVET
      consistentMapping: true,
      reversibleMasking: true, // ENABLE reversible masking for restoration
      hashEmails: false,
      customTokens: {
        // Use simple placeholders matching original behavior
        PIIType.email: '[EMAIL]',
        PIIType.phone: '[PHONE]',
        PIIType.ssn: '[SSN]',
        PIIType.creditCard: '[CARD]',
        PIIType.address: '[ADDRESS]',
        PIIType.name: '[NAME]',
      },
    );
    
    final result = _maskingService.maskText(text, options: options);
    
    // Build reversible map (masked token -> original value)
    // The maskingMap is original -> masked, we need masked -> original
    final reversibleMap = <String, String>{};
    final findings = <String>[];
    
    for (final entry in result.maskingMap.entries) {
      final original = entry.key;
      final masked = entry.value;
      reversibleMap[masked] = original;
      
      // Extract PII type from findings
      for (final match in result.processedMatches) {
        if (text.substring(match.startIndex, match.endIndex) == original) {
          findings.add('${match.type.toString().split('.').last}: $original');
          break;
        }
      }
    }
    
    return ScrubbingResult(
      scrubbedText: result.maskedText.trim(),
      reversibleMap: reversibleMap,
      findings: findings,
    );
  }

  /// Restore original PII from scrubbed text using reversible map
  /// This restores placeholders back to original values
  static String restore(String scrubbedText, Map<String, String> reversibleMap) {
    if (reversibleMap.isEmpty) return scrubbedText;
    
    String restored = scrubbedText;
    
    // Restore in reverse order of key length to handle nested replacements
    final sortedKeys = reversibleMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    
    for (final maskedToken in sortedKeys) {
      final original = reversibleMap[maskedToken]!;
      restored = restored.replaceAll(maskedToken, original);
    }
    
    return restored;
  }

  /// Check if text contains potential PII using unified detection service
  static bool containsPii(String text) {
    final result = _detectionService.detectPII(text);
    return result.hasPII;
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
