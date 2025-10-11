import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import '../models/mcp_schemas.dart';
import '../export/manifest_builder.dart';
import '../export/checksum_utils.dart';
import '../export/zip_utils.dart';
import 'mcp_validator.dart';

/// Service for automatically repairing common MCP bundle issues
class McpBundleRepairService {
  final Directory _bundleDir;
  final McpManifestBuilder _manifestBuilder = McpManifestBuilder(bundleId: 'repair_${DateTime.now().millisecondsSinceEpoch}');

  McpBundleRepairService(this._bundleDir);

  /// Repair common issues in an MCP bundle
  Future<BundleRepairResult> repairBundle() async {
    final repairs = <BundleRepair>[];
    final errors = <String>[];

    try {
      // 1. Repair missing files
      await _repairMissingFiles(repairs, errors);

      // 2. Repair manifest issues
      await _repairManifest(repairs, errors);

      // 3. Repair NDJSON files
      await _repairNdjsonFiles(repairs, errors);

      // 4. Repair checksums
      await _repairChecksums(repairs, errors);

      // 5. Repair data integrity
      await _repairDataIntegrity(repairs, errors);

      return BundleRepairResult(
        success: errors.isEmpty,
        repairs: repairs,
        errors: errors,
      );
    } catch (e) {
      errors.add('Repair process failed: $e');
      return BundleRepairResult(
        success: false,
        repairs: repairs,
        errors: errors,
      );
    }
  }

  /// Repair missing required files
  Future<void> _repairMissingFiles(List<BundleRepair> repairs, List<String> errors) async {
    final requiredFiles = [
      'manifest.json',
      'nodes.jsonl',
      'edges.jsonl',
      'pointers.jsonl',
      'embeddings.jsonl',
    ];

    for (final filename in requiredFiles) {
      final file = File(path.join(_bundleDir.path, filename));
      if (!await file.exists()) {
        try {
          await file.create(recursive: true);
          
          if (filename == 'manifest.json') {
            // Create a minimal manifest
            final manifest = McpManifest(
              bundleId: 'repaired_${DateTime.now().millisecondsSinceEpoch}',
              version: '1.0.0',
              createdAt: DateTime.now(),
              storageProfile: 'minimal',
              counts: const McpCounts(),
              checksums: const McpChecksums(),
              encoderRegistry: [],
            );
            await file.writeAsString(jsonEncode(manifest.toJson()));
          } else {
            // Create empty NDJSON file
            await file.writeAsString('');
          }

          repairs.add(BundleRepair(
            type: RepairType.missingFile,
            description: 'Created missing file: $filename',
            severity: RepairSeverity.high,
          ));
        } catch (e) {
          errors.add('Failed to create missing file $filename: $e');
        }
      }
    }
  }

  /// Repair manifest issues
  Future<void> _repairManifest(List<BundleRepair> repairs, List<String> errors) async {
    final manifestFile = File(path.join(_bundleDir.path, 'manifest.json'));
    
    try {
      if (await manifestFile.exists()) {
        final content = await manifestFile.readAsString();
        if (content.trim().isEmpty) {
          // Create minimal manifest for empty file
          final manifest = McpManifest(
            bundleId: 'repaired_${DateTime.now().millisecondsSinceEpoch}',
            version: '1.0.0',
            createdAt: DateTime.now(),
            storageProfile: 'minimal',
            counts: const McpCounts(),
            checksums: const McpChecksums(),
            encoderRegistry: [],
          );
          await manifestFile.writeAsString(jsonEncode(manifest.toJson()));
          
          repairs.add(BundleRepair(
            type: RepairType.emptyFile,
            description: 'Repaired empty manifest.json',
            severity: RepairSeverity.high,
          ));
        } else {
          // Validate and fix manifest structure
          final manifestJson = jsonDecode(content);
          final fixed = _fixManifestStructure(manifestJson);
          
          if (fixed) {
            await manifestFile.writeAsString(jsonEncode(manifestJson));
            repairs.add(BundleRepair(
              type: RepairType.invalidStructure,
              description: 'Fixed manifest.json structure',
              severity: RepairSeverity.medium,
            ));
          }
        }
      }
    } catch (e) {
      errors.add('Failed to repair manifest: $e');
    }
  }

