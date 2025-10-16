/// MCP (Memory Bundle) v1 Schema Models
/// 
/// This file contains Dart models that serialize to the normative MCP v1 field names
/// for Nodes, Edges, Pointers, Embeddings, and Manifest records.
library;


/// MCP Node v1 Schema
class McpNode {
  final String id;
  final String type;
  final DateTime timestamp;
  final String schemaVersion;
  final String? pointerRef;
  final String? contentSummary;
  final String? phaseHint;
  final List<String> keywords;
  final String? embeddingRef;
  final McpNarrative? narrative;
  final Map<String, double> emotions;
  final McpProvenance provenance;
  
  // Additional properties for compatibility
  final String? label;
  final Map<String, dynamic>? properties;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? privacyLevel;
  final String? phase;
  final String? sourceHash;
  final Map<String, dynamic>? metadata;

  const McpNode({
    required this.id,
    required this.type,
    required this.timestamp,
    this.schemaVersion = 'node.v1',
    this.pointerRef,
    this.contentSummary,
    this.phaseHint,
    this.keywords = const [],
    this.embeddingRef,
    this.narrative,
    this.emotions = const {},
    required this.provenance,
    this.label,
    this.properties,
    this.createdAt,
    this.updatedAt,
    this.privacyLevel,
    this.phase,
    this.sourceHash,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'type': type,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'schema_version': schemaVersion,
      'provenance': provenance.toJson(),
    };

    if (pointerRef != null) json['pointer_ref'] = pointerRef;
    if (contentSummary != null) json['content_summary'] = contentSummary;
    if (phaseHint != null) json['phase_hint'] = phaseHint;
    if (keywords.isNotEmpty) json['keywords'] = keywords;
    if (embeddingRef != null) json['embedding_ref'] = embeddingRef;
    if (narrative != null) json['narrative'] = narrative!.toJson();
    if (emotions.isNotEmpty) json['emotions'] = emotions;
    if (label != null) json['label'] = label;
    if (properties != null) json['properties'] = properties;
    if (createdAt != null) json['created_at'] = createdAt!.toUtc().toIso8601String();
    if (updatedAt != null) json['updated_at'] = updatedAt!.toUtc().toIso8601String();
    if (privacyLevel != null) json['privacy_level'] = privacyLevel;
    if (phase != null) json['phase'] = phase;
    if (sourceHash != null) json['source_hash'] = sourceHash;
    if (metadata != null) json['metadata'] = metadata;

    return json;
  }

  /// Extract keywords from JSON, checking both top-level and content.keywords
  static List<String> _extractKeywordsFromJson(Map<String, dynamic> json) {
    // First try top-level keywords
    if (json.containsKey('keywords')) {
      final keywords = json['keywords'];
      if (keywords is List) {
        return keywords.map((k) => k.toString()).toList();
      }
    }
    
    // Then try content.keywords
    if (json.containsKey('content')) {
      final content = json['content'];
      if (content is Map<String, dynamic> && content.containsKey('keywords')) {
        final contentKeywords = content['keywords'];
        if (contentKeywords is List) {
          return contentKeywords.map((k) => k.toString()).toList();
        }
      }
    }
    
    return [];
  }

