import 'dart:convert';
import '../models/reflective_entry_data.dart';
import 'package:my_app/prism/atlas/rivet/rivet_models.dart';
import '../../prism/extractors/sentinel_risk_detector.dart';
import '../../prism/extractors/enhanced_keyword_extractor.dart';
import 'package:my_app/arc/chat/chat/chat_models.dart';
import 'package:my_app/arc/chat/chat/content_parts.dart';

/// Service for analyzing LUMARA chat conversations through RIVET and SENTINEL
class ChatAnalysisService {
  static const double _chatConfidence = 0.8; // Medium confidence for chat

  /// Process a chat message through RIVET
  static RivetEvent? processChatMessageForRivet({
    required ChatMessage message,
    required String predPhase,
    required String refPhase,
    Map<String, double> tolerance = const {},
  }) {
    // Only process user messages for RIVET analysis
    if (message.role != MessageRole.user) return null;

    final keywords = _extractKeywordsFromMessage(message);
    if (keywords.isEmpty) return null;

    return RivetEvent.fromLumaraChat(
      date: message.createdAt,
      keywords: keywords.toSet(),
      predPhase: predPhase,
      refPhase: refPhase,
      tolerance: tolerance,
    );
  }

  /// Process a chat message through SENTINEL
  static ReflectiveEntryData? processChatMessageForSentinel({
    required ChatMessage message,
    required String phase,
    String? mood,
    Map<String, dynamic> metadata = const {},
  }) {
    // Process both user and assistant messages for SENTINEL
    final keywords = _extractKeywordsFromMessage(message);
    if (keywords.isEmpty) return null;

    final context = _generateChatContext(message);
    
    return ReflectiveEntryData.fromLumaraChat(
      timestamp: message.createdAt,
      keywords: keywords,
      phase: phase,
      mood: mood,
      context: context,
      confidence: _chatConfidence,
      metadata: {
        ...metadata,
        'message_id': message.id,
        'session_id': message.sessionId,
        'role': message.role.toString(),
        'content_length': _getMessageContentLength(message),
      },
    );
  }

  /// Extract keywords from a chat message
  static List<String> _extractKeywordsFromMessage(ChatMessage message) {
    final content = _getMessageContent(message);
    if (content.isEmpty) return [];

    // Extract keywords using enhanced keyword extractor
    final response = EnhancedKeywordExtractor.extractKeywords(
      entryText: content,
      currentPhase: 'Transition', // Default phase for chat
    );
    final keywords = response.chips;
    
    // Add chat-specific context keywords
    final contextKeywords = _generateContextKeywords(message);
    
    return [...keywords, ...contextKeywords];
  }

  /// Get the text content from a chat message
  static String _getMessageContent(ChatMessage message) {
    return (message.contentParts ?? [])
        .whereType<TextContentPart>()
        .map((part) => part.text)
        .join(' ')
        .trim();
  }

  /// Get the length of message content
  static int _getMessageContentLength(ChatMessage message) {
    return _getMessageContent(message).length;
  }

  /// Generate context keywords based on chat characteristics
  static List<String> _generateContextKeywords(ChatMessage message) {
    final keywords = <String>[];
    
    // Add role-based context
    if (message.role == MessageRole.user) {
      keywords.add('user_input');
    } else if (message.role == MessageRole.assistant) {
      keywords.add('lumara_response');
    }

    // Add session context if available
    if (message.sessionId.isNotEmpty) {
      keywords.add('session:${message.sessionId}');
    }

    // Add provenance context if available
    if (message.provenance != null && message.provenance!.isNotEmpty) {
      try {
        final provenanceMap = jsonDecode(message.provenance!) as Map<String, dynamic>?;
        if (provenanceMap != null) {
          final veilEdge = provenanceMap['veil_edge'] as Map<String, dynamic>?;
          if (veilEdge != null) {
            final phaseGroup = veilEdge['phase_group'];
            if (phaseGroup != null) {
              keywords.add('phase_group:$phaseGroup');
            }
          }
        }
      } catch (e) {
        // Provenance is not JSON, skip
      }
    }

    return keywords;
  }

  /// Generate chat context string
  static String _generateChatContext(ChatMessage message) {
    final role = message.role == MessageRole.user ? 'user' : 'lumara';
    return 'source:chat:role:$role';
  }

