// l../mira/reasoning/lumara_decisive_recommendations.dart
// LUMARA decisive recommendation system for personal growth and development

import '../memory/enhanced_attribution_schema.dart';
import '../../arc/chat/data/models/lumara_message.dart';

/// Types of recommendation requests
enum RecommendationType {
  generalAdvice,     // "What do you think I should do?"
  specificDecision,  // "Should I take this job?"
  relationshipGuidance, // "How should I handle this situation?"
  careerDirection,   // "What career path should I pursue?"
  healthWellness,    // "How can I improve my wellbeing?"
  personalGrowth,    // "How can I develop myself?"
  conflictResolution, // "How should I deal with this conflict?"
  lifeTransition,    // "How should I navigate this change?"
}

/// Growth domains for maximizing becoming
enum GrowthDomain {
  emotional,      // Emotional intelligence and regulation
  intellectual,   // Learning and cognitive development
  social,         // Relationships and communication
  physical,       // Health and physical wellbeing
  spiritual,      // Purpose and meaning
  creative,       // Creative expression and innovation
  practical,      // Life skills and practical competence
  leadership,     // Influence and guidance of others
}

/// Recommendation confidence levels
enum RecommendationConfidence {
  veryHigh('Very High', 0.9, 'Strong evidence supports this path'),
  high('High', 0.8, 'Clear indicators point in this direction'),
  moderate('Moderate', 0.7, 'Good reasons support this choice'),
  cautious('Cautious', 0.6, 'Proceed with careful consideration'),
  exploratory('Exploratory', 0.5, 'Worth exploring as an option');

  const RecommendationConfidence(this.label, this.score, this.description);
  final String label;
  final double score;
  final String description;
}

/// Safety check result
class SafetyCheck {
  final bool isSafe;
  final List<String> concerns;
  final List<String> modifications;
  final String reasoning;

  const SafetyCheck({
    required this.isSafe,
    this.concerns = const [],
    this.modifications = const [],
    required this.reasoning,
  });
}

/// A decisive recommendation with growth optimization
class DecisiveRecommendation {
  final String recommendation;
  final RecommendationType type;
  final List<GrowthDomain> growthDomains;
  final RecommendationConfidence confidence;
  final String reasoning;
  final List<String> actionSteps;
  final List<String> growthOpportunities;
  final List<String> potentialChallenges;
  final String timeframe;
  final List<String> successMetrics;
  final SafetyCheck safetyCheck;
  final SAGEResponse sageFormat;
  final ECHOResponse echoFormat;
  final List<EnhancedAttributionTrace> supportingEvidence;

  const DecisiveRecommendation({
    required this.recommendation,
    required this.type,
    required this.growthDomains,
    required this.confidence,
    required this.reasoning,
    required this.actionSteps,
    required this.growthOpportunities,
    required this.potentialChallenges,
    required this.timeframe,
    required this.successMetrics,
    required this.safetyCheck,
    required this.sageFormat,
    required this.echoFormat,
    required this.supportingEvidence,
  });
}

/// SAGE format response (Situation, Action, Growth, Essence)
class SAGEResponse {
  final String situation;
  final String action;
  final String growth;
  final String essence;

  const SAGEResponse({
    required this.situation,
    required this.action,
    required this.growth,
    required this.essence,
  });

  String format() {
    return '''
**SAGE Analysis:**

📍 **Situation**: $situation

🎯 **Action**: $action

🌱 **Growth**: $growth

💎 **Essence**: $essence''';
  }
}

/// ECHO format response (Experience, Context, Harmony, Optimization)
class ECHOResponse {
  final String experience;
  final String context;
  final String harmony;
  final String optimization;

  const ECHOResponse({
    required this.experience,
    required this.context,
    required this.harmony,
    required this.optimization,
  });

  String format() {
    return '''
**ECHO Framework:**

🎭 **Experience**: $experience

🌐 **Context**: $context

🎵 **Harmony**: $harmony

⚡ **Optimization**: $optimization''';
  }
}

