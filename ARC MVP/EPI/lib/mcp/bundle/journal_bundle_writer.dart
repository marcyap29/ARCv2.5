// lib/mcp/bundle/journal_bundle_writer.dart
// MCP-only bundle writer that projects journal entries directly and includes doctor validation

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../../arc/core/journal_repository.dart';
import '../adapters/journal_entry_projector.dart';
import 'doctor.dart';
import 'validate.dart';

class JournalBundleWriter {
  final JournalRepository journalRepo;

  JournalBundleWriter(this.journalRepo);

  /// Export journal entries as MCP bundle with automatic validation and repair
  Future<Directory> exportBundle({
    required Directory outDir,
    required String storageProfile, // minimal|space_saver|balanced|hi_fidelity
    String? notes,
    bool includeEmbeddingPlaceholders = false,
  }) async {
    if (!await outDir.exists()) await outDir.create(recursive: true);

    final nodesFile = File('${outDir.path}/nodes.jsonl');
    final edgesFile = File('${outDir.path}/edges.jsonl');
    final pointersFile = File('${outDir.path}/pointers.jsonl');
    final embeddingsFile = File('${outDir.path}/embeddings.jsonl');
    final manifestFile = File('${outDir.path}/manifest.json');

    // Clear any existing files
    await nodesFile.writeAsString('');
    await edgesFile.writeAsString('');
    await pointersFile.writeAsString('');
    await embeddingsFile.writeAsString('');

    // Create sinks for writing
    final nodesSink = nodesFile.openWrite();
    final edgesSink = edgesFile.openWrite();
    final pointersSink = pointersFile.openWrite();
    final embeddingsSink = includeEmbeddingPlaceholders ? embeddingsFile.openWrite() : null;

    try {
      // PROJECT FIRST: Use the projector to generate MCP records from journal entries
      await McpEntryProjector.emitAll(
        repo: journalRepo,
        nodesSink: nodesSink,
        edgesSink: edgesSink,
        pointersSink: pointersSink,
        embeddingsSink: embeddingsSink,
      );

      await nodesSink.close();
      await edgesSink.close();
      await pointersSink.close();
      if (embeddingsSink != null) await embeddingsSink.close();

      // Calculate file statistics for manifest
      final nodeStats = await _getFileStats(nodesFile);
      final edgeStats = await _getFileStats(edgesFile);
      final pointerStats = await _getFileStats(pointersFile);
      final embeddingStats = await _getFileStats(embeddingsFile);

      // Create manifest
      final manifest = _createManifest(
        storageProfile: storageProfile,
        notes: notes,
        nodeStats: nodeStats,
        edgeStats: edgeStats,
        pointerStats: pointerStats,
        embeddingStats: embeddingStats,
      );

      await manifestFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(manifest)
      );

      // DOCTOR CHECK: Validate and auto-repair if needed
      final doctor = McpBundleDoctor(journalRepo, McpValidatorV1());
      final health = await doctor.checkBundleHealth(outDir);

      if (!health.ok) {
        // Auto-repair if validation fails
        await doctor.repairBundle(outDir, addEmbeddingPlaceholders: includeEmbeddingPlaceholders);
      }

      return outDir;
    } catch (e) {
      // Ensure sinks are closed even on error
      await nodesSink.close();
      await edgesSink.close();
      await pointersSink.close();
      if (embeddingsSink != null) await embeddingsSink.close();
      rethrow;
    }
  }

  /// Create manifest with proper metadata
  Map<String, dynamic> _createManifest({
    required String storageProfile,
    String? notes,
    required FileStats nodeStats,
    required FileStats edgeStats,
    required FileStats pointerStats,
    required FileStats embeddingStats,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();

    return _sortKeys({
      'bundle_id': 'epi_journal_$now',
      'version': '1.0.0',
      'created_at': now,
      'storage_profile': storageProfile,
      'counts': {
        'nodes': nodeStats.lines,
        'edges': edgeStats.lines,
        'pointers': pointerStats.lines,
        'embeddings': embeddingStats.lines,
      },
      'bytes': {
        'nodes_jsonl': nodeStats.bytes,
        'edges_jsonl': edgeStats.bytes,
        'pointers_jsonl': pointerStats.bytes,
        'embeddings_jsonl': embeddingStats.bytes,
      },
      'checksums': {
        'nodes_jsonl': 'sha256:${nodeStats.sha256}',
        'edges_jsonl': 'sha256:${edgeStats.sha256}',
        'pointers_jsonl': 'sha256:${pointerStats.sha256}',
        'embeddings_jsonl': 'sha256:${embeddingStats.sha256}',
      },
      'encoder_registry': [
        {
          'id': 'epi_journal_projector',
          'version': '1.0.0',
          'description': 'EPI Journal Entry to MCP Projector',
          'schema_mappings': {
            'journal_entry': 'node.v1',
            'journal_pointer': 'pointer.v1',
            'journal_relations': 'edge.v1',
          }
        }
      ],
      'cas_remotes': <String>[],
      'notes': notes ?? 'Exported from EPI journal entries using MCP-only pipeline',
      'schema_version': '1.0.0',
    });
  }

  /// Get file statistics for manifest
  static Future<FileStats> _getFileStats(File file) async {
    if (!await file.exists()) return FileStats.empty();

    final bytes = await file.readAsBytes();
    final content = utf8.decode(bytes, allowMalformed: true);
    final lines = const LineSplitter()
        .convert(content)
        .where((line) => line.trim().isNotEmpty)
        .length;
    final sha = sha256.convert(bytes).toString();

    return FileStats(bytes.length, lines, sha);
  }

  /// Sort map keys recursively for deterministic output
  static Map<String, dynamic> _sortKeys(Map<String, dynamic> map) {
    final sorted = Map<String, dynamic>.fromEntries(
      map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );

    sorted.updateAll((key, value) {
      if (value is Map<String, dynamic>) {
        return _sortKeys(value);
      } else if (value is List) {
        return value.map((item) {
          if (item is Map<String, dynamic>) {
            return _sortKeys(item);
          }
          return item;
        }).toList();
      }
      return value;
    });

    return sorted;
  }
}

/// File statistics for manifest generation
class FileStats {
  final int bytes;
  final int lines;
  final String sha256;

  const FileStats(this.bytes, this.lines, this.sha256);

  bool get isEmpty => bytes == 0 || lines == 0;

  static FileStats empty() => const FileStats(
        0,
        0,
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
}