  factory McpNode.fromJson(Map<String, dynamic> json) {
    // Capture root-level 'media' field for journal entries (exported by journal_entry_projector.dart)
    Map<String, dynamic>? enhancedMetadata = json['metadata'] != null 
        ? Map<String, dynamic>.from(json['metadata']) 
        : <String, dynamic>{};
    
    // If this is a journal entry with root-level media, preserve it in metadata
    if (json['type'] == 'journal_entry' && json.containsKey('media')) {
      enhancedMetadata['media'] = json['media'];
      print('🔍 McpNode: Captured root-level media for journal entry ${json['id']}');
    }
    
    return McpNode(
      id: json['id'] as String,
      type: json['type'] is String ? json['type'] as String : (json['type'] as int).toString(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      schemaVersion: json['schema_version'] as String? ?? 
                    (json['schemaVersion'] is int ? (json['schemaVersion'] as int).toString() : 'node.v1'),
      pointerRef: json['pointer_ref'] as String?,
      contentSummary: json['content_summary'] as String?,
      phaseHint: json['phase_hint'] as String?,
      keywords: _extractKeywordsFromJson(json),
      embeddingRef: json['embedding_ref'] as String?,
      narrative: json['narrative'] != null 
          ? McpNarrative.fromJson(json['narrative'] as Map<String, dynamic>)
          : null,
      emotions: Map<String, double>.from(json['emotions'] ?? {}),
      provenance: json['provenance'] != null
          ? McpProvenance.fromJson(json['provenance'] as Map<String, dynamic>)
          : const McpProvenance(
              source: 'imported',
              device: 'unknown',
              app: 'EPI',
              importMethod: 'mcp_import',
              userId: null,
            ),
      label: json['label'] as String?,
      properties: json['properties'] != null ? Map<String, dynamic>.from(json['properties']) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      privacyLevel: json['privacy_level'] as String?,
      phase: json['phase'] as String?,
      sourceHash: json['source_hash'] as String?,
      metadata: enhancedMetadata.isNotEmpty ? enhancedMetadata : null,
    );
  }
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

/// MCP Edge v1 Schema
class McpEdge {
  final String source;
  final String target;
  final String relation;
  final DateTime timestamp;
  final String schemaVersion;
  final double? weight;
  
  // Additional properties for compatibility
  final String? id;
  final String? type;
  final String? sourceId;
  final String? targetId;
  final Map<String, dynamic>? properties;
  final bool? directed;
  final DateTime? createdAt;
  final String? privacyLevel;
  final String? phase;
  final Map<String, dynamic>? metadata;

  const McpEdge({
    required this.source,
    required this.target,
    required this.relation,
    required this.timestamp,
    this.schemaVersion = 'edge.v1',
    this.weight,
    this.id,
    this.type,
    this.sourceId,
    this.targetId,
    this.properties,
    this.directed,
    this.createdAt,
    this.privacyLevel,
    this.phase,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'source': source,
      'target': target,
      'relation': relation,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'schema_version': schemaVersion,
    };

    if (weight != null) json['weight'] = weight;
    if (id != null) json['id'] = id;
    if (type != null) json['type'] = type;
    if (sourceId != null) json['source_id'] = sourceId;
    if (targetId != null) json['target_id'] = targetId;
    if (properties != null) json['properties'] = properties;
    if (directed != null) json['directed'] = directed;
    if (createdAt != null) json['created_at'] = createdAt!.toUtc().toIso8601String();
    if (privacyLevel != null) json['privacy_level'] = privacyLevel;
    if (phase != null) json['phase'] = phase;
    if (metadata != null) json['metadata'] = metadata;

    return json;
  }

  factory McpEdge.fromJson(Map<String, dynamic> json) {
    return McpEdge(
      source: json['source'] as String,
      target: json['target'] as String,
      relation: json['relation'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      schemaVersion: json['schema_version'] as String? ?? 'edge.v1',
      weight: (json['weight'] as num?)?.toDouble(),
      id: json['id'] as String?,
      type: json['type'] as String?,
      sourceId: json['source_id'] as String?,
      targetId: json['target_id'] as String?,
      properties: json['properties'] != null ? Map<String, dynamic>.from(json['properties']) : null,
      directed: json['directed'] as bool?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      privacyLevel: json['privacy_level'] as String?,
      phase: json['phase'] as String?,
      metadata: json['metadata'] != null ? Map<String, dynamic>.from(json['metadata']) : null,
    );
  }
}

/// MCP Pointer v1 Schema
class McpPointer {
  final String id;
  final String mediaType;
  final String? sourceUri;
  final List<String> altUris;
  final McpDescriptor descriptor;
  final McpSamplingManifest samplingManifest;
  final McpIntegrity integrity;
  final McpProvenance provenance;
  final McpPrivacy privacy;
  final List<String> labels;
  final String schemaVersion;
  
  // Additional properties for compatibility
  final String? storageType;
  final String? contentHash;
  final String? contentEncoding;
  final Map<String, dynamic>? metadata;
  final String? privacyLevel;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final List<String>? casRefs;

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
    this.storageType,
    this.contentHash,
    this.contentEncoding,
    this.metadata,
    this.privacyLevel,
    this.createdAt,
    this.expiresAt,
    this.casRefs,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'media_type': mediaType,
      'source_uri': sourceUri,
      'alt_uris': altUris,
      'descriptor': descriptor.toJson(),
      'sampling_manifest': samplingManifest.toJson(),
      'integrity': integrity.toJson(),
      'provenance': provenance.toJson(),
      'privacy': privacy.toJson(),
      'labels': labels,
      'schema_version': schemaVersion,
    };
    
    if (storageType != null) json['storage_type'] = storageType;
    if (contentHash != null) json['content_hash'] = contentHash;
    if (contentEncoding != null) json['content_encoding'] = contentEncoding;
    if (metadata != null) json['metadata'] = metadata;
    if (privacyLevel != null) json['privacy_level'] = privacyLevel;
    if (createdAt != null) json['created_at'] = createdAt!.toUtc().toIso8601String();
    if (expiresAt != null) json['expires_at'] = expiresAt!.toUtc().toIso8601String();
    if (casRefs != null) json['cas_refs'] = casRefs;

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
      storageType: json['storage_type'] as String?,
      contentHash: json['content_hash'] as String?,
      contentEncoding: json['content_encoding'] as String?,
      metadata: json['metadata'] != null ? Map<String, dynamic>.from(json['metadata']) : null,
      privacyLevel: json['privacy_level'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at'] as String) : null,
      casRefs: json['cas_refs'] != null ? List<String>.from(json['cas_refs']) : null,
    );
  }
}

/// Pointer descriptor information
class McpDescriptor {
  final String? language;
  final int? length;
  final String? mimeType;
  final Map<String, dynamic> metadata;
  
