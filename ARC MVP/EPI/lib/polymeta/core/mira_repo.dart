// lpackage:my_app/polymeta/core/mira_repo.dart
// Abstract repository interface for MIRA semantic memory operations
// Single touchpoint between features and storage, enabling clean testing and implementation swaps

import 'schema.dart';
import 'events.dart';

/// Abstract repository for MIRA semantic memory operations
///
/// This serves as the single interface between all MIRA features and the underlying
/// storage mechanism, whether Hive, SQLite, or other implementations.
abstract class MiraRepo {
  // ---- Node Operations ----

  /// Store or update a node in the graph
  Future<void> upsertNode(MiraNode node);

  /// Retrieve a node by its ID
  Future<MiraNode?> getNode(String id);

  /// Find nodes by type with optional limit
  Future<List<MiraNode>> findNodesByType(NodeType type, {int limit = 100});

  /// Search nodes by text content (for keywords, entries)
  Future<List<MiraNode>> searchNodes(String query, {int limit = 50});

  /// Get nodes created or updated within a time range
  Future<List<MiraNode>> getNodesInTimeRange({
    required DateTime start,
    required DateTime end,
    NodeType? type,
    int limit = 100,
  });

  /// Remove a node and its associated edges
  Future<void> removeNode(String nodeId);

  // ---- Edge Operations ----

  /// Store or update an edge in the graph
  Future<void> upsertEdge(MiraEdge edge);

  /// Get all edges from a source node, optionally filtered by label
  Future<List<MiraEdge>> edgesFrom(String src, {EdgeType? label});

  /// Get all edges to a destination node, optionally filtered by label
  Future<List<MiraEdge>> edgesTo(String dst, {EdgeType? label});

  /// Get edges between two specific nodes
  Future<List<MiraEdge>> edgesBetween(String nodeA, String nodeB);

  /// Remove an edge (used by VEIL for pruning)
  Future<void> removeEdge(String edgeId);

  // ---- Event Operations (Append-Only) ----

  /// Check if an event already exists (for idempotency)
  Future<bool> eventExists(String eventId);

  /// Append an event to the log (no-op if already exists)
  Future<void> appendEvent(MiraEvent event);

  /// Replay all events in chronological order
  Stream<MiraEvent> replayEvents();

  /// Get events of a specific type
  Future<List<MiraEvent>> getEventsByType(String type, {int limit = 100});

  // ---- Bulk Operations ----

  /// Get neighbors of a node (all connected nodes)
  Future<List<MiraNode>> getNeighbors(String nodeId, {EdgeType? edgeType, int limit = 50});

  /// Get strongly connected component containing a node
  Future<List<MiraNode>> getConnectedComponent(String nodeId, {int maxDepth = 3});

  /// Batch upsert multiple nodes efficiently
  Future<void> upsertNodes(List<MiraNode> nodes);

  /// Batch upsert multiple edges efficiently
  Future<void> upsertEdges(List<MiraEdge> edges);

  // ---- Analytics Support ----

  /// Get node count by type
  Future<Map<NodeType, int>> getNodeCounts();

  /// Get edge count by type
  Future<Map<EdgeType, int>> getEdgeCounts();

  /// Get most frequent keywords
  Future<List<MiraNode>> getTopKeywords({int limit = 20});

  /// Get recent entries
  Future<List<MiraNode>> getRecentEntries({int limit = 10});

  // ---- MCP Portability ----

  /// Export all data for MCP bundle creation
  /// Returns stream of records tagged with 'kind' for partitioning
  Stream<Map<String, dynamic>> exportAll();

  /// Import records from MCP bundle
  /// Records should be tagged with 'kind' for routing
  Future<void> importAll(Iterable<Map<String, dynamic>> records);

  // ---- Auxiliary Storage (MCP Support) ----

  /// Store pointer record for MCP export/import
  Future<void> storePointer(Map<String, dynamic> pointer);

  /// Get pointer by ID
  Future<Map<String, dynamic>?> getPointer(String pointerId);

  /// Store embedding record for MCP export/import
  Future<void> storeEmbedding(Map<String, dynamic> embedding);

  /// Get embedding by ID
  Future<Map<String, dynamic>?> getEmbedding(String embeddingId);

  /// Get embeddings for a pointer
  Future<List<Map<String, dynamic>>> getEmbeddingsForPointer(String pointerId);

  // ---- Maintenance ----

  /// Rebuild internal indexes for performance
  Future<void> rebuildIndexes();

  /// Clear all data (for testing and reset)
  Future<void> clearAll();

  /// Close repository and release resources
  Future<void> close();
}

/// Exception thrown by MIRA repository operations
class MiraRepoException implements Exception {
  final String message;
  final dynamic cause;

  const MiraRepoException(this.message, [this.cause]);

  @override
  String toString() => 'MiraRepoException: $message${cause != null ? ' (caused by: $cause)' : ''}';
}

/// Result of bulk operations
class BulkOperationResult {
  final int successful;
  final int failed;
  final List<String> errors;

  const BulkOperationResult({
    required this.successful,
    required this.failed,
    required this.errors,
  });

  bool get isSuccess => failed == 0;
  int get total => successful + failed;

  @override
  String toString() => 'BulkOperationResult($successful/$total successful, ${errors.length} errors)';
}