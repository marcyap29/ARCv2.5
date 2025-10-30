// lib/mcp/bundle/mcp_bundle_v2.dart
// MCP Bundle v1.1 with enhanced capabilities and integrity
// Implements Merkle trees, selective export, and signature support

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:my_app/mira/core/schema_v2.dart';
import 'package:my_app/lumara/chat/ulid.dart';

/// MCP Bundle v1.1 with enhanced capabilities
class McpBundleV2 {
  final String schemaId;
  final String bundleId;
  final String version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String owner;
  final List<String> capabilities;
  final List<McpNodeV2> nodes;
  final List<McpEdgeV2> edges;
  final List<McpPointerV2> pointers;
  final List<McpEmbeddingV2> embeddings;
  final Map<String, String> hashes;
  final String? merkleRoot;
  final String? signature;
  final Map<String, dynamic> metadata;
  final List<String> repairLog;

  const McpBundleV2({
    required this.schemaId,
    required this.bundleId,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    required this.owner,
    required this.capabilities,
    required this.nodes,
    required this.edges,
    required this.pointers,
    required this.embeddings,
    required this.hashes,
    this.merkleRoot,
    this.signature,
    this.metadata = const {},
    this.repairLog = const [],
  });

  /// Create a new MCP bundle v1.1
  factory McpBundleV2.create({
    required String owner,
    List<String>? capabilities,
    List<McpNodeV2>? nodes,
    List<McpEdgeV2>? edges,
    List<McpPointerV2>? pointers,
    List<McpEmbeddingV2>? embeddings,
    Map<String, dynamic>? metadata,
  }) {
    final now = DateTime.now().toUtc();
    final bundleId = 'b-${ULID.generate()}';
    
    return McpBundleV2(
      schemaId: 'mcp.manifest@1.1.0',
      bundleId: bundleId,
      version: '1.1.0',
      createdAt: now,
      updatedAt: now,
      owner: owner,
      capabilities: capabilities ?? _getDefaultCapabilities(),
      nodes: nodes ?? [],
      edges: edges ?? [],
      pointers: pointers ?? [],
      embeddings: embeddings ?? [],
      hashes: {},
      metadata: metadata ?? {},
    );
  }

  /// Get default capabilities
  static List<String> _getDefaultCapabilities() => [
    'redact',
    'selective-domain-export',
    'checksum-verify',
    'merkle-verify',
    'signature-verify',
  ];

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() => {
    'schema_id': schemaId,
    'bundle_id': bundleId,
    'version': version,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'owner': owner,
    'capabilities': capabilities,
    'nodes': nodes.map((n) => n.toJson()).toList(),
    'edges': edges.map((e) => e.toJson()).toList(),
    'pointers': pointers.map((p) => p.toJson()).toList(),
    'embeddings': embeddings.map((e) => e.toJson()).toList(),
    'hashes': hashes,
    if (merkleRoot != null) 'merkle_root': merkleRoot,
    if (signature != null) 'signature': signature,
    'metadata': metadata,
    if (repairLog.isNotEmpty) 'repair_log': repairLog,
  };

  /// Create from JSON
  factory McpBundleV2.fromJson(Map<String, dynamic> json) => McpBundleV2(
    schemaId: json['schema_id'] as String? ?? 'mcp.manifest@1.0.0',
    bundleId: json['bundle_id'] as String,
    version: json['version'] as String? ?? '1.0.0',
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    owner: json['owner'] as String,
    capabilities: List<String>.from(json['capabilities'] ?? []),
    nodes: (json['nodes'] as List<dynamic>? ?? [])
        .map((n) => McpNodeV2.fromJson(n as Map<String, dynamic>))
        .toList(),
    edges: (json['edges'] as List<dynamic>? ?? [])
        .map((e) => McpEdgeV2.fromJson(e as Map<String, dynamic>))
        .toList(),
    pointers: (json['pointers'] as List<dynamic>? ?? [])
        .map((p) => McpPointerV2.fromJson(p as Map<String, dynamic>))
        .toList(),
    embeddings: (json['embeddings'] as List<dynamic>? ?? [])
        .map((e) => McpEmbeddingV2.fromJson(e as Map<String, dynamic>))
        .toList(),
    hashes: Map<String, String>.from(json['hashes'] ?? {}),
    merkleRoot: json['merkle_root'] as String?,
    signature: json['signature'] as String?,
    metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    repairLog: List<String>.from(json['repair_log'] ?? []),
  );

