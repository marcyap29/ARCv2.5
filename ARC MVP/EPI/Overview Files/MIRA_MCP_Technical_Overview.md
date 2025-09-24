# MIRA-MCP Technical Implementation Overview

> **Purpose**: Comprehensive technical reference for implementing MIRA graph visualization and insights
> **Audience**: AI systems, developers implementing MIRA UI components
> **Last Updated**: September 21, 2025

---

## Executive Summary

This document provides a complete technical overview of the MIRA-MCP semantic memory system implemented in the EPI ARC MVP. MIRA (semantic memory graph) and MCP (Memory Bundle v1 serialization) work together to provide context-aware AI responses and semantic data export/import capabilities.

**Key Achievement**: Full bidirectional semantic memory system with deterministic export/import, enabling AI context sharing and persistent semantic knowledge graphs. CRITICAL RESOLUTION: Fixed issue where MCP export generated empty files instead of journal content by unifying standalone McpExportService with MIRA-based semantic export system. Now includes complete journal entry export as MCP Pointer + Node + Edge records with full text preservation and automatic relationship generation.

**NEW**: **LUMARA Chat Memory Integration** - Complete implementation of persistent chat sessions with 30-day auto-archive, MIRA graph integration (ChatSession/ChatMessage nodes with contains edges), and MCP export system with node.v2 schema compliance.

---

## 1. MIRA Core Architecture

### 1.1 Semantic Data Model

**File**: `lib/mira/core/schema.dart`

MIRA represents semantic memory as a graph with typed nodes and edges:

#### Node Types (Semantic Entities)
```dart
enum NodeType {
  entry,       // Journal entries (user input)
  keyword,     // Extracted keywords
  emotion,     // Emotional states
  phase,       // SAGE Echo phases
  period,      // Time periods
  topic,       // Semantic topics
  concept,     // Abstract concepts
  episode,     // Narrative segments
  summary,     // Compressed narratives
  evidence,    // Supporting data
  chatSession, // LUMARA chat sessions
  chatMessage  // LUMARA chat messages
}
```

#### Edge Types (Relationships)
```dart
enum EdgeType {
  mentions,     // Entry mentions keyword
  cooccurs,     // Keywords co-occur
  expresses,    // Entry expresses emotion
  taggedAs,     // Entry tagged as phase
  inPeriod,     // Event in time period
  belongsTo,    // Belongs to category
  evidenceFor,  // Evidence for claim
  partOf,       // Part of larger concept
  precedes,     // Temporal precedence
  contains      // Session contains message
}
```

#### Core Data Structures
```dart
class MiraNode {
  final String id;           // Deterministic ID
  final NodeType type;       // Semantic type
  final String narrative;    // Human-readable content
  final List<String> keywords; // Associated keywords
  final DateTime timestamp;  // Creation time (UTC)
  final Map<String, dynamic> metadata; // Extensible properties
}

class MiraEdge {
  final String src;         // Source node ID
  final String dst;         // Destination node ID
  final EdgeType relation;  // Relationship type
  final double weight;      // Relationship strength (0.0-1.0)
  final DateTime timestamp; // Creation time (UTC)
  final Map<String, dynamic> metadata; // Extensible properties
}
```

### 1.2 Deterministic ID Generation

**File**: `lib/mira/core/ids.dart`

All IDs are deterministic for stable exports:

```dart
// Keyword nodes: normalized text → stable ID
String stableKeywordId(String text) {
  final normalized = text.trim().toLowerCase();
  final slug = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return 'kw_$slug';
}

// Entry nodes: content hash → stable ID
String deterministicEntryId(String content, DateTime timestamp) {
  final normalized = content.trim();
  final hash = sha1.convert(utf8.encode('$normalized|${timestamp.toIso8601String()}')).toString().substring(0, 12);
  return 'entry_$hash';
}

// Edges: source + relation + destination → stable ID
String deterministicEdgeId(String src, String label, String dst) {
  final combined = '$src|$label|$dst';
  final hash = sha1.convert(utf8.encode(combined)).toString().substring(0, 12);
  return 'e_$hash';
}
```

### 1.3 Feature Flags System

**File**: `lib/mira/core/flags.dart`

Controlled rollout with development/production presets:

```dart
class MiraFlags {
  final bool miraEnabled;          // Enable/disable entire MIRA system
  final bool miraAdvancedEnabled;  // Advanced features (SAGE phases, complex relationships)
  final bool retrievalEnabled;     // Context-aware retrieval from semantic memory
  final bool useSqliteRepo;        // Use SQLite backend instead of Hive

  // Development preset: all features enabled
  static MiraFlags developmentDefaults() => MiraFlags(
    miraEnabled: true,
    miraAdvancedEnabled: true,
    retrievalEnabled: true,
    useSqliteRepo: false,
  );

  // Production preset: conservative rollout
  static MiraFlags productionDefaults() => MiraFlags(
    miraEnabled: true,
    miraAdvancedEnabled: false,
    retrievalEnabled: false,
    useSqliteRepo: false,
  );
}
```

