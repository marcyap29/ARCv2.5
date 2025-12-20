// lib/lumara/memory/mcp_memory_models.dart
// MCP (Memory Container Protocol) data models for LUMARA conversational memory

import 'dart:convert';
import 'package:crypto/crypto.dart';

/// MCP Bundle - contains all conversation data for a session
class McpBundle {
  final String mcpVersion;
  final String owner;
  final String bundleId;
  final DateTime createdAt;
  final List<McpRecord> records;
  final List<McpEmbedding> embeddings;

  McpBundle({
    this.mcpVersion = '1.0',
    required this.owner,
    required this.bundleId,
    required this.createdAt,
    this.records = const [],
    this.embeddings = const [],
  });

  Map<String, dynamic> toJson() => {
    'mcp_version': mcpVersion,
    'owner': owner,
    'bundle_id': bundleId,
    'created_at': createdAt.toIso8601String(),
    'records': records.map((r) => r.toJson()).toList(),
    'embeddings': embeddings.map((e) => e.toJson()).toList(),
  };

  factory McpBundle.fromJson(Map<String, dynamic> json) => McpBundle(
    mcpVersion: json['mcp_version'] ?? '1.0',
    owner: json['owner'],
    bundleId: json['bundle_id'],
    createdAt: DateTime.parse(json['created_at']),
    records: (json['records'] as List<dynamic>)
        .map((r) => McpRecord.fromJson(r))
        .toList(),
    embeddings: (json['embeddings'] as List<dynamic>)
        .map((e) => McpEmbedding.fromJson(e))
        .toList(),
  );

  /// Add a record to the bundle
  McpBundle addRecord(McpRecord record) => McpBundle(
    mcpVersion: mcpVersion,
    owner: owner,
    bundleId: bundleId,
    createdAt: createdAt,
    records: [...records, record],
    embeddings: embeddings,
  );
}

/// Base class for MCP records
abstract class McpRecord {
  final String type;
  final String id;
  final DateTime timestamp;

  McpRecord({
    required this.type,
    required this.id,
    required this.timestamp,
  });

  Map<String, dynamic> toJson();

  factory McpRecord.fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'conversation.session':
        return ConversationSession.fromJson(json);
      case 'conversation.message':
        return ConversationMessage.fromJson(json);
      case 'conversation.summary':
        return ConversationSummary.fromJson(json);
      case 'privacy.redaction':
        return PrivacyRedaction.fromJson(json);
      default:
        throw Exception('Unknown MCP record type: ${json['type']}');
    }
  }
}

/// Conversation session metadata
class ConversationSession extends McpRecord {
  final String title;
  final List<String> tags;
  final Map<String, dynamic> meta;

  ConversationSession({
    required String id,
    required DateTime timestamp,
    required this.title,
    this.tags = const [],
    this.meta = const {},
  }) : super(type: 'conversation.session', id: id, timestamp: timestamp);

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'ts': timestamp.toIso8601String(),
    'title': title,
    'tags': tags,
    'meta': meta,
  };

  factory ConversationSession.fromJson(Map<String, dynamic> json) =>
      ConversationSession(
        id: json['id'],
        timestamp: DateTime.parse(json['ts']),
        title: json['title'],
        tags: List<String>.from(json['tags'] ?? []),
        meta: Map<String, dynamic>.from(json['meta'] ?? {}),
      );
}

/// Individual conversation message
class ConversationMessage extends McpRecord {
  final String role; // user, assistant, system
  final String content; // post-redaction
  final String originalHash; // sha256 of original content
  final String? redactionRef; // reference to redaction record
  final String parent; // session ID