/// Service for generating decisive recommendations
class LumaraDecisiveRecommendations {

  /// Detect if a message is asking for a recommendation
  static RecommendationType? detectRecommendationRequest(String userMessage) {
    final messageLower = userMessage.toLowerCase();
    print('LUMARA Debug: [Recommendation Detection] Checking message: "$userMessage"');

    // Decisive recommendation patterns
    final decisivePatterns = [
      'what should i do',
      'what do you think i should do',
      'what do you recommend',
      'what do you think',
      'what would you do',
      'what\'s your recommendation',
      'should i',
      'what direction should i',
      'how should i',
      'what path should i',
      'what choice should i make',
      'what decision should i make',
      'what action should i take',
      'give me advice',
      'help me decide',
      'tell me what to do',
      'be more decisive',
      'give me decisive input',
      'i need decisive advice',
      'don\'t ask questions',
      'stop asking questions',
      'just tell me',
      'make a decision for me',
      'i want decisive',
      'be decisive',
      'decisive input',
      'decisive advice',
      'decisive recommendation',
      'no more questions',
      'stop being wishy washy',
      'give me a clear answer',
      'what\'s the best choice',
      'what\'s the right choice',
      'which option',
      'pick one',
      'make the call',
    ];

    // Check for decisive patterns
    for (final pattern in decisivePatterns) {
      if (messageLower.contains(pattern)) {
        print('LUMARA Debug: [Recommendation Detection] ✓ MATCH found for pattern: "$pattern"');
        // Determine specific type based on context
        if (messageLower.contains('career') || messageLower.contains('job') || messageLower.contains('work')) {
          return RecommendationType.careerDirection;
        }
        if (messageLower.contains('relationship') || messageLower.contains('partner') || messageLower.contains('friend')) {
          return RecommendationType.relationshipGuidance;
        }
        if (messageLower.contains('health') || messageLower.contains('wellness') || messageLower.contains('wellbeing')) {
          return RecommendationType.healthWellness;
        }
        if (messageLower.contains('conflict') || messageLower.contains('disagreement') || messageLower.contains('argument')) {
          return RecommendationType.conflictResolution;
        }
        if (messageLower.contains('change') || messageLower.contains('transition') || messageLower.contains('moving')) {
          return RecommendationType.lifeTransition;
        }
        if (messageLower.contains('grow') || messageLower.contains('develop') || messageLower.contains('improve')) {
          return RecommendationType.personalGrowth;
        }

        // Default to general advice
        return RecommendationType.generalAdvice;
      }
    }

    print('LUMARA Debug: [Recommendation Detection] ✗ NO MATCH found - using regular processing');
    return null;
  }

  /// Generate a decisive recommendation based on user context
  static Future<DecisiveRecommendation> generateRecommendation({
    required String userMessage,
    required RecommendationType type,
    required List<EnhancedAttributionTrace> contextTraces,
    required List<LumaraMessage> conversationHistory,
    Map<String, dynamic> additionalContext = const {},
  }) async {
    // Analyze user's growth patterns and needs
    final growthAnalysis = _analyzeGrowthOpportunities(contextTraces, conversationHistory);

    // Generate the core recommendation
    final coreRecommendation = _generateCoreRecommendation(
      userMessage: userMessage,
      type: type,
      growthAnalysis: growthAnalysis,
      contextTraces: contextTraces,
    );

    // Perform safety check
    final safetyCheck = _performSafetyCheck(coreRecommendation, type);

    // Create SAGE format response
    final sageResponse = _createSAGEResponse(
      userMessage: userMessage,
      recommendation: coreRecommendation,
      contextTraces: contextTraces,
      type: type,
    );

    // Create ECHO format response
    final echoResponse = _createECHOResponse(
      userMessage: userMessage,
      recommendation: coreRecommendation,
      contextTraces: contextTraces,
      type: type,
    );

    // Determine confidence level
    final confidence = _calculateConfidence(contextTraces, type);

    return DecisiveRecommendation(
      recommendation: safetyCheck.isSafe ? coreRecommendation : _modifyForSafety(coreRecommendation, safetyCheck),
      type: type,
      growthDomains: growthAnalysis.primaryDomains,
      confidence: confidence,
      reasoning: _generateReasoning(contextTraces, type, growthAnalysis),
      actionSteps: _generateActionSteps(coreRecommendation, type),
      growthOpportunities: growthAnalysis.opportunities,
      potentialChallenges: _identifyPotentialChallenges(type, contextTraces),
      timeframe: _determineTimeframe(type),
      successMetrics: _generateSuccessMetrics(type, coreRecommendation),
      safetyCheck: safetyCheck,
      sageFormat: sageResponse,
      echoFormat: echoResponse,
      supportingEvidence: contextTraces,
    );
  }

