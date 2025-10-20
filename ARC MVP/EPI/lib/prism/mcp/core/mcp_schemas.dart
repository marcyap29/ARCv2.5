// lib/mcp/core/mcp_schemas.dart
import 'dart:core';

/// ---- Core Graph Types ----
class McpNode {
  final String id; // ULID/UUID
  final String type; // e.g., "chat.message", "journal.entry"
  final DateTime timestamp;
  final String? contentSummary;
  final String? phaseHint;
  final List<String> keywords;
  final String? pointerRef;
  final String? embeddingRef;
  final McpNarrative? narrative;
  final Map<String, double> emotions;
  final McpProvenance provenance;
  final Map<String, dynamic>? metadata;
  final String schemaVersion;

  const McpNode({
    required this.id,
    required this.type,
    required this.timestamp,
    this.contentSummary,
    this.phaseHint,
    this.keywords = const [],
    this.pointerRef,
    this.embeddingRef,
    this.narrative,
    this.emotions = const {},
    required this.provenance,
    this.metadata,
    this.schemaVersion = 'node.v1',
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'type': type,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'keywords': keywords,
      'emotions': emotions,
      'provenance': provenance.toJson(),
      'schema_version': schemaVersion,
    };
    if (contentSummary != null) json['content_summary'] = contentSummary;
    if (phaseHint != null) json['phase_hint'] = phaseHint;
    if (pointerRef != null) json['pointer_ref'] = pointerRef;
    if (embeddingRef != null) json['embedding_ref'] = embeddingRef;
    if (narrative != null) json['narrative'] = narrative!.toJson();
    if (metadata != null) json['metadata'] = metadata;
    return json;
  }

  factory McpNode.fromJson(Map<String, dynamic> json) {
    // Handle different JSON formats - check if this is the new format or legacy format
    final isLegacyFormat = json.containsKey('content') && json.containsKey('encoder_id');
    final isImportedFormat = json.containsKey('content') && json.containsKey('created_at') && !json.containsKey('encoder_id');
    
    if (isLegacyFormat) {
      // Legacy format with content, encoder_id, etc.
      return McpNode(
        id: json['id'] as String,
        type: json['type'] as String,
        timestamp: _parseTimestamp(json),
        contentSummary: _extractContentSummary(json),
        phaseHint: _extractPhaseHint(json),
        keywords: _extractKeywords(json),
        pointerRef: json['pointer_ref'] as String?,
        embeddingRef: json['embedding_ref'] as String?,
        narrative: _extractNarrative(json),
        emotions: _extractEmotions(json),
        provenance: McpProvenance(
          source: json['encoder_id'] as String? ?? 'unknown',
          app: 'mcp_import',
          importMethod: 'import',
          userId: json['id'] as String,
        ),
        metadata: json['metadata'] as Map<String, dynamic>?,
        schemaVersion: json['schema_version'] as String? ?? 'node.v1',
      );
    } else if (isImportedFormat) {
      // Imported format with content, created_at, metadata, etc.
      return McpNode(
        id: json['id'] as String,
        type: json['type'] as String,
        timestamp: _parseTimestamp(json),
        contentSummary: json['content'] as String?, // Use the content field directly
        phaseHint: json['phase_hint'] as String?,
        keywords: List<String>.from(json['keywords'] ?? []),
        pointerRef: json['pointer_ref'] as String?,
        embeddingRef: json['embedding_ref'] as String?,
        narrative: json['narrative'] != null
            ? McpNarrative.fromJson(json['narrative'] as Map<String, dynamic>)
            : null,
        emotions: Map<String, double>.from(json['emotions'] ?? {}),
        provenance: McpProvenance(
          source: 'mcp_import',
          app: 'EPI',
          importMethod: 'import',
          userId: json['id'] as String,
        ),
        metadata: json['metadata'] as Map<String, dynamic>?,
        schemaVersion: json['schema_version'] as String? ?? 'node.v1',
      );
    } else {
      // New format with standard fields
      return McpNode(
        id: json['id'] as String,
        type: json['type'] as String,
        timestamp: _parseTimestamp(json),
        contentSummary: json['content_summary'] as String?,
        phaseHint: json['phase_hint'] as String?,
        keywords: List<String>.from(json['keywords'] ?? []),
        pointerRef: json['pointer_ref'] as String?,
        embeddingRef: json['embedding_ref'] as String?,
        narrative: json['narrative'] != null
            ? McpNarrative.fromJson(json['narrative'] as Map<String, dynamic>)
            : null,
        emotions: Map<String, double>.from(json['emotions'] ?? {}),
        provenance: json['provenance'] != null
            ? McpProvenance.fromJson(json['provenance'] as Map<String, dynamic>)
            : McpProvenance(
                source: 'unknown',
                app: 'mcp_import',
                importMethod: 'import',
                userId: json['id'] as String,
              ),
        metadata: json['metadata'] as Map<String, dynamic>?,
        schemaVersion: json['schema_version'] as String? ?? 'node.v1',
      );
    }
  }

