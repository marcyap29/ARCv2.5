// l../mira/memory/conversation_context_service.dart
// Service for tracking and attributing current conversation context

import 'enhanced_attribution_schema.dart';
import '../../arc/chat/data/models/lumara_message.dart';

/// Service for managing current conversation context and attribution
class ConversationContextService {

  /// Generate enhanced attributions for current conversation context
  static List<EnhancedAttributionTrace> generateCurrentConversationAttributions({
    required String currentResponseId,
    required List<LumaraMessage> currentSessionMessages,
    required String currentUserMessage,
    int lookbackLimit = 10,
  }) {
    final traces = <EnhancedAttributionTrace>[];
    final now = DateTime.now();

    // Filter to recent messages in current session (exclude the current response being generated)
    final recentMessages = currentSessionMessages
        .where((msg) => msg.id != currentResponseId)
        .toList()
        .reversed // Most recent first
        .take(lookbackLimit)
        .toList();

    for (int i = 0; i < recentMessages.length; i++) {
      final message = recentMessages[i];
      final recencyIndex = i; // 0 = most recent, higher = older

      // Generate attribution based on message type and recency
      final trace = _createConversationTrace(
        message: message,
        currentUserMessage: currentUserMessage,
        recencyIndex: recencyIndex,
        currentResponseId: currentResponseId,
      );

      if (trace != null) {
        traces.add(trace);
      }
    }

    return traces;
  }

  /// Create attribution trace for a conversation message
  static EnhancedAttributionTrace? _createConversationTrace({
    required LumaraMessage message,
    required String currentUserMessage,
    required int recencyIndex,
    required String currentResponseId,
  }) {
    final isLumara = message.role == LumaraMessageRole.assistant;
    final minutesSince = DateTime.now().difference(message.timestamp).inMinutes;

    // Calculate relevance confidence
    final confidence = _calculateConversationConfidence(
      message: message,
      currentUserMessage: currentUserMessage,
      recencyIndex: recencyIndex,
      minutesSince: minutesSince,
    );

    // Skip if confidence is too low
    if (confidence < 0.3) return null;

    // Determine relation type
    final relation = _determineConversationRelation(message, currentUserMessage, isLumara);

    // Generate reasoning
    final reasoning = _generateConversationReasoning(
      message: message,
      isLumara: isLumara,
      minutesSince: minutesSince,
      relation: relation,
    );

    // Extract relevant excerpt
    final excerpt = _extractConversationExcerpt(message, currentUserMessage);

    return EnhancedAttributionTrace(
      nodeRef: message.id,
      sourceType: isLumara ? SourceType.lumaraResponse : SourceType.chatMessage,
      relation: relation,
      confidence: confidence,
      timestamp: DateTime.now(),
      reasoning: reasoning,
      excerpt: excerpt,
      responseSectionId: null,
      contributionWeight: _calculateContributionWeight(confidence, recencyIndex),
      sourceMetadata: {
        'session_id': message.metadata['sessionId']?.toString() ?? 'current',
        'role': message.role.name,
        'timestamp': message.timestamp.toIso8601String(),
        'minutes_ago': minutesSince,
        'position_in_conversation': recencyIndex,
        'message_length': message.content.length,
        'is_current_session': true,
        'conversation_context': 'current',
      },
      crossReferences: _findConversationCrossReferences(message, currentUserMessage),
    );
  }