---

## 2. Storage Implementation

### 2.1 Hive Backend (Production)

**File**: `lib/mira/core/hive_repo.dart`

Primary storage implementation with in-memory indexes for performance:

```dart
class HiveMiraRepo implements MiraRepo {
  // In-memory indexes for fast queries
  final Map<NodeType, Set<String>> _byType = {};     // Type → node IDs
  final Map<String, Set<String>> _outIndex = {};     // Source → edge IDs
  final Map<String, Set<String>> _inIndex = {};      // Destination → edge IDs
  final Map<String, Set<String>> _timeIndex = {};    // Time bucket → node IDs

  // Core operations with index maintenance
  Future<void> upsertNode(MiraNode node) async {
    await _nodesBox.put(node.id, node);
    _indexNode(node);  // Update in-memory indexes
  }

  Future<void> upsertEdge(MiraEdge edge) async {
    final edgeId = deterministicEdgeId(edge.src, edge.relation.toString(), edge.dst);
    await _edgesBox.put(edgeId, edge);
    _indexEdge(edgeId, edge);  // Update in-memory indexes
  }

  // Fast retrieval using indexes
  Future<List<MiraNode>> findNodesByType(NodeType type, {int limit = 100}) async {
    final nodeIds = _byType[type] ?? <String>{};
    return nodeIds.take(limit).map((id) => _nodesBox.get(id)!).toList();
  }
}
```

Key Performance Features:
- **In-memory indexes** for O(1) type/relationship lookups
- **Batch operations** for efficient bulk imports
- **Time-based indexing** for temporal queries
- **Graceful error recovery** with fallback mechanisms

### 2.2 SQLite Backend (Future)

**File**: `lib/mira/core/sqlite_repo.dart`

Placeholder implementation for future SQLite integration:

```dart
class SqliteMiraRepo implements MiraRepo {
  final dynamic database;  // To be provided by DI

  @override
  Future<void> upsertNode(MiraNode node) {
    throw UnimplementedError('SQLite implementation pending');
  }
  // ... all methods throw UnimplementedError
}
```

Activated via `useSqliteRepo: true` flag when ready.

### 2.3 iOS Deployment & Sandbox Compatibility

**Critical Fix**: MCP import functionality now supports iOS app sandbox environments.

**Issue Resolved** (BUG-2025-09-20-001): MiraWriter previously used hardcoded development paths that don't exist in iOS sandboxes:

```dart
// ❌ BEFORE: Hardcoded development path
: _storageRoot = storageRoot ?? '/Users/mymac/Software Development/EPI/ARC MVP/EPI/mira_storage';

// ✅ AFTER: Dynamic iOS sandbox path resolution
Future<String> get _storageRoot async {
  if (_customStorageRoot != null) return _customStorageRoot!;

  final appDir = await getApplicationDocumentsDirectory();
  return path.join(appDir.path, 'mira_storage');
}
```

**iOS Storage Paths**:
- **Development**: `/Users/mymac/.../mira_storage`
- **iOS Production**: `/var/mobile/Containers/Data/Application/.../Documents/mira_storage/`

**Key Technical Changes**:
- Added `path_provider` dependency for cross-platform path resolution
- Updated all 20+ MiraWriter storage methods to use async path resolution
- Ensured proper directory creation with `recursive: true` for app sandbox
- Maintains compatibility with CLI tools and desktop development

**Impact**: MCP import/export now works seamlessly on iOS devices, enabling full AI ecosystem interoperability on mobile platforms.

---

## 3. Event Logging System

### 3.1 Append-Only Events

**File**: `lib/mira/core/events.dart`

All changes logged as immutable events with integrity verification:

```dart
class MiraEvent {
  final String id;           // SHA-1 hash of content
  final String type;         // Event type (node_created, edge_updated, etc.)
  final Map<String, dynamic> payload; // Event data
  final DateTime ts;         // Timestamp (UTC)
  final String checksum;     // SHA-1 integrity hash

  // Create event with automatic checksum
  static MiraEvent create({
    required String type,
    required Map<String, dynamic> payload,
  }) {
    final ts = DateTime.now().toUtc();
    final content = jsonEncode({'type': type, 'payload': payload, 'ts': ts.toIso8601String()});
    final checksum = sha1.convert(utf8.encode(content)).toString();

    return MiraEvent(
      id: checksum.substring(0, 16),
      type: type,
      payload: payload,
      ts: ts,
      checksum: checksum,
    );
  }
}
```

