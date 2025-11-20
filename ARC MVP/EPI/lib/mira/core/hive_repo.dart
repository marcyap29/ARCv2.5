// lib/mira/core/hive_repo.dart
import 'dart:async';
import 'package:hive/hive.dart';
import 'ids.dart';
import 'schema.dart';
import 'events.dart';
import 'mira_repo.dart';

/// Record wrappers for Hive persistence.
class _NodeRec {
  final MiraNode n;
  _NodeRec(this.n);
  Map<String, dynamic> toJson() => {
    'id': n.id,
    'type': n.type.index,
    'schemaVersion': n.schemaVersion,
    'data': n.data,
    'createdAt': n.createdAt.toUtc().toIso8601String(),
    'updatedAt': n.updatedAt.toUtc().toIso8601String(),
  };
  static _NodeRec fromJson(Map<String, dynamic> j) => _NodeRec(
    MiraNode(
      id: j['id'],
      type: NodeType.values[j['type']],
      schemaVersion: j['schemaVersion'],
      data: Map<String, dynamic>.from(j['data'] ?? {}),
      createdAt: DateTime.parse(j['createdAt']).toUtc(),
      updatedAt: DateTime.parse(j['updatedAt']).toUtc(),
    ),
  );
}

class _EdgeRec {
  final MiraEdge e;
  _EdgeRec(this.e);
  Map<String, dynamic> toJson() => {
    'id': e.id,
    'src': e.src,
    'dst': e.dst,
    'label': e.label.index,
    'schemaVersion': e.schemaVersion,
    'data': e.data,
    'createdAt': e.createdAt.toUtc().toIso8601String(),
  };
  static _EdgeRec fromJson(Map<String, dynamic> j) => _EdgeRec(
    MiraEdge(
      id: j['id'],
      src: j['src'],
      dst: j['dst'],
      label: EdgeType.values[j['label']],
      schemaVersion: j['schemaVersion'],
      data: Map<String, dynamic>.from(j['data'] ?? {}),
      createdAt: DateTime.parse(j['createdAt']).toUtc(),
    ),
  );
}

class _EventRec {
  final MiraEvent e;
  _EventRec(this.e);
  Map<String, dynamic> toJson() => {
    'id': e.id,
    'type': e.type,
    'payload': e.payload,
    'ts': e.ts.toUtc().toIso8601String(),
    'checksum': e.checksum,
  };
  static _EventRec fromJson(Map<String, dynamic> j) => _EventRec(
    MiraEvent(
      id: j['id'],
      type: j['type'],
      payload: Map<String, dynamic>.from(j['payload'] ?? {}),
      ts: DateTime.parse(j['ts']).toUtc(),
      checksum: j['checksum'],
    ),
  );
}

/// Optional aux stores to support MCP (pointers, embeddings).
class _PointerRec {
  final Map<String, dynamic> m;
  _PointerRec(this.m);
}
class _EmbeddingRec {
  final Map<String, dynamic> m;
  _EmbeddingRec(this.m);
}

/// Minimal, deterministic Hive-backed repo.
/// Notes:
/// - Append-only events
/// - In-memory per-type + in/out indexes for fast traversal
/// - exportAll()/importAll() stream typed records for MCP writer/reader
class HiveMiraRepo implements MiraRepo {
  final Box nodesBox;
  final Box edgesBox;
  final Box eventsBox;
  final Box pointersBox;    // MCP aux
  final Box embeddingsBox;  // MCP aux

  // In-memory indexes
  final Map<NodeType, Set<String>> _byType = {
    for (final t in NodeType.values) t: <String>{}
  };
  final Map<String, Set<String>> _outIndex = {}; // src -> edgeIds
  final Map<String, Set<String>> _inIndex = {};  // dst -> edgeIds

  HiveMiraRepo._({
    required this.nodesBox,
    required this.edgesBox,
    required this.eventsBox,
    required this.pointersBox,
    required this.embeddingsBox,
  }) {
    _rebuildIndexes();
  }

