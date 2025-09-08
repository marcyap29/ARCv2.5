import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../fr_settings.dart';
import 'redaction_rules.dart';

class RedactionMatch {
  final String original;
  final String replacement;
  final int start;
  final int end;
  final RedactionCategory category;
  
  RedactionMatch({
    required this.original,
    required this.replacement,
    required this.start,
    required this.end,
    required this.category,
  });
}

enum RedactionCategory {
  name,
  location,
  unit,
  time,
  contact,
  gps,
  plate,
}

extension RedactionCategoryExtension on RedactionCategory {
  String get displayName {
    switch (this) {
      case RedactionCategory.name:
        return 'Name';
      case RedactionCategory.location:
        return 'Location';
      case RedactionCategory.unit:
        return 'Unit';
      case RedactionCategory.time:
        return 'Time';
      case RedactionCategory.contact:
        return 'Contact';
      case RedactionCategory.gps:
        return 'Geo';
      case RedactionCategory.plate:
        return 'Plate';
    }
  }
  
  String get placeholderPrefix {
    switch (this) {
      case RedactionCategory.name:
        return 'Name';
      case RedactionCategory.location:
        return 'Location';
      case RedactionCategory.unit:
        return 'Unit';
      case RedactionCategory.time:
        return 'Time';
      case RedactionCategory.contact:
        return 'Contact';
      case RedactionCategory.gps:
        return 'Geo';
      case RedactionCategory.plate:
        return 'Plate';
    }
  }
}

class RedactionService {
  static const String _appSecret = 'EPI_REDACTION_V1'; // In production, use secure key management
  
  Future<String> redact({
    required String entryId,
    required String originalText,
    required DateTime createdAt,
    required FRSettings settings,
    Set<String>? temporaryAllowlist,
  }) async {
    if (originalText.isEmpty) return originalText;
    
    // Generate per-entry seed for stable placeholders
    _generateSeed(entryId, createdAt);
    
    // Track placeholders for each category
    final placeholderMaps = <RedactionCategory, Map<String, String>>{};
    for (final category in RedactionCategory.values) {
      placeholderMaps[category] = <String, String>{};
    }
    
    // Find all matches across categories
    var allMatches = <RedactionMatch>[];
    
    // People names
    if (settings.redactionEnabled) { // Using master toggle for individual categories for now
      allMatches.addAll(_findNameMatches(originalText));
      allMatches.addAll(_findLocationMatches(originalText));
      allMatches.addAll(_findUnitMatches(originalText));
      allMatches.addAll(_findTimeMatches(originalText));
      allMatches.addAll(_findContactMatches(originalText));
      allMatches.addAll(_findGpsMatches(originalText));
      allMatches.addAll(_findPlateMatches(originalText));
    }
    
    // Remove overlapping matches (keep longer/more specific ones)
    allMatches = _removeOverlappingMatches(allMatches);
    
    // Generate stable placeholders
    String redactedText = originalText;
    
    for (final match in allMatches.reversed) { // Process in reverse order to maintain indices
      // Skip if in temporary allowlist
      if (temporaryAllowlist?.contains(match.original) == true) continue;
      
      // Get or create placeholder for this match
      final categoryMap = placeholderMaps[match.category]!;
      final placeholder = categoryMap.putIfAbsent(
        match.original,
        () => '[${match.category.displayName}-${categoryMap.length + 1}]',
      );
      
      // Replace in text
      redactedText = redactedText.replaceRange(
        match.start,
        match.end,
        placeholder,
      );
    }
    
    return redactedText;
  }

  /// Remove overlapping matches, keeping longer/more specific ones
  List<RedactionMatch> _removeOverlappingMatches(List<RedactionMatch> matches) {
    if (matches.length <= 1) return matches;
    
    // Sort by start position, then by length (longer first)
    matches.sort((a, b) {
      final positionDiff = a.start.compareTo(b.start);
      if (positionDiff != 0) return positionDiff;
      return (b.end - b.start).compareTo(a.end - a.start);
    });
    
    final result = <RedactionMatch>[];
    RedactionMatch? current;
    
    for (final match in matches) {
      if (current == null || match.start >= current.end) {
        // No overlap, add the match
        current = match;
        result.add(match);
      } else if (match.end > current.end && match.start < current.end) {
        // Overlapping - keep the longer one or more specific category
        if ((match.end - match.start) > (current.end - current.start) || 
            _getCategoryPriority(match.category) > _getCategoryPriority(current.category)) {
          result.removeLast();
          result.add(match);
          current = match;
        }
      }
    }
    
    return result;
  }
  
  /// Get priority for redaction categories (higher = more important)
  int _getCategoryPriority(RedactionCategory category) {
    switch (category) {
      case RedactionCategory.name: return 5;
      case RedactionCategory.contact: return 4;
      case RedactionCategory.gps: return 3;
      case RedactionCategory.location: return 2;
      case RedactionCategory.time: return 2;
      case RedactionCategory.unit: return 1;
      case RedactionCategory.plate: return 1;
    }
  }
  
  List<RedactionMatch> _findNameMatches(String text) {
    final matches = <RedactionMatch>[];
    final nameMatches = RedactionRules.peopleNameRegex.allMatches(text);
    
    for (final match in nameMatches) {
      final matchText = match.group(1)!;
      if (RedactionRules.isValidName(matchText)) {
        matches.add(RedactionMatch(
          original: matchText,
          replacement: '[Name-#]',
          start: match.start,
          end: match.end,
          category: RedactionCategory.name,
        ));
      }
    }
    
    return matches;
  }
  
