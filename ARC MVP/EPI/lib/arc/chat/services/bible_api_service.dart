// lib/arc/chat/services/bible_api_service.dart
// Bible Reference Retrieval Service - HelloAO API Integration

import 'dart:convert';
import 'package:http/http.dart' as http;

/// Bible API Service using HelloAO Bible API
/// 
/// Provides accurate Bible verse retrieval with support for:
/// - Multiple translations
/// - Commentaries
/// - Cross-references and datasets
class BibleApiService {
  static const String _baseUrl = 'https://bible.helloao.org/api';
  static const String _defaultTranslation = 'BSB'; // Berean Study Bible
  
  /// Get available translations
  Future<List<Map<String, dynamic>>> getAvailableTranslations() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/available_translations.json'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final translations = <Map<String, dynamic>>[];
        data.forEach((key, value) {
          translations.add({
            'code': key,
            'name': value is Map ? value['name'] ?? key : key,
            'description': value is Map ? value['description'] : null,
          });
        });
        return translations;
      }
      return [];
    } catch (e) {
      print('Bible API: Error fetching translations: $e');
      return [];
    }
  }
  
  /// Get books for a translation
  Future<List<Map<String, dynamic>>> getBooks(String translation) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$translation/books.json'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final books = <Map<String, dynamic>>[];
        data.forEach((key, value) {
          books.add({
            'code': key,
            'name': value is Map ? value['name'] ?? key : key,
            'chapters': value is Map ? value['chapters'] : null,
          });
        });
        return books;
      }
      return [];
    } catch (e) {
      print('Bible API: Error fetching books for $translation: $e');
      return [];
    }
  }
  
  /// Get a chapter
  Future<Map<String, dynamic>?> getChapter({
    required String translation,
    required String book,
    required int chapter,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$translation/$book/$chapter.json'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Bible API: Error fetching chapter $book $chapter: $e');
      return null;
    }
  }
  
  /// Get verses from a reference
  /// 
  /// Supports formats like:
  /// - "John 3:16"
  /// - "Jn 3:16"
  /// - "1 Cor 13"
  /// - "Genesis 1"
  /// - "Psalm 23"
  /// - "Romans 8:28-30"
  /// - "John 3:16-18 (ESV)"
  Future<BibleVerseResult?> getVerses({
    required String reference,
    String? translation,
  }) async {
    try {
      final parsed = _parseReference(reference);
      if (parsed == null) return null;
      
      final trans = translation ?? _defaultTranslation;
      final bookCode = await _resolveBookCode(parsed['book'] as String, trans);
      if (bookCode == null) return null;
      
      final chapter = parsed['chapter'] as int;
      final startVerse = parsed['startVerse'] as int?;
      final endVerse = parsed['endVerse'] as int?;
      
      // Fetch the chapter
      final chapterData = await getChapter(
        translation: trans,
        book: bookCode,
        chapter: chapter,
      );
      
      if (chapterData == null) return null;
      
      // Extract verses
      final verses = <Map<String, dynamic>>[];
      final versesData = chapterData['verses'] as Map<String, dynamic>? ?? {};
      
      if (startVerse != null) {
        final end = endVerse ?? startVerse;
        for (int v = startVerse; v <= end; v++) {
          final verseKey = v.toString();
          if (versesData.containsKey(verseKey)) {
            verses.add({
              'verse': v,
              'text': versesData[verseKey],
            });
          }
        }
      } else {
        // Return entire chapter
        versesData.forEach((key, value) {
          verses.add({
            'verse': int.tryParse(key) ?? 0,
            'text': value,
          });
        });
        verses.sort((a, b) => (a['verse'] as int).compareTo(b['verse'] as int));
      }
      
      return BibleVerseResult(
        reference: reference,
        translation: trans,
        book: parsed['book'] as String,
        bookCode: bookCode,
        chapter: chapter,
        verses: verses,
        chapterData: chapterData,
      );
    } catch (e) {
      print('Bible API: Error getting verses for "$reference": $e');
      return null;
    }
  }
  
  /// Parse a Bible reference string
  Map<String, dynamic>? _parseReference(String reference) {
    // Remove translation specification like "(ESV)" or "[NIV]"
    final cleanRef = reference.replaceAll(RegExp(r'\s*\([^)]+\)\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[[^\]]+\]\s*', caseSensitive: false), '')
        .trim();
    
    // Pattern: Book Chapter:Verse-Verse or Book Chapter
    final pattern = RegExp(
      r'^(\d*\s*[A-Za-z]+)\s+(\d+)(?::(\d+)(?:-(\d+))?)?$',
      caseSensitive: false,
    );
    
    final match = pattern.firstMatch(cleanRef);
    if (match == null) return null;
    
    final book = match.group(1)?.trim() ?? '';
    final chapter = int.tryParse(match.group(2) ?? '') ?? 0;
    final startVerse = match.group(3) != null ? int.tryParse(match.group(3)!) : null;
    final endVerse = match.group(4) != null ? int.tryParse(match.group(4)!) : null;
    
    return {
      'book': book,
      'chapter': chapter,
      'startVerse': startVerse,
      'endVerse': endVerse,
    };
  }
  
  /// Resolve book name to book code
  Future<String?> _resolveBookCode(String bookName, String translation) async {
    // Common book abbreviations
    final abbreviations = {
      'gen': 'GEN', 'genesis': 'GEN',
      'ex': 'EXO', 'exodus': 'EXO',
      'lev': 'LEV', 'leviticus': 'LEV',
      'num': 'NUM', 'numbers': 'NUM',
      'deut': 'DEU', 'deuteronomy': 'DEU',
      'josh': 'JOS', 'joshua': 'JOS',
      'judg': 'JDG', 'judges': 'JDG',
      'ruth': 'RUT',
      '1 sam': '1SA', '1 samuel': '1SA', '1sam': '1SA',
      '2 sam': '2SA', '2 samuel': '2SA', '2sam': '2SA',
      '1 kgs': '1KI', '1 kings': '1KI', '1kgs': '1KI',
      '2 kgs': '2KI', '2 kings': '2KI', '2kgs': '2KI',
      '1 chr': '1CH', '1 chronicles': '1CH', '1chr': '1CH',
      '2 chr': '2CH', '2 chronicles': '2CH', '2chr': '2CH',
      'ezra': 'EZR',
      'neh': 'NEH', 'nehemiah': 'NEH',
      'est': 'EST', 'esther': 'EST',
      'job': 'JOB',
      'ps': 'PSA', 'psalm': 'PSA', 'psalms': 'PSA',
      'prov': 'PRO', 'proverbs': 'PRO',
      'eccl': 'ECC', 'ecclesiastes': 'ECC',
      'song': 'SNG', 'song of solomon': 'SNG',
      'isa': 'ISA', 'isaiah': 'ISA',
      'jer': 'JER', 'jeremiah': 'JER',
      'lam': 'LAM', 'lamentations': 'LAM',
      'ezek': 'EZK', 'ezekiel': 'EZK',
      'dan': 'DAN', 'daniel': 'DAN',
      'hos': 'HOS', 'hosea': 'HOS',
      'joel': 'JOL',
      'amos': 'AMO',
      'obad': 'OBA', 'obadiah': 'OBA',
      'jon': 'JON', 'jonah': 'JON',
      'mic': 'MIC', 'micah': 'MIC',
      'nah': 'NAH', 'nahum': 'NAH',
      'hab': 'HAB', 'habakkuk': 'HAB',
      'zeph': 'ZEP', 'zephaniah': 'ZEP',
      'hag': 'HAG', 'haggai': 'HAG',
      'zech': 'ZEC', 'zechariah': 'ZEC',
      'mal': 'MAL', 'malachi': 'MAL',
      'matt': 'MAT', 'matthew': 'MAT', 'mt': 'MAT',
      'mk': 'MRK', 'mark': 'MRK',
      'lk': 'LUK', 'luke': 'LUK',
      'jn': 'JHN', 'john': 'JHN', 'jhn': 'JHN',
      'acts': 'ACT',
      'rom': 'ROM', 'romans': 'ROM',
      '1 cor': '1CO', '1 corinthians': '1CO', '1cor': '1CO',
      '2 cor': '2CO', '2 corinthians': '2CO', '2cor': '2CO',
      'gal': 'GAL', 'galatians': 'GAL',
      'eph': 'EPH', 'ephesians': 'EPH',
      'phil': 'PHP', 'philippians': 'PHP',
      'col': 'COL', 'colossians': 'COL',
      '1 thes': '1TH', '1 thessalonians': '1TH', '1thes': '1TH',
      '2 thes': '2TH', '2 thessalonians': '2TH', '2thes': '2TH',
      '1 tim': '1TI', '1 timothy': '1TI', '1tim': '1TI',
      '2 tim': '2TI', '2 timothy': '2TI', '2tim': '2TI',
      'titus': 'TIT',
      'philem': 'PHM', 'philemon': 'PHM',
      'heb': 'HEB', 'hebrews': 'HEB',
      'jas': 'JAS', 'james': 'JAS',
      '1 pet': '1PE', '1 peter': '1PE', '1pet': '1PE',
      '2 pet': '2PE', '2 peter': '2PE', '2pet': '2PE',
      '1 jn': '1JN', '1 john': '1JN', '1jn': '1JN',
      '2 jn': '2JN', '2 john': '2JN', '2jn': '2JN',
      '3 jn': '3JN', '3 john': '3JN', '3jn': '3JN',
      'jude': 'JUD',
      'rev': 'REV', 'revelation': 'REV',
    };
    
    final normalized = bookName.toLowerCase().trim();
    if (abbreviations.containsKey(normalized)) {
      return abbreviations[normalized];
    }
    
    // Try fetching books list and matching
    try {
      final books = await getBooks(translation);
      for (final book in books) {
        final bookNameLower = (book['name'] as String? ?? '').toLowerCase();
        if (bookNameLower.contains(normalized) || normalized.contains(bookNameLower)) {
          return book['code'] as String?;
        }
      }
    } catch (e) {
      print('Bible API: Error resolving book code: $e');
    }
    
    return null;
  }
  
  /// Get available commentaries
  Future<List<Map<String, dynamic>>> getAvailableCommentaries() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/available_commentaries.json'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final commentaries = <Map<String, dynamic>>[];
        data.forEach((key, value) {
          commentaries.add({
            'code': key,
            'name': value is Map ? value['name'] ?? key : key,
          });
        });
        return commentaries;
      }
      return [];
    } catch (e) {
      print('Bible API: Error fetching commentaries: $e');
      return [];
    }
  }
  
  /// Get commentary chapter
  Future<Map<String, dynamic>?> getCommentaryChapter({
    required String commentary,
    required String book,
    required int chapter,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/c/$commentary/$book/$chapter.json'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Bible API: Error fetching commentary: $e');
      return null;
    }
  }
}

/// Result of a Bible verse lookup
class BibleVerseResult {
  final String reference;
  final String translation;
  final String book;
  final String bookCode;
  final int chapter;
  final List<Map<String, dynamic>> verses;
  final Map<String, dynamic>? chapterData;
  
  BibleVerseResult({
    required this.reference,
    required this.translation,
    required this.book,
    required this.bookCode,
    required this.chapter,
    required this.verses,
    this.chapterData,
  });
  
  /// Format verses as text
  String formatVerses() {
    if (verses.isEmpty) return '';
    
    final buffer = StringBuffer();
    for (final verse in verses) {
      final verseNum = verse['verse'] as int;
      final text = verse['text'] as String? ?? '';
      buffer.writeln('$verseNum $text');
    }
    return buffer.toString().trim();
  }
  
  /// Get full reference string
  String getFullReference() {
    if (verses.isEmpty) return '$book $chapter';
    if (verses.length == 1) {
      return '$book $chapter:${verses.first['verse']}';
    }
    final first = verses.first['verse'] as int;
    final last = verses.last['verse'] as int;
    return '$book $chapter:$first-$last';
  }
}