  /// Calculate confidence for conversation message relevance
  static double _calculateConversationConfidence({
    required LumaraMessage message,
    required String currentUserMessage,
    required int recencyIndex,
    required int minutesSince,
  }) {
    double confidence = 0.4; // Base confidence for conversation context

    // Recency boost (more recent = higher confidence)
    if (recencyIndex == 0) confidence += 0.4; // Most recent message
    else if (recencyIndex == 1) confidence += 0.3; // Second most recent
    else if (recencyIndex <= 3) confidence += 0.2; // Within last 3 messages
    else if (recencyIndex <= 5) confidence += 0.1; // Within last 5 messages

    // Time-based adjustment
    if (minutesSince <= 5) confidence += 0.2; // Very recent (last 5 minutes)
    else if (minutesSince <= 30) confidence += 0.1; // Recent (last 30 minutes)
    else if (minutesSince > 120) confidence -= 0.1; // Older than 2 hours

    // Content relevance (simple keyword matching)
    final currentWords = currentUserMessage.toLowerCase().split(' ');
    final messageWords = message.content.toLowerCase().split(' ');
    final commonWords = currentWords
        .where((word) => messageWords.contains(word) && word.length > 3)
        .length;

    if (commonWords > 3) confidence += 0.2;
    else if (commonWords > 1) confidence += 0.1;

    // Message type adjustment
    if (message.role == LumaraMessageRole.assistant) {
      confidence += 0.1; // LUMARA's previous responses are valuable context
    }

    // Length consideration (more substantive messages are more likely relevant)
    if (message.content.length > 100) confidence += 0.1;

    return confidence.clamp(0.0, 1.0);
  }

  /// Determine relation type for conversation message
  static String _determineConversationRelation(
    LumaraMessage message,
    String currentUserMessage,
    bool isLumara,
  ) {
    if (isLumara) {
      // Previous LUMARA responses
      return 'builds_on'; // Current response builds on previous responses
    } else {
      // User messages
      final currentLower = currentUserMessage.toLowerCase();
      final messageLower = message.content.toLowerCase();

      // Look for question patterns
      if (messageLower.contains('?') || currentLower.contains('?')) {
        return 'contextualizes'; // Previous questions provide context
      }

      // Look for continuation patterns
      final continuationWords = ['also', 'additionally', 'furthermore', 'similarly', 'moreover'];
      if (continuationWords.any((word) => currentLower.contains(word))) {
        return 'supports'; // Current message builds on previous
      }

      // Look for clarification patterns
      final clarificationWords = ['clarify', 'explain', 'elaborate', 'expand', 'tell me more'];
      if (clarificationWords.any((word) => currentLower.contains(word))) {
        return 'references'; // Current message references previous content
      }

      return 'references'; // Default for user messages
    }
  }

  /// Generate reasoning for conversation attribution
  static String _generateConversationReasoning({
    required LumaraMessage message,
    required bool isLumara,
    required int minutesSince,
    required String relation,
  }) {
    final timeDesc = _getTimeDescription(minutesSince);

    if (isLumara) {
      switch (relation) {
        case 'builds_on':
          return 'My previous response from $timeDesc provides foundation and context for this response';
        case 'references':
          return 'My earlier response from $timeDesc contains relevant information';
        default:
          return 'Previous response from $timeDesc offers relevant context';
      }
    } else {
      switch (relation) {
        case 'contextualizes':
          return 'Your question from $timeDesc provides important context for understanding your current inquiry';
        case 'supports':
          return 'Your previous message from $timeDesc supports and builds toward your current question';
        case 'references':
          return 'Your message from $timeDesc contains relevant background information';
        default:
          return 'Your previous message from $timeDesc provides conversational context';
      }
    }
  }

  /// Extract relevant excerpt from conversation message
  static String? _extractConversationExcerpt(LumaraMessage message, String currentUserMessage) {
    final content = message.content;

    // For shorter messages, return the full content
    if (content.length <= 150) return content;

    // For longer messages, try to find the most relevant part
    final currentWords = currentUserMessage.toLowerCase().split(' ');
    final sentences = content.split(RegExp(r'[.!?]\s+'));

    // Find sentence with most keyword overlap
    String bestSentence = sentences.first;
    int maxOverlap = 0;

    for (final sentence in sentences) {
      if (sentence.trim().isEmpty) continue;

      final sentenceWords = sentence.toLowerCase().split(' ');
      final overlap = currentWords
          .where((word) => sentenceWords.contains(word) && word.length > 3)
          .length;

      if (overlap > maxOverlap) {
        maxOverlap = overlap;
        bestSentence = sentence;
      }
    }

    // Return best sentence or truncated content
    if (bestSentence.length <= 200) {
      return bestSentence.trim() + '.';
    } else {
      return content.substring(0, 197).trim() + '...';
    }
  }

