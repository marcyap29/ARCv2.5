// lib/mira/mira_service.dart
// Main service class that wires together MIRA core with MCP import/export

import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/flags.dart';
import 'core/mira_repo.dart';
import 'core/hive_repo.dart';
import 'core/sqlite_repo.dart';
import 'core/schema.dart';
import '../core/mcp/bundle/writer.dart';
import '../core/mcp/bundle/reader.dart';
import '../core/mcp/bundle/manifest.dart';
import '../core/mcp/export/mcp_export_service.dart';
import '../core/mcp/import/mcp_import_service.dart';
import '../core/mcp/models/mcp_schemas.dart';
import '../lumara/chat/chat_repo.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/arc/core/journal_repository.dart';

class MiraService {
  static MiraService? _instance;
  late final MiraRepo _repo;
  late final MiraFlags _flags;
  late final McpBundleWriter _bundleWriter;
  late final McpBundleReader _bundleReader;
  late final McpExportService _mcpExportService;
  late final McpImportService _mcpImportService;
  ChatRepo? _chatRepo;
  JournalRepository? _journalRepo;

  bool _initialized = false;

  MiraService._();

  static MiraService get instance {
    _instance ??= MiraService._();
    return _instance!;
  }

  /// Initialize MIRA service with configuration
  Future<void> initialize({
    MiraFlags? flags,
    String? hiveBoxName,
    dynamic sqliteDatabase,
    ChatRepo? chatRepo,
    JournalRepository? journalRepo,
  }) async {
    if (_initialized) return;

    _flags = flags ?? MiraFlags.defaults();

    // Initialize storage based on flags
    if (_flags.useSqliteRepo && sqliteDatabase != null) {
      _repo = SqliteMiraRepo(database: sqliteDatabase);
    } else {
      // Default to Hive implementation
      await Hive.initFlutter();

      // Register adapters for MIRA types
      _registerHiveAdapters();

      _repo = await HiveMiraRepo.create(boxName: hiveBoxName ?? 'mira_default');
    }

    // Initialize MCP components
    _bundleWriter = McpBundleWriter(_repo);
    _bundleReader = McpBundleReader(_repo);

    // Store repository references
    _chatRepo = chatRepo;
    _journalRepo = journalRepo ?? JournalRepository();

    // Initialize enhanced MCP export/import services
    _mcpExportService = McpExportService(
      storageProfile: McpStorageProfile.balanced,
      chatRepo: _chatRepo,
    );
    _mcpImportService = McpImportService(
      chatRepo: _chatRepo,
      journalRepo: _journalRepo,
    );

    _initialized = true;
  }

  /// Get the underlying repository
  MiraRepo get repo {
    _ensureInitialized();
    return _repo;
  }

  /// Get current feature flags
  MiraFlags get flags {
    _ensureInitialized();
    return _flags;
  }

  /// Export MIRA data to MCP bundle
  Future<Directory> exportToMcp({
    required Directory outputDir,
    String storageProfile = 'balanced',
    bool includeEvents = false,
    String? encoderId,
  }) async {
    _ensureInitialized();

    if (!_flags.miraEnabled) {
      throw StateError('MIRA export disabled by feature flags');
    }

    // Use default encoder registry if not specified
    final encoderRegistry = encoderId != null
        ? [DefaultEncoderRegistry.getEncoder(encoderId) ?? DefaultEncoderRegistry.encoders.first]
        : DefaultEncoderRegistry.encoders;

    return await _bundleWriter.exportBundle(
      outDir: outputDir,
      storageProfile: storageProfile,
      encoderRegistry: encoderRegistry,
      includeEvents: includeEvents,
    );
  }

  /// Import MCP bundle into MIRA
  Future<ImportResult> importFromMcp({
    required Directory bundleDir,
    bool validateChecksums = true,
    bool skipExisting = true,
  }) async {
    _ensureInitialized();

    if (!_flags.miraEnabled) {
      throw StateError('MIRA import disabled by feature flags');
    }

    return await _bundleReader.importBundle(
      bundleDir: bundleDir,
      validateChecksums: validateChecksums,
      skipExisting: skipExisting,
    );
  }

