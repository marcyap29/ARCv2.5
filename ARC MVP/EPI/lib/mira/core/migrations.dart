// lib/mira/core/migrations.dart
// MIRA v0.1 to v0.2 Migration System
// Handles backward compatibility and data migration

import 'schema.dart' as v1;
import 'schema_v2.dart';
import '../../lumara/chat/ulid.dart';

/// Migration result
class MigrationResult {
  final bool success;
  final int nodesMigrated;
  final int edgesMigrated;
  final int pointersMigrated;
  final List<String> errors;
  final Map<String, dynamic> report;

  const MigrationResult({
    required this.success,
    required this.nodesMigrated,
    required this.edgesMigrated,
    required this.pointersMigrated,
    required this.errors,
    required this.report,
  });

  Map<String, dynamic> toJson() => {
    'success': success,
    'nodes_migrated': nodesMigrated,
    'edges_migrated': edgesMigrated,
    'pointers_migrated': pointersMigrated,
    'errors': errors,
    'report': report,
  };
}

/// Migration registry
class MigrationRegistry {
  static final Map<String, Map<String, MigrationFunction>> _migrations = {
    '0.1.0': {
      '0.2.0': (data, options) => _migrateV1ToV2(data, options),
    },
  };

  /// Get migration function for version transition
  static MigrationFunction? getMigration(String fromVersion, String toVersion) {
    return _migrations[fromVersion]?[toVersion];
  }

  /// Check if migration is available
  static bool hasMigration(String fromVersion, String toVersion) {
    return _migrations[fromVersion]?[toVersion] != null;
  }

  /// Get all available migrations
  static Map<String, List<String>> getAvailableMigrations() {
    final result = <String, List<String>>{};
    for (final fromVersion in _migrations.keys) {
      result[fromVersion] = _migrations[fromVersion]!.keys.toList();
    }
    return result;
  }
}

/// Migration function signature
typedef MigrationFunction = Future<MigrationResult> Function(
  Map<String, dynamic> data,
  Map<String, dynamic> options,
);

/// Migrate from v0.1 to v0.2
Future<MigrationResult> _migrateV1ToV2(
  Map<String, dynamic> data,
  Map<String, dynamic> options,
) async {
  final errors = <String>[];
  int nodesMigrated = 0;
  int edgesMigrated = 0;
  int pointersMigrated = 0;

  try {
    // Migrate nodes
    final nodes = data['nodes'] as List<dynamic>? ?? [];
    final migratedNodes = <Map<String, dynamic>>[];

    for (final nodeData in nodes) {
      try {
        final node = v1.MiraNode.fromJson(nodeData as Map<String, dynamic>);
        final migratedNode = _migrateNodeV1ToV2(node);
        migratedNodes.add(migratedNode.toJson());
        nodesMigrated++;
      } catch (e) {
        errors.add('Failed to migrate node ${nodeData['id']}: $e');
      }
    }

    // Migrate edges
    final edges = data['edges'] as List<dynamic>? ?? [];
    final migratedEdges = <Map<String, dynamic>>[];

    for (final edgeData in edges) {
      try {
        final edge = v1.MiraEdge.fromJson(edgeData as Map<String, dynamic>);
        final migratedEdge = _migrateEdgeV1ToV2(edge);
        migratedEdges.add(migratedEdge.toJson());
        edgesMigrated++;
      } catch (e) {
        errors.add('Failed to migrate edge ${edgeData['id']}: $e');
      }
    }

    // Migrate pointers (if any)
    final pointers = data['pointers'] as List<dynamic>? ?? [];
    final migratedPointers = <Map<String, dynamic>>[];

    for (final pointerData in pointers) {
      try {
        final migratedPointer = _migratePointerV1ToV2(pointerData as Map<String, dynamic>);
        migratedPointers.add(migratedPointer.toJson());
        pointersMigrated++;
      } catch (e) {
        errors.add('Failed to migrate pointer ${pointerData['id']}: $e');
      }
    }

    final report = {
      'migration_version': '0.1.0->0.2.0',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'nodes_migrated': nodesMigrated,
      'edges_migrated': edgesMigrated,
      'pointers_migrated': pointersMigrated,
      'errors_count': errors.length,
      'migrated_data': {
        'nodes': migratedNodes,
        'edges': migratedEdges,
        'pointers': migratedPointers,
      },
    };

    return MigrationResult(
      success: errors.isEmpty,
      nodesMigrated: nodesMigrated,
      edgesMigrated: edgesMigrated,
      pointersMigrated: pointersMigrated,
      errors: errors,
      report: report,
    );
  } catch (e) {
    errors.add('Migration failed: $e');
    return MigrationResult(
      success: false,
      nodesMigrated: nodesMigrated,
      edgesMigrated: edgesMigrated,
      pointersMigrated: pointersMigrated,
      errors: errors,
      report: {'error': e.toString()},
    );
  }
}

/// Migrate a v0.1 node to v0.2
MiraNodeV2 _migrateNodeV1ToV2(v1.MiraNode node) {
  // Generate new ULID if the old ID is not a valid ULID
  String newId = node.id;
  if (!ULID.isValid(node.id)) {
    newId = ULID.generate();
  }

  // Create provenance for migrated node
  final provenance = Provenance.create(
    source: 'migration',
    operation: 'migrate_node',
    metadata: {
      'original_id': node.id,
      'migration_version': '0.1.0->0.2.0',
    },
  );

  // Extract embedding version from metadata if available
  final embeddingsVer = node.data['embeddings_ver'] as String?;

  // Extract embedding refs from metadata if available
  final embeddingRefs = List<String>.from(node.data['embedding_refs'] ?? []);

  return MiraNodeV2(
    id: newId,
    schemaId: 'mira.node@${MiraVersion.MIRA_VERSION}',
    type: NodeType.values[node.type.index],
    schemaVersion: MiraVersion.SCHEMA_VERSION,
    data: Map<String, dynamic>.from(node.data),
    createdAt: node.createdAt,
    updatedAt: node.updatedAt,
    provenance: provenance,
    embeddingsVer: embeddingsVer,
    embeddingRefs: embeddingRefs,
    metadata: {
      'migrated_from': '0.1.0',
      'original_id': node.id,
    },
  );
}