**Benefits**:
- **Audit trails** for all semantic memory changes
- **Idempotency** via checksum-based deduplication
- **Integrity verification** for data consistency
- **Replay capability** for debugging and recovery

---

## 4. LUMARA Chat Memory System

### 4.1 Chat Memory Architecture

**Files**:
- `lib/lumara/chat/chat_models.dart` - Core data models
- `lib/lumara/chat/chat_repo.dart` - Repository interface
- `lib/lumara/chat/chat_repo_impl.dart` - Hive-backed implementation

The chat memory system provides persistent storage for LUMARA conversations:

#### Chat Data Models
```dart
@HiveType(typeId: 20)
class ChatSession extends Equatable {
  @HiveField(0) final String id;           // ULID for stability
  @HiveField(1) final String subject;      // Auto-generated from first message
  @HiveField(2) final DateTime createdAt;  // Session creation time
  @HiveField(3) final DateTime updatedAt;  // Last activity time
  @HiveField(4) final bool isPinned;       // Prevents auto-archive
  @HiveField(5) final bool isArchived;     // Archive status
  @HiveField(6) final DateTime? archivedAt; // Archive timestamp
  @HiveField(7) final List<String> tags;   // User tags for organization
  @HiveField(8) final int messageCount;    // Cached count for performance
}

@HiveType(typeId: 21)
class ChatMessage extends Equatable {
  @HiveField(0) final String id;           // ULID for stability
  @HiveField(1) final String sessionId;    // Parent session ID
  @HiveField(2) final MessageRole role;    // user/assistant
  @HiveField(3) final String content;      // Message text
  @HiveField(4) final DateTime createdAt;  // Message timestamp
  @HiveField(5) final Map<String, dynamic> metadata; // Extensible properties
}
```

#### Repository Pattern
```dart
abstract class ChatRepo {
  Future<String> createSession({String? subject, List<String> tags = const []});
  Future<void> addMessage({required String sessionId, required MessageRole role, required String content});
  Future<List<ChatSession>> listActive({String? query, int limit = 50});
  Future<List<ChatSession>> listArchived({String? query, int limit = 50});
  Future<void> archiveSession(String sessionId, bool archived);
  Future<void> deleteSession(String sessionId);
  Future<void> pruneByPolicy({Duration maxAge = const Duration(days: 30)});
}
```

### 4.2 30-Day Auto-Archive Policy

**File**: `lib/lumara/chat/chat_archive_policy.dart`

Non-destructive archive system with configurable policies:

```dart
class ChatArchivePolicy {
  static const Duration defaultMaxAge = Duration(days: 30);
  static const int defaultMessageThreshold = 5;

  // Check if session should be archived
  static bool shouldArchive(ChatSession session, {
    Duration maxAge = defaultMaxAge,
    int messageThreshold = defaultMessageThreshold,
  }) {
    // Never archive pinned sessions
    if (session.isPinned) return false;

    // Already archived
    if (session.isArchived) return false;

    // Check age-based criteria
    final age = DateTime.now().difference(session.updatedAt);
    if (age > maxAge) return true;

    // Check activity-based criteria
    if (session.messageCount < messageThreshold && age > Duration(days: 7)) {
      return true;
    }

    return false;
  }
}
```

### 4.3 MIRA Graph Integration

**Files**:
- `lib/mira/nodes/chat_session_node.dart` - ChatSession → MIRA Node
- `lib/mira/nodes/chat_message_node.dart` - ChatMessage → MIRA Node
- `lib/mira/edges/contains_edge.dart` - Session-Message relationships
- `lib/mira/adapters/chat_to_mira.dart` - Conversion utilities

Chat sessions and messages are integrated into the MIRA semantic graph:

#### MIRA Node Creation
```dart
class ChatSessionNode extends MiraNode {
  final String sessionId;
  final String subject;
  final bool isPinned;
  final bool isArchived;
  final List<String> tags;
  final int messageCount;

  // Convert from ChatSession model
  factory ChatSessionNode.fromModel(ChatSession session) {
    return ChatSessionNode(
      id: 'chat_session_${session.id}',
      sessionId: session.id,
      subject: session.subject,
      isPinned: session.isPinned,
      isArchived: session.isArchived,
      tags: session.tags,
      messageCount: session.messageCount,
      timestamp: session.createdAt,
      metadata: {
        'source': 'lumara_chat',
        'session_type': 'conversation',
        'updated_at': session.updatedAt.toIso8601String(),
      },
    );
  }
}
```

