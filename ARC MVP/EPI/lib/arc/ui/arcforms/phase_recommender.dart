import 'package:my_app/prism/atlas/phase/phase_scoring.dart';

class PhaseRecommender {
  static bool _lastRecommendationWasKeywordBased = false;
  
  static String recommend({
    required String emotion,
    required String reason,
    required String text,
    List<String>? selectedKeywords,
  }) {
    final e = emotion.toLowerCase();
    final r = reason.toLowerCase();
    final t = text.toLowerCase();
    
    // FIRST: Check for explicit phase hashtags in content (highest priority)
    final phaseHashtag = _extractPhaseHashtag(text);
    if (phaseHashtag != null) {
      print('DEBUG: PhaseRecommender - Found explicit phase hashtag: $phaseHashtag');
      _lastRecommendationWasKeywordBased = false;
      return phaseHashtag;
    }
    
    // Keyword-based phase detection (prioritized when keywords are available)
    if (selectedKeywords != null && selectedKeywords.isNotEmpty) {
      final keywordPhase = _getPhaseFromKeywords(selectedKeywords);
      if (keywordPhase != null) {
        _lastRecommendationWasKeywordBased = true;
        return keywordPhase;
      }
    }
    
    _lastRecommendationWasKeywordBased = false;
    
    // Strong emotion-based recommendations
    if (['depressed', 'tired', 'stressed', 'anxious', 'angry'].any(e.contains)) {
      return 'Recovery';
    }
    if (['excited', 'curious', 'hopeful'].any(e.contains)) {
      return 'Discovery';
    }
    if (['happy', 'blessed', 'grateful', 'energized', 'relaxed'].any(e.contains)) {
      return 'Expansion';
    }
    
    // Content-based analysis
    bool has(String keyword) => t.contains(keyword);
    
    // Transition indicators
    if (['relationship', 'work', 'school', 'family'].any(r.contains) &&
        (has('switch') || has('move') || has('change') || has('leaving') || has('transition'))) {
      return 'Transition';
    }
    
    // Consolidation indicators
    if (has('integrate') || has('organize') || has('weave') || has('routine') || has('habit') ||
        has('ground') || has('settle') || has('stable') || has('consistency')) {
      return 'Consolidation';
    }
    
    // Breakthrough indicators
    if (has('epiphany') || has('breakthrough') || has('suddenly') || has('realized') ||
        has('clarity') || has('insight') || has('understand') || has('aha')) {
      return 'Breakthrough';
    }
    
    // Recovery indicators (beyond emotion)
    if (has('rest') || has('heal') || has('recover') || has('gentle') || has('breathe') ||
        has('peace') || has('calm') || has('restore')) {
      return 'Recovery';
    }
    
    // Expansion indicators
    if (has('grow') || has('expand') || has('reach') || has('possibility') || has('energy') ||
        has('outward') || has('more') || has('bigger') || has('increase')) {
      return 'Expansion';
    }
    
    // Discovery indicators
    if (has('explore') || has('new') || has('curiosity') || has('wonder') || has('question') ||
        has('learn') || has('discover') || has('beginning') || has('start')) {
      return 'Discovery';
    }
    
    // More balanced default logic based on overall content tone
    if (t.length < 20) {
      // Short entries tend to be quick thoughts or feelings
      return 'Expansion';
    } else if (t.length > 100) {
      // Longer entries suggest deeper processing
      return 'Consolidation';
    } else if (t.split(' ').length < 10) {
      // Brief but not too short - could be transitional
      return 'Transition';
    }
    
    // Fallback to Discovery only if nothing else matches
    return 'Discovery';
  }

  static String rationale(String phase) {
    if (_lastRecommendationWasKeywordBased) {
      return 'Based on your selected keywords and emotional context.';
    }
    
    switch (phase) {
      case 'Recovery':
        return 'Your emotion suggests rest and repair.';
      case 'Discovery':
        return 'Your emotion points toward curiosity and exploration.';
      case 'Expansion':
        return 'Your tone suggests growth and outward energy.';
      case 'Transition':
        return 'Your words hint at change and movement between places.';
      case 'Consolidation':
        return 'You mentioned integration and grounding.';
      case 'Breakthrough':
        return 'You referenced sudden clarity or insight.';
      default:
        return 'A gentle starting place for this moment.';
    }
  }
  
  /// Check if the last recommendation was based on keywords
  static bool get wasLastRecommendationKeywordBased => _lastRecommendationWasKeywordBased;

  /// Extract phase hashtag from text (e.g., #discovery, #transition)
  static String? _extractPhaseHashtag(String text) {
    // Match hashtags followed by phase names (case-insensitive)
    final hashtagPattern = RegExp(r'#(discovery|expansion|transition|consolidation|recovery|breakthrough)', caseSensitive: false);
    final match = hashtagPattern.firstMatch(text);
    
    if (match != null) {
      final phaseName = match.group(1)?.toLowerCase();
      if (phaseName != null) {
        // Capitalize first letter to match expected format
        return phaseName[0].toUpperCase() + phaseName.substring(1);
      }
    }
    
    return null;
  }

  /// Determine phase based on selected keywords using semantic mapping
  static String? _getPhaseFromKeywords(List<String> keywords) {
    final keywordSet = keywords.map((k) => k.toLowerCase()).toSet();
    print('DEBUG: PhaseRecommender analyzing keywords: $keywordSet');
    
    // Define keyword mappings for each phase
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
    
    // Score each phase based on keyword matches
    final Map<String, double> phaseScores = {};
    
    for (final phase in phaseKeywords.keys) {
      final phaseSet = phaseKeywords[phase]!;
      final matches = keywordSet.intersection(phaseSet).length;
      final coverage = matches / phaseSet.length;
      final relevance = matches / keywordSet.length;
      
      // Combined score: keyword matches + coverage + relevance
      phaseScores[phase] = matches + (coverage * 0.5) + (relevance * 2.0);
    }
    
    // Find the phase with the highest score
    if (phaseScores.isNotEmpty) {
      final sortedPhases = phaseScores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      print('DEBUG: Phase scores: $phaseScores');
      final topPhase = sortedPhases.first;
      print('DEBUG: Top phase: ${topPhase.key} with score: ${topPhase.value}');
      
      // Only return a phase if it has a meaningful score (at least 1 keyword match)
      if (topPhase.value >= 1.0) {
        print('DEBUG: Returning keyword-based phase: ${topPhase.key}');
        return topPhase.key;
      } else {
        print('DEBUG: Score too low (${topPhase.value}), falling back to text analysis');
      }
    }
    
    return null; // Fall back to emotion/text analysis
  }

  /// Get probability scores for all phases based on entry data
  /// This delegates to PhaseScoring for consistency with the phase stability system
  static Map<String, double> score({
    required String emotion,
    required String reason,
    required String text,
    List<String>? selectedKeywords,
  }) {
    return PhaseScoring.score(
      emotion: emotion,
      reason: reason,
      text: text,
      selectedKeywords: selectedKeywords,
    );
  }

  /// Get the highest scoring phase from a score map
  /// This is a convenience method that delegates to PhaseScoring
  static String getHighestScoringPhase(Map<String, double> scores) {
    return PhaseScoring.getHighestScoringPhase(scores);
  }

  /// Get a summary of the scoring results for debugging
  /// This is a convenience method that delegates to PhaseScoring
  static String getScoringSummary(Map<String, double> scores) {
    return PhaseScoring.getScoringSummary(scores);
  }
}