  /// Analyze growth opportunities from user's context
  static GrowthAnalysis _analyzeGrowthOpportunities(
    List<EnhancedAttributionTrace> contextTraces,
    List<LumaraMessage> conversationHistory,
  ) {
    final patterns = <String>[];
    final domains = <GrowthDomain>[];
    final opportunities = <String>[];

    // Analyze journal entries for growth patterns
    for (final trace in contextTraces) {
      if (trace.sourceType == SourceType.journalEntry) {
        final content = trace.excerpt?.toLowerCase() ?? '';

        // Emotional domain indicators
        if (content.contains('feel') || content.contains('emotion') || content.contains('stressed')) {
          domains.add(GrowthDomain.emotional);
          opportunities.add('Develop emotional awareness and regulation skills');
        }

        // Relationship domain indicators
        if (content.contains('relationship') || content.contains('friend') || content.contains('family')) {
          domains.add(GrowthDomain.social);
          opportunities.add('Strengthen communication and relationship skills');
        }

        // Career/intellectual domain indicators
        if (content.contains('work') || content.contains('learn') || content.contains('goal')) {
          domains.add(GrowthDomain.intellectual);
          opportunities.add('Expand knowledge and professional capabilities');
        }

        // Health/physical domain indicators
        if (content.contains('health') || content.contains('exercise') || content.contains('energy')) {
          domains.add(GrowthDomain.physical);
          opportunities.add('Improve physical health and vitality');
        }

        // Purpose/spiritual domain indicators
        if (content.contains('meaning') || content.contains('purpose') || content.contains('value')) {
          domains.add(GrowthDomain.spiritual);
          opportunities.add('Deepen sense of purpose and meaning');
        }
      }
    }

    // Remove duplicates and prioritize
    final uniqueDomains = domains.toSet().toList();
    final uniqueOpportunities = opportunities.toSet().toList();

    return GrowthAnalysis(
      primaryDomains: uniqueDomains.take(3).toList(), // Top 3 growth domains
      opportunities: uniqueOpportunities,
      patterns: patterns,
    );
  }

  /// Generate core recommendation based on context
  static String _generateCoreRecommendation({
    required String userMessage,
    required RecommendationType type,
    required GrowthAnalysis growthAnalysis,
    required List<EnhancedAttributionTrace> contextTraces,
  }) {
    switch (type) {
      case RecommendationType.generalAdvice:
        return _generateGeneralAdvice(growthAnalysis, contextTraces);
      case RecommendationType.careerDirection:
        return _generateCareerRecommendation(growthAnalysis, contextTraces);
      case RecommendationType.relationshipGuidance:
        return _generateRelationshipRecommendation(growthAnalysis, contextTraces);
      case RecommendationType.healthWellness:
        return _generateHealthRecommendation(growthAnalysis, contextTraces);
      case RecommendationType.personalGrowth:
        return _generatePersonalGrowthRecommendation(growthAnalysis, contextTraces);
      case RecommendationType.conflictResolution:
        return _generateConflictResolutionRecommendation(growthAnalysis, contextTraces);
      case RecommendationType.lifeTransition:
        return _generateLifeTransitionRecommendation(growthAnalysis, contextTraces);
      case RecommendationType.specificDecision:
        return _generateSpecificDecisionRecommendation(userMessage, growthAnalysis, contextTraces);
    }
  }

