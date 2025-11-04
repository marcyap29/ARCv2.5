// lib/mcp/bundle_doctor/bundle_doctor.dart
// MCP Bundle Doctor - Validation and Auto-Repair for MCP bundles

import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'mcp_models.dart';

/// UUID generator instance
const _uuid = Uuid();

/// Bundle Doctor - Validates and auto-repairs MCP bundles
///
/// Ensures every MCP bundle is valid, complete, and repairable before
/// committing to MIRA. Follows the principle of "always return a valid bundle"
/// even if partially repaired.
class BundleDoctor {
  /// Repair and validate an MCP bundle
  ///
  /// Rules:
  /// 1. Validate bundle against schema
  /// 2. If missing required fields → auto-generate placeholders
  /// 3. If IDs missing → auto-generate UUIDs
  /// 4. If timestamps missing → fill with current UTC time
  /// 5. If edges reference unknown nodes → drop edge, log warning
  /// 6. Always return a valid bundle, even if partially repaired
  static MCPBundle repair(Map<String, dynamic> input) {
    final repairLog = <String>[];

    // 1. Ensure schemaVersion
    String schemaVersion = input['schemaVersion'] as String? ?? 'mcp-1.0';
    if (input['schemaVersion'] == null) {
      repairLog.add('Added missing schemaVersion: mcp-1.0');
    }

    // 2. Ensure bundleId
    String bundleId = input['bundleId'] as String? ?? 'b-${_uuid.v4()}';
    if (input['bundleId'] == null) {
      repairLog.add('Generated missing bundleId: $bundleId');
    }

    // 3. Process pointers (optional)
    final pointers = (input['pointers'] as List<dynamic>?)
        ?.map<MCPPointer>((p) => _repairPointer(p as Map<String, dynamic>, repairLog))
        .toList() ?? <MCPPointer>[];

    // 4. Process nodes (required)
    final nodesList = input['nodes'] as List<dynamic>? ?? <dynamic>[];
    final nodes = nodesList
        .map<MCPNode>((n) => _repairNode(n as Map<String, dynamic>, repairLog))
        .toList();

    // 5. Process edges and validate references
    final edgesList = input['edges'] as List<dynamic>? ?? <dynamic>[];
    final nodeIds = nodes.map((n) => n.id).toSet();
    final edges = <MCPEdge>[];

    for (final e in edgesList) {
      final edge = _repairEdge(e as Map<String, dynamic>, repairLog);

      // Validate node references
      if (nodeIds.contains(edge.from) && nodeIds.contains(edge.to)) {
        edges.add(edge);
      } else {
        repairLog.add('Dropped edge with invalid references: ${edge.from} -> ${edge.to}');
      }
    }

    final bundle = MCPBundle(
      schemaVersion: schemaVersion,
      bundleId: bundleId,
      pointers: pointers,
      nodes: nodes,
      edges: edges,
      repairLog: repairLog,
    );

    return bundle;
  }

  /// Repair a pointer object
  static MCPPointer _repairPointer(Map<String, dynamic> input, List<String> repairLog) {
    String id = input['id'] as String? ?? 'p-${_uuid.v4()}';
    if (input['id'] == null) {
      repairLog.add('Generated missing pointer ID: $id');
    }

    String kind = input['kind'] as String? ?? 'unknown';
    if (input['kind'] == null) {
      repairLog.add('Added default pointer kind: unknown');
    }

    String ref = input['ref'] as String? ?? 'ref://unknown';
    if (input['ref'] == null) {
      repairLog.add('Added default pointer ref: ref://unknown');
    }

    return MCPPointer(
      id: id,
      kind: kind,
      ref: ref,
      metadata: Map<String, dynamic>.from(input)..removeWhere(
        (key, value) => ['id', 'kind', 'ref'].contains(key),
      ),
    );
  }

  /// Repair a node object
  static MCPNode _repairNode(Map<String, dynamic> input, List<String> repairLog) {
    String id = input['id'] as String? ?? 'n-${_uuid.v4()}';
    if (input['id'] == null) {
      repairLog.add('Generated missing node ID: $id');
    }

    String type = input['type'] as String? ?? 'unknown';
    if (input['type'] == null) {
      repairLog.add('Added default node type: unknown');
    }

    String timestamp = input['timestamp'] as String? ?? DateTime.now().toUtc().toIso8601String();
    if (input['timestamp'] == null) {
      repairLog.add('Added current timestamp to node: $id');
    }

    return MCPNode(
      id: id,
      type: type,
      timestamp: timestamp,
      metadata: Map<String, dynamic>.from(input)..removeWhere(
        (key, value) => ['id', 'type', 'timestamp'].contains(key),
      ),
    );
  }

  /// Repair an edge object
  static MCPEdge _repairEdge(Map<String, dynamic> input, List<String> repairLog) {
    String from = input['from'] as String? ?? 'unknown-source';
    if (input['from'] == null) {
      repairLog.add('Added default edge source: unknown-source');
    }

    String to = input['to'] as String? ?? 'unknown-target';
    if (input['to'] == null) {
      repairLog.add('Added default edge target: unknown-target');
    }

    String type = input['type'] as String? ?? 'unknown';
    if (input['type'] == null) {
      repairLog.add('Added default edge type: unknown');
    }

    return MCPEdge(
      from: from,
      to: to,
      type: type,
      metadata: Map<String, dynamic>.from(input)..removeWhere(
        (key, value) => ['from', 'to', 'type'].contains(key),
      ),
    );
  }

  /// Validate that a bundle conforms to basic structural requirements
  static BundleValidationResult validate(MCPBundle bundle) {
    final errors = <String>[];
    final warnings = <String>[];

    // Check schema version
    if (!bundle.schemaVersion.startsWith('mcp-')) {
      errors.add('Invalid schemaVersion format: ${bundle.schemaVersion}');
    }

    // Check bundle ID format
    if (!bundle.bundleId.startsWith('b-')) {
      warnings.add('Bundle ID should start with "b-": ${bundle.bundleId}');
    }

    // Check node IDs
    final nodeIds = <String>{};
    for (final node in bundle.nodes) {
      if (nodeIds.contains(node.id)) {
        errors.add('Duplicate node ID: ${node.id}');
      }
      nodeIds.add(node.id);

      if (!node.id.startsWith('n-')) {
        warnings.add('Node ID should start with "n-": ${node.id}');
      }

      // Validate timestamp format
      try {
        DateTime.parse(node.timestamp);
      } catch (e) {
        errors.add('Invalid timestamp format in node ${node.id}: ${node.timestamp}');
      }
    }

    // Check edge references
    for (final edge in bundle.edges) {
      if (!nodeIds.contains(edge.from)) {
        errors.add('Edge references unknown source node: ${edge.from}');
      }
      if (!nodeIds.contains(edge.to)) {
        errors.add('Edge references unknown target node: ${edge.to}');
      }
    }

    return BundleValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      repairLog: bundle.repairLog,
    );
  }

  /// Convenience method to repair and validate in one step
  static BundleValidationResult repairAndValidate(Map<String, dynamic> input) {
    final repairedBundle = repair(input);
    return validate(repairedBundle);
  }

  /// Convert bundle to JSON string
  static String toJson(MCPBundle bundle) {
    return jsonEncode(bundle.toJson());
  }

  /// Parse bundle from JSON string with repair
  static MCPBundle fromJson(String jsonString) {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    return repair(data);
  }
}