// lib/mcp/bundle/writer.dart
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';
import '../../mira/core/mira_repo.dart';
import '../../mira/core/schema.dart';
import '../../mcp/adapters/from_mira.dart';
// import 'manifest.dart';

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
    final nodesHashSink = AccumulatorSink<Digest>();
    final edgesHashSink = AccumulatorSink<Digest>();
    final pointersHashSink = AccumulatorSink<Digest>();
    final embeddingsHashSink = AccumulatorSink<Digest>();
    final nodesDigest = sha256.startChunkedConversion(nodesHashSink);
    final edgesDigest = sha256.startChunkedConversion(edgesHashSink);
    final pointersDigest = sha256.startChunkedConversion(pointersHashSink);
    final embeddingsDigest = sha256.startChunkedConversion(embeddingsHashSink);

    int nodesCount = 0, edgesCount = 0, pointersCount = 0, embeddingsCount = 0;

    // 0) Explicitly project journal entries to MCP (pointer + node + edges)
    final emittedIds = <String>{};
    try {
      print('🔍 MCP Bundle Writer: Starting entry projection...');
      final projected = await McpEntryProjector.projectAll(repo: repo);
      print('🔍 MCP Bundle Writer: Projected ${projected.length} records');

      for (final rec in projected) {
        final kind = rec['kind'];
        final line = '${JsonEncoder.withIndent(null, (o) => o).convert(_sortKeys(rec))}\n';
        final bytes = utf8.encode(line);
        final id = rec['id'] as String?;
        if (id != null) emittedIds.add(id);

        print('🔍 Writing record kind=$kind, id=$id, size=${bytes.length} bytes');

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
            // embeddings not emitted by projector (yet)
            break;
          default:
            print('🔍 Unknown record kind: $kind');
            break;
        }
      }
    } catch (e, stackTrace) {
      print('🔍 MCP Bundle Writer: Error in entry projection: $e');
      print('🔍 Stack trace: $stackTrace');
    }

    // 1) Stream repo export in stable order; partition by "kind" with duplicate guards
    await for (final rec in repo.exportAll()) {
      final kind = rec['kind'];

      // Prepare MCP-shaped record for nodes/edges; pass-through for others
      Map<String, dynamic> outRec = rec;
      final String? recId = rec['id'] as String?;
      if (recId != null && emittedIds.contains(recId)) {
        // Skip records already emitted by projector
        continue;
      }
      if (kind == 'node') {
        try {
          final node = MiraNode(
            id: rec['id'] as String,
            type: NodeType.values[(rec['type'] as num).toInt()],
            schemaVersion: (rec['schemaVersion'] as num).toInt(),
            data: Map<String, dynamic>.from(rec['data'] ?? const <String, dynamic>{}),
            createdAt: DateTime.parse(rec['createdAt'] as String).toUtc(),
            updatedAt: DateTime.parse(rec['updatedAt'] as String).toUtc(),
          );
          outRec = MiraToMcpAdapter.nodeToMcp(node);
        } catch (_) {
          // Fallback to original record if mapping fails
          outRec = rec;
        }
      } else if (kind == 'edge') {
        try {
          final edge = MiraEdge(
            id: rec['id'] as String,
            src: rec['src'] as String,
            dst: rec['dst'] as String,
            label: EdgeType.values[(rec['label'] as num).toInt()],
            schemaVersion: (rec['schemaVersion'] as num).toInt(),
            data: Map<String, dynamic>.from(rec['data'] ?? const <String, dynamic>{}),
            createdAt: DateTime.parse(rec['createdAt'] as String).toUtc(),
          );
          outRec = MiraToMcpAdapter.edgeToMcp(edge);
        } catch (_) {
          // Fallback to original record if mapping fails
          outRec = rec;
        }
      }

      // Stable key order for determinism
      final line = '${JsonEncoder.withIndent(null, (o) => o).convert(_sortKeys(outRec))}\n';
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
          // Validate pointer_ref before writing; skip invalid embeddings
          final pointerRef = rec['pointer_ref'];
          if (pointerRef is String && pointerRef.isNotEmpty) {
            embeddingsSink.add(bytes);
            embeddingsDigest.add(bytes);
            embeddingsBytes += bytes.length;
            embeddingsCount++;
          }
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

    // Ensure all data is flushed before closing
    await nodesSink.flush();
    await edgesSink.flush();
    await pointersSink.flush();
    await embeddingsSink.flush();

    await nodesSink.close();
    await edgesSink.close();
    await pointersSink.close();
    await embeddingsSink.close();

    print('🔍 MCP Bundle Writer: All streams flushed and closed');

    nodesDigest.close();
    edgesDigest.close();
    pointersDigest.close();
    embeddingsDigest.close();

    // Byte-count diagnostics
    try {
      print('MCP export: nodes=$nodesCount bytes=$nodesBytes, edges=$edgesCount bytes=$edgesBytes, pointers=$pointersCount bytes=$pointersBytes, embeddings=$embeddingsCount bytes=$embeddingsBytes');
    } catch (_) {}

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
        'nodes_jsonl': '${nodesHashSink.events.single}',
        'edges_jsonl': '${edgesHashSink.events.single}',
        'pointers_jsonl': '${pointersHashSink.events.single}',
        'embeddings_jsonl': '${embeddingsHashSink.events.single}',
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