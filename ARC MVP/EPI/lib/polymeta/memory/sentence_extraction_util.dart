// lib/polymeta/memory/sentence_extraction_util.dart
// Utility for extracting relevant sentences from text for attribution excerpts

/// Extract the most relevant 2-3 sentences from text based on query/keywords
/// Returns a string with the top sentences joined together
String extractRelevantSentences(String text, {String? query, List<String>? keywords, int maxSentences = 3}) {
  if (text.trim().isEmpty) {
    return text;
  }

  // Split text into sentences
  final sentences = _splitSentences(text);
  
  if (sentences.isEmpty) {
    return text.length > 200 ? '${text.substring(0, 200)}...' : text;
  }

  // If we have 3 or fewer sentences, return all of them
  if (sentences.length <= maxSentences) {
    return sentences.join(' ');
  }

  // Score sentences based on relevance
  final scoredSentences = <({String sentence, double score})>[];
  
  // Build query terms for matching
  final queryTerms = <String>{};
  if (query != null && query.isNotEmpty) {
    queryTerms.addAll(_extractKeywords(query));
  }
  if (keywords != null) {
    queryTerms.addAll(keywords.map((k) => k.toLowerCase()));
  }

  for (final sentence in sentences) {
    final score = _scoreSentence(sentence, queryTerms);
    scoredSentences.add((sentence: sentence, score: score));
  }

  // Sort by score (highest first)
  scoredSentences.sort((a, b) => b.score.compareTo(a.score));

  // Take top maxSentences sentences, but preserve original order if possible
  final topSentences = scoredSentences.take(maxSentences).toList();
  
  // Sort by original position to maintain context flow
  final sentenceIndices = <String, int>{};
  for (int i = 0; i < sentences.length; i++) {
    sentenceIndices[sentences[i]] = i;
  }
  
  topSentences.sort((a, b) {
    final indexA = sentenceIndices[a.sentence] ?? 0;
    final indexB = sentenceIndices[b.sentence] ?? 0;
    return indexA.compareTo(indexB);
  });

  // Join the top sentences
  final result = topSentences.map((s) => s.sentence).join(' ');
  
  // Limit total length to ~300 chars to keep it readable
  if (result.length > 300) {
    // Take first 300 chars and try to end at a sentence boundary
    final truncated = result.substring(0, 300);
    final lastPeriod = truncated.lastIndexOf('.');
    final lastQuestion = truncated.lastIndexOf('?');
    final lastExclamation = truncated.lastIndexOf('!');
    final lastSentenceEnd = [lastPeriod, lastQuestion, lastExclamation]
        .where((i) => i > 0)
        .fold<int>(-1, (max, i) => i > max ? i : max);
    
    if (lastSentenceEnd > 100) {
      // End at sentence boundary if we have enough content
      return '${truncated.substring(0, lastSentenceEnd + 1)}...';
    } else {
      return '$truncated...';
    }
  }

  return result;
}

/// Split text into sentences
List<String> _splitSentences(String text) {
  return text
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .split(RegExp(r'(?<=[\.\?\!])\s+'))
      .where((s) => s.trim().isNotEmpty)
      .map((s) => s.trim())
      .toList();
}

/// Extract keywords from query text (words longer than 3 chars)
Set<String> _extractKeywords(String query) {
  return query
      .toLowerCase()
      .split(RegExp(r'[^\w]+'))
      .where((w) => w.length > 3)
      .toSet();
}

/// Score a sentence based on keyword overlap with query terms
double _scoreSentence(String sentence, Set<String> queryTerms) {
  if (queryTerms.isEmpty) {
    // If no query terms, prefer earlier sentences (they're usually more important)
    return 0.5;
  }

  final sentenceLower = sentence.toLowerCase();
  final sentenceWords = _extractKeywords(sentenceLower);
  
  // Count keyword matches
  int matches = 0;
  for (final term in queryTerms) {
    if (sentenceWords.contains(term) || sentenceLower.contains(term)) {
      matches++;
    }
  }

  // Score based on match ratio
  final matchRatio = matches / queryTerms.length;
  
  // Boost score for sentences with multiple matches
  final boost = matches > 1 ? 0.2 : 0.0;
  
  return matchRatio + boost;
}

