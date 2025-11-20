/// MCP Node Factory Service
/// 
/// Factory for creating appropriate MCP node types based on content and context.
/// Handles Chat, Draft, LUMARA enhanced, and standard journal entries.
library;

import '../models/mcp_schemas.dart';
import '../models/mcp_enhanced_nodes.dart';
import 'package:my_app/arc/chat/chat/chat_models.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/core/services/draft_cache_service.dart';
import 'package:my_app/arc/chat/chat/content_parts.dart';

/// Factory for creating MCP nodes from various sources
class McpNodeFactory {
  /// Create a Chat Session node from LUMARA chat data
  static ChatSessionNode createChatSession({
    required String sessionId,
    required DateTime timestamp,
    required String title,
    bool isArchived = false,
    DateTime? archivedAt,
    bool isPinned = false,
    List<String> tags = const [],
    int messageCount = 0,
    String retention = 'auto-archive-30d',
    McpProvenance? provenance,
  }) {
    return ChatSessionNode(
      id: McpIdGenerator.generateChatSessionId(),
      timestamp: timestamp,
      title: title,
      isArchived: isArchived,
      archivedAt: archivedAt,
      isPinned: isPinned,
      tags: tags,
      messageCount: messageCount,
      retention: retention,
      provenance: provenance ?? const McpProvenance(source: 'LUMARA', device: 'unknown'),
    );
  }

  /// Create a Chat Message node from LUMARA message data
  static ChatMessageNode createChatMessage({
    required String messageId,
    required DateTime timestamp,
    required String role,
    required String text,
    String mimeType = 'text/plain',
    int order = 0,
    McpProvenance? provenance,
  }) {
    return ChatMessageNode(
      id: McpIdGenerator.generateChatMessageId(),
      timestamp: timestamp,
      role: role,
      text: text,
      mimeType: mimeType,
      order: order,
      provenance: provenance ?? const McpProvenance(source: 'LUMARA', device: 'unknown'),
    );
  }

  /// Create a Draft Entry node from draft cache data
  static DraftEntryNode createDraftEntry({
    required String draftId,
    required DateTime timestamp,
    required String content,
    String? title,
    bool isAutoSaved = false,
    DateTime? lastModified,
    List<String> tags = const [],
    String? phaseHint,
    Map<String, double> emotions = const {},
    McpProvenance? provenance,
  }) {
    final wordCount = content.split(RegExp(r'\s+')).length;
    
    return DraftEntryNode(
      id: McpIdGenerator.generateDraftId(),
      timestamp: timestamp,
      content: content,
      title: title,
      isAutoSaved: isAutoSaved,
      lastModified: lastModified,
      wordCount: wordCount,
      tags: tags,
      phaseHint: phaseHint,
      emotions: emotions,
      provenance: provenance ?? const McpProvenance(source: 'ARC', device: 'unknown'),
    );
  }

  /// Create a LUMARA Enhanced Journal node with rosebud and insights
  static LumaraEnhancedJournalNode createLumaraEnhancedJournal({
    required String journalId,
    required DateTime timestamp,
    required String content,
    String? rosebud,
    List<String> lumaraInsights = const [],
    Map<String, dynamic> lumaraMetadata = const {},
    String? phasePrediction,
    Map<String, double> emotionalAnalysis = const {},
    List<String> suggestedKeywords = const [],
    String? lumaraContext,
    McpProvenance? provenance,
  }) {
    return LumaraEnhancedJournalNode(
      id: McpIdGenerator.generateLumaraId(),
      timestamp: timestamp,
      content: content,
      rosebud: rosebud,
      lumaraInsights: lumaraInsights,
      lumaraMetadata: lumaraMetadata,
      phasePrediction: phasePrediction,
      emotionalAnalysis: emotionalAnalysis,
      suggestedKeywords: suggestedKeywords,
      lumaraContext: lumaraContext,
      provenance: provenance ?? const McpProvenance(source: 'LUMARA', device: 'unknown'),
    );
  }

  /// Create a standard journal entry node
  static McpNode createJournalEntry({
    required String journalId,
    required DateTime timestamp,
    required String content,
    String? contentSummary,
    String? phaseHint,
    List<String> keywords = const [],
    McpNarrative? narrative,
    Map<String, double> emotions = const {},
    String? pointerRef,
    String? embeddingRef,
    McpProvenance? provenance,
  }) {
    return McpNode(
      id: journalId,
      type: 'journal_entry',
      timestamp: timestamp,
      contentSummary: contentSummary,
      phaseHint: phaseHint,
      keywords: keywords,
      narrative: narrative,
      emotions: emotions,
      pointerRef: pointerRef,
      embeddingRef: embeddingRef,
      provenance: provenance ?? const McpProvenance(source: 'ARC', device: 'unknown'),
    );
  }

  /// Create a chat edge (contains relationship)
  static ChatEdge createChatEdge({
    required String sessionId,
    required String messageId,
    required DateTime timestamp,
    int? order,
    String? relationType,
  }) {
    return ChatEdge(
      source: sessionId,
      target: messageId,
      relation: 'contains',
      timestamp: timestamp,
      order: order,
      relationType: relationType,
    );
  }

  /// Create a standard edge
  static McpEdge createEdge({
    required String source,
    required String target,
    required String relation,
    required DateTime timestamp,
    double? weight,
    Map<String, dynamic>? metadata,
  }) {
    return McpEdge(
      source: source,
      target: target,
      relation: relation,
      timestamp: timestamp,
      weight: weight,
      metadata: metadata,
    );
  }

