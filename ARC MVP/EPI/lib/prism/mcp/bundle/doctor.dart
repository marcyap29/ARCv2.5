// lib/mcp/bundle/doctor.dart
// Bundle doctor for validating and auto-repairing MCP bundles
// Ensures that every journal entry becomes a proper Pointer + Node + Edge trio

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../../repositories/journal_repository.dart';
import '../adapters/journal_entry_projector.dart';
import 'validate.dart';

class McpBundleDoctor {
  final JournalRepository journalRepo;
  final McpValidator validator;

  McpBundleDoctor(this.journalRepo, this.validator);

  /// Check the health of an MCP bundle directory
  Future<BundleHealth> checkBundleHealth(Directory dir) async {
    final manifestFile = File('${dir.path}/manifest.json');
    final nodesFile = File('${dir.path}/nodes.jsonl');
    final edgesFile = File('${dir.path}/edges.jsonl');
    final pointersFile = File('${dir.path}/pointers.jsonl');
    final embeddingsFile = File('${dir.path}/embeddings.jsonl');

    // Check if all required files exist
    final exists = await Future.wait([
      manifestFile.exists(),
      nodesFile.exists(),
      edgesFile.exists(),
      pointersFile.exists(),
      embeddingsFile.exists(),
    ]);

    if (exists.any((e) => !e)) {
      return BundleHealth.incomplete('Missing one or more bundle files.');
    }

    // Validate manifest
    final errors = <String>[];
    final manifest = jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
    validator.validateManifest(manifest, errors);

    // Check file statistics
    final nodeStats = await _getFileStats(nodesFile);
    final edgeStats = await _getFileStats(edgesFile);
    final pointerStats = await _getFileStats(pointersFile);
    final embeddingStats = await _getFileStats(embeddingsFile);

    // Check manifest counts against actual counts
    final manifestCounts = (manifest['counts'] ?? {}) as Map<String, dynamic>;
    final manifestNodes = (manifestCounts['nodes'] ?? 0) as int;
    final manifestEdges = (manifestCounts['edges'] ?? 0) as int;
    final manifestPointers = (manifestCounts['pointers'] ?? 0) as int;

    final issues = <String>[];

    // Critical issues that indicate empty/broken export
    if (pointerStats.isEmpty || manifestPointers == 0) {
      issues.add('pointers.jsonl is empty or manifest shows 0 pointers - no journal content exported');
    }
    if (nodeStats.isEmpty || manifestNodes == 0) {
      issues.add('nodes.jsonl is empty or manifest shows 0 nodes - no journal entries exported');
    }
    if (manifestEdges == 0) {
      issues.add('edges count is 0 - no relationships exported (unexpected for journal entries)');
    }

    // Count mismatches
    if (manifestNodes != nodeStats.lines && nodeStats.lines > 0) {
      issues.add('Manifest nodes count ($manifestNodes) does not match file (${ nodeStats.lines })');
    }
    if (manifestEdges != edgeStats.lines && edgeStats.lines > 0) {
      issues.add('Manifest edges count ($manifestEdges) does not match file (${ edgeStats.lines })');
    }
    if (manifestPointers != pointerStats.lines && pointerStats.lines > 0) {
      issues.add('Manifest pointers count ($manifestPointers) does not match file (${ pointerStats.lines })');
    }

    return BundleHealth(
      ok: issues.isEmpty && errors.isEmpty,
      problems: [...errors, ...issues],
      nodes: nodeStats,
      edges: edgeStats,
      pointers: pointerStats,
      embeddings: embeddingStats,
    );
  }