  /// Enhanced export that includes both MIRA and chat data
  Future<McpExportResult> exportToMcpEnhanced({
    required Directory outputDir,
    required List<JournalEntry> journalEntries,
    McpExportScope scope = McpExportScope.all,
    List<MediaItem>? mediaFiles,
    Map<String, dynamic>? customScope,
    bool includeChats = true,
    bool includeArchivedChats = true,
    String? notes,
  }) async {
    _ensureInitialized();

    if (!_flags.miraEnabled) {
      throw StateError('MIRA export disabled by feature flags');
    }

    return await _mcpExportService.exportToMcp(
      outputDir: outputDir,
      scope: scope,
      journalEntries: journalEntries,
      mediaFiles: mediaFiles,
      customScope: customScope,
      includeChats: includeChats,
      includeArchivedChats: includeArchivedChats,
    );
  }

  /// Enhanced import that handles both MIRA and chat data
  Future<McpImportResult> importFromMcpEnhanced({
    required Directory bundleDir,
    McpImportOptions? options,
  }) async {
    _ensureInitialized();

    if (!_flags.miraEnabled) {
      throw StateError('MIRA import disabled by feature flags');
    }

    return await _mcpImportService.importBundle(
      bundleDir,
      options ?? const McpImportOptions(),
    );
  }

  /// ---- Graph Access Convenience API (thin wrappers over repo) ----
  Future<void> addNode(MiraNode node) async {
    _ensureInitialized();
    await _repo.upsertNode(node);
  }

  Future<void> addEdge(MiraEdge edge) async {
    _ensureInitialized();
    await _repo.upsertEdge(edge);
  }

  Future<void> removeNode(String nodeId) async {
    _ensureInitialized();
    await _repo.removeNode(nodeId);
  }

  Future<void> removeEdge(String edgeId) async {
    _ensureInitialized();
    await _repo.removeEdge(edgeId);
  }

  Future<List<MiraNode>> getNodesByType(NodeType type, {int limit = 100}) async {
    _ensureInitialized();
    return _repo.findNodesByType(type, limit: limit);
  }

  Future<List<MiraEdge>> getEdgesBySource(String nodeId, {EdgeType? label}) async {
    _ensureInitialized();
    return _repo.edgesFrom(nodeId, label: label);
  }

  Future<List<MiraEdge>> getEdgesByDestination(String nodeId, {EdgeType? label}) async {
    _ensureInitialized();
    return _repo.edgesTo(nodeId, label: label);
  }

  Future<MiraNode?> getNode(String nodeId) async {
    _ensureInitialized();
    return _repo.getNode(nodeId);
  }

