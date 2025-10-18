// lib/mira/migration/migration_service.dart
// MIRA Migration Service for v0.1 to v0.2 compatibility
// Handles automatic detection, migration, and backward compatibility

import 'dart:convert';
import 'dart:io';
import '../core/schema.dart' as v1;
import '../core/schema_v2.dart';
import '../core/migrations.dart';
import '../../../lumara/chat/ulid.dart';

/// Migration service for handling v0.1 to v0.2 transitions
class MigrationService {
  static const String VERSION_KEY = 'mira_version';
  static const String CURRENT_VERSION = '0.2.0';
  static const String LEGACY_VERSION = '0.1.0';

  /// Check if data needs migration
  static bool needsMigration(Map<String, dynamic> data) {
    final version = _detectVersion(data);
    return version != CURRENT_VERSION;
  }

  /// Detect version from data structure
  static String _detectVersion(Map<String, dynamic> data) {
    // Check for explicit version field
    final explicitVersion = data[VERSION_KEY] as String?;
    if (explicitVersion != null) {
      return explicitVersion;
    }

    // Check schema version
    final schemaVersion = data['schema_version'] as int? ?? 1;
    if (schemaVersion == 1) return LEGACY_VERSION;
    if (schemaVersion == 2) return CURRENT_VERSION;

    // Check for v0.2 specific fields
    if (data.containsKey('provenance') || 
        data.containsKey('schema_id') ||
        data.containsKey('is_tombstoned')) {
      return CURRENT_VERSION;
    }

    // Check for v0.1 specific patterns
    if (data.containsKey('nodes') && data['nodes'] is List) {
      final nodes = data['nodes'] as List;
      if (nodes.isNotEmpty) {
        final firstNode = nodes.first as Map<String, dynamic>;
        if (firstNode.containsKey('provenance')) {
          return CURRENT_VERSION;
        }
        return LEGACY_VERSION;
      }
    }

    return LEGACY_VERSION; // Default to legacy
  }

  /// Migrate data from v0.1 to v0.2
  static Future<MigrationResult> migrateToV2(Map<String, dynamic> data) async {
    final version = _detectVersion(data);
    
    if (version == CURRENT_VERSION) {
      return MigrationResult(
        success: true,
        nodesMigrated: 0,
        edgesMigrated: 0,
        pointersMigrated: 0,
        errors: [],
        report: {'message': 'Data is already at v0.2'},
      );
    }

    if (version == LEGACY_VERSION) {
      return await _migrateV1ToV2(data);
    }

    throw Exception('Unsupported version: $version');
  }

