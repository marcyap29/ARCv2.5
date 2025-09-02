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

  /// Determine phase based on selected keywords using semantic mapping
  static String? _getPhaseFromKeywords(List<String> keywords) {
    final keywordSet = keywords.map((k) => k.toLowerCase()).toSet();
    
    // Define keyword mappings for each phase
    final Map<String, Set<String>> phaseKeywords = {
      'Recovery': {
        'stressed', 'anxious', 'tired', 'overwhelmed', 'frustrated', 'worried',
        'healing', 'calm', 'peaceful', 'relaxed', 'rest', 'breathe', 'gentle',
        'restore', 'balance', 'meditation', 'mindfulness', 'health'
      },
      'Discovery': {
        'curious', 'excited', 'hopeful', 'learning', 'goals', 'dreams', 
        'growth', 'discovery', 'insight', 'exploration', 'new', 'beginning',
        'wonder', 'question', 'explore', 'creativity', 'spirituality'
      },
      'Expansion': {
        'grateful', 'joyful', 'confident', 'energized', 'happy', 'blessed',
        'opportunity', 'progress', 'breakthrough', 'transformation', 'wisdom',
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
        'epiphany', 'suddenly', 'realized', 'understand', 'aha', 'purpose'
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
      
      final topPhase = sortedPhases.first;
      
      // Only return a phase if it has a meaningful score (at least 1 keyword match)
      if (topPhase.value >= 1.0) {
        return topPhase.key;
      }
    }
    
    return null; // Fall back to emotion/text analysis
  }
}