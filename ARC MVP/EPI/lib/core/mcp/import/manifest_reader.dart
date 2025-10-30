import 'dart:io';
import 'dart:convert';
import 'package:my_app/core/mcp/models/mcp_schemas.dart';

/// Exception thrown when manifest reading fails
class ManifestReadException implements Exception {
  final String message;
  final dynamic cause;

  const ManifestReadException(this.message, [this.cause]);

  @override
  String toString() => 'ManifestReadException: $message${cause != null ? ' (caused by: $cause)' : ''}';
}

/// Reader for MCP bundle manifests
/// 
/// Handles reading and parsing manifest.json files from MCP bundles,
/// with validation of required fields and proper error handling.
class ManifestReader {
  /// Read and parse manifest.json from the bundle directory
  Future<McpManifest> readManifest(Directory bundleDir) async {
    File? manifestFile;
    final rootCandidate = File('${bundleDir.path}/manifest.json');
    if (rootCandidate.existsSync()) {
      manifestFile = rootCandidate;
    } else {
      // Fallback: search recursively for a file named manifest.json (case-insensitive)
      try {
        await for (final entity in bundleDir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            final name = entity.uri.pathSegments.isNotEmpty
                ? entity.uri.pathSegments.last
                : '';
            if (name.toLowerCase() == 'manifest.json') {
              manifestFile = entity;
              break;
            }
          }
        }
      } catch (e) {
        // Ignore search errors; we will throw below if still null
      }
      if (manifestFile == null) {
        throw ManifestReadException('Manifest file not found anywhere under: ${bundleDir.path}');
      }
    }

