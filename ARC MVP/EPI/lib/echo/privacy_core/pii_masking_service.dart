// lib/services/privacy/pii_masking_service.dart
// PII Masking Service - F2 Implementation
// REQ-2.1 through REQ-2.5

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'pii_detection_service.dart';
import 'models/pii_types.dart';

class MaskingResult {
  final String maskedText;
  final Map<String, String> maskingMap; // original -> masked token
  final List<PIIMatch> processedMatches;
  final bool hasReversibleMasking;

  MaskingResult({
    required this.maskedText,
    required this.maskingMap,
    required this.processedMatches,
    required this.hasReversibleMasking,
  });

  @override
  String toString() {
    return 'MaskingResult(masked: "${maskedText.substring(0, maskedText.length.clamp(0, 50))}...", mappings: ${maskingMap.length})';
  }
}

class MaskingOptions {
  final bool preserveStructure;      // Maintain text length and formatting
  final bool consistentMapping;      // Same PII -> same token within session
  final bool reversibleMasking;      // Allow local unmasking
  final bool hashEmails;             // Generate email hashes
  final Map<PIIType, String> customTokens; // Custom token patterns

  const MaskingOptions({
    this.preserveStructure = true,
    this.consistentMapping = true,
    this.reversibleMasking = false,
    this.hashEmails = true,
    this.customTokens = const {},
  });
}

/// PII Masking Service implementing REQ-2.1 through REQ-2.5
class PIIMaskingService {
  final PIIDetectionService _detectionService;
  final Map<String, String> _sessionMappings = {}; // For consistent masking (REQ-2.2)
  final Map<String, String> _reverseMappings = {}; // For reversible masking (REQ-2.5)

  // Counters for generating unique tokens
  final Map<String, int> _tokenCounters = {};

  PIIMaskingService(this._detectionService);

  /// Main masking method (REQ-2.1: Replace detected PII with semantic tokens)
  MaskingResult maskText(String text, {MaskingOptions options = const MaskingOptions()}) {
    // Step 1: Detect PII in the text
    final detectionResult = _detectionService.detectPII(text);

    if (!detectionResult.hasPII) {
      return MaskingResult(
        maskedText: text,
        maskingMap: {},
        processedMatches: [],
        hasReversibleMasking: false,
      );
    }

    // Step 2: Sort matches by position (reverse order for replacement)
    final sortedMatches = [...detectionResult.matches]
      ..sort((a, b) => b.startIndex.compareTo(a.startIndex));

    String maskedText = text;
    final maskingMap = <String, String>{};
    final processedMatches = <PIIMatch>[];

    // Step 3: Process each match and apply masking
    for (final match in sortedMatches) {
      final originalValue = text.substring(match.startIndex, match.endIndex);
      final maskedToken = _generateMaskToken(match, originalValue, options);

      // Apply the mask to the text
      maskedText = maskedText.replaceRange(
        match.startIndex,
        match.endIndex,
        maskedToken,
      );

      // Store mapping for consistency and potential reversal
      maskingMap[originalValue] = maskedToken;
      processedMatches.add(match);

      // Store for session consistency (REQ-2.2)
      if (options.consistentMapping) {
        _sessionMappings[originalValue] = maskedToken;
      }

      // Store for reversible masking (REQ-2.5)
      if (options.reversibleMasking) {
        _reverseMappings[maskedToken] = originalValue;
      }
    }

    return MaskingResult(
      maskedText: maskedText,
      maskingMap: maskingMap,
      processedMatches: processedMatches,
      hasReversibleMasking: options.reversibleMasking,
    );
  }

  /// Generate appropriate mask token for PII type (REQ-2.1)
  String _generateMaskToken(PIIMatch match, String originalValue, MaskingOptions options) {
    // Check for existing session mapping first (REQ-2.2)
    if (options.consistentMapping && _sessionMappings.containsKey(originalValue)) {
      return _sessionMappings[originalValue]!;
    }

    // Check for custom token patterns
    if (options.customTokens.containsKey(match.type)) {
      return _applyCustomToken(options.customTokens[match.type]!, match, originalValue);
    }

    // Generate standard semantic tokens based on PII type
    switch (match.type) {
      case PIIType.name:
        return _generateNameToken(originalValue, options);
      case PIIType.email:
        return _generateEmailToken(originalValue, options);
      case PIIType.phone:
        return _generatePhoneToken(originalValue, options);
      case PIIType.address:
        return _generateAddressToken(originalValue, options);
      case PIIType.ssn:
        return _generateSSNToken(originalValue, options);
      case PIIType.creditCard:
        return _generateCreditCardToken(originalValue, options);
      case PIIType.ipAddress:
        return _generateIPToken(originalValue, options);
      case PIIType.url:
        return _generateURLToken(originalValue, options);
      case PIIType.dateOfBirth:
        return _generateDateToken(originalValue, options);
      case PIIType.macAddress:
      case PIIType.licensePlate:
      case PIIType.passport:
      case PIIType.driverLicense:
      case PIIType.bankAccount:
      case PIIType.routingNumber:
      case PIIType.medicalRecord:
      case PIIType.healthInsurance:
      case PIIType.biometric:
      case PIIType.other:
        return '[SECRET]';
    }
  }

  /// Generate name tokens (REQ-2.1, REQ-2.2)
  String _generateNameToken(String originalValue, MaskingOptions options) {
    final words = originalValue.split(' ');

    if (words.length == 1) {
      // Single name
      return '[PERSON_${_getNextToken('person')}]';
    } else {
      // Full name - preserve structure if requested
      if (options.preserveStructure) {
        return words.map((word) => '[PERSON_${_getNextToken('person')}]').join(' ');
      } else {
        return '[PERSON_${_getNextToken('person')}]';
      }
    }
  }

