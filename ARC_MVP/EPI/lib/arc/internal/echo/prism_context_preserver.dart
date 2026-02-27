/// PRISM Context Preservation Layer
/// 
/// Enhanced PRISM layer that scrubs PII while preserving
/// conversational structure for cloud API effectiveness.
/// 
/// Core principle: Strip identifiers, preserve meaning and structure.
library;

import 'prism_adapter.dart';

/// Query types that inform response style
enum QueryType {
  question,                          // Asking for information
  requestForSuggestions,             // Wants concrete ideas
  requestForInput,                   // Wants perspective/thoughts
  requestForValidation,              // Wants confirmation/support
  requestForChallenge,               // Wants to be pushed
  statement,                         // Just sharing information
  thinkingAloud,                     // Processing out loud
  frustratedWithReflection,           // Explicitly frustrated with mirroring
}

/// Expected response types
enum ExpectedResponseType {
  substantiveAnswerWithConcreteSuggestions,
  validationAndGentleAcknowledgment,
  strategicDirectionWithPrioritization,
  groundingWithoutSolving,
  directAnswer,
  challengeWithAccountability,
  patternRecognition,
  analyticalSynthesis,
  gentleOptionsWithPermission,
  practicalSuggestionsWithOptions,
  encouragingWithConcreteNextSteps,
  directPerspective,
  briefAcknowledgment,
  observationOrQuestion,
  honestValidationWithoutPandering,
  directAnswerNoMoreReflection,
}

/// Context payload for cloud API
class PrismContextPayload {
  final int conversationTurn;
  final int totalTurns;
  final String previousContext;
  final QueryType currentQueryType;
  final String semanticContent;
  final String phase;
  final double phaseStability;
  final double emotionalIntensity;
  final String engagementMode;
  final List<String> recentPatterns;
  final ExpectedResponseType expectedResponseType;
  final String interactionMode; // "voice" or "text"
  final String scrubbedInput; // The actual scrubbed user input

  PrismContextPayload({
    required this.conversationTurn,
    required this.totalTurns,
    required this.previousContext,
    required this.currentQueryType,
    required this.semanticContent,
    required this.phase,
    required this.phaseStability,
    required this.emotionalIntensity,
    required this.engagementMode,
    required this.recentPatterns,
    required this.expectedResponseType,
    required this.interactionMode,
    required this.scrubbedInput,
  });

  /// Convert to JSON for cloud API
  Map<String, dynamic> toJson() {
    return {
      'conversation_turn': conversationTurn,
      'total_turns': totalTurns,
      'previous_context': previousContext,
      'current_query_type': _queryTypeToString(currentQueryType),
      'semantic_content': semanticContent,
      'phase': phase,
      'phase_stability': phaseStability,
      'emotional_intensity': emotionalIntensity,
      'engagement_mode': engagementMode,
      'recent_patterns': recentPatterns,
      'expected_response_type': _expectedResponseTypeToString(expectedResponseType),
      'interaction_mode': interactionMode,
      'scrubbed_input': scrubbedInput,
    };
  }

  String _queryTypeToString(QueryType type) {
    switch (type) {
      case QueryType.question:
        return 'question';
      case QueryType.requestForSuggestions:
        return 'request_for_suggestions';
      case QueryType.requestForInput:
        return 'request_for_input';
      case QueryType.requestForValidation:
        return 'request_for_validation';
      case QueryType.requestForChallenge:
        return 'request_for_challenge';
      case QueryType.statement:
        return 'statement';
      case QueryType.thinkingAloud:
        return 'thinking_aloud';
      case QueryType.frustratedWithReflection:
        return 'frustrated_with_reflection';
    }
  }