#### Relationship Edges
```dart
class ContainsEdge extends MiraEdge {
  final int messageOrder;

  factory ContainsEdge.sessionToMessage({
    required String sessionId,
    required String messageId,
    required int order,
    required DateTime timestamp,
  }) {
    return ContainsEdge(
      src: 'chat_session_$sessionId',
      dst: 'chat_message_$messageId',
      relation: EdgeType.contains,
      weight: 1.0,
      timestamp: timestamp,
      messageOrder: order,
      metadata: {
        'order': order,
        'relationship_type': 'session_message',
      },
    );
  }
}
```

### 4.4 MCP Export Integration

**File**: `lib/mcp/export/chat_exporter.dart`

Complete MCP export system for chat data:

#### Chat-Specific MCP Export
```dart
class ChatMcpExporter {
  /// Export chats to MCP format with node.v2 compliance
  Future<Directory> exportChatsToMcp({
    required Directory outputDir,
    bool includeArchived = true,
    DateTime? since,
    DateTime? until,
    String profile = "monthly_chat_archive",
  }) async {
    // Export sessions as MCP nodes
    for (final session in sessions) {
      final sessionNode = _createSessionNode(session);
      nodesStream.writeln(jsonEncode(sessionNode));

      // Export session pointer for discoverability
      final sessionPointer = _createSessionPointer(session);
      pointersStream.writeln(jsonEncode(sessionPointer));

      // Export messages and contains edges
      final messages = await _chatRepo.getMessages(session.id);
      for (int i = 0; i < messages.length; i++) {
        final message = messages[i];

        // Export message node with privacy processing
        final messageNode = _createMessageNode(message);
        nodesStream.writeln(jsonEncode(messageNode));

        // Export contains edge with order metadata
        final containsEdge = _createContainsEdge(
          session.id, message.id, message.createdAt, i
        );
        edgesStream.writeln(jsonEncode(containsEdge));
      }
    }
  }

  /// Create MCP node.v2 for chat session
  Map<String, dynamic> _createSessionNode(ChatSession session) {
    return {
      "kind": "node",
      "type": "ChatSession",
      "id": "session:${session.id}",
      "timestamp": session.createdAt.toUtc().toIso8601String(),
      "content": {"title": session.subject},
      "metadata": {
        "isArchived": session.isArchived,
        "isPinned": session.isPinned,
        "tags": session.tags,
        "messageCount": session.messageCount,
        "retention": "auto-archive-30d",
      },
      "schema_version": "node.v2"
    };
  }
}
```

#### Privacy and Provenance
```dart
class ChatPrivacyRedactor {
  /// Process message content for privacy
  ChatPrivacyResult processContent(String content) {
    bool containsPii = false;
    String processedContent = content;
    final List<String> detectedPii = [];

    // Detect PII patterns (email, phone, SSN, etc.)
    for (final pattern in _piiPatterns) {
      final matches = pattern.allMatches(content);
      if (matches.isNotEmpty) {
        containsPii = true;
        for (final match in matches) {
          detectedPii.add(match.group(0) ?? '');
          if (maskPii) {
            processedContent = processedContent.replaceFirst(
              match.group(0)!, '[REDACTED-${detectedPii.length}]'
            );
          }
        }
      }
    }

    return ChatPrivacyResult(
      content: processedContent,
      containsPii: containsPii,
      detectedPatterns: detectedPii,
      originalHash: preserveHashes ? _hashContent(content) : null,
    );
  }
}
```

### 4.5 JSON Schema Validation

**Files**: `lib/mcp/bundle/schemas/`
- `chat_session.v1.json` - ChatSession node schema
- `chat_message.v1.json` - ChatMessage node schema
- `edge.v1.json` - Enhanced with contains relationship
- `node.v2.json` - Updated with ChatSession/ChatMessage types

#### Chat Session Schema
```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://schemas.mcp.ai/chat_session.v1.json",
  "title": "MCP Chat Session v1",
  "type": "object",
  "properties": {
    "kind": {"const": "node"},
    "type": {"const": "ChatSession"},
    "id": {"type": "string", "pattern": "^session:"},
    "content": {
      "type": "object",
      "properties": {
        "title": {"type": "string", "maxLength": 200}
      },
      "required": ["title"]
    },
    "metadata": {
      "type": "object",
      "properties": {
        "isArchived": {"type": "boolean"},
        "isPinned": {"type": "boolean"},
        "messageCount": {"type": "integer", "minimum": 0},
        "tags": {"type": "array", "items": {"type": "string"}},
        "retention": {"type": "string"}
      }
    }
  },
  "required": ["kind", "type", "id", "timestamp", "content", "schema_version"]
}
```

---

## 5. MCP Bundle System

### 5.1 Manifest and JSON Schema Validation

**File**: `lib/mcp/bundle/schemas.dart`