    try {
      final content = await manifestFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      
      return _parseManifest(json);
    } on FormatException catch (e) {
      throw ManifestReadException('Invalid JSON in manifest file', e);
    } catch (e) {
      throw ManifestReadException('Failed to read manifest file', e);
    }
  }

  /// Parse manifest JSON into McpManifest object
  McpManifest _parseManifest(Map<String, dynamic> json) {
    try {
      // Validate required fields exist
      _validateRequiredFields(json);
      
      // Parse with explicit field extraction for better error handling
      return McpManifest(
        bundleId: json['bundle_id'] as String? ?? '',
        version: json['version'] as String? ?? '',
        createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
        storageProfile: json['storage_profile'] as String? ?? 'balanced',
        counts: _parseCounts(json['counts']) ?? const McpCounts(nodes: 0, edges: 0, pointers: 0, embeddings: 0),
        checksums: _parseChecksums(json['checksums']) ?? const McpChecksums(nodesJsonl: '', edgesJsonl: '', pointersJsonl: '', embeddingsJsonl: ''),
        encoderRegistry: _parseEncoderRegistry(json['encoder_registry']) ?? [],
        casRemotes: _parseCasRemotes(json['cas_remotes']) ?? [],
        notes: json['notes'] as String?,
        schemaVersion: json['schema_version'] as String? ?? '1.0.0',
        bundles: _parseBundles(json['bundles']),
      );
    } catch (e) {
      throw ManifestReadException('Failed to parse manifest JSON', e);
    }
  }

  /// Validate that required fields are present
  void _validateRequiredFields(Map<String, dynamic> json) {
    // schema_version is optional since we have a fallback default
    final requiredFields = ['version', 'created_at'];
    final missingFields = <String>[];

    for (final field in requiredFields) {
      if (!json.containsKey(field) || json[field] == null) {
        missingFields.add(field);
      }
    }

    if (missingFields.isNotEmpty) {
      throw ManifestReadException('Missing required fields: ${missingFields.join(', ')}');
    }
  }

  /// Parse DateTime from ISO-8601 string, ensuring UTC
  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    
    if (value is String) {
      try {
        final dt = DateTime.parse(value);
        // Ensure UTC timezone
        return dt.isUtc ? dt : dt.toUtc();
      } catch (e) {
        throw ManifestReadException('Invalid datetime format: $value', e);
      }
    }
    
    throw ManifestReadException('DateTime must be a string, got: ${value.runtimeType}');
  }

  /// Parse counts object
  McpCounts? _parseCounts(dynamic value) {
    if (value == null) return null;
    
    if (value is Map<String, dynamic>) {
      return McpCounts(
        nodes: (value['nodes'] as int?) ?? 0,
        edges: (value['edges'] as int?) ?? 0,
        pointers: (value['pointers'] as int?) ?? 0,
        embeddings: (value['embeddings'] as int?) ?? 0,
      );
    }
    
    throw ManifestReadException('Counts must be an object, got: ${value.runtimeType}');
  }

  /// Parse checksums object
  McpChecksums? _parseChecksums(dynamic value) {
    if (value == null) return null;
    
    if (value is Map<String, dynamic>) {
      return McpChecksums(
        nodesJsonl: value['nodes_jsonl'] as String? ?? '',
        edgesJsonl: value['edges_jsonl'] as String? ?? '',
        pointersJsonl: value['pointers_jsonl'] as String? ?? '',
        embeddingsJsonl: value['embeddings_jsonl'] as String? ?? '',
        vectorsParquet: value['vectors_parquet'] as String?,
      );
    }
    
    throw ManifestReadException('Checksums must be an object, got: ${value.runtimeType}');
  }

  /// Parse encoder registry array
  List<McpEncoderRegistry>? _parseEncoderRegistry(dynamic value) {
    if (value == null) return null;
    
    if (value is List) {
      final registry = <McpEncoderRegistry>[];
      for (int i = 0; i < value.length; i++) {
        final item = value[i];
        if (item is Map<String, dynamic>) {
          registry.add(McpEncoderRegistry(
            modelId: item['model_id'] as String? ?? '',
            embeddingVersion: item['embedding_version'] as String? ?? '',
            dim: item['dim'] as int? ?? 0,
          ));
        } else {
          throw ManifestReadException('Encoder registry item $i must be an object, got: ${item.runtimeType}');
        }
      }
      return registry;
    }
    
    throw ManifestReadException('Encoder registry must be an array, got: ${value.runtimeType}');
  }

  /// Parse CAS remotes array
  List<String>? _parseCasRemotes(dynamic value) {
    if (value == null) return null;
    
    if (value is List) {
      final remotes = <String>[];
      for (int i = 0; i < value.length; i++) {
        final item = value[i];
        if (item is String) {
          remotes.add(item);
        } else {
          throw ManifestReadException('CAS remote $i must be a string, got: ${item.runtimeType}');
        }
      }
      return remotes;
    }
    
    throw ManifestReadException('CAS remotes must be an array, got: ${value.runtimeType}');
  }

  /// Parse bundles array (for multi-bundle manifests)
  List<String>? _parseBundles(dynamic value) {
    if (value == null) return null;
    
    if (value is List) {
      final bundles = <String>[];
      for (int i = 0; i < value.length; i++) {
        final item = value[i];
        if (item is String) {
          bundles.add(item);
        } else {
          throw ManifestReadException('Bundle item $i must be a string, got: ${item.runtimeType}');
        }
      }
      return bundles;
    }
    
    throw ManifestReadException('Bundles must be an array, got: ${value.runtimeType}');
  }

  /// Validate manifest structure and content
  void validateManifest(McpManifest manifest) {
    final errors = <String>[];
    
    // Validate schema version format
    if (!_isValidSchemaVersion(manifest.schemaVersion)) {
      errors.add('Invalid schema_version format: ${manifest.schemaVersion}');
    }
    
    // Validate version format (semantic versioning)
    if (!_isValidVersion(manifest.version)) {
      errors.add('Invalid version format: ${manifest.version}');
    }
    
    // Validate created_at is in the past
    if (manifest.createdAt.isAfter(DateTime.now().toUtc())) {
      errors.add('created_at cannot be in the future: ${manifest.createdAt}');
    }
    
    // Validate storage profile if present
    if (!_isValidStorageProfile(manifest.storageProfile)) {
      errors.add('Invalid storage_profile: ${manifest.storageProfile}');
    }
    
    if (errors.isNotEmpty) {
      throw ManifestReadException('Manifest validation failed: ${errors.join(', ')}');
    }
  }

  /// Check if schema version is valid (e.g., "1.0.0" or "manifest.v1")
  bool _isValidSchemaVersion(String version) {
    if (version.isEmpty) return false;

    // Accept semantic versioning format (1.0.0, 1.0, etc.)
    final semanticPattern = RegExp(r'^\d+(\.\d+)*$');
    if (semanticPattern.hasMatch(version)) {
      return true;
    }

    // Accept legacy format (manifest.v1, manifest.v1.0, etc.)
    if (version.startsWith('manifest.v')) {
      return true;
    }

    // Accept simple version formats
    if (version == 'v1' || version == '1') {
      return true;
    }

    return false;
  }

  /// Check if version follows semantic versioning
  bool _isValidVersion(String version) {
    final pattern = RegExp(r'^\d+\.\d+\.\d+(-[a-zA-Z0-9\-\.]+)?(\+[a-zA-Z0-9\-\.]+)?$');
    return pattern.hasMatch(version);
  }

  /// Check if storage profile is valid
  bool _isValidStorageProfile(String profile) {
    const validProfiles = ['minimal', 'space_saver', 'balanced', 'hi_fidelity'];
    return validProfiles.contains(profile);
  }

  /// Get manifest summary for logging/debugging
  String getManifestSummary(McpManifest manifest) {
    final buffer = StringBuffer();
    buffer.writeln('MCP Manifest Summary:');
    buffer.writeln('  Schema Version: ${manifest.schemaVersion}');
    buffer.writeln('  Version: ${manifest.version}');
    buffer.writeln('  Created: ${manifest.createdAt.toIso8601String()}');
    buffer.writeln('  Storage Profile: ${manifest.storageProfile}');
    
    buffer.writeln('  Counts:');
    buffer.writeln('    nodes: ${manifest.counts.nodes}');
    buffer.writeln('    edges: ${manifest.counts.edges}');
    buffer.writeln('    pointers: ${manifest.counts.pointers}');
    buffer.writeln('    embeddings: ${manifest.counts.embeddings}');
    
    buffer.writeln('  Checksums: ${manifest.checksums.nodesJsonl.isNotEmpty ? 'present' : 'missing'}');
    
    buffer.writeln('  Encoder Registry: ${manifest.encoderRegistry.length} entries');
    
    buffer.writeln('  CAS Remotes: ${manifest.casRemotes.length} configured');
    
    if (manifest.notes != null) {
      buffer.writeln('  Notes: ${manifest.notes}');
    }
    
    return buffer.toString();
  }
}