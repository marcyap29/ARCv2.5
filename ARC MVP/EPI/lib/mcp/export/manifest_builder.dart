/// MCP Manifest Builder
/// 
/// Builds the root manifest.json file with metadata, checksums,
/// and encoder registry information.
library;

import 'dart:io';
import 'dart:convert';
import '../models/mcp_schemas.dart';
import 'checksum_utils.dart';

class McpManifestBuilder {
  final String bundleId;
  final String version;
  final DateTime createdAt;
  final McpStorageProfile storageProfile;
  final String? notes;

  McpManifestBuilder({
    required this.bundleId,
    this.version = '1.0.0',
    DateTime? createdAt,
    this.storageProfile = McpStorageProfile.balanced,
    this.notes,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();

  /// Build manifest from file checksums and counts
  Future<McpManifest> buildManifest({
    required Map<String, File> ndjsonFiles,
    required McpCounts counts,
    required List<McpEncoderRegistry> encoderRegistry,
    List<String> casRemotes = const [],
  }) async {
    // Compute checksums for all NDJSON files
    final checksums = McpChecksums(
      nodesJsonl: McpChecksumUtils.computeFileChecksum(ndjsonFiles['nodes']!),
      edgesJsonl: McpChecksumUtils.computeFileChecksum(ndjsonFiles['edges']!),
      pointersJsonl: McpChecksumUtils.computeFileChecksum(ndjsonFiles['pointers']!),
      embeddingsJsonl: McpChecksumUtils.computeFileChecksum(ndjsonFiles['embeddings']!),
      vectorsParquet: ndjsonFiles['vectors_parquet'] != null
          ? McpChecksumUtils.computeFileChecksum(ndjsonFiles['vectors_parquet']!)
          : null,
    );

    return McpManifest(
      bundleId: bundleId,
      version: version,
      createdAt: createdAt,
      storageProfile: storageProfile.value,
      counts: counts,
      checksums: checksums,
      encoderRegistry: encoderRegistry,
      casRemotes: casRemotes,
      notes: notes,
    );
  }

  /// Write manifest to file
  Future<File> writeManifest(McpManifest manifest, Directory outputDir) async {
    final file = File('${outputDir.path}/manifest.json');
    final json = manifest.toJson();
    final jsonString = const JsonEncoder.withIndent('  ').convert(json);
    await file.writeAsString(jsonString);
    return file;
  }

  /// Build and write complete manifest
  Future<File> buildAndWriteManifest({
    required Directory outputDir,
    required Map<String, File> ndjsonFiles,
    required McpCounts counts,
    required List<McpEncoderRegistry> encoderRegistry,
    List<String> casRemotes = const [],
  }) async {
    final manifest = await buildManifest(
      ndjsonFiles: ndjsonFiles,
      counts: counts,
      encoderRegistry: encoderRegistry,
      casRemotes: casRemotes,
    );
    
    return await writeManifest(manifest, outputDir);
  }

  /// Validate manifest file
  static Future<bool> validateManifest(File manifestFile) async {
    try {
      final content = await manifestFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      
      // Check required fields
      final requiredFields = [
        'bundle_id',
        'version',
        'created_at',
        'storage_profile',
        'counts',
        'checksums',
        'encoder_registry',
        'schema_version',
      ];
      
      for (final field in requiredFields) {
        if (!json.containsKey(field)) {
          return false;
        }
      }
      
      // Validate timestamp format
      try {
        DateTime.parse(json['created_at'] as String);
      } catch (e) {
        return false;
      }
      
      // Validate counts structure
      final counts = json['counts'] as Map<String, dynamic>;
      final countFields = ['nodes', 'edges', 'pointers', 'embeddings'];
      for (final field in countFields) {
        if (!counts.containsKey(field) || counts[field] is! int) {
          return false;
        }
      }
      
      // Validate checksums structure
      final checksums = json['checksums'] as Map<String, dynamic>;
      final checksumFields = ['nodes_jsonl', 'edges_jsonl', 'pointers_jsonl', 'embeddings_jsonl'];
      for (final field in checksumFields) {
        if (!checksums.containsKey(field) || checksums[field] is! String) {
          return false;
        }
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Read and parse manifest file
  static Future<McpManifest> readManifest(File manifestFile) async {
    final content = await manifestFile.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    return McpManifest.fromJson(json);
  }

  /// Verify manifest checksums against actual files
  static Future<bool> verifyChecksums(
    McpManifest manifest,
    Map<String, File> ndjsonFiles,
  ) async {
    try {
      // Verify nodes.jsonl
      if (!McpChecksumUtils.verifyFileChecksum(
          ndjsonFiles['nodes']!, manifest.checksums.nodesJsonl)) {
        return false;
      }
      
      // Verify edges.jsonl
      if (!McpChecksumUtils.verifyFileChecksum(
          ndjsonFiles['edges']!, manifest.checksums.edgesJsonl)) {
        return false;
      }
      
      // Verify pointers.jsonl
      if (!McpChecksumUtils.verifyFileChecksum(
          ndjsonFiles['pointers']!, manifest.checksums.pointersJsonl)) {
        return false;
      }
      
      // Verify embeddings.jsonl
      if (!McpChecksumUtils.verifyFileChecksum(
          ndjsonFiles['embeddings']!, manifest.checksums.embeddingsJsonl)) {
        return false;
      }
      
      // Verify vectors.parquet if present
      if (manifest.checksums.vectorsParquet != null) {
        final vectorsFile = ndjsonFiles['vectors_parquet'];
        if (vectorsFile == null || !McpChecksumUtils.verifyFileChecksum(
            vectorsFile, manifest.checksums.vectorsParquet!)) {
          return false;
        }
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Generate bundle ID from timestamp and random suffix
  static String generateBundleId() {
    final now = DateTime.now().toUtc();
    final timestamp = now.millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'epi_mcp_${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}_$random';
  }

  /// Create encoder registry from embeddings
  static List<McpEncoderRegistry> createEncoderRegistry(List<McpEmbedding> embeddings) {
    final encoders = <String, McpEncoderRegistry>{};
    
    for (final embedding in embeddings) {
      final key = '${embedding.modelId}_${embedding.embeddingVersion}';
      if (!encoders.containsKey(key)) {
        encoders[key] = McpEncoderRegistry(
          modelId: embedding.modelId,
          embeddingVersion: embedding.embeddingVersion,
          dim: embedding.dim,
        );
      }
    }
    
    return encoders.values.toList()
      ..sort((a, b) => a.modelId.compareTo(b.modelId));
  }
}
