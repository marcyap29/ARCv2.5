// lib/mcp/adapters/from_mira.dart
// Converts MIRA semantic records to MCP interchange format

import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../mira/core/schema.dart';
import '../../mira/core/ids.dart';

class MiraToMcpAdapter {
  static const String _defaultEncoderId = 'gemini_1_5_flash';
  static const String _defaultVersion = '1.0.0';

  /// Convert MiraNode to MCP node record
  static Map<String, dynamic> nodeToMcp(MiraNode node, {String? encoderId}) {
    return _sortKeys({
      'id': node.id,
      'kind': 'node',
      'type': node.type.toString().split('.').last,
      'timestamp': node.timestamp.toUtc().toIso8601String(),
      'schema_version': 'node.v1',
      'content': _nodeContentToMcp(node),
      'metadata': _nodeMetadataToMcp(node),
      'encoder_id': encoderId ?? _defaultEncoderId,
    });
  }

  /// Convert MiraEdge to MCP edge record
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
      'encoder_id': encoderId ?? _defaultEncoderId,
    });
  }

  /// Convert MIRA content to MCP pointer record
  static Map<String, dynamic> contentToPointer({
    required String content,
    required String mediaType,
    String? pointerId,
    String? encoderId,
    Map<String, dynamic>? metadata,
  }) {
    final id = pointerId ?? _deterministicPointerId(content, mediaType);
    final now = DateTime.now().toUtc().toIso8601String();

    return _sortKeys({
      'id': id,
      'kind': 'pointer',
      'media_type': mediaType,
      'descriptor': {
        'content_type': mediaType,
        'size_bytes': utf8.encode(content).length,
        'encoding': 'utf-8',
      },
      'sampling_manifest': {
        'method': 'full_content',
        'parameters': {},
      },
      'integrity': {
        'created_at': now,
        'content_hash': _contentHash(content),
        'stable': true,
      },
      'provenance': {
        'source': 'mira_export',
        'encoder_id': encoderId ?? _defaultEncoderId,
        'export_timestamp': now,
      },
      'privacy': {
        'classification': 'internal',
        'retention_policy': 'standard',
      },
      'schema_version': 'pointer.v1',
      'content': content,
      'metadata': metadata ?? {},
    });
  }

  /// Convert embedding data to MCP embedding record
  static Map<String, dynamic> embeddingToMcp({
    required String pointerId,
    required String modelId,
    required List<double> vector,
    String? embeddingId,
    String? encoderId,
    Map<String, dynamic>? metadata,
  }) {
    final id = embeddingId ?? _deterministicEmbeddingId(pointerId, modelId);

    return _sortKeys({
      'id': id,
      'kind': 'embedding',
      'pointer_ref': pointerId,
      'model_id': modelId,
      'embedding_version': _defaultVersion,
      'dim': vector.length,
      'vector': vector,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'schema_version': 'embedding.v1',
      'encoder_id': encoderId ?? _defaultEncoderId,
      'metadata': metadata ?? {},
    });
  }

  /// Convert MIRA narrative to MCP content structure
  static Map<String, dynamic> _nodeContentToMcp(MiraNode node) {
    final content = <String, dynamic>{};

    // Map MIRA fields to MCP content structure
    if (node.narrative.isNotEmpty) {
      content['narrative'] = node.narrative;
    }

    if (node.keywords.isNotEmpty) {
      content['keywords'] = node.keywords;
    }

    // Add type-specific content
    switch (node.type) {
      case NodeType.entry:
        content['entry_type'] = 'user_input';
        break;
      case NodeType.keyword:
        content['keyword_type'] = 'extracted';
        break;
      case NodeType.emotion:
        content['emotion_type'] = 'detected';
        break;
      case NodeType.phase:
        content['phase_type'] = 'sage_echo';
        break;
      case NodeType.period:
        content['period_type'] = 'temporal_segment';
        break;
      case NodeType.topic:
        content['topic_type'] = 'semantic_cluster';
        break;
      case NodeType.concept:
        content['concept_type'] = 'abstract_entity';
        break;
      case NodeType.episode:
        content['episode_type'] = 'narrative_segment';
        break;
      case NodeType.summary:
        content['summary_type'] = 'compressed_narrative';
        break;
      case NodeType.evidence:
        content['evidence_type'] = 'supporting_data';
        break;
    }

    return content;
  }

  /// Convert MIRA metadata to MCP metadata structure
  static Map<String, dynamic> _nodeMetadataToMcp(MiraNode node) {
    final metadata = Map<String, dynamic>.from(node.metadata);

    // Add MIRA-specific metadata
    metadata['mira_type'] = node.type.toString();
    metadata['mira_id'] = node.id;

    // Add creation context
    metadata['created_via'] = 'mira_semantic_layer';
    metadata['export_timestamp'] = DateTime.now().toUtc().toIso8601String();

    return metadata;
  }

  /// Sort map keys recursively for deterministic output
  static Map<String, dynamic> _sortKeys(Map<String, dynamic> map) {
    final sorted = Map<String, dynamic>.fromEntries(
      map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );

    sorted.updateAll((key, value) {
      if (value is Map<String, dynamic>) {
        return _sortKeys(value);
      } else if (value is List) {
        return value.map((item) {
          if (item is Map<String, dynamic>) {
            return _sortKeys(item);
          }
          return item;
        }).toList();
      }
      return value;
    });

    return sorted;
  }

  /// Generate deterministic pointer ID
  static String _deterministicPointerId(String content, String mediaType) {
    final combined = '$mediaType:$content';
    final hash = sha1.convert(utf8.encode(combined)).toString().substring(0, 12);
    return 'ptr_$hash';
  }

  /// Generate content hash
  static String _contentHash(String content) {
    return sha1.convert(utf8.encode(content)).toString();
  }

  /// Generate deterministic embedding ID
  static String _deterministicEmbeddingId(String pointerId, String modelId) {
    final combined = '$pointerId:$modelId';
    final hash = sha1.convert(utf8.encode(combined)).toString().substring(0, 12);
    return 'emb_$hash';
  }
}

/// Helper functions for converting MIRA concepts to MCP
extension MiraNodeExtensions on MiraNode {
  /// Convert this node to MCP format
  Map<String, dynamic> toMcp({String? encoderId}) {
    return MiraToMcpAdapter.nodeToMcp(this, encoderId: encoderId);
  }

  /// Generate MCP pointer record for this node's content
  Map<String, dynamic> toMcpPointer({String? encoderId}) {
    return MiraToMcpAdapter.contentToPointer(
      content: narrative,
      mediaType: 'text/plain',
      encoderId: encoderId,
      metadata: {
        'mira_node_id': id,
        'mira_node_type': type.toString(),
      },
    );
  }
}

extension MiraEdgeExtensions on MiraEdge {
  /// Convert this edge to MCP format
  Map<String, dynamic> toMcp({String? encoderId}) {
    return MiraToMcpAdapter.edgeToMcp(this, encoderId: encoderId);
  }
}