  /// Add semantic data to MIRA
  Future<void> addSemanticData({
    String? entryText,
    List<String>? keywords,
    String? emotion,
    Map<String, dynamic>? sagePhases,
    Map<String, dynamic>? metadata,
  }) async {
    _ensureInitialized();

    if (!_flags.miraEnabled) return;

    final timestamp = DateTime.now();

    // Create entry node if text provided
    if (entryText != null && entryText.trim().isNotEmpty) {
      final entryNode = MiraNode.entry(
        narrative: entryText.trim(),
        keywords: keywords ?? [],
        timestamp: timestamp,
        metadata: metadata ?? {},
      );
      await _repo.upsertNode(entryNode);

      // Create keyword nodes and edges
      if (keywords != null) {
        for (final keyword in keywords) {
          final keywordNode = MiraNode.keyword(text: keyword, timestamp: timestamp);
          await _repo.upsertNode(keywordNode);

          final mentionsEdge = MiraEdge.mentions(
            src: entryNode.id,
            dst: keywordNode.id,
            timestamp: timestamp,
          );
          await _repo.upsertEdge(mentionsEdge);
        }
      }

      // Create emotion node and edge
      if (emotion != null && emotion.trim().isNotEmpty) {
        final emotionNode = MiraNode.emotion(text: emotion, timestamp: timestamp);
        await _repo.upsertNode(emotionNode);

        final expressesEdge = MiraEdge.expresses(
          src: entryNode.id,
          dst: emotionNode.id,
          timestamp: timestamp,
        );
        await _repo.upsertEdge(expressesEdge);
      }

      // Create SAGE phase nodes and edges
      if (sagePhases != null && _flags.miraAdvancedEnabled) {
        for (final entry in sagePhases.entries) {
          final phaseNode = MiraNode.phase(
            text: entry.value.toString(),
            timestamp: timestamp,
            metadata: {'sage_phase': entry.key},
          );
          await _repo.upsertNode(phaseNode);

          final taggedAsEdge = MiraEdge.taggedAs(
            src: entryNode.id,
            dst: phaseNode.id,
            timestamp: timestamp,
          );
          await _repo.upsertEdge(taggedAsEdge);
        }
      }
    }
  }

  /// Retrieve semantic data based on query
  Future<List<MiraNode>> retrieveSemanticData({
    String? query,
    NodeType? nodeType,
    DateTime? since,
    DateTime? until,
    int limit = 50,
  }) async {
    _ensureInitialized();

    if (!_flags.retrievalEnabled) {
      return [];
    }

    if (query != null && query.trim().isNotEmpty) {
      return await _repo.searchNodes(query.trim(), limit: limit);
    }

    if (nodeType != null) {
      return await _repo.findNodesByType(nodeType, limit: limit);
    }

    if (since != null || until != null) {
      return await _repo.getNodesInTimeRange(
        start: since ?? DateTime.fromMillisecondsSinceEpoch(0),
        end: until ?? DateTime.now(),
        limit: limit,
      );
    }

    return await _repo.getRecentEntries(limit: limit);
  }

  /// Get analytics about MIRA data including chat statistics
  Future<Map<String, dynamic>> getAnalytics() async {
    _ensureInitialized();

    final nodeCounts = await _repo.getNodeCounts();
    final edgeCounts = await _repo.getEdgeCounts();
    final recentEntries = await _repo.getRecentEntries(limit: 10);
    final topKeywords = await _repo.getTopKeywords(limit: 20);

    final analytics = {
      'enabled': _flags.miraEnabled,
      'advanced_enabled': _flags.miraAdvancedEnabled,
      'retrieval_enabled': _flags.retrievalEnabled,
      'storage_backend': _flags.useSqliteRepo ? 'sqlite' : 'hive',
      'node_counts': nodeCounts.map((k, v) => MapEntry(k.toString().split('.').last, v)),
      'edge_counts': edgeCounts.map((k, v) => MapEntry(k.toString().split('.').last, v)),
      'total_nodes': nodeCounts.values.fold(0, (sum, count) => sum + count),
      'total_edges': edgeCounts.values.fold(0, (sum, count) => sum + count),
      'recent_entries_count': recentEntries.length,
      'top_keywords_count': topKeywords.length,
    };

    // Add chat analytics if chat repository is available
    if (_chatRepo != null) {
      try {
        final chatStats = await _chatRepo!.getStats();
        analytics['chat'] = {
          'enabled': true,
          'total_sessions': chatStats['total_sessions'] ?? 0,
          'active_sessions': chatStats['active_sessions'] ?? 0,
          'archived_sessions': chatStats['archived_sessions'] ?? 0,
          'pinned_sessions': chatStats['pinned_sessions'] ?? 0,
          'total_messages': chatStats['total_messages'] ?? 0,
        };
      } catch (e) {
        analytics['chat'] = {
          'enabled': true,
          'error': 'Failed to get chat stats: $e',
        };
      }
    } else {
      analytics['chat'] = {
        'enabled': false,
        'reason': 'No chat repository configured',
      };
    }

    return analytics;
  }