  String _expectedResponseTypeToString(ExpectedResponseType type) {
    switch (type) {
      case ExpectedResponseType.substantiveAnswerWithConcreteSuggestions:
        return 'substantive_answer_with_concrete_suggestions';
      case ExpectedResponseType.validationAndGentleAcknowledgment:
        return 'validation_and_gentle_acknowledgment';
      case ExpectedResponseType.strategicDirectionWithPrioritization:
        return 'strategic_direction_with_prioritization';
      case ExpectedResponseType.groundingWithoutSolving:
        return 'grounding_without_solving';
      case ExpectedResponseType.directAnswer:
        return 'direct_answer';
      case ExpectedResponseType.challengeWithAccountability:
        return 'challenge_with_accountability';
      case ExpectedResponseType.patternRecognition:
        return 'pattern_recognition';
      case ExpectedResponseType.analyticalSynthesis:
        return 'analytical_synthesis';
      case ExpectedResponseType.gentleOptionsWithPermission:
        return 'gentle_options_with_permission';
      case ExpectedResponseType.practicalSuggestionsWithOptions:
        return 'practical_suggestions_with_options';
      case ExpectedResponseType.encouragingWithConcreteNextSteps:
        return 'encouraging_with_concrete_next_steps';
      case ExpectedResponseType.directPerspective:
        return 'direct_perspective';
      case ExpectedResponseType.briefAcknowledgment:
        return 'brief_acknowledgment';
      case ExpectedResponseType.observationOrQuestion:
        return 'observation_or_question';
      case ExpectedResponseType.honestValidationWithoutPandering:
        return 'honest_validation_without_pandering';
      case ExpectedResponseType.directAnswerNoMoreReflection:
        return 'direct_answer_no_more_reflection';
    }
  }
}

/// Conversation turn for context building
class ConversationTurn {
  final String userText;
  final String lumaraText;
  final DateTime timestamp;

  ConversationTurn({
    required this.userText,
    required this.lumaraText,
    required this.timestamp,
  });
}

/// Phase data for context
class PhaseData {
  final String currentPhase;
  final double stability;
  final double intensity;
  final List<String> recentPatterns;

  PhaseData({
    required this.currentPhase,
    required this.stability,
    required this.intensity,
    required this.recentPatterns,
  });
}

/// PRISM Context Preserver
/// 
/// Prepares privacy-safe, context-rich payloads for cloud API
class PrismContextPreserver {
  final PrismAdapter _prismAdapter = PrismAdapter();

  /// Main entry point: Convert raw user input into privacy-safe,
  /// context-rich payload for cloud API
  PrismContextPayload prepareCloudContext({
    required String userInput,
    required List<ConversationTurn> conversationHistory,
    required PhaseData phaseData,
    required String engagementMode,
    required bool isVoiceSession,
  }) {
    // Step 1: Scrub PII from current input
    final prismResult = _prismAdapter.scrub(userInput);
    final scrubbedInput = prismResult.scrubbedText;

    // Step 2: Classify what type of query this is
    final queryType = _classifyQuery(userInput);

    // Step 3: Extract semantic meaning
    final semanticContent = _extractSemanticContent(
      scrubbedInput,
      conversationHistory,
    );

    // Step 4: Build conversational context
    final previousContext = _buildPreviousContext(
      conversationHistory: conversationHistory,
      lookback: 3,
    );

    // Step 5: Infer expected response type
    final expectedResponse = _inferExpectedResponse(
      queryType: queryType,
      phase: phaseData.currentPhase,
      intensity: phaseData.intensity,
    );

    // Step 6: Assemble full context payload
    return PrismContextPayload(
      conversationTurn: conversationHistory.length + 1,
      totalTurns: conversationHistory.length,
      previousContext: previousContext,
      currentQueryType: queryType,
      semanticContent: semanticContent,
      phase: phaseData.currentPhase.toLowerCase(),
      phaseStability: phaseData.stability,
      emotionalIntensity: phaseData.intensity,
      engagementMode: engagementMode.toLowerCase(),
      recentPatterns: phaseData.recentPatterns,
      expectedResponseType: expectedResponse,
      interactionMode: isVoiceSession ? 'voice' : 'text',
      scrubbedInput: scrubbedInput,
    );
  }

