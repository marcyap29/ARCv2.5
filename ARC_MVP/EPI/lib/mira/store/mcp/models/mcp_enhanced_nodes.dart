/// MCP Enhanced Node Types
/// 
/// This file contains specialized node types for Chat, Draft, and LUMARA enhancements
/// as defined in the MCP whitepaper specification.
library;

import 'mcp_schemas.dart';

/// Chat Session Node - Metadata for an entire conversational thread
class ChatSessionNode extends McpNode {
  final String title;
  final bool isArchived;
  final DateTime? archivedAt;
  final bool isPinned;
  final List<String> tags;
  final int messageCount;
  final String retention;

  const ChatSessionNode({
    required super.id,
    required super.timestamp,
    required this.title,
    this.isArchived = false,
    this.archivedAt,
    this.isPinned = false,
    this.tags = const [],
    this.messageCount = 0,
    this.retention = 'auto-archive-30d',
    super.schemaVersion,
    McpProvenance? provenance,
    super.metadata,
  }) : super(
          type: 'ChatSession',
          provenance: provenance ?? const McpProvenance(source: 'LUMARA', device: 'unknown'),
        );

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['content'] = {
      'title': title,
    };
    json['metadata'] = {
      ...?metadata,
      'isArchived': isArchived,
      if (archivedAt != null) 'archivedAt': archivedAt!.toUtc().toIso8601String(),
      'isPinned': isPinned,
      'tags': tags,
      'messageCount': messageCount,
      'retention': retention,
    };
    return json;
  }

  factory ChatSessionNode.fromJson(Map<String, dynamic> json) {
    final content = json['content'] as Map<String, dynamic>? ?? {};
    final metadata = json['metadata'] as Map<String, dynamic>? ?? {};
    
    return ChatSessionNode(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      title: content['title'] as String? ?? '',
      isArchived: metadata['isArchived'] as bool? ?? false,
      archivedAt: metadata['archivedAt'] != null 
          ? DateTime.parse(metadata['archivedAt'] as String)
          : null,
      isPinned: metadata['isPinned'] as bool? ?? false,
      tags: List<String>.from(metadata['tags'] ?? []),
      messageCount: metadata['messageCount'] as int? ?? 0,
      retention: metadata['retention'] as String? ?? 'auto-archive-30d',
      schemaVersion: json['schema_version'] as String? ?? 'node.v1',
      provenance: json['provenance'] != null 
          ? McpProvenance.fromJson(json['provenance'] as Map<String, dynamic>)
          : null,
      metadata: metadata,
    );
  }
}

/// Chat Message Node - A single utterance within a session
class ChatMessageNode extends McpNode {
  final String role; // 'user', 'assistant', 'system'
  final String text;
  final String mimeType;
  final int order;

  const ChatMessageNode({
    required super.id,
    required super.timestamp,
    required this.role,
    required this.text,
    this.mimeType = 'text/plain',
    this.order = 0,
    super.schemaVersion,
    McpProvenance? provenance,
    super.metadata,
  }) : super(
          type: 'ChatMessage',
          provenance: provenance ?? const McpProvenance(source: 'LUMARA', device: 'unknown'),
        );

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['content'] = {
      'mime': mimeType,
      'text': text,
    };
    json['metadata'] = {
      ...?metadata,
      'role': role,
      'order': order,
    };
    return json;
  }

  factory ChatMessageNode.fromJson(Map<String, dynamic> json) {
    final content = json['content'] as Map<String, dynamic>? ?? {};
    final metadata = json['metadata'] as Map<String, dynamic>? ?? {};
    
    return ChatMessageNode(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      role: metadata['role'] as String? ?? 'user',
      text: content['text'] as String? ?? '',
      mimeType: content['mime'] as String? ?? 'text/plain',
      order: metadata['order'] as int? ?? 0,
      schemaVersion: json['schema_version'] as String? ?? 'node.v1',
      provenance: json['provenance'] != null 
          ? McpProvenance.fromJson(json['provenance'] as Map<String, dynamic>)
          : null,
      metadata: metadata,
    );
  }
}

/// Draft Entry Node - Unpublished journal entries
class DraftEntryNode extends McpNode {
  final String content;
  final String? title;
  final bool isAutoSaved;
  final DateTime? lastModified;
  final int wordCount;
  final List<String> tags;
  @override
  final String? phaseHint;
  @override
  final Map<String, double> emotions;

  const DraftEntryNode({
    required super.id,
    required super.timestamp,
    required this.content,
    this.title,
    this.isAutoSaved = false,
    this.lastModified,
    this.wordCount = 0,
    this.tags = const [],
    this.phaseHint,
    this.emotions = const {},
    super.schemaVersion,
    McpProvenance? provenance,
    super.metadata,
  }) : super(
          type: 'DraftEntry',
          provenance: provenance ?? const McpProvenance(source: 'ARC', device: 'unknown'),
        );

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['content'] = {
      'text': content,
      if (title != null) 'title': title,
    };
    json['metadata'] = {
      ...?metadata,
      'isAutoSaved': isAutoSaved,
      if (lastModified != null) 'lastModified': lastModified!.toUtc().toIso8601String(),
      'wordCount': wordCount,
      'tags': tags,
      if (phaseHint != null) 'phaseHint': phaseHint,
      'emotions': emotions,
    };
    return json;
  }

  factory DraftEntryNode.fromJson(Map<String, dynamic> json) {
    final content = json['content'] as Map<String, dynamic>? ?? {};
    final metadata = json['metadata'] as Map<String, dynamic>? ?? {};
    
    return DraftEntryNode(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      content: content['text'] as String? ?? '',
      title: content['title'] as String?,
      isAutoSaved: metadata['isAutoSaved'] as bool? ?? false,
      lastModified: metadata['lastModified'] != null 
          ? DateTime.parse(metadata['lastModified'] as String)
          : null,
      wordCount: metadata['wordCount'] as int? ?? 0,
      tags: List<String>.from(metadata['tags'] ?? []),
      phaseHint: metadata['phaseHint'] as String?,
      emotions: Map<String, double>.from(metadata['emotions'] ?? {}),
      schemaVersion: json['schema_version'] as String? ?? 'node.v1',
      provenance: json['provenance'] != null 
          ? McpProvenance.fromJson(json['provenance'] as Map<String, dynamic>)
          : null,
      metadata: metadata,
    );
  }
}

