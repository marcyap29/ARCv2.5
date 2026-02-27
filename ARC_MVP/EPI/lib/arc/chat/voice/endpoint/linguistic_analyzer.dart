/// Linguistic Analyzer
/// 
/// Analyzes transcript completeness using linguistic cues:
/// - Sentence-ending punctuation
/// - Incomplete trailing patterns ("and", "but", "because", etc.)
/// - Complete thought patterns ("that's it", "that's all", "I think")
/// - Returns confidence: definitelyComplete, definitelyIncomplete, or uncertain
library;

import 'package:flutter/foundation.dart';

/// Completion confidence levels
enum CompletionConfidence {
  definitelyComplete,    // High confidence the speaker is done
  definitelyIncomplete,  // High confidence the speaker will continue
  uncertain,             // Not sure - rely on silence threshold
}

/// Linguistic Analyzer
/// 
/// Analyzes transcripts to determine if speech is complete
class LinguisticAnalyzer {
  /// Incomplete trailing patterns (speaker will likely continue)
  static const _incompletePatterns = [
    'and',
    'but',
    'so',
    'because',
    'like',
    'um',
    'uh',
    'you know',
    'i mean',
    'the',
    'a',
    'an',
    'or',
    'if',
    'when',
    'where',
    'which',
    'that',
    'with',
    'for',
    'to',
  ];
  
  /// Complete thought patterns (speaker is done)
  static const _completePatterns = [
    'that\'s it',
    'that\'s all',
    'i think',
    'i guess',
    'right now',
    'for now',
    'at the moment',
    'that\'s what',
    'that\'s how',
    'you know what i mean',
    'does that make sense',
    'yeah',
    'okay',
    'alright',
    'done',
    'finished',
    'that\'s everything',
  ];
  
  /// Analyze transcript for completeness
  CompletionConfidence analyzeCompleteness(String transcript) {
    if (transcript.trim().isEmpty) {
      return CompletionConfidence.uncertain;
    }
    
    final trimmed = transcript.trim().toLowerCase();
    
    // Check 1: Ends with sentence-ending punctuation
    if (_hasSentenceEndingPunctuation(trimmed)) {
      debugPrint('LinguisticAnalyzer: Has sentence-ending punctuation');
      return CompletionConfidence.definitelyComplete;
    }
    
    // Check 2: Ends with incomplete pattern
    for (final pattern in _incompletePatterns) {
      if (_endsWithPattern(trimmed, pattern)) {
        debugPrint('LinguisticAnalyzer: Ends with incomplete pattern "$pattern"');
        return CompletionConfidence.definitelyIncomplete;
      }
    }
    
    // Check 3: Ends with complete thought pattern
    for (final pattern in _completePatterns) {
      if (_endsWithPattern(trimmed, pattern)) {
        debugPrint('LinguisticAnalyzer: Ends with complete pattern "$pattern"');
        return CompletionConfidence.definitelyComplete;
      }
    }
    
    // Check 4: Multiple sentences suggest completeness
    if (_hasMultipleSentences(trimmed)) {
      debugPrint('LinguisticAnalyzer: Has multiple sentences');
      return CompletionConfidence.definitelyComplete;
    }
    
    // Check 5: Very short utterances are usually incomplete
    final wordCount = trimmed.split(RegExp(r'\s+')).length;
    if (wordCount < 3) {
      debugPrint('LinguisticAnalyzer: Too short ($wordCount words)');
      return CompletionConfidence.uncertain;
    }
    
    // Check 6: Question marks usually indicate completeness
    if (trimmed.contains('?')) {
      debugPrint('LinguisticAnalyzer: Contains question mark');
      return CompletionConfidence.definitelyComplete;
    }
    
    // Default: uncertain - rely on silence threshold
    debugPrint('LinguisticAnalyzer: Uncertain about completeness');
    return CompletionConfidence.uncertain;
  }
  
  /// Check if transcript ends with sentence-ending punctuation
  bool _hasSentenceEndingPunctuation(String text) {
    return text.endsWith('.') || 
           text.endsWith('!') || 
           text.endsWith('?');
  }
  
  /// Check if transcript ends with a specific pattern
  bool _endsWithPattern(String text, String pattern) {
    // Check for exact match at end
    if (text.endsWith(pattern)) {
      // Make sure it's a word boundary (not part of larger word)
      if (text.length == pattern.length) {
        return true;
      }
      
      final beforePattern = text.substring(0, text.length - pattern.length);
      if (beforePattern.endsWith(' ') || beforePattern.endsWith('\n')) {
        return true;
      }
    }
    
    // Check for pattern followed by punctuation
    if (text.endsWith('$pattern.') || 
        text.endsWith('$pattern,') || 
        text.endsWith('$pattern!') ||
        text.endsWith('$pattern?')) {
      return true;
    }
    
    return false;
  }
  
  /// Check if transcript contains multiple sentences
  bool _hasMultipleSentences(String text) {
    // Count sentence endings
    final periods = '.'.allMatches(text).length;
    final exclamations = '!'.allMatches(text).length;
    final questions = '?'.allMatches(text).length;
    
    final totalSentenceEndings = periods + exclamations + questions;
    
    return totalSentenceEndings >= 2;
  }
  
  /// Estimate sentence completeness score (0.0 to 1.0)
  double estimateCompleteness(String transcript) {
    final confidence = analyzeCompleteness(transcript);
    
    switch (confidence) {
      case CompletionConfidence.definitelyComplete:
        return 1.0;
      case CompletionConfidence.definitelyIncomplete:
        return 0.0;
      case CompletionConfidence.uncertain:
        return 0.5;
    }
  }
  
  /// Get detailed analysis for debugging
  Map<String, dynamic> getDetailedAnalysis(String transcript) {
    final trimmed = transcript.trim().toLowerCase();
    
    return {
      'has_punctuation': _hasSentenceEndingPunctuation(trimmed),
      'has_multiple_sentences': _hasMultipleSentences(trimmed),
      'word_count': trimmed.split(RegExp(r'\s+')).length,
      'ends_with_incomplete': _incompletePatterns.any((p) => _endsWithPattern(trimmed, p)),
      'ends_with_complete': _completePatterns.any((p) => _endsWithPattern(trimmed, p)),
      'confidence': analyzeCompleteness(transcript).toString(),
      'completeness_score': estimateCompleteness(transcript),
    };
  }
}