Embedded JSON Schema definitions for MCP v1 records. The manifest now uses `schema_version: "1.0.0"` (semantic) rather than `manifest.v1`:

```dart
class McpSchemas {
  // Node schema - semantic entities
  static const String nodeV1 = '''
  {
    "type": "object",
    "properties": {
      "id": {"type": "string"},
      "kind": {"const": "node"},
      "type": {"enum": ["entry", "keyword", "emotion", "phase", "period", "topic", "concept", "episode", "summary", "evidence"]},
      "timestamp": {"type": "string", "format": "date-time"},
      "schema_version": {"const": "node.v1"},
      "content": {"type": "object"},
      "metadata": {"type": "object"}
    },
    "required": ["id", "kind", "type", "timestamp", "schema_version"]
  }
  ''';

  // Edge schema - relationships
  static const String edgeV1 = '''
  {
    "type": "object",
    "properties": {
      "kind": {"const": "edge"},
      "source": {"type": "string"},
      "target": {"type": "string"},
      "relation": {"enum": ["mentions", "cooccurs", "expresses", "taggedAs", "inPeriod", "belongsTo", "evidenceFor", "partOf", "precedes"]},
      "timestamp": {"type": "string", "format": "date-time"},
      "schema_version": {"const": "edge.v1"},
      "weight": {"type": "number", "minimum": 0.0, "maximum": 1.0}
    },
    "required": ["kind", "source", "target", "relation", "timestamp", "schema_version"]
  }
  ''';
}
```

### 5.2 Bundle Export (Deterministic)

**File**: `lib/mcp/bundle/writer.dart`

Streaming NDJSON export with SHA-256 integrity:

```dart
class McpBundleWriter {
  Future<Directory> exportBundle({
    required Directory outDir,
    required String storageProfile,
    required List<Map<String, dynamic>> encoderRegistry,
    bool includeEvents = false,
  }) async {
    // Create deterministic file structure
    final nodesPath = File('${outDir.path}/nodes.jsonl');
    final edgesPath = File('${outDir.path}/edges.jsonl');
    final manifestPath = File('${outDir.path}/manifest.json');

    // Stream export with checksum calculation
    var nodesBytes = 0, edgesBytes = 0;
    final nodesHash = AccumulatorSink<Digest>();
    final nodesDigest = sha256.startChunkedConversion(nodesHash);

    // Export in dependency order: nodes, edges, pointers, embeddings
    await for (final rec in repo.exportAll()) {
      final kind = rec['kind'];
      final line = JsonEncoder.withIndent(null, (o) => o).convert(_sortKeys(rec)) + '\n';
      final bytes = utf8.encode(line);

      switch (kind) {
        case 'node':
          nodesSink.add(bytes);
          nodesDigest.add(bytes);
          nodesBytes += bytes.length;
          break;
        // ... handle other types
      }
    }

    // Generate manifest with checksums
    final manifest = {
      'bundle_id': 'mcp_${DateTime.now().toUtc().toIso8601String()}',
      'version': '1.0.0',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'storage_profile': storageProfile,
      'checksums': {
        'nodes_jsonl': 'sha256:${nodesHash.events.single}',
        'edges_jsonl': 'sha256:${edgesHash.events.single}',
      },
      'encoder_registry': encoderRegistry,
    };

    await manifestPath.writeAsString(const JsonEncoder.withIndent('  ').convert(manifest));
    return outDir;
  }
}
```

### 5.3 Bundle Import (Streaming)

**File**: `lib/mcp/bundle/reader.dart`

Streaming import with validation and conflict resolution:

```dart
class McpBundleReader {
  Future<ImportResult> importBundle({
    required Directory bundleDir,
    bool validateChecksums = true,
    bool skipExisting = true,
  }) async {
    // Validate manifest
    final manifest = jsonDecode(await manifestFile.readAsString());
    final errors = <String>[];
    if (!validator.validateManifest(manifest, errors)) {
      throw ImportError('Invalid manifest: ${errors.join(', ')}');
    }

    // Import in dependency order
    await _importJsonlFile(bundleDir: bundleDir, filename: 'nodes.jsonl', kind: 'node');
    await _importJsonlFile(bundleDir: bundleDir, filename: 'edges.jsonl', kind: 'edge');

    return result;
  }

  Future<void> _importJsonlFile({required String filename, required String kind}) async {
    final stream = file.openRead().transform(utf8.decoder).transform(const LineSplitter());

    await for (final line in stream) {
      final record = jsonDecode(line);

      // Validate record
      if (!validator.validateLine(kind, record, lineNo, errors)) continue;

      // Check for existing records
      if (skipExisting && await _recordExists(kind, record)) continue;

      records.add(record);
    }

    // Batch import for performance
    if (records.isNotEmpty) {
      await repo.importAll(records);
    }
  }
}
```

