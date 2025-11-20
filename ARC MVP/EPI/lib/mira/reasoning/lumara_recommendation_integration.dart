// l../mira/reasoning/lumara_recommendation_integration.dart
// Integration service for LUMARA decisive recommendations with chat system

import 'lumara_decisive_recommendations.dart';
import '../memory/enhanced_attribution_schema.dart';
import '../memory/enhanced_attribution_service.dart';
import '../../arc/chat/data/models/lumara_message.dart';
import '../../arc/chat/services/lumara_reflection_settings_service.dart';

/// Integration service for decisive recommendations in LUMARA
class LumaraRecommendationIntegration {

  /// Enhanced prompt system that checks for recommendation requests
  static Future<String> processUserMessage({
    required String userMessage,
    required List<LumaraMessage> conversationHistory,
    required EnhancedAttributionService attributionService,
    required String messageId,
    Map<String, dynamic> additionalContext = const {},
  }) async {
    // Check if this is a recommendation request
    final recommendationType = LumaraDecisiveRecommendations.detectRecommendationRequest(userMessage);

    if (recommendationType != null) {
      print('LUMARA Debug: [Recommendation Integration] ✓ Processing recommendation type: ${recommendationType.name}');
      // Generate enhanced response with decisive recommendation
      return await _generateDecisiveResponse(
        userMessage: userMessage,
        type: recommendationType,
        conversationHistory: conversationHistory,
        attributionService: attributionService,
        messageId: messageId,
        additionalContext: additionalContext,
      );
    }

    // Return null to indicate this should be processed by normal LUMARA flow
    return '';
  }

  /// Generate a decisive recommendation response
  static Future<String> _generateDecisiveResponse({
    required String userMessage,
    required RecommendationType type,
    required List<LumaraMessage> conversationHistory,
    required EnhancedAttributionService attributionService,
    required String messageId,
    required Map<String, dynamic> additionalContext,
  }) async {
    print('LUMARA Debug: [Recommendation Integration] Starting context gathering...');
    // Get enhanced attribution context
    final contextTraces = await _gatherRecommendationContext(
      userMessage: userMessage,
      conversationHistory: conversationHistory,
      attributionService: attributionService,
    );

    print('LUMARA Debug: [Recommendation Integration] Found ${contextTraces.length} context traces');

    // Generate the decisive recommendation
    final recommendation = await LumaraDecisiveRecommendations.generateRecommendation(
      userMessage: userMessage,
      type: type,
      contextTraces: contextTraces,
      conversationHistory: conversationHistory,
      additionalContext: additionalContext,
    );

    print('LUMARA Debug: [Recommendation Integration] Generated recommendation: ${recommendation.recommendation.substring(0, recommendation.recommendation.length > 100 ? 100 : recommendation.recommendation.length)}...');

    // Format the response with SAGE and ECHO structures
    final formattedResponse = _formatDecisiveResponse(recommendation, type);
    print('LUMARA Debug: [Recommendation Integration] ✓ Returning formatted response (${formattedResponse.length} chars)');
    return formattedResponse;
  }

