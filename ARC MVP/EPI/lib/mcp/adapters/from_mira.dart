// lib/mcp/adapters/from_mira.dart
// Converts MIRA semantic records to MCP interchange format

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../../mira/core/schema.dart';
import '../../mira/core/ids.dart';
import '../../mira/core/mira_repo.dart';

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
    final combined = '${pointerId}:$modelId';
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

class McpEntryProjector {
  /// Projects confirmed journal entries to MCP records:
  /// Pointer (text evidence), Node (type: journal_entry), and Edges (entry→phase/keywords).
  /// Writes lines directly to the provided sinks.
  static Future<McpCounts> emitAll({
    required MiraRepo repo,
    required IOSink nodesSink,
    required IOSink edgesSink,
    required IOSink pointersSink,
    IOSink? embeddingsSink, // optional for later
  }) async {
    int nodeCount = 0, edgeCount = 0, pointerCount = 0, embeddingCount = 0;

    // Fetch candidate Entry nodes from MIRA
    final entries = await repo.findNodesByType(NodeType.entry, limit: 100000);

    for (final entry in entries) {
      // Skip unconfirmed entries if your app distinguishes; here we accept all Entry nodes.
      final text = _extractEntryText(entry);
      if (text == null || text.trim().isEmpty) {
        // Fallback: if no raw text, try narrative essence if present
        final essence = (entry.data['narrative']?['essence'] ?? '').toString();
        if (essence.trim().isEmpty) continue; // nothing to export
      }

      // 1) Pointer (evidence)
      final pointerId = _pointerIdFor(entry, text);
      final pointer = _pointerRecord(
        pointerId: pointerId,
        entry: entry,
        text: text ?? (entry.data['narrative']?['essence'] ?? '').toString(),
      );
      _writeNdjson(pointersSink, pointer);
      pointerCount++;

      // 2) Node (journal_entry) referencing that pointer
      final journalNode = _journalNodeRecord(entry: entry, pointerId: pointerId);
      _writeNdjson(nodesSink, journalNode);
      nodeCount++;

      // 3) Edges: entry → phase, entry → keywords
      final edges = _edgeRecordsFor(entry: entry, journalNodeId: journalNode['id']);
      for (final e in edges) {
        _writeNdjson(edgesSink, e);
        edgeCount++;
      }

      // 4) (Optional) Embedding placeholder (skip for MVP)
      // If you want a placeholder row now, uncomment:
      // if (embeddingsSink != null) {
      //   final emb = _emptyEmbedding(pointerId);
      //   _writeNdjson(embeddingsSink, emb);
      //   embeddingCount++;
      // }
    }

    return McpCounts(
      nodes: nodeCount,
      edges: edgeCount,
      pointers: pointerCount,
      embeddings: embeddingCount,
    );
  }

  // --- helpers ---

