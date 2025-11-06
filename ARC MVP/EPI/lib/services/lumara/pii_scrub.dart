import '../../state/feature_flags.dart';
import 'package:my_app/echo/privacy_core/pii_detection_service.dart';
import 'package:my_app/echo/privacy_core/pii_masking_service.dart' show PIIMaskingService, MaskingOptions;
import 'package:my_app/echo/privacy_core/models/pii_types.dart' show PIIType;

/// PII scrubbing service for protecting user privacy in external API calls
/// Uses unified PIIMaskingService for consistent PII handling
class PiiScrubber {
  static final PIIDetectionService _detectionService = PIIDetectionService();
  static final PIIMaskingService _maskingService = PIIMaskingService(_detectionService);

  /// Scrub PII from text using unified masking service
  /// Uses deterministic placeholders compatible with RIVET requirements
  static String rivetScrub(String text) {
    if (!FeatureFlags.piiScrubbing) return text;
    
    // Use unified masking service with simple placeholder options
    const options = MaskingOptions(
      preserveStructure: false, // Simple placeholders for RIVET
      consistentMapping: true,
      reversibleMasking: false,
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
    return result.maskedText.trim();
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
