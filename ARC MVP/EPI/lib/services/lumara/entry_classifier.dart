enum EntryType {
  factual,        // Questions, clarifications, learning notes
  reflective,     // Feelings, struggles, personal assessment, goals
  analytical,     // Essays, theories, frameworks, external analysis
  conversational, // Quick updates, mundane logging
  metaAnalysis    // Explicit requests for pattern recognition
}

class EntryClassifier {

  /// Main classification function
  /// Returns the entry type based on content analysis
  static EntryType classify(String entryText) {
    if (entryText.trim().isEmpty) {
      return EntryType.conversational;
    }

    // Preprocessing
    final wordCount = _countWords(entryText);
    final lowerText = entryText.toLowerCase();
    final hasQuestionMark = entryText.contains('?');

    // Calculate indicators
    final metaIndicatorCount = _countMetaAnalysisIndicators(lowerText);
    final emotionalDensity = _calculateEmotionalDensity(entryText);
    final firstPersonDensity = _calculateFirstPersonDensity(entryText);
    final technicalIndicators = _countTechnicalIndicators(lowerText);
    final analyticalIndicators = _countAnalyticalIndicators(lowerText);
    final hasPersonalMetrics = _containsPersonalMetrics(lowerText);
    final hasGoalLanguage = _containsGoalLanguage(lowerText);
    final hasStruggleLanguage = _containsStruggleLanguage(lowerText);

    // Classification logic (ordered by priority - most specific first)

    // PRIORITY 1: Meta-analysis requests (explicit pattern recognition)
    if (metaIndicatorCount > 0) {
      return EntryType.metaAnalysis;
    }

    // PRIORITY 2: Factual questions (short, clarification-seeking)
    if (wordCount < 100 && hasQuestionMark) {
      final factualTriggers = [
        'does this make sense',
        'is this right',
        'is this correct',
        'am i understanding',
        'did i get this',
      ];

      if (factualTriggers.any((trigger) => lowerText.contains(trigger))) {
        return EntryType.factual;
      }

      // Pattern: "I thought X but it's actually Y?"
      if (lowerText.contains('i thought') ||
          lowerText.contains('i learned')) {
        return EntryType.factual;
      }
    }

    // PRIORITY 3: Reflective content (emotional, personal, goal-oriented)
    if (emotionalDensity > 0.15 ||
        hasPersonalMetrics ||
        hasGoalLanguage ||
        hasStruggleLanguage) {
      return EntryType.reflective;
    }

    // PRIORITY 4: Analytical essays (long-form, third-person, theoretical)
    if (wordCount > 200 &&
        firstPersonDensity < 0.05 &&
        analyticalIndicators > 3) {
      return EntryType.analytical;
    }

    // PRIORITY 5: Conversational updates (short, low emotion, observational)
    if (wordCount < 150 &&
        emotionalDensity < 0.05 &&
        !hasQuestionMark) {
      return EntryType.conversational;
    }

    // DEFAULT: Reflective (safe fallback for life arc tracking)
    return EntryType.reflective;
  }