  /// Classify the query type based on linguistic patterns
  QueryType _classifyQuery(String userInput) {
    final lowerInput = userInput.toLowerCase();

    // Frustration signals (highest priority)
    final frustrationSignals = [
      "i'm asking you",
      "i asked you",
      "just tell me",
      "give me an answer",
      "stop reflecting",
      "actually answer",
    ];
    if (frustrationSignals.any((signal) => lowerInput.contains(signal))) {
      return QueryType.frustratedWithReflection;
    }

    // Challenge requests
    final challengeSignals = [
      "be honest",
      "don't sugarcoat",
      "challenge me",
      "push me",
      "give it to me straight",
    ];
    if (challengeSignals.any((signal) => lowerInput.contains(signal))) {
      return QueryType.requestForChallenge;
    }

    // Validation requests
    final validationSignals = [
      "is this silly",
      "am i crazy",
      "does this make sense",
      "is it okay",
      "am i overthinking",
    ];
    if (validationSignals.any((signal) => lowerInput.contains(signal))) {
      return QueryType.requestForValidation;
    }

    // Suggestion requests
    final suggestionSignals = [
      "suggestions",
      "recommendations",
      "what should i",
      "how do i",
      "how would i",
      "what are some ways",
      "ideas for",
    ];
    if (suggestionSignals.any((signal) => lowerInput.contains(signal))) {
      return QueryType.requestForSuggestions;
    }

    // Input/perspective requests
    final inputSignals = [
      "what do you think",
      "your thoughts",
      "input on",
      "perspective on",
      "thoughts on",
    ];
    if (inputSignals.any((signal) => lowerInput.contains(signal))) {
      return QueryType.requestForInput;
    }

    // Questions (general)
    if (userInput.contains('?') ||
        lowerInput.startsWith('what') ||
        lowerInput.startsWith('how') ||
        lowerInput.startsWith('why') ||
        lowerInput.startsWith('when') ||
        lowerInput.startsWith('where') ||
        lowerInput.startsWith('who') ||
        lowerInput.startsWith('which')) {
      return QueryType.question;
    }

    // Thinking aloud
    final thinkingSignals = [
      "i think",
      "i'm thinking",
      "wondering if",
      "i wonder",
      "maybe i",
    ];
    if (thinkingSignals.any((signal) => lowerInput.contains(signal))) {
      return QueryType.thinkingAloud;
    }

    // Default to statement
    return QueryType.statement;
  }

  /// Extract semantic meaning from scrubbed input
  String _extractSemanticContent(
    String scrubbedInput,
    List<ConversationTurn> context,
  ) {
    // Check if input is pronoun-heavy
    final isPronounHeavy = _isPronounHeavy(scrubbedInput);

    // Get main topic
    String mainTopic;
    if (isPronounHeavy && context.isNotEmpty) {
      mainTopic = _extractTopicFromContext(context);
    } else {
      mainTopic = _extractTopicFromInput(scrubbedInput);
    }

    // Get intent
    final intent = _extractIntent(scrubbedInput);

    return "$intent $mainTopic";
  }

  /// Check if text relies heavily on pronouns
  bool _isPronounHeavy(String text) {
    final pronouns = ['this', 'that', 'it', 'these', 'those'];
    final words = text.toLowerCase().split(' ');
    if (words.isEmpty) return false;
    final pronounCount = words.where((w) => pronouns.contains(w)).length;
    return pronounCount / words.length > 0.2;
  }

  /// Extract topic from conversation context
  String _extractTopicFromContext(List<ConversationTurn> context) {
    if (context.isEmpty) return 'topic';
    // Use the most recent user turn to infer topic
    final lastTurn = context.last.userText;
    // Simple extraction: take first few words after scrubbing
    final scrubbed = _prismAdapter.scrub(lastTurn).scrubbedText;
    final words = scrubbed.split(' ').take(5).join(' ');
    return words.isNotEmpty ? words : 'topic';
  }

  /// Extract topic from input
  String _extractTopicFromInput(String scrubbedInput) {
    // Simple extraction: take key words
    final words = scrubbedInput.split(' ').where((w) {
      final lower = w.toLowerCase();
      return !['the', 'a', 'an', 'is', 'are', 'was', 'were', 'to', 'of', 'in', 'on', 'at', 'for', 'with'].contains(lower);
    }).take(5).join(' ');
    return words.isNotEmpty ? words : 'topic';
  }

  /// Extract what the user intends to do/get
  String _extractIntent(String text) {
    final lower = text.toLowerCase();

    if (lower.contains('how') && (lower.contains('do') || lower.contains('implement'))) {
      return 'User wants implementation steps for';
    } else if (lower.contains('suggestions') || lower.contains('recommendations')) {
      return 'User wants suggestions for';
    } else if (lower.contains('thoughts') || lower.contains('think')) {
      return 'User wants perspective on';
    } else if (lower.contains('is') && ['silly', 'okay', 'valid', 'crazy'].any((w) => lower.contains(w))) {
      return 'User seeks validation about';
    } else if (text.contains('?')) {
      return 'User asks about';
    } else {
      return 'User discusses';
    }
  }

