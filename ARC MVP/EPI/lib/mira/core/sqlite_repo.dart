// lib/mira/core/sqlite_repo.dart
// SQLite implementation of MiraRepo (future implementation)
// Currently throws UnimplementedError to be filled later when useSqliteRepo flag is enabled

import 'schema.dart';
import 'events.dart';
import 'mira_repo.dart';

/// SQLite-based implementation of MiraRepo
///
/// This is a stub implementation that will be completed when the useSqliteRepo
/// flag is enabled and SQLite is chosen as the primary storage backend.
class SqliteMiraRepo implements MiraRepo {
  /// Database handle (to be provided by DI when implemented)
  final dynamic database;

  SqliteMiraRepo({required this.database});

  @override
  Future<void> appendEvent(MiraEvent event) {
    throw UnimplementedError('SQLite implementation pending');
  }

  @override
  Future<void> clearAll() {
    throw UnimplementedError('SQLite implementation pending');
  }

  @override
  Future<void> close() {
    throw UnimplementedError('SQLite implementation pending');
  }

  @override
  Future<List<MiraEdge>> edgesBetween(String nodeA, String nodeB) {
    throw UnimplementedError('SQLite implementation pending');
  }

  @override
  Future<List<MiraEdge>> edgesFrom(String src, {EdgeType? label}) {
    throw UnimplementedError('SQLite implementation pending');
  }

  @override
  Future<List<MiraEdge>> edgesTo(String dst, {EdgeType? label}) {
    throw UnimplementedError('SQLite implementation pending');
  }

  @override
  Future<bool> eventExists(String eventId) {
    throw UnimplementedError('SQLite implementation pending');
  }

  @override
  Stream<Map<String, dynamic>> exportAll() {
    throw UnimplementedError('SQLite implementation pending');
  }

  @override
  Future<List<MiraNode>> findNodesByType(NodeType type, {int limit = 100}) {
    throw UnimplementedError('SQLite implementation pending');
  }

  @override
  Future<List<MiraNode>> getConnectedComponent(String nodeId, {int maxDepth = 3}) {
    throw UnimplementedError('SQLite implementation pending');
  }

  @override
  Future<Map<EdgeType, int>> getEdgeCounts() {
    throw UnimplementedError('SQLite implementation pending');
  }

  @override
  Future<Map<String, dynamic>?> getEmbedding(String embeddingId) {
    throw UnimplementedError('SQLite implementation pending');
  }

  @override
  Future<List<Map<String, dynamic>>> getEmbeddingsForPointer(String pointerId) {
    throw UnimplementedError('SQLite implementation pending');
  }

  @override
  Future<List<MiraEvent>> getEventsByType(String type, {int limit = 100}) {
    throw UnimplementedError('SQLite implementation pending');
  }

  @override
  Future<List<MiraNode>> getNeighbors(String nodeId, {EdgeType? edgeType, int limit = 50}) {
    throw UnimplementedError('SQLite implementation pending');
  }

  @override
  Future<MiraNode?> getNode(String id) {
    throw UnimplementedError('SQLite implementation pending');
  }

  @override
  Future<Map<NodeType, int>> getNodeCounts() {
    throw UnimplementedError('SQLite implementation pending');
  }

  @override
  Future<List<MiraNode>> getNodesInTimeRange({
    required DateTime start,
    required DateTime end,
    NodeType? type,
    int limit = 100,
  }) {
    throw UnimplementedError('SQLite implementation pending');
  }

  @override
  Future<Map<String, dynamic>?> getPointer(String pointerId) {
    throw UnimplementedError('SQLite implementation pending');
  }

  @override
  Future<List<MiraNode>> getRecentEntries({int limit = 10}) {
    throw UnimplementedError('SQLite implementation pending');
  }

  @override
  Future<List<MiraNode>> getTopKeywords({int limit = 20}) {
    throw UnimplementedError('SQLite implementation pending');
  }

  @override
  Future<void> importAll(Iterable<Map<String, dynamic>> records) {
    throw UnimplementedError('SQLite implementation pending');
  }

  @override
  Future<void> rebuildIndexes() {
    throw UnimplementedError('SQLite implementation pending');
  }

  @override
  Future<void> removeEdge(String edgeId) {
    throw UnimplementedError('SQLite implementation pending');
  }

  @override
  Stream<MiraEvent> replayEvents() {
    throw UnimplementedError('SQLite implementation pending');
  }

  @override
  Future<List<MiraNode>> searchNodes(String query, {int limit = 50}) {
    throw UnimplementedError('SQLite implementation pending');
  }

  @override
  Future<void> storeEmbedding(Map<String, dynamic> embedding) {
    throw UnimplementedError('SQLite implementation pending');
  }

  @override
  Future<void> storePointer(Map<String, dynamic> pointer) {
    throw UnimplementedError('SQLite implementation pending');
  }

  @override
  Future<void> upsertEdge(MiraEdge edge) {
    throw UnimplementedError('SQLite implementation pending');
  }

  @override
  Future<void> upsertEdges(List<MiraEdge> edges) {
    throw UnimplementedError('SQLite implementation pending');
  }

  @override
  Future<void> upsertNode(MiraNode node) {
    throw UnimplementedError('SQLite implementation pending');
  }

  @override
  Future<void> upsertNodes(List<MiraNode> nodes) {
    throw UnimplementedError('SQLite implementation pending');
  }
}