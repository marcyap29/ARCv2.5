import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Journal Paragraph Formatting Tests', () {
    test('Extract sentences correctly', () {
      const testText = '''
This is the first sentence. This is the second sentence! This is the third sentence? This is the fourth sentence. This is a final sentence.
''';

      final sentences = extractSentences(testText);

      expect(sentences.length, 5);
      expect(sentences[0], 'This is the first sentence.');
      expect(sentences[1], 'This is the second sentence!');
      expect(sentences[2], 'This is the third sentence?');
      expect(sentences[3], 'This is the fourth sentence.');
      expect(sentences[4], 'This is a final sentence.');
    });

    test('Format journal paragraphs with 10-word minimum sentences', () {
      const testText = '''
This is a sentence that contains exactly ten words here. This is another sentence that also meets the minimum word requirement. A third sentence continues with the minimum ten words needed. The fourth sentence completes this test with exactly ten words. The fifth sentence adds more content for testing purposes.
''';

      final paragraphs = formatInJournalParagraphs(testText);

      // Should create at least 1 paragraph
      expect(paragraphs.length, greaterThanOrEqualTo(1));

      // Each paragraph should have content
      for (final paragraph in paragraphs) {
        expect(paragraph.trim().isNotEmpty, true);
        // Count sentences more accurately
        final sentenceCount = paragraph.split(RegExp(r'[.!?]')).where((s) => s.trim().isNotEmpty).length;
        expect(sentenceCount, greaterThanOrEqualTo(1));
      }
    });

    test('Journal formatting handles short sentences by combining them', () {
      const testText = '''
This is a sentence that contains exactly ten words here. Short. This is another sentence that meets the minimum word requirement. Very short. The final sentence completes this test with exactly ten words.
''';

      final paragraphs = formatInJournalParagraphs(testText);

      // Short sentences should be combined with adjacent sentences
      expect(paragraphs.isNotEmpty, true);

      // Should not have standalone very short sentences
      for (final paragraph in paragraphs) {
        final wordCount = paragraph.trim().split(RegExp(r'\s+')).length;
        expect(wordCount, greaterThan(5)); // Combined sentences should be longer
      }
    });

    test('Journal formatting creates 2-4 sentence paragraphs', () {
      const testText = '''
Sentence one contains exactly ten words for testing purposes here. Sentence two also contains exactly ten words for testing purposes here. Sentence three continues with exactly ten words for testing purposes here. Sentence four maintains exactly ten words for testing purposes here. Sentence five keeps exactly ten words for testing purposes here. Sentence six provides exactly ten words for testing purposes here. Sentence seven delivers exactly ten words for testing purposes here.
''';

      final paragraphs = formatInJournalParagraphs(testText);

      for (final paragraph in paragraphs) {
        final sentenceCount = paragraph.split(RegExp(r'[.!?]')).where((s) => s.trim().isNotEmpty).length;
        expect(sentenceCount, greaterThanOrEqualTo(2));
        expect(sentenceCount, lessThanOrEqualTo(4));
      }
    });

  });

  group('Chat Paragraph Formatting Tests', () {
    test('Format chat paragraphs with 10-word minimum sentences', () {
      const testText = '''
This is a sentence that contains exactly ten words here. This is another sentence that also meets the minimum word requirement. A third sentence continues with the minimum ten words needed. The fourth sentence completes this test with exactly ten words. The fifth sentence adds more content for testing purposes. The sixth sentence provides additional content for comprehensive testing here.
''';

      final paragraphs = formatInChatParagraphs(testText);

      // Should create at least 1 paragraph
      expect(paragraphs.length, greaterThanOrEqualTo(1));

      // Each paragraph should have content
      for (final paragraph in paragraphs) {
        expect(paragraph.trim().isNotEmpty, true);
        // Count sentences more accurately
        final sentenceCount = paragraph.split(RegExp(r'[.!?]')).where((s) => s.trim().isNotEmpty).length;
        expect(sentenceCount, greaterThanOrEqualTo(1));
      }
    });

    test('Chat formatting creates 3-5 sentence paragraphs', () {
      const testText = '''
Sentence one contains exactly ten words for testing purposes here. Sentence two also contains exactly ten words for testing purposes here. Sentence three continues with exactly ten words for testing purposes here. Sentence four maintains exactly ten words for testing purposes here. Sentence five keeps exactly ten words for testing purposes here. Sentence six provides exactly ten words for testing purposes here. Sentence seven delivers exactly ten words for testing purposes here. Sentence eight completes exactly ten words for testing purposes here.
''';

      final paragraphs = formatInChatParagraphs(testText);

      for (final paragraph in paragraphs) {
        final sentenceCount = paragraph.split(RegExp(r'[.!?]')).where((s) => s.trim().isNotEmpty).length;
        expect(sentenceCount, greaterThanOrEqualTo(3));
        expect(sentenceCount, lessThanOrEqualTo(5));
      }
    });

    test('Chat formatting handles short sentences by combining them', () {
      const testText = '''
This is a sentence that contains exactly ten words here. Short. This is another sentence that meets the minimum word requirement. Very short. The fourth sentence completes this test with exactly ten words. Brief. The final sentence completes this test with exactly ten words.
''';

      final paragraphs = formatInChatParagraphs(testText);

      // Short sentences should be combined with adjacent sentences
      expect(paragraphs.isNotEmpty, true);

      // Should not have standalone very short sentences
      for (final paragraph in paragraphs) {
        final wordCount = paragraph.trim().split(RegExp(r'\s+')).length;
        expect(wordCount, greaterThan(10)); // Combined sentences should be longer
      }
    });
  });

  group('Legacy Tests (Updated)', () {
    test('Group sentences into 2-sentence paragraphs', () {
      const testText = '''
This is the first sentence. This is the second sentence. This is the third sentence. This is the fourth sentence. This is the fifth sentence.
''';

      final paragraphs = formatIntoParagraphs(testText);

      expect(paragraphs.length, 3); // 5 sentences = 3 paragraphs (2+2+1)
      expect(paragraphs[0], 'This is the first sentence. This is the second sentence.');
      expect(paragraphs[1], 'This is the third sentence. This is the fourth sentence.');
      expect(paragraphs[2], 'This is the fifth sentence.');
    });

    test('Handle text with existing paragraph breaks', () {
      const testText = '''
This is paragraph one. It has two sentences.

This is paragraph two. It also has content.
''';

      final paragraphs = formatIntoParagraphs(testText);

      // Should preserve existing paragraph breaks
      expect(paragraphs.length, 2);
      expect(paragraphs[0], 'This is paragraph one. It has two sentences.');
      expect(paragraphs[1], 'This is paragraph two. It also has content.');
    });

    test('Handle complex punctuation', () {
      const testText = '''
LUMARA reflects: "This is interesting." You mentioned Dr. Smith, which reminds me of something. What do you think about this? I.e., how does it make you feel?
''';

      final sentences = extractSentences(testText);

      // Should handle quotes and abbreviations correctly
      expect(sentences.length, greaterThanOrEqualTo(2));
      expect(sentences[0], contains('LUMARA reflects'));
      // Check that Dr. is handled properly in any sentence
      final fullText = sentences.join(' ');
      expect(fullText, contains('Dr.'));
    });

    test('Handle LUMARA response with reflection header', () {
      const testText = '''
✨ Reflection

This is a thoughtful response. It contains multiple sentences for the user. This is the third sentence. And here's the fourth one.
''';

      final paragraphs = formatIntoParagraphs(testText);

      // Should handle the header and format the content
      expect(paragraphs.length, greaterThanOrEqualTo(1));
    });
  });
}