/// LUMARA Enhanced Journal Entry - Includes rosebud and other LUMARA enhancements
class LumaraEnhancedJournalNode extends McpNode {
  final String content;
  final String? rosebud; // LUMARA's rosebud insight
  final List<String> lumaraInsights;
  final Map<String, dynamic> lumaraMetadata;
  final String? phasePrediction;
  final Map<String, double> emotionalAnalysis;
  final List<String> suggestedKeywords;
  final String? lumaraContext;

  const LumaraEnhancedJournalNode({
    required super.id,
    required super.timestamp,
    required this.content,
    this.rosebud,
    this.lumaraInsights = const [],
    this.lumaraMetadata = const {},
    this.phasePrediction,
    this.emotionalAnalysis = const {},
    this.suggestedKeywords = const [],
    this.lumaraContext,
    super.schemaVersion,
    McpProvenance? provenance,
    super.metadata,
  }) : super(
          type: 'LumaraEnhancedJournal',
          provenance: provenance ?? const McpProvenance(source: 'LUMARA', device: 'unknown'),
        );

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['content'] = {
      'text': content,
      if (rosebud != null) 'rosebud': rosebud,
    };
    json['metadata'] = {
      ...?metadata,
      'lumaraInsights': lumaraInsights,
      'lumaraMetadata': lumaraMetadata,
      if (phasePrediction != null) 'phasePrediction': phasePrediction,
      'emotionalAnalysis': emotionalAnalysis,
      'suggestedKeywords': suggestedKeywords,
      if (lumaraContext != null) 'lumaraContext': lumaraContext,
    };
    return json;
  }

  factory LumaraEnhancedJournalNode.fromJson(Map<String, dynamic> json) {
    final content = json['content'] as Map<String, dynamic>? ?? {};
    final metadata = json['metadata'] as Map<String, dynamic>? ?? {};
    
    return LumaraEnhancedJournalNode(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      content: content['text'] as String? ?? '',
      rosebud: content['rosebud'] as String?,
      lumaraInsights: List<String>.from(metadata['lumaraInsights'] ?? []),
      lumaraMetadata: Map<String, dynamic>.from(metadata['lumaraMetadata'] ?? {}),
      phasePrediction: metadata['phasePrediction'] as String?,
      emotionalAnalysis: Map<String, double>.from(metadata['emotionalAnalysis'] ?? {}),
      suggestedKeywords: List<String>.from(metadata['suggestedKeywords'] ?? []),
      lumaraContext: metadata['lumaraContext'] as String?,
      schemaVersion: json['schema_version'] as String? ?? 'node.v1',
      provenance: json['provenance'] != null 
          ? McpProvenance.fromJson(json['provenance'] as Map<String, dynamic>)
          : null,
      metadata: metadata,
    );
  }
}

/// Enhanced Edge for Chat relationships
class ChatEdge extends McpEdge {
  final int? order;
  final String? relationType;

  const ChatEdge({
    required super.source,
    required super.target,
    required super.relation,
    required super.timestamp,
    this.order,
    this.relationType,
    super.schemaVersion,
    super.metadata,
  });

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['metadata'] = {
      ...?metadata,
      if (order != null) 'order': order,
      if (relationType != null) 'relationType': relationType,
    };
    return json;
  }

  factory ChatEdge.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] as Map<String, dynamic>? ?? {};
    
    return ChatEdge(
      source: json['source'] as String,
      target: json['target'] as String,
      relation: json['relation'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      order: metadata['order'] as int?,
      relationType: metadata['relationType'] as String?,
      schemaVersion: json['schema_version'] as String? ?? 'edge.v1',
      metadata: metadata,
    );
  }
}

/// ULID Generator for MCP IDs
class McpIdGenerator {
  static String generateChatSessionId() => 'session:${_generateUlid()}';
  static String generateChatMessageId() => 'msg:${_generateUlid()}';
  static String generateDraftId() => 'draft:${_generateUlid()}';
  static String generateLumaraId() => 'lumara:${_generateUlid()}';
  static String generatePointerId() => 'ptr:${_generateUlid()}';
  static String generateEmbeddingId() => 'emb:${_generateUlid()}';
  static String generateEdgeId() => 'edge:${_generateUlid()}';

  static String _generateUlid() {
    // Simple ULID implementation - in production, use a proper ULID library
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp * 1000 + (timestamp % 1000)).toString();
    return '${timestamp.toRadixString(36)}${random.substring(0, 10)}';
  }
}
