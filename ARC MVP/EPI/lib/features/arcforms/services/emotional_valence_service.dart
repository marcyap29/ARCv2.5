import 'dart:ui';

/// Service for determining emotional valence and color temperature of words
class EmotionalValenceService {
  static final EmotionalValenceService _instance = EmotionalValenceService._internal();
  factory EmotionalValenceService() => _instance;
  EmotionalValenceService._internal();

  /// Positive words that should have warm colors
  static const _positiveWords = {
    // Core positive emotions
    'love', 'joy', 'happiness', 'peace', 'calm', 'serenity', 'bliss',
    'gratitude', 'thankful', 'blessed', 'appreciation', 'grateful',
    
    // Growth and achievement
    'breakthrough', 'discovery', 'success', 'achievement', 'growth', 'progress',
    'improvement', 'learning', 'wisdom', 'insight', 'clarity', 'understanding',
    'realization', 'enlightenment', 'awakening', 'transformation', 'evolution',
    
    // Connection and relationships
    'connection', 'bond', 'friendship', 'community', 'belonging', 'intimacy',
    'warmth', 'comfort', 'support', 'encouragement', 'kindness', 'compassion',
    'empathy', 'acceptance', 'forgiveness', 'healing',
    
    // Energy and vitality
    'energy', 'vitality', 'strength', 'power', 'confidence', 'courage',
    'determination', 'resilience', 'hope', 'optimism', 'excitement',
    'enthusiasm', 'passion', 'inspiration', 'motivation', 'purpose',
    
    // Beauty and wonder
    'beauty', 'wonder', 'awe', 'marvel', 'magnificent', 'brilliant',
    'radiant', 'glowing', 'shining', 'light', 'bright', 'golden',
    
    // Freedom and expansion
    'freedom', 'liberation', 'release', 'expansion', 'openness', 'flow',
    'adventure', 'exploration', 'journey', 'creation', 'innovation',
  };

  /// Negative words that should have cool colors
  static const _negativeWords = {
    // Core negative emotions
    'sadness', 'grief', 'sorrow', 'melancholy', 'depression', 'despair',
    'loneliness', 'isolation', 'abandonment', 'emptiness', 'void',
    
    // Fear and anxiety
    'fear', 'anxiety', 'worry', 'stress', 'tension', 'panic', 'dread',
    'terror', 'horror', 'nightmare', 'phobia', 'paranoia', 'concern',
    
    // Anger and frustration
    'anger', 'rage', 'fury', 'frustration', 'irritation', 'annoyance',
    'resentment', 'bitterness', 'hatred', 'hostility', 'aggression',
    
    // Difficulty and struggle
    'struggle', 'difficulty', 'challenge', 'obstacle', 'barrier', 'problem',
    'crisis', 'conflict', 'pain', 'suffering', 'hurt', 'wound', 'trauma',
    'loss', 'failure', 'defeat', 'rejection', 'disappointment',
    
    // Confusion and uncertainty
    'confusion', 'uncertainty', 'doubt', 'questioning', 'lost', 'stuck',
    'overwhelmed', 'chaos', 'disorder', 'instability', 'turbulence',
    
    // Physical and mental states
    'tired', 'exhausted', 'drained', 'depleted', 'weak', 'sick', 'illness',
    'fatigue', 'burnout', 'breakdown', 'collapse',
    
    // Darkness and cold
    'darkness', 'shadow', 'cold', 'frozen', 'numb', 'distant', 'remote',
  };

  /// Words that are neutral and should use balanced colors
  static const _neutralWords = {
    'thinking', 'reflection', 'contemplation', 'observation', 'awareness',
    'mindfulness', 'presence', 'moment', 'time', 'space', 'place',
    'experience', 'feeling', 'emotion', 'thought', 'memory', 'dream',
    'work', 'family', 'home', 'life', 'day', 'night', 'morning', 'evening',
    'nature', 'world', 'people', 'person', 'self', 'mind', 'body', 'soul',
    'question', 'answer', 'decision', 'choice', 'path', 'way', 'direction',
    'change', 'transition', 'process', 'journey', 'step', 'beginning', 'end',
  };

  /// Determine emotional valence of a word (-1.0 to 1.0)
  /// -1.0 = very negative, 0.0 = neutral, 1.0 = very positive
  double getEmotionalValence(String word) {
    final lowerWord = word.toLowerCase().trim();
    
    if (_positiveWords.contains(lowerWord)) {
      return _getPositiveStrength(lowerWord);
    } else if (_negativeWords.contains(lowerWord)) {
      return _getNegativeStrength(lowerWord);
    } else if (_neutralWords.contains(lowerWord)) {
      return 0.0;
    }
    
    // For unknown words, try basic sentiment analysis
    return _basicSentimentAnalysis(lowerWord);
  }

