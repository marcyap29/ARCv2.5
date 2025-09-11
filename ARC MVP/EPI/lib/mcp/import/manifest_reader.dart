import 'dart:io';
import 'dart:convert';
import 'package:my_app/mcp/models/mcp_schemas.dart';

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
    final manifestFile = File('${bundleDir.path}/manifest.json');
    
    if (!manifestFile.existsSync()) {
      throw ManifestReadException('Manifest file not found: ${manifestFile.path}');
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
        schemaVersion: json['schema_version'] as String? ?? '',
        version: json['version'] as String? ?? '',
        createdAt: _parseDateTime(json['created_at']),
        counts: _parseCounts(json['counts']),
        checksums: _parseChecksums(json['checksums']),
        encoderRegistry: _parseEncoderRegistry(json['encoder_registry']),
        casRemotes: _parseCasRemotes(json['cas_remotes']),
        storageProfile: json['storage_profile'] as String?,
        notes: json['notes'] as String?,
        bundles: _parseBundles(json['bundles']),
      );
    } catch (e) {
      throw ManifestReadException('Failed to parse manifest JSON', e);
    }
  }

  /// Validate that required fields are present
  void _validateRequiredFields(Map<String, dynamic> json) {
    final requiredFields = ['schema_version', 'version', 'created_at'];
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
  Map<String, int>? _parseCounts(dynamic value) {
    if (value == null) return null;
    
    if (value is Map<String, dynamic>) {
      final counts = <String, int>{};
      for (final entry in value.entries) {
        if (entry.value is int) {
          counts[entry.key] = entry.value as int;
        } else {
          throw ManifestReadException('Count values must be integers, got ${entry.value.runtimeType} for ${entry.key}');
        }
      }
      return counts;
    }
    
    throw ManifestReadException('Counts must be an object, got: ${value.runtimeType}');
  }

  /// Parse checksums object
  Map<String, String>? _parseChecksums(dynamic value) {
    if (value == null) return null;
    
    if (value is Map<String, dynamic>) {
      final checksums = <String, String>{};
      for (final entry in value.entries) {
        if (entry.value is String) {
          checksums[entry.key] = entry.value as String;
        } else {
          throw ManifestReadException('Checksum values must be strings, got ${entry.value.runtimeType} for ${entry.key}');
        }
      }
      return checksums;
    }
    
    throw ManifestReadException('Checksums must be an object, got: ${value.runtimeType}');
  }

  /// Parse encoder registry array
  List<Map<String, dynamic>>? _parseEncoderRegistry(dynamic value) {
    if (value == null) return null;
    
    if (value is List) {
      final registry = <Map<String, dynamic>>[];
      for (int i = 0; i < value.length; i++) {
        final item = value[i];
        if (item is Map<String, dynamic>) {
          registry.add(item);
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
  List<Map<String, dynamic>>? _parseBundles(dynamic value) {
    if (value == null) return null;
    
    if (value is List) {
      final bundles = <Map<String, dynamic>>[];
      for (int i = 0; i < value.length; i++) {
        final item = value[i];
        if (item is Map<String, dynamic>) {
          bundles.add(item);
        } else {
          throw ManifestReadException('Bundle item $i must be an object, got: ${item.runtimeType}');
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
    if (manifest.createdAt != null && manifest.createdAt!.isAfter(DateTime.now().toUtc())) {
      errors.add('created_at cannot be in the future: ${manifest.createdAt}');
    }
    
    // Validate storage profile if present
    if (manifest.storageProfile != null && !_isValidStorageProfile(manifest.storageProfile!)) {
      errors.add('Invalid storage_profile: ${manifest.storageProfile}');
    }
    
    if (errors.isNotEmpty) {
      throw ManifestReadException('Manifest validation failed: ${errors.join(', ')}');
    }
  }

  /// Check if schema version is valid (e.g., "1.0.0")
  bool _isValidSchemaVersion(String version) {
    final pattern = RegExp(r'^\d+\.\d+\.\d+$');
    return pattern.hasMatch(version);
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
    buffer.writeln('  Created: ${manifest.createdAt?.toIso8601String() ?? 'unknown'}');
    buffer.writeln('  Storage Profile: ${manifest.storageProfile ?? 'not specified'}');
    
    if (manifest.counts != null) {
      buffer.writeln('  Counts:');
      for (final entry in manifest.counts!.entries) {
        buffer.writeln('    ${entry.key}: ${entry.value}');
      }
    }
    
    if (manifest.checksums != null) {
      buffer.writeln('  Checksums: ${manifest.checksums!.length} files');
    }
    
    if (manifest.encoderRegistry != null) {
      buffer.writeln('  Encoder Registry: ${manifest.encoderRegistry!.length} entries');
    }
    
    if (manifest.casRemotes != null) {
      buffer.writeln('  CAS Remotes: ${manifest.casRemotes!.length} configured');
    }
    
    if (manifest.notes != null) {
      buffer.writeln('  Notes: ${manifest.notes}');
    }
    
    return buffer.toString();
  }
}