  /// Repair a bundle by regenerating from journal repository
  Future<BundleHealth> repairBundle(Directory dir, {bool addEmbeddingPlaceholders = false}) async {
    final nodesFile = File('${dir.path}/nodes.jsonl');
    final edgesFile = File('${dir.path}/edges.jsonl');
    final pointersFile = File('${dir.path}/pointers.jsonl');
    final embeddingsFile = File('${dir.path}/embeddings.jsonl');
    final manifestFile = File('${dir.path}/manifest.json');

    // Clear existing files and regenerate from journal repository
    await nodesFile.writeAsString('');
    await edgesFile.writeAsString('');
    await pointersFile.writeAsString('');
    await embeddingsFile.writeAsString('');

    final nodesSink = nodesFile.openWrite();
    final edgesSink = edgesFile.openWrite();
    final pointersSink = pointersFile.openWrite();
    final embeddingsSink = addEmbeddingPlaceholders ? embeddingsFile.openWrite() : null;

    try {
      // Use the projector to regenerate all MCP records from journal entries
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

      // Update file stats after regeneration
      final nodeStats = await _getFileStats(nodesFile);
      final edgeStats = await _getFileStats(edgesFile);
      final pointerStats = await _getFileStats(pointersFile);
      final embeddingStats = await _getFileStats(embeddingsFile);

      // Update or create manifest
      Map<String, dynamic> manifest = {};
      if (await manifestFile.exists()) {
        manifest = jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      }

      // Update manifest with current data
      manifest['bundle_id'] ??= 'mcp_repair_${DateTime.now().toUtc().toIso8601String()}';
      manifest['version'] ??= '1.0.0';
      manifest['created_at'] ??= DateTime.now().toUtc().toIso8601String();
      manifest['storage_profile'] ??= 'balanced';

      manifest['counts'] = {
        'nodes': nodeStats.lines,
        'edges': edgeStats.lines,
        'pointers': pointerStats.lines,
        'embeddings': embeddingStats.lines,
      };

      manifest['bytes'] = {
        'nodes_jsonl': nodeStats.bytes,
        'edges_jsonl': edgeStats.bytes,
        'pointers_jsonl': pointerStats.bytes,
        'embeddings_jsonl': embeddingStats.bytes,
      };

      manifest['checksums'] = {
        'nodes_jsonl': 'sha256:${nodeStats.sha256}',
        'edges_jsonl': 'sha256:${edgeStats.sha256}',
        'pointers_jsonl': 'sha256:${pointerStats.sha256}',
        'embeddings_jsonl': 'sha256:${embeddingStats.sha256}',
      };

      manifest['encoder_registry'] ??= <Map<String, dynamic>>[];
      manifest['cas_remotes'] ??= <String>[];
      manifest['notes'] ??= 'Auto-repaired by McpBundleDoctor';

      // Write updated manifest with sorted keys
      await manifestFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(_sortMapKeys(manifest))
      );

      return await checkBundleHealth(dir);
    } catch (e) {
      // Ensure sinks are closed even on error
      await nodesSink.close();
      await edgesSink.close();
      await pointersSink.close();
      if (embeddingsSink != null) await embeddingsSink.close();

      return BundleHealth.incomplete('Repair failed: $e');
    }
  }

  /// Get statistics for a file
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
  static Map<String, dynamic> _sortMapKeys(Map<String, dynamic> map) {
    final sorted = Map<String, dynamic>.fromEntries(
      map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );

    sorted.updateAll((key, value) {
      if (value is Map<String, dynamic>) {
        return _sortMapKeys(value);
      } else if (value is List) {
        return value.map((item) {
          if (item is Map<String, dynamic>) {
            return _sortMapKeys(item);
          }
          return item;
        }).toList();
      }
      return value;
    });

    return sorted;
  }
}

/// Health status of an MCP bundle
class BundleHealth {
  final bool ok;
  final List<String> problems;
  final FileStats nodes;
  final FileStats edges;
  final FileStats pointers;
  final FileStats embeddings;

  BundleHealth({
    required this.ok,
    required this.problems,
    required this.nodes,
    required this.edges,
    required this.pointers,
    required this.embeddings,
  });

  factory BundleHealth.incomplete(String message) => BundleHealth(
        ok: false,
        problems: [message],
        nodes: FileStats.empty(),
        edges: FileStats.empty(),
        pointers: FileStats.empty(),
        embeddings: FileStats.empty(),
      );
}

/// Statistics for a file
class FileStats {
  final int bytes;
  final int lines;
  final String sha256;

  const FileStats(this.bytes, this.lines, this.sha256);

  bool get isEmpty => bytes == 0 || lines == 0;

  static FileStats empty() => const FileStats(
        0,
        0,
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', // SHA-256 of empty string
      );
}