// lib/mcp/bundle_doctor/mcp_models.dart
// MCP Data Models for Bundle Doctor

/// MCP Bundle - Root container for memory export/import
class MCPBundle {
  final String schemaVersion;
  final String bundleId;
  final List<MCPPointer> pointers;
  final List<MCPNode> nodes;
  final List<MCPEdge> edges;
  final List<String> repairLog;

  const MCPBundle({
    required this.schemaVersion,
    required this.bundleId,
    required this.pointers,
    required this.nodes,
    required this.edges,
    this.repairLog = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'bundleId': bundleId,
      'pointers': pointers.map((p) => p.toJson()).toList(),
      'nodes': nodes.map((n) => n.toJson()).toList(),
      'edges': edges.map((e) => e.toJson()).toList(),
      if (repairLog.isNotEmpty) '_repairLog': repairLog,
    };
  }

  factory MCPBundle.fromJson(Map<String, dynamic> json) {
    return MCPBundle(
      schemaVersion: json['schemaVersion'] as String,
      bundleId: json['bundleId'] as String,
      pointers: (json['pointers'] as List<dynamic>? ?? [])
          .map((p) => MCPPointer.fromJson(p as Map<String, dynamic>))
          .toList(),
      nodes: (json['nodes'] as List<dynamic>? ?? [])
          .map((n) => MCPNode.fromJson(n as Map<String, dynamic>))
          .toList(),
      edges: (json['edges'] as List<dynamic>? ?? [])
          .map((e) => MCPEdge.fromJson(e as Map<String, dynamic>))
          .toList(),
      repairLog: (json['_repairLog'] as List<dynamic>? ?? [])
          .map((r) => r.toString())
          .toList(),
    );
  }
}

/// MCP Pointer - Reference to external resources
class MCPPointer {
  final String id;
  final String kind;
  final String ref;
  final Map<String, dynamic> metadata;

  const MCPPointer({
    required this.id,
    required this.kind,
    required this.ref,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kind': kind,
      'ref': ref,
      ...metadata,
    };
  }

  factory MCPPointer.fromJson(Map<String, dynamic> json) {
    final metadata = Map<String, dynamic>.from(json);
    metadata.removeWhere((key, value) => ['id', 'kind', 'ref'].contains(key));

    return MCPPointer(
      id: json['id'] as String,
      kind: json['kind'] as String,
      ref: json['ref'] as String,
      metadata: metadata,
    );
  }
}

/// MCP Node - Memory graph node
class MCPNode {
  final String id;
  final String type;
  final String timestamp;
  final Map<String, dynamic> metadata;

  const MCPNode({
    required this.id,
    required this.type,
    required this.timestamp,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'timestamp': timestamp,
      ...metadata,
    };
  }

  factory MCPNode.fromJson(Map<String, dynamic> json) {
    final metadata = Map<String, dynamic>.from(json);
    metadata.removeWhere((key, value) => ['id', 'type', 'timestamp'].contains(key));

    return MCPNode(
      id: json['id'] as String,
      type: json['type'] as String,
      timestamp: json['timestamp'] as String,
      metadata: metadata,
    );
  }
}

/// MCP Edge - Memory graph relationship
class MCPEdge {
  final String from;
  final String to;
  final String type;
  final Map<String, dynamic> metadata;

  const MCPEdge({
    required this.from,
    required this.to,
    required this.type,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'from': from,
      'to': to,
      'type': type,
      ...metadata,
    };
  }

  factory MCPEdge.fromJson(Map<String, dynamic> json) {
    final metadata = Map<String, dynamic>.from(json);
    metadata.removeWhere((key, value) => ['from', 'to', 'type'].contains(key));

    return MCPEdge(
      from: json['from'] as String,
      to: json['to'] as String,
      type: json['type'] as String,
      metadata: metadata,
    );
  }
}

/// Bundle validation result
class BundleValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final List<String> repairLog;

  const BundleValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
    this.repairLog = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'isValid': isValid,
      'errors': errors,
      'warnings': warnings,
      'repairLog': repairLog,
    };
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Bundle Validation Result:');
    buffer.writeln('  Valid: $isValid');

    if (errors.isNotEmpty) {
      buffer.writeln('  Errors:');
      for (final error in errors) {
        buffer.writeln('    - $error');
      }
    }

    if (warnings.isNotEmpty) {
      buffer.writeln('  Warnings:');
      for (final warning in warnings) {
        buffer.writeln('    - $warning');
      }
    }

    if (repairLog.isNotEmpty) {
      buffer.writeln('  Repairs made:');
      for (final repair in repairLog) {
        buffer.writeln('    - $repair');
      }
    }

    return buffer.toString();
  }
}

/// Common MCP node types
class MCPNodeType {
  static const String entry = 'entry';
  static const String keyword = 'keyword';
  static const String phase = 'phase';
  static const String emotion = 'emotion';
  static const String arcform = 'arcform';
  static const String chat = 'chat';
  static const String reflection = 'reflection';
  static const String unknown = 'unknown';
}

/// Common MCP edge types
class MCPEdgeType {
  static const String mentions = 'mentions';
  static const String phaseHint = 'phase_hint';
  static const String emotionHint = 'emotion_hint';
  static const String contains = 'contains';
  static const String relatesTo = 'relates_to';
  static const String followsFrom = 'follows_from';
  static const String unknown = 'unknown';
}