  List<RedactionMatch> _findLocationMatches(String text) {
    final matches = <RedactionMatch>[];
    
    // Street addresses
    final addressMatches = RedactionRules.streetAddressRegex.allMatches(text);
    for (final match in addressMatches) {
      matches.add(RedactionMatch(
        original: match.group(0)!,
        replacement: '[Location-#]',
        start: match.start,
        end: match.end,
        category: RedactionCategory.location,
      ));
    }
    
    // Intersections
    final intersectionMatches = RedactionRules.intersectionRegex.allMatches(text);
    for (final match in intersectionMatches) {
      matches.add(RedactionMatch(
        original: match.group(0)!,
        replacement: '[Location-#]',
        start: match.start,
        end: match.end,
        category: RedactionCategory.location,
      ));
    }
    
    // Facilities
    final facilityMatches = RedactionRules.facilityRegex.allMatches(text);
    for (final match in facilityMatches) {
      matches.add(RedactionMatch(
        original: match.group(0)!,
        replacement: '[Location-#]',
        start: match.start,
        end: match.end,
        category: RedactionCategory.location,
      ));
    }
    
    return matches;
  }
  
  List<RedactionMatch> _findUnitMatches(String text) {
    final matches = <RedactionMatch>[];
    final unitMatches = RedactionRules.unitsRegex.allMatches(text);
    
    for (final match in unitMatches) {
      final matchText = match.group(0)!;
      if (RedactionRules.isValidUnit(matchText)) {
        matches.add(RedactionMatch(
          original: matchText,
          replacement: '[Unit-#]',
          start: match.start,
          end: match.end,
          category: RedactionCategory.unit,
        ));
      }
    }
    
    return matches;
  }
  
  List<RedactionMatch> _findTimeMatches(String text) {
    final matches = <RedactionMatch>[];
    
    // Times
    final timeMatches = RedactionRules.timeRegex.allMatches(text);
    for (final match in timeMatches) {
      matches.add(RedactionMatch(
        original: match.group(0)!,
        replacement: '[Time-#]',
        start: match.start,
        end: match.end,
        category: RedactionCategory.time,
      ));
    }
    
    // Dates
    final dateMatches = RedactionRules.dateRegex.allMatches(text);
    for (final match in dateMatches) {
      matches.add(RedactionMatch(
        original: match.group(0)!,
        replacement: '[Time-#]',
        start: match.start,
        end: match.end,
        category: RedactionCategory.time,
      ));
    }
    
    return matches;
  }
  
  List<RedactionMatch> _findContactMatches(String text) {
    final matches = <RedactionMatch>[];
    
    // Phone numbers
    final phoneMatches = RedactionRules.phoneRegex.allMatches(text);
    for (final match in phoneMatches) {
      matches.add(RedactionMatch(
        original: match.group(0)!,
        replacement: '[Contact-#]',
        start: match.start,
        end: match.end,
        category: RedactionCategory.contact,
      ));
    }
    
    // Email addresses
    final emailMatches = RedactionRules.emailRegex.allMatches(text);
    for (final match in emailMatches) {
      matches.add(RedactionMatch(
        original: match.group(0)!,
        replacement: '[Contact-#]',
        start: match.start,
        end: match.end,
        category: RedactionCategory.contact,
      ));
    }
    
    return matches;
  }
  
  List<RedactionMatch> _findGpsMatches(String text) {
    final matches = <RedactionMatch>[];
    final gpsMatches = RedactionRules.gpsRegex.allMatches(text);
    
    for (final match in gpsMatches) {
      matches.add(RedactionMatch(
        original: match.group(0)!,
        replacement: '[Geo-#]',
        start: match.start,
        end: match.end,
        category: RedactionCategory.gps,
      ));
    }
    
    return matches;
  }
  
  List<RedactionMatch> _findPlateMatches(String text) {
    final matches = <RedactionMatch>[];
    final plateMatches = RedactionRules.plateRegex.allMatches(text);
    
    for (final match in plateMatches) {
      final plateNumber = match.group(1)!;
      matches.add(RedactionMatch(
        original: plateNumber,
        replacement: '[Plate-#]',
        start: match.start + match.group(0)!.indexOf(plateNumber),
        end: match.start + match.group(0)!.indexOf(plateNumber) + plateNumber.length,
        category: RedactionCategory.plate,
      ));
    }
    
    return matches;
  }
  
  String _generateSeed(String entryId, DateTime createdAt) {
    final input = _appSecret + entryId + createdAt.toIso8601String();
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  /// Get all redaction matches for preview purposes
  Future<List<RedactionMatch>> getRedactionMatches({
    required String entryId,
    required String originalText,
    required DateTime createdAt,
    required FRSettings settings,
  }) async {
    if (originalText.isEmpty) return [];
    
    final allMatches = <RedactionMatch>[];
    
    if (settings.redactionEnabled) {
      allMatches.addAll(_findNameMatches(originalText));
      allMatches.addAll(_findLocationMatches(originalText));
      allMatches.addAll(_findUnitMatches(originalText));
      allMatches.addAll(_findTimeMatches(originalText));
      allMatches.addAll(_findContactMatches(originalText));
      allMatches.addAll(_findGpsMatches(originalText));
      allMatches.addAll(_findPlateMatches(originalText));
    }
    
    return allMatches..sort((a, b) => a.start.compareTo(b.start));
  }
}