  /// Generate general advice recommendation
  static String _generateGeneralAdvice(GrowthAnalysis analysis, List<EnhancedAttributionTrace> traces) {
    if (analysis.primaryDomains.contains(GrowthDomain.emotional)) {
      return 'Focus on developing emotional intelligence and self-awareness. This is your foundational growth opportunity right now.';
    }
    if (analysis.primaryDomains.contains(GrowthDomain.social)) {
      return 'Invest in strengthening your relationships and communication skills. Connection is key to your next level of growth.';
    }
    return 'Start with small, consistent actions in your strongest growth area. Build momentum before tackling larger challenges.';
  }

  /// Generate career-specific recommendation
  static String _generateCareerRecommendation(GrowthAnalysis analysis, List<EnhancedAttributionTrace> traces) {
    if (analysis.primaryDomains.contains(GrowthDomain.intellectual)) {
      return 'Pursue the opportunity that offers the greatest learning potential. Your intellectual growth is your career accelerator.';
    }
    if (analysis.primaryDomains.contains(GrowthDomain.leadership)) {
      return 'Choose the path that gives you more leadership responsibility. You\'re ready to guide others and expand your influence.';
    }
    return 'Select the option that aligns with your long-term vision while providing immediate growth opportunities.';
  }

  /// Generate relationship guidance
  static String _generateRelationshipRecommendation(GrowthAnalysis analysis, List<EnhancedAttributionTrace> traces) {
    if (analysis.primaryDomains.contains(GrowthDomain.emotional)) {
      return 'Lead with vulnerability and authentic communication. Express your feelings clearly and listen deeply to understand their perspective.';
    }
    return 'Take the initiative to create positive change in the relationship. Be the person who elevates the connection through your actions.';
  }

  /// Generate health and wellness recommendation
  static String _generateHealthRecommendation(GrowthAnalysis analysis, List<EnhancedAttributionTrace> traces) {
    if (analysis.primaryDomains.contains(GrowthDomain.physical)) {
      return 'Commit to a sustainable daily practice that energizes you. Start small but be absolutely consistent for 30 days.';
    }
    return 'Begin with the one health habit that will create the most positive ripple effect in your life. Focus on systems, not just goals.';
  }

  /// Generate personal growth recommendation
  static String _generatePersonalGrowthRecommendation(GrowthAnalysis analysis, List<EnhancedAttributionTrace> traces) {
    final topDomain = analysis.primaryDomains.isNotEmpty ? analysis.primaryDomains.first : GrowthDomain.emotional;

    switch (topDomain) {
      case GrowthDomain.emotional:
        return 'Develop daily emotional awareness practices. Your emotional intelligence is your foundation for all other growth.';
      case GrowthDomain.intellectual:
        return 'Challenge yourself with learning that stretches your current capabilities. Intellectual growth accelerates all other development.';
      case GrowthDomain.social:
        return 'Invest in relationships that challenge you to become your best self. Surround yourself with people who elevate your thinking.';
      case GrowthDomain.creative:
        return 'Engage in creative expression that energizes your soul. Creativity is your pathway to discovering hidden potentials.';
      default:
        return 'Focus on developing self-awareness through reflection and feedback. All growth begins with knowing yourself deeply.';
    }
  }

  /// Generate conflict resolution recommendation
  static String _generateConflictResolutionRecommendation(GrowthAnalysis analysis, List<EnhancedAttributionTrace> traces) {
    return 'Address the conflict directly with compassion and clarity. Seek to understand first, then work toward a solution that serves everyone\'s growth.';
  }

