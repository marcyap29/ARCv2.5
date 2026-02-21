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
        // Emotional states
        'stressed', 'anxious', 'tired', 'exhausted', 'drained', 'burned out', 'depleted',
        'overwhelmed', 'frustrated', 'worried', 'sad', 'depressed', 'lonely', 'isolated',
        'vulnerable', 'fragile', 'hurt', 'pain', 'suffering', 'struggling', 'difficult',
        // Recovery actions and states
        'healing', 'recovering', 'restoring', 'rest', 'pause', 'break', 'retreat', 'withdraw',
        'calm', 'peaceful', 'relaxed', 'serene', 'tranquil', 'quiet', 'still', 'gentle',
        'breathe', 'meditation', 'mindfulness', 'self-care', 'therapy', 'support', 'help',
        'comfort', 'safe', 'protected', 'nurturing', 'caring', 'compassionate', 'kind',
        'balance', 'equilibrium', 'harmony', 'stability', 'foundation', 'grounding', 'centered',
        'renewal', 'recharge', 'reset', 'fresh start', 'beginning again', 'starting over',
        'health', 'wellness', 'wholeness', 'integration', 'acceptance', 'forgiveness', 'patience'
      },
      'Discovery': {
        // Curiosity and exploration
        'curious', 'curiosity', 'wonder', 'question', 'questions', 'explore', 'exploration',
        'discover', 'discovery', 'investigate', 'investigation', 'seek', 'seeking', 'search',
        'searching', 'adventure', 'adventurous', 'journey', 'quest', 'mission', 'purpose',
        // New beginnings
        'new', 'beginning', 'start', 'starting', 'fresh', 'first', 'initial', 'early',
        'dawn', 'birth', 'genesis', 'origin', 'seed', 'sprout', 'bud', 'embryo',
        // Learning and growth
        'learning', 'learn', 'study', 'studying', 'education', 'teach', 'teaching', 'knowledge',
        'wisdom', 'understanding', 'insight', 'awareness', 'consciousness', 'enlightenment',
        'goals', 'dreams', 'aspirations', 'hopes', 'hopeful', 'optimistic', 'positive',
        'growth', 'developing', 'development', 'evolving', 'evolution', 'progressing',
        // Excitement and anticipation
        'excited', 'excitement', 'enthusiastic', 'enthusiasm', 'eager', 'eagerness', 'anticipation',
        'thrilled', 'inspired', 'inspiration', 'motivated', 'motivation', 'driven', 'ambitious',
        // Creativity and spirituality
        'creativity', 'creative', 'imagination', 'imaginative', 'innovative', 'innovation',
        'spirituality', 'spiritual', 'sacred', 'divine', 'transcendent', 'mystical', 'mystery',
        'magic', 'awe', 'amazement', 'fascination', 'intrigue', 'interest'
      },
      'Expansion': {
        // Positive emotions
        'grateful', 'gratitude', 'thankful', 'appreciation', 'joyful', 'joy', 'happiness', 'happy',
        'blessed', 'blessing', 'fortunate', 'lucky', 'confident', 'confidence', 'self-assured',
        'energized', 'energy', 'vitality', 'vibrant', 'alive', 'lively', 'dynamic', 'active',
        'enthusiastic', 'enthusiasm', 'passionate', 'passion', 'excited', 'excitement',
        // Growth and abundance
        'growth', 'growing', 'expand', 'expanding', 'expansion', 'flourishing', 'thriving',
        'prosperous', 'prosperity', 'abundance', 'abundant', 'plenty', 'rich', 'wealthy',
        'success', 'successful', 'achievement', 'achieving', 'accomplishment', 'accomplishing',
        'progress', 'progressing', 'advancement', 'advancing', 'improvement', 'improving',
        // Opportunities and possibilities
        'opportunity', 'opportunities', 'possibility', 'possibilities', 'potential', 'promise',
        'promising', 'future', 'ahead', 'forward', 'onward', 'upward',
        'reach', 'reaching', 'stretching', 'extending', 'widening', 'broadening',
        // Outward movement
        'outward', 'external', 'outside', 'beyond', 'further', 'more', 'bigger', 'larger',
        'greater', 'increased', 'increasing', 'multiplying', 'amplifying',
        'amplified', 'enhanced', 'enhancing', 'boosted', 'boosting', 'elevated', 'elevating',
        'rising', 'ascending', 'climbing', 'soaring', 'flying', 'sailing', 'flowing'
      },
      'Transition': {
        // Uncertainty and change
        'uncertain', 'uncertainty', 'unclear', 'unfamiliar', 'unknown', 'unpredictable',
        'change', 'changing', 'shift', 'shifting', 'move', 'moving', 'transition', 'transforming',
        'transformation', 'metamorphosis', 'evolution', 'evolving', 'adaptation', 'adapting',
        // Challenges and difficulties
        'challenge', 'challenges', 'difficult', 'difficulty', 'struggle', 'struggling',
        'obstacle', 'obstacles', 'barrier', 'barriers', 'hurdle', 'hurdles', 'setback', 'setbacks',
        'trial', 'trials', 'test', 'testing', 'tribulation', 'tribulations', 'adversity',
        // Life domains
        'work', 'job', 'career', 'profession', 'employment', 'occupation', 'vocation',
        'family', 'relationships', 'relationship', 'partnership', 'marriage', 'divorce',
        'school', 'education', 'learning', 'study', 'academic', 'university', 'college',
        'home', 'house', 'residence', 'living', 'lifestyle', 'life', 'existence',
        // Movement and leaving
        'leaving', 'departing', 'exiting', 'abandoning', 'letting go', 'releasing',
        'switch', 'switching', 'swap', 'swapping', 'exchange', 'exchanging', 'trade', 'trading',
        'between', 'betwixt', 'liminal', 'threshold', 'doorway', 'gateway', 'bridge', 'crossing',
        // Patterns and habits
        'patterns', 'pattern', 'habits', 'habit', 'routine', 'routines', 'ritual', 'rituals',
        'cycle', 'cycles', 'rhythm', 'rhythms', 'flow', 'flows', 'current', 'currents',
        'phase', 'phases', 'stage', 'stages', 'period', 'periods', 'era', 'eras', 'epoch'
      },
      'Consolidation': {
        // Reflection and awareness
        'reflection', 'reflecting', 'reflective', 'contemplation', 'contemplating',
        'meditation', 'meditating', 'mindfulness', 'mindful', 'awareness', 'aware', 'conscious',
        'consciousness', 'presence', 'present', 'attentive', 'attention', 'focus', 'focused',
        'observation', 'observing', 'noticing', 'witnessing', 'witness',
        // Patterns and habits
        'patterns', 'pattern', 'habits', 'habit', 'routine', 'routines', 'ritual', 'rituals',
        'structure', 'structured', 'organization', 'organize', 'organizing', 'system', 'systems',
        'order', 'ordered', 'orderly', 'systematic', 'methodical', 'disciplined', 'discipline',
        // Stability and grounding
        'stable', 'stability', 'steadfast', 'steady', 'consistent', 'consistency', 'constant',
        'reliable', 'reliability', 'dependable', 'dependability', 'trustworthy', 'trust',
        'ground', 'grounded', 'grounding', 'rooted', 'rooting', 'anchored', 'anchoring',
        'settle', 'settling', 'settled', 'establish', 'establishing', 'established',
        'foundation', 'foundational', 'base', 'basis', 'core', 'center', 'centered',
        // Integration and weaving
        'integrate', 'integrating', 'integration', 'integrated', 'unify', 'unifying', 'unity',
        'unified', 'connect', 'connecting', 'connection', 'connected', 'link', 'linking', 'linked',
        'weave', 'weaving', 'woven', 'interweave', 'interweaving', 'interwoven', 'blend', 'blending',
        'blended', 'merge', 'merging', 'merged', 'combine', 'combining', 'combined', 'synthesize',
        'synthesizing', 'synthesized', 'harmonize', 'harmonizing', 'harmonized', 'balance', 'balanced',
        // Home and relationships
        'home', 'homely', 'homestead', 'dwelling', 'residence', 'residential', 'domestic',
        'friendship', 'friendships', 'friend', 'friends', 'companionship', 'companion', 'companions',
        'community', 'communities', 'belonging', 'belong', 'belonged', 'inclusion', 'included',
        'consolidate', 'consolidating', 'consolidation', 'consolidated', 'solidify', 'solidifying',
        'solidified', 'strengthen', 'strengthening', 'strengthened', 'reinforce', 'reinforcing',
        'reinforced', 'fortify', 'fortifying', 'fortified', 'secure', 'securing', 'secured'
      },
      'Breakthrough': {
        // Clarity and insight
        'clarity', 'clear', 'clearly', 'lucid', 'lucidity', 'transparent', 'transparency',
        'insight', 'insights', 'illumination', 'illuminated', 'enlightened', 'enlightenment',
        'understanding', 'understand', 'understood', 'comprehension', 'comprehend', 'comprehended',
        'realization', 'realize', 'realized', 'recognition', 'recognize', 'recognized',
        'awareness', 'aware', 'consciousness', 'conscious', 'awakening', 'awaken', 'awakened',
        // Epiphany and sudden realization
        'epiphany', 'epiphanies', 'revelation', 'revelations', 'revelatory', 'reveling',
        'suddenly', 'sudden', 'abrupt', 'abruptly', 'instant', 'instantly', 'instantaneous',
        'immediate', 'immediately', 'immediacy', 'spontaneous', 'spontaneously', 'spontaneity',
        'aha', 'eureka', 'lightbulb', 'click', 'clicked', 'snap', 'snapped', 'flash', 'flashed',
        // Transformation and breakthrough
        'breakthrough', 'breakthroughs', 'break through', 'breaking through', 'broke through',
        'transformation', 'transform', 'transforming', 'transformed', 'transcendence', 'transcend',
        'transcending', 'transcended', 'metamorphosis', 'metamorphose', 'metamorphosing',
        'evolution', 'evolve', 'evolving', 'evolved', 'revolution', 'revolutionary', 'revolutionize',
        'shift', 'shifting', 'shifted', 'paradigm shift', 'quantum leap', 'leap', 'leaping', 'leaped',
        // Wisdom and purpose
        'wisdom', 'wise', 'wisely', 'sagacity', 'sage', 'sagely', 'knowledge', 'knowing', 'know',
        'knowingness', 'gnosis', 'gnostic', 'intuition', 'intuitive', 'intuitively', 'instinct',
        'instinctive', 'instinctively', 'gut feeling', 'gut instinct', 'sixth sense',
        'purpose', 'purposed', 'purposive', 'meaning', 'meaningful', 'meaningfully', 'significance',
        'significant', 'significantly', 'importance', 'important', 'importantly', 'value', 'valuable',
        // Threshold and crossing
        'threshold', 'thresholds', 'doorway', 'doorways', 'gateway', 'gateways', 'portal', 'portals',
        'crossing', 'cross', 'crossed', 'bridge', 'bridges', 'bridging', 'bridged', 'passage',
        'passages', 'passing', 'passed', 'transition', 'transitions', 'transiting', 'transited',
        // Momentum and coherence
        'momentum', 'momentous', 'momentously', 'impetus', 'impulse', 'impulsive', 'impulsively',
        'drive', 'driving', 'driven', 'force', 'forces', 'forcing', 'forced', 'power', 'powerful',
        'powerfully', 'energy', 'energetic', 'energetically', 'vitality', 'vital', 'vitally',
        'coherent', 'coherence', 'coherently', 'cohesive', 'cohesion', 'cohesively',
        'unity', 'unify', 'unifying', 'integrated', 'integration', 'integrate', 'integrating',
        // Unlocking and path
        'unlock', 'unlocking', 'unlocked', 'unleash', 'unleashing', 'unleashed', 'release', 'releasing',
        'released', 'free', 'freedom', 'freed', 'liberate', 'liberating', 'liberated', 'liberation',
        'path', 'paths', 'way', 'ways', 'route', 'routes', 'road', 'roads', 'journey', 'journeys',
        'trail', 'trails', 'track', 'tracks', 'course', 'courses', 'direction', 'directions',
        // Alive and crisp
        'alive', 'lively', 'vivacious', 'vibrant', 'vibrance', 'vitalize',
        'vitalizing', 'vitalized', 'animate', 'animated', 'animation', 'energize', 'energizing',
        'energized', 'invigorate', 'invigorating', 'invigorated', 'revitalize', 'revitalizing',
        'revitalized', 'rejuvenate', 'rejuvenating', 'rejuvenated', 'refresh', 'refreshing', 'refreshed',
        'crisp', 'crisply', 'crispness', 'sharp', 'sharply', 'sharpness',
        'precise', 'precisely', 'precision', 'exact', 'exactly', 'exactness', 'definite', 'definitely',
        'definiteness', 'certain', 'certainly', 'certainty', 'sure', 'surely', 'sureness', 'confident',
        'confidence', 'confidently', 'assured', 'assuredly', 'assurance', 'landing', 'landed', 'arrived',
        'arrival', 'reached', 'reaching', 'attained', 'attaining', 'attainment', 'achieved', 'achieving',
        'achievement', 'accomplished', 'accomplishing', 'accomplishment', 'completed', 'completing',
        'completion', 'finished', 'finishing', 'finish', 'fulfilled', 'fulfilling', 'fulfillment'
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

    // Transition indicators - life changes and uncertainty
    final transitionReasonKeywords = ['relationship', 'work', 'job', 'career', 'school', 'family', 
        'home', 'move', 'moving', 'relocation'];
    final transitionActionKeywords = ['switch', 'switching', 'move', 'moving', 'change', 'changing',
        'leaving', 'departing', 'transition', 'transforming', 'shift', 'shifting', 'between',
        'uncertain', 'uncertainty', 'challenge', 'challenges', 'setback', 'setbacks'];
    
    final transitionReasonMatches = transitionReasonKeywords.where(reason.contains).length;
    final transitionActionMatches = transitionActionKeywords.where(has).length;
    if (transitionReasonMatches > 0 && transitionActionMatches > 0) {
      scores['Transition'] = 0.8;
    } else if (transitionActionMatches > 0) {
      scores['Transition'] = (transitionActionMatches / transitionActionKeywords.length) * 0.7;
    }

    // Consolidation indicators - reflection, stability, integration
    final consolidationKeywords = ['integrate', 'integrating', 'integration', 'organize', 'organizing',
        'organization', 'weave', 'weaving', 'routine', 'routines', 'habit', 'habits', 'pattern', 'patterns',
        'ground', 'grounded', 'grounding', 'settle', 'settling', 'settled', 'stable', 'stability',
        'consistency', 'consistent', 'reflection', 'reflecting', 'reflective', 'awareness', 'aware',
        'conscious', 'consciousness', 'mindful', 'mindfulness', 'presence', 'present', 'focus', 'focused',
        'structure', 'structured', 'order', 'ordered', 'system', 'systems', 'foundation', 'foundational',
        'home', 'friendship', 'friendships', 'community', 'belonging', 'consolidate', 'consolidating'];
    final consolidationMatches = consolidationKeywords.where(has).length;
    if (consolidationMatches > 0) {
      scores['Consolidation'] = (consolidationMatches / consolidationKeywords.length) * 0.8;
    }

    // Breakthrough indicators - clarity, insight, transformation
    final breakthroughKeywords = ['epiphany', 'epiphanies', 'breakthrough', 'breakthroughs',
        'suddenly', 'sudden', 'realized', 'realize', 'realization', 'clarity', 'clear', 'clearly',
        'insight', 'insights', 'understand', 'understanding', 'comprehend', 'comprehension', 'aha',
        'eureka', 'revelation', 'revelations', 'transformation', 'transform', 'transforming',
        'wisdom', 'wise', 'purpose', 'meaning', 'meaningful', 'threshold', 'thresholds', 'crossing',
        'cross', 'crossed', 'momentum', 'coherent', 'coherence', 'unlock', 'unlocking', 'unlocked',
        'path', 'paths', 'alive', 'lively', 'vibrant', 'crisp', 'landing', 'arrived', 'arrival',
        'achieved', 'achievement', 'accomplished', 'accomplishment', 'fulfilled', 'fulfillment'];
    final breakthroughMatches = breakthroughKeywords.where(has).length;
    if (breakthroughMatches > 0) {
      scores['Breakthrough'] = (breakthroughMatches / breakthroughKeywords.length) * 0.8;
    }

    // Recovery indicators - healing, rest, self-care
    final recoveryKeywords = ['rest', 'resting', 'rested', 'heal', 'healing', 'recover', 'recovering',
        'recovery', 'gentle', 'gently', 'breathe', 'breathing', 'breathed', 'peace', 'peaceful',
        'peacefully', 'calm', 'calmly', 'calmness', 'restore', 'restoring', 'restored', 'restoration',
        'balance', 'balanced', 'balancing', 'equilibrium', 'harmony', 'harmonious', 'meditation',
        'meditating', 'mindfulness', 'mindful', 'self-care', 'therapy', 'support', 'supported',
        'comfort', 'comfortable', 'comforting', 'safe', 'safety', 'protected', 'protection',
        'nurturing', 'nurture', 'caring', 'care', 'compassionate', 'compassion', 'kind', 'kindness',
        'renewal', 'renew', 'renewing', 'renewed', 'recharge', 'recharging', 'recharged', 'reset',
        'resetting', 'resetted', 'fresh start', 'beginning again', 'starting over', 'health', 'healthy',
        'wellness', 'well', 'wholeness', 'whole', 'integration', 'integrated', 'acceptance', 'accept',
        'accepting', 'accepted', 'forgiveness', 'forgive', 'forgiving', 'forgave', 'patience', 'patient'];
    final recoveryMatches = recoveryKeywords.where(has).length;
    if (recoveryMatches > 0) {
      scores['Recovery'] = (recoveryMatches / recoveryKeywords.length) * 0.7;
    }

    // Expansion indicators - growth, abundance, outward movement
    final expansionKeywords = ['grow', 'growing', 'growth', 'expand', 'expanding', 'expansion',
        'reach', 'reaching', 'reached', 'possibility', 'possibilities', 'possible', 'energy', 'energetic',
        'energized', 'outward', 'external', 'outside', 'beyond', 'further', 'more', 'bigger', 'larger',
        'greater', 'increase', 'increasing', 'increased', 'grateful', 'gratitude', 'thankful', 'joyful',
        'joy', 'happiness', 'happy', 'blessed', 'blessing', 'confident', 'confidence', 'vitality',
        'vibrant', 'alive', 'lively', 'dynamic', 'active', 'enthusiastic', 'enthusiasm', 'passionate',
        'passion', 'excited', 'excitement', 'opportunity', 'opportunities', 'progress', 'progressing',
        'progressed', 'abundance', 'abundant', 'flourishing', 'flourish', 'thriving', 'thrive', 'thrived',
        'prosperous', 'prosperity', 'success', 'successful', 'achievement', 'achieving', 'accomplishment',
        'accomplishing', 'improvement', 'improving', 'improved', 'multiplying', 'amplifying', 'amplified',
        'enhanced', 'enhancing', 'boosted', 'boosting', 'elevated', 'elevating', 'rising', 'ascending',
        'climbing', 'soaring', 'flying', 'sailing', 'flowing'];
    final expansionMatches = expansionKeywords.where(has).length;
    if (expansionMatches > 0) {
      scores['Expansion'] = (expansionMatches / expansionKeywords.length) * 0.7;
    }

    // Discovery indicators - curiosity, exploration, new beginnings
    final discoveryKeywords = ['explore', 'exploring', 'exploration', 'explored', 'new', 'newly',
        'curiosity', 'curious', 'wonder', 'wondering', 'wondered', 'question', 'questions', 'questioning',
        'questioned', 'learn', 'learning', 'learned', 'study', 'studying', 'studied', 'discover',
        'discovering', 'discovery', 'discovered', 'beginning', 'beginnings', 'begin', 'beginning',
        'start', 'starting', 'started', 'fresh', 'first', 'initial', 'early', 'dawn', 'birth', 'genesis',
        'origin', 'seed', 'sprout', 'bud', 'embryo', 'goals', 'dreams', 'aspirations', 'hopes', 'hopeful',
        'hoping', 'optimistic', 'optimism', 'positive', 'positivity', 'growth', 'developing', 'development',
        'evolving', 'evolution', 'progressing', 'excited', 'excitement', 'enthusiastic', 'enthusiasm',
        'eager', 'eagerness', 'anticipation', 'anticipating', 'thrilled', 'inspired', 'inspiration',
        'motivated', 'motivation', 'driven', 'ambitious', 'ambition', 'creativity', 'creative', 'imagination',
        'imaginative', 'innovative', 'innovation', 'spirituality', 'spiritual', 'sacred', 'divine',
        'transcendent', 'mystical', 'mystery', 'magic', 'magical', 'awe', 'amazement', 'fascination',
        'fascinated', 'intrigue', 'intrigued', 'interest', 'interested', 'interesting'];
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
    
    // Safety check: if all scores are zero (shouldn't happen), assign equal small scores
    final maxScore = scores.values.reduce(math.max);
    if (maxScore == 0.0) {
      // This shouldn't happen, but if it does, assign equal probability to all phases
      final equalScore = 1.0 / allPhases.length;
      for (final phase in allPhases) {
        scores[phase] = equalScore;
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