  /// Build summary of previous turns WITHOUT exposing PII
  String _buildPreviousContext({
    required List<ConversationTurn> conversationHistory,
    int lookback = 3,
  }) {
    if (conversationHistory.isEmpty) {
      return 'Start of conversation';
    }

    // Get last N turns
    final recentTurns = conversationHistory.length > lookback
        ? conversationHistory.sublist(conversationHistory.length - lookback)
        : conversationHistory;

    // Scrub and summarize each
    final summaries = <String>[];
    for (final turn in recentTurns) {
      // Scrub PII from both user and LUMARA turns
      final scrubbedUser = _prismAdapter.scrub(turn.userText).scrubbedText;
      final scrubbedLumara = _prismAdapter.scrub(turn.lumaraText).scrubbedText;

      // Extract key topic/action
      final userTopic = _extractTopic(scrubbedUser);
      final lumaraResponseType = _classifyResponse(scrubbedLumara);

      summaries.add('$userTopic → $lumaraResponseType');
    }

    return summaries.join(' | ');
  }

  /// Extract the main topic/subject from scrubbed text
  String _extractTopic(String scrubbedText) {
    // Simple extraction: take first meaningful words
    final words = scrubbedText.split(' ').take(5).join(' ');
    return words.isNotEmpty ? words : 'discussing topic';
  }

  /// Classify what type of response LUMARA gave
  String _classifyResponse(String lumaraText) {
    final lower = lumaraText.toLowerCase();

    if (lower.contains('it sounds like') || lower.contains('it seems')) {
      return 'reflected query';
    } else if (lower.contains("that's") && (lower.contains('hard') || lower.contains('difficult'))) {
      return 'validated difficulty';
    } else if (['try', 'approach', 'method', 'technique'].any((w) => lower.contains(w))) {
      return 'provided suggestions';
    } else if (lumaraText.contains('?')) {
      return 'asked question';
    } else {
      return 'made observation';
    }
  }

  /// Infer what type of response would be most helpful
  ExpectedResponseType _inferExpectedResponse({
    required QueryType queryType,
    required String phase,
    required double intensity,
  }) {
    // Frustration = immediate substance
    if (queryType == QueryType.frustratedWithReflection) {
      return ExpectedResponseType.directAnswerNoMoreReflection;
    }

    // Challenge requested = give it
    if (queryType == QueryType.requestForChallenge) {
      return ExpectedResponseType.challengeWithAccountability;
    }

    final phaseLower = phase.toLowerCase();

    // Recovery + high intensity combinations
    if (phaseLower == 'recovery' && intensity > 0.7) {
      if (queryType == QueryType.requestForSuggestions) {
        return ExpectedResponseType.gentleOptionsWithPermission;
      } else {
        return ExpectedResponseType.validationAndGentleAcknowledgment;
      }
    }

    // Expansion + suggestion request
    if (phaseLower == 'expansion' && queryType == QueryType.requestForSuggestions) {
      if (intensity > 0.7) {
        return ExpectedResponseType.strategicDirectionWithPrioritization;
      } else {
        return ExpectedResponseType.practicalSuggestionsWithOptions;
      }
    }

    // Breakthrough + high intensity
    if (phaseLower == 'breakthrough' && intensity > 0.7) {
      return ExpectedResponseType.challengeWithAccountability;
    }

    // Discovery + suggestion request
    if (phaseLower == 'discovery' && queryType == QueryType.requestForSuggestions) {
      return ExpectedResponseType.encouragingWithConcreteNextSteps;
    }

    // Transition + question
    if (phaseLower == 'transition') {
      return ExpectedResponseType.groundingWithoutSolving;
    }

    // Consolidation + input request
    if (phaseLower == 'consolidation' && queryType == QueryType.requestForInput) {
      return ExpectedResponseType.analyticalSynthesis;
    }

    // Validation requests
    if (queryType == QueryType.requestForValidation) {
      return ExpectedResponseType.honestValidationWithoutPandering;
    }

    // Default by query type
    if (queryType == QueryType.requestForSuggestions) {
      return ExpectedResponseType.substantiveAnswerWithConcreteSuggestions;
    } else if (queryType == QueryType.requestForInput) {
      return ExpectedResponseType.directPerspective;
    } else if (queryType == QueryType.question) {
      return ExpectedResponseType.directAnswer;
    } else if (queryType == QueryType.thinkingAloud) {
      return ExpectedResponseType.briefAcknowledgment;
    } else {
      return ExpectedResponseType.observationOrQuestion;
    }
  }
}