  /// Create repository with boxes for the given name
  static Future<HiveMiraRepo> create({String boxName = 'mira_default'}) async {
    final nodesBox = await Hive.openBox('${boxName}_nodes');
    final edgesBox = await Hive.openBox('${boxName}_edges');
    final eventsBox = await Hive.openBox('${boxName}_events');
    final pointersBox = await Hive.openBox('${boxName}_pointers');
    final embeddingsBox = await Hive.openBox('${boxName}_embeddings');

    return HiveMiraRepo._(
      nodesBox: nodesBox,
      edgesBox: edgesBox,
      eventsBox: eventsBox,
      pointersBox: pointersBox,
      embeddingsBox: embeddingsBox,
    );
  }

  void _rebuildIndexes() {
    _byType.forEach((k, v) => v.clear());
    _outIndex.clear();
    _inIndex.clear();

    for (final key in nodesBox.keys) {
      final rec = _NodeRec.fromJson(Map<String, dynamic>.from(nodesBox.get(key)));
      _byType[rec.n.type]!.add(rec.n.id);
    }
    for (final key in edgesBox.keys) {
      final rec = _EdgeRec.fromJson(Map<String, dynamic>.from(edgesBox.get(key)));
      _outIndex.putIfAbsent(rec.e.src, () => <String>{}).add(rec.e.id);
      _inIndex.putIfAbsent(rec.e.dst, () => <String>{}).add(rec.e.id);
    }
  }

  // ---------- Nodes ----------
  @override
  Future<void> upsertNode(MiraNode node) async {
    final now = DateTime.now().toUtc();
    final n = MiraNode(
      id: node.id,
      type: node.type,
      schemaVersion: node.schemaVersion,
      data: node.data,
      createdAt: node.createdAt,
      updatedAt: now,
    );
    await nodesBox.put(n.id, _NodeRec(n).toJson());
    _byType[n.type]!.add(n.id);
  }

  @override
  Future<MiraNode?> getNode(String id) async {
    final raw = nodesBox.get(id);
    if (raw == null) return null;
    return _NodeRec.fromJson(Map<String, dynamic>.from(raw)).n;
    }

  @override
  Future<void> removeNode(String nodeId) async {
    final raw = nodesBox.get(nodeId);
    if (raw == null) {
      return;
    }

    // Remove node record
    final node = _NodeRec.fromJson(Map<String, dynamic>.from(raw)).n;
    await nodesBox.delete(nodeId);
    _byType[node.type]?.remove(nodeId);

    // Remove outgoing edges
    final outgoing = _outIndex[nodeId]?.toList() ?? const [];
    for (final edgeId in outgoing) {
      await removeEdge(edgeId);
    }
    _outIndex.remove(nodeId);

    // Remove incoming edges
    final incoming = _inIndex[nodeId]?.toList() ?? const [];
    for (final edgeId in incoming) {
      await removeEdge(edgeId);
    }
    _inIndex.remove(nodeId);
  }

  @override
  Future<List<MiraNode>> findNodesByType(NodeType type, {int limit = 100}) async {
    final ids = _byType[type]!.take(limit);
    final out = <MiraNode>[];
    for (final id in ids) {
      final n = await getNode(id);
      if (n != null) out.add(n);
    }
    return out;
  }

  @override
  Future<List<MiraNode>> searchNodes(String query, {int limit = 50}) async {
    final queryLower = query.toLowerCase();
    final results = <MiraNode>[];

    for (final key in nodesBox.keys) {
      if (results.length >= limit) break;
      final raw = nodesBox.get(key);
      if (raw == null) continue;

      final node = _NodeRec.fromJson(Map<String, dynamic>.from(raw)).n;

      // Search in node ID, data content, and type-specific fields
      if (node.id.toLowerCase().contains(queryLower)) {
        results.add(node);
        continue;
      }

      // Search in data fields
      final dataStr = node.data.toString().toLowerCase();
      if (dataStr.contains(queryLower)) {
        results.add(node);
      }
    }

    return results;
  }