  /// Count words in text
  static int _countWords(String text) {
    return text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  /// Calculate emotional density (emotional words / total words)
  static double _calculateEmotionalDensity(String text) {
    final emotionalWords = [
      // Negative emotions
      'feel', 'felt', 'feeling', 'frustrated', 'angry', 'sad',
      'anxious', 'worried', 'scared', 'disappointed', 'ashamed',
      'guilty', 'overwhelmed', 'struggling', 'hate', 'depressed',
      'lonely', 'afraid', 'nervous', 'insecure', 'jealous',

      // Positive emotions
      'excited', 'happy', 'hopeful', 'proud', 'grateful',
      'thankful', 'relieved', 'confident', 'love', 'blessed',
      'joyful', 'content', 'peaceful', 'energized', 'amazed',
    ];

    final lowerText = text.toLowerCase();
    final wordCount = _countWords(text);

    if (wordCount == 0) return 0.0;

    int emotionalCount = 0;
    for (var word in emotionalWords) {
      // Use word boundaries to avoid partial matches
      final pattern = RegExp(r'\b' + RegExp.escape(word) + r'\b');
      emotionalCount += pattern.allMatches(lowerText).length;
    }

    return emotionalCount / wordCount;
  }

  /// Calculate first-person pronoun density
  static double _calculateFirstPersonDensity(String text) {
    final firstPersonPatterns = [
      r'\bi\s',       // "I "
      r'\bmy\s',      // "my "
      r'\bme\s',      // "me "
      r'\bmyself\b',  // "myself"
      r"\bi'm\b",     // "I'm"
      r"\bi've\b",    // "I've"
      r"\bi'll\b",    // "I'll"
      r"\bi'd\b",     // "I'd"
    ];

    final lowerText = text.toLowerCase();
    final wordCount = _countWords(text);

    if (wordCount == 0) return 0.0;

    int count = 0;
    for (var pattern in firstPersonPatterns) {
      count += RegExp(pattern).allMatches(lowerText).length;
    }

    return count / wordCount;
  }

  /// Count technical/factual indicators
  static int _countTechnicalIndicators(String lowerText) {
    final technicalPatterns = [
      'calculate', 'calculation', 'formula', 'equation', 'algorithm',
      'function', 'mathematics', 'mathematical', 'physics', 'engineering',
      'code', 'coding', 'programming', 'data', 'system', 'architecture',
      'framework', 'model', 'technical', 'methodology', 'implementation',
      'integration', 'optimization', 'variable', 'constant', 'derivative',
    ];

    int count = 0;
    for (var pattern in technicalPatterns) {
      if (RegExp(r'\b' + RegExp.escape(pattern) + r'\b').hasMatch(lowerText)) {
        count++;
      }
    }

    return count;
  }

  /// Count analytical/theoretical indicators
  static int _countAnalyticalIndicators(String lowerText) {
    final analyticalPatterns = [
      'theory', 'hypothesis', 'analysis', 'analyze', 'pattern',
      'structural', 'systemic', 'adoption', 'diffusion', 'transformation',
      'believe', 'posit', 'argue', 'suggest', 'demonstrate', 'implies',
      'looking back', 'historically', 'similar to', 'analogous',
      'in contrast', 'however', 'therefore', 'consequently',
      'the key to', 'the breakthrough', 'the barrier', 'choke point',
    ];

    int count = 0;
    for (var pattern in analyticalPatterns) {
      if (lowerText.contains(pattern)) {
        count++;
      }
    }

    return count;
  }

  /// Count meta-analysis indicators (pattern recognition requests)
  static int _countMetaAnalysisIndicators(String lowerText) {
    final metaPatterns = [
      // Direct pattern requests
      r'what patterns?\s+(do you see|have you noticed|are there|emerge)',
      r'(find|identify|show me|tell me about)\s+.*\bpatterns?\b',
      r'looking back\s+(at|on)\s+my',
      r'what themes?\s+(keep coming up|have emerged|do you notice)',
      r'how have i changed',
      r'how has my\s+.+\s+(changed|evolved|shifted)',
      r'what connections?\s+(exist|are there|do you see)',
      r'compare my\s+.+\s+(across|over|between)',
      r'analyze my (entries|journey|progress)',
      r'what (do|does) my (entries|writing)\s+(reveal|show|suggest)',
      r'summarize my (progress|journey|development)',
      r'what insights?\s+(can you|do you)\s+(provide|offer|see)',
      r'track my (changes|evolution|development)',
      r'review my (entries|notes|thoughts)',
      r'what (trends|shifts|movements) do you (see|notice)',

      // Temporal comparison requests
      r'compared to (last|previous|earlier)',
      r'since (last|when i)',
      r'over (the past|time|these)',
      r'from .+ to .+',
      r'between .+ and .+',

      // Meta-cognitive requests
      r"what am i (really|actually|truly)\s+(saying|trying to|working through)",
      r"what'?s (really|actually) going on",
      r'help me understand (my|what)',
      r'make sense of (my|this|these)',
      r'connect the dots',
      r'see the bigger picture',

      // Explicit ARC capability requests
      r'what (does|can)\s+(arc|your memory)\s+(tell|show|reveal)',
      r'based on (everything|what)\s+(you know|we.?ve discussed)',
      r'given (all|everything)\s+(you know|we.?ve talked about)',
    ];

    int count = 0;
    for (var pattern in metaPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(lowerText)) {
        count++;
      }
    }

    return count;
  }

