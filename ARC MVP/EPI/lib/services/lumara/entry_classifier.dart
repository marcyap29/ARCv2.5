enum EntryType {
  factual,        // Questions, clarifications, learning notes
  reflective,     // Feelings, struggles, personal assessment, goals
  analytical,     // Essays, theories, frameworks, external analysis
  conversational, // Quick updates, mundane logging
  metaAnalysis    // Explicit requests for pattern recognition
}

/// Voice depth mode for Jarvis/Samantha dual-mode system
/// Used to determine response depth in voice conversations
enum VoiceDepthMode {
  transactional,  // Jarvis: Quick, efficient, 50-100 words
  reflective,     // Samantha: Deep, engaged, 150-200 words
}

/// Result of voice depth classification
class VoiceDepthResult {
  final VoiceDepthMode depth;
  final double confidence;
  final List<String> triggers;
  
  const VoiceDepthResult({
    required this.depth,
    required this.confidence,
    required this.triggers,
  });
  
  Map<String, dynamic> toJson() => {
    'depth': depth.name,
    'confidence': confidence,
    'triggers': triggers,
  };
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
        'is my understanding',
        'does newton',
        'is newton',
      ];

      if (factualTriggers.any((trigger) => lowerText.contains(trigger))) {
        print('LUMARA Classifier: Detected factual question via trigger: ${factualTriggers.where((t) => lowerText.contains(t)).first}');
        return EntryType.factual;
      }

      // Pattern: "I thought X but it's actually Y?"
      if (lowerText.contains('i thought') ||
          lowerText.contains('i learned') ||
          lowerText.contains('i had thought')) {
        print('LUMARA Classifier: Detected factual clarification via learning pattern');
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
      'newton', 'calculus', 'predict', 'movement', 'predict or calculate',
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

  // =========================================================================
  // VOICE DEPTH CLASSIFICATION (Jarvis/Samantha dual-mode system)
  // =========================================================================

  /// Classify voice input for depth mode (transactional vs reflective)
  /// Used to route between Jarvis (quick) and Samantha (deep) response paths
  /// 
  /// Returns VoiceDepthResult with depth, confidence, and matched triggers
  static VoiceDepthResult classifyVoiceDepth(String transcript) {
    if (transcript.trim().isEmpty) {
      return const VoiceDepthResult(
        depth: VoiceDepthMode.transactional,
        confidence: 1.0,
        triggers: [],
      );
    }

    final lowerText = transcript.toLowerCase();
    final wordCount = _countWords(transcript);
    final triggers = <String>[];
    double confidence = 0.0;

    // Check for REFLECTIVE triggers (any match → reflective)
    
    // 1. Explicit processing language
    if (_containsProcessingLanguage(lowerText)) {
      triggers.add('processing_language');
      confidence += 0.3;
    }

    // 2. Emotional struggle markers (reuse existing)
    if (_containsStruggleLanguage(lowerText)) {
      triggers.add('struggle_language');
      confidence += 0.25;
    }

    // 3. Emotional state declarations
    if (_containsEmotionalStateDeclaration(lowerText)) {
      triggers.add('emotional_state');
      confidence += 0.25;
    }

    // 4. Decision support requests
    if (_containsDecisionSupportLanguage(lowerText)) {
      triggers.add('decision_support');
      confidence += 0.25;
    }

    // 5. Self-reflective questions
    if (_containsSelfReflectiveQuestions(lowerText)) {
      triggers.add('self_reflective_question');
      confidence += 0.25;
    }

    // 6. Relationship/identity exploration
    if (_containsRelationshipIdentityLanguage(lowerText)) {
      triggers.add('relationship_identity');
      confidence += 0.2;
    }

    // 7. High emotional density (reuse existing calculation)
    final emotionalDensity = _calculateEmotionalDensity(transcript);
    if (emotionalDensity > 0.15) {
      triggers.add('high_emotional_density');
      confidence += 0.2;
    }

    // 8. Long utterances with personal pronouns
    final firstPersonDensity = _calculateFirstPersonDensity(transcript);
    if (wordCount > 50 && firstPersonDensity > 0.1) {
      triggers.add('long_personal_utterance');
      confidence += 0.15;
    }

    // Determine depth based on triggers
    if (triggers.isNotEmpty) {
      // Cap confidence at 1.0
      confidence = confidence.clamp(0.0, 1.0);
      return VoiceDepthResult(
        depth: VoiceDepthMode.reflective,
        confidence: confidence,
        triggers: triggers,
      );
    }

    // No reflective triggers → transactional (default)
    // Higher confidence for shorter, simpler utterances
    final transactionalConfidence = wordCount < 20 ? 1.0 : 
                                    wordCount < 50 ? 0.9 : 0.8;
    
    return VoiceDepthResult(
      depth: VoiceDepthMode.transactional,
      confidence: transactionalConfidence,
      triggers: [],
    );
  }

  /// Check for explicit processing language
  /// "I need to process...", "Help me think through...", etc.
  static bool _containsProcessingLanguage(String lowerText) {
    final processingPatterns = [
      r'\bi need to process\b',
      r'\bi need to think through\b',
      r'\bi need to work through\b',
      r'\bhelp me think about\b',
      r'\bhelp me think through\b',
      r'\bhelp me understand\b',
      r'\bcan we talk about\b',
      r"\blet'?s explore\b",
      r"\blet'?s discuss\b",
      r'\bi want to talk about\b',
      r'\bi need to talk about\b',
    ];

    return processingPatterns.any((pattern) => 
      RegExp(pattern).hasMatch(lowerText)
    );
  }

  /// Check for emotional state declarations
  /// "I'm feeling...", "I feel [emotion] about..."
  static bool _containsEmotionalStateDeclaration(String lowerText) {
    final emotionalStatePatterns = [
      r"\bi'?m feeling\b",
      r'\bi feel \w+ about\b',
      r"\bi'?m so \w+ (about|that|because)\b",
      r'\bfeeling (really|very|so|quite) \w+\b',
    ];

    return emotionalStatePatterns.any((pattern) => 
      RegExp(pattern).hasMatch(lowerText)
    );
  }

  /// Check for decision support requests
  /// "Should I...", "What do you think about...", "Help me decide..."
  static bool _containsDecisionSupportLanguage(String lowerText) {
    final decisionPatterns = [
      r'\bshould i\b',
      r'\bwhat do you think (about|of)\b',
      r'\bdo you think i should\b',
      r'\bhelp me decide\b',
      r"\bi can'?t decide\b",
      r"\bi don'?t know (if|whether) i should\b",
      r'\bwhat would you do\b',
      r'\bwhat should i do\b',
    ];

    return decisionPatterns.any((pattern) => 
      RegExp(pattern).hasMatch(lowerText)
    );
  }

  /// Check for self-reflective questions
  /// "Why do I...", "Am I being...", "What does it mean that I..."
  static bool _containsSelfReflectiveQuestions(String lowerText) {
    final selfReflectivePatterns = [
      r'\bwhy do i\b',
      r'\bwhy am i\b',
      r'\bwhat does it mean that i\b',
      r'\bam i being\b',
      r'\bam i (too|being too)\b',
      r"\bi don'?t understand why i\b",
      r"\bi can'?t figure out (why|what)\b",
      r"\bi'?m not sure (why|what|if) i\b",
      r'\bwhat is wrong with me\b',
      r"\bwhy can'?t i\b",
    ];

    return selfReflectivePatterns.any((pattern) => 
      RegExp(pattern).hasMatch(lowerText)
    );
  }

  /// Check for relationship/identity exploration
  /// Questions about relationships, purpose, meaning, values
  static bool _containsRelationshipIdentityLanguage(String lowerText) {
    final relationshipIdentityPatterns = [
      r'\bmy relationship with\b',
      r'\bwho i (am|want to be)\b',
      r'\bwhat i (really )?want\b',
      r'\bmy purpose\b',
      r'\bmeaning (of|in) (my )?life\b',
      r'\bmy values\b',
      r'\bwhat matters (to me|most)\b',
      r'\bwho i am\b',
      r'\bwhat kind of person\b',
      r'\bmy identity\b',
    ];

    return relationshipIdentityPatterns.any((pattern) => 
      RegExp(pattern).hasMatch(lowerText)
    );
  }

  /// Get human-readable description of voice depth mode
  static String getVoiceDepthDescription(VoiceDepthMode mode) {
    switch (mode) {
      case VoiceDepthMode.transactional:
        return 'Quick Response (Jarvis)';
      case VoiceDepthMode.reflective:
        return 'Deep Engagement (Samantha)';
    }
  }
}