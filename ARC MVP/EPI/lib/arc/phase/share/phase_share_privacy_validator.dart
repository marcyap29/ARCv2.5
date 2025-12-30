// lib/arc/phase/share/phase_share_privacy_validator.dart
// Privacy validation for phase sharing

import 'phase_share_models.dart';

/// Privacy validator for phase shares
class PhaseSharePrivacyValidator {
  /// Patterns that might indicate sensitive information
  static final List<RegExp> _sensitivePatterns = [
    // Dates in various formats
    RegExp(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b'),
    // Phone numbers
    RegExp(r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b'),
    // Email addresses
    RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'),
    // Social security numbers (US)
    RegExp(r'\b\d{3}-\d{2}-\d{4}\b'),
    // Credit card numbers
    RegExp(r'\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b'),
  ];

  /// Validate that share data doesn't contain sensitive information
  static ValidationResult validateShareData(PhaseShare share) {
    final errors = <String>[];

    // Validate caption doesn't contain sensitive patterns
    if (share.userCaption.isNotEmpty) {
      for (final pattern in _sensitivePatterns) {
        if (pattern.hasMatch(share.userCaption)) {
          errors.add('Caption may contain sensitive information (dates, emails, phone numbers, etc.)');
          break;
        }
      }

      // Check for very specific personal details
      if (_containsPersonalDetails(share.userCaption)) {
        errors.add('Caption may contain personal details that should not be shared');
      }
    }

    // Validate caption length
    if (share.userCaption.length < 10) {
      errors.add('Caption must be at least 10 characters');
    }

    if (share.userCaption.length > 500) {
      errors.add('Caption must be less than 500 characters');
    }

    // Ensure only allowed data is included
    if (share.timelineData.any((phase) => phase.start.isBefore(
      DateTime.now().subtract(const Duration(days: 180)),
    ))) {
      // Timeline should only show last 6 months
      errors.add('Timeline contains data older than 6 months');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// Check if text contains personal details
  static bool _containsPersonalDetails(String text) {
    final lowerText = text.toLowerCase();
    
    // Common personal detail indicators
    final personalIndicators = [
      'my therapist',
      'my doctor',
      'my medication',
      'my diagnosis',
      'hospital',
      'emergency room',
      'suicide',
      'self-harm',
      'abuse',
      'trauma',
      'ptsd',
    ];

    return personalIndicators.any((indicator) => lowerText.contains(indicator));
  }
}

/// Validation result
class ValidationResult {
  final bool isValid;
  final List<String> errors;

  ValidationResult({
    required this.isValid,
    required this.errors,
  });

  String get errorMessage => errors.join('\n');
}

