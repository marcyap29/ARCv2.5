// lib/arc/chat/services/bible_retrieval_helper.dart
// Bible Retrieval Helper for LUMARA - Fetches Bible verses when requested

import 'package:my_app/arc/chat/services/bible_api_service.dart';
import 'package:my_app/arc/chat/services/bible_terminology_library.dart';

/// Bible Retrieval Helper
/// 
/// Provides a simple interface for LUMARA to fetch Bible verses
/// when users request Bible references.
class BibleRetrievalHelper {
  static final BibleApiService _apiService = BibleApiService();
  
  /// Check if a user message is requesting a Bible verse
  static bool isBibleRequest(String message) {
    final lower = message.toLowerCase();
    
    // First, check comprehensive Bible terminology library
    if (BibleTerminologyLibrary.containsBibleTerminology(message)) {
      return true;
    }
    
    // Patterns that indicate Bible verse requests
    final patterns = [
      // Specific verse/chapter references
      RegExp(r'\b(john|matthew|mark|luke|acts|romans|corinthians|galatians|ephesians|philippians|colossians|thessalonians|timothy|titus|philemon|hebrews|james|peter|jude|revelation|genesis|exodus|leviticus|numbers|deuteronomy|joshua|judges|ruth|samuel|kings|chronicles|ezra|nehemiah|esther|job|psalm|psalms|proverbs|ecclesiastes|song|isaiah|jeremiah|lamentations|ezekiel|daniel|hosea|joel|amos|obadiah|jonah|micah|nahum|habakkuk|zephaniah|haggai|zechariah|malachi)\s+\d+', caseSensitive: false),
      RegExp(r'\b(1|2|3)?\s*(john|cor|thes|tim|pet|sam|kgs|chr)\s+\d+', caseSensitive: false),
      RegExp(r'\b(verse|chapter|book|bible|scripture|scriptures)\s+.*\d+', caseSensitive: false),
      // Topic questions
      RegExp(r'what does the bible say about', caseSensitive: false),
      RegExp(r'what does.*bible.*say', caseSensitive: false),
      RegExp(r'bible.*about', caseSensitive: false),
      // Explicit Bible references
      RegExp(r'bible verse', caseSensitive: false),
      RegExp(r'look up.*bible', caseSensitive: false),
      // Questions about Bible books/prophets (even without chapter/verse)
      RegExp(r'\b(about|tell me about|who is|what is).*\b(prophet|book of|book)', caseSensitive: false),
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
  
  /// Extract Bible book name from user message
  static String? extractBibleBook(String message) {
    // Use the comprehensive terminology library
    final book = BibleTerminologyLibrary.getPrimaryBibleBook(message);
    if (book != null) {
      // Handle numbered books properly
      if (book.startsWith('1 ') || book.startsWith('2 ') || book.startsWith('3 ')) {
        // Already formatted correctly
        return book.substring(0, 1).toUpperCase() + book.substring(1);
      }
      // Capitalize first letter for single-word books
      return book.substring(0, 1).toUpperCase() + book.substring(1);
    }
    
    // Fallback to manual check for numbered books
    final lower = message.toLowerCase();
    final numberedBooks = {
      '1 samuel': '1 Samuel', '2 samuel': '2 Samuel',
      '1 kings': '1 Kings', '2 kings': '2 Kings',
      '1 chronicles': '1 Chronicles', '2 chronicles': '2 Chronicles',
      '1 corinthians': '1 Corinthians', '2 corinthians': '2 Corinthians',
      '1 thessalonians': '1 Thessalonians', '2 thessalonians': '2 Thessalonians',
      '1 timothy': '1 Timothy', '2 timothy': '2 Timothy',
      '1 peter': '1 Peter', '2 peter': '2 Peter',
      '1 john': '1 John', '2 john': '2 John', '3 john': '3 John',
    };
    
    for (final entry in numberedBooks.entries) {
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
      final isBible = isBibleRequest(userMessage);
      print('Bible Retrieval Helper: ===== CHECKING BIBLE REQUEST =====');
      print('Bible Retrieval Helper: Message: "${userMessage.substring(0, userMessage.length > 50 ? 50 : userMessage.length)}..."');
      print('Bible Retrieval Helper: Is Bible request: $isBible');
      
      if (!isBible) {
        print('Bible Retrieval Helper: ❌ Not detected as Bible request, returning null');
        return null;
      }
      
      print('Bible Retrieval Helper: ✅ Bible request detected! Processing...');
      
      // Extract reference
      final reference = extractReference(userMessage);
      if (reference != null) {
        // User asked for a specific verse/chapter - fetch it
        final translation = extractTranslation(userMessage);
        
        final result = await _apiService.getVerses(
          reference: reference,
          translation: translation,
        );
        
        if (result != null) {
          // Format the response
          final buffer = StringBuffer();
          buffer.writeln('**${result.getFullReference()} (${result.translation})**');
          buffer.writeln();
          buffer.writeln(result.formatVerses());
          return buffer.toString();
        }
      }
      
      // User asked about a Bible book/prophet/topic without specific verse
      // Try to fetch actual verses to provide concrete content
      final bookName = extractBibleBook(userMessage);
      final character = BibleTerminologyLibrary.getBiblicalCharacter(userMessage);
      final isConcept = BibleTerminologyLibrary.isAskingAboutConcept(userMessage);
      final bibleTerms = BibleTerminologyLibrary.extractBibleTerms(userMessage);
      
      print('Bible Retrieval Helper: ===== EXTRACTION RESULTS =====');
      print('Bible Retrieval Helper: Book name extracted: $bookName');
      print('Bible Retrieval Helper: Character extracted: $character');
      print('Bible Retrieval Helper: Is concept: $isConcept');
      print('Bible Retrieval Helper: Bible terms found: $bibleTerms');
      print('Bible Retrieval Helper: ============================');
      
      if (bookName != null || character != null || isConcept) {
        // Try to fetch the first chapter as context if we have a book name
        if (bookName != null) {
          print('Bible Retrieval Helper: Attempting to fetch verses for book: $bookName');
          try {
            final translation = extractTranslation(userMessage) ?? 'BSB';
            final books = await _apiService.getBooks(translation);
            String? bookCode;
            
            for (final book in books) {
              final name = (book['name'] as String? ?? '').toLowerCase();
              final bookNameLower = bookName.toLowerCase();
              if (name.contains(bookNameLower) || bookNameLower.contains(name)) {
                bookCode = book['code'] as String?;
                break;
              }
            }
            
            if (bookCode != null) {
              print('Bible Retrieval Helper: Found book code $bookCode for $bookName');
              // Fetch first chapter to provide actual content
              final chapterData = await _apiService.getChapter(
                translation: translation,
                book: bookCode,
                chapter: 1,
              );
              
              if (chapterData != null) {
                print('Bible Retrieval Helper: Successfully fetched chapter 1 for $bookName');
                final verses = chapterData['verses'] as Map<String, dynamic>? ?? {};
                print('Bible Retrieval Helper: Found ${verses.length} verses in chapter 1');
                
                final buffer = StringBuffer();
                buffer.writeln('[BIBLE_VERSE_CONTEXT]');
                buffer.writeln('**$bookName 1 (${translation})**');
                buffer.writeln();
                
                // Include first few verses as example
                final verseKeys = verses.keys.toList()..sort((a, b) => 
                  (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
                final versesToShow = verseKeys.take(5).toList();
                
                for (final verseKey in versesToShow) {
                  final verseText = verses[verseKey];
                  buffer.writeln('$verseKey $verseText');
                }
                
                if (verses.length > 5) {
                  buffer.writeln('... (${verses.length - 5} more verses in this chapter)');
                }
                
                buffer.writeln();
                buffer.writeln('[BIBLE_CONTEXT]');
                buffer.writeln('The user is asking about $bookName from the Bible.');
                buffer.writeln('Above are the first verses from $bookName chapter 1.');
                buffer.writeln('You MUST respond about $bookName using the verses provided above.');
                buffer.writeln('DO NOT give a generic introduction. Respond directly about $bookName.');
                buffer.writeln('Provide context about $bookName and offer to fetch more chapters or specific verses.');
                buffer.writeln('[/BIBLE_CONTEXT]');
                buffer.writeln('[/BIBLE_VERSE_CONTEXT]');
                final result = buffer.toString();
                print('Bible Retrieval Helper: Returning verses context (length: ${result.length})');
                return result;
              } else {
                print('Bible Retrieval Helper: Failed to fetch chapter data for $bookName $bookCode');
              }
            } else {
              print('Bible Retrieval Helper: Could not find book code for $bookName');
            }
          } catch (e) {
            print('Bible Retrieval Helper: Error fetching book context: $e');
          }
        }
        
        // If we have a character (prophet) but no book name, try to fetch their book
        if (character != null && bookName == null) {
          print('Bible Retrieval Helper: Character detected but no book name - trying to find book for: $character');
          // Many prophets have books named after them
          final characterLower = character.toLowerCase();
          if (BibleTerminologyLibrary.prophets.contains(characterLower) || 
              BibleTerminologyLibrary.biblicalCharacters.contains(characterLower)) {
            print('Bible Retrieval Helper: Character is a prophet/biblical figure - attempting to fetch their book');
            try {
              final translation = extractTranslation(userMessage) ?? 'BSB';
              final books = await _apiService.getBooks(translation);
              String? bookCode;
              String? foundBookName;
              
              // Try to find a book that matches the character name
              for (final book in books) {
                final name = (book['name'] as String? ?? '').toLowerCase();
                if (name == characterLower || 
                    name.contains(characterLower) || 
                    characterLower.contains(name)) {
                  bookCode = book['code'] as String?;
                  foundBookName = book['name'] as String?;
                  print('Bible Retrieval Helper: Found matching book: $foundBookName ($bookCode) for character $character');
                  break;
                }
              }
              
              if (bookCode != null && foundBookName != null) {
                print('Bible Retrieval Helper: Fetching chapter 1 for book: $foundBookName');
                final chapterData = await _apiService.getChapter(
                  translation: translation,
                  book: bookCode,
                  chapter: 1,
                );
                
                if (chapterData != null) {
                  print('Bible Retrieval Helper: ✅ Successfully fetched chapter 1 for $foundBookName');
                  final verses = chapterData['verses'] as Map<String, dynamic>? ?? {};
                  print('Bible Retrieval Helper: Found ${verses.length} verses in chapter 1');
                  
                  final buffer = StringBuffer();
                  buffer.writeln('[BIBLE_VERSE_CONTEXT]');
                  buffer.writeln('**$foundBookName 1 (${translation})**');
                  buffer.writeln();
                  
                  final verseKeys = verses.keys.toList()..sort((a, b) => 
                    (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
                  final versesToShow = verseKeys.take(5).toList();
                  
                  for (final verseKey in versesToShow) {
                    final verseText = verses[verseKey];
                    buffer.writeln('$verseKey $verseText');
                  }
                  
                  if (verses.length > 5) {
                    buffer.writeln('... (${verses.length - 5} more verses in this chapter)');
                  }
                  
                  buffer.writeln();
                  buffer.writeln('[BIBLE_CONTEXT]');
                  buffer.writeln('The user is asking about $character from the Bible.');
                  buffer.writeln('Above are the first verses from the book of $foundBookName chapter 1.');
                  buffer.writeln('You MUST respond about $character using the verses provided above.');
                  buffer.writeln('DO NOT give a generic introduction. Respond directly about $character.');
                  buffer.writeln('Provide context about $character and offer to fetch more chapters or specific verses.');
                  buffer.writeln('[/BIBLE_CONTEXT]');
                  buffer.writeln('[/BIBLE_VERSE_CONTEXT]');
                  final result = buffer.toString();
                  print('Bible Retrieval Helper: ✅ Returning verses context for character (length: ${result.length})');
                  return result;
                } else {
                  print('Bible Retrieval Helper: ❌ Failed to fetch chapter data for $foundBookName');
                }
              } else {
                print('Bible Retrieval Helper: ❌ Could not find book code for character: $character');
              }
            } catch (e, stackTrace) {
              print('Bible Retrieval Helper: ❌ Error fetching book for character $character: $e');
              print('Bible Retrieval Helper: Stack trace: $stackTrace');
            }
          }
        }
        
        // Build context for character or concept questions (fallback if no verses fetched)
        print('Bible Retrieval Helper: Building general Bible context (no verses fetched)');
        final buffer = StringBuffer();
        buffer.writeln('[BIBLE_CONTEXT]');
        buffer.writeln('CRITICAL: This is a Bible-related question. You MUST respond about the Bible topic, not with a generic introduction.');
        if (character != null) {
          buffer.writeln('The user is asking about $character from the Bible.');
          buffer.writeln('You MUST respond about $character. DO NOT give a generic introduction.');
          buffer.writeln('Provide information about $character and offer to fetch specific verses or chapters.');
        } else if (isConcept) {
          buffer.writeln('The user is asking about a biblical concept or theme.');
          buffer.writeln('Bible-related terms detected: ${bibleTerms.join(", ")}');
          buffer.writeln('You MUST respond about this biblical topic. DO NOT give a generic introduction.');
          buffer.writeln('Provide key Bible references and offer to fetch the full text of specific verses.');
        } else if (bookName != null) {
          buffer.writeln('The user is asking about $bookName from the Bible.');
          buffer.writeln('You MUST respond about $bookName. DO NOT give a generic introduction.');
          buffer.writeln('You should use the Bible API to fetch relevant verses or chapters.');
        }
        buffer.writeln('Always use the HelloAO Bible API to retrieve accurate Bible verses.');
        buffer.writeln('Never quote from memory - always fetch from the Bible API.');
        buffer.writeln('The original user question was: "$userMessage"');
        buffer.writeln('[/BIBLE_CONTEXT]');
        final result = buffer.toString();
        print('Bible Retrieval Helper: Returning general context (length: ${result.length})');
        return result;
      }
      
      // General Bible topic question - provide context
      print('Bible Retrieval Helper: Building general Bible context');
      final buffer = StringBuffer();
      buffer.writeln('[BIBLE_CONTEXT]');
      buffer.writeln('CRITICAL: This is a Bible-related question. You MUST respond about the Bible topic, not with a generic introduction.');
      buffer.writeln('The user asked: "$userMessage"');
      buffer.writeln('You MUST respond directly to this Bible question. DO NOT say "I\'m ready to assist you" or give a generic introduction.');
      buffer.writeln('You should use the Bible API (HelloAO) to fetch accurate Bible verses.');
      buffer.writeln('If the user asks about a specific book, prophet, or topic, use the Bible API to retrieve relevant verses.');
      buffer.writeln('Always fetch from HelloAO Bible API rather than quoting from memory.');
      buffer.writeln('If you cannot access the Bible API, use Google Search to find Bible verses from reputable sources.');
      buffer.writeln('[/BIBLE_CONTEXT]');
      final result = buffer.toString();
      print('Bible Retrieval Helper: Returning context: ${result.substring(0, result.length > 200 ? 200 : result.length)}...');
      return result;
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