  static void _writeNdjson(IOSink sink, Map<String, dynamic> rec) {
    // Sort keys for determinism (stable diffs)
    final sorted = Map<String, dynamic>.fromEntries(
      rec.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    sink.writeln(jsonEncode(sorted));
  }

  static String? _extractEntryText(MiraNode entry) {
    // Try typical locations; adjust if your app stores it differently.
    if (entry.data['text'] is String) return entry.data['text'];
    if (entry.data['journal']?['text'] is String) return entry.data['journal']['text'];
    // Some builds only store SAGE; use that as evidence fallback:
    final s = entry.data['narrative']?['situation'] ?? '';
    final a = entry.data['narrative']?['action'] ?? '';
    final g = entry.data['narrative']?['growth'] ?? '';
    final e = entry.data['narrative']?['essence'] ?? '';
    final cat = [s, a, g, e].whereType<String>().where((t) => t.trim().isNotEmpty).join(' ');
    return cat.isEmpty ? null : cat;
  }

  static String _pointerIdFor(MiraNode entry, String? text) {
    final t = (text ?? '').trim();
    final h = sha1.convert(utf8.encode('${entry.id}|$t')).toString().substring(0, 12);
    return 'ptr_${entry.id}_$h';
  }

  static Map<String, dynamic> _pointerRecord({
    required String pointerId,
    required MiraNode entry,
    required String text,
  }) {
    final ts = entry.createdAt.toUtc().toIso8601String();
    final contentHash = sha256.convert(utf8.encode(text)).toString();
    // Minimal span w/ optional summary (first ~140 chars)
    final summary = text.length <= 140 ? text : text.substring(0, 140);

    return {
      'id': pointerId,
      'media_type': 'text/plain',
      'descriptor': {
        'kind': 'journal_entry',
        'entry_id': entry.id,
      },
      'sampling_manifest': {
        'spans': [
          {
            'start': 0,
            'end': text.length,
            'summary': summary,
          }
        ],
      },
      'integrity': {
        'content_hash': 'sha256:$contentHash',
        'created_at': ts,
      },
      'provenance': {
        'source': 'EPI',
        'device': 'ios',
      },
      'privacy': {
        'pii_scanned': true,
        'faces': 0,
        'location_precision': 'coarse',
      },
      'schema_version': 'pointer.v1',
    };
  }

  static Map<String, dynamic> _journalNodeRecord({
    required MiraNode entry,
    required String pointerId,
  }) {
    final ts = entry.createdAt.toUtc().toIso8601String();
    final nodeId = 'je_${entry.id}'; // deterministic

    // Carry SAGE (if present) and hints.
    final narrative = (entry.data['narrative'] is Map) ? entry.data['narrative'] : {};
    final phaseHint = entry.data['phase'] ?? entry.data['phase_hint'];
    final keywords = (entry.data['keywords'] is List) ? entry.data['keywords'] : const [];
    final emotions = (entry.data['emotions'] is Map) ? entry.data['emotions'] : const {};

    return {
      'id': nodeId,
      'type': 'journal_entry',
      'timestamp': ts,
      'phase_hint': phaseHint?.toString(),
      'narrative': {
        'situation': narrative['situation'],
        'action': narrative['action'],
        'growth': narrative['growth'],
        'essence': narrative['essence'],
      },
      'keywords': keywords,
      'emotions': emotions,
      'pointer_ref': pointerId,
      // 'embedding_ref': null, // add when vectors are emitted
      'schema_version': 'node.v1',
    };
  }

  static List<Map<String, dynamic>> _edgeRecordsFor({
    required MiraNode entry,
    required String journalNodeId,
  }) {
    final ts = entry.updatedAt.toUtc().toIso8601String();
    final out = <Map<String, dynamic>>[];

    // Phase edge (if phase info present)
    final phase = entry.data['phase'] ?? entry.data['phase_hint'];
    if (phase is String && phase.isNotEmpty) {
      final phaseId = 'ph_${phase.trim().toLowerCase()}';
      out.add({
        'source': journalNodeId,
        'target': phaseId,
        'relation': 'taggedAs',
        'timestamp': ts,
        'schema_version': 'edge.v1',
      });
    }

    // Keyword edges
    final keywords = (entry.data['keywords'] is List) ? entry.data['keywords'] as List : const [];
    for (final k in keywords) {
      final kw = k.toString();
      if (kw.trim().isEmpty) continue;
      final kwId = stableKeywordId(kw);
      out.add({
        'source': journalNodeId,
        'target': kwId,
        'relation': 'mentions',
        'timestamp': ts,
        'schema_version': 'edge.v1',
      });
    }

    return out;
  }

  // Optional placeholder, if you want a record in embeddings.jsonl now
  static Map<String, dynamic> _emptyEmbedding(String pointerId) {
    return {
      'id': 'emb_$pointerId',
      'pointer_ref': pointerId,
      'model_id': 'stub',
      'embedding_version': 'v0',
      'dim': 0,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'schema_version': 'embedding.v1',
    };
  }
}

class McpCounts {
  final int nodes, edges, pointers, embeddings;
  McpCounts({required this.nodes, required this.edges, required this.pointers, required this.embeddings});
}