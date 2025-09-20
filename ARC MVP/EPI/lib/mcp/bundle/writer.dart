// lib/mcp/bundle/writer.dart
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../../mira/core/mira_repo.dart';
import 'manifest.dart';

class McpBundleWriter {
  final MiraRepo repo;
  McpBundleWriter(this.repo);

  Future<Directory> exportBundle({
    required Directory outDir,
    required String storageProfile, // minimal|space_saver|balanced|hi_fidelity
    required List<Map<String, dynamic>> encoderRegistry,
    bool includeEvents = false,
  }) async {
    if (!await outDir.exists()) await outDir.create(recursive: true);

    final nodesPath = File('${outDir.path}/nodes.jsonl');
    final edgesPath = File('${outDir.path}/edges.jsonl');
    final pointersPath = File('${outDir.path}/pointers.jsonl');
    final embeddingsPath = File('${outDir.path}/embeddings.jsonl');
    final manifestPath = File('${outDir.path}/manifest.json');

    final nodesSink = nodesPath.openWrite();
    final edgesSink = edgesPath.openWrite();
    final pointersSink = pointersPath.openWrite();
    final embeddingsSink = embeddingsPath.openWrite();

    var nodesBytes = 0, edgesBytes = 0, pointersBytes = 0, embeddingsBytes = 0;
    final nodesHash = AccumulatorSink<Digest>();
    final edgesHash = AccumulatorSink<Digest>();
    final pointersHash = AccumulatorSink<Digest>();
    final embeddingsHash = AccumulatorSink<Digest>();
    final nodesDigest = sha256.startChunkedConversion(nodesHash);
    final edgesDigest = sha256.startChunkedConversion(edgesHash);
    final pointersDigest = sha256.startChunkedConversion(pointersHash);
    final embeddingsDigest = sha256.startChunkedConversion(embeddingsHash);

    int nodesCount = 0, edgesCount = 0, pointersCount = 0, embeddingsCount = 0;

    // Stream repo export in stable order; partition by "kind"
    await for (final rec in repo.exportAll()) {
      final kind = rec['kind'];
      // Stable key order for determinism
      final line = JsonEncoder.withIndent(null, (o) => o).convert(_sortKeys(rec)) + '\n';
      final bytes = utf8.encode(line);
      switch (kind) {
        case 'node':
          nodesSink.add(bytes);
          nodesDigest.add(bytes);
          nodesBytes += bytes.length;
          nodesCount++;
          break;
        case 'edge':
          edgesSink.add(bytes);
          edgesDigest.add(bytes);
          edgesBytes += bytes.length;
          edgesCount++;
          break;
        case 'pointer':
          pointersSink.add(bytes);
          pointersDigest.add(bytes);
          pointersBytes += bytes.length;
          pointersCount++;
          break;
        case 'embedding':
          embeddingsSink.add(bytes);
          embeddingsDigest.add(bytes);
          embeddingsBytes += bytes.length;
          embeddingsCount++;
          break;
        case 'event':
          if (includeEvents) {
            // (Optional) Write to a separate events.jsonl if you choose to add it later.
          }
          break;
        default:
          // ignore unknown kinds
          break;
      }
    }

    await nodesSink.close();
    await edgesSink.close();
    await pointersSink.close();
    await embeddingsSink.close();

    nodesDigest.close();
    edgesDigest.close();
    pointersDigest.close();
    embeddingsDigest.close();

    final manifest = _sortKeys({
      'bundle_id': 'mcp_${DateTime.now().toUtc().toIso8601String()}',
      'version': '1.0.0',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'storage_profile': storageProfile,
      'counts': {
        'nodes': nodesCount,
        'edges': edgesCount,
        'pointers': pointersCount,
        'embeddings': embeddingsCount,
      },
      'bytes': {
        'nodes_jsonl': nodesBytes,
        'edges_jsonl': edgesBytes,
        'pointers_jsonl': pointersBytes,
        'embeddings_jsonl': embeddingsBytes,
      },
      'checksums': {
        'nodes_jsonl': 'sha256:${nodesHash.events.single}',
        'edges_jsonl': 'sha256:${edgesHash.events.single}',
        'pointers_jsonl': 'sha256:${pointersHash.events.single}',
        'embeddings_jsonl': 'sha256:${embeddingsHash.events.single}',
      },
      'encoder_registry': encoderRegistry,
      'cas_remotes': <String>[],
      'notes': '',
    });

    await manifestPath.writeAsString(const JsonEncoder.withIndent('  ').convert(manifest));
    return outDir;
  }

  Map<String, dynamic> _sortKeys(Map<String, dynamic> m) {
    final sorted = Map<String, dynamic>.fromEntries(
      m.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    sorted.updateAll((key, value) {
      if (value is Map<String, dynamic>) return _sortKeys(value);
      if (value is List) {
        return value.map((e) => e is Map<String, dynamic> ? _sortKeys(e) : e).toList();
      }
      return value;
    });
    return sorted;
  }
}