  /// Convert LUMARA ChatSession to MCP ChatSessionNode
  static ChatSessionNode fromLumaraChatSession(ChatSession session) {
    return createChatSession(
      sessionId: session.id,
      timestamp: session.createdAt,
      title: session.subject,
      isArchived: session.isArchived,
      archivedAt: session.archivedAt,
      isPinned: session.isPinned,
      tags: session.tags,
      messageCount: session.messageCount,
      retention: session.retention ?? 'auto-archive-30d',
    );
  }

  /// Convert LUMARA ChatMessage to MCP ChatMessageNode
  static ChatMessageNode fromLumaraChatMessage(ChatMessage message) {
    // Extract text content from content parts
    final textContent = (message.contentParts ?? [])
        .whereType<TextContentPart>()
        .map((part) => part.text)
        .join(' ');
    
    return createChatMessage(
      messageId: message.id,
      timestamp: message.createdAt,
      role: message.role,
      text: textContent,
      mimeType: 'text/plain',
      order: 0, // Will be set by the session
    );
  }

  /// Convert JournalEntry to MCP Node with SAGE analysis
  static McpNode fromJournalEntry(JournalEntry entry) {
    final narrative = McpNarrative.fromJournalContent(entry.content);
    
    // Convert emotion to emotions map
    final emotions = <String, double>{};
    if (entry.emotion != null) {
      emotions[entry.emotion!] = 0.8; // Default confidence
    }
    
    return createJournalEntry(
      journalId: entry.id,
      timestamp: entry.createdAt,
      content: entry.content,
      contentSummary: entry.title, // Use title as summary
      phaseHint: entry.phase,
      keywords: entry.keywords,
      narrative: narrative,
      emotions: emotions,
      provenance: McpProvenance(
        source: 'ARC',
        device: 'unknown',
      ),
    );
  }

  /// Convert JournalDraft to MCP DraftEntryNode
  static DraftEntryNode fromJournalDraft(JournalDraft draft) {
    return createDraftEntry(
      draftId: draft.id,
      timestamp: draft.createdAt,
      content: draft.content,
      title: null, // JournalDraft doesn't have title
      isAutoSaved: false, // Will be determined by context
      lastModified: draft.lastModified,
      tags: [], // JournalDraft doesn't have tags
      phaseHint: null, // JournalDraft doesn't have phase
      emotions: {}, // JournalDraft doesn't have emotions
    );
  }

  /// Create LUMARA enhanced journal with rosebud analysis
  static LumaraEnhancedJournalNode createLumaraJournalWithRosebud({
    required String journalId,
    required DateTime timestamp,
    required String content,
    required String rosebud,
    List<String> insights = const [],
    Map<String, dynamic> metadata = const {},
  }) {
    return createLumaraEnhancedJournal(
      journalId: journalId,
      timestamp: timestamp,
      content: content,
      rosebud: rosebud,
      lumaraInsights: insights,
      lumaraMetadata: metadata,
      phasePrediction: _extractPhaseFromContent(content),
      emotionalAnalysis: _analyzeEmotions(content),
      suggestedKeywords: _extractKeywords(content),
      lumaraContext: 'journal_enhancement',
    );
  }

  /// Extract phase from content (simple implementation)
  static String? _extractPhaseFromContent(String content) {
    final lowerContent = content.toLowerCase();
    if (lowerContent.contains('discovery') || lowerContent.contains('new')) return 'Discovery';
    if (lowerContent.contains('growth') || lowerContent.contains('learning')) return 'Expansion';
    if (lowerContent.contains('transition') || lowerContent.contains('change')) return 'Transition';
    if (lowerContent.contains('consolidation') || lowerContent.contains('stable')) return 'Consolidation';
    if (lowerContent.contains('recovery') || lowerContent.contains('healing')) return 'Recovery';
    if (lowerContent.contains('breakthrough') || lowerContent.contains('insight')) return 'Breakthrough';
    return null;
  }

  /// Analyze emotions from content (simple implementation)
  static Map<String, double> _analyzeEmotions(String content) {
    final emotions = <String, double>{};
    final lowerContent = content.toLowerCase();
    
    // Simple emotion detection
    if (lowerContent.contains('happy') || lowerContent.contains('joy')) emotions['joy'] = 0.8;
    if (lowerContent.contains('sad') || lowerContent.contains('grief')) emotions['sadness'] = 0.7;
    if (lowerContent.contains('angry') || lowerContent.contains('frustrated')) emotions['anger'] = 0.6;
    if (lowerContent.contains('anxious') || lowerContent.contains('worried')) emotions['anxiety'] = 0.7;
    if (lowerContent.contains('excited') || lowerContent.contains('thrilled')) emotions['excitement'] = 0.8;
    
    return emotions;
  }

  /// Extract keywords from content (simple implementation)
  static List<String> _extractKeywords(String content) {
    final words = content.toLowerCase().split(RegExp(r'\s+'));
    final keywords = <String>[];
    
    // Simple keyword extraction - in production, use proper NLP
    for (final word in words) {
      if (word.length > 3 && !_isStopWord(word)) {
        keywords.add(word);
      }
    }
    
    return keywords.take(10).toList();
  }

  /// Check if word is a stop word
  static bool _isStopWord(String word) {
    const stopWords = {
      'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by',
      'is', 'are', 'was', 'were', 'be', 'been', 'being', 'have', 'has', 'had', 'do', 'does', 'did',
      'will', 'would', 'could', 'should', 'may', 'might', 'can', 'this', 'that', 'these', 'those'
    };
    return stopWords.contains(word);
  }
}