  /// Infer phase from chat conversation context
  static String inferPhaseFromChat({
    required List<ChatMessage> conversation,
    required String currentPhase,
    Map<String, dynamic> context = const {},
  }) {
    // Analyze conversation patterns to infer phase
    final userMessages = conversation.where((m) => m.role == MessageRole.user).toList();

    if (userMessages.isEmpty) return currentPhase;

    // Extract keywords from recent user messages
    final recentKeywords = userMessages
        .take(5) // Last 5 user messages
        .expand((m) => _extractKeywordsFromMessage(m))
        .toList();

    // Check for phase-indicative patterns
    final phaseKeywords = {
      'Discovery': ['explore', 'discover', 'new', 'curious', 'wonder'],
      'Expansion': ['grow', 'expand', 'develop', 'progress', 'advance'],
      'Transition': ['change', 'shift', 'transition', 'between', 'uncertain'],
      'Consolidation': ['stable', 'settle', 'consolidate', 'integrate', 'solid'],
      'Recovery': ['heal', 'recover', 'restore', 'rebuild', 'rest'],
      'Breakthrough': ['breakthrough', 'break', 'sudden', 'insight', 'realization'],
    };

    // Count phase-indicative keywords
    final phaseScores = <String, int>{};
    for (final phase in phaseKeywords.keys) {
      phaseScores[phase] = recentKeywords
          .where((kw) => phaseKeywords[phase]!.any((pk) => kw.toLowerCase().contains(pk)))
          .length;
    }

    // Find the phase with highest score
    final bestPhase = phaseScores.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    // Only change phase if there's strong evidence
    return phaseScores[bestPhase]! > 2 ? bestPhase : currentPhase;
  }

  /// Analyze a conversation for risk patterns
  static Future<SentinelAnalysis> analyzeConversationRisk({
    required List<ChatMessage> conversation,
    required TimeWindow timeWindow,
    String currentPhase = 'Transition',
    SentinelConfig config = SentinelConfig.defaultConfig,
  }) async {
    final reflectiveEntries = <ReflectiveEntryData>[];

    for (final message in conversation) {
      final entry = processChatMessageForSentinel(
        message: message,
        phase: currentPhase,
        mood: null, // Chat doesn't have explicit mood
      );

      if (entry != null) {
        reflectiveEntries.add(entry);
      }
    }

    return SentinelRiskDetector.analyzeRisk(
      entries: reflectiveEntries,
      timeWindow: timeWindow,
      config: config,
    );
  }

  /// Analyze multiple conversations for patterns
  static Future<SentinelAnalysis> analyzeMultipleConversations({
    required List<List<ChatMessage>> conversations,
    required TimeWindow timeWindow,
    String currentPhase = 'Transition',
    SentinelConfig config = SentinelConfig.defaultConfig,
  }) async {
    final allEntries = <ReflectiveEntryData>[];

    for (final conversation in conversations) {
      // Extract entries from the conversation
      for (final message in conversation) {
        final entry = processChatMessageForSentinel(
          message: message,
          phase: currentPhase,
        );

        if (entry != null) {
          allEntries.add(entry);
        }
      }
    }

    return SentinelRiskDetector.analyzeRisk(
      entries: allEntries,
      timeWindow: timeWindow,
      config: config,
    );
  }

  /// Get chat confidence score based on message characteristics
  static double calculateChatConfidence({
    required ChatMessage message,
    required List<ChatMessage> conversationContext,
  }) {
    double confidence = _chatConfidence;

    // Adjust based on message length
    final contentLength = _getMessageContentLength(message);
    if (contentLength < 10) {
      confidence *= 0.7; // Very short message
    } else if (contentLength > 500) {
      confidence *= 1.1; // Substantial message
    }

    // Adjust based on conversation context
    if (conversationContext.length > 10) {
      confidence *= 1.05; // Rich conversation context
    }

    // Adjust based on role
    if (message.role == MessageRole.user) {
      confidence *= 1.1; // User messages are more reliable
    } else if (message.role == MessageRole.assistant) {
      confidence *= 0.9; // Assistant messages are less reliable for user analysis
    }

    return confidence.clamp(0.1, 1.0);
  }
}