  // Helper methods for legacy format extraction
  static String? _extractContentSummary(Map<String, dynamic> json) {
    final content = json['content'] as Map<String, dynamic>?;
    if (content == null) return null;
    
    // Try different possible fields for content summary
    return content['narrative'] as String? ?? 
           content['content'] as String? ?? 
           content['summary'] as String?;
  }

  static String? _extractPhaseHint(Map<String, dynamic> json) {
    final content = json['content'] as Map<String, dynamic>?;
    if (content == null) return null;
    
    return content['phase'] as String? ?? 
           content['phase_hint'] as String?;
  }

  static List<String> _extractKeywords(Map<String, dynamic> json) {
    final content = json['content'] as Map<String, dynamic>?;
    if (content == null) return [];
    
    final keywords = content['keywords'] as List<dynamic>?;
    if (keywords == null) return [];
    
    return keywords.map((k) => k.toString()).toList();
  }

  static McpNarrative? _extractNarrative(Map<String, dynamic> json) {
    final content = json['content'] as Map<String, dynamic>?;
    if (content == null) return null;
    
    final narrative = content['narrative'] as String?;
    if (narrative == null) return null;
    
    return McpNarrative(
      situation: narrative,
      action: '',
      growth: '',
      essence: '',
    );
  }

  static Map<String, double> _extractEmotions(Map<String, dynamic> json) {
    final content = json['content'] as Map<String, dynamic>?;
    if (content == null) return {};
    
    final emotions = content['emotions'] as Map<String, dynamic>?;
    if (emotions == null) return {};
    
    return emotions.map((k, v) => MapEntry(k, (v as num).toDouble()));
  }

  /// Parse timestamp from various field names and formats
  static DateTime _parseTimestamp(Map<String, dynamic> json) {
    // Try different timestamp field names
    final timestampValue = json['timestamp'] ?? json['created_at'] ?? json['createdAt'];
    
    if (timestampValue == null) {
      print('⚠️ No timestamp found in JSON, using current time');
      return DateTime.now().toUtc();
    }
    
    if (timestampValue is String) {
      try {
        // Parse and ensure UTC to preserve original date/time
        final parsed = DateTime.parse(timestampValue);
        final utc = parsed.toUtc();
        print('🕐 DEBUG: Parsed timestamp "$timestampValue" -> $utc (UTC)');
        return utc;
      } catch (e) {
        print('⚠️ Failed to parse timestamp "$timestampValue": $e');
        return DateTime.now().toUtc();
      }
    }
    
    if (timestampValue is int) {
      // Handle Unix timestamp (seconds)
      final parsed = DateTime.fromMillisecondsSinceEpoch(timestampValue * 1000);
      final utc = parsed.toUtc();
      print('🕐 DEBUG: Parsed Unix timestamp $timestampValue -> $utc (UTC)');
      return utc;
    }
    
    print('⚠️ Unknown timestamp format: $timestampValue (${timestampValue.runtimeType})');
    return DateTime.now().toUtc();
  }
}