  /// Calculate contribution weight based on confidence and recency
  static double _calculateContributionWeight(double confidence, int recencyIndex) {
    double weight = confidence;

    // Recency adjustment
    if (recencyIndex == 0) weight *= 1.0; // Most recent gets full weight
    else if (recencyIndex <= 2) weight *= 0.8; // Recent messages get high weight
    else if (recencyIndex <= 5) weight *= 0.6; // Older messages get medium weight
    else weight *= 0.4; // Much older messages get low weight

    return weight.clamp(0.0, 1.0);
  }

  /// Find cross-references within current conversation
  static List<CrossReference> _findConversationCrossReferences(
    LumaraMessage message,
    String currentUserMessage,
  ) {
    final crossRefs = <CrossReference>[];

    // Simple implementation - could be enhanced with more sophisticated analysis
    if (message.role == LumaraMessageRole.assistant) {
      // If this is a LUMARA response, it might reference user inputs
      crossRefs.add(CrossReference(
        targetId: 'current_user_input',
        targetType: SourceType.chatMessage,
        relation: 'responds_to',
        strength: 0.8,
        description: 'Responds to current user message',
        timestamp: DateTime.now(),
      ));
    }

    return crossRefs;
  }

  /// Helper method to get human-readable time description
  static String _getTimeDescription(int minutesSince) {
    if (minutesSince < 1) return 'just now';
    if (minutesSince < 5) return 'a few minutes ago';
    if (minutesSince < 15) return '${minutesSince} minutes ago';
    if (minutesSince < 60) return '${(minutesSince / 15).round() * 15} minutes ago';
    if (minutesSince < 120) return 'about an hour ago';
    return '${(minutesSince / 60).round()} hours ago';
  }

  /// Generate conversation context summary
  static String generateConversationContextSummary(List<EnhancedAttributionTrace> conversationTraces) {
    if (conversationTraces.isEmpty) {
      return 'This response is based on your current message without reference to previous conversation.';
    }

    final lumaraResponses = conversationTraces
        .where((t) => t.sourceType == SourceType.lumaraResponse)
        .length;
    final userMessages = conversationTraces
        .where((t) => t.sourceType == SourceType.chatMessage)
        .length;

    final contextParts = <String>[];

    if (lumaraResponses > 0) {
      contextParts.add('$lumaraResponses previous response${lumaraResponses == 1 ? '' : 's'} from our conversation');
    }

    if (userMessages > 0) {
      contextParts.add('$userMessages earlier message${userMessages == 1 ? '' : 's'} from you');
    }

    String summary = 'This response draws on ${contextParts.join(' and ')}.';

    // Add recency information
    final mostRecent = conversationTraces
        .where((t) => t.sourceMetadata['minutes_ago'] != null)
        .map((t) => t.sourceMetadata['minutes_ago'] as int)
        .fold<int?>(null, (min, value) => min == null || value < min ? value : min);

    if (mostRecent != null) {
      summary += ' The most recent reference is from ${_getTimeDescription(mostRecent)}.';
    }

    return summary;
  }

  /// Create attribution for immediate conversational context (last 1-2 exchanges)
  static List<EnhancedAttributionTrace> createImmediateContextAttributions({
    required String currentResponseId,
    required List<LumaraMessage> recentMessages,
    required String currentUserMessage,
  }) {
    // Focus on immediate context (last 2-3 messages)
    final immediateMessages = recentMessages.take(3).toList();

    return generateCurrentConversationAttributions(
      currentResponseId: currentResponseId,
      currentSessionMessages: immediateMessages,
      currentUserMessage: currentUserMessage,
      lookbackLimit: 3,
    ).where((trace) => trace.confidence >= 0.5).toList(); // Higher threshold for immediate context
  }

  /// Create attribution for broader conversational context
  static List<EnhancedAttributionTrace> createBroaderContextAttributions({
    required String currentResponseId,
    required List<LumaraMessage> allSessionMessages,
    required String currentUserMessage,
  }) {
    return generateCurrentConversationAttributions(
      currentResponseId: currentResponseId,
      currentSessionMessages: allSessionMessages,
      currentUserMessage: currentUserMessage,
      lookbackLimit: 15,
    ).where((trace) => trace.confidence >= 0.4).toList(); // Lower threshold for broader context
  }
}