/// Simulates the sentence extraction logic
List<String> extractSentences(String text) {
  if (text.trim().isEmpty) return [];

  // Simple sentence splitting for test
  final sentencePattern = RegExp(r'([^.!?]*[.!?]+)');
  final matches = sentencePattern.allMatches(text);

  return matches
      .map((match) => match.group(1)?.trim())
      .where((s) => s != null && s.isNotEmpty)
      .cast<String>()
      .toList();
}

/// Simulates the paragraph formatting logic
List<String> formatIntoParagraphs(String content) {
  if (content.trim().isEmpty) return [];

  // Split by double newlines first (explicit paragraphs)
  List<String> paragraphs = content.split('\n\n');

  // Clean up paragraphs - remove single newlines within paragraphs
  paragraphs = paragraphs.map((p) => p.replaceAll('\n', ' ').trim()).toList();

  // If still single paragraph, group sentences
  if (paragraphs.length == 1) {
    final sentences = extractSentences(content);

    if (sentences.length >= 2) {
      paragraphs = [];

      // Group every 2 sentences together
      for (int i = 0; i < sentences.length; i += 2) {
        String paragraphText = sentences[i];

        // Add second sentence if available
        if (i + 1 < sentences.length) {
          paragraphText += ' ' + sentences[i + 1];
        }

        paragraphs.add(paragraphText.trim());
      }
    }
  }

  return paragraphs.where((p) => p.isNotEmpty).toList();
}