---

## 6. Bidirectional Adapters

### 6.1 MIRA → MCP Conversion

**File**: `lib/mcp/adapters/from_mira.dart`

Converts semantic objects to MCP interchange format:

```dart
class MiraToMcpAdapter {
  // Convert semantic node to MCP record
  static Map<String, dynamic> nodeToMcp(MiraNode node, {String? encoderId}) {
    return _sortKeys({
      'id': node.id,
      'kind': 'node',
      'type': node.type.toString().split('.').last,
      'timestamp': node.timestamp.toUtc().toIso8601String(),
      'schema_version': 'node.v1',
      'content': _nodeContentToMcp(node),
      'metadata': _nodeMetadataToMcp(node),
      'encoder_id': encoderId ?? 'gemini_1_5_flash',
    });
  }

  // Convert semantic relationship to MCP edge
  static Map<String, dynamic> edgeToMcp(MiraEdge edge, {String? encoderId}) {
    return _sortKeys({
      'kind': 'edge',
      'source': edge.src,
      'target': edge.dst,
      'relation': edge.relation.toString().split('.').last,
      'timestamp': edge.timestamp.toUtc().toIso8601String(),
      'schema_version': 'edge.v1',
      'weight': edge.weight,
      'metadata': edge.metadata,
      'encoder_id': encoderId ?? 'gemini_1_5_flash',
    });
  }
}
```

### 6.2 MCP → MIRA Conversion

**File**: `lib/mcp/adapters/to_mira.dart`

Converts MCP records back to semantic objects:

```dart
class McpToMiraAdapter {
  // Parse MCP node record to semantic object
  static MiraNode? nodeFromMcp(Map<String, dynamic> record) {
    try {
      final id = record['id'] as String;
      final typeStr = record['type'] as String;
      final type = _parseNodeType(typeStr);
      if (type == null) return null;

      final content = record['content'] as Map<String, dynamic>? ?? {};
      final narrative = content['narrative'] as String? ?? '';
      final keywords = _parseKeywords(content['keywords']);

      return MiraNode(
        id: id,
        type: type,
        narrative: narrative,
        keywords: keywords,
        timestamp: DateTime.parse(record['timestamp'] as String),
        metadata: Map<String, dynamic>.from(record['metadata'] ?? {}),
      );
    } catch (e) {
      return null; // Skip malformed records gracefully
    }
  }
}
```

---

## 7. AI Integration Enhancement

### 7.1 Context-Aware ArcLLM

**Files**:
- `lib/core/arc_llm.dart` (enhanced)
- `lib/services/llm_bridge_adapter.dart` (enhanced)

ArcLLM now includes semantic memory context:

```dart
class ArcLLM {
  final ArcSendFn send;
  final MiraService? _miraService;

  // Enhanced chat with semantic context
  Future<String> chat({
    required String userIntent,
    String entryText = "",
    String? phaseHintJson,
    String? lastKeywordsJson,
  }) async {
    // Enhance with MIRA context if available
    String enhancedKeywords = lastKeywordsJson ?? 'null';
    if (_miraService != null && _miraService!.flags.retrievalEnabled) {
      try {
        final contextKeywords = await _miraService!.searchNarratives(userIntent, limit: 5);
        if (contextKeywords.isNotEmpty) {
          enhancedKeywords = '{"context": ${contextKeywords.map((k) => '"$k"').join(', ')}, "last": $lastKeywordsJson}';
        }
      } catch (e) {
        // Fall back to original keywords if MIRA fails
      }
    }

    // Send enhanced prompt with context
    return send(system: ArcPrompts.system, user: userPrompt, jsonExpected: false);
  }

  // Auto-store SAGE results in semantic memory
  Future<String> sageEcho(String entryText) async {
    final result = await send(system: ArcPrompts.system, user: userPrompt, jsonExpected: true);

    if (_miraService != null && _miraService!.flags.miraEnabled) {
      await _miraService!.addSemanticData(
        entryText: entryText,
        sagePhases: {'sage_echo': result},
        metadata: {'source': 'sage_echo', 'timestamp': DateTime.now().toIso8601String()},
      );
    }

    return result;
  }
}
```

### 7.2 Semantic Data Storage

When AI processes user input, results are automatically stored in MIRA:

1. **Journal Entry** → MIRA Entry Node
2. **SAGE Echo** → MIRA Phase Nodes + metadata
3. **Keywords** → MIRA Keyword Nodes + "mentions" edges
4. **Emotions** → MIRA Emotion Nodes + "expresses" edges

---

## 8. High-Level Integration API

### 8.1 MiraIntegration Service

**File**: `lib/mira/mira_integration.dart`