  /// Gather context for recommendation from multiple sources
  static Future<List<EnhancedAttributionTrace>> _gatherRecommendationContext({
    required String userMessage,
    required List<LumaraMessage> conversationHistory,
    required EnhancedAttributionService attributionService,
  }) async {
    // Get user's LUMARA settings
    final settingsService = LumaraReflectionSettingsService.instance;
    final similarityThreshold = await settingsService.getSimilarityThreshold();
    final maxMatches = await settingsService.getEffectiveMaxMatches();
    final lookbackYears = await settingsService.getEffectiveLookbackYears();
    final crossModalEnabled = await settingsService.isCrossModalEnabled();

    print('LUMARA Debug: [Context Gathering] Using settings - threshold: $similarityThreshold, maxMatches: $maxMatches, lookback: ${lookbackYears}y, crossModal: $crossModalEnabled');

    final contextTraces = <EnhancedAttributionTrace>[];

    // Priority 1: Current conversation context (high relevance for decisions)
    final conversationTraces = await _getConversationContextTraces(
      userMessage: userMessage,
      conversationHistory: conversationHistory,
      maxMatches: maxMatches,
      similarityThreshold: similarityThreshold,
    );
    contextTraces.addAll(conversationTraces);

    // Priority 2: Use Enhanced Attribution Service for multi-source memory gathering
    try {
      print('LUMARA Debug: [Context Gathering] Calling enhanced attribution service...');
      final multiSourceTraces = await attributionService.gatherContextTraces(
        userMessage: userMessage,
        currentSessionMessages: conversationHistory,
        // Note: In a real implementation, you'd pass actual data:
        // journalEntries: await getJournalEntries(),
        // chatMessages: await getChatHistory(),
        // mediaReferences: await getMediaReferences(),
        // arcformData: await getArcformData(),
      );

      print('LUMARA Debug: [Context Gathering] Enhanced attribution service returned ${multiSourceTraces.length} traces');
      contextTraces.addAll(multiSourceTraces);
    } catch (e) {
      print('LUMARA Debug: [Context Gathering] Enhanced attribution service error: $e');
      // Fallback to manual gathering if enhanced service fails

      // Priority 2 Fallback: Recent journal entries (personal context)
      final journalTraces = await _getJournalContextTraces(
        userMessage: userMessage,
        maxMatches: maxMatches,
        similarityThreshold: similarityThreshold,
      );
      contextTraces.addAll(journalTraces);

      // Priority 3 Fallback: Past LUMARA recommendations for learning
      final pastRecommendationTraces = await _getPastRecommendationTraces(
        conversationHistory: conversationHistory,
        maxMatches: maxMatches,
      );
      contextTraces.addAll(pastRecommendationTraces);

      // Priority 4 Fallback: Relevant phase and emotional context (if cross-modal enabled)
      if (crossModalEnabled) {
        final phaseTraces = await _getPhaseContextTraces();
        contextTraces.addAll(phaseTraces);
      }
    }

    // Apply max matches limit across all sources
    final limitedTraces = contextTraces.take(maxMatches * 2).toList(); // Allow 2x for diverse sources
    print('LUMARA Debug: [Context Gathering] Returning ${limitedTraces.length} total context traces');

    return limitedTraces;
  }

  /// Get conversation context traces
  static Future<List<EnhancedAttributionTrace>> _getConversationContextTraces({
    required String userMessage,
    required List<LumaraMessage> conversationHistory,
    required int maxMatches,
    required double similarityThreshold,
  }) async {
    final traces = <EnhancedAttributionTrace>[];

    // Analyze recent conversation for decision-relevant context (respect maxMatches)
    final lookbackLimit = (maxMatches * 1.5).round().clamp(5, 20); // Allow more candidates for filtering
    final recentMessages = conversationHistory.take(lookbackLimit).toList();

    for (int i = 0; i < recentMessages.length; i++) {
      final message = recentMessages[i];
      final relevanceScore = _calculateRelevanceScore(message.content, userMessage);
      final isRelevant = relevanceScore >= similarityThreshold;

      if (isRelevant) {
        final trace = EnhancedAttributionTrace(
          nodeRef: message.id,
          sourceType: message.role == LumaraMessageRole.assistant
              ? SourceType.lumaraResponse
              : SourceType.chatMessage,
          relation: 'contextualizes',
          confidence: 0.8 - (i * 0.1), // Decrease confidence for older messages
          timestamp: DateTime.now(),
          reasoning: 'Previous conversation provides decision context',
          excerpt: _extractDecisionRelevantExcerpt(message.content),
          sourceMetadata: {
            'role': message.role.name,
            'timestamp': message.timestamp.toIso8601String(),
            'conversation_position': i,
          },
        );
        traces.add(trace);
      }
    }

    return traces;
  }