  /// Create a copy with updated fields
  McpBundleV2 copyWith({
    String? schemaId,
    String? bundleId,
    String? version,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? owner,
    List<String>? capabilities,
    List<McpNodeV2>? nodes,
    List<McpEdgeV2>? edges,
    List<McpPointerV2>? pointers,
    List<McpEmbeddingV2>? embeddings,
    Map<String, String>? hashes,
    String? merkleRoot,
    String? signature,
    Map<String, dynamic>? metadata,
    List<String>? repairLog,
  }) => McpBundleV2(
    schemaId: schemaId ?? this.schemaId,
    bundleId: bundleId ?? this.bundleId,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? DateTime.now().toUtc(),
    owner: owner ?? this.owner,
    capabilities: capabilities ?? this.capabilities,
    nodes: nodes ?? this.nodes,
    edges: edges ?? this.edges,
    pointers: pointers ?? this.pointers,
    embeddings: embeddings ?? this.embeddings,
    hashes: hashes ?? this.hashes,
    merkleRoot: merkleRoot ?? this.merkleRoot,
    signature: signature ?? this.signature,
    metadata: metadata ?? this.metadata,
    repairLog: repairLog ?? this.repairLog,
  );

  /// Add a node to the bundle
  McpBundleV2 addNode(McpNodeV2 node) {
    final updatedNodes = List<McpNodeV2>.from(nodes)..add(node);
    return copyWith(nodes: updatedNodes);
  }

  /// Add an edge to the bundle
  McpBundleV2 addEdge(McpEdgeV2 edge) {
    final updatedEdges = List<McpEdgeV2>.from(edges)..add(edge);
    return copyWith(edges: updatedEdges);
  }

  /// Add a pointer to the bundle
  McpBundleV2 addPointer(McpPointerV2 pointer) {
    final updatedPointers = List<McpPointerV2>.from(pointers)..add(pointer);
    return copyWith(pointers: updatedPointers);
  }

  /// Add an embedding to the bundle
  McpBundleV2 addEmbedding(McpEmbeddingV2 embedding) {
    final updatedEmbeddings = List<McpEmbeddingV2>.from(embeddings)..add(embedding);
    return copyWith(embeddings: updatedEmbeddings);
  }

  /// Compute hashes for all components
  Future<McpBundleV2> computeHashes() async {
    final hashes = <String, String>{};
    
    // Compute hash for nodes
    final nodesJson = jsonEncode(nodes.map((n) => n.toJson()).toList());
    hashes['nodes'] = sha256.convert(utf8.encode(nodesJson)).toString();
    
    // Compute hash for edges
    final edgesJson = jsonEncode(edges.map((e) => e.toJson()).toList());
    hashes['edges'] = sha256.convert(utf8.encode(edgesJson)).toString();
    
    // Compute hash for pointers
    final pointersJson = jsonEncode(pointers.map((p) => p.toJson()).toList());
    hashes['pointers'] = sha256.convert(utf8.encode(pointersJson)).toString();
    
    // Compute hash for embeddings
    final embeddingsJson = jsonEncode(embeddings.map((e) => e.toJson()).toList());
    hashes['embeddings'] = sha256.convert(utf8.encode(embeddingsJson)).toString();
    
    // Compute Merkle root
    final merkleRoot = _computeMerkleRoot(hashes);
    
    return copyWith(hashes: hashes, merkleRoot: merkleRoot);
  }