  ConversationMessage({
    required String id,
    required DateTime timestamp,
    required this.role,
    required this.content,
    required this.originalHash,
    this.redactionRef,
    required this.parent,
  }) : super(type: 'conversation.message', id: id, timestamp: timestamp);

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'ts': timestamp.toIso8601String(),
    'role': role,
    'content': content,
    'orig_hash': originalHash,
    'redaction_ref': redactionRef,
    'parent': parent,
  };

  factory ConversationMessage.fromJson(Map<String, dynamic> json) =>
      ConversationMessage(
        id: json['id'],
        timestamp: DateTime.parse(json['ts']),
        role: json['role'],
        content: json['content'],
        originalHash: json['orig_hash'],
        redactionRef: json['redaction_ref'],
        parent: json['parent'],
      );

  /// Create hash for content
  static String createHash(String content) {
    return sha256.convert(utf8.encode(content)).toString();
  }
}

/// Rolling conversation summary
class ConversationSummary extends McpRecord {
  final String method; // e.g., "map-reduce-v3"
  final SummaryWindow window;
  final String content; // abstractive summary
  final List<String> keyFacts;
  final List<String> openLoops;
  final Map<String, String> phaseSignals;
  final String parent; // session ID

  ConversationSummary({
    required String id,
    required DateTime timestamp,
    this.method = 'map-reduce-v3',
    required this.window,
    required this.content,
    this.keyFacts = const [],
    this.openLoops = const [],
    this.phaseSignals = const {},
    required this.parent,
  }) : super(type: 'conversation.summary', id: id, timestamp: timestamp);

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'ts': timestamp.toIso8601String(),
    'method': method,
    'window': window.toJson(),
    'content': content,
    'key_facts': keyFacts,
    'open_loops': openLoops,
    'phase_signals': phaseSignals,
    'parent': parent,
  };

  factory ConversationSummary.fromJson(Map<String, dynamic> json) =>
      ConversationSummary(
        id: json['id'],
        timestamp: DateTime.parse(json['ts']),
        method: json['method'] ?? 'map-reduce-v3',
        window: SummaryWindow.fromJson(json['window']),
        content: json['content'],
        keyFacts: List<String>.from(json['key_facts'] ?? []),
        openLoops: List<String>.from(json['open_loops'] ?? []),
        phaseSignals: Map<String, String>.from(json['phase_signals'] ?? {}),
        parent: json['parent'],
      );
}

/// Summary window definition
class SummaryWindow {
  final String startMessageId;
  final String endMessageId;

  SummaryWindow({
    required this.startMessageId,
    required this.endMessageId,
  });

  Map<String, dynamic> toJson() => {
    'start_msg_id': startMessageId,
    'end_msg_id': endMessageId,
  };

  factory SummaryWindow.fromJson(Map<String, dynamic> json) => SummaryWindow(
    startMessageId: json['start_msg_id'],
    endMessageId: json['end_msg_id'],
  );
}

/// Privacy redaction record
class PrivacyRedaction extends McpRecord {
  final String policy; // e.g., "pii.v2"
  final String original; // encrypted at rest
  final String replacement; // e.g., "[EMAIL_REDACTED]"
  final RedactionScope scope;

  PrivacyRedaction({
    required String id,
    required DateTime timestamp,
    this.policy = 'pii.v2',
    required this.original,
    required this.replacement,
    required this.scope,
  }) : super(type: 'privacy.redaction', id: id, timestamp: timestamp);

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'ts': timestamp.toIso8601String(),
    'policy': policy,
    'original': original,
    'replacement': replacement,
    'scope': scope.toJson(),
  };

  factory PrivacyRedaction.fromJson(Map<String, dynamic> json) =>
      PrivacyRedaction(
        id: json['id'],
        timestamp: DateTime.parse(json['ts']),
        policy: json['policy'] ?? 'pii.v2',
        original: json['original'],
        replacement: json['replacement'],
        scope: RedactionScope.fromJson(json['scope']),
      );
}

/// Redaction scope definition
class RedactionScope {
  final String messageId;
  final String field;

  RedactionScope({
    required this.messageId,
    required this.field,
  });

  Map<String, dynamic> toJson() => {
    'msg_id': messageId,
    'field': field,
  };

  factory RedactionScope.fromJson(Map<String, dynamic> json) => RedactionScope(
    messageId: json['msg_id'],
    field: json['field'],
  );
}

