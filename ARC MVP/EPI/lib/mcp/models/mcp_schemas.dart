/// MCP (Memory Bundle) v1 Schema Models
/// 
/// This file contains Dart models that serialize to the normative MCP v1 field names
/// for Nodes, Edges, Pointers, Embeddings, and Manifest records.

import 'dart:convert';

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

    return json;
  }

  factory McpNode.fromJson(Map<String, dynamic> json) {
    return McpNode(
      id: json['id'] as String,
      type: json['type'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      schemaVersion: json['schema_version'] as String? ?? 'node.v1',
      pointerRef: json['pointer_ref'] as String?,
      contentSummary: json['content_summary'] as String?,
      phaseHint: json['phase_hint'] as String?,
      keywords: List<String>.from(json['keywords'] ?? []),
      embeddingRef: json['embedding_ref'] as String?,
      narrative: json['narrative'] != null 
          ? McpNarrative.fromJson(json['narrative'] as Map<String, dynamic>)
          : null,
      emotions: Map<String, double>.from(json['emotions'] ?? {}),
      provenance: McpProvenance.fromJson(json['provenance'] as Map<String, dynamic>),
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

  const McpEdge({
    required this.source,
    required this.target,
    required this.relation,
    required this.timestamp,
    this.schemaVersion = 'edge.v1',
    this.weight,
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
    return {
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
    this.schemaVersion = 'manifest.v1',
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
      schemaVersion: json['schema_version'] as String? ?? 'manifest.v1',
    );
  }
}

/// Record counts in the bundle
class McpCounts {
  final int nodes;
  final int edges;
  final int pointers;
  final int embeddings;

  const McpCounts({
    required this.nodes,
    required this.edges,
    required this.pointers,
    required this.embeddings,
  });

  Map<String, dynamic> toJson() {
    return {
      'nodes': nodes,
      'edges': edges,
      'pointers': pointers,
      'embeddings': embeddings,
    };
  }

  factory McpCounts.fromJson(Map<String, dynamic> json) {
    return McpCounts(
      nodes: json['nodes'] as int,
      edges: json['edges'] as int,
      pointers: json['pointers'] as int,
      embeddings: json['embeddings'] as int,
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
      nodesJsonl: json['nodes_jsonl'] as String,
      edgesJsonl: json['edges_jsonl'] as String,
      pointersJsonl: json['pointers_jsonl'] as String,
      embeddingsJsonl: json['embeddings_jsonl'] as String,
      vectorsParquet: json['vectors_parquet'] as String?,
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
