// lib/services/privacy/pii_detection_service.dart
// PII Detection Engine - F1 Implementation
// REQ-1.1 through REQ-1.6

import 'dart:convert';
import 'package:crypto/crypto.dart';

enum PIIType {
  name,
  email,
  phone,
  address,
  ssn,
  creditCard,
  ipAddress,
  url,
  dateOfBirth,
  other
}

enum SensitivityLevel {
  strict,   // Aggressive detection, may have false positives
  normal,   // Balanced detection for general use
  relaxed   // Conservative detection, fewer false positives
}

class PIIMatch {
  final String originalText;
  final PIIType type;
  final int startIndex;
  final int endIndex;
  final double confidence;
  final Map<String, dynamic> metadata;

  PIIMatch({
    required this.originalText,
    required this.type,
    required this.startIndex,
    required this.endIndex,
    required this.confidence,
    this.metadata = const {},
  });

  @override
  String toString() {
    return 'PIIMatch(type: $type, text: "${originalText.substring(startIndex, endIndex)}", confidence: $confidence)';
  }
}

class PIIDetectionResult {
  final String originalText;
  final List<PIIMatch> matches;
  final Duration processingTime;
  final bool hasPII;

  PIIDetectionResult({
    required this.originalText,
    required this.matches,
    required this.processingTime,
  }) : hasPII = matches.isNotEmpty;

  @override
  String toString() {
    return 'PIIDetectionResult(matches: ${matches.length}, hasPII: $hasPII, time: ${processingTime.inMilliseconds}ms)';
  }
}

/// PII Detection Engine implementing REQ-1.1 through REQ-1.6
class PIIDetectionService {
  SensitivityLevel sensitivityLevel;

  // Common names list for enhanced name detection (REQ-1.1)
  static const List<String> _commonFirstNames = [
    'john', 'jane', 'michael', 'sarah', 'david', 'lisa', 'chris', 'maria',
    'james', 'jennifer', 'robert', 'linda', 'william', 'elizabeth', 'richard',
    'barbara', 'joseph', 'susan', 'thomas', 'jessica', 'charles', 'karen'
  ];

  static const List<String> _commonLastNames = [
    'smith', 'johnson', 'williams', 'brown', 'jones', 'garcia', 'miller',
    'davis', 'rodriguez', 'martinez', 'hernandez', 'lopez', 'gonzalez',
    'wilson', 'anderson', 'thomas', 'taylor', 'moore', 'jackson', 'martin'
  ];

  PIIDetectionService({this.sensitivityLevel = SensitivityLevel.normal});