  /// Get strength of positive emotion (0.3 to 1.0)
  double _getPositiveStrength(String word) {
    // High intensity positive words
    final highIntensity = {
      'love', 'bliss', 'breakthrough', 'enlightenment', 'transformation',
      'magnificent', 'radiant', 'brilliant', 'liberation', 'ecstasy'
    };
    
    // Medium intensity positive words
    final mediumIntensity = {
      'joy', 'happiness', 'gratitude', 'success', 'growth', 'wisdom',
      'connection', 'strength', 'beauty', 'freedom'
    };
    
    if (highIntensity.contains(word)) return 1.0;
    if (mediumIntensity.contains(word)) return 0.7;
    return 0.4; // Default positive
  }

  /// Get strength of negative emotion (-0.3 to -1.0)
  double _getNegativeStrength(String word) {
    // High intensity negative words
    final highIntensity = {
      'despair', 'terror', 'rage', 'hatred', 'trauma', 'agony',
      'devastation', 'horror', 'collapse', 'nightmare'
    };
    
    // Medium intensity negative words
    final mediumIntensity = {
      'sadness', 'fear', 'anger', 'pain', 'loss', 'stress',
      'anxiety', 'depression', 'struggle', 'difficulty'
    };
    
    if (highIntensity.contains(word)) return -1.0;
    if (mediumIntensity.contains(word)) return -0.7;
    return -0.4; // Default negative
  }

  /// Basic sentiment analysis for unknown words
  double _basicSentimentAnalysis(String word) {
    // Check for common positive suffixes/patterns
    if (word.endsWith('ness') && !word.contains('sad') && !word.contains('dark')) {
      return 0.2;
    }
    if (word.endsWith('ful') && !word.contains('pain') && !word.contains('harm')) {
      return 0.3;
    }
    if (word.startsWith('un') || word.startsWith('dis') || word.startsWith('mis')) {
      return -0.2;
    }
    
    return 0.0; // Default neutral
  }

  /// Convert emotional valence to color temperature
  /// Positive valence = warm colors, Negative valence = cool colors
  Color getEmotionalColor(String word, {double opacity = 1.0}) {
    final valence = getEmotionalValence(word);
    return _valenceToColor(valence, opacity: opacity);
  }

  /// Convert valence score to color
  Color _valenceToColor(double valence, {double opacity = 1.0}) {
    if (valence > 0.7) {
      // Very positive: Golden/warm yellow
      return const Color(0xFFFFD700).withOpacity(opacity);
    } else if (valence > 0.4) {
      // Positive: Warm orange
      return const Color(0xFFFF8C42).withOpacity(opacity);
    } else if (valence > 0.1) {
      // Slightly positive: Soft coral
      return const Color(0xFFFF6B6B).withOpacity(opacity);
    } else if (valence > -0.1) {
      // Neutral: Soft purple (app's primary color)
      return const Color(0xFFD1B3FF).withOpacity(opacity);
    } else if (valence > -0.4) {
      // Slightly negative: Cool blue
      return const Color(0xFF4A90E2).withOpacity(opacity);
    } else if (valence > -0.7) {
      // Negative: Deeper blue
      return const Color(0xFF2E86AB).withOpacity(opacity);
    } else {
      // Very negative: Cool teal
      return const Color(0xFF4ECDC4).withOpacity(opacity);
    }
  }

  /// Get glow color for emotional temperature
  Color getGlowColor(String word, {double opacity = 0.3}) {
    final valence = getEmotionalValence(word);
    
    if (valence > 0.3) {
      // Positive words get warm glow
      return const Color(0xFFFF8C42).withOpacity(opacity);
    } else if (valence < -0.3) {
      // Negative words get cool glow
      return const Color(0xFF4A90E2).withOpacity(opacity);
    } else {
      // Neutral words get soft purple glow
      return const Color(0xFFD1B3FF).withOpacity(opacity);
    }
  }

  /// Get color palette for a list of keywords
  Map<String, Color> generateEmotionalColorMap(List<String> keywords) {
    final colorMap = <String, Color>{};
    
    for (final keyword in keywords) {
      colorMap[keyword] = getEmotionalColor(keyword);
    }
    
    return colorMap;
  }

  /// Get emotional category for display
  String getEmotionalCategory(String word) {
    final valence = getEmotionalValence(word);
    
    if (valence > 0.7) return 'Very Positive';
    if (valence > 0.4) return 'Positive';
    if (valence > 0.1) return 'Slightly Positive';
    if (valence > -0.1) return 'Neutral';
    if (valence > -0.4) return 'Slightly Negative';
    if (valence > -0.7) return 'Negative';
    return 'Very Negative';
  }

  /// Get temperature description
  String getTemperatureDescription(String word) {
    final valence = getEmotionalValence(word);
    
    if (valence > 0.3) return 'Warm';
    if (valence < -0.3) return 'Cool';
    return 'Neutral';
  }
}