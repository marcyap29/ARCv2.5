import '../../models/engagement_discipline.dart';

enum EntryType {
  factual,        // Questions, clarifications, learning notes
  reflective,     // Feelings, struggles, personal assessment, goals
  analytical,     // Essays, theories, frameworks, external analysis
  conversational, // Quick updates, mundane logging
  metaAnalysis    // Explicit requests for pattern recognition
}

/// What the user is seeking from this interaction
/// Used to calibrate LUMARA's response style in voice mode
enum SeekingType {
  validation,   // "Am I right to feel this way?" - needs acknowledgment, not analysis
  exploration,  // "Help me think through this" - wants questions that deepen
  direction,    // "Tell me what to do" - wants clear recommendation
  reflection,   // "I need to process this" - needs space and mirroring
}

/// Result of seeking classification
class SeekingResult {
  final SeekingType seeking;
  final double confidence;
  final List<String> triggers;
  
  const SeekingResult({
    required this.seeking,
    required this.confidence,
    required this.triggers,
  });
  
  Map<String, dynamic> toJson() => {
    'seeking': seeking.name,
    'confidence': confidence,
    'triggers': triggers,
  };
}

/// Result of voice depth classification
/// Uses EngagementMode to match written mode behavior
class VoiceDepthResult {
  final EngagementMode depth;
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

