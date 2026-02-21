// lib/mcp/adapters/to_mira.dart
// Converts MCP interchange format to MIRA semantic records

import 'package:my_app/mira/core/schema.dart';

class McpToMiraAdapter {
  /// Convert MCP node record to MiraNode
  static MiraNode? nodeFromMcp(Map<String, dynamic> record) {
    try {
      // Validate required fields
      if (!_hasRequiredFields(record, ['id', 'type', 'timestamp'])) {
        return null;
      }

      final id = record['id'] as String;
      final typeStr = record['type'] as String;
      final timestampStr = record['timestamp'] as String;

      // Parse node type
      final type = _parseNodeType(typeStr);
      if (type == null) return null;

      // Parse timestamp
      final timestamp = DateTime.parse(timestampStr);

      // Extract content
      final content = record['content'] as Map<String, dynamic>? ?? {};
      final narrative = content['narrative'] as String? ?? '';
      final keywords = _parseKeywords(content['keywords']);

      // Extract metadata
      final metadata = Map<String, dynamic>.from(
        record['metadata'] as Map<String, dynamic>? ?? {},
      );

      return MiraNode.entry(
        narrative: narrative,
        keywords: keywords,
        timestamp: timestamp,
        metadata: {
          ...metadata,
          'mcp_id': id,
          'mcp_type': typeStr,
        },
        id: id,
      );
    } catch (e) {
      // Log error and skip malformed record
      return null;
    }
  }

  /// Convert MCP edge record to MiraEdge
  static MiraEdge? edgeFromMcp(Map<String, dynamic> record) {
    try {
      // Validate required fields
      if (!_hasRequiredFields(record, ['source', 'target', 'relation', 'timestamp'])) {
        return null;
      }

      final src = record['source'] as String;
      final dst = record['target'] as String;
      final relationStr = record['relation'] as String;
      final timestampStr = record['timestamp'] as String;

      // Parse edge type
      final relation = _parseEdgeType(relationStr);
      if (relation == null) return null;

      // Parse timestamp
      final timestamp = DateTime.parse(timestampStr);

      // Extract optional fields
      final weight = (record['weight'] as num?)?.toDouble() ?? 1.0;
      final metadata = Map<String, dynamic>.from(
        record['metadata'] as Map<String, dynamic>? ?? {},
      );

      switch (relation) {
        case EdgeType.mentions:
          return MiraEdge.mentions(
            src: src,
            dst: dst,
            timestamp: timestamp,
            weight: weight,
          );
        case EdgeType.expresses:
          return MiraEdge.expresses(
            src: src,
            dst: dst,
            timestamp: timestamp,
            intensity: metadata['intensity'] is num ? (metadata['intensity'] as num).toDouble() : 1.0,
          );
        case EdgeType.taggedAs:
          return MiraEdge.taggedAs(
            src: src,
            dst: dst,
            timestamp: timestamp,
            confidence: metadata['confidence'] is num ? (metadata['confidence'] as num).toDouble() : 1.0,
          );
        case EdgeType.cooccurs:
          return MiraEdge.cooccurs(
            keyword1Id: src,
            keyword2Id: dst,
            count: (metadata['count'] as int?) ?? 1,
            lift: (metadata['lift'] as num?)?.toDouble() ?? 1.0,
          );
        default:
          return MiraEdge.create(
            src: src,
            dst: dst,
            label: relation,
            data: metadata,
          );
      }
    } catch (e) {
      // Log error and skip malformed record
      return null;
    }
  }