  /// Generate life transition recommendation
  static String _generateLifeTransitionRecommendation(GrowthAnalysis analysis, List<EnhancedAttributionTrace> traces) {
    return 'Embrace the transition as an opportunity to become who you\'re meant to be. Trust the process and take deliberate action toward your vision.';
  }

  /// Generate specific decision recommendation
  static String _generateSpecificDecisionRecommendation(String userMessage, GrowthAnalysis analysis, List<EnhancedAttributionTrace> traces) {
    return 'Choose the option that maximizes your long-term growth and aligns with your deepest values. When in doubt, choose growth over comfort.';
  }

  /// Perform safety check on recommendation
  static SafetyCheck _performSafetyCheck(String recommendation, RecommendationType type) {
    final concerns = <String>[];
    final modifications = <String>[];

    // Check for potentially harmful advice
    final harmfulPatterns = [
      'quit without a plan',
      'cut off all contact',
      'ignore your health',
      'take extreme action',
      'rush into',
    ];

    for (final pattern in harmfulPatterns) {
      if (recommendation.toLowerCase().contains(pattern)) {
        concerns.add('Recommendation may be too extreme or hasty');
        modifications.add('Add cautionary guidance and gradual approach');
      }
    }

    // Safety requirements by type
    switch (type) {
      case RecommendationType.healthWellness:
        if (!recommendation.contains('consult') && !recommendation.contains('gradual')) {
          concerns.add('Health advice should include professional consultation');
          modifications.add('Add recommendation to consult healthcare professionals');
        }
        break;
      case RecommendationType.careerDirection:
        if (recommendation.contains('quit') && !recommendation.contains('plan')) {
          concerns.add('Career advice should include financial planning');
          modifications.add('Add guidance about financial preparation');
        }
        break;
      default:
        break;
    }

    return SafetyCheck(
      isSafe: concerns.isEmpty,
      concerns: concerns,
      modifications: modifications,
      reasoning: concerns.isEmpty
        ? 'Recommendation promotes positive growth without safety concerns'
        : 'Recommendation requires modification to ensure user safety and wellbeing',
    );
  }

  /// Create SAGE format response
  static SAGEResponse _createSAGEResponse({
    required String userMessage,
    required String recommendation,
    required List<EnhancedAttributionTrace> contextTraces,
    required RecommendationType type,
  }) {
    // Extract situation context from traces
    final situationContext = _extractSituationContext(contextTraces);

    return SAGEResponse(
      situation: 'Based on your recent experiences, you\'re at a decision point that requires clear direction. $situationContext',
      action: recommendation,
      growth: 'This choice will develop your capacity in key areas while building confidence in your decision-making abilities.',
      essence: 'The deeper opportunity here is to trust your growth process and take action aligned with your highest potential.',
    );
  }

  /// Create ECHO format response
  static ECHOResponse _createECHOResponse({
    required String userMessage,
    required String recommendation,
    required List<EnhancedAttributionTrace> contextTraces,
    required RecommendationType type,
  }) {
    return const ECHOResponse(
      experience: 'Your past experiences have prepared you for this moment of choice and growth.',
      context: 'The current circumstances provide an optimal opportunity for positive change and development.',
      harmony: 'This recommendation aligns your actions with your values while honoring your growth trajectory.',
      optimization: 'Taking this action will maximize your potential while creating positive momentum for future decisions.',
    );
  }

  /// Helper methods for generating components
  static String _extractSituationContext(List<EnhancedAttributionTrace> traces) {
    if (traces.isEmpty) return 'You\'re navigating new territory.';

    final recentTrace = traces.first;
    if (recentTrace.excerpt != null) {
      return 'Your recent reflection shows: "${recentTrace.excerpt!.substring(0, recentTrace.excerpt!.length > 50 ? 50 : recentTrace.excerpt!.length)}..."';
    }

    return 'Drawing from your recent experiences and reflections.';
  }