  /// Get journal context traces
  static Future<List<EnhancedAttributionTrace>> _getJournalContextTraces({
    required String userMessage,
    required int maxMatches,
    required double similarityThreshold,
  }) async {
    // Mock implementation - in real app, this would query journal entries
    final traces = <EnhancedAttributionTrace>[];

    // Example: Recent journal entry that might inform decision
    traces.add(EnhancedAttributionTrace(
      nodeRef: 'recent_journal_entry',
      sourceType: SourceType.journalEntry,
      relation: 'supports',
      confidence: 0.9,
      timestamp: DateTime.now(),
      reasoning: 'Recent journal reflection provides personal insight for decision',
      excerpt: 'I\'ve been thinking about making changes that align with my values and long-term growth...',
      sourceMetadata: {
        'entry_type': 'reflection',
        'days_ago': 2,
      },
    ));

    return traces;
  }

  /// Get past LUMARA recommendation traces
  static Future<List<EnhancedAttributionTrace>> _getPastRecommendationTraces({
    required List<LumaraMessage> conversationHistory,
    required int maxMatches,
  }) async {
    final traces = <EnhancedAttributionTrace>[];
    int count = 0;

    // Look for past LUMARA responses that contained recommendations (limit by maxMatches)
    for (final message in conversationHistory) {
      if (count >= maxMatches) break;

      if (message.role == LumaraMessageRole.assistant &&
          _containsRecommendation(message.content)) {

        final trace = EnhancedAttributionTrace(
          nodeRef: message.id,
          sourceType: SourceType.lumaraResponse,
          relation: 'builds_on',
          confidence: 0.7,
          timestamp: DateTime.now(),
          reasoning: 'Previous LUMARA recommendation provides learning context',
          excerpt: _extractRecommendationExcerpt(message.content),
          sourceMetadata: {
            'response_type': 'past_recommendation',
            'timestamp': message.timestamp.toIso8601String(),
          },
        );
        traces.add(trace);
        count++;
      }
    }

    return traces;
  }

  /// Get phase context traces
  static Future<List<EnhancedAttributionTrace>> _getPhaseContextTraces() async {
    final traces = <EnhancedAttributionTrace>[];

    // Mock implementation - in real app, this would get current phase data
    traces.add(EnhancedAttributionTrace(
      nodeRef: 'current_phase_data',
      sourceType: SourceType.phaseRegime,
      relation: 'contextualizes',
      confidence: 0.6,
      timestamp: DateTime.now(),
      reasoning: 'Current phase and emotional state inform optimal decision timing',
      excerpt: 'Current phase: Transition → Discovery. Emotional state: Open to growth and change.',
      sourceMetadata: {
        'phase': 'transition_to_discovery',
        'emotional_readiness': 'high',
        'confidence_level': 'growing',
      },
    ));

    return traces;
  }

  /// Format the decisive response with SAGE and ECHO structures
  static String _formatDecisiveResponse(DecisiveRecommendation recommendation, RecommendationType type) {
    final response = StringBuffer();

    // Header with confidence indicator
    response.writeln('## 🎯 Decisive Recommendation');
    response.writeln('**Confidence Level**: ${recommendation.confidence.label} - ${recommendation.confidence.description}');
    response.writeln();

    // Core recommendation (clear and decisive)
    response.writeln('### 💡 My Recommendation');
    response.writeln(recommendation.recommendation);
    response.writeln();

    // Reasoning based on evidence
    response.writeln('### 🧠 Why This Recommendation');
    response.writeln(recommendation.reasoning);
    response.writeln();

    // Safety check notice if applicable
    if (!recommendation.safetyCheck.isSafe) {
      response.writeln('### ⚠️ Important Considerations');
      for (final concern in recommendation.safetyCheck.concerns) {
        response.writeln('• $concern');
      }
      response.writeln();
    }

    // SAGE format
    response.writeln(recommendation.sageFormat.format());
    response.writeln();

    // ECHO format
    response.writeln(recommendation.echoFormat.format());
    response.writeln();

    // Actionable steps
    response.writeln('### 🚀 Next Actions');
    for (int i = 0; i < recommendation.actionSteps.length; i++) {
      response.writeln('${i + 1}. ${recommendation.actionSteps[i]}');
    }
    response.writeln();

    // Growth opportunities
    response.writeln('### 🌱 Growth Opportunities');
    for (final opportunity in recommendation.growthOpportunities) {
      response.writeln('• $opportunity');
    }
    response.writeln();

    // Timeline and success metrics
    response.writeln('### ⏰ Timeline & Success');
    response.writeln('**Timeframe**: ${recommendation.timeframe}');
    response.writeln();
    response.writeln('**Success Indicators**:');
    for (final metric in recommendation.successMetrics) {
      response.writeln('• $metric');
    }
    response.writeln();

    // Potential challenges
    response.writeln('### 🎯 Potential Challenges & How to Navigate Them');
    for (final challenge in recommendation.potentialChallenges) {
      response.writeln('• $challenge');
    }
    response.writeln();

    // Evidence footer
    response.writeln('### 📊 Evidence Base');
    response.writeln('This recommendation is based on analysis of ${recommendation.supportingEvidence.length} sources from your personal context, including recent conversations, journal reflections, and growth patterns.');

    return response.toString();
  }