  /// Extract content from MCP pointer record
  static String? contentFromPointer(Map<String, dynamic> record) {
    try {
      // Check if this is a pointer record
      if (record['kind'] != 'pointer') return null;

      // Extract content based on media type
      final mediaType = record['media_type'] as String?;
      if (mediaType == null || !mediaType.startsWith('text/')) {
        return null; // Only handle text content for now
      }

      return record['content'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Extract embedding vector from MCP embedding record
  static List<double>? embeddingFromMcp(Map<String, dynamic> record) {
    try {
      // Check if this is an embedding record
      if (record['kind'] != 'embedding') return null;

      final vector = record['vector'] as List?;
      if (vector == null) return null;

      return vector.map((v) => (v as num).toDouble()).toList();
    } catch (e) {
      return null;
    }
  }

  /// Parse node type from string
  static NodeType? _parseNodeType(String typeStr) {
    switch (typeStr.toLowerCase()) {
      case 'entry':
        return NodeType.entry;
      case 'keyword':
        return NodeType.keyword;
      case 'emotion':
        return NodeType.emotion;
      case 'phase':
        return NodeType.phase;
      case 'period':
        return NodeType.period;
      case 'topic':
        return NodeType.topic;
      case 'concept':
        return NodeType.concept;
      case 'episode':
        return NodeType.episode;
      case 'summary':
        return NodeType.summary;
      case 'evidence':
        return NodeType.evidence;
      default:
        return null;
    }
  }

  /// Parse edge type from string
  static EdgeType? _parseEdgeType(String relationStr) {
    switch (relationStr.toLowerCase()) {
      case 'mentions':
        return EdgeType.mentions;
      case 'cooccurs':
        return EdgeType.cooccurs;
      case 'expresses':
        return EdgeType.expresses;
      case 'taggedas':
      case 'tagged_as':
        return EdgeType.taggedAs;
      case 'inperiod':
      case 'in_period':
        return EdgeType.inPeriod;
      case 'belongsto':
      case 'belongs_to':
        return EdgeType.belongsTo;
      case 'evidencefor':
      case 'evidence_for':
        return EdgeType.evidenceFor;
      case 'partof':
      case 'part_of':
        return EdgeType.partOf;
      case 'precedes':
        return EdgeType.precedes;
      default:
        return null;
    }
  }

  /// Parse keywords from various formats
  static List<String> _parseKeywords(dynamic keywords) {
    if (keywords == null) return [];

    if (keywords is String) {
      // Handle comma-separated keywords
      return keywords.split(',').map((k) => k.trim()).where((k) => k.isNotEmpty).toList();
    }

    if (keywords is List) {
      // Handle array of keywords
      return keywords.map((k) => k.toString().trim()).where((k) => k.isNotEmpty).toList();
    }

    return [];
  }

  /// Check if record has required fields
  static bool _hasRequiredFields(Map<String, dynamic> record, List<String> required) {
    for (final field in required) {
      if (!record.containsKey(field) || record[field] == null) {
        return false;
      }
    }
    return true;
  }

  /// Convert MCP bundle records to MIRA repository import format
  static List<Map<String, dynamic>> prepareBatchImport(List<Map<String, dynamic>> mcpRecords) {
    final miraRecords = <Map<String, dynamic>>[];

    for (final record in mcpRecords) {
      final kind = record['kind'] as String?;

      switch (kind) {
        case 'node':
          final node = nodeFromMcp(record);
          if (node != null) {
            miraRecords.add({
              'kind': 'node',
              'data': node.toJson(),
            });
          }
          break;

        case 'edge':
          final edge = edgeFromMcp(record);
          if (edge != null) {
            miraRecords.add({
              'kind': 'edge',
              'data': edge.toJson(),
            });
          }
          break;

        case 'pointer':
          // Store pointers as-is for now
          miraRecords.add({
            'kind': 'pointer',
            'data': record,
          });
          break;

        case 'embedding':
          // Store embeddings as-is for now
          miraRecords.add({
            'kind': 'embedding',
            'data': record,
          });
          break;

        default:
          // Skip unknown kinds (additive evolution)
          break;
      }
    }

    return miraRecords;
  }
}

/// Helper extensions for working with MCP records
extension McpRecordExtensions on Map<String, dynamic> {
  /// Check if this is a valid MCP record
  bool get isMcpRecord {
    return containsKey('kind') && containsKey('schema_version');
  }

  /// Get the MCP record kind
  String? get mcpKind => this['kind'] as String?;

  /// Get the MCP schema version
  String? get mcpSchemaVersion => this['schema_version'] as String?;

  /// Convert to MIRA node if this is a node record
  MiraNode? toMiraNode() {
    if (mcpKind == 'node') {
      return McpToMiraAdapter.nodeFromMcp(this);
    }
    return null;
  }

  /// Convert to MIRA edge if this is an edge record
  MiraEdge? toMiraEdge() {
    if (mcpKind == 'edge') {
      return McpToMiraAdapter.edgeFromMcp(this);
    }
    return null;
  }

  /// Extract content if this is a pointer record
  String? extractContent() {
    if (mcpKind == 'pointer') {
      return McpToMiraAdapter.contentFromPointer(this);
    }
    return null;
  }

  /// Extract embedding vector if this is an embedding record
  List<double>? extractEmbedding() {
    if (mcpKind == 'embedding') {
      return McpToMiraAdapter.embeddingFromMcp(this);
    }
    return null;
  }
}