  static List<String> _generateActionSteps(String recommendation, RecommendationType type) {
    switch (type) {
      case RecommendationType.careerDirection:
        return [
          'Clarify your specific goals and timeline',
          'Research requirements and opportunities',
          'Create a practical action plan',
          'Take the first concrete step within 48 hours',
        ];
      case RecommendationType.relationshipGuidance:
        return [
          'Reflect on your desired outcome',
          'Plan your communication approach',
          'Choose the right time and setting',
          'Express yourself with clarity and compassion',
        ];
      default:
        return [
          'Define your specific next action',
          'Set a timeline for implementation',
          'Identify potential obstacles',
          'Take the first step immediately',
        ];
    }
  }

  static List<String> _identifyPotentialChallenges(RecommendationType type, List<EnhancedAttributionTrace> traces) {
    switch (type) {
      case RecommendationType.careerDirection:
        return ['Financial uncertainty during transition', 'Imposter syndrome in new role', 'Work-life balance adjustments'];
      case RecommendationType.relationshipGuidance:
        return ['Initial discomfort with vulnerability', 'Potential resistance from others', 'Need for patience with change'];
      default:
        return ['Initial resistance to change', 'Maintaining consistency over time', 'Adapting approach based on results'];
    }
  }

  static String _determineTimeframe(RecommendationType type) {
    switch (type) {
      case RecommendationType.careerDirection:
        return '3-6 months for significant progress, 1-2 years for full transition';
      case RecommendationType.relationshipGuidance:
        return 'Immediate action, 1-3 months to see substantial improvement';
      case RecommendationType.healthWellness:
        return '30 days for habit formation, 3-6 months for significant results';
      default:
        return '2-4 weeks for initial progress, 3-6 months for substantial change';
    }
  }

  static List<String> _generateSuccessMetrics(RecommendationType type, String recommendation) {
    switch (type) {
      case RecommendationType.careerDirection:
        return ['Clear progress toward goals weekly', 'Increased confidence in abilities', 'Positive feedback from others', 'Greater alignment with values'];
      case RecommendationType.relationshipGuidance:
        return ['Improved communication quality', 'Increased mutual understanding', 'Reduced conflict frequency', 'Stronger emotional connection'];
      default:
        return ['Consistent progress on action steps', 'Increased clarity and confidence', 'Positive momentum building', 'Alignment with personal values'];
    }
  }

  static RecommendationConfidence _calculateConfidence(List<EnhancedAttributionTrace> traces, RecommendationType type) {
    if (traces.length >= 5) return RecommendationConfidence.veryHigh;
    if (traces.length >= 3) return RecommendationConfidence.high;
    if (traces.length >= 2) return RecommendationConfidence.moderate;
    return RecommendationConfidence.cautious;
  }

  static String _generateReasoning(List<EnhancedAttributionTrace> traces, RecommendationType type, GrowthAnalysis analysis) {
    return 'Based on analysis of ${traces.length} relevant context sources, your primary growth opportunities lie in ${analysis.primaryDomains.map((d) => d.name).join(', ')}. The recommendation optimizes for your personal development while ensuring practical feasibility.';
  }

  static String _modifyForSafety(String recommendation, SafetyCheck safetyCheck) {
    var modified = recommendation;
    for (final modification in safetyCheck.modifications) {
      if (modification.contains('gradual')) {
        modified = 'Gradually $modified';
      }
      if (modification.contains('professional')) {
        modified = '$modified (Consider consulting with relevant professionals for guidance)';
      }
      if (modification.contains('financial')) {
        modified = '$modified Ensure you have adequate financial preparation before making major changes.';
      }
    }
    return modified;
  }
}

/// Growth analysis result
class GrowthAnalysis {
  final List<GrowthDomain> primaryDomains;
  final List<String> opportunities;
  final List<String> patterns;

  const GrowthAnalysis({
    required this.primaryDomains,
    required this.opportunities,
    required this.patterns,
  });
}