  @override
  Future<List<MiraNode>> getNodesInTimeRange({
    required DateTime start,
    required DateTime end,
    NodeType? type,
    int limit = 100,
  }) async {
    final results = <MiraNode>[];
    final typeIds = type != null ? _byType[type]! : nodesBox.keys.cast<String>();

    for (final id in typeIds) {
      if (results.length >= limit) break;
      final node = await getNode(id);
      if (node != null) {
        if (node.createdAt.isAfter(start) && node.createdAt.isBefore(end)) {
          results.add(node);
        }
      }
    }

    // Sort by creation time, newest first
    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }

  // ---------- Edges ----------
  @override
  Future<void> upsertEdge(MiraEdge edge) async {
    final id = edge.id.isNotEmpty ? edge.id : deterministicEdgeId(edge.src, edge.label.name, edge.dst);
    final e = MiraEdge(
      id: id,
      src: edge.src,
      dst: edge.dst,
      label: edge.label,
      schemaVersion: edge.schemaVersion,
      data: edge.data,
      createdAt: edge.createdAt,
    );
    await edgesBox.put(e.id, _EdgeRec(e).toJson());
    _outIndex.putIfAbsent(e.src, () => <String>{}).add(e.id);
    _inIndex.putIfAbsent(e.dst, () => <String>{}).add(e.id);
  }

  @override
  Future<List<MiraEdge>> edgesFrom(String src, {EdgeType? label}) async {
    final ids = _outIndex[src] ?? const <String>{};
    final out = <MiraEdge>[];
    for (final id in ids) {
      final raw = edgesBox.get(id);
      if (raw == null) continue;
      final e = _EdgeRec.fromJson(Map<String, dynamic>.from(raw)).e;
      if (label == null || e.label == label) out.add(e);
    }
    return out;
  }

  @override
  Future<List<MiraEdge>> edgesTo(String dst, {EdgeType? label}) async {
    final ids = _inIndex[dst] ?? const <String>{};
    final out = <MiraEdge>[];
    for (final id in ids) {
      final raw = edgesBox.get(id);
      if (raw == null) continue;
      final e = _EdgeRec.fromJson(Map<String, dynamic>.from(raw)).e;
      if (label == null || e.label == label) out.add(e);
    }
    return out;
  }

  @override
  Future<List<MiraEdge>> edgesBetween(String nodeA, String nodeB) async {
    final fromA = await edgesFrom(nodeA);
    final toB = fromA.where((e) => e.dst == nodeB).toList();

    final fromB = await edgesFrom(nodeB);
    final toA = fromB.where((e) => e.dst == nodeA).toList();

    return [...toB, ...toA];
  }

  @override
  Future<void> removeEdge(String edgeId) async {
    final raw = edgesBox.get(edgeId);
    if (raw != null) {
      final edge = _EdgeRec.fromJson(Map<String, dynamic>.from(raw)).e;
      _outIndex[edge.src]?.remove(edgeId);
      _inIndex[edge.dst]?.remove(edgeId);
      await edgesBox.delete(edgeId);
    }
  }

  // ---------- Events (append-only) ----------
  @override
  Future<bool> eventExists(String eventId) async => eventsBox.containsKey(eventId);

  @override
  Future<void> appendEvent(MiraEvent e) async {
    if (await eventExists(e.id)) return; // idempotent
    await eventsBox.put(e.id, _EventRec(e).toJson());
  }

  @override
  Stream<MiraEvent> replayEvents() async* {
    final keys = eventsBox.keys.toList()..sort(); // deterministic order
    for (final k in keys) {
      final raw = Map<String, dynamic>.from(eventsBox.get(k));
      yield _EventRec.fromJson(raw).e;
    }
  }