Simplified API for existing components:

```dart
class MiraIntegration {
  // Initialize with feature flags
  Future<void> initialize({
    bool miraEnabled = true,
    bool miraAdvancedEnabled = false,
    bool retrievalEnabled = false,
    bool useSqliteRepo = false,
  });

  // Create MIRA-enhanced ArcLLM
  ArcLLM createArcLLM({required ArcSendFn sendFunction});

  // Export semantic memory to MCP bundle
  Future<String?> exportMcpBundle({
    required String outputPath,
    String storageProfile = 'balanced',
    bool includeEvents = false,
  });

  // Import MCP bundle into semantic memory
  Future<Map<String, dynamic>?> importMcpBundle({
    required String bundlePath,
    bool validateChecksums = true,
    bool skipExisting = true,
  });

  // Search semantic memory
  Future<List<Map<String, dynamic>>> searchMemory({
    String? query,
    String? nodeType,
    DateTime? since,
    DateTime? until,
    int limit = 50,
  });

  // Get analytics
  Future<Map<String, dynamic>> getStatus();
}
```

### 8.2 Usage Examples

```dart
// Initialize MIRA system
await MiraIntegration.instance.initialize(
  miraEnabled: true,
  retrievalEnabled: true,
);

// Create context-aware ArcLLM
final arcLLM = MiraIntegration.instance.createArcLLM(
  sendFunction: geminiSend,
);

// Get intelligent responses with semantic context
final response = await arcLLM.chat(
  userIntent: "How am I handling work stress lately?",
  entryText: currentEntry,
);

// Export semantic memory for AI sharing
final bundlePath = await MiraIntegration.instance.exportMcpBundle(
  outputPath: '/path/to/export',
  storageProfile: 'balanced',
);

// Search semantic patterns
final workStressEntries = await MiraIntegration.instance.searchMemory(
  query: "work stress",
  nodeType: "entry",
  since: DateTime.now().subtract(Duration(days: 30)),
);
```

---

## 9. Graph Visualization Requirements

### 9.1 Data Access Patterns

For implementing MIRA graph visualization, you'll need these data access patterns:

```dart
// Get all nodes by type
final keywords = await repo.findNodesByType(NodeType.keyword, limit: 100);
final entries = await repo.findNodesByType(NodeType.entry, limit: 50);

// Get relationships between nodes
final keywordEdges = await repo.edgesFrom(keywordId, label: EdgeType.mentions);
final emotionEdges = await repo.edgesTo(entryId, label: EdgeType.expresses);

// Get connected components (for clustering)
final cluster = await repo.getConnectedComponent(nodeId, maxDepth: 3);

// Get temporal patterns
final recentNodes = await repo.getNodesInTimeRange(
  start: DateTime.now().subtract(Duration(days: 30)),
  end: DateTime.now(),
);

// Get top keywords (for sizing)
final topKeywords = await repo.getTopKeywords(limit: 20);

// Get node/edge statistics
final nodeCounts = await repo.getNodeCounts();
final edgeCounts = await repo.getEdgeCounts();
```

### 9.2 Graph Structure

The semantic graph has these characteristics:

**Node Properties**:
- **ID**: Unique identifier (deterministic)
- **Type**: Semantic category (entry, keyword, emotion, etc.)
- **Content**: Human-readable narrative
- **Keywords**: Associated keywords list
- **Timestamp**: Creation time (for temporal clustering)
- **Metadata**: Extensible properties

**Edge Properties**:
- **Source/Target**: Node IDs
- **Relation**: Relationship type (mentions, cooccurs, expresses, etc.)
- **Weight**: Relationship strength (0.0-1.0)
- **Timestamp**: Creation time
- **Metadata**: Extensible properties

**Recommended Visualizations**:
1. **Keyword Co-occurrence Network**: Keywords as nodes, co-occurrence as edges
2. **Entry-Keyword Bipartite Graph**: Entries and keywords with "mentions" edges
3. **Temporal Clustering**: Nodes grouped by time periods
4. **Emotional Landscape**: Entries colored by emotional valence
5. **Phase Progression**: Entries connected by temporal sequence with phase annotations

### 9.3 Performance Considerations

- **In-memory indexes** provide O(1) lookups for node types and relationships
- **Batch queries** for efficient data loading
- **Pagination** for large result sets
- **Caching** for expensive graph computations
- **Incremental updates** for real-time visualization

---

## 10. Insights Generation Patterns

### 10.1 Semantic Patterns

```dart
// Keyword frequency over time
final keywordTrends = await analyzeKeywordTrends(timeWindow: Duration(days: 30));

// Emotional patterns
final emotionalJourney = await analyzeEmotionalProgression(entries);

// Phase transitions
final phaseTransitions = await analyzePhaseTransitions(entries);

// Co-occurrence clusters
final topicClusters = await analyzeKeywordClusters(threshold: 0.5);
```