  /// Close MIRA service and clean up resources
  Future<void> close() async {
    if (!_initialized) return;

    await _repo.close();
    _initialized = false;
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('MiraService not initialized. Call initialize() first.');
    }
  }

  void _registerHiveAdapters() {
    // Register Hive adapters for MIRA types if not already registered
    // JSON persistence only; no Hive type adapters needed in this implementation
  }

  /// Delete a MIRA node and all associated edges
  Future<void> deleteNode(String nodeId) async {
    _ensureInitialized();
    
    if (!_flags.miraEnabled) {
      print('⚠️ MIRA deletion disabled by feature flags');
      return;
    }

    try {
      print('🔍 MIRA: Deleting node $nodeId and associated edges');
      await _repo.removeNode(nodeId);
      print('✅ MIRA: Successfully deleted node $nodeId');
    } catch (e) {
      print('❌ MIRA: Error deleting node $nodeId: $e');
      rethrow;
    }
  }

  /// Delete edges where node is source or target
  Future<void> deleteEdgesForNode(String nodeId) async {
    _ensureInitialized();
    
    if (!_flags.miraEnabled) {
      print('⚠️ MIRA deletion disabled by feature flags');
      return;
    }

    try {
      // Get all edges where this node is source or target
      final edgesFrom = await _repo.edgesFrom(nodeId);
      final edgesTo = await _repo.edgesTo(nodeId);
      
      final allEdges = [...edgesFrom, ...edgesTo];
      print('🔍 MIRA: Found ${allEdges.length} edges to delete for node $nodeId');
      
      for (final edge in allEdges) {
        await _repo.removeEdge(edge.id);
      }
      
      print('✅ MIRA: Successfully deleted ${allEdges.length} edges for node $nodeId');
    } catch (e) {
      print('❌ MIRA: Error deleting edges for node $nodeId: $e');
      rethrow;
    }
  }

  /// Clean up orphaned keyword nodes (if no other entries reference them)
  Future<void> cleanupOrphanedKeywords(List<String> keywords) async {
    _ensureInitialized();
    
    if (!_flags.miraEnabled) {
      print('⚠️ MIRA cleanup disabled by feature flags');
      return;
    }

    try {
      for (final keyword in keywords) {
        final keywordNodeId = 'kw_${keyword.toLowerCase().replaceAll(' ', '-')}';
        
        // Check if any other entries reference this keyword
        final edgesToKeyword = await _repo.edgesTo(keywordNodeId);
        
        if (edgesToKeyword.isEmpty) {
          print('🔍 MIRA: Deleting orphaned keyword node: $keywordNodeId');
          await _repo.removeNode(keywordNodeId);
        } else {
          print('🔍 MIRA: Keyword $keywordNodeId still referenced by ${edgesToKeyword.length} entries');
        }
      }
    } catch (e) {
      print('❌ MIRA: Error cleaning up orphaned keywords: $e');
      rethrow;
    }
  }
}

/// Convenience extensions for easier MIRA integration
extension MiraServiceExtensions on MiraService {
  /// Quick semantic search
  Future<List<String>> searchNarratives(String query, {int limit = 10}) async {
    final nodes = await retrieveSemanticData(query: query, limit: limit);
    return nodes.map((n) => n.narrative).where((n) => n.isNotEmpty).toList();
  }

  /// Get all keywords
  Future<List<String>> getAllKeywords({int limit = 100}) async {
    final keywords = await repo.getTopKeywords(limit: limit);
    return keywords.map((k) => k.narrative).toList();
  }

  /// Get emotional context
  Future<List<String>> getEmotions({int limit = 50}) async {
    final emotions = await repo.findNodesByType(NodeType.emotion, limit: limit);
    return emotions.map((e) => e.narrative).toList();
  }
}