  @override
  Future<List<MiraEvent>> getEventsByType(String type, {int limit = 100}) async {
    final results = <MiraEvent>[];

    for (final key in eventsBox.keys) {
      if (results.length >= limit) break;
      final raw = eventsBox.get(key);
      if (raw == null) continue;

      final event = _EventRec.fromJson(Map<String, dynamic>.from(raw)).e;
      if (event.type == type) {
        results.add(event);
      }
    }

    // Sort by timestamp, newest first
    results.sort((a, b) => b.ts.compareTo(a.ts));
    return results;
  }

  // ---------- Bulk Operations ----------
  @override
  Future<List<MiraNode>> getNeighbors(String nodeId, {EdgeType? edgeType, int limit = 50}) async {
    final neighbors = <MiraNode>[];
    final neighborIds = <String>{};

    // Get outgoing neighbors
    final outgoingEdges = await edgesFrom(nodeId, label: edgeType);
    for (final edge in outgoingEdges) {
      neighborIds.add(edge.dst);
    }

    // Get incoming neighbors
    final incomingEdges = await edgesTo(nodeId, label: edgeType);
    for (final edge in incomingEdges) {
      neighborIds.add(edge.src);
    }

    // Fetch neighbor nodes
    for (final id in neighborIds.take(limit)) {
      final neighbor = await getNode(id);
      if (neighbor != null) {
        neighbors.add(neighbor);
      }
    }

    return neighbors;
  }

  @override
  Future<List<MiraNode>> getConnectedComponent(String nodeId, {int maxDepth = 3}) async {
    final visited = <String>{};
    final component = <MiraNode>[];
    final queue = <({String id, int depth})>[(id: nodeId, depth: 0)];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);

      if (visited.contains(current.id) || current.depth > maxDepth) continue;
      visited.add(current.id);