    // PRIORITY 2: Factual questions (short, clarification-seeking, or direct educational)
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
        // Direct educational/factual (answer directly per master prompt; do not treat as journal)
        'what is the calculation of',
        'what is the formula for',
        'how do you calculate',
        'how do i calculate',
        'how do we calculate',
        'calculation of ',
        'formula for ',
        'define ',  // e.g. "define density"
        'what is the definition of',
        'what is the difference between',
        'how does * work',  // pattern: "how does [concept] work"
      ];

      if (factualTriggers.any((trigger) {
        if (trigger.contains('*')) {
          final pattern = trigger.replaceAll('*', r'\w+');
          return RegExp(pattern).hasMatch(lowerText);
        }
        return lowerText.contains(trigger);
      })) {
        print('LUMARA Classifier: Detected factual question via trigger (educational/direct)');
        return EntryType.factual;
      }

      // "What is X?" / "How do you X?" when short and no personal/emotional language → factual
      if (wordCount <= 25 &&
          (lowerText.startsWith('what is ') ||
              lowerText.startsWith('how do you ') ||
              lowerText.startsWith('how does ') ||
              lowerText.startsWith('why does ')) &&
          !lowerText.contains('your take') &&
          !lowerText.contains('my ') &&
          emotionalDensity < 0.1) {
        print('LUMARA Classifier: Detected short direct factual question (what/how/why)');
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

    // PRIORITY 4.5: Temporal/retrospective queries (require memory retrieval)
    if (_containsTemporalQueryLanguage(lowerText)) {
      return EntryType.metaAnalysis;
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
      
      // Temporal retrospective queries (require memory retrieval)
      r'tell me (about|how) (my|the) (work|progress|activities|week|month|day)',
      r"(what|tell me).*(i'?ve|have i) been (doing|working on)",
      r'(this|last) (week|month|day|year).*(detail|analysis|summary)',
      r'go into (detail|depth|analysis)',
      r'(detail|detailed) (and |)(analysis|summary)',
      r'(summarize|review|analyze) (my|the|this) (week|month|work|day)',
      r'what (have|did).*(been|i) (doing|working)',
      r'catch me up on',

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

  /// Check for temporal/retrospective query language that requires memory retrieval
  static bool _containsTemporalQueryLanguage(String lowerText) {
    final temporalQueryPatterns = [
      // Direct temporal queries (must be asking about activity, not making statements)
      r'tell me (about|how) (my|the) (work|progress|activities|week|month|day)',
      r"(what|tell me).*(i'?ve|have i) been (doing|working on)",
      r'(this|last) (week|month|day|year).*(detail|analysis|summary)',
      r'go into (detail|depth|analysis)',
      r'(detail|detailed) (and |)(analysis|summary)',
      r'(summarize|review|analyze) (my|the|this) (week|month|work|day)',
      r'what (have|did).*(been|i) (doing|working)',
      r'catch me up on',
      r'how am i doing (with|on)',
      r"what'?s been going on",
      r'what have i been up to',
      r'(my|the) recent (work|progress|activity|activities)',
    ];

    return temporalQueryPatterns.any((pattern) =>
      RegExp(pattern, caseSensitive: false).hasMatch(lowerText)
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

  /// Classify voice input for engagement mode (reflect, explore, or integrate)
  /// Uses EngagementMode to match written mode behavior exactly
  /// Three-tier system:
  /// - Reflect (default): Casual conversation, shortest, stays in present moment
  /// - Explore: Analysis and pattern surfacing, longer, when user asks for exploration
  /// - Integrate: Synthesis across domains, longest, when user asks for synthesis
  /// 
  /// Returns VoiceDepthResult with depth (EngagementMode), confidence, and matched triggers
  static VoiceDepthResult classifyVoiceDepth(String transcript) {
    if (transcript.trim().isEmpty) {
      return const VoiceDepthResult(
        depth: EngagementMode.reflect,
        confidence: 1.0,
        triggers: [],
      );
    }

    final lowerText = transcript.toLowerCase();
    final wordCount = _countWords(transcript);
    final triggers = <String>[];
    double confidence = 0.0;

    // PRIORITY 1: Check for synthesis/connect triggers → Deeper
    if (_containsIntegrationLanguage(lowerText)) {
      triggers.add('integration_request');
      confidence = 0.9;
      return VoiceDepthResult(
        depth: EngagementMode.deeper,
        confidence: confidence,
        triggers: triggers,
      );
    }

    // PRIORITY 2: Check for exploration/pattern triggers → Deeper
    if (_containsExplorationLanguage(lowerText)) {
      triggers.add('exploration_request');
      confidence = 0.85;
      return VoiceDepthResult(
        depth: EngagementMode.deeper,
        confidence: confidence,
        triggers: triggers,
      );
    }

    // PRIORITY 3: Check for REFLECT triggers (emotional, personal processing)
    // Default to reflect mode for casual conversation
    
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
        depth: EngagementMode.reflect,
        confidence: confidence,
        triggers: triggers,
      );
    }

    // No triggers → reflect (default for casual conversation)
    // Higher confidence for shorter, simpler utterances
    final reflectConfidence = wordCount < 20 ? 1.0 : 
                                    wordCount < 50 ? 0.9 : 0.8;
    
    return VoiceDepthResult(
      depth: EngagementMode.reflect,
      confidence: reflectConfidence,
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

  /// Check for integration/synthesis language
  /// Only explicit synthesis requests or clear cross-domain language.
  /// Avoids broad single-word or casual phrases so default stays reflect.
  static bool _containsIntegrationLanguage(String lowerText) {
    final integrationPatterns = [
      // Explicit voice commands for Integrate mode only
      r'\bgo into integrate (mode|mode)\b',
      r'\bswitch to integrate\b',
      r'\bintegrate mode\b',
      r'\bsynthesis mode\b',
      r'\bsynthesize\b',
      r'\bsynthesis\b',
      // "integrate" / "integration" only when clearly requesting mode (e.g. "I want to integrate" as in synthesis)
      r'\b(switch|go|want) .* (to )?integrate\b',
      r'\b(do|give|provide) (a )?(full|complete|comprehensive) synthesis\b',
      r'\b(do|give|provide) (a )?deep analysis\b',
      r'\bdeep analysis\b',
      r'\b(do|give|provide) (a )?deep dive\b',
      r'\bdeep dive\b',
      // Explicit cross-domain / synthesis phrases (not casual "put it together" or "bigger picture")
      r'\bconnect the dots\b',
      r'\bhow does (this|that|it) (relate|connect|link) (to|with)\b',
      r'\bhow (are|do) (these|all) (relate|connect|link)\b',
      r'\bhow (does|do) (this|these|it|they) (fit|work) together\b',
      r'\bacross (domains|areas|topics|contexts)\b',
      r'\bhow (does|do) (my|this) .* (relate|connect|link) (to|with) (my|this) .*\b',
      r'\bwhat (are|is) the (connections|links|relationships) (between|across)\b',
      r'\bsee how (this|it|everything) (connects|relates|fits)\b',
      r'\bhow (does|do) (this|it|everything) (all|all of this) (connect|relate|fit together)\b',
      r'\bweave (it|this|everything) together\b',
      // Explicit "give me the full picture" type (synthesis request)
      r'\b(show|give) (me )?the (full|complete|whole) (picture|view|perspective)\b',
      r"what's the (full|complete|whole) (picture|story|context)\b",
    ];

    return integrationPatterns.any((pattern) => 
      RegExp(pattern).hasMatch(lowerText)
    );
  }

  /// Check for exploration/analysis language
  /// "What patterns...", "Explore...", "Analyze...", "Help me understand..."
  /// Also includes explicit voice commands: "Analyze", "Give me insight", etc.
  static bool _containsExplorationLanguage(String lowerText) {
    final explorationPatterns = [
      // Explicit voice commands for Explore mode
      r'\banalyze\b',
      r'\banalyze (this|that|it|for me)\b',
      r'\bgive me (insight|insights)\b',
      r'\b(show|give) (me )?(some )?insight\b',
      r'\binsight (please|now)\b',
      r'\bgo into explore (mode|mode)\b',
      r'\bswitch to explore\b',
      r'\bexplore mode\b',
      
      // Temporal/retrospective queries (require memory retrieval)
      r'\bhow (has|have) my (day|week|month|year|time|journey) been\b',
      r'\bwhat (have|did) i (do|done|accomplish|work on)\b',
      r'\bsummary of my\b',
      r'\bsummarize my\b',
      r'\breview my (day|week|month|year|entries|journal)\b',
      r'\breflect on my (day|week|month|year|journey|progress)\b',
      r'\blook at my (day|week|month|year|entries|journal)\b',
      r'\bwhat (happened|did i do) (this|last) (day|week|month|year)\b',
      r'\bwhat have i been (doing|working on|focused on)\b',
      r'\btell me (about|how) my (day|week|month|year)\b',
      r'\bmy (day|week|month|year) (has|have) been\b',
      r'\bwhat (themes|patterns|trends) (have|do) (i|you see)\b',
      r'\brecommendations? (for|based on)\b',
      r'\bbased on (my|what i)\b',
      
      // Natural exploration language
      r'\bwhat patterns?\b',
      r'\bwhat (patterns|themes) (do you see|have you noticed|are there)\b',
      r'\bexplore\b',
      r'\bexploration\b',
      r'\bexploring\b',
      r'\banalysis\b',
      r'\banalyzing\b',
      r'\bhelp me understand\b',
      r'\bhelp me see\b',
      r'\bhelp me figure out\b',
      r'\bwhat (do you see|are you noticing|insights) (in|about|from)\b',
      r'\bwhat (can you|do you) (tell|show|reveal) (me|about)\b',
      r'\bwhat (does|is) (this|that|it) (mean|suggest|indicate|reveal)\b',
      r'\bwhat (are|is) the (themes|patterns|trends|insights)\b',
      r'\bidentify (patterns|themes|trends)\b',
      r'\bsurface (patterns|themes|insights)\b',
      r'\bwhat (connections|insights|observations) (do you see|can you make)\b',
      r'\bdig (deeper|into)\b',
      r'\bdive (into|deeper)\b',
      r'\bbreak (this|it) down\b',
      r'\bunpack (this|it)\b',
      r"what's (really|actually) (going on|happening|here)\b",
      r'\bwhat (do|does) (my|this) (entries|journey|progress) (reveal|show|suggest)\b',
      r'\bexamine (this|that|it)\b',
      r'\binvestigate\b',
      r'\blook deeper\b',
      r'\bwhat do you think\b',
      r"what's your take\b",
      r"what's your perspective\b",
    ];

    return explorationPatterns.any((pattern) => 
      RegExp(pattern).hasMatch(lowerText)
    );
  }

  /// Get human-readable description of voice engagement mode
  static String getVoiceDepthDescription(EngagementMode mode) {
    switch (mode) {
      case EngagementMode.reflect:
        return 'Default (Casual Conversation)';
      case EngagementMode.deeper:
      case EngagementMode.explore:
      case EngagementMode.integrate:
        return 'Deeper (Patterns & Synthesis)';
    }
  }

  // =========================================================================
  // SEEKING CLASSIFICATION (Voice Mode - What does the user want?)
  // =========================================================================
  
  /// Classify what the user is seeking from this interaction
  /// 
  /// This is critical for voice mode response calibration:
  /// - Someone seeking VALIDATION who gets analysis feels unheard
  /// - Someone seeking DIRECTION who gets questions feels frustrated
  /// - Someone seeking EXPLORATION wants deepening, not answers
  /// - Someone seeking REFLECTION needs space, not action pressure
  /// 
  /// Returns SeekingResult with seeking type, confidence, and matched triggers
  static SeekingResult classifySeeking(String transcript) {
    if (transcript.trim().isEmpty) {
      return const SeekingResult(
        seeking: SeekingType.reflection,
        confidence: 0.5,
        triggers: [],
      );
    }

    final lowerText = transcript.toLowerCase();
    final triggers = <String>[];
    
    // PRIORITY 1: Direction seeking (explicit requests for advice/guidance)
    if (_containsDirectionSeeking(lowerText)) {
      triggers.add('direction_request');
      return SeekingResult(
        seeking: SeekingType.direction,
        confidence: 0.9,
        triggers: triggers,
      );
    }
    
    // PRIORITY 2: Validation seeking (checking if feelings/thoughts are okay)
    if (_containsValidationSeeking(lowerText)) {
      triggers.add('validation_request');
      return SeekingResult(
        seeking: SeekingType.validation,
        confidence: 0.85,
        triggers: triggers,
      );
    }
    
    // PRIORITY 3: Exploration seeking (wanting to think through something)
    if (_containsExplorationSeeking(lowerText)) {
      triggers.add('exploration_request');
      return SeekingResult(
        seeking: SeekingType.exploration,
        confidence: 0.85,
        triggers: triggers,
      );
    }
    
    // PRIORITY 4: Check for reflection indicators (processing, venting)
    double reflectionConfidence = 0.5;
    
    // Venting/processing indicators
    if (_containsVentingLanguage(lowerText)) {
      triggers.add('venting');
      reflectionConfidence += 0.25;
    }
    
    // Emotional processing
    if (_containsEmotionalStateDeclaration(lowerText)) {
      triggers.add('emotional_processing');
      reflectionConfidence += 0.2;
    }
    
    // Struggle language without explicit request for help
    if (_containsStruggleLanguage(lowerText) && !_containsExplicitHelpRequest(lowerText)) {
      triggers.add('processing_struggle');
      reflectionConfidence += 0.15;
    }
    
    // If we have reflection triggers, return reflection
    if (triggers.isNotEmpty) {
      return SeekingResult(
        seeking: SeekingType.reflection,
        confidence: reflectionConfidence.clamp(0.0, 1.0),
        triggers: triggers,
      );
    }
    
    // Default: Exploration (safe default - asks questions to understand)
    return const SeekingResult(
      seeking: SeekingType.exploration,
      confidence: 0.5,
      triggers: ['default'],
    );
  }
  
  /// Check for direction-seeking language
  /// "What should I do?", "Tell me what to do", "Give me advice"
  static bool _containsDirectionSeeking(String lowerText) {
    final directionPatterns = [
      r'\bwhat should i do\b',
      r'\btell me what to do\b',
      r'\bgive me (advice|guidance|direction|recommendation)\b',
      r'\bwhat do you (think|suggest|recommend) i (do|should do)\b',
      r'\bwhat would you (do|suggest|recommend)\b',
      r'\bshould i \w+ or \w+\b',  // "Should I X or Y?"
      r'\bi need (advice|guidance|direction|help deciding)\b',
      r'\bhelp me decide\b',
      r'\bjust tell me\b',
      r'\bgive (me )?a straight answer\b',
      r'\bwhat (is|would be) (the )?(best|right) (thing|choice|option|move)\b',
      r'\bwhich (one|option|path|choice) should i\b',
      r'\bwhat do i do\b',
      r'\bhow do i (handle|deal with|approach|fix|solve)\b',
      r'\bwhat (steps|actions) should i (take)?\b',
    ];

    return directionPatterns.any((pattern) => 
      RegExp(pattern).hasMatch(lowerText)
    );
  }
  
  /// Check for validation-seeking language
  /// "Is it okay that...", "Am I right to feel...", "Does that make sense?"
  static bool _containsValidationSeeking(String lowerText) {
    final validationPatterns = [
      r'\bis (it|that) (okay|ok|alright|normal|valid)\b',
      r'\bam i (right|wrong|crazy|overreacting|being unreasonable)\b',
      r'\bdoes (that|this|it) make sense\b',
      r'\bis (that|this|it) (reasonable|fair|justified)\b',
      r'\bdo you (think|feel) (that|this|i)\b',
      r'\bwould you (think|feel) the same\b',
      r'\bam i justified\b',
      r"\bi'?m not (crazy|wrong|overreacting),? (right|am i)\b",
      r'\bdo i have (a )?right to\b',
      r'\bis (it|this) (too much|asking too much)\b',
      r'\bwas i (right|wrong) to\b',
      r'\bdid i (do|handle) (that|this|it) (right|okay|wrong)\b',
      r'\bi just need (to know|confirmation|reassurance)\b',
      r"\btell me (i'?m|that i'?m) (not|being) (crazy|unreasonable)\b",
      r'\bvalidate\b',
      r'\breassure me\b',
    ];

    return validationPatterns.any((pattern) => 
      RegExp(pattern).hasMatch(lowerText)
    );
  }
  
  /// Check for exploration-seeking language
  /// "Help me think through...", "What might be going on?", "Let's explore..."
  static bool _containsExplorationSeeking(String lowerText) {
    final explorationPatterns = [
      r'\bhelp me (think through|understand|figure out|work through|explore)\b',
      r'\bwhat (might|could) be (going on|happening)\b',
      r"\blet'?s (explore|think about|discuss|talk through)\b",
      r'\bi want to (explore|understand|think through|talk through)\b',
      r'\bwhy (do|might|would) (i|this)\b',
      r'\bwhat (is|does) (this|that|it) (mean|say about)\b',
      r'\bhelp me see\b',
      r'\bwhat am i (missing|not seeing)\b',
      r'\bwhat (else|other) (could|might)\b',
      r'\bcan we (explore|dig into|unpack|think about)\b',
      r'\bi want to get (to the bottom|clarity)\b',
      r'\bhelp me (connect|process|unpack)\b',
    ];

    return explorationPatterns.any((pattern) => 
      RegExp(pattern).hasMatch(lowerText)
    );
  }
  
  /// Check for venting language (processing, not seeking solutions)
  static bool _containsVentingLanguage(String lowerText) {
    final ventingPatterns = [
      r'\bi just need to (vent|get this off my chest|talk)\b',
      r'\blet me (vent|just say|get this out)\b',
      r'\bi just (want|need) (to|you to) (listen|hear me)\b',
      r"\bi don'?t (need|want) (advice|solutions|you to fix)\b",
      r'\bjust (let me|need to) (vent|talk|express)\b',
      r'\bi (just )?need to (process|express|get out)\b',
      r'\bugh\b',
      r'\bargh\b',
      r'\b(so|really) (frustrated|annoyed|upset|angry|pissed)\b',
      r"\bi can'?t (believe|stand|take)\b",
      r'\bwhy (does|do) (this|everything) (always|keep)\b',
    ];

    return ventingPatterns.any((pattern) => 
      RegExp(pattern).hasMatch(lowerText)
    );
  }
  
  /// Check for explicit help request (to distinguish processing from help-seeking)
  static bool _containsExplicitHelpRequest(String lowerText) {
    final helpPatterns = [
      r'\bhelp me\b',
      r'\bi need help\b',
      r'\bcan you help\b',
      r'\bwhat should i\b',
      r'\badvice\b',
      r'\bguidance\b',
    ];

    return helpPatterns.any((pattern) => 
      RegExp(pattern).hasMatch(lowerText)
    );
  }
  
  /// Get human-readable description of seeking type
  static String getSeekingDescription(SeekingType seeking) {
    switch (seeking) {
      case SeekingType.validation:
        return 'Validation (needs acknowledgment)';
      case SeekingType.exploration:
        return 'Exploration (wants to think through)';
      case SeekingType.direction:
        return 'Direction (wants clear guidance)';
      case SeekingType.reflection:
        return 'Reflection (needs space to process)';
    }
  }
}