  /// Helper methods for content analysis
  static bool _isRelevantForDecision(String messageContent, String userMessage) {
    final messageLower = messageContent.toLowerCase();
    final userLower = userMessage.toLowerCase();

    // Look for shared keywords or themes
    final messageWords = messageLower.split(' ');
    final userWords = userLower.split(' ');
    final sharedWords = messageWords.where((word) => userWords.contains(word) && word.length > 3).length;

    // Consider relevant if there are shared meaningful words or decision-related content
    return sharedWords > 2 ||
           messageLower.contains('decision') ||
           messageLower.contains('choice') ||
           messageLower.contains('should') ||
           messageLower.contains('recommend');
  }

  static bool _containsRecommendation(String content) {
    final contentLower = content.toLowerCase();
    return contentLower.contains('recommend') ||
           contentLower.contains('suggest') ||
           contentLower.contains('should') ||
           contentLower.contains('consider') ||
           contentLower.contains('advise');
  }

  static String _extractDecisionRelevantExcerpt(String content) {
    // Extract the most relevant part for decision-making
    final sentences = content.split(RegExp(r'[.!?]\s+'));

    for (final sentence in sentences) {
      final sentenceLower = sentence.toLowerCase();
      if (sentenceLower.contains('decision') ||
          sentenceLower.contains('choice') ||
          sentenceLower.contains('should') ||
          sentenceLower.contains('important')) {
        return sentence.length > 150 ? sentence.substring(0, 147) + '...' : sentence;
      }
    }

    // Fallback to first meaningful sentence
    final firstMeaningful = sentences.firstWhere(
      (s) => s.trim().length > 10,
      orElse: () => content,
    );

    return firstMeaningful.length > 150 ? firstMeaningful.substring(0, 147) + '...' : firstMeaningful;
  }

  static String _extractRecommendationExcerpt(String content) {
    final sentences = content.split(RegExp(r'[.!?]\s+'));

    for (final sentence in sentences) {
      final sentenceLower = sentence.toLowerCase();
      if (sentenceLower.contains('recommend') ||
          sentenceLower.contains('suggest') ||
          sentenceLower.contains('advise')) {
        return sentence.length > 150 ? sentence.substring(0, 147) + '...' : sentence;
      }
    }

    return content.length > 150 ? content.substring(0, 147) + '...' : content;
  }

  /// Create enhanced attribution for the recommendation response
  static Future<void> recordRecommendationAttribution({
    required String responseId,
    required DecisiveRecommendation recommendation,
    required EnhancedAttributionService attributionService,
  }) async {
    // Record the recommendation generation with enhanced attribution
    await attributionService.recordMultiSourceMemoryUsage(
      responseId: responseId,
      responseContent: _formatDecisiveResponse(recommendation, recommendation.type),
      currentUserMessage: 'User requested decisive recommendation',
      model: 'LUMARA_Decisive_v1.0',
      context: {
        'recommendation_type': recommendation.type.name,
        'confidence_level': recommendation.confidence.label,
        'growth_domains': recommendation.growthDomains.map((d) => d.name).toList(),
        'safety_check_passed': recommendation.safetyCheck.isSafe,
        'timeframe': recommendation.timeframe,
      },
      traces: recommendation.supportingEvidence,
      includeConversationContext: true,
    );
  }

