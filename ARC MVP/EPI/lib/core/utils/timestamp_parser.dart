/// Shared Timestamp Parser Utility
/// 
/// Consolidates timestamp parsing logic across import services with robust error handling
/// CRITICAL: Entry timestamps should NEVER fallback to DateTime.now() to preserve data integrity
/// Media timestamps can use DateTime.now() as fallback since they're optional metadata
library;

/// Timestamp parsing result
class TimestampParseResult {
  final DateTime? value;
  final bool isDateOnly; // True if only date portion was parsed (time set to midnight)
  final String? error;

  TimestampParseResult({
    this.value,
    this.isDateOnly = false,
    this.error,
  });

  bool get isSuccess => value != null;
}

/// Shared timestamp parser with robust error handling
class TimestampParser {
  /// Parse timestamp with robust handling of different formats
  /// CRITICAL: Never fallback to DateTime.now() for entry dates - throws exception instead
  /// This preserves data integrity by skipping entries with unparseable timestamps
  /// rather than importing them with incorrect dates
  static TimestampParseResult parseEntryTimestamp(String timestamp) {
    final originalTimestamp = timestamp;
    try {
      // Handle malformed timestamps missing 'Z' suffix
      if (timestamp.endsWith('.000') && !timestamp.endsWith('Z')) {
        // Add 'Z' suffix for UTC timezone
        timestamp = '${timestamp}Z';
      } else if (!timestamp.endsWith('Z') && !timestamp.contains('+') && !timestamp.contains('-', 10)) {
        // Check if it has timezone offset (contains '-' after position 10, which is the date part)
        final hasOffset = timestamp.length > 10 && 
                         (timestamp.contains('+', 10) || timestamp.contains('-', 10));
        if (!hasOffset) {
          // If no timezone indicator, assume UTC and add 'Z'
          timestamp = '${timestamp}Z';
        }
      }
      
      final parsed = DateTime.parse(timestamp);
      return TimestampParseResult(value: parsed, isDateOnly: false);
    } catch (e) {
      // Try to extract at least the date portion even if time parsing fails
      try {
        // Try parsing just the date part (YYYY-MM-DD)
        if (originalTimestamp.length >= 10) {
          final datePart = originalTimestamp.substring(0, 10);
          final dateOnly = DateTime.parse('${datePart}T00:00:00Z');
          return TimestampParseResult(
            value: dateOnly,
            isDateOnly: true,
            error: 'Only date portion parsed (time set to midnight UTC)',
          );
        }
      } catch (e2) {
        // Could not extract date
        return TimestampParseResult(
          error: 'Cannot parse timestamp "$originalTimestamp": $e. Date extraction also failed: $e2',
        );
      }
      
      // LAST RESORT: Return error instead of using DateTime.now()
      // This preserves data integrity by requiring explicit handling
      return TimestampParseResult(
        error: 'Cannot parse timestamp "$originalTimestamp": $e. Entry will be skipped to preserve data integrity.',
      );
    }
  }

  /// Parse media timestamp with robust handling (can be null)
  /// Note: Media timestamps can fallback to DateTime.now() as they're optional metadata
  static DateTime parseMediaTimestamp(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) {
      // Media timestamp is optional, so using current time is acceptable
      return DateTime.now();
    }
    
    final result = parseEntryTimestamp(timestamp);
    if (result.isSuccess && result.value != null) {
      return result.value!;
    }
    
    // Media timestamps are less critical than entry dates
    // Fallback to current time if parsing fails
    return DateTime.now();
  }

  /// Parse timestamp with fallback (for non-critical timestamps)
  /// Returns DateTime.now() if parsing fails
  static DateTime parseWithFallback(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) {
      return DateTime.now();
    }
    
    final result = parseEntryTimestamp(timestamp);
    if (result.isSuccess && result.value != null) {
      return result.value!;
    }
    
    // Fallback to current time for non-critical timestamps
    return DateTime.now();
  }
}