  /// Migrate from v0.1 to v0.2
  static Future<MigrationResult> _migrateV1ToV2(Map<String, dynamic> data) async {
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
          migratedPointers.add(migratedPointer);
          pointersMigrated++;
        } catch (e) {
          errors.add('Failed to migrate pointer ${pointerData['id']}: $e');
        }
      }

      final report = {
        'migration_version': '$LEGACY_VERSION->$CURRENT_VERSION',
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
  static MiraNodeV2 _migrateNodeV1ToV2(v1.MiraNode node) {
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
        'migration_version': '$LEGACY_VERSION->$CURRENT_VERSION',
      },
    );

    // Extract embedding version from metadata if available
    final embeddingsVer = node.data['embeddings_ver'] as String?;

    // Extract embedding refs from metadata if available
    final embeddingRefs = List<String>.from(node.data['embedding_refs'] ?? []);

    return MiraNodeV2(
      id: newId,
      schemaId: 'mira.node@$CURRENT_VERSION',
      type: NodeType.values[node.type.index],
      schemaVersion: 2,
      data: Map<String, dynamic>.from(node.data),
      createdAt: node.createdAt,
      updatedAt: node.updatedAt,
      provenance: provenance,
      embeddingsVer: embeddingsVer,
      embeddingRefs: embeddingRefs,
      metadata: {
        'migrated_from': LEGACY_VERSION,
        'original_id': node.id,
      },
    );
  }

  /// Migrate a v0.1 edge to v0.2
  static MiraEdgeV2 _migrateEdgeV1ToV2(v1.MiraEdge edge) {
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
        'migration_version': '$LEGACY_VERSION->$CURRENT_VERSION',
      },
    );

    return MiraEdgeV2(
      id: newId,
      schemaId: 'mira.edge@$CURRENT_VERSION',
      src: edge.src,
      dst: edge.dst,
      label: EdgeType.values[edge.label.index],
      schemaVersion: 2,
      data: Map<String, dynamic>.from(edge.data),
      createdAt: edge.createdAt,
      updatedAt: edge.createdAt, // Use createdAt as updatedAt for migrated edges
      provenance: provenance,
      metadata: {
        'migrated_from': LEGACY_VERSION,
        'original_id': edge.id,
      },
    );
  }

  /// Migrate a v0.1 pointer to v0.2
  static Map<String, dynamic> _migratePointerV1ToV2(Map<String, dynamic> pointerData) {
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
        'migration_version': '$LEGACY_VERSION->$CURRENT_VERSION',
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

    return {
      'id': newId,
      'schema_id': 'mira.pointer@$CURRENT_VERSION',
      'kind': kind,
      'ref': ref,
      'schema_version': 2,
      'descriptor': descriptor,
      'integrity': integrity,
      'privacy': privacy,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': createdAt.toUtc().toIso8601String(),
      'provenance': provenance.toJson(),
      if (sha256 != null) 'sha256': sha256,
      if (bytes != null) 'bytes': bytes,
      if (mimeType != null) 'mime_type': mimeType,
      'embedding_refs': embeddingRefs,
      'is_tombstoned': false,
      'metadata': {
        'migrated_from': LEGACY_VERSION,
        'original_id': pointerData['id'],
      },
    };
  }

  /// Create migration report
  static Map<String, dynamic> createMigrationReport(MigrationResult result) {
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

  /// Validate migrated data
  static bool validateMigratedData(Map<String, dynamic> data) {
    try {
      // Check that all nodes have required v0.2 fields
      final nodes = data['nodes'] as List<dynamic>? ?? [];
      for (final nodeData in nodes) {
        final node = nodeData as Map<String, dynamic>;
        if (!node.containsKey('provenance') ||
            !node.containsKey('schema_id') ||
            !node.containsKey('is_tombstoned')) {
          return false;
        }
      }

      // Check that all edges have required v0.2 fields
      final edges = data['edges'] as List<dynamic>? ?? [];
      for (final edgeData in edges) {
        final edge = edgeData as Map<String, dynamic>;
        if (!edge.containsKey('provenance') ||
            !edge.containsKey('schema_id') ||
            !edge.containsKey('is_tombstoned')) {
          return false;
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get migration statistics
  static Map<String, dynamic> getMigrationStatistics(Map<String, dynamic> data) {
    final version = _detectVersion(data);
    final nodes = data['nodes'] as List<dynamic>? ?? [];
    final edges = data['edges'] as List<dynamic>? ?? [];
    final pointers = data['pointers'] as List<dynamic>? ?? [];

    return {
      'current_version': version,
      'target_version': CURRENT_VERSION,
      'needs_migration': needsMigration(data),
      'total_nodes': nodes.length,
      'total_edges': edges.length,
      'total_pointers': pointers.length,
      'migration_ready': version == LEGACY_VERSION,
    };
  }
}

/// Backward compatibility reader for v0.1 data
class BackwardCompatibilityReader {
  /// Read v0.1 data with backward compatibility
  static Map<String, dynamic> readWithCompatibility(Map<String, dynamic> data) {
    final version = MigrationService._detectVersion(data);
    
    if (version == MigrationService.CURRENT_VERSION) {
      return data; // Already v0.2
    }

    if (version == MigrationService.LEGACY_VERSION) {
      return _readV1Data(data);
    }

    throw Exception('Unsupported data version: $version');
  }

  /// Read v0.1 data format
  static Map<String, dynamic> _readV1Data(Map<String, dynamic> data) {
    // Convert v0.1 format to a compatible structure
    final compatibleData = Map<String, dynamic>.from(data);
    
    // Add version information
    compatibleData[MigrationService.VERSION_KEY] = MigrationService.LEGACY_VERSION;
    compatibleData['schema_version'] = 1;
    
    // Ensure all nodes have required fields
    final nodes = compatibleData['nodes'] as List<dynamic>? ?? [];
    for (final nodeData in nodes) {
      final node = nodeData as Map<String, dynamic>;
      node['is_tombstoned'] = false;
      node['metadata'] = node['metadata'] ?? {};
    }
    
    // Ensure all edges have required fields
    final edges = compatibleData['edges'] as List<dynamic>? ?? [];
    for (final edgeData in edges) {
      final edge = edgeData as Map<String, dynamic>;
      edge['is_tombstoned'] = false;
      edge['metadata'] = edge['metadata'] ?? {};
    }
    
    return compatibleData;
  }
}

/// Migration manager for handling multiple migration scenarios
class MigrationManager {
  final Map<String, MigrationFunction> _migrations;
  final List<Map<String, dynamic>> _migrationHistory;

  MigrationManager() : 
    _migrations = {},
    _migrationHistory = [];

  /// Register a migration function
  void registerMigration(String fromVersion, String toVersion, MigrationFunction migration) {
    final key = '$fromVersion->$toVersion';
    _migrations[key] = migration;
  }

  /// Run migration if needed
  Future<MigrationResult?> migrateIfNeeded(Map<String, dynamic> data) async {
    final version = MigrationService._detectVersion(data);
    final targetVersion = MigrationService.CURRENT_VERSION;
    
    if (version == targetVersion) {
      return null; // No migration needed
    }

    final migrationKey = '$version->$targetVersion';
    final migration = _migrations[migrationKey];
    
    if (migration == null) {
      throw Exception('No migration available from $version to $targetVersion');
    }

    final result = await migration(data, {});
    _migrationHistory.add({
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'from_version': version,
      'to_version': targetVersion,
      'success': result.success,
      'nodes_migrated': result.nodesMigrated,
      'edges_migrated': result.edgesMigrated,
      'pointers_migrated': result.pointersMigrated,
    });

    return result;
  }

  /// Get migration history
  List<Map<String, dynamic>> getMigrationHistory() {
    return List.unmodifiable(_migrationHistory);
  }

  /// Get available migrations
  List<String> getAvailableMigrations() {
    return _migrations.keys.toList();
  }
}