class McpEdge {
  final String id; // ULID/UUID
  final String type; // e.g., "contains", "references"
  final String source; // source node id
  final String target; // target node id
  final String relation;
  final DateTime timestamp;
  final String schemaVersion;
  final double? weight;
  final Map<String, dynamic> data;

  const McpEdge({
    required this.id,
    required this.type,
    required this.source,
    required this.target,
    required this.relation,
    required this.timestamp,
    this.schemaVersion = 'edge.v1',
    this.weight,
    required this.data,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'type': type,
      'source': source,
      'target': target,
      'relation': relation,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'schema_version': schemaVersion,
      'data': data,
    };
    if (weight != null) json['weight'] = weight;
    return json;
  }

  factory McpEdge.fromJson(Map<String, dynamic> json) {
    return McpEdge(
      id: json['id'] as String,
      type: json['type'] as String,
      source: json['source'] as String,
      target: json['target'] as String,
      relation: json['relation'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      schemaVersion: json['schema_version'] as String? ?? 'edge.v1',
      weight: (json['weight'] as num?)?.toDouble(),
      data: Map<String, dynamic>.from(json['data'] ?? {}),
    );
  }
}

class McpPointer {
  final String id; // ULID/UUID
  final String mediaType; // MIME type, e.g., "image/jpeg"
  final String? sourceUri; // ph://, file://, mcp://
  final List<String> altUris;
  final McpDescriptor descriptor;
  final McpSamplingManifest samplingManifest;
  final McpIntegrity integrity;
  final McpProvenance provenance;
  final McpPrivacy privacy;
  final List<String> labels;
  final String schemaVersion;

  const McpPointer({
    required this.id,
    required this.mediaType,
    this.sourceUri,
    this.altUris = const [],
    required this.descriptor,
    required this.samplingManifest,
    required this.integrity,
    required this.provenance,
    required this.privacy,
    this.labels = const [],
    this.schemaVersion = 'pointer.v1',
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'media_type': mediaType,
      'alt_uris': altUris,
      'descriptor': descriptor.toJson(),
      'sampling_manifest': samplingManifest.toJson(),
      'integrity': integrity.toJson(),
      'provenance': provenance.toJson(),
      'privacy': privacy.toJson(),
      'labels': labels,
      'schema_version': schemaVersion,
    };
    if (sourceUri != null) json['source_uri'] = sourceUri;
    return json;
  }

  factory McpPointer.fromJson(Map<String, dynamic> json) {
    return McpPointer(
      id: json['id'] as String,
      mediaType: json['media_type'] as String,
      sourceUri: json['source_uri'] as String?,
      altUris: List<String>.from(json['alt_uris'] ?? []),
      descriptor: McpDescriptor.fromJson(json['descriptor'] as Map<String, dynamic>),
      samplingManifest: McpSamplingManifest.fromJson(json['sampling_manifest'] as Map<String, dynamic>),
      integrity: McpIntegrity.fromJson(json['integrity'] as Map<String, dynamic>),
      provenance: McpProvenance.fromJson(json['provenance'] as Map<String, dynamic>),
      privacy: McpPrivacy.fromJson(json['privacy'] as Map<String, dynamic>),
      labels: List<String>.from(json['labels'] ?? []),
      schemaVersion: json['schema_version'] as String? ?? 'pointer.v1',
    );
  }
}

/// Pointer descriptor information
class McpDescriptor {
  final String? language;
  final int? length;
  final String? mimeType;
  final Map<String, dynamic> metadata;

  const McpDescriptor({
    this.language,
    this.length,
    this.mimeType,
    this.metadata = const {},
  });

  /// Returns true if the descriptor has meaningful content
  bool? get isNotEmpty {
    return language != null ||
           length != null ||
           mimeType != null ||
           metadata.isNotEmpty;
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'metadata': metadata,
    };
    if (language != null) json['language'] = language;
    if (length != null) json['length'] = length;
    if (mimeType != null) json['mime_type'] = mimeType;
    return json;
  }

