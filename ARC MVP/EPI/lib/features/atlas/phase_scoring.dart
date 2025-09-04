import 'dart:math' as math;

/// Phase scoring system that provides probability scores (0-1) for all phases
/// based on emotion, reason, text content, and selected keywords.
/// 
/// This is used by the PhaseTracker for gradual phase evolution rather than
/// binary phase recommendations.
class PhaseScoring {
  /// All available phases in the system
  static const List<String> allPhases = [
    'Discovery',
    'Expansion', 
    'Transition',
    'Consolidation',
    'Recovery',
    'Breakthrough',
  ];

  /// Calculate probability scores for all phases based on entry data
  /// Returns a map of phase -> score (0.0 to 1.0)
  static Map<String, double> score({
    required String emotion,
    required String reason,
    required String text,
    List<String>? selectedKeywords,
  }) {
    final e = emotion.toLowerCase();
    final r = reason.toLowerCase();
    final t = text.toLowerCase();
    
    // Initialize all phases with base score
    final Map<String, double> scores = {
      for (final phase in allPhases) phase: 0.0,
    };

    // 1. Keyword-based scoring (highest priority when available)
    if (selectedKeywords != null && selectedKeywords.isNotEmpty) {
      final keywordScores = _scoreFromKeywords(selectedKeywords);
      // Blend keyword scores with emotion/text scores (70% keywords, 30% other)
      for (final phase in allPhases) {
        scores[phase] = (keywordScores[phase]! * 0.7) + (scores[phase]! * 0.3);
      }
    }

    // 2. Emotion-based scoring
    final emotionScores = _scoreFromEmotion(e);
    for (final phase in allPhases) {
      scores[phase] = math.max(scores[phase]!, emotionScores[phase]!);
    }

    // 3. Content-based scoring
    final contentScores = _scoreFromContent(t, r);
    for (final phase in allPhases) {
      scores[phase] = math.max(scores[phase]!, contentScores[phase]!);
    }

    // 4. Text length and structure scoring
    final structureScores = _scoreFromStructure(t);
    for (final phase in allPhases) {
      scores[phase] = math.max(scores[phase]!, structureScores[phase]!);
    }

    // 5. Normalize scores to ensure they sum to a reasonable total
    _normalizeScores(scores);

    return scores;
  }

  /// Score phases based on selected keywords
  static Map<String, double> _scoreFromKeywords(List<String> keywords) {
    final keywordSet = keywords.map((k) => k.toLowerCase()).toSet();
    
    // Define keyword mappings for each phase (from existing PhaseRecommender)
    final Map<String, Set<String>> phaseKeywords = {
      'Recovery': {
        'stressed', 'anxious', 'tired', 'overwhelmed', 'frustrated', 'worried',
        'healing', 'calm', 'peaceful', 'relaxed', 'rest', 'breathe', 'gentle',
        'restore', 'balance', 'meditation', 'mindfulness', 'health'
      },
      'Discovery': {
        'curious', 'excited', 'hopeful', 'learning', 'goals', 'dreams', 
        'growth', 'discovery', 'exploration', 'new', 'beginning',
        'wonder', 'question', 'explore', 'creativity', 'spirituality'
      },
      'Expansion': {
        'grateful', 'joyful', 'confident', 'energized', 'happy', 'blessed',
        'opportunity', 'progress', 'abundance', 'flourishing',
        'reach', 'possibility', 'energy', 'outward', 'more', 'bigger'
      },
      'Transition': {
        'uncertain', 'change', 'challenge', 'transition', 'work', 'family',
        'relationship', 'career', 'move', 'leaving', 'switch', 'patterns',
        'habits', 'setback', 'between'
      },
      'Consolidation': {
        'reflection', 'awareness', 'patterns', 'habits', 'routine', 'stable',
        'organize', 'weave', 'integrate', 'ground', 'settle', 'consistency',
        'home', 'friendship', 'consolidate'
      },
      'Breakthrough': {
        'clarity', 'insight', 'breakthrough', 'transformation', 'wisdom',
        'epiphany', 'suddenly', 'realized', 'understand', 'aha', 'purpose',
        'threshold', 'crossing', 'barrier', 'momentum', 'coherent', 'alive',
        'unlock', 'path', 'crisp', 'landing'
      },
    };

    final Map<String, double> scores = {};
    
    for (final phase in allPhases) {
      final phaseSet = phaseKeywords[phase]!;
      final matches = keywordSet.intersection(phaseSet).length;
      
      if (matches == 0) {
        scores[phase] = 0.0;
      } else {
        // Calculate score based on both coverage and relevance
        final coverage = matches / phaseSet.length; // How much of the phase's keywords are present
        final relevance = matches / keywordSet.length; // How much of user's keywords match this phase
        
        // Weighted combination: 60% coverage, 40% relevance
        scores[phase] = (coverage * 0.6) + (relevance * 0.4);
      }
    }
    
    return scores;
  }