  /// Generate email tokens with hash (REQ-2.4)
  String _generateEmailToken(String originalValue, MaskingOptions options) {
    if (options.hashEmails) {
      final hash = _generateHash(originalValue);
      return '[EMAIL_SHA256:$hash]';
    } else {
      return '[EMAIL]';
    }
  }

  /// Generate phone tokens
  String _generatePhoneToken(String originalValue, MaskingOptions options) {
    if (options.preserveStructure) {
      // Preserve format structure
      final normalized = originalValue.replaceAll(RegExp(r'[^\d+\(\)\-\.\s]'), '');
      return normalized.replaceAll(RegExp(r'\d'), 'X');
    } else {
      return '[PHONE]';
    }
  }

  /// Generate address tokens
  String _generateAddressToken(String originalValue, MaskingOptions options) {
    if (options.preserveStructure) {
      // Replace numbers with X, keep structure
      return originalValue.replaceAll(RegExp(r'\d'), 'X');
    } else {
      return '[ADDRESS]';
    }
  }

  /// Generate SSN tokens
  String _generateSSNToken(String originalValue, MaskingOptions options) {
    if (options.preserveStructure) {
      return 'XXX-XX-${originalValue.substring(originalValue.length - 4)}'; // Show last 4
    } else {
      return '[SSN]';
    }
  }

  /// Generate credit card tokens
  String _generateCreditCardToken(String originalValue, MaskingOptions options) {
    if (options.preserveStructure) {
      final numbers = originalValue.replaceAll(RegExp(r'[^\d]'), '');
      if (numbers.length >= 4) {
        final lastFour = numbers.substring(numbers.length - 4);
        return '**** **** **** $lastFour';
      }
    }
    return '[CREDIT_CARD]';
  }

  /// Generate IP address tokens
  String _generateIPToken(String originalValue, MaskingOptions options) {
    if (options.preserveStructure) {
      return originalValue.replaceAll(RegExp(r'\d'), 'X');
    } else {
      return '[IP_ADDRESS]';
    }
  }

  /// Generate URL tokens
  String _generateURLToken(String originalValue, MaskingOptions options) {
    try {
      final uri = Uri.parse(originalValue);
      if (options.preserveStructure) {
        return '${uri.scheme}://[DOMAIN_REDACTED]${uri.path}';
      } else {
        return '[URL_REDACTED]';
      }
    } catch (e) {
      return '[URL_REDACTED]';
    }
  }

  /// Generate date tokens
  String _generateDateToken(String originalValue, MaskingOptions options) {
    // Extract year and show partial date for utility preservation
    final yearMatch = RegExp(r'(19|20)\d{2}').firstMatch(originalValue);
    if (yearMatch != null) {
      return '[DATE_PARTIAL:${yearMatch.group(0)}]';
    } else {
      return '[DATE_REDACTED]';
    }
  }

  /// Apply custom token patterns
  String _applyCustomToken(String pattern, PIIMatch match, String originalValue) {
    return pattern
        .replaceAll('{type}', match.type.toString().split('.').last.toUpperCase())
        .replaceAll('{hash}', _generateHash(originalValue).substring(0, 8))
        .replaceAll('{length}', originalValue.length.toString());
  }

  /// Get next token counter for type
  String _getNextToken(String type) {
    final count = _tokenCounters[type] ?? 0;
    _tokenCounters[type] = count + 1;
    return String.fromCharCode(65 + (count % 26)); // A, B, C, etc.
  }

  /// Generate hash for sensitive data (REQ-2.4)
  String _generateHash(String input) {
    final bytes = utf8.encode(input.toLowerCase());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Reverse masking for local display (REQ-2.5)
  String unmaskText(String maskedText) {
    String unmasked = maskedText;

    for (final entry in _reverseMappings.entries) {
      unmasked = unmasked.replaceAll(entry.key, entry.value);
    }

    return unmasked;
  }

  /// Check if text contains any PII tokens
  bool containsPIITokens(String text) {
    final tokenPatterns = [
      RegExp(r'\[PERSON_[A-Z]\]'),
      RegExp(r'\[EMAIL[^\]]*\]'),
      RegExp(r'\[PHONE\]'),
      RegExp(r'\[ADDRESS\]'),
      RegExp(r'\[SSN\]'),
      RegExp(r'\[CREDIT_CARD\]'),
      RegExp(r'\[IP_ADDRESS\]'),
      RegExp(r'\[URL_REDACTED\]'),
      RegExp(r'\[DATE_[^\]]*\]'),
      RegExp(r'\[SECRET\]'),
    ];

    return tokenPatterns.any((pattern) => pattern.hasMatch(text));
  }

  /// Clear session mappings
  void clearSession() {
    _sessionMappings.clear();
    _reverseMappings.clear();
    _tokenCounters.clear();
  }

  /// Get session statistics
  Map<String, dynamic> getSessionStats() {
    return {
      'mappingsCount': _sessionMappings.length,
      'reversibleCount': _reverseMappings.length,
      'tokenTypes': _tokenCounters.keys.toList(),
      'totalTokensGenerated': _tokenCounters.values.fold(0, (a, b) => a + b),
    };
  }

  /// Validate that masking was successful (no original PII remains)
  bool validateMasking(String originalText, String maskedText) {
    final originalDetection = _detectionService.detectPII(originalText);
    final maskedDetection = _detectionService.detectPII(maskedText);

    // Check that no original PII values appear in masked text
    for (final match in originalDetection.matches) {
      final originalValue = originalText.substring(match.startIndex, match.endIndex);
      if (maskedText.contains(originalValue)) {
        return false; // Original PII found in masked text
      }
    }

    // Masked text should have significantly fewer PII detections
    return maskedDetection.matches.length < originalDetection.matches.length;
  }
}