  factory McpDescriptor.fromJson(Map<String, dynamic> json) {
    return McpDescriptor(
      language: json['language'] as String?,
      length: json['length'] as int?,
      mimeType: json['mime_type'] as String?,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
}

class McpCounts {
  final int nodes;
  final int edges;
  final int pointers;
  final int embeddings;

  const McpCounts({
    required this.nodes,
    required this.edges,
    required this.pointers,
    this.embeddings = 0,
  });

  McpCounts operator +(McpCounts other) => McpCounts(
    nodes: nodes + other.nodes,
    edges: edges + other.edges,
    pointers: pointers + other.pointers,
    embeddings: embeddings + other.embeddings,
  );

  @override
  String toString() =>
      'McpCounts(nodes: $nodes, edges: $edges, pointers: $pointers, embeddings: $embeddings)';
}

/// SAGE narrative structure for Node content
class McpNarrative {
  final String? situation;
  final String? action;
  final String? growth;
  final String? essence;

  const McpNarrative({
    this.situation,
    this.action,
    this.growth,
    this.essence,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (situation != null) json['situation'] = situation;
    if (action != null) json['action'] = action;
    if (growth != null) json['growth'] = growth;
    if (essence != null) json['essence'] = essence;
    return json;
  }

  factory McpNarrative.fromJson(Map<String, dynamic> json) {
    return McpNarrative(
      situation: json['situation'] as String?,
      action: json['action'] as String?,
      growth: json['growth'] as String?,
      essence: json['essence'] as String?,
    );
  }
}

/// Provenance information
class McpProvenance {
  final String source;
  final String? device;
  final String? app;
  final String? importMethod;
  final String? userId;

  const McpProvenance({
    required this.source,
    this.device,
    this.app,
    this.importMethod,
    this.userId,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'source': source,
    };
    if (device != null) json['device'] = device;
    if (app != null) json['app'] = app;
    if (importMethod != null) json['import_method'] = importMethod;
    if (userId != null) json['user_id'] = userId;
    return json;
  }

  factory McpProvenance.fromJson(Map<String, dynamic> json) {
    return McpProvenance(
      source: json['source'] as String,
      device: json['device'] as String?,
      app: json['app'] as String?,
      importMethod: json['import_method'] as String?,
      userId: json['user_id'] as String?,
    );
  }
}

/// Storage profile options
enum McpStorageProfile {
  minimal('minimal'),
  spaceSaver('space_saver'),
  balanced('balanced'),
  hiFidelity('hi_fidelity');

  const McpStorageProfile(this.value);
  final String value;
}

/// MCP export scope options
enum McpExportScope {
  last30Days('last-30-days'),
  last90Days('last-90-days'),
  lastYear('last-year'),
  all('all'),
  custom('custom');

  const McpExportScope(this.value);
  final String value;
}

/// Text span information
class McpSpan {
  final int start;
  final int end;
  final String? type;
  final Map<String, dynamic> metadata;

  const McpSpan({
    required this.start,
    required this.end,
    this.type,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'start': start,
      'end': end,
      'metadata': metadata,
    };
    if (type != null) json['type'] = type;
    return json;
  }

  factory McpSpan.fromJson(Map<String, dynamic> json) {
    return McpSpan(
      start: json['start'] as int,
      end: json['end'] as int,
      type: json['type'] as String?,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
}

/// Video keyframe information
class McpKeyframe {
  final double timestamp;
  final String? description;
  final Map<String, dynamic> metadata;

  const McpKeyframe({
    required this.timestamp,
    this.description,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'timestamp': timestamp,
      'metadata': metadata,
    };
    if (description != null) json['description'] = description;
    return json;
  }

  factory McpKeyframe.fromJson(Map<String, dynamic> json) {
    return McpKeyframe(
      timestamp: (json['timestamp'] as num).toDouble(),
      description: json['description'] as String?,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
}

/// Sampling manifest for derivative content
class McpSamplingManifest {
  final List<McpSpan> spans;
  final List<McpKeyframe> keyframes;
  final Map<String, dynamic> metadata;

  const McpSamplingManifest({
    this.spans = const [],
    this.keyframes = const [],
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'spans': spans.map((s) => s.toJson()).toList(),
      'keyframes': keyframes.map((k) => k.toJson()).toList(),
      'metadata': metadata,
    };
  }

  factory McpSamplingManifest.fromJson(Map<String, dynamic> json) {
    return McpSamplingManifest(
      spans: (json['spans'] as List<dynamic>?)
              ?.map((s) => McpSpan.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      keyframes: (json['keyframes'] as List<dynamic>?)
              ?.map((k) => McpKeyframe.fromJson(k as Map<String, dynamic>))
              .toList() ??
          [],
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
}

/// Integrity information for content verification
class McpIntegrity {
  final String contentHash;
  final int bytes;
  final String? mime;
  final DateTime createdAt;

  const McpIntegrity({
    required this.contentHash,
    required this.bytes,
    this.mime,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'content_hash': contentHash,
      'bytes': bytes,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
    if (mime != null) json['mime'] = mime;
    return json;
  }

  factory McpIntegrity.fromJson(Map<String, dynamic> json) {
    return McpIntegrity(
      contentHash: json['content_hash'] as String,
      bytes: json['bytes'] as int,
      mime: json['mime'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Privacy information for content
class McpPrivacy {
  final bool containsPii;
  final bool facesDetected;
  final String? locationPrecision;
  final String sharingPolicy;

  const McpPrivacy({
    this.containsPii = false,
    this.facesDetected = false,
    this.locationPrecision,
    this.sharingPolicy = 'private',
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'contains_pii': containsPii,
      'faces_detected': facesDetected,
      'sharing_policy': sharingPolicy,
    };
    if (locationPrecision != null) {
      json['location_precision'] = locationPrecision;
    }
    return json;
  }

  factory McpPrivacy.fromJson(Map<String, dynamic> json) {
    return McpPrivacy(
      containsPii: json['contains_pii'] as bool? ?? false,
      facesDetected: json['faces_detected'] as bool? ?? false,
      locationPrecision: json['location_precision'] as String?,
      sharingPolicy: json['sharing_policy'] as String? ?? 'private',
    );
  }
}

/// MCP Embedding v1 Schema
class McpEmbedding {
  final String id;
  final String pointerRef;
  final String? spanRef;
  final String? docScope;
  final List<double> vector;
  final String modelId;
  final String embeddingVersion;
  final int dim;
  final String schemaVersion;

  const McpEmbedding({
    required this.id,
    required this.pointerRef,
    this.spanRef,
    this.docScope,
    required this.vector,
    required this.modelId,
    required this.embeddingVersion,
    required this.dim,
    this.schemaVersion = 'embedding.v1',
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'pointer_ref': pointerRef,
      'vector': vector,
      'model_id': modelId,
      'embedding_version': embeddingVersion,
      'dim': dim,
      'schema_version': schemaVersion,
    };
    if (spanRef != null) json['span_ref'] = spanRef;
    if (docScope != null) json['doc_scope'] = docScope;
    return json;
  }

  factory McpEmbedding.fromJson(Map<String, dynamic> json) {
    return McpEmbedding(
      id: json['id'] as String,
      pointerRef: json['pointer_ref'] as String,
      spanRef: json['span_ref'] as String?,
      docScope: json['doc_scope'] as String?,
      vector: List<double>.from(json['vector'] as List<dynamic>),
      modelId: json['model_id'] as String,
      embeddingVersion: json['embedding_version'] as String,
      dim: json['dim'] as int,
      schemaVersion: json['schema_version'] as String? ?? 'embedding.v1',
    );
  }
}

/// Encoder registry entry
class McpEncoderRegistry {
  final String modelId;
  final String embeddingVersion;
  final int dim;

  const McpEncoderRegistry({
    required this.modelId,
    required this.embeddingVersion,
    required this.dim,
  });

  Map<String, dynamic> toJson() {
    return {
      'model_id': modelId,
      'embedding_version': embeddingVersion,
      'dim': dim,
    };
  }

  factory McpEncoderRegistry.fromJson(Map<String, dynamic> json) {
    return McpEncoderRegistry(
      modelId: json['model_id'] as String? ?? '',
      embeddingVersion: json['embedding_version'] as String? ?? '',
      dim: json['dim'] as int? ?? 0,
    );
  }
}

/// Checksums for bundle integrity verification
class McpChecksums {
  final String nodesJsonl;
  final String edgesJsonl;
  final String pointersJsonl;
  final String embeddingsJsonl;
  final String? vectorsParquet;

  const McpChecksums({
    required this.nodesJsonl,
    required this.edgesJsonl,
    required this.pointersJsonl,
    required this.embeddingsJsonl,
    this.vectorsParquet,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'nodes_jsonl': nodesJsonl,
      'edges_jsonl': edgesJsonl,
      'pointers_jsonl': pointersJsonl,
      'embeddings_jsonl': embeddingsJsonl,
    };
    if (vectorsParquet != null) json['vectors_parquet'] = vectorsParquet;
    return json;
  }

  factory McpChecksums.fromJson(Map<String, dynamic> json) {
    return McpChecksums(
      nodesJsonl: json['nodes_jsonl'] as String? ?? '',
      edgesJsonl: json['edges_jsonl'] as String? ?? '',
      pointersJsonl: json['pointers_jsonl'] as String? ?? '',
      embeddingsJsonl: json['embeddings_jsonl'] as String? ?? '',
      vectorsParquet: json['vectors_parquet'] as String?,
    );
  }
}

/// MCP Bundle Manifest
class McpManifest {
  final String bundleId;
  final String version;
  final DateTime createdAt;
  final String storageProfile;
  final McpCounts counts;
  final McpChecksums checksums;
  final List<McpEncoderRegistry> encoderRegistry;
  final List<String> casRemotes;
  final String? notes;
  final String schemaVersion;
  final List<String>? bundles;

  const McpManifest({
    required this.bundleId,
    required this.version,
    required this.createdAt,
    required this.storageProfile,
    required this.counts,
    required this.checksums,
    required this.encoderRegistry,
    required this.casRemotes,
    this.notes,
    this.schemaVersion = '1.0.0',
    this.bundles,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'bundle_id': bundleId,
      'version': version,
      'created_at': createdAt.toUtc().toIso8601String(),
      'storage_profile': storageProfile,
      'counts': {
        'nodes': counts.nodes,
        'edges': counts.edges,
        'pointers': counts.pointers,
        'embeddings': counts.embeddings,
      },
      'checksums': checksums.toJson(),
      'encoder_registry': encoderRegistry.map((e) => e.toJson()).toList(),
      'cas_remotes': casRemotes,
      'schema_version': schemaVersion,
    };
    if (notes != null) json['notes'] = notes;
    if (bundles != null) json['bundles'] = bundles;
    return json;
  }

  factory McpManifest.fromJson(Map<String, dynamic> json) {
    return McpManifest(
      bundleId: json['bundle_id'] as String? ?? '',
      version: json['version'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      storageProfile: json['storage_profile'] as String? ?? 'balanced',
      counts: McpCounts(
        nodes: (json['counts']?['nodes'] as int?) ?? 0,
        edges: (json['counts']?['edges'] as int?) ?? 0,
        pointers: (json['counts']?['pointers'] as int?) ?? 0,
        embeddings: (json['counts']?['embeddings'] as int?) ?? 0,
      ),
      checksums: McpChecksums.fromJson(json['checksums'] as Map<String, dynamic>? ?? {}),
      encoderRegistry: (json['encoder_registry'] as List<dynamic>?)
              ?.map((e) => McpEncoderRegistry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      casRemotes: List<String>.from(json['cas_remotes'] ?? []),
      notes: json['notes'] as String?,
      schemaVersion: json['schema_version'] as String? ?? '1.0.0',
      bundles: json['bundles'] != null ? List<String>.from(json['bundles']) : null,
    );
  }
}

/// ---- Encoding Registry (pluggable encoders; safe default: passthrough) ----
abstract class McpEncoder<T> {
  Map<String, dynamic> encode(T value);
}