/// Migrate a v0.1 edge to v0.2
MiraEdgeV2 _migrateEdgeV1ToV2(v1.MiraEdge edge) {
  // Generate new ULID if the old ID is not a valid ULID
  String newId = edge.id;
  if (!ULID.isValid(edge.id)) {
    newId = ULID.generate();
  }

  // Create provenance for migrated edge
  final provenance = Provenance.create(
    source: 'migration',
    operation: 'migrate_edge',
    metadata: {
      'original_id': edge.id,
      'migration_version': '0.1.0->0.2.0',
    },
  );

  return MiraEdgeV2(
    id: newId,
    schemaId: 'mira.edge@${MiraVersion.MIRA_VERSION}',
    src: edge.src,
    dst: edge.dst,
    label: EdgeType.values[edge.label.index],
    schemaVersion: MiraVersion.SCHEMA_VERSION,
    data: Map<String, dynamic>.from(edge.data),
    createdAt: edge.createdAt,
    updatedAt: edge.createdAt, // Use createdAt as updatedAt for migrated edges
    provenance: provenance,
    metadata: {
      'migrated_from': '0.1.0',
      'original_id': edge.id,
    },
  );
}

/// Migrate a v0.1 pointer to v0.2
MiraPointerV2 _migratePointerV1ToV2(Map<String, dynamic> pointerData) {
  // Generate new ULID if the old ID is not a valid ULID
  String newId = pointerData['id'] as String;
  if (!ULID.isValid(newId)) {
    newId = ULID.generate();
  }

  // Create provenance for migrated pointer
  final provenance = Provenance.create(
    source: 'migration',
    operation: 'migrate_pointer',
    metadata: {
      'original_id': pointerData['id'],
      'migration_version': '0.1.0->0.2.0',
    },
  );

  // Extract basic pointer information
  final kind = pointerData['kind'] as String? ?? 'unknown';
  final ref = pointerData['ref'] as String? ?? '';
  final descriptor = Map<String, dynamic>.from(pointerData['descriptor'] ?? {});
  final integrity = Map<String, dynamic>.from(pointerData['integrity'] ?? {});
  final privacy = Map<String, dynamic>.from(pointerData['privacy'] ?? {});

  // Extract additional v0.2 fields
  final sha256 = pointerData['sha256'] as String?;
  final bytes = pointerData['bytes'] as int?;
  final mimeType = pointerData['mime_type'] as String?;
  final embeddingRefs = List<String>.from(pointerData['embedding_refs'] ?? []);

  final createdAt = pointerData['created_at'] != null
      ? DateTime.parse(pointerData['created_at'] as String)
      : DateTime.now().toUtc();

  return MiraPointerV2(
    id: newId,
    schemaId: 'mira.pointer@${MiraVersion.MIRA_VERSION}',
    kind: kind,
    ref: ref,
    schemaVersion: MiraVersion.SCHEMA_VERSION,
    descriptor: descriptor,
    integrity: integrity,
    privacy: privacy,
    createdAt: createdAt,
    updatedAt: createdAt,
    provenance: provenance,
    sha256: sha256,
    bytes: bytes,
    mimeType: mimeType,
    embeddingRefs: embeddingRefs,
    metadata: {
      'migrated_from': '0.1.0',
      'original_id': pointerData['id'],
    },
  );
}

/// Migration service for handling v0.1 to v0.2 transitions
class MigrationService {
  /// Check if data needs migration
  static bool needsMigration(Map<String, dynamic> data) {
    final schemaVersion = data['schema_version'] as int? ?? 1;
    return schemaVersion < MiraVersion.SCHEMA_VERSION;
  }

  /// Detect version from data
  static String detectVersion(Map<String, dynamic> data) {
    final schemaVersion = data['schema_version'] as int? ?? 1;
    if (schemaVersion == 1) return '0.1.0';
    if (schemaVersion == 2) return '0.2.0';
    return 'unknown';
  }

  /// Run migration if needed
  static Future<MigrationResult?> migrateIfNeeded(
    Map<String, dynamic> data,
    Map<String, dynamic> options,
  ) async {
    if (!needsMigration(data)) {
      return null; // No migration needed
    }

    final fromVersion = detectVersion(data);
    final toVersion = '0.2.0';

    final migration = MigrationRegistry.getMigration(fromVersion, toVersion);
    if (migration == null) {
      throw Exception('No migration available from $fromVersion to $toVersion');
    }

    return await migration(data, options);
  }

  /// Get migration report
  static Map<String, dynamic> getMigrationReport(MigrationResult result) {
    return {
      'migration_successful': result.success,
      'migration_timestamp': DateTime.now().toUtc().toIso8601String(),
      'nodes_migrated': result.nodesMigrated,
      'edges_migrated': result.edgesMigrated,
      'pointers_migrated': result.pointersMigrated,
      'errors_count': result.errors.length,
      'errors': result.errors,
      'report': result.report,
    };
  }
}