      final node = await getNode(current.id);
      if (node != null) {
        component.add(node);

        if (current.depth < maxDepth) {
          final neighbors = await getNeighbors(current.id);
          for (final neighbor in neighbors) {
            if (!visited.contains(neighbor.id)) {
              queue.add((id: neighbor.id, depth: current.depth + 1));
            }
          }
        }
      }
    }

    return component;
  }

  @override
  Future<void> upsertNodes(List<MiraNode> nodes) async {
    for (final node in nodes) {
      await upsertNode(node);
    }
  }

  @override
  Future<void> upsertEdges(List<MiraEdge> edges) async {
    for (final edge in edges) {
      await upsertEdge(edge);
    }
  }

  // ---------- Analytics Support ----------
  @override
  Future<Map<NodeType, int>> getNodeCounts() async {
    final counts = <NodeType, int>{};
    for (final type in NodeType.values) {
      counts[type] = _byType[type]!.length;
    }
    return counts;
  }

  @override
  Future<Map<EdgeType, int>> getEdgeCounts() async {
    final counts = <EdgeType, int>{};
    for (final type in EdgeType.values) {
      counts[type] = 0;
    }

    for (final key in edgesBox.keys) {
      final raw = edgesBox.get(key);
      if (raw != null) {
        final edge = _EdgeRec.fromJson(Map<String, dynamic>.from(raw)).e;
        counts[edge.label] = (counts[edge.label] ?? 0) + 1;
      }
    }

    return counts;
  }

  @override
  Future<List<MiraNode>> getTopKeywords({int limit = 20}) async {
    final keywords = await findNodesByType(NodeType.keyword);

    // Sort by frequency (stored in data.frequency)
    keywords.sort((a, b) {
      final freqA = a.data['frequency'] as int? ?? 0;
      final freqB = b.data['frequency'] as int? ?? 0;
      return freqB.compareTo(freqA);
    });

    return keywords.take(limit).toList();
  }

  @override
  Future<List<MiraNode>> getRecentEntries({int limit = 10}) async {
    final entries = await findNodesByType(NodeType.entry);

    // Sort by creation time, newest first
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return entries.take(limit).toList();
  }

  // ---------- Portability for MCP ----------
  // Kind tags so the writer can partition cleanly.
  @override
  Stream<Map<String, dynamic>> exportAll() async* {
    // nodes
    final nodeKeys = nodesBox.keys.toList()..sort();
    for (final k in nodeKeys) {
      final rec = Map<String, dynamic>.from(nodesBox.get(k));
      yield {'kind':'node', ...rec};
    }
    // edges
    final edgeKeys = edgesBox.keys.toList()..sort();
    for (final k in edgeKeys) {
      final rec = Map<String, dynamic>.from(edgesBox.get(k));
      yield {'kind':'edge', ...rec};
    }
    // pointers
    final ptrKeys = pointersBox.keys.toList()..sort();
    for (final k in ptrKeys) {
      final rec = Map<String, dynamic>.from(pointersBox.get(k));
      yield {'kind':'pointer', ...rec};
    }
    // embeddings
    final embKeys = embeddingsBox.keys.toList()..sort();
    for (final k in embKeys) {
      final rec = Map<String, dynamic>.from(embeddingsBox.get(k));
      // Only yield embeddings with a valid pointer_ref
      final ptr = rec['pointer_ref'];
      if (ptr is String && ptr.isNotEmpty) {
        yield {'kind':'embedding', ...rec};
      }
    }
    // events (optional for audit export)
    final evKeys = eventsBox.keys.toList()..sort();
    for (final k in evKeys) {
      final rec = Map<String, dynamic>.from(eventsBox.get(k));
      yield {'kind':'event', ...rec};
    }
  }

  @override
  Future<void> importAll(Iterable<Map<String, dynamic>> records) async {
    for (final rec in records) {
      final kind = rec['kind'] as String? ?? '';
      switch (kind) {
        case 'node':
          await upsertNode(_NodeRec.fromJson(rec).n);
          break;
        case 'edge':
          await upsertEdge(_EdgeRec.fromJson(rec).e);
          break;
        case 'pointer':
          await pointersBox.put(rec['id'], rec);
          break;
        case 'embedding':
          await embeddingsBox.put(rec['id'], rec);
          break;
        case 'event':
          await eventsBox.put(rec['id'], rec);
          break;
        default:
          // Ignore unknown kinds (additive evolution).
          break;
      }
    }
  }

  // ---------- Auxiliary Storage (MCP Support) ----------
  @override
  Future<void> storePointer(Map<String, dynamic> pointer) async {
    await pointersBox.put(pointer['id'], pointer);
  }

  @override
  Future<Map<String, dynamic>?> getPointer(String pointerId) async {
    final raw = pointersBox.get(pointerId);
    return raw != null ? Map<String, dynamic>.from(raw) : null;
  }

  @override
  Future<void> storeEmbedding(Map<String, dynamic> embedding) async {
    await embeddingsBox.put(embedding['id'], embedding);
  }

  @override
  Future<Map<String, dynamic>?> getEmbedding(String embeddingId) async {
    final raw = embeddingsBox.get(embeddingId);
    return raw != null ? Map<String, dynamic>.from(raw) : null;
  }

  @override
  Future<List<Map<String, dynamic>>> getEmbeddingsForPointer(String pointerId) async {
    final results = <Map<String, dynamic>>[];

    for (final key in embeddingsBox.keys) {
      final raw = embeddingsBox.get(key);
      if (raw != null) {
        final embedding = Map<String, dynamic>.from(raw);
        if (embedding['pointer_ref'] == pointerId) {
          results.add(embedding);
        }
      }
    }

    return results;
  }

  // ---------- Maintenance ----------
  @override
  Future<void> rebuildIndexes() async {
    _rebuildIndexes();
  }

  @override
  Future<void> clearAll() async {
    await nodesBox.clear();
    await edgesBox.clear();
    await eventsBox.clear();
    await pointersBox.clear();
    await embeddingsBox.clear();
    _rebuildIndexes();
  }

  @override
  Future<void> close() async {
    await nodesBox.close();
    await edgesBox.close();
    await eventsBox.close();
    await pointersBox.close();
    await embeddingsBox.close();
  }
}