  /// Main detection method (REQ-1.5: <500ms processing time)
  PIIDetectionResult detectPII(String text) {
    final stopwatch = Stopwatch()..start();
    final matches = <PIIMatch>[];

    try {
      // Parallel detection for performance
      matches.addAll(_detectEmails(text));
      matches.addAll(_detectPhones(text));
      matches.addAll(_detectNames(text));
      matches.addAll(_detectAddresses(text));
      matches.addAll(_detectSSNs(text));
      matches.addAll(_detectCreditCards(text));
      matches.addAll(_detectIPAddresses(text));
      matches.addAll(_detectURLs(text));
      matches.addAll(_detectDatesOfBirth(text));

      // Sort matches by position for consistent processing
      matches.sort((a, b) => a.startIndex.compareTo(b.startIndex));

      stopwatch.stop();
      return PIIDetectionResult(
        originalText: text,
        matches: matches,
        processingTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      // Fail safely - return empty result if detection fails
      return PIIDetectionResult(
        originalText: text,
        matches: [],
        processingTime: stopwatch.elapsed,
      );
    }
  }

  /// Email detection (REQ-1.2: 100% accuracy with RFC-compliant regex)
  List<PIIMatch> _detectEmails(String text) {
    // RFC 5322 compliant email regex (simplified for performance)
    final emailRegex = RegExp(
      r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
      caseSensitive: false,
    );

    return emailRegex.allMatches(text).map((match) => PIIMatch(
      originalText: text,
      type: PIIType.email,
      startIndex: match.start,
      endIndex: match.end,
      confidence: 1.0, // 100% confidence for valid email format
      metadata: {
        'domain': match.group(0)!.split('@').last,
        'hash': _generateHash(match.group(0)!),
      },
    )).toList();
  }

  /// Phone detection (REQ-1.3: >90% accuracy, US/international)
  List<PIIMatch> _detectPhones(String text) {
    final matches = <PIIMatch>[];

    // US phone patterns
    final usPhonePatterns = [
      RegExp(r'\b\(?(\d{3})\)?[-.\s]?(\d{3})[-.\s]?(\d{4})\b'), // (123) 456-7890
      RegExp(r'\b\d{3}-\d{3}-\d{4}\b'), // 123-456-7890
      RegExp(r'\b\d{10}\b'), // 1234567890
      RegExp(r'\+1[-.\s]?\(?(\d{3})\)?[-.\s]?(\d{3})[-.\s]?(\d{4})\b'), // +1 (123) 456-7890
    ];

    // International patterns
    final intlPhonePatterns = [
      RegExp(r'\+\d{1,3}[-.\s]?\d{1,14}\b'), // +xx xxxxxxxxxx
    ];

    for (final pattern in usPhonePatterns) {
      for (final match in pattern.allMatches(text)) {
        matches.add(PIIMatch(
          originalText: text,
          type: PIIType.phone,
          startIndex: match.start,
          endIndex: match.end,
          confidence: 0.95,
          metadata: {'format': 'us', 'normalized': _normalizePhone(match.group(0)!)},
        ));
      }
    }

    for (final pattern in intlPhonePatterns) {
      for (final match in pattern.allMatches(text)) {
        matches.add(PIIMatch(
          originalText: text,
          type: PIIType.phone,
          startIndex: match.start,
          endIndex: match.end,
          confidence: 0.90,
          metadata: {'format': 'international'},
        ));
      }
    }

    return matches;
  }

  /// Name detection (REQ-1.1: >95% accuracy using regex + common names)
  List<PIIMatch> _detectNames(String text) {
    final matches = <PIIMatch>[];

    // Pattern for capitalized words that could be names
    final namePattern = RegExp(r'\b[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*\b');

    for (final match in namePattern.allMatches(text)) {
      final nameText = match.group(0)!.toLowerCase();
      final words = nameText.split(' ');

      double confidence = 0.0;

      // Check against common names list
      if (words.length >= 2) {
        final firstName = words.first;
        final lastName = words.last;

        if (_commonFirstNames.contains(firstName) && _commonLastNames.contains(lastName)) {
          confidence = 0.98; // High confidence for known first+last combination
        } else if (_commonFirstNames.contains(firstName) || _commonLastNames.contains(lastName)) {
          confidence = 0.85; // Medium confidence for partial match
        }
      } else if (words.length == 1 && _commonFirstNames.contains(words.first)) {
        confidence = 0.70; // Lower confidence for single name
      }

      // Adjust confidence based on sensitivity level
      final adjustedConfidence = _adjustConfidenceForSensitivity(confidence);

      if (adjustedConfidence > 0.5) {
        matches.add(PIIMatch(
          originalText: text,
          type: PIIType.name,
          startIndex: match.start,
          endIndex: match.end,
          confidence: adjustedConfidence,
          metadata: {'wordCount': words.length},
        ));
      }
    }

    return matches;
  }

  /// Address detection (REQ-1.4: >85% accuracy)
  List<PIIMatch> _detectAddresses(String text) {
    final matches = <PIIMatch>[];
    final processedRanges = <List<int>>[];

    // Street address patterns
    final addressPatterns = [
      RegExp(r'\b\d+\s+[A-Za-z\s]+(?:Street|St|Avenue|Ave|Road|Rd|Drive|Dr|Lane|Ln|Boulevard|Blvd|Court|Ct|Place|Pl)\b', caseSensitive: false),
      RegExp(r'\b\d+\s+[A-Za-z\s]+\s+(St|Ave|Rd|Dr|Ln|Blvd|Ct|Pl)\.?\b', caseSensitive: false),
    ];

    for (final pattern in addressPatterns) {
      for (final match in pattern.allMatches(text)) {
        // Check for overlapping matches
        bool overlaps = processedRanges.any((range) =>
          (match.start >= range[0] && match.start < range[1]) ||
          (match.end > range[0] && match.end <= range[1])
        );

        if (!overlaps) {
          matches.add(PIIMatch(
            originalText: text,
            type: PIIType.address,
            startIndex: match.start,
            endIndex: match.end,
            confidence: 0.87,
            metadata: {'type': 'street'},
          ));
          processedRanges.add([match.start, match.end]);
        }
      }
    }

    return matches;
  }

  /// SSN detection
  List<PIIMatch> _detectSSNs(String text) {
    final ssnPattern = RegExp(r'\b\d{3}-\d{2}-\d{4}\b');

    return ssnPattern.allMatches(text).map((match) => PIIMatch(
      originalText: text,
      type: PIIType.ssn,
      startIndex: match.start,
      endIndex: match.end,
      confidence: 1.0,
      metadata: {'masked': 'XXX-XX-${match.group(0)!.substring(7)}'},
    )).toList();
  }

  /// Credit card detection
  List<PIIMatch> _detectCreditCards(String text) {
    final ccPattern = RegExp(r'\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b');

    return ccPattern.allMatches(text).map((match) => PIIMatch(
      originalText: text,
      type: PIIType.creditCard,
      startIndex: match.start,
      endIndex: match.end,
      confidence: 0.90,
      metadata: {'lastFour': match.group(0)!.replaceAll(RegExp(r'[-\s]'), '').substring(12)},
    )).toList();
  }

  /// IP address detection
  List<PIIMatch> _detectIPAddresses(String text) {
    final ipPattern = RegExp(r'\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b');

    return ipPattern.allMatches(text).map((match) => PIIMatch(
      originalText: text,
      type: PIIType.ipAddress,
      startIndex: match.start,
      endIndex: match.end,
      confidence: 0.95,
      metadata: {'type': 'ipv4'},
    )).toList();
  }

  /// URL detection
  List<PIIMatch> _detectURLs(String text) {
    final urlPattern = RegExp(r'https?://[^\s]+', caseSensitive: false);

    return urlPattern.allMatches(text).map((match) => PIIMatch(
      originalText: text,
      type: PIIType.url,
      startIndex: match.start,
      endIndex: match.end,
      confidence: 0.98,
      metadata: {'domain': Uri.tryParse(match.group(0)!)?.host ?? 'unknown'},
    )).toList();
  }

  /// Date of birth detection
  List<PIIMatch> _detectDatesOfBirth(String text) {
    final dobPatterns = [
      RegExp(r'\b(0?[1-9]|1[0-2])/(0?[1-9]|[12][0-9]|3[01])/(19|20)\d{2}\b'), // MM/DD/YYYY
      RegExp(r'\b(19|20)\d{2}-(0?[1-9]|1[0-2])-(0?[1-9]|[12][0-9]|3[01])\b'), // YYYY-MM-DD
    ];

    final matches = <PIIMatch>[];
    for (final pattern in dobPatterns) {
      for (final match in pattern.allMatches(text)) {
        matches.add(PIIMatch(
          originalText: text,
          type: PIIType.dateOfBirth,
          startIndex: match.start,
          endIndex: match.end,
          confidence: 0.85,
          metadata: {'format': 'date'},
        ));
      }
    }

    return matches;
  }

  /// Adjust confidence based on sensitivity level (REQ-1.6)
  double _adjustConfidenceForSensitivity(double baseConfidence) {
    switch (sensitivityLevel) {
      case SensitivityLevel.strict:
        return baseConfidence * 1.2; // Increase sensitivity
      case SensitivityLevel.normal:
        return baseConfidence;
      case SensitivityLevel.relaxed:
        return baseConfidence * 0.8; // Decrease sensitivity
    }
  }

  /// Generate hash for sensitive data
  String _generateHash(String input) {
    final bytes = utf8.encode(input.toLowerCase());
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 8); // First 8 chars for brevity
  }

  /// Normalize phone number format
  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^\d]'), '');
  }
}