  // Additional properties for compatibility
  final bool? isNotEmpty;

  const McpDescriptor({
    this.language,
    this.length,
    this.mimeType,
    this.metadata = const {},
    this.isNotEmpty,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'metadata': metadata,
    };
    if (language != null) json['language'] = language;
    if (length != null) json['length'] = length;
    if (mimeType != null) json['mime_type'] = mimeType;
    if (isNotEmpty != null) json['isNotEmpty'] = isNotEmpty;
    return json;
  }

  factory McpDescriptor.fromJson(Map<String, dynamic> json) {
    return McpDescriptor(
      language: json['language'] as String?,
      length: json['length'] as int?,
      mimeType: json['mime_type'] as String?,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      isNotEmpty: json['isNotEmpty'] as bool?,
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
          .toList() ?? [],
      keyframes: (json['keyframes'] as List<dynamic>?)
          ?.map((k) => McpKeyframe.fromJson(k as Map<String, dynamic>))
          .toList() ?? [],
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
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
    if (locationPrecision != null) json['location_precision'] = locationPrecision;
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
  
  // Additional properties for compatibility
  final String? model;
  final String? sourceText;
  final int? chunkIndex;
  final int? totalChunks;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;
  final String? sourceHash;
  final String? privacyLevel;

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
    this.model,
    this.sourceText,
    this.chunkIndex,
    this.totalChunks,
    this.metadata,
    this.createdAt,
    this.sourceHash,
    this.privacyLevel,
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
    if (model != null) json['model'] = model;
    if (sourceText != null) json['source_text'] = sourceText;
    if (chunkIndex != null) json['chunk_index'] = chunkIndex;
    if (totalChunks != null) json['total_chunks'] = totalChunks;
    if (metadata != null) json['metadata'] = metadata;
    if (createdAt != null) json['created_at'] = createdAt!.toUtc().toIso8601String();
    if (sourceHash != null) json['source_hash'] = sourceHash;
    if (privacyLevel != null) json['privacy_level'] = privacyLevel;
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
      model: json['model'] as String?,
      sourceText: json['source_text'] as String?,
      chunkIndex: json['chunk_index'] as int?,
      totalChunks: json['total_chunks'] as int?,
      metadata: json['metadata'] != null ? Map<String, dynamic>.from(json['metadata']) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      sourceHash: json['source_hash'] as String?,
      privacyLevel: json['privacy_level'] as String?,
    );
  }
}

/// Provenance information
class McpProvenance {
  final String source;
  final String? device;
  final String? os;
  final String? app;
  final String? importMethod;
  final String? userId;

  const McpProvenance({
    required this.source,
    this.device,
    this.os,
    this.app,
    this.importMethod,
    this.userId,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'source': source,
    };
    if (device != null) json['device'] = device;
    if (os != null) json['os'] = os;
    if (app != null) json['app'] = app;
    if (importMethod != null) json['import_method'] = importMethod;
    if (userId != null) json['user_id'] = userId;
    return json;
  }

