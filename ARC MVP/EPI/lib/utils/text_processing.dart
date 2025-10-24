// lib/utils/text_processing.dart
// Text processing utilities for keyword extraction and analysis

import 'dart:math' as math;

/// Utility class for text processing and keyword extraction
class TextProcessing {
  // Stop words to filter out (common words with little semantic value)
  static const Set<String> stopWords = {
    // Articles
    'the', 'a', 'an',
    // Conjunctions
    'and', 'but', 'or', 'nor', 'so', 'yet',
    // Prepositions
    'in', 'on', 'at', 'to', 'for', 'of', 'with', 'from', 'by', 'about',
    'into', 'through', 'during', 'before', 'after', 'above', 'below',
    'between', 'under', 'over',
    // Pronouns
    'i', 'you', 'he', 'she', 'it', 'we', 'they', 'them', 'their', 'your',
    'his', 'her', 'its', 'our', 'my', 'me', 'him', 'us',
    // Common verbs
    'is', 'am', 'are', 'was', 'were', 'be', 'been', 'being',
    'have', 'has', 'had', 'having', 'do', 'does', 'did', 'doing',
    'will', 'would', 'could', 'should', 'may', 'might', 'must', 'can',
    // Others
    'that', 'this', 'these', 'those', 'what', 'which', 'who', 'whom',
    'when', 'where', 'why', 'how', 'all', 'each', 'every', 'both',
    'few', 'more', 'most', 'some', 'such', 'no', 'not', 'only', 'own',
    'same', 'than', 'too', 'very', 'just', 'now', 'then', 'here', 'there',
    'also', 'well', 'even', 'still', 'however', 'although', 'though',
    // Common journal words
    'feel', 'felt', 'feeling', 'think', 'thought', 'thinking', 'want', 'wanted',
    'need', 'needed', 'like', 'liked', 'know', 'knew', 'today', 'yesterday',
    'tomorrow', 'day', 'week', 'month', 'year', 'time', 'times', 'thing',
    'things', 'really', 'actually', 'basically', 'literally',
  };

  /// Extract words from text, normalized and filtered
  static List<String> extractWords(String text, {
    int minLength = 3,
    int maxLength = 25,
    bool filterStopWords = true,
  }) {
    // Convert to lowercase and extract words
    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ') // Remove punctuation
        .split(RegExp(r'\s+'))
        .where((word) => word.length >= minLength && word.length <= maxLength)
        .toList();

    if (filterStopWords) {
      return words.where((word) => !stopWords.contains(word)).toList();
    }

    return words;
  }

  /// Calculate TF (Term Frequency) for a word in a document
  /// TF = (count of word in document) / (total words in document)
  static double termFrequency(String word, List<String> documentWords) {
    if (documentWords.isEmpty) return 0.0;

    final count = documentWords.where((w) => w == word).length;
    return count / documentWords.length;
  }

  /// Calculate IDF (Inverse Document Frequency) for a word across documents
  /// IDF = log(total documents / documents containing word)
  static double inverseDocumentFrequency(
    String word,
    List<List<String>> allDocuments,
  ) {
    if (allDocuments.isEmpty) return 0.0;

    final documentsContainingWord = allDocuments
        .where((doc) => doc.contains(word))
        .length;

    if (documentsContainingWord == 0) return 0.0;

    return math.log(allDocuments.length / documentsContainingWord);
  }

  /// Calculate TF-IDF score for a word
  /// TF-IDF = TF * IDF
  /// Higher scores indicate more important/distinctive words
  static double tfidf(
    String word,
    List<String> documentWords,
    List<List<String>> allDocuments,
  ) {
    final tf = termFrequency(word, documentWords);
    final idf = inverseDocumentFrequency(word, allDocuments);
    return tf * idf;
  }

  /// Extract top keywords from a collection of documents using TF-IDF
  /// Returns map of {word: average TF-IDF score across documents}
  static Map<String, double> extractKeywordsWithTfidf(
    List<List<String>> allDocuments, {
    int topN = 50,
    double minScore = 0.0,
  }) {
    if (allDocuments.isEmpty) return {};

    // Get all unique words
    final allWords = <String>{};
    for (final doc in allDocuments) {
      allWords.addAll(doc);
    }

    // Calculate average TF-IDF for each word
    final wordScores = <String, double>{};
    for (final word in allWords) {
      double totalScore = 0.0;
      int documentCount = 0;

      for (final doc in allDocuments) {
        if (doc.contains(word)) {
          totalScore += tfidf(word, doc, allDocuments);
          documentCount++;
        }
      }

      if (documentCount > 0) {
        final avgScore = totalScore / documentCount;
        if (avgScore >= minScore) {
          wordScores[word] = avgScore;
        }
      }
    }

    // Sort by score and return top N
    final sortedWords = wordScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Map.fromEntries(sortedWords.take(topN));
  }

  /// Calculate word frequency across all documents
  static Map<String, int> calculateWordFrequency(List<List<String>> allDocuments) {
    final frequency = <String, int>{};

    for (final doc in allDocuments) {
      for (final word in doc) {
        frequency[word] = (frequency[word] ?? 0) + 1;
      }
    }

    return frequency;
  }

  /// Extract excerpt (context) containing a keyword from text
  /// Returns a short excerpt showing the keyword in context
  static String extractExcerpt(String text, String keyword, {
    int contextWords = 5,
    int maxLength = 100,
  }) {
    final words = text.split(RegExp(r'\s+'));
    final keywordLower = keyword.toLowerCase();

    // Find first occurrence of keyword
    final keywordIndex = words.indexWhere(
      (word) => word.toLowerCase().contains(keywordLower),
    );

    if (keywordIndex == -1) return '';

    // Extract context around keyword
    final startIndex = math.max(0, keywordIndex - contextWords);
    final endIndex = math.min(words.length, keywordIndex + contextWords + 1);

    var excerpt = words.sublist(startIndex, endIndex).join(' ');

    // Truncate if too long
    if (excerpt.length > maxLength) {
      excerpt = excerpt.substring(0, maxLength) + '...';
    }

    // Add ellipsis if not at start/end
    if (startIndex > 0) excerpt = '...$excerpt';
    if (endIndex < words.length && !excerpt.endsWith('...')) excerpt = '$excerpt...';

    return excerpt.trim();
  }

  /// Calculate recency score for a keyword based on when it was last used
  /// Returns score between 0.0 (old) and 1.0 (very recent)
  static double calculateRecencyScore(
    DateTime lastUsed,
    DateTime referenceDate, {
    int halfLifeDays = 30,
  }) {
    final daysSinceLastUse = referenceDate.difference(lastUsed).inDays;

    // Exponential decay: score = 0.5^(days / halfLifeDays)
    return math.pow(0.5, daysSinceLastUse / halfLifeDays).toDouble();
  }

  /// Normalize text for comparison (lowercase, trim, etc.)
  static String normalize(String text) {
    return text.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Check if two words are similar (basic stemming/matching)
  static bool areSimilar(String word1, String word2) {
    // Exact match
    if (word1 == word2) return true;

    // One contains the other (for basic stemming)
    if (word1.length > 4 && word2.length > 4) {
      return word1.contains(word2) || word2.contains(word1);
    }

    return false;
  }

  /// Simple word stemming (removes common suffixes)
  static String stem(String word) {
    // Remove common English suffixes
    const suffixes = ['ing', 'ed', 'er', 'est', 'ly', 's', 'es', 'ies'];

    for (final suffix in suffixes) {
      if (word.endsWith(suffix) && word.length > suffix.length + 2) {
        return word.substring(0, word.length - suffix.length);
      }
    }

    return word;
  }
}