  /// Score phases based on emotion
  static Map<String, double> _scoreFromEmotion(String emotion) {
    final Map<String, double> scores = {
      for (final phase in allPhases) phase: 0.0,
    };

    // Strong emotion indicators (high confidence)
    if (['depressed', 'tired', 'stressed', 'anxious', 'angry'].any(emotion.contains)) {
      scores['Recovery'] = 0.9;
    } else if (['excited', 'curious', 'hopeful'].any(emotion.contains)) {
      scores['Discovery'] = 0.9;
    } else if (['happy', 'blessed', 'grateful', 'energized', 'relaxed'].any(emotion.contains)) {
      scores['Expansion'] = 0.9;
    } else {
      // Weaker emotion indicators (medium confidence)
      if (emotion.contains('uncertain') || emotion.contains('confused')) {
        scores['Transition'] = 0.6;
      } else if (emotion.contains('content') || emotion.contains('peaceful')) {
        scores['Consolidation'] = 0.6;
      } else if (emotion.contains('amazed') || emotion.contains('surprised')) {
        scores['Breakthrough'] = 0.6;
      } else {
        // Default to Discovery for unknown emotions
        scores['Discovery'] = 0.3;
      }
    }

    return scores;
  }

  /// Score phases based on text content and reason
  static Map<String, double> _scoreFromContent(String text, String reason) {
    final Map<String, double> scores = {
      for (final phase in allPhases) phase: 0.0,
    };

    bool has(String keyword) => text.contains(keyword);

    // Transition indicators
    if (['relationship', 'work', 'school', 'family'].any(reason.contains) &&
        (has('switch') || has('move') || has('change') || has('leaving') || has('transition'))) {
      scores['Transition'] = 0.8;
    }

    // Consolidation indicators
    final consolidationKeywords = ['integrate', 'organize', 'weave', 'routine', 'habit',
        'ground', 'settle', 'stable', 'consistency'];
    final consolidationMatches = consolidationKeywords.where(has).length;
    if (consolidationMatches > 0) {
      scores['Consolidation'] = (consolidationMatches / consolidationKeywords.length) * 0.8;
    }

    // Breakthrough indicators
    final breakthroughKeywords = ['epiphany', 'breakthrough', 'suddenly', 'realized',
        'clarity', 'insight', 'understand', 'aha'];
    final breakthroughMatches = breakthroughKeywords.where(has).length;
    if (breakthroughMatches > 0) {
      scores['Breakthrough'] = (breakthroughMatches / breakthroughKeywords.length) * 0.8;
    }

    // Recovery indicators (beyond emotion)
    final recoveryKeywords = ['rest', 'heal', 'recover', 'gentle', 'breathe',
        'peace', 'calm', 'restore'];
    final recoveryMatches = recoveryKeywords.where(has).length;
    if (recoveryMatches > 0) {
      scores['Recovery'] = (recoveryMatches / recoveryKeywords.length) * 0.7;
    }

    // Expansion indicators
    final expansionKeywords = ['grow', 'expand', 'reach', 'possibility', 'energy',
        'outward', 'more', 'bigger', 'increase'];
    final expansionMatches = expansionKeywords.where(has).length;
    if (expansionMatches > 0) {
      scores['Expansion'] = (expansionMatches / expansionKeywords.length) * 0.7;
    }

    // Discovery indicators
    final discoveryKeywords = ['explore', 'new', 'curiosity', 'wonder', 'question',
        'learn', 'discover', 'beginning', 'start'];
    final discoveryMatches = discoveryKeywords.where(has).length;
    if (discoveryMatches > 0) {
      scores['Discovery'] = (discoveryMatches / discoveryKeywords.length) * 0.7;
    }

    return scores;
  }

  /// Score phases based on text structure and length
  static Map<String, double> _scoreFromStructure(String text) {
    final Map<String, double> scores = {
      for (final phase in allPhases) phase: 0.0,
    };

    final wordCount = text.split(' ').length;
    final charCount = text.length;

    // Short entries tend to be quick thoughts or feelings
    if (charCount < 20) {
      scores['Expansion'] = 0.4; // Quick positive thoughts
    } else if (charCount > 100) {
      // Longer entries suggest deeper processing
      scores['Consolidation'] = 0.4;
    } else if (wordCount < 10) {
      // Brief but not too short - could be transitional
      scores['Transition'] = 0.3;
    } else {
      // Medium length - balanced processing
      scores['Discovery'] = 0.2;
    }

    return scores;
  }

  /// Normalize scores to ensure they sum to a reasonable total and no single score dominates
  static void _normalizeScores(Map<String, double> scores) {
    final total = scores.values.fold(0.0, (sum, score) => sum + score);
    
    // If total is too high, scale down
    if (total > 2.0) {
      final scaleFactor = 2.0 / total;
      for (final phase in allPhases) {
        scores[phase] = scores[phase]! * scaleFactor;
      }
    }
    
    // Ensure no single score is too high (cap at 0.95)
    for (final phase in allPhases) {
      scores[phase] = math.min(scores[phase]!, 0.95);
    }
    
    // Ensure minimum scores for phases that have some evidence
    for (final phase in allPhases) {
      if (scores[phase]! > 0.1) {
        scores[phase] = math.max(scores[phase]!, 0.2);
      }
    }
  }

  /// Get the highest scoring phase from a score map
  static String getHighestScoringPhase(Map<String, double> scores) {
    String highestPhase = 'Discovery';
    double highestScore = 0.0;
    
    for (final entry in scores.entries) {
      if (entry.value > highestScore) {
        highestScore = entry.value;
        highestPhase = entry.key;
      }
    }
    
    return highestPhase;
  }

  /// Get a summary of the scoring results for debugging
  static String getScoringSummary(Map<String, double> scores) {
    final sortedScores = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedScores
        .map((e) => '${e.key}: ${e.value.toStringAsFixed(3)}')
        .join(', ');
  }
}