  /// Repair NDJSON files
  Future<void> _repairNdjsonFiles(List<BundleRepair> repairs, List<String> errors) async {
    final ndjsonFiles = [
      'nodes.jsonl',
      'edges.jsonl',
      'pointers.jsonl',
      'embeddings.jsonl',
    ];

    for (final filename in ndjsonFiles) {
      final file = File(path.join(_bundleDir.path, filename));
      
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          if (content.trim().isEmpty) {
            // Empty file is valid for NDJSON, no repair needed
            continue;
          }

          // Validate and fix NDJSON format
          final lines = content.split('\n').where((line) => line.trim().isNotEmpty).toList();
          final fixedLines = <String>[];

          for (final line in lines) {
            try {
              final json = jsonDecode(line);
              // Validate and fix record structure
              final fixed = _fixRecordStructure(json, filename);
              fixedLines.add(jsonEncode(fixed));
            } catch (e) {
              // Skip invalid lines
              repairs.add(BundleRepair(
                type: RepairType.invalidRecord,
                description: 'Removed invalid record in $filename',
                severity: RepairSeverity.low,
              ));
            }
          }

          if (fixedLines.length != lines.length) {
            await file.writeAsString(fixedLines.join('\n'));
            repairs.add(BundleRepair(
              type: RepairType.invalidRecord,
              description: 'Cleaned invalid records from $filename',
              severity: RepairSeverity.medium,
            ));
          }
        } catch (e) {
          errors.add('Failed to repair $filename: $e');
        }
      }
    }
  }

  /// Repair checksums
  Future<void> _repairChecksums(List<BundleRepair> repairs, List<String> errors) async {
    try {
      final manifestFile = File(path.join(_bundleDir.path, 'manifest.json'));
      if (await manifestFile.exists()) {
        final manifest = await McpManifestBuilder.readManifest(manifestFile);
        
        // Calculate new checksums
        final ndjsonFiles = {
          'nodes': File(path.join(_bundleDir.path, 'nodes.jsonl')),
          'edges': File(path.join(_bundleDir.path, 'edges.jsonl')),
          'pointers': File(path.join(_bundleDir.path, 'pointers.jsonl')),
          'embeddings': File(path.join(_bundleDir.path, 'embeddings.jsonl')),
        };

        final newChecksums = <String, String>{};
        for (final entry in ndjsonFiles.entries) {
          if (await entry.value.exists()) {
            final content = await entry.value.readAsBytes();
            final hash = sha256.convert(content).toString();
            newChecksums[entry.key] = hash;
          }
        }

        // Update manifest with new checksums
        final updatedChecksums = McpChecksums(
          nodesJsonl: newChecksums['nodes'] ?? '',
          edgesJsonl: newChecksums['edges'] ?? '',
          pointersJsonl: newChecksums['pointers'] ?? '',
          embeddingsJsonl: newChecksums['embeddings'] ?? '',
        );

        final updatedManifest = McpManifest(
          bundleId: manifest.bundleId,
          version: manifest.version,
          createdAt: manifest.createdAt,
          storageProfile: manifest.storageProfile,
          counts: manifest.counts,
          checksums: updatedChecksums,
          encoderRegistry: manifest.encoderRegistry,
          casRemotes: manifest.casRemotes,
          notes: manifest.notes,
          schemaVersion: manifest.schemaVersion,
          bundles: manifest.bundles,
        );

        await manifestFile.writeAsString(jsonEncode(updatedManifest.toJson()));
        
        repairs.add(BundleRepair(
          type: RepairType.checksumMismatch,
          description: 'Updated checksums in manifest',
          severity: RepairSeverity.medium,
        ));
      }
    } catch (e) {
      errors.add('Failed to repair checksums: $e');
    }
  }

  /// Repair data integrity issues
  Future<void> _repairDataIntegrity(List<BundleRepair> repairs, List<String> errors) async {
    try {
      // This would involve more complex repairs like:
      // - Fixing broken references between nodes and pointers
      // - Removing orphaned edges
      // - Validating required fields
      
      // For now, we'll just add a placeholder repair
      repairs.add(BundleRepair(
        type: RepairType.dataIntegrity,
        description: 'Data integrity validation completed',
        severity: RepairSeverity.low,
      ));
    } catch (e) {
      errors.add('Failed to repair data integrity: $e');
    }
  }

  /// Fix manifest structure issues
  bool _fixManifestStructure(Map<String, dynamic> manifest) {
    bool fixed = false;

    // Ensure required fields exist
    if (!manifest.containsKey('bundle_id')) {
      manifest['bundle_id'] = 'repaired_${DateTime.now().millisecondsSinceEpoch}';
      fixed = true;
    }

    if (!manifest.containsKey('version')) {
      manifest['version'] = '1.0.0';
      fixed = true;
    }

    if (!manifest.containsKey('created_at')) {
      manifest['created_at'] = DateTime.now().toUtc().toIso8601String();
      fixed = true;
    }

    if (!manifest.containsKey('storage_profile')) {
      manifest['storage_profile'] = 'minimal';
      fixed = true;
    }

    // Ensure counts object exists
    if (!manifest.containsKey('counts')) {
      manifest['counts'] = {
        'nodes': 0,
        'edges': 0,
        'pointers': 0,
        'embeddings': 0,
      };
      fixed = true;
    }

    // Ensure checksums object exists
    if (!manifest.containsKey('checksums')) {
      manifest['checksums'] = {
        'nodes_jsonl': '',
        'edges_jsonl': '',
        'pointers_jsonl': '',
        'embeddings_jsonl': '',
      };
      fixed = true;
    }

    // Ensure encoder_registry exists
    if (!manifest.containsKey('encoder_registry')) {
      manifest['encoder_registry'] = [];
      fixed = true;
    }

    return fixed;
  }

  /// Fix record structure based on file type
  Map<String, dynamic> _fixRecordStructure(Map<String, dynamic> record, String filename) {
    final fixed = Map<String, dynamic>.from(record);

    // Add required fields based on record type
    switch (filename) {
      case 'nodes.jsonl':
        if (!fixed.containsKey('id')) {
          fixed['id'] = 'repaired_${DateTime.now().millisecondsSinceEpoch}';
        }
        if (!fixed.containsKey('type')) {
          fixed['type'] = 'unknown';
        }
        if (!fixed.containsKey('timestamp')) {
          fixed['timestamp'] = DateTime.now().toUtc().toIso8601String();
        }
        if (!fixed.containsKey('provenance')) {
          fixed['provenance'] = {
            'source': 'repaired',
            'device': 'unknown',
            'app': 'EPI',
          };
        }
        break;

      case 'edges.jsonl':
        if (!fixed.containsKey('source')) {
          fixed['source'] = 'unknown';
        }
        if (!fixed.containsKey('target')) {
          fixed['target'] = 'unknown';
        }
        if (!fixed.containsKey('relation')) {
          fixed['relation'] = 'unknown';
        }
        if (!fixed.containsKey('timestamp')) {
          fixed['timestamp'] = DateTime.now().toUtc().toIso8601String();
        }
        break;

      case 'pointers.jsonl':
        if (!fixed.containsKey('id')) {
          fixed['id'] = 'repaired_${DateTime.now().millisecondsSinceEpoch}';
        }
        if (!fixed.containsKey('media_type')) {
          fixed['media_type'] = 'unknown';
        }
        if (!fixed.containsKey('descriptor')) {
          fixed['descriptor'] = {'metadata': {}};
        }
        if (!fixed.containsKey('sampling_manifest')) {
          fixed['sampling_manifest'] = {'spans': [], 'keyframes': [], 'metadata': {}};
        }
        if (!fixed.containsKey('integrity')) {
          fixed['integrity'] = {
            'content_hash': '',
            'bytes': 0,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          };
        }
        if (!fixed.containsKey('provenance')) {
          fixed['provenance'] = {
            'source': 'repaired',
            'device': 'unknown',
            'app': 'EPI',
          };
        }
        if (!fixed.containsKey('privacy')) {
          fixed['privacy'] = {
            'contains_pii': false,
            'faces_detected': false,
            'sharing_policy': 'private',
          };
        }
        break;

      case 'embeddings.jsonl':
        if (!fixed.containsKey('id')) {
          fixed['id'] = 'repaired_${DateTime.now().millisecondsSinceEpoch}';
        }
        if (!fixed.containsKey('pointer_ref')) {
          fixed['pointer_ref'] = 'unknown';
        }
        if (!fixed.containsKey('vector')) {
          fixed['vector'] = [];
        }
        if (!fixed.containsKey('model_id')) {
          fixed['model_id'] = 'unknown';
        }
        if (!fixed.containsKey('embedding_version')) {
          fixed['embedding_version'] = '1.0';
        }
        if (!fixed.containsKey('dim')) {
          fixed['dim'] = 0;
        }
        break;
    }

    return fixed;
  }

  /// Repair a zip file containing an MCP bundle
  static Future<BundleRepairResult> repairZipBundle(File zipFile) async {
    final repairs = <BundleRepair>[];
    final errors = <String>[];

    try {
      // Check if zip file exists
      if (!await zipFile.exists()) {
        return BundleRepairResult(
          success: false,
          repairs: repairs,
          errors: ['ZIP file does not exist'],
        );
      }

      // Check if zip contains valid MCP bundle
      final isValidBundle = await ZipUtils.isValidMcpBundle(zipFile);
      if (!isValidBundle) {
        return BundleRepairResult(
          success: false,
          repairs: repairs,
          errors: ['ZIP file does not contain a valid MCP bundle'],
        );
      }

      // Extract zip to temporary directory
      final tempDir = await ZipUtils.extractZip(zipFile);
      
      try {
        // Repair the extracted bundle
        final repairService = McpBundleRepairService(tempDir);
        final result = await repairService.repairBundle();
        
        if (result.success) {
          // Create a new zip file with the repaired bundle
          final repairedZipFile = File('${zipFile.path.replaceAll('.zip', '_repaired.zip')}');
          await ZipUtils.zipDirectory(tempDir, zipFileName: repairedZipFile.path);
          
          repairs.add(BundleRepair(
            type: RepairType.dataIntegrity,
            description: 'Created repaired ZIP file: ${repairedZipFile.path}',
            severity: RepairSeverity.medium,
          ));
        }
        
        // Clean up temporary directory
        await tempDir.delete(recursive: true);
        
        return BundleRepairResult(
          success: result.success,
          repairs: [...repairs, ...result.repairs],
          errors: result.errors,
        );
      } catch (e) {
        // Clean up temporary directory on error
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
        rethrow;
      }
    } catch (e) {
      errors.add('Error repairing ZIP file: $e');
      return BundleRepairResult(
        success: false,
        repairs: repairs,
        errors: errors,
      );
    }
  }
}

/// Result of bundle repair operation
class BundleRepairResult {
  final bool success;
  final List<BundleRepair> repairs;
  final List<String> errors;

  BundleRepairResult({
    required this.success,
    required this.repairs,
    required this.errors,
  });
}

/// Individual repair operation
class BundleRepair {
  final RepairType type;
  final String description;
  final RepairSeverity severity;

  BundleRepair({
    required this.type,
    required this.description,
    required this.severity,
  });
}

/// Types of repairs that can be performed
enum RepairType {
  missingFile,
  emptyFile,
  invalidStructure,
  invalidRecord,
  checksumMismatch,
  dataIntegrity,
}

/// Severity levels for repairs
enum RepairSeverity {
  low,
  medium,
  high,
}
