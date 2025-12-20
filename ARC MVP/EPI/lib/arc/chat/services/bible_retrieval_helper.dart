// lib/arc/chat/services/bible_retrieval_helper.dart
// Bible Retrieval Helper for LUMARA - Fetches Bible verses when requested

import 'package:my_app/arc/chat/services/bible_api_service.dart';

/// Bible Retrieval Helper
/// 
/// Provides a simple interface for LUMARA to fetch Bible verses
/// when users request Bible references.
class BibleRetrievalHelper {
  static final BibleApiService _apiService = BibleApiService();
  
  /// Check if a user message is requesting a Bible verse
  static bool isBibleRequest(String message) {
    final lower = message.toLowerCase();
    
    // Patterns that indicate Bible verse requests
    final patterns = [
      RegExp(r'\b(john|matthew|mark|luke|acts|romans|corinthians|galatians|ephesians|philippians|colossians|thessalonians|timothy|titus|philemon|hebrews|james|peter|jude|revelation|genesis|exodus|leviticus|numbers|deuteronomy|joshua|judges|ruth|samuel|kings|chronicles|ezra|nehemiah|esther|job|psalm|psalms|proverbs|ecclesiastes|song|isaiah|jeremiah|lamentations|ezekiel|daniel|hosea|joel|amos|obadiah|jonah|micah|nahum|habakkuk|zephaniah|haggai|zechariah|malachi)\s+\d+', caseSensitive: false),
      RegExp(r'\b(1|2|3)?\s*(john|cor|thes|tim|pet|sam|kgs|chr)\s+\d+', caseSensitive: false),
      RegExp(r'\b(verse|chapter|book|bible|scripture|scriptures)\s+.*\d+', caseSensitive: false),
      RegExp(r'what does the bible say about', caseSensitive: false),
      RegExp(r'bible verse', caseSensitive: false),
      RegExp(r'look up.*bible', caseSensitive: false),
    ];
    
    return patterns.any((pattern) => pattern.hasMatch(lower));
  }
  
  /// Extract Bible reference from user message
  static String? extractReference(String message) {
    // Try to find a Bible reference pattern
    final pattern = RegExp(
      r'(\d*\s*[A-Za-z]+\s+\d+(?::\d+(?:-\d+)?)?)',
      caseSensitive: false,
    );
    
    final match = pattern.firstMatch(message);
    return match?.group(1)?.trim();
  }
  
  /// Extract translation preference from user message
  static String? extractTranslation(String message) {
    final lower = message.toLowerCase();
    
    // Common translation codes
    final translations = {
      'esv': 'ESV',
      'niv': 'NIV',
      'nlt': 'NLT',
      'kjv': 'KJV',
      'nasb': 'NASB',
      'bsb': 'BSB',
      'nrsv': 'NRSV',
      'amp': 'AMP',
      'msg': 'MSG',
    };
    
    for (final entry in translations.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    
    return null;
  }
  
  /// Fetch Bible verses for a user request
  /// 
  /// Returns formatted text that LUMARA can include in its response
  static Future<String?> fetchVersesForRequest(String userMessage) async {
    try {
      // Check if this is a Bible request
      if (!isBibleRequest(userMessage)) {
        return null;
      }
      
      // Extract reference
      final reference = extractReference(userMessage);
      if (reference == null) {
        // User asked "what does the Bible say about X?"
        // Return null - LUMARA should handle this with general guidance
        return null;
      }
      
      // Extract translation
      final translation = extractTranslation(userMessage);
      
      // Fetch verses
      final result = await _apiService.getVerses(
        reference: reference,
        translation: translation,
      );
      
      if (result == null) {
        return null;
      }
      
      // Format the response
      final buffer = StringBuffer();
      buffer.writeln('**${result.getFullReference()} (${result.translation})**');
      buffer.writeln();
      buffer.writeln(result.formatVerses());
      
      return buffer.toString();
    } catch (e) {
      print('Bible Retrieval Helper: Error fetching verses: $e');
      return null;
    }
  }
  
  /// Format Bible verse result for LUMARA response
  static String formatVerseResult(BibleVerseResult result, {String? context, String? interpretation}) {
    final buffer = StringBuffer();
    
    buffer.writeln('**${result.getFullReference()} (${result.translation})**');
    buffer.writeln();
    buffer.writeln(result.formatVerses());
    
    if (context != null && context.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('**Context:** $context');
    }
    
    if (interpretation != null && interpretation.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('**Interpretation:** $interpretation');
    }
    
    return buffer.toString();
  }
}
