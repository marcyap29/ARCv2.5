// lib/mira/mira_integration.dart
// High-level integration helpers for MIRA with existing EPI components

import 'dart:io';
import 'mira_service.dart';
import 'core/flags.dart';
import 'core/schema.dart';
import '../core/arc_llm.dart';
import '../services/llm_bridge_adapter.dart';

class MiraIntegration {
  static MiraIntegration? _instance;
  MiraService? _miraService;
  MiraFlags? _flags;

  MiraIntegration._();

  static MiraIntegration get instance {
    _instance ??= MiraIntegration._();
    return _instance!;
  }

  /// Initialize MIRA integration with feature flags
  Future<void> initialize({
    bool miraEnabled = true,
    bool miraAdvancedEnabled = false,
    bool retrievalEnabled = false,
    bool useSqliteRepo = false,
    String? hiveBoxName,
    dynamic sqliteDatabase,
  }) async {
    _flags = MiraFlags(
      miraEnabled: miraEnabled,
      miraAdvancedEnabled: miraAdvancedEnabled,
      retrievalEnabled: retrievalEnabled,
      useSqliteRepo: useSqliteRepo,
    );

    _miraService = MiraService.instance;
    await _miraService!.initialize(
      flags: _flags,
      hiveBoxName: hiveBoxName,
      sqliteDatabase: sqliteDatabase,
    );
  }

  /// Create MIRA-aware ArcLLM instance
  ArcLLM createArcLLM({required ArcSendFn sendFunction}) {
    return ArcLLM(
      send: sendFunction,
      miraService: _miraService,
    );
  }

  /// Create MIRA-aware LLM bridge adapter
  // ignore: deprecated_member_use_from_same_package
  ArcLLM createLLMBridge({required LLMInvocation sendFunction}) {
    return ArcLLM(
      send: sendFunction,
      miraService: _miraService,
    );
  }

  /// Export MIRA data to MCP bundle
  Future<String?> exportMcpBundle({
    required String outputPath,
    String storageProfile = 'balanced',
    bool includeEvents = false,
  }) async {
    if (_miraService == null || !_flags!.miraEnabled) {
      return null;
    }

    try {
      final outputDir = Directory(outputPath);
      final result = await _miraService!.exportToMcp(
        outputDir: outputDir,
        storageProfile: storageProfile,
        includeEvents: includeEvents,
      );
      return result.path;
    } catch (e) {
      return null;
    }
  }