  factory McpProvenance.fromJson(Map<String, dynamic> json) {
    return McpProvenance(
      source: json['source'] as String,
      device: json['device'] as String?,
      os: json['os'] as String?,
      app: json['app'] as String?,
      importMethod: json['import_method'] as String?,
      userId: json['user_id'] as String?,
    );
  }
}

/// MCP Manifest v1 Schema
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
    this.casRemotes = const [],
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
      'counts': counts.toJson(),
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
      bundleId: json['bundle_id'] as String,
      version: json['version'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      storageProfile: json['storage_profile'] as String,
      counts: McpCounts.fromJson(json['counts'] as Map<String, dynamic>),
      checksums: McpChecksums.fromJson(json['checksums'] as Map<String, dynamic>),
      encoderRegistry: (json['encoder_registry'] as List<dynamic>)
          .map((e) => McpEncoderRegistry.fromJson(e as Map<String, dynamic>))
          .toList(),
      casRemotes: List<String>.from(json['cas_remotes'] ?? []),
      notes: json['notes'] as String?,
      schemaVersion: json['schema_version'] as String? ?? '1.0.0',
      bundles: json['bundles'] != null ? List<String>.from(json['bundles']) : null,
    );
  }
}

/// Record counts in the bundle
class McpCounts {
  final int nodes;
  final int edges;
  final int pointers;
  final int embeddings;
  
  // Additional properties for compatibility
  final Map<String, int>? entries;

  const McpCounts({
    this.nodes = 0,
    this.edges = 0,
    this.pointers = 0,
    this.embeddings = 0,
    this.entries,
  });

  factory McpCounts.fromMap(Map<String, int> map) {
    return McpCounts(
      nodes: map['nodes'] ?? 0,
      edges: map['edges'] ?? 0,
      pointers: map['pointers'] ?? 0,
      embeddings: map['embeddings'] ?? 0,
      entries: map,
    );
  }

  const McpCounts.single({int nodes = 0, int edges = 0, int pointers = 0, int embeddings = 0})
      : this(nodes: nodes, edges: edges, pointers: pointers, embeddings: embeddings);

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'nodes': nodes,
      'edges': edges,
      'pointers': pointers,
      'embeddings': embeddings,
    };
    if (entries != null) json['entries'] = entries;
    return json;
  }

  factory McpCounts.fromJson(Map<String, dynamic> json) {
    return McpCounts(
      nodes: json['nodes'] as int,
      edges: json['edges'] as int,
      pointers: json['pointers'] as int,
      embeddings: json['embeddings'] as int,
      entries: json['entries'] != null ? Map<String, int>.from(json['entries']) : null,
    );
  }
}

/// File checksums
class McpChecksums {
  final String nodesJsonl;
  final String edgesJsonl;
  final String pointersJsonl;
  final String embeddingsJsonl;
  final String? vectorsParquet;
  
  // Additional properties for compatibility
  final int? length;

  const McpChecksums({
    this.nodesJsonl = '',
    this.edgesJsonl = '',
    this.pointersJsonl = '',
    this.embeddingsJsonl = '',
    this.vectorsParquet,
    this.length,
  });

  factory McpChecksums.fromMap(Map<String, String> map) {
    return McpChecksums(
      nodesJsonl: map['nodesJsonl'] ?? '',
      edgesJsonl: map['edgesJsonl'] ?? '',
      pointersJsonl: map['pointersJsonl'] ?? '',
      embeddingsJsonl: map['embeddingsJsonl'] ?? '',
    );
  }

  const McpChecksums.defaults({
    String nodes = '',
    String edges = '',
    String pointers = '',
    String embeddings = '',
  }) : this(
          nodesJsonl: nodes,
          edgesJsonl: edges,
          pointersJsonl: pointers,
          embeddingsJsonl: embeddings,
        );

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'nodes_jsonl': nodesJsonl,
      'edges_jsonl': edgesJsonl,
      'pointers_jsonl': pointersJsonl,
      'embeddings_jsonl': embeddingsJsonl,
    };
    if (vectorsParquet != null) json['vectors_parquet'] = vectorsParquet;
    if (length != null) json['length'] = length;
    return json;
  }

  factory McpChecksums.fromJson(Map<String, dynamic> json) {
    return McpChecksums(
      nodesJsonl: json['nodes_jsonl'] as String,
      edgesJsonl: json['edges_jsonl'] as String,
      pointersJsonl: json['pointers_jsonl'] as String,
      embeddingsJsonl: json['embeddings_jsonl'] as String,
      vectorsParquet: json['vectors_parquet'] as String?,
      length: json['length'] as int?,
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
      modelId: json['model_id'] as String,
      embeddingVersion: json['embedding_version'] as String,
      dim: json['dim'] as int,
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