/// MCP Embedding record
class McpEmbedding {
  final String id;
  final String ref; // reference to record
  final String model;
  final List<double>? vector; // optional vector data

  McpEmbedding({
    required this.id,
    required this.ref,
    required this.model,
    this.vector,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'ref': ref,
    'model': model,
    'vec': vector,
  };

  factory McpEmbedding.fromJson(Map<String, dynamic> json) => McpEmbedding(
    id: json['id'],
    ref: json['ref'],
    model: json['model'],
    vector: json['vec'] != null ? List<double>.from(json['vec']) : null,
  );
}

/// Global memory index
class MemoryIndex {
  final String mcpVersion;
  final String owner;
  final DateTime updatedAt;
  final List<TopicEntry> topics;
  final List<EntityEntry> entities;
  final List<OpenLoopEntry> openLoops;

  MemoryIndex({
    this.mcpVersion = '1.0',
    required this.owner,
    required this.updatedAt,
    this.topics = const [],
    this.entities = const [],
    this.openLoops = const [],
  });

  Map<String, dynamic> toJson() => {
    'mcp_version': mcpVersion,
    'owner': owner,
    'updated_at': updatedAt.toIso8601String(),
    'topics': topics.map((t) => t.toJson()).toList(),
    'entities': entities.map((e) => e.toJson()).toList(),
    'open_loops': openLoops.map((o) => o.toJson()).toList(),
  };

  factory MemoryIndex.fromJson(Map<String, dynamic> json) => MemoryIndex(
    mcpVersion: json['mcp_version'] ?? '1.0',
    owner: json['owner'],
    updatedAt: DateTime.parse(json['updated_at']),
    topics: (json['topics'] as List<dynamic>)
        .map((t) => TopicEntry.fromJson(t))
        .toList(),
    entities: (json['entities'] as List<dynamic>)
        .map((e) => EntityEntry.fromJson(e))
        .toList(),
    openLoops: (json['open_loops'] as List<dynamic>)
        .map((o) => OpenLoopEntry.fromJson(o))
        .toList(),
  );
}

/// Topic entry in memory index
class TopicEntry {
  final String topic;
  final List<String> refs;
  final DateTime lastTimestamp;

  TopicEntry({
    required this.topic,
    required this.refs,
    required this.lastTimestamp,
  });

  Map<String, dynamic> toJson() => {
    'topic': topic,
    'refs': refs,
    'last_ts': lastTimestamp.toIso8601String(),
  };

  factory TopicEntry.fromJson(Map<String, dynamic> json) => TopicEntry(
    topic: json['topic'],
    refs: List<String>.from(json['refs']),
    lastTimestamp: DateTime.parse(json['last_ts']),
  );
}

/// Entity entry in memory index
class EntityEntry {
  final String name;
  final List<String> refs;
  final DateTime lastTimestamp;

  EntityEntry({
    required this.name,
    required this.refs,
    required this.lastTimestamp,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'refs': refs,
    'last_ts': lastTimestamp.toIso8601String(),
  };

  factory EntityEntry.fromJson(Map<String, dynamic> json) => EntityEntry(
    name: json['name'],
    refs: List<String>.from(json['refs']),
    lastTimestamp: DateTime.parse(json['last_ts']),
  );
}

/// Open loop entry in memory index
class OpenLoopEntry {
  final String title;
  final List<String> refs;
  final String status; // open, closed, etc.
  final DateTime lastTimestamp;

  OpenLoopEntry({
    required this.title,
    required this.refs,
    this.status = 'open',
    required this.lastTimestamp,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'refs': refs,
    'status': status,
    'last_ts': lastTimestamp.toIso8601String(),
  };

  factory OpenLoopEntry.fromJson(Map<String, dynamic> json) => OpenLoopEntry(
    title: json['title'],
    refs: List<String>.from(json['refs']),
    status: json['status'] ?? 'open',
    lastTimestamp: DateTime.parse(json['last_ts']),
  );
}