### 10.2 Insight Types

Based on the semantic graph, generate insights for:

1. **Temporal Patterns**: How themes evolve over time
2. **Emotional Patterns**: Emotional state progression
3. **Topic Clusters**: Related keyword groups
4. **Phase Transitions**: Life phase change indicators
5. **Growth Indicators**: Evidence of personal development
6. **Relationship Patterns**: How concepts connect
7. **Narrative Coherence**: Story consistency over time

---

## 11. Implementation Files Reference

### Core MIRA Files
```
lib/mira/core/
├── flags.dart           # Feature flag system
├── ids.dart            # Deterministic ID generation
├── schema.dart         # Node/Edge data models
├── events.dart         # Event logging system
├── mira_repo.dart      # Repository interface
├── hive_repo.dart      # Hive storage implementation
└── sqlite_repo.dart    # SQLite stub (future)
```

### MCP Bundle Files
```
lib/mcp/bundle/
├── schemas.dart        # JSON Schema definitions
├── validate.dart       # MCP record validation
├── manifest.dart       # Bundle manifest builder
├── writer.dart         # Deterministic export
└── reader.dart         # Streaming import
```

### Adapter Files
```
lib/mcp/adapters/
├── from_mira.dart      # MIRA → MCP conversion
└── to_mira.dart        # MCP → MIRA conversion
```

### Integration Files
```
lib/mira/
├── mira_service.dart      # Main service orchestrator
└── mira_integration.dart  # High-level API
```

### Enhanced AI Files
```
lib/core/arc_llm.dart              # Enhanced ArcLLM
lib/services/llm_bridge_adapter.dart  # Enhanced bridge
```

### LUMARA Chat Memory Files
```
lib/lumara/chat/
├── chat_models.dart        # ChatSession/ChatMessage data models
├── chat_repo.dart          # Repository interface
├── chat_repo_impl.dart     # Hive storage implementation
├── chat_archive_policy.dart # 30-day auto-archive policy
├── chat_pruner.dart        # Archive policy executor
├── privacy_redactor.dart   # PII detection and redaction
├── provenance_tracker.dart # Export metadata tracking
├── ulid.dart              # Stable ID generation
└── ui/
    ├── chats_screen.dart   # Chat history with search/filter
    ├── archive_screen.dart # Archived sessions view
    └── session_view.dart   # Individual session display
```

### MIRA Chat Integration Files
```
lib/mira/nodes/
├── chat_session_node.dart  # ChatSession → MIRA Node
└── chat_message_node.dart  # ChatMessage → MIRA Node

lib/mira/edges/
└── contains_edge.dart      # Session-Message relationships

lib/mira/adapters/
└── chat_to_mira.dart      # Chat → MIRA conversion utilities
```

### Chat MCP Export Files
```
lib/mcp/export/
└── chat_exporter.dart      # Chat-specific MCP export

lib/mcp/bundle/schemas/
├── chat_session.v1.json    # ChatSession schema
├── chat_message.v1.json    # ChatMessage schema
├── edge.v1.json           # Enhanced with contains relation
└── node.v2.json           # Updated with chat types
```

### Chat Memory Tests
```
test/lumara/chat/
├── chat_repo_test.dart          # Repository functionality
├── privacy_redactor_test.dart   # PII detection/redaction
└── provenance_tracker_test.dart # Metadata generation

test/mcp/export/
└── chat_exporter_test.dart      # MCP export validation
```

---

## 12. Next Steps for Graph Implementation

### Immediate Requirements
1. **Graph Visualization Component**: Create Flutter widget for interactive graph display
2. **Data Loading Service**: Implement efficient graph data loading from MIRA repository
3. **Layout Algorithms**: Implement force-directed or hierarchical layout for nodes
4. **Interaction Handlers**: Add pan, zoom, node selection, and detail views
5. **Real-time Updates**: Stream updates from MIRA repository to visualization

### Advanced Features
1. **Semantic Clustering**: Group related nodes using graph algorithms
2. **Temporal Animation**: Show graph evolution over time
3. **Insight Generation**: Detect patterns and generate natural language insights
4. **Export Capabilities**: Export graph visualizations and insights
5. **Search Integration**: Find and highlight nodes/patterns based on queries

This technical overview provides the complete foundation for implementing MIRA graph visualization and insights. The semantic memory system is fully functional and ready for advanced UI components.

---

*Document Status: Complete*
*Implementation Status: Production Ready*
*LUMARA Chat Memory: Complete with 30-day auto-archive + MIRA integration + MCP export*
*Next Phase: Graph Visualization UI*