  /// Generate LUMARA prompt that incorporates past recommendations for learning
  static String generateContextAwarePrompt({
    required String userMessage,
    required List<LumaraMessage> conversationHistory,
    required List<EnhancedAttributionTrace> contextTraces,
  }) {
    final prompt = StringBuffer();

    prompt.writeln('You are LUMARA, a decisive AI assistant focused on maximizing human growth and potential.');
    prompt.writeln();
    prompt.writeln('CRITICAL INSTRUCTIONS for recommendation requests:');
    prompt.writeln('- BE DECISIVE: Give clear, actionable recommendations, not wishy-washy suggestions');
    prompt.writeln('- MAXIMIZE BECOMING: Always optimize for the person\'s highest growth and potential');
    prompt.writeln('- SAFETY FIRST: Never recommend anything harmful, but be bold within safe boundaries');
    prompt.writeln('- USE EVIDENCE: Draw from their personal context, conversations, and growth patterns');
    prompt.writeln('- STRUCTURE RESPONSES: Use SAGE (Situation, Action, Growth, Essence) and ECHO frameworks');
    prompt.writeln();

    // Add context from attributions
    if (contextTraces.isNotEmpty) {
      prompt.writeln('PERSONAL CONTEXT TO INFORM YOUR RECOMMENDATION:');
      for (final trace in contextTraces.take(5)) {
        prompt.writeln('- ${trace.sourceType.name}: ${trace.excerpt ?? trace.reasoning}');
      }
      prompt.writeln();
    }

    // Add conversation learning
    final pastRecommendations = conversationHistory
        .where((m) => m.role == LumaraMessageRole.assistant && _containsRecommendation(m.content))
        .take(3);

    if (pastRecommendations.isNotEmpty) {
      prompt.writeln('LEARN FROM PAST RECOMMENDATIONS:');
      for (final rec in pastRecommendations) {
        prompt.writeln('- Previous guidance: ${_extractRecommendationExcerpt(rec.content)}');
      }
      prompt.writeln();
    }

    prompt.writeln('USER MESSAGE: $userMessage');
    prompt.writeln();
    prompt.writeln('Provide a decisive, growth-oriented recommendation using SAGE and ECHO frameworks.');

    return prompt.toString();
  }

  /// Calculate relevance score between message content and user query
  static double _calculateRelevanceScore(String messageContent, String userQuery) {
    final messageLower = messageContent.toLowerCase();
    final queryLower = userQuery.toLowerCase();

    double score = 0.0;

    // Word overlap scoring
    final messageWords = messageLower.split(RegExp(r'\W+'));
    final queryWords = queryLower.split(RegExp(r'\W+'));

    final meaningfulMessageWords = messageWords.where((w) => w.length > 3).toSet();
    final meaningfulQueryWords = queryWords.where((w) => w.length > 3).toSet();

    if (meaningfulQueryWords.isNotEmpty && meaningfulMessageWords.isNotEmpty) {
      final overlap = meaningfulQueryWords.intersection(meaningfulMessageWords).length;
      score += (overlap / meaningfulQueryWords.length) * 0.6;
    }

    // Decision-related content boost
    final decisionKeywords = ['decision', 'choice', 'should', 'recommend', 'advice', 'help', 'think', 'suggest'];
    if (decisionKeywords.any((keyword) => messageLower.contains(keyword))) {
      score += 0.3;
    }

    // Recent emotional context boost
    final emotionalKeywords = ['feel', 'emotion', 'stressed', 'anxious', 'excited', 'worried', 'confident'];
    if (emotionalKeywords.any((keyword) => messageLower.contains(keyword))) {
      score += 0.2;
    }

    return score.clamp(0.0, 1.0);
  }
}