  /// Check for personal metrics (weight, distance, money, etc.)
  static bool _containsPersonalMetrics(String lowerText) {
    final metricPatterns = [
      r'\d+\.?\d*\s*(lbs|pounds|kg)',        // Weight
      r'\d+\.?\d*\s*(miles|km|kilometers)',  // Distance
      r'\d+\.?\d*\s*(hours|minutes)',        // Time
      r'\$\d+',                               // Money
      r'\d+%',                                // Percentage
      r'\bweighed\b', r'\bweight\b', r'\bscale\b',  // Weight-related
      r'\bran\b', r'\bwalked\b', r'\bexercise\b',   // Activity-related
      r'\bcalories\b', r'\bsteps\b',                // Health metrics
    ];

    return metricPatterns.any((pattern) =>
      RegExp(pattern).hasMatch(lowerText)
    );
  }

  /// Check for goal-setting language
  static bool _containsGoalLanguage(String lowerText) {
    final goalPatterns = [
      r'\bmy goal\b', r'\bi want to\b', r'\bi need to\b', r'\bi should\b',
      r'\btrying to\b', r'\bworking on\b', r'\bcommitted to\b',
      r'\bplanning to\b', r'\bgoing to\b', r'\bwill\b.+\bby\b',
      r'\baim to\b', r'\bintend to\b', r'\bhope to\b',
      r'\bgoal is\b', r'\btarget is\b', r'\bobjective\b',
    ];

    return goalPatterns.any((pattern) =>
      RegExp(pattern).hasMatch(lowerText)
    );
  }

  /// Check for struggle/difficulty language
  static bool _containsStruggleLanguage(String lowerText) {
    final strugglePatterns = [
      r'\bstruggling\b', r'\bdifficult\b', r'\bhard\b', r'\bchallenging\b',
      r"\bcan'?t\b", r"\bwon'?t\b", r'\bfailing\b', r'\bfailed\b',
      r'\bstuck\b', r'\blost\b', r'\bconfused\b', r'\bunsure\b',
      r'\bdoubt\b', r'\bworried\b', r'\bscared\b', r'\bafraid\b',
      r'\boverwhelmed\b', r'\bexhausted\b', r'\btired\b', r'\bdrained\b',
    ];

    return strugglePatterns.any((pattern) =>
      RegExp(pattern).hasMatch(lowerText)
    );
  }

  /// Get human-readable description of entry type
  static String getTypeDescription(EntryType type) {
    switch (type) {
      case EntryType.factual:
        return 'Factual Question';
      case EntryType.reflective:
        return 'Reflective Entry';
      case EntryType.analytical:
        return 'Analytical Essay';
      case EntryType.conversational:
        return 'Conversational Update';
      case EntryType.metaAnalysis:
        return 'Pattern Analysis Request';
    }
  }

  /// Get debug information for classification
  static Map<String, dynamic> getClassificationDebugInfo(String entryText) {
    final wordCount = _countWords(entryText);
    final lowerText = entryText.toLowerCase();
    final hasQuestionMark = entryText.contains('?');

    return {
      'wordCount': wordCount,
      'hasQuestionMark': hasQuestionMark,
      'metaIndicatorCount': _countMetaAnalysisIndicators(lowerText),
      'emotionalDensity': _calculateEmotionalDensity(entryText),
      'firstPersonDensity': _calculateFirstPersonDensity(entryText),
      'technicalIndicators': _countTechnicalIndicators(lowerText),
      'analyticalIndicators': _countAnalyticalIndicators(lowerText),
      'hasPersonalMetrics': _containsPersonalMetrics(lowerText),
      'hasGoalLanguage': _containsGoalLanguage(lowerText),
      'hasStruggleLanguage': _containsStruggleLanguage(lowerText),
      'finalClassification': classify(entryText),
    };
  }
}