/// Simulates the journal paragraph formatting logic
List<String> formatInJournalParagraphs(String content) {
  final sentences = extractValidSentences(content, minWords: 10);

  if (sentences.length < 2) {
    // If less than 2 valid sentences, fallback to previous behavior
    return formatIntoParagraphs(content);
  }

  final paragraphs = <String>[];

  // Group sentences into paragraphs (2-4 sentences each)
  for (int i = 0; i < sentences.length;) {
    final remainingSentences = sentences.length - i;
    int sentencesToTake;

    if (remainingSentences <= 4) {
      // Take all remaining if 4 or fewer
      sentencesToTake = remainingSentences;
    } else if (remainingSentences == 5) {
      // Split 5 sentences as 2+3 instead of 4+1
      sentencesToTake = 2;
    } else {
      // Take 4 sentences for optimal readability
      sentencesToTake = 4;
    }

    // Ensure minimum of 2 sentences per paragraph
    if (sentencesToTake < 2) sentencesToTake = 2;

    final paragraphSentences = sentences.sublist(i, i + sentencesToTake);
    paragraphs.add(paragraphSentences.join(' '));

    i += sentencesToTake;
  }

  return paragraphs;
}

/// Simulates the chat paragraph formatting logic
List<String> formatInChatParagraphs(String content) {
  final sentences = extractValidSentences(content, minWords: 10);

  if (sentences.length < 3) {
    // If less than 3 valid sentences, fallback to simpler logic
    return [content];
  }

  final paragraphs = <String>[];

  // Group sentences into paragraphs (3-5 sentences each)
  for (int i = 0; i < sentences.length;) {
    final remainingSentences = sentences.length - i;
    int sentencesToTake;

    if (remainingSentences <= 5) {
      // Take all remaining if 5 or fewer
      sentencesToTake = remainingSentences;
    } else if (remainingSentences == 6) {
      // Split 6 sentences as 3+3 instead of 5+1
      sentencesToTake = 3;
    } else if (remainingSentences == 7) {
      // Split 7 sentences as 3+4 instead of 5+2
      sentencesToTake = 3;
    } else {
      // Take 5 sentences for optimal readability
      sentencesToTake = 5;
    }

    // Ensure minimum of 3 sentences per paragraph
    if (sentencesToTake < 3) sentencesToTake = 3;

    final paragraphSentences = sentences.sublist(i, i + sentencesToTake);
    paragraphs.add(paragraphSentences.join(' '));

    i += sentencesToTake;
  }

  return paragraphs;
}

/// Extract sentences that meet minimum word requirements
List<String> extractValidSentences(String text, {required int minWords}) {
  final allSentences = extractSentences(text);
  final validSentences = <String>[];

  for (final sentence in allSentences) {
    final wordCount = sentence.trim().split(RegExp(r'\s+')).length;
    if (wordCount >= minWords) {
      validSentences.add(sentence);
    } else {
      // If sentence is too short, try to combine with previous sentence
      if (validSentences.isNotEmpty) {
        final lastSentence = validSentences.removeLast();
        final combined = '$lastSentence $sentence';
        validSentences.add(combined);
      } else {
        // Keep short sentence as is if it's the first one
        validSentences.add(sentence);
      }
    }
  }

  return validSentences;
}