  /// Import MCP bundle into MIRA
  Future<Map<String, dynamic>?> importMcpBundle({
    required String bundlePath,
    bool validateChecksums = true,
    bool skipExisting = true,
  }) async {
    if (_miraService == null || !_flags!.miraEnabled) {
      return null;
    }

    try {
      final bundleDir = Directory(bundlePath);
      final result = await _miraService!.importFromMcp(
        bundleDir: bundleDir,
        validateChecksums: validateChecksums,
        skipExisting: skipExisting,
      );

      return {
        'success': !result.hasErrors,
        'imported': result.imported,
        'skipped': result.skipped,
        'errors': result.errors,
        'total_imported': result.totalImported,
        'total_skipped': result.totalSkipped,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get MIRA analytics and status
  Future<Map<String, dynamic>> getStatus() async {
    if (_miraService == null) {
      return {
        'initialized': false,
        'enabled': false,
      };
    }

    final analytics = await _miraService!.getAnalytics();
    return {
      'initialized': true,
      'flags': {
        'mira_enabled': _flags!.miraEnabled,
        'mira_advanced_enabled': _flags!.miraAdvancedEnabled,
        'retrieval_enabled': _flags!.retrievalEnabled,
        'use_sqlite_repo': _flags!.useSqliteRepo,
      },
      'analytics': analytics,
    };
  }

  /// Search semantic memory
  Future<List<Map<String, dynamic>>> searchMemory({
    String? query,
    String? nodeType,
    DateTime? since,
    DateTime? until,
    int limit = 50,
  }) async {
    if (_miraService == null || !_flags!.retrievalEnabled) {
      return [];
    }

    NodeType? type;
    if (nodeType != null) {
      type = _parseNodeType(nodeType);
    }

    final nodes = await _miraService!.retrieveSemanticData(
      query: query,
      nodeType: type,
      since: since,
      until: until,
      limit: limit,
    );

    return nodes.map((node) => {
      'id': node.id,
      'type': node.type.toString().split('.').last,
      'narrative': node.narrative,
      'keywords': node.keywords,
      'timestamp': node.timestamp.toIso8601String(),
      'metadata': node.metadata,
    }).toList();
  }

  /// Add semantic data manually
  Future<bool> addSemanticData({
    String? entryText,
    List<String>? keywords,
    String? emotion,
    Map<String, dynamic>? sagePhases,
    Map<String, dynamic>? metadata,
  }) async {
    if (_miraService == null || !_flags!.miraEnabled) {
      return false;
    }

    try {
      await _miraService!.addSemanticData(
        entryText: entryText,
        keywords: keywords,
        emotion: emotion,
        sagePhases: sagePhases,
        metadata: metadata,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get recent entries
  Future<List<Map<String, dynamic>>> getRecentEntries({int limit = 10}) async {
    if (_miraService == null || !_flags!.retrievalEnabled) {
      return [];
    }

    final nodes = await _miraService!.repo.getRecentEntries(limit: limit);
    return nodes.map((node) => {
      'id': node.id,
      'type': node.type.toString().split('.').last,
      'narrative': node.narrative,
      'keywords': node.keywords,
      'timestamp': node.timestamp.toIso8601String(),
      'metadata': node.metadata,
    }).toList();
  }

  /// Get top keywords
  Future<List<String>> getTopKeywords({int limit = 20}) async {
    if (_miraService == null || !_flags!.retrievalEnabled) {
      return [];
    }

    final keywords = await _miraService!.repo.getTopKeywords(limit: limit);
    return keywords.map((k) => k.narrative).toList();
  }

  /// Clear all MIRA data
  Future<bool> clearAllData() async {
    if (_miraService == null || !_flags!.miraEnabled) {
      return false;
    }

    try {
      await _miraService!.repo.clearAll();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Close MIRA integration
  Future<void> close() async {
    if (_miraService != null) {
      await _miraService!.close();
      _miraService = null;
    }
    _flags = null;
  }

  NodeType? _parseNodeType(String typeStr) {
    switch (typeStr.toLowerCase()) {
      case 'entry': return NodeType.entry;
      case 'keyword': return NodeType.keyword;
      case 'emotion': return NodeType.emotion;
      case 'phase': return NodeType.phase;
      case 'period': return NodeType.period;
      case 'topic': return NodeType.topic;
      case 'concept': return NodeType.concept;
      case 'episode': return NodeType.episode;
      case 'summary': return NodeType.summary;
      case 'evidence': return NodeType.evidence;
      default: return null;
    }
  }
}

/// Utility class for managing MIRA feature flags
class MiraFeatureFlags {
  static const String _miraEnabledKey = 'mira_enabled';
  static const String _miraAdvancedEnabledKey = 'mira_advanced_enabled';
  static const String _retrievalEnabledKey = 'mira_retrieval_enabled';
  static const String _useSqliteRepoKey = 'mira_use_sqlite_repo';

  /// Load flags from storage (placeholder - implement with shared_preferences)
  static Future<MiraFlags> loadFromStorage() async {
    // TODO: Implement with shared_preferences or similar
    return MiraFlags.defaults();
  }

  /// Save flags to storage (placeholder - implement with shared_preferences)
  static Future<void> saveToStorage(MiraFlags flags) async {
    // TODO: Implement with shared_preferences or similar
  }

  /// Get default development flags
  static MiraFlags developmentDefaults() {
    return const MiraFlags(
      miraEnabled: true,
      miraAdvancedEnabled: true,
      retrievalEnabled: true,
      useSqliteRepo: false,
    );
  }

  /// Get production flags
  static MiraFlags productionDefaults() {
    return const MiraFlags(
      miraEnabled: true,
      miraAdvancedEnabled: false,
      retrievalEnabled: false,
      useSqliteRepo: false,
    );
  }
}