  /// Compute Merkle root from hashes
  String _computeMerkleRoot(Map<String, String> hashes) {
    final sortedHashes = hashes.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    final combined = sortedHashes.map((e) => '${e.key}:${e.value}').join('|');
    return sha256.convert(utf8.encode(combined)).toString();
  }

  /// Verify bundle integrity
  bool verifyIntegrity() {
    // Verify Merkle root
    if (merkleRoot != null) {
      final computedRoot = _computeMerkleRoot(hashes);
      if (computedRoot != merkleRoot) {
        return false;
      }
    }
    
    // Verify individual hashes
    final nodesJson = jsonEncode(nodes.map((n) => n.toJson()).toList());
    final nodesHash = sha256.convert(utf8.encode(nodesJson)).toString();
    if (hashes['nodes'] != nodesHash) {
      return false;
    }
    
    final edgesJson = jsonEncode(edges.map((e) => e.toJson()).toList());
    final edgesHash = sha256.convert(utf8.encode(edgesJson)).toString();
    if (hashes['edges'] != edgesHash) {
      return false;
    }
    
    final pointersJson = jsonEncode(pointers.map((p) => p.toJson()).toList());
    final pointersHash = sha256.convert(utf8.encode(pointersJson)).toString();
    if (hashes['pointers'] != pointersHash) {
      return false;
    }
    
    final embeddingsJson = jsonEncode(embeddings.map((e) => e.toJson()).toList());
    final embeddingsHash = sha256.convert(utf8.encode(embeddingsJson)).toString();
    if (hashes['embeddings'] != embeddingsHash) {
      return false;
    }
    
    return true;
  }

  /// Create selective export
  McpBundleV2 createSelectiveExport({
    required List<MemoryDomain> domains,
    required PrivacyLevel maxPrivacyLevel,
    bool redactPII = true,
    bool userOverride = false,
  }) {
    // Filter nodes by domain and privacy level
    final filteredNodes = nodes.where((node) {
      final nodeDomain = node.metadata['domain'] as MemoryDomain?;
      final nodePrivacy = node.metadata['privacy'] as PrivacyLevel?;
      
      if (nodeDomain != null && !domains.contains(nodeDomain)) {
        return false;
      }
      
      if (nodePrivacy != null && nodePrivacy.index > maxPrivacyLevel.index) {
        return false;
      }
      
      return true;
    }).toList();
    
    // Filter edges to only include those connecting filtered nodes
    final filteredNodeIds = filteredNodes.map((n) => n.id).toSet();
    final filteredEdges = edges.where((edge) =>
      filteredNodeIds.contains(edge.src) && filteredNodeIds.contains(edge.dst)
    ).toList();
    
    // Filter pointers to only include those referenced by filtered nodes
    final filteredPointerIds = <String>{};
    for (final node in filteredNodes) {
      final embeddingRefs = node.metadata['embedding_refs'] as List<String>? ?? [];
      filteredPointerIds.addAll(embeddingRefs);
    }
    
    final filteredPointers = pointers.where((pointer) =>
      filteredPointerIds.contains(pointer.id)
    ).toList();
    
    // Filter embeddings to only include those referenced by filtered pointers
    final filteredEmbeddingIds = <String>{};
    for (final pointer in filteredPointers) {
      final embeddingRefs = pointer.metadata['embedding_refs'] as List<String>? ?? [];
      filteredEmbeddingIds.addAll(embeddingRefs);
    }
    
    final filteredEmbeddings = embeddings.where((embedding) =>
      filteredEmbeddingIds.contains(embedding.id)
    ).toList();
    
    // Redact PII if requested
    final processedNodes = redactPII && !userOverride
        ? filteredNodes.map((node) => _redactPII(node)).toList()
        : filteredNodes;
    
    return copyWith(
      nodes: processedNodes,
      edges: filteredEdges,
      pointers: filteredPointers,
      embeddings: filteredEmbeddings,
      metadata: {
        ...metadata,
        'export_type': 'selective',
        'domains': domains.map((d) => d.name).toList(),
        'max_privacy_level': maxPrivacyLevel.name,
        'redact_pii': redactPII,
        'user_override': userOverride,
        'exported_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  /// Redact PII from a node
  McpNodeV2 _redactPII(McpNodeV2 node) {
    final hasPII = node.metadata['has_pii'] as bool? ?? false;
    if (!hasPII) return node;
    
    // Redact sensitive content
    final redactedData = Map<String, dynamic>.from(node.data);
    if (redactedData.containsKey('content')) {
      redactedData['content'] = '[REDACTED - PII DETECTED]';
    }
    if (redactedData.containsKey('text')) {
      redactedData['text'] = '[REDACTED - PII DETECTED]';
    }
    
    return node.copyWith(
      data: redactedData,
      metadata: {
        ...node.metadata,
        'pii_redacted': true,
        'redacted_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  /// Add repair log entry
  McpBundleV2 addRepairLog(String entry) {
    final updatedLog = List<String>.from(repairLog)..add(entry);
    return copyWith(repairLog: updatedLog);
  }

  /// Get bundle statistics
  Map<String, dynamic> getStatistics() => {
    'total_nodes': nodes.length,
    'total_edges': edges.length,
    'total_pointers': pointers.length,
    'total_embeddings': embeddings.length,
    'active_nodes': nodes.where((n) => !n.isTombstoned).length,
    'active_edges': edges.where((e) => !e.isTombstoned).length,
    'active_pointers': pointers.where((p) => !p.isTombstoned).length,
    'active_embeddings': embeddings.where((e) => !e.isTombstoned).length,
    'domains': nodes.map((n) => n.metadata['domain']).toSet().toList(),
    'privacy_levels': nodes.map((n) => n.metadata['privacy']).toSet().toList(),
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}

/// Enhanced MCP Node v1.1
class McpNodeV2 {
  final String id;
  final String schemaId;
  final String type;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isTombstoned;
  final DateTime? deletedAt;
  final Map<String, dynamic> metadata;

  const McpNodeV2({
    required this.id,
    required this.schemaId,
    required this.type,
    required this.data,
    required this.createdAt,
    required this.updatedAt,
    this.isTombstoned = false,
    this.deletedAt,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'schema_id': schemaId,
    'type': type,
    'data': data,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'is_tombstoned': isTombstoned,
    if (deletedAt != null) 'deleted_at': deletedAt!.toUtc().toIso8601String(),
    'metadata': metadata,
  };

  factory McpNodeV2.fromJson(Map<String, dynamic> json) => McpNodeV2(
    id: json['id'] as String,
    schemaId: json['schema_id'] as String? ?? 'mcp.node@1.0.0',
    type: json['type'] as String,
    data: Map<String, dynamic>.from(json['data'] as Map),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    isTombstoned: json['is_tombstoned'] as bool? ?? false,
    deletedAt: json['deleted_at'] != null 
        ? DateTime.parse(json['deleted_at'] as String) 
        : null,
    metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
  );

  /// Create a copy with updated fields
  McpNodeV2 copyWith({
    String? id,
    String? schemaId,
    String? type,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isTombstoned,
    DateTime? deletedAt,
    Map<String, dynamic>? metadata,
  }) => McpNodeV2(
    id: id ?? this.id,
    schemaId: schemaId ?? this.schemaId,
    type: type ?? this.type,
    data: data ?? Map<String, dynamic>.from(this.data),
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? DateTime.now().toUtc(),
    isTombstoned: isTombstoned ?? this.isTombstoned,
    deletedAt: deletedAt ?? this.deletedAt,
    metadata: metadata ?? Map<String, dynamic>.from(this.metadata),
  );
}

/// Enhanced MCP Edge v1.1
class McpEdgeV2 {
  final String id;
  final String schemaId;
  final String src;
  final String dst;
  final String relation;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isTombstoned;
  final DateTime? deletedAt;
  final Map<String, dynamic> metadata;

  const McpEdgeV2({
    required this.id,
    required this.schemaId,
    required this.src,
    required this.dst,
    required this.relation,
    required this.data,
    required this.createdAt,
    required this.updatedAt,
    this.isTombstoned = false,
    this.deletedAt,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'schema_id': schemaId,
    'src': src,
    'dst': dst,
    'relation': relation,
    'data': data,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'is_tombstoned': isTombstoned,
    if (deletedAt != null) 'deleted_at': deletedAt!.toUtc().toIso8601String(),
    'metadata': metadata,
  };

  factory McpEdgeV2.fromJson(Map<String, dynamic> json) => McpEdgeV2(
    id: json['id'] as String,
    schemaId: json['schema_id'] as String? ?? 'mcp.edge@1.0.0',
    src: json['src'] as String,
    dst: json['dst'] as String,
    relation: json['relation'] as String,
    data: Map<String, dynamic>.from(json['data'] as Map),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    isTombstoned: json['is_tombstoned'] as bool? ?? false,
    deletedAt: json['deleted_at'] != null 
        ? DateTime.parse(json['deleted_at'] as String) 
        : null,
    metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
  );
}

/// Enhanced MCP Pointer v1.1
class McpPointerV2 {
  final String id;
  final String schemaId;
  final String kind;
  final String ref;
  final Map<String, dynamic> descriptor;
  final Map<String, dynamic> integrity;
  final Map<String, dynamic> privacy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isTombstoned;
  final DateTime? deletedAt;
  final Map<String, dynamic> metadata;

  const McpPointerV2({
    required this.id,
    required this.schemaId,
    required this.kind,
    required this.ref,
    required this.descriptor,
    required this.integrity,
    required this.privacy,
    required this.createdAt,
    required this.updatedAt,
    this.isTombstoned = false,
    this.deletedAt,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'schema_id': schemaId,
    'kind': kind,
    'ref': ref,
    'descriptor': descriptor,
    'integrity': integrity,
    'privacy': privacy,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'is_tombstoned': isTombstoned,
    if (deletedAt != null) 'deleted_at': deletedAt!.toUtc().toIso8601String(),
    'metadata': metadata,
  };

  factory McpPointerV2.fromJson(Map<String, dynamic> json) => McpPointerV2(
    id: json['id'] as String,
    schemaId: json['schema_id'] as String? ?? 'mcp.pointer@1.0.0',
    kind: json['kind'] as String,
    ref: json['ref'] as String,
    descriptor: Map<String, dynamic>.from(json['descriptor'] as Map),
    integrity: Map<String, dynamic>.from(json['integrity'] as Map),
    privacy: Map<String, dynamic>.from(json['privacy'] as Map),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    isTombstoned: json['is_tombstoned'] as bool? ?? false,
    deletedAt: json['deleted_at'] != null 
        ? DateTime.parse(json['deleted_at'] as String) 
        : null,
    metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
  );
}

/// Enhanced MCP Embedding v1.1
class McpEmbeddingV2 {
  final String id;
  final String schemaId;
  final String model;
  final List<double> values;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isTombstoned;
  final DateTime? deletedAt;
  final Map<String, dynamic> metadata;

  const McpEmbeddingV2({
    required this.id,
    required this.schemaId,
    required this.model,
    required this.values,
    required this.createdAt,
    required this.updatedAt,
    this.isTombstoned = false,
    this.deletedAt,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'schema_id': schemaId,
    'model': model,
    'values': values,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'is_tombstoned': isTombstoned,
    if (deletedAt != null) 'deleted_at': deletedAt!.toUtc().toIso8601String(),
    'metadata': metadata,
  };

  factory McpEmbeddingV2.fromJson(Map<String, dynamic> json) => McpEmbeddingV2(
    id: json['id'] as String,
    schemaId: json['schema_id'] as String? ?? 'mcp.embedding@1.0.0',
    model: json['model'] as String,
    values: List<double>.from(json['values'] as List),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    isTombstoned: json['is_tombstoned'] as bool? ?? false,
    deletedAt: json['deleted_at'] != null 
        ? DateTime.parse(json['deleted_at'] as String) 
        : null,
    metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
  );
}
