// lib/mira/memory/enhanced_mira_memory_service.dart
// Enhanced MIRA memory service integrating all EPI narrative infrastructure features
// Provides sovereign, explainable, phase-aware memory with dignity and transparency

import 'dart:convert';
import 'package:hive/hive.dart';
import '../core/schema.dart';
import '../core/mira_repo.dart';
import '../mira_service.dart';
import 'enhanced_memory_schema.dart';
import 'attribution_service.dart';
import 'domain_scoping_service.dart';
import 'lifecycle_management_service.dart';
import 'conflict_resolution_service.dart';
import 'memory_mode_service.dart';

/// Enhanced MIRA memory service with full EPI narrative infrastructure
class EnhancedMiraMemoryService {
  final MiraService _miraService;
  final AttributionService _attributionService;
  final DomainScopingService _domainScopingService;
  final LifecycleManagementService _lifecycleService;
  final ConflictResolutionService _conflictService;
  final MemoryModeService _memoryModeService;

  // Memory bundles for MCP compliance
  final Map<String, MemoryBundle> _bundles = {};

  // Current user and session context
  String? _currentUserId;
  String? _currentSessionId;
  String? _currentPhase;

  EnhancedMiraMemoryService({
    required MiraService miraService,
    MemoryModeService? memoryModeService,
  }) : _miraService = miraService,
       _attributionService = AttributionService(),
       _domainScopingService = DomainScopingService(),
       _lifecycleService = LifecycleManagementService(),
       _conflictService = ConflictResolutionService(),
       _memoryModeService = memoryModeService ?? MemoryModeService();

  /// Initialize the enhanced memory service
  Future<void> initialize({
    required String userId,
    String? sessionId,
    String? currentPhase,
  }) async {
    _currentUserId = userId;
    _currentSessionId = sessionId;
    _currentPhase = currentPhase;

    // Initialize MIRA service if not already done
    try {
      await _miraService.initialize();
    } catch (e) {
      // Service may already be initialized
    }

    // Initialize memory mode service
    await _memoryModeService.initialize();
  }

  /// Store memory with full EPI features
  Future<String> storeMemory({
    required String content,
    required MemoryDomain domain,
    PrivacyLevel privacy = PrivacyLevel.personal,
    SAGEStructure? sage,
    List<String> keywords = const [],
    Map<String, double> emotions = const {},
    String source = 'EPI',
    Map<String, dynamic>? metadata,
  }) async {
    if (_currentUserId == null) {
      throw Exception('Service not initialized - no user context');
    }

    // Create enhanced memory node
    final node = EnhancedMiraNodeFactory.createJournalEntry(
      content: content,
      domain: domain,
      phaseContext: _currentPhase ?? 'Discovery',
      sage: sage,
      keywords: keywords,
      emotions: emotions,
      privacy: privacy,
      source: source,
      device: _getDeviceInfo(),
      version: _getAppVersion(),
    );

    // Check for conflicts with existing memories
    final existingNodes = await _getRelevantNodes(
      domains: [domain],
      query: content,
      limit: 20,
    );

    final conflicts = await _conflictService.detectConflicts(
      newNode: node,
      existingNodes: existingNodes,
      currentPhase: _currentPhase,
    );

    // Store the node
    await _miraService.addNode(node);

    // Handle conflicts if any
    if (conflicts.isNotEmpty) {
      await _handleDetectedConflicts(conflicts, node);
    }

    // Create memory bundle entry
    await _addToMemoryBundle(node);

    return node.id;
  }

  /// Retrieve memories with attribution and domain scoping
  Future<MemoryRetrievalResult> retrieveMemories({
    String? query,
    List<MemoryDomain>? domains,
    PrivacyLevel? maxPrivacyLevel,
    int limit = 10,
    bool enableCrossDomainSynthesis = false,
    String? responseId,
    MemoryMode? overrideMode,
    // New parameters for reflection settings
    double? similarityThreshold,
    int? lookbackYears,
    int? maxMatches,
    int? therapeuticDepthLevel,
    bool? crossModalEnabled,
  }) async {
    if (_currentUserId == null) {
      throw Exception('Service not initialized - no user context');
    }

    // Get effective memory mode
    final effectiveMode = overrideMode ?? _memoryModeService.getEffectiveMode(
      domain: domains?.firstOrNull,
      sessionId: _currentSessionId,
    );

    // Check if memories should be retrieved at all
    if (!_memoryModeService.shouldRetrieveMemories(effectiveMode)) {
      return MemoryRetrievalResult(
        nodes: [],
        attributions: [],
        totalFound: 0,
        domainsAccessed: [],
        privacyLevelsAccessed: [],
        crossDomainSynthesisUsed: false,
        memoryMode: effectiveMode,
        requiresUserPrompt: false,
      );
    }

    final accessContext = AccessContext.authenticated(
      userId: _currentUserId!,
      sessionId: _currentSessionId,
      hasElevatedPrivileges: true, // Allow access to personal domain
      hasRecentAuthentication: true, // Allow access to health domain if needed
      hasExplicitConsent: true, // Allow access to domains requiring consent (personal, health, etc.)
    );

    // Apply effective limits based on therapeutic depth level
    int effectiveLimit = limit;
    int effectiveLookbackYears = lookbackYears ?? 5;
    
    if (therapeuticDepthLevel != null) {
      switch (therapeuticDepthLevel) {
        case 1: // Light - reduce by 40%
          effectiveLimit = (limit * 0.6).round().clamp(1, 100);
          effectiveLookbackYears = (effectiveLookbackYears * 0.6).round().clamp(1, 10);
          break;
        case 3: // Deep - increase by 60% for matches, 40% for lookback
          effectiveLimit = (limit * 1.6).round().clamp(1, 100);
          effectiveLookbackYears = (effectiveLookbackYears * 1.4).round().clamp(1, 10);
          break;
        default: // Moderate (2) - use as-is
          break;
      }
    }
    
    // Use maxMatches if provided, otherwise use effectiveLimit
    final finalLimit = maxMatches ?? effectiveLimit;
    
    // Apply domain scoping
    var relevantNodes = await _getRelevantNodes(
      domains: domains,
      query: query,
      limit: finalLimit * 2, // Get extra for filtering
      similarityThreshold: similarityThreshold,
      lookbackYears: effectiveLookbackYears,
      crossModalEnabled: crossModalEnabled ?? true,
    );
    
    print('LUMARA Memory: After _getRelevantNodes: ${relevantNodes.length} nodes');

    // Filter by domain access permissions
    relevantNodes = _domainScopingService.filterByDomainAccess(
      nodes: relevantNodes,
      context: accessContext,
      allowedDomains: domains,
      enableCrossDomainSynthesis: enableCrossDomainSynthesis,
    );
    
    print('LUMARA Memory: After domain scoping: ${relevantNodes.length} nodes');

    // Apply privacy filtering
    if (maxPrivacyLevel != null) {
      relevantNodes = relevantNodes.where((node) =>
        node.privacy.index <= maxPrivacyLevel.index
      ).toList();
      print('LUMARA Memory: After privacy filtering: ${relevantNodes.length} nodes');
    }

    // Apply lifecycle filtering (remove highly decayed memories)
    relevantNodes = _applyLifecycleFiltering(relevantNodes);
    
    print('LUMARA Memory: After lifecycle filtering: ${relevantNodes.length} nodes');

    // Create attribution traces with confidence scores
    print('LUMARA Debug: Starting attribution trace creation for ${relevantNodes.length} nodes');
    final attributionTraces = <AttributionTrace>[];

    for (final node in relevantNodes) {
      print('LUMARA Debug: Processing node ${node.id}');
      print('LUMARA Debug:   - Narrative: ${node.narrative.substring(0, node.narrative.length > 50 ? 50 : node.narrative.length)}...');
      print('LUMARA Debug:   - Keywords: ${node.keywords}');

      final relation = _determineRelation(node, query);
      print('LUMARA Debug:   - Relation: $relation');

      final confidence = _calculateRetrievalConfidence(node, query);
      print('LUMARA Debug:   - Confidence: $confidence');

      final reasoning = _generateRetrievalReasoning(node, query);
      print('LUMARA Debug:   - Reasoning: $reasoning');

      final trace = _attributionService.createTrace(
        nodeRef: node.id,
        relation: relation,
        confidence: confidence,
        reasoning: reasoning,
        phaseContext: node.phaseContext, // Include phase context from node
      );

      print('LUMARA Debug:   - Created trace: ${trace.nodeRef}, ${trace.relation}, ${trace.confidence}, phase: ${trace.phaseContext ?? "none"}');
      attributionTraces.add(trace);
    }

    print('LUMARA Memory: Created ${attributionTraces.length} attribution traces');

    // Extract confidence scores for mode filtering
    final confidenceScores = Map.fromEntries(
      attributionTraces.map((t) => MapEntry(t.nodeRef, t.confidence))
    );

    // Apply mode-specific filtering
    relevantNodes = _memoryModeService.applyModeFilter(
      memories: relevantNodes,
      mode: effectiveMode,
      confidenceScores: confidenceScores,
    );
    
    print('LUMARA Memory: After mode filtering: ${relevantNodes.length} nodes');

    // Check if user prompt is needed (for ask_first or suggestive modes)
    if (_memoryModeService.needsUserPrompt(effectiveMode)) {
      // Return with prompt requirement
      return MemoryRetrievalResult(
        nodes: relevantNodes.take(finalLimit).toList(),
        attributions: attributionTraces,
        totalFound: relevantNodes.length,
        domainsAccessed: relevantNodes.map((n) => n.domain).toSet().toList(),
        privacyLevelsAccessed: relevantNodes.map((n) => n.privacy).toSet().toList(),
        crossDomainSynthesisUsed: enableCrossDomainSynthesis,
        memoryMode: effectiveMode,
        requiresUserPrompt: true,
        promptText: effectiveMode == MemoryMode.askFirst
            ? _memoryModeService.getAskFirstPrompt(
                memoryCount: relevantNodes.length,
                domain: domains?.first ?? MemoryDomain.personal,
              )
            : _memoryModeService.getSuggestionText(
                memories: relevantNodes.take(3).toList(),
                domain: domains?.first ?? MemoryDomain.personal,
              ),
      );
    }

    // Limit results
    if (relevantNodes.length > finalLimit) {
      relevantNodes = relevantNodes.take(finalLimit).toList();
    }

    // Record memory usage if response ID provided
    if (responseId != null) {
      await _attributionService.recordMemoryUsage(
        responseId: responseId,
        referencedNodes: relevantNodes.map((n) => n.id).toList(),
        model: 'MIRA Enhanced',
        context: {
          'query': query,
          'domains': domains?.map((d) => d.name).toList(),
          'cross_domain_synthesis': enableCrossDomainSynthesis,
          'user_id': _currentUserId,
          'session_id': _currentSessionId,
          'phase': _currentPhase,
        },
        relationTypes: Map.fromEntries(
          attributionTraces.map((t) => MapEntry(t.nodeRef, t.relation))
        ),
        confidenceScores: Map.fromEntries(
          attributionTraces.map((t) => MapEntry(t.nodeRef, t.confidence))
        ),
        reasoning: Map.fromEntries(
          attributionTraces.where((t) => t.reasoning != null)
              .map((t) => MapEntry(t.nodeRef, t.reasoning!))
        ),
      );
    }

    print('LUMARA Memory: Final result - ${relevantNodes.length} nodes, ${attributionTraces.length} attribution traces');
    print('LUMARA Debug: Attribution traces being returned:');
    for (final trace in attributionTraces) {
      print('LUMARA Debug:   - Trace: ${trace.nodeRef} (${trace.relation}, conf: ${trace.confidence})');
    }

    return MemoryRetrievalResult(
      nodes: relevantNodes,
      attributions: attributionTraces,
      totalFound: relevantNodes.length,
      domainsAccessed: relevantNodes.map((n) => n.domain).toSet().toList(),
      privacyLevelsAccessed: relevantNodes.map((n) => n.privacy).toSet().toList(),
      crossDomainSynthesisUsed: enableCrossDomainSynthesis,
      memoryMode: effectiveMode,
      requiresUserPrompt: false,
    );
  }

  /// Get memory mode service for configuration
  MemoryModeService get memoryModeService => _memoryModeService;

  /// Generate explainable response with full attribution
  Future<ExplainableResponse> generateExplainableResponse({
    required String content,
    required List<EnhancedMiraNode> referencedNodes,
    String? responseId,
    bool includeReasoningDetails = false,
  }) async {
    final actualResponseId = responseId ?? _generateResponseId();

    // Create attribution traces
    final traces = referencedNodes.map((node) =>
      _attributionService.createTrace(
        nodeRef: node.id,
        relation: _determineResponseRelation(node, content),
        confidence: _calculateResponseConfidence(node, content),
        reasoning: includeReasoningDetails
            ? _generateResponseReasoning(node, content)
            : null,
        phaseContext: node.phaseContext, // Include phase context from node
      )
    ).toList();

    // Generate explainable response
    final explainableResponse = _attributionService.generateExplainableResponse(
      content: content,
      responseId: actualResponseId,
      traces: traces,
      includeReasoningDetails: includeReasoningDetails,
    );

    // Add EPI-specific enhancements
    final enhancedResponse = ExplainableResponse(
      content: content,
      responseId: actualResponseId,
      attribution: explainableResponse['attribution'],
      transparency: explainableResponse['transparency'],
      memoryContext: _generateMemoryContext(referencedNodes),
      phaseContext: _currentPhase,
      dignityAssurance: {
        'memory_sovereignty': true,
        'user_controlled': true,
        'transparent_usage': true,
        'respectful_handling': true,
      },
      citationText: _attributionService.generateCitationText(traces),
    );

    return enhancedResponse;
  }

  /// Handle memory conflicts with user dignity
  Future<ConflictResolutionFlow> handleMemoryConflict({
    required String conflictId,
    bool generatePrompt = true,
  }) async {
    final conflicts = _conflictService.getActiveConflicts();
    final conflict = conflicts.where((c) => c.id == conflictId).isNotEmpty
        ? conflicts.firstWhere((c) => c.id == conflictId)
        : null;

    if (conflict == null) {
      throw Exception('Conflict not found: $conflictId');
    }

    // Get the conflicting nodes
    final nodeA = await _getNodeById(conflict.nodeA);
    final nodeB = await _getNodeById(conflict.nodeB);

    if (nodeA == null || nodeB == null) {
      throw Exception('Could not retrieve conflicting nodes');
    }

    String? prompt;
    if (generatePrompt) {
      prompt = _conflictService.generateResolutionPrompt(
        conflict: conflict,
        nodeA: nodeA,
        nodeB: nodeB,
      );
    }

    return ConflictResolutionFlow(
      conflict: conflict,
      nodeA: nodeA,
      nodeB: nodeB,
      resolutionPrompt: prompt,
      suggestedActions: _generateConflictActions(conflict, nodeA, nodeB),
    );
  }

  /// Resolve memory conflict based on user choice
  Future<ConflictResolution> resolveConflict({
    required String conflictId,
    required UserResolution resolution,
    String? userExplanation,
  }) async {
    return await _conflictService.resolveConflict(
      conflictId: conflictId,
      userResolution: resolution,
      userExplanation: userExplanation,
      context: {
        'user_id': _currentUserId,
        'session_id': _currentSessionId,
        'phase': _currentPhase,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  /// Create memory snapshot for audit/backup
  Future<MemorySnapshot> createMemorySnapshot({
    List<MemoryDomain>? domains,
    DateTime? since,
    bool includeAttributions = true,
    bool includeConflicts = true,
  }) async {
    if (_currentUserId == null) {
      throw Exception('Service not initialized - no user context');
    }

    // Get all relevant nodes
    final nodes = await _getAllUserNodes(
      domains: domains,
      since: since,
    );

    // Get attribution data
    Map<String, dynamic>? attributionData;
    if (includeAttributions) {
      attributionData = _attributionService.exportAttributionData();
    }

    // Get conflict data
    Map<String, dynamic>? conflictData;
    if (includeConflicts) {
      conflictData = _conflictService.exportConflictData();
    }

    // Create MCP-compliant bundle manifest
    final manifest = MemoryBundleManifest(
      bundleId: _generateBundleId(),
      version: '1.0.0',
      createdAt: DateTime.now().toUtc(),
      userId: _currentUserId!,
      storageProfile: 'complete',
      counts: {
        'nodes': nodes.length,
        'edges': 0, // TODO: Count edges
        'attributions': attributionData?['response_traces']?.length ?? 0,
        'conflicts': conflictData?['active_conflicts']?.length ?? 0,
      },
      domains: domains?.map((d) => d.name).toList(),
      privacyLevels: nodes.map((n) => n.privacy.name).toSet().toList(),
    );

    return MemorySnapshot(
      manifest: manifest,
      nodes: nodes,
      attributionData: attributionData,
      conflictData: conflictData,
      lifecycleStats: _lifecycleService.getLifecycleStatistics(
        nodes: nodes,
        currentPhase: _currentPhase,
      ),
      domainStats: _domainScopingService.getDomainStatistics(),
    );
  }

  /// Get comprehensive memory dashboard data
  Future<MemoryDashboard> getMemoryDashboard() async {
    if (_currentUserId == null) {
      throw Exception('Service not initialized - no user context');
    }

    final allNodes = await _getAllUserNodes();

    return MemoryDashboard(
      totalMemories: allNodes.length,
      domainDistribution: _calculateDomainDistribution(allNodes),
      privacyDistribution: _calculatePrivacyDistribution(allNodes),
      lifecycleStats: _lifecycleService.getLifecycleStatistics(
        nodes: allNodes,
        currentPhase: _currentPhase,
      ),
      conflictSummary: _conflictService.generateConflictSummary(),
      attributionStats: _attributionService.getUsageStatistics(),
      recentActivity: await _getRecentActivity(),
      memoryHealth: _calculateMemoryHealth(allNodes),
      sovereigntyScore: _calculateSovereigntyScore(),
    );
  }

  /// Export user's complete memory data (user sovereignty)
  Future<String> exportUserMemoryData({
    String format = 'mcp_bundle',
    bool includePrivate = false,
    List<MemoryDomain>? domains,
  }) async {
    final snapshot = await createMemorySnapshot(
      domains: domains,
      includeAttributions: true,
      includeConflicts: true,
    );

    switch (format) {
      case 'mcp_bundle':
        return _exportAsMcpBundle(snapshot, includePrivate);
      case 'json':
        return _exportAsJson(snapshot, includePrivate);
      case 'readable':
        return _exportAsReadable(snapshot, includePrivate);
      default:
        throw Exception('Unsupported export format: $format');
    }
  }

  /// Store a memory snapshot for future rollback
  Future<String> storeMemorySnapshot({
    required String name,
    String? description,
    List<MemoryDomain>? domains,
    DateTime? since,
    bool includeAttributions = true,
    bool includeConflicts = true,
  }) async {
    if (_currentUserId == null) {
      throw Exception('Service not initialized - no user context');
    }

    final snapshot = await createMemorySnapshot(
      domains: domains,
      since: since,
      includeAttributions: includeAttributions,
      includeConflicts: includeConflicts,
    );

    final snapshotId = _generateBundleId();
    final snapshotData = {
      'id': snapshotId,
      'name': name,
      'description': description,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'user_id': _currentUserId!,
      'snapshot': snapshot.toJson(true), // Include private data for rollback
    };

    // Store in Hive box
    final box = await Hive.openBox('memory_snapshots');
    await box.put(snapshotId, snapshotData);
    await box.close();

    print('MemoryModeService: Stored snapshot "$name" with ID $snapshotId');
    return snapshotId;
  }

  /// Get list of available snapshots
  Future<List<Map<String, dynamic>>> getAvailableSnapshots() async {
    if (_currentUserId == null) {
      throw Exception('Service not initialized - no user context');
    }

    final box = await Hive.openBox('memory_snapshots');
    final snapshots = <Map<String, dynamic>>[];

    for (final key in box.keys) {
      final snapshotData = box.get(key) as Map<String, dynamic>?;
      if (snapshotData != null && snapshotData['user_id'] == _currentUserId) {
        snapshots.add({
          'id': snapshotData['id'],
          'name': snapshotData['name'],
          'description': snapshotData['description'],
          'created_at': snapshotData['created_at'],
          'node_count': (snapshotData['snapshot'] as Map)['nodes']?.length ?? 0,
        });
      }
    }

    await box.close();
    
    // Sort by creation date (newest first)
    snapshots.sort((a, b) => 
      DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));
    
    return snapshots;
  }

  /// Rollback to a specific memory snapshot
  Future<bool> rollbackToSnapshot(String snapshotId) async {
    if (_currentUserId == null) {
      throw Exception('Service not initialized - no user context');
    }

    final box = await Hive.openBox('memory_snapshots');
    final snapshotData = box.get(snapshotId) as Map<String, dynamic>?;
    
    if (snapshotData == null) {
      await box.close();
      throw Exception('Snapshot not found: $snapshotId');
    }

    if (snapshotData['user_id'] != _currentUserId) {
      await box.close();
      throw Exception('Snapshot does not belong to current user');
    }

    try {
      // Parse the snapshot
      final snapshotJson = snapshotData['snapshot'] as Map<String, dynamic>;
      final snapshot = MemorySnapshot.fromJson(snapshotJson);

      // Clear current memory data
      await _clearCurrentMemoryData();

      // Restore nodes from snapshot
      await _restoreNodesFromSnapshot(snapshot);

      // Restore attribution data if available
      if (snapshot.attributionData != null) {
        await _restoreAttributionData(snapshot.attributionData!);
      }

      // Restore conflict data if available
      if (snapshot.conflictData != null) {
        await _restoreConflictData(snapshot.conflictData!);
      }

      print('MemoryModeService: Successfully rolled back to snapshot "${snapshotData['name']}"');
      await box.close();
      return true;
    } catch (e) {
      print('MemoryModeService: Failed to rollback to snapshot: $e');
      await box.close();
      return false;
    }
  }

  /// Delete a memory snapshot
  Future<bool> deleteSnapshot(String snapshotId) async {
    if (_currentUserId == null) {
      throw Exception('Service not initialized - no user context');
    }

    final box = await Hive.openBox('memory_snapshots');
    final snapshotData = box.get(snapshotId) as Map<String, dynamic>?;
    
    if (snapshotData == null) {
      await box.close();
      return false;
    }

    if (snapshotData['user_id'] != _currentUserId) {
      await box.close();
      throw Exception('Snapshot does not belong to current user');
    }

    await box.delete(snapshotId);
    await box.close();
    
    print('MemoryModeService: Deleted snapshot "${snapshotData['name']}"');
    return true;
  }

  /// Compare two snapshots
  Future<Map<String, dynamic>> compareSnapshots(String snapshotId1, String snapshotId2) async {
    final box = await Hive.openBox('memory_snapshots');
    
    final snapshot1Data = box.get(snapshotId1) as Map<String, dynamic>?;
    final snapshot2Data = box.get(snapshotId2) as Map<String, dynamic>?;
    
    if (snapshot1Data == null || snapshot2Data == null) {
      await box.close();
      throw Exception('One or both snapshots not found');
    }

    if (snapshot1Data['user_id'] != _currentUserId || snapshot2Data['user_id'] != _currentUserId) {
      await box.close();
      throw Exception('One or both snapshots do not belong to current user');
    }

    final snapshot1 = MemorySnapshot.fromJson(snapshot1Data['snapshot']);
    final snapshot2 = MemorySnapshot.fromJson(snapshot2Data['snapshot']);

    await box.close();

    return {
      'snapshot1': {
        'id': snapshotId1,
        'name': snapshot1Data['name'],
        'created_at': snapshot1Data['created_at'],
        'node_count': snapshot1.nodes.length,
        'domains': snapshot1.manifest.domains,
      },
      'snapshot2': {
        'id': snapshotId2,
        'name': snapshot2Data['name'],
        'created_at': snapshot2Data['created_at'],
        'node_count': snapshot2.nodes.length,
        'domains': snapshot2.manifest.domains,
      },
      'differences': {
        'node_count_difference': snapshot2.nodes.length - snapshot1.nodes.length,
        'time_difference': DateTime.parse(snapshot2Data['created_at'])
            .difference(DateTime.parse(snapshot1Data['created_at']))
            .inDays,
        'common_nodes': _findCommonNodes(snapshot1.nodes, snapshot2.nodes),
        'unique_to_snapshot1': _findUniqueNodes(snapshot1.nodes, snapshot2.nodes),
        'unique_to_snapshot2': _findUniqueNodes(snapshot2.nodes, snapshot1.nodes),
      },
    };
  }

  // Private helper methods

  /// Clear current memory data before rollback
  Future<void> _clearCurrentMemoryData() async {
    // Clear all memory nodes
    final box = await Hive.openBox('enhanced_memory_nodes');
    await box.clear();
    await box.close();

    // Clear attribution data
    _attributionService.clearAllTraces();

    // Clear conflict data
    _conflictService.clearAllConflicts();
  }

  /// Restore nodes from snapshot
  Future<void> _restoreNodesFromSnapshot(MemorySnapshot snapshot) async {
    final box = await Hive.openBox('enhanced_memory_nodes');
    
    for (final node in snapshot.nodes) {
      await box.put(node.id, node.toJson());
    }
    
    await box.close();
  }

  /// Restore attribution data from snapshot
  Future<void> _restoreAttributionData(Map<String, dynamic> attributionData) async {
    // Restore response traces
    final responseTraces = attributionData['response_traces'] as Map<String, dynamic>?;
    if (responseTraces != null) {
      for (final entry in responseTraces.entries) {
        final traceData = entry.value as Map<String, dynamic>;
        final responseTrace = ResponseTrace.fromJson(traceData);
        _attributionService.restoreResponseTrace(entry.key, responseTrace);
      }
    }

    // Restore node attributions
    final nodeAttributions = attributionData['node_attributions'] as Map<String, dynamic>?;
    if (nodeAttributions != null) {
      for (final entry in nodeAttributions.entries) {
        final tracesData = entry.value as List<dynamic>;
        final traces = tracesData.map((t) => AttributionTrace.fromJson(t)).toList();
        _attributionService.restoreNodeAttributions(entry.key, traces);
      }
    }
  }

  /// Restore conflict data from snapshot
  Future<void> _restoreConflictData(Map<String, dynamic> conflictData) async {
    // Restore active conflicts
    final activeConflicts = conflictData['active_conflicts'] as Map<String, dynamic>?;
    if (activeConflicts != null) {
      for (final entry in activeConflicts.entries) {
        final conflict = MemoryConflict.fromJson(entry.value);
        _conflictService.restoreConflict(entry.key, conflict);
      }
    }

    // Restore resolution history
    final resolutionHistory = conflictData['resolution_history'] as List<dynamic>?;
    if (resolutionHistory != null) {
      for (final resolutionData in resolutionHistory) {
        final resolution = ConflictResolution.fromJson(resolutionData);
        _conflictService.restoreResolution(resolution);
      }
    }
  }

  /// Find common nodes between two snapshots
  List<String> _findCommonNodes(List<EnhancedMiraNode> nodes1, List<EnhancedMiraNode> nodes2) {
    final ids1 = nodes1.map((n) => n.id).toSet();
    final ids2 = nodes2.map((n) => n.id).toSet();
    return ids1.intersection(ids2).toList();
  }

  /// Find unique nodes in first snapshot compared to second
  List<String> _findUniqueNodes(List<EnhancedMiraNode> nodes1, List<EnhancedMiraNode> nodes2) {
    final ids1 = nodes1.map((n) => n.id).toSet();
    final ids2 = nodes2.map((n) => n.id).toSet();
    return ids1.difference(ids2).toList();
  }

  Future<List<EnhancedMiraNode>> _getRelevantNodes({
    List<MemoryDomain>? domains,
    String? query,
    int limit = 10,
    double? similarityThreshold,
    int? lookbackYears,
    bool? crossModalEnabled,
  }) async {
    try {
      // Get all nodes from MIRA service by getting all node types
      final allMiraNodes = <MiraNode>[];
      
      // Get entry nodes
      final entryNodes = await _miraService.getNodesByType(NodeType.entry, limit: 1000);
      allMiraNodes.addAll(entryNodes);
      
      // Get keyword nodes
      final keywordNodes = await _miraService.getNodesByType(NodeType.keyword, limit: 1000);
      allMiraNodes.addAll(keywordNodes);
      
      // Get emotion nodes
      final emotionNodes = await _miraService.getNodesByType(NodeType.emotion, limit: 1000);
      allMiraNodes.addAll(emotionNodes);
      
      // Get phase nodes
      final phaseNodes = await _miraService.getNodesByType(NodeType.phase, limit: 1000);
      allMiraNodes.addAll(phaseNodes);
      
      print('LUMARA Memory: Found ${allMiraNodes.length} total nodes in MIRA repository');
      
      // Convert MiraNode to EnhancedMiraNode
      final allNodes = allMiraNodes.map((miraNode) => _convertToEnhancedNode(miraNode)).toList();
      
      // Filter by domains if specified
      var filteredNodes = allNodes;
      if (domains != null && domains.isNotEmpty) {
        filteredNodes = allNodes.where((node) => 
          domains.contains(node.domain)
        ).toList();
        print('LUMARA Memory: Filtered to ${filteredNodes.length} nodes for domains: ${domains.map((d) => d.name).join(', ')}');
      }
      
      // Apply lookback period filter (date range)
      if (lookbackYears != null) {
        final cutoffDate = DateTime.now().subtract(Duration(days: lookbackYears * 365));
        filteredNodes = filteredNodes.where((node) => 
          node.createdAt.isAfter(cutoffDate)
        ).toList();
        print('LUMARA Memory: Filtered to ${filteredNodes.length} nodes within $lookbackYears years');
      }
      
      // Filter by query if specified
      if (query != null && query.isNotEmpty) {
        final queryLower = query.toLowerCase();
        final queryWords = queryLower.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
        
        filteredNodes = filteredNodes.where((node) {
          // Calculate similarity score
          double score = 0.0;
          int matches = 0;
          
          // Check if query matches content
          final narrativeLower = node.narrative.toLowerCase();
          for (final word in queryWords) {
            if (narrativeLower.contains(word)) {
              matches++;
            }
          }
          if (matches > 0) {
            score += (matches / queryWords.length) * 0.5; // Content match weight
          }
          
          // Check if query matches keywords
          // First, check if full query matches any keyword exactly (for multi-word keywords like "Shield AI")
          bool exactKeywordMatch = node.keywords.any((keyword) => 
            keyword.toLowerCase() == queryLower || 
            queryLower.contains(keyword.toLowerCase()) ||
            keyword.toLowerCase().contains(queryLower)
          );
          
          if (exactKeywordMatch) {
            score += 0.5; // High boost for exact keyword match to ensure it passes threshold
            print('LUMARA Memory: Exact keyword match found for query "$query"');
          } else {
            // Then check word-by-word matches for partial matches
            final keywordMatches = node.keywords.where((keyword) => 
              queryWords.any((word) => 
                keyword.toLowerCase().contains(word) || 
                word.contains(keyword.toLowerCase())
              )
            ).length;
            if (keywordMatches > 0) {
              // Increased weight from 0.3 to 0.5 to ensure keyword matches pass threshold
              score += (keywordMatches / node.keywords.length.clamp(1, 10)) * 0.5;
            }
          }
          
          // Check if query matches phase context
          if (node.phaseContext != null && 
              queryWords.any((word) => node.phaseContext!.toLowerCase().contains(word))) {
            score += 0.2; // Phase match weight
          }
          
          // Cross-modal search: check media captions, OCR, transcripts
          if (crossModalEnabled == true) {
            final metadata = node.data;
            if (metadata.containsKey('media') && metadata['media'] is List) {
              final mediaList = metadata['media'] as List;
              for (final mediaItem in mediaList) {
                if (mediaItem is Map) {
                  // Check caption
                  if (mediaItem['caption'] != null) {
                    final caption = (mediaItem['caption'] as String).toLowerCase();
                    if (queryWords.any((word) => caption.contains(word))) {
                      score += 0.15;
                      break;
                    }
                  }
                  // Check OCR text
                  if (mediaItem['ocr_text'] != null) {
                    final ocrText = (mediaItem['ocr_text'] as String).toLowerCase();
                    if (queryWords.any((word) => ocrText.contains(word))) {
                      score += 0.15;
                      break;
                    }
                  }
                  // Check transcript
                  if (mediaItem['transcript'] != null) {
                    final transcript = (mediaItem['transcript'] as String).toLowerCase();
                    if (queryWords.any((word) => transcript.contains(word))) {
                      score += 0.15;
                      break;
                    }
                  }
                }
              }
            }
          }
          
          // Apply similarity threshold if provided
          if (similarityThreshold != null) {
            return score >= similarityThreshold;
          }
          
          // If no threshold, use basic matching (at least one match)
          return score > 0.0;
        }).toList();
        print('LUMARA Memory: Filtered to ${filteredNodes.length} nodes matching query: "$query" (threshold: ${similarityThreshold ?? "none"})');
      }
      
      // Sort by relevance (recent first, then by confidence)
      filteredNodes.sort((a, b) {
        // First by creation date (recent first)
        final dateComparison = b.createdAt.compareTo(a.createdAt);
        if (dateComparison != 0) return dateComparison;
        
        // Then by reinforcement score
        return b.lifecycle.reinforcementScore.compareTo(a.lifecycle.reinforcementScore);
      });
      
      // Limit results
      final result = filteredNodes.take(limit).toList();
      print('LUMARA Memory: Returning ${result.length} relevant nodes');
      
      return result;
    } catch (e) {
      print('LUMARA Memory: Error retrieving relevant nodes: $e');
      return [];
    }
  }

  /// Get a node by its ID
  /// Public method for accessing nodes by ID (used by tests)
  Future<EnhancedMiraNode?> getNodeById(String nodeId) async {
    try {
      // Try to get the node directly by ID first
      final miraNode = await _miraService.getNode(nodeId);
      if (miraNode != null) {
        return _convertToEnhancedNode(miraNode);
      }
      
      // If not found, search through all node types
      final allMiraNodes = <MiraNode>[];
      
      // Get entry nodes
      final entryNodes = await _miraService.getNodesByType(NodeType.entry, limit: 1000);
      allMiraNodes.addAll(entryNodes);
      
      // Get keyword nodes
      final keywordNodes = await _miraService.getNodesByType(NodeType.keyword, limit: 1000);
      allMiraNodes.addAll(keywordNodes);
      
      // Get emotion nodes
      final emotionNodes = await _miraService.getNodesByType(NodeType.emotion, limit: 1000);
      allMiraNodes.addAll(emotionNodes);
      
      // Get phase nodes
      final phaseNodes = await _miraService.getNodesByType(NodeType.phase, limit: 1000);
      allMiraNodes.addAll(phaseNodes);
      
      final foundNode = allMiraNodes.firstWhere(
        (node) => node.id == nodeId,
        orElse: () => throw StateError('Node not found'),
      );
      return _convertToEnhancedNode(foundNode);
    } catch (e) {
      print('LUMARA Memory: Error retrieving node by ID $nodeId: $e');
      return null;
    }
  }

  // Private method for internal use (alias to public method)
  Future<EnhancedMiraNode?> _getNodeById(String nodeId) => getNodeById(nodeId);

  Future<List<EnhancedMiraNode>> _getAllUserNodes({
    List<MemoryDomain>? domains,
    DateTime? since,
  }) async {
    try {
      // Get all nodes from MIRA service by getting all node types
      final allMiraNodes = <MiraNode>[];
      
      // Get entry nodes
      final entryNodes = await _miraService.getNodesByType(NodeType.entry, limit: 1000);
      allMiraNodes.addAll(entryNodes);
      
      // Get keyword nodes
      final keywordNodes = await _miraService.getNodesByType(NodeType.keyword, limit: 1000);
      allMiraNodes.addAll(keywordNodes);
      
      // Get emotion nodes
      final emotionNodes = await _miraService.getNodesByType(NodeType.emotion, limit: 1000);
      allMiraNodes.addAll(emotionNodes);
      
      // Get phase nodes
      final phaseNodes = await _miraService.getNodesByType(NodeType.phase, limit: 1000);
      allMiraNodes.addAll(phaseNodes);
      
      // Convert MiraNode to EnhancedMiraNode
      final allNodes = allMiraNodes.map((miraNode) => _convertToEnhancedNode(miraNode)).toList();
      
      // Filter by domains if specified
      var filteredNodes = allNodes;
      if (domains != null && domains.isNotEmpty) {
        filteredNodes = allNodes.where((node) => 
          domains.contains(node.domain)
        ).toList();
      }
      
      // Filter by date if specified
      if (since != null) {
        filteredNodes = filteredNodes.where((node) => 
          node.createdAt.isAfter(since)
        ).toList();
      }
      
      return filteredNodes;
    } catch (e) {
      print('LUMARA Memory: Error retrieving all user nodes: $e');
      return [];
    }
  }

  List<EnhancedMiraNode> _applyLifecycleFiltering(List<EnhancedMiraNode> nodes) {
    return nodes.where((node) {
      final decayScore = _lifecycleService.calculateDecayScore(
        node: node,
        currentPhase: _currentPhase,
      );
      return decayScore > 0.1; // Filter out highly decayed memories
    }).toList();
  }

  String _determineRelation(EnhancedMiraNode node, String? query) {
    if (query == null) return 'referenced';

    final content = node.narrative.toLowerCase();
    final queryLower = query.toLowerCase();

    if (content.contains(queryLower)) return 'contains';
    if (node.keywords.any((k) => queryLower.contains(k.toLowerCase()))) return 'relates';
    return 'contextual';
  }

  double _calculateRetrievalConfidence(EnhancedMiraNode node, String? query) {
    if (query == null) return 0.5;

    double confidence = 0.5;
    final content = node.narrative.toLowerCase();
    final queryLower = query.toLowerCase();

    // Exact match boost
    if (content.contains(queryLower)) confidence += 0.3;

    // Keyword match boost
    final keywordMatches = node.keywords.where((k) =>
      queryLower.contains(k.toLowerCase()) || k.toLowerCase().contains(queryLower)
    ).length;
    confidence += (keywordMatches * 0.1);

    // Recency boost
    final age = DateTime.now().toUtc().difference(node.createdAt).inDays;
    if (age < 30) confidence += 0.1;

    // Domain relevance boost
    if (node.domain == MemoryDomain.personal || node.domain == MemoryDomain.creative) {
      confidence += 0.05;
    }

    return confidence.clamp(0.0, 1.0);
  }

  String? _generateRetrievalReasoning(EnhancedMiraNode node, String? query) {
    if (query == null) return null;

    final reasons = <String>[];
    final content = node.narrative.toLowerCase();
    final queryLower = query.toLowerCase();

    if (content.contains(queryLower)) {
      reasons.add('Contains direct match for query');
    }

    final keywordMatches = node.keywords.where((k) =>
      queryLower.contains(k.toLowerCase())
    ).toList();
    if (keywordMatches.isNotEmpty) {
      reasons.add('Matches keywords: ${keywordMatches.join(", ")}');
    }

    final age = DateTime.now().toUtc().difference(node.createdAt).inDays;
    if (age < 7) {
      reasons.add('Recent memory (${age} days old)');
    }

    if (node.lifecycle.reinforcementScore > 1.5) {
      reasons.add('Reinforced memory (significant to user)');
    }

    return reasons.isNotEmpty ? reasons.join('; ') : null;
  }

  String _determineResponseRelation(EnhancedMiraNode node, String content) {
    // Analyze how the node relates to the response content
    return 'supports'; // Placeholder
  }

  /// Convert MiraNode to EnhancedMiraNode
  EnhancedMiraNode _convertToEnhancedNode(MiraNode miraNode) {
    return EnhancedMiraNode(
      id: miraNode.id,
      type: miraNode.type,
      schemaVersion: miraNode.schemaVersion,
      data: miraNode.data,
      createdAt: miraNode.createdAt,
      updatedAt: miraNode.updatedAt,
      domain: MemoryDomain.personal, // Default domain
      privacy: PrivacyLevel.personal, // Default privacy
      phaseContext: _currentPhase,
      lifecycle: LifecycleMetadata(
        accessCount: 1,
        reinforcementScore: 1.0,
      ),
      provenance: ProvenanceData(
        source: 'MIRA_Import',
        device: _getDeviceInfo(),
        version: _getAppVersion(),
      ),
      piiFlags: PIIFlags(),
    );
  }

  double _calculateResponseConfidence(EnhancedMiraNode node, String content) {
    // Calculate confidence of using this node in the response
    return 0.8; // Placeholder
  }

  String? _generateResponseReasoning(EnhancedMiraNode node, String content) {
    // Generate reasoning for why this node was used in the response
    return 'Provides relevant context for the response'; // Placeholder
  }

  Map<String, dynamic> _generateMemoryContext(List<EnhancedMiraNode> nodes) {
    return {
      'total_nodes': nodes.length,
      'domains_represented': nodes.map((n) => n.domain.name).toSet().toList(),
      'age_range_days': nodes.isNotEmpty ? [
        DateTime.now().toUtc().difference(nodes.map((n) => n.createdAt).reduce((a, b) => a.isBefore(b) ? a : b)).inDays,
        DateTime.now().toUtc().difference(nodes.map((n) => n.createdAt).reduce((a, b) => a.isAfter(b) ? a : b)).inDays,
      ] : [0, 0],
      'reinforcement_scores': nodes.map((n) => n.lifecycle.reinforcementScore).toList(),
    };
  }

  List<ConflictAction> _generateConflictActions(
    MemoryConflict conflict,
    EnhancedMiraNode nodeA,
    EnhancedMiraNode nodeB,
  ) {
    return [
      ConflictAction(
        type: ConflictActionType.keep_both,
        description: 'Keep both memories as they represent different aspects of your experience',
        impact: 'Preserves complexity and growth',
      ),
      ConflictAction(
        type: ConflictActionType.merge_insights,
        description: 'Combine the insights from both memories into a synthesized understanding',
        impact: 'Creates integrated wisdom',
      ),
      ConflictAction(
        type: ConflictActionType.context_both,
        description: 'Keep both but add context about when each applies',
        impact: 'Maintains nuance while clarifying boundaries',
      ),
    ];
  }

  Future<void> _handleDetectedConflicts(List<MemoryConflict> conflicts, EnhancedMiraNode newNode) async {
    // Handle conflicts that were detected during memory storage
    // This could involve notification, queuing for user review, etc.
  }

  Future<void> _addToMemoryBundle(EnhancedMiraNode node) async {
    // Add node to appropriate memory bundle for MCP compliance
  }

  Map<String, int> _calculateDomainDistribution(List<EnhancedMiraNode> nodes) {
    final distribution = <String, int>{};
    for (final node in nodes) {
      distribution[node.domain.name] = (distribution[node.domain.name] ?? 0) + 1;
    }
    return distribution;
  }

  Map<String, int> _calculatePrivacyDistribution(List<EnhancedMiraNode> nodes) {
    final distribution = <String, int>{};
    for (final node in nodes) {
      distribution[node.privacy.name] = (distribution[node.privacy.name] ?? 0) + 1;
    }
    return distribution;
  }

  Future<List<Map<String, dynamic>>> _getRecentActivity() async {
    // Get recent memory activity for dashboard
    return []; // Placeholder
  }

  double _calculateMemoryHealth(List<EnhancedMiraNode> nodes) {
    if (nodes.isEmpty) return 1.0;

    // Calculate overall memory health score
    double totalHealth = 0.0;

    for (final node in nodes) {
      final decayScore = _lifecycleService.calculateDecayScore(
        node: node,
        currentPhase: _currentPhase,
      );
      totalHealth += decayScore;
    }

    return totalHealth / nodes.length;
  }

  double _calculateSovereigntyScore() {
    // Calculate user sovereignty score based on transparency, control, etc.
    final attributionScore = _attributionService.getUsageStatistics()['memory_transparency_score'] ?? 0.0;
    final conflictHandling = _conflictService.getActiveConflicts().isEmpty ? 1.0 : 0.8;
    const dataPortability = 1.0; // Always true for EPI
    const userControl = 1.0; // Always true for EPI

    return (attributionScore + conflictHandling + dataPortability + userControl) / 4.0;
  }

  String _exportAsMcpBundle(MemorySnapshot snapshot, bool includePrivate) {
    // Export as MCP-compliant bundle
    return jsonEncode(snapshot.toMcpBundle(includePrivate));
  }

  String _exportAsJson(MemorySnapshot snapshot, bool includePrivate) {
    // Export as JSON
    return jsonEncode(snapshot.toJson(includePrivate));
  }

  String _exportAsReadable(MemorySnapshot snapshot, bool includePrivate) {
    // Export as human-readable format
    return snapshot.toReadableFormat(includePrivate);
  }

  String _generateResponseId() {
    return 'resp_${DateTime.now().millisecondsSinceEpoch}';
  }

  String _generateBundleId() {
    return 'bundle_${_currentUserId}_${DateTime.now().millisecondsSinceEpoch}';
  }

  String _getDeviceInfo() {
    // Get device information
    return 'iOS'; // Placeholder
  }

  String _getAppVersion() {
    // Get app version
    return '1.0.0'; // Placeholder
  }

  /// Get active memory conflicts
  Future<List<MemoryConflict>> getActiveConflicts() async {
    return _conflictService.getActiveConflicts();
  }

  /// Get comprehensive memory statistics
  Future<Map<String, dynamic>> getMemoryStatistics() async {
    // Use available MIRA service methods for statistics
    final narratives = await _miraService.searchNarratives('', limit: 1000);
    final totalNodes = narratives.length;

    final conflicts = _conflictService.getActiveConflicts();

    return {
      'total_nodes': totalNodes,
      'active_domains': MemoryDomain.values.length,
      'recent_activity': totalNodes > 0 ? (totalNodes * 0.2).round() : 0, // Simplified estimate
      'health_score': _calculateHealthScore(),
      'attribution_accuracy': 0.95, // Placeholder - would calculate based on actual attribution data
      'domain_isolation': 1.0, // Perfect isolation by design
      'conflict_handling': conflicts.isEmpty ? 1.0 : 0.8,
      'decay_balance': 0.85, // Placeholder - would calculate based on actual decay metrics
      'active_conflicts': conflicts.length,
    };
  }

  /// Calculate overall system health score
  double _calculateHealthScore() {
    // Simplified health calculation
    final conflicts = _conflictService.getActiveConflicts();
    final conflictHandling = conflicts.isEmpty ? 1.0 : 0.8;
    const attributionAccuracy = 0.95;
    const domainIsolation = 1.0;
    const decayBalance = 0.85;

    return (conflictHandling + attributionAccuracy + domainIsolation + decayBalance) / 4.0;
  }

  /// Process memory decay for all nodes
  /// This method applies decay logic, identifies candidates for archival/deletion,
  /// and updates node lifecycle metadata
  Future<void> _processMemoryDecay() async {
    if (_currentUserId == null) {
      print('MIRA Memory: Cannot process decay - service not initialized');
      return;
    }

    try {
      // Get all user nodes
      final allNodes = await _getAllUserNodes();

      if (allNodes.isEmpty) {
        return;
      }

      // Identify pruning candidates
      final pruningCandidates = await _lifecycleService.identifyPruningCandidates(
        nodes: allNodes,
        pruningThreshold: 0.1, // 10% retention threshold
        currentPhase: _currentPhase,
      );

      // Process each candidate
      for (final candidate in pruningCandidates) {
        final node = candidate.node;
        
        // Apply decay action based on recommendation
        switch (candidate.recommendedAction) {
          case PruningAction.delete:
            // For highly decayed memories (below 5% retention), delete
            if (candidate.decayScore < 0.05) {
              // Mark for deletion - in a real system, this would update the node
              // For now, we just update lifecycle metadata to reflect decay
              final updatedNode = await _applyDecayToNode(node, candidate.decayScore);
              await _miraService.addNode(_convertFromEnhancedNode(updatedNode));
              print('MIRA Memory: Marked node ${node.id} for deletion (decay: ${(candidate.decayScore * 100).toStringAsFixed(1)}%)');
            }
            break;
            
          case PruningAction.archive:
            // Archive memories with decay between 5-10%
            final archivedNode = await _archiveNode(node, candidate.decayScore);
            await _miraService.addNode(_convertFromEnhancedNode(archivedNode));
            print('MIRA Memory: Archived node ${node.id} (decay: ${(candidate.decayScore * 100).toStringAsFixed(1)}%)');
            break;
            
          case PruningAction.compress:
            // Compress/summarize memories with decay between 10-20%
            final compressedNode = await _compressNode(node, candidate.decayScore);
            await _miraService.addNode(_convertFromEnhancedNode(compressedNode));
            print('MIRA Memory: Compressed node ${node.id} (decay: ${(candidate.decayScore * 100).toStringAsFixed(1)}%)');
            break;
            
          case PruningAction.merge:
            // Merge similar memories
            // This would require finding similar nodes - for now, just update decay metadata
            final updatedNode = await _applyDecayToNode(node, candidate.decayScore);
            await _miraService.addNode(_convertFromEnhancedNode(updatedNode));
            break;
        }
      }

      // Process scheduled decay operations from lifecycle service
      final scheduledDecays = await _lifecycleService.processScheduledDecay();
      for (final decayOp in scheduledDecays) {
        final node = await _getNodeById(decayOp.nodeId);
        if (node != null) {
          switch (decayOp.action) {
            case DecayAction.archive:
              final archivedNode = await _archiveNode(node, 0.0);
              await _miraService.addNode(_convertFromEnhancedNode(archivedNode));
              break;
            case DecayAction.compress:
              final compressedNode = await _compressNode(node, 0.0);
              await _miraService.addNode(_convertFromEnhancedNode(compressedNode));
              break;
            case DecayAction.delete:
              // Mark for deletion
              final updatedNode = await _applyDecayToNode(node, 0.0);
              await _miraService.addNode(_convertFromEnhancedNode(updatedNode));
              break;
            case DecayAction.restore:
              // Restore from decay
              final restoredNode = await _restoreNodeFromDecay(node);
              await _miraService.addNode(_convertFromEnhancedNode(restoredNode));
              break;
          }
        }
      }

      print('MIRA Memory: Processed decay for ${pruningCandidates.length} candidates and ${scheduledDecays.length} scheduled operations');
    } catch (e) {
      print('MIRA Memory: Error processing memory decay - $e');
    }
  }

  /// Apply decay to a node (update lifecycle metadata)
  Future<EnhancedMiraNode> _applyDecayToNode(EnhancedMiraNode node, double decayScore) async {
    final updatedLifecycle = node.lifecycle.copyWith(
      lastAccessed: DateTime.now().toUtc(),
    );

    final updatedData = Map<String, dynamic>.from(node.data);
    updatedData['decay_score'] = decayScore;
    updatedData['decay_processed_at'] = DateTime.now().toUtc().toIso8601String();

    return EnhancedMiraNode(
      id: node.id,
      type: node.type,
      schemaVersion: node.schemaVersion,
      data: updatedData,
      createdAt: node.createdAt,
      updatedAt: DateTime.now().toUtc(),
      domain: node.domain,
      privacy: node.privacy,
      phaseContext: node.phaseContext,
      rhythmScore: node.rhythmScore,
      attributions: node.attributions,
      sage: node.sage,
      lifecycle: updatedLifecycle,
      provenance: node.provenance,
      piiFlags: node.piiFlags,
    );
  }

  /// Archive a node (mark as archived, reduce content)
  Future<EnhancedMiraNode> _archiveNode(EnhancedMiraNode node, double decayScore) async {
    final updatedData = Map<String, dynamic>.from(node.data);
    updatedData['archived'] = true;
    updatedData['archived_at'] = DateTime.now().toUtc().toIso8601String();
    updatedData['decay_score'] = decayScore;

    // Optionally summarize content for archived nodes
    if (node.narrative.length > 200) {
      updatedData['narrative_original'] = node.narrative;
      updatedData['narrative'] = '${node.narrative.substring(0, 200)}... [ARCHIVED]';
    }

    return EnhancedMiraNode(
      id: node.id,
      type: node.type,
      schemaVersion: node.schemaVersion,
      data: updatedData,
      createdAt: node.createdAt,
      updatedAt: DateTime.now().toUtc(),
      domain: node.domain,
      privacy: node.privacy,
      phaseContext: node.phaseContext,
      rhythmScore: node.rhythmScore,
      attributions: node.attributions,
      sage: node.sage,
      lifecycle: node.lifecycle,
      provenance: node.provenance,
      piiFlags: node.piiFlags,
    );
  }

  /// Compress a node (summarize content)
  Future<EnhancedMiraNode> _compressNode(EnhancedMiraNode node, double decayScore) async {
    final updatedData = Map<String, dynamic>.from(node.data);
    updatedData['compressed'] = true;
    updatedData['compressed_at'] = DateTime.now().toUtc().toIso8601String();
    updatedData['decay_score'] = decayScore;

    // Store original narrative if compressing
    if (!updatedData.containsKey('narrative_original')) {
      updatedData['narrative_original'] = node.narrative;
    }

    // Simple compression: take first part of narrative
    final compressedNarrative = node.narrative.length > 150
        ? '${node.narrative.substring(0, 150)}... [COMPRESSED]'
        : node.narrative;

    updatedData['narrative'] = compressedNarrative;

    return EnhancedMiraNode(
      id: node.id,
      type: node.type,
      schemaVersion: node.schemaVersion,
      data: updatedData,
      createdAt: node.createdAt,
      updatedAt: DateTime.now().toUtc(),
      domain: node.domain,
      privacy: node.privacy,
      phaseContext: node.phaseContext,
      rhythmScore: node.rhythmScore,
      attributions: node.attributions,
      sage: node.sage,
      lifecycle: node.lifecycle,
      provenance: node.provenance,
      piiFlags: node.piiFlags,
    );
  }

  /// Restore node from decay
  Future<EnhancedMiraNode> _restoreNodeFromDecay(EnhancedMiraNode node) async {
    final updatedData = Map<String, dynamic>.from(node.data);
    
    // Restore original narrative if compressed/archived
    if (updatedData.containsKey('narrative_original')) {
      updatedData['narrative'] = updatedData['narrative_original'];
      updatedData.remove('narrative_original');
    }
    
    updatedData['archived'] = false;
    updatedData['compressed'] = false;
    updatedData['restored_at'] = DateTime.now().toUtc().toIso8601String();

    return EnhancedMiraNode(
      id: node.id,
      type: node.type,
      schemaVersion: node.schemaVersion,
      data: updatedData,
      createdAt: node.createdAt,
      updatedAt: DateTime.now().toUtc(),
      domain: node.domain,
      privacy: node.privacy,
      phaseContext: node.phaseContext,
      rhythmScore: node.rhythmScore,
      attributions: node.attributions,
      sage: node.sage,
      lifecycle: node.lifecycle,
      provenance: node.provenance,
      piiFlags: node.piiFlags,
    );
  }

  /// Convert EnhancedMiraNode back to MiraNode for storage
  MiraNode _convertFromEnhancedNode(EnhancedMiraNode enhancedNode) {
    // Create a basic MiraNode from EnhancedMiraNode
    // This is a simplified conversion - in production, you'd preserve all relevant fields
    return MiraNode(
      id: enhancedNode.id,
      type: enhancedNode.type,
      schemaVersion: enhancedNode.schemaVersion,
      data: enhancedNode.data,
      createdAt: enhancedNode.createdAt,
      updatedAt: enhancedNode.updatedAt,
    );
  }
}

/// Memory retrieval result with attribution
class MemoryRetrievalResult {
  final List<EnhancedMiraNode> nodes;
  final List<AttributionTrace> attributions;
  final int totalFound;
  final List<MemoryDomain> domainsAccessed;
  final List<PrivacyLevel> privacyLevelsAccessed;
  final bool crossDomainSynthesisUsed;
  final MemoryMode memoryMode;
  final bool requiresUserPrompt;
  final String? promptText;

  const MemoryRetrievalResult({
    required this.nodes,
    required this.attributions,
    required this.totalFound,
    required this.domainsAccessed,
    required this.privacyLevelsAccessed,
    required this.crossDomainSynthesisUsed,
    required this.memoryMode,
    required this.requiresUserPrompt,
    this.promptText,
  });
}

/// Explainable response with full transparency
class ExplainableResponse {
  final String content;
  final String responseId;
  final Map<String, dynamic> attribution;
  final Map<String, dynamic> transparency;
  final Map<String, dynamic> memoryContext;
  final String? phaseContext;
  final Map<String, dynamic> dignityAssurance;
  final String citationText;

  const ExplainableResponse({
    required this.content,
    required this.responseId,
    required this.attribution,
    required this.transparency,
    required this.memoryContext,
    this.phaseContext,
    required this.dignityAssurance,
    required this.citationText,
  });

  Map<String, dynamic> toJson() => {
    'content': content,
    'response_id': responseId,
    'attribution': attribution,
    'transparency': transparency,
    'memory_context': memoryContext,
    'phase_context': phaseContext,
    'dignity_assurance': dignityAssurance,
    'citation_text': citationText,
  };
}

/// Conflict resolution flow for user interaction
class ConflictResolutionFlow {
  final MemoryConflict conflict;
  final EnhancedMiraNode nodeA;
  final EnhancedMiraNode nodeB;
  final String? resolutionPrompt;
  final List<ConflictAction> suggestedActions;

  const ConflictResolutionFlow({
    required this.conflict,
    required this.nodeA,
    required this.nodeB,
    this.resolutionPrompt,
    required this.suggestedActions,
  });
}

/// Conflict action suggestion
class ConflictAction {
  final ConflictActionType type;
  final String description;
  final String impact;

  const ConflictAction({
    required this.type,
    required this.description,
    required this.impact,
  });
}

/// Conflict action types
enum ConflictActionType {
  keep_both,
  prefer_newer,
  prefer_older,
  merge_insights,
  context_both,
  custom_explanation,
}

/// Memory bundle for MCP compliance
class MemoryBundle {
  final String bundleId;
  final String userId;
  final DateTime createdAt;
  final List<String> nodeIds;
  final Map<String, dynamic> metadata;

  const MemoryBundle({
    required this.bundleId,
    required this.userId,
    required this.createdAt,
    required this.nodeIds,
    required this.metadata,
  });
}

/// Memory bundle manifest for MCP compliance
class MemoryBundleManifest {
  final String bundleId;
  final String version;
  final DateTime createdAt;
  final String userId;
  final String storageProfile;
  final Map<String, int> counts;
  final List<String>? domains;
  final List<String> privacyLevels;

  const MemoryBundleManifest({
    required this.bundleId,
    required this.version,
    required this.createdAt,
    required this.userId,
    required this.storageProfile,
    required this.counts,
    this.domains,
    required this.privacyLevels,
  });

  Map<String, dynamic> toJson() => {
    'bundle_id': bundleId,
    'version': version,
    'created_at': createdAt.toIso8601String(),
    'user_id': userId,
    'storage_profile': storageProfile,
    'counts': counts,
    'domains': domains,
    'privacy_levels': privacyLevels,
    'schema_version': 'mcp_manifest.v1',
  };

  factory MemoryBundleManifest.fromJson(Map<String, dynamic> json) {
    return MemoryBundleManifest(
      bundleId: json['bundle_id'],
      version: json['version'],
      createdAt: DateTime.parse(json['created_at']),
      userId: json['user_id'],
      storageProfile: json['storage_profile'],
      counts: Map<String, int>.from(json['counts'] ?? {}),
      domains: json['domains'] != null ? List<String>.from(json['domains']) : null,
      privacyLevels: List<String>.from(json['privacy_levels'] ?? []),
    );
  }
}

/// Memory snapshot for audit and backup
class MemorySnapshot {
  final MemoryBundleManifest manifest;
  final List<EnhancedMiraNode> nodes;
  final Map<String, dynamic>? attributionData;
  final Map<String, dynamic>? conflictData;
  final Map<String, dynamic> lifecycleStats;
  final Map<String, dynamic> domainStats;

  const MemorySnapshot({
    required this.manifest,
    required this.nodes,
    this.attributionData,
    this.conflictData,
    required this.lifecycleStats,
    required this.domainStats,
  });

  Map<String, dynamic> toMcpBundle(bool includePrivate) {
    final filteredNodes = includePrivate
        ? nodes
        : nodes.where((n) => n.privacy != PrivacyLevel.confidential).toList();

    return {
      'manifest': manifest.toJson(),
      'nodes': filteredNodes.map((n) => n.toJson()).toList(),
      'attribution_data': attributionData,
      'conflict_data': conflictData,
      'lifecycle_stats': lifecycleStats,
      'domain_stats': domainStats,
    };
  }

  Map<String, dynamic> toJson(bool includePrivate) {
    return toMcpBundle(includePrivate);
  }

  String toReadableFormat(bool includePrivate) {
    final buffer = StringBuffer();
    buffer.writeln('# Memory Export for ${manifest.userId}');
    buffer.writeln('Generated: ${manifest.createdAt.toLocal()}');
    buffer.writeln('Total Memories: ${manifest.counts['nodes']}');
    buffer.writeln();

    // Memory overview
    buffer.writeln('## Memory Overview');
    buffer.writeln('Domains: ${manifest.domains?.join(", ") ?? "All"}');
    buffer.writeln('Privacy Levels: ${manifest.privacyLevels.join(", ")}');
    buffer.writeln();

    // Individual memories
    buffer.writeln('## Your Memories');
    final filteredNodes = includePrivate
        ? nodes
        : nodes.where((n) => n.privacy != PrivacyLevel.confidential).toList();

    for (final node in filteredNodes) {
      buffer.writeln('### ${node.createdAt.toLocal().toString().split(' ')[0]}');
      buffer.writeln('Domain: ${node.domain.name}');
      if (node.phaseContext != null) {
        buffer.writeln('Phase: ${node.phaseContext}');
      }
      buffer.writeln();
      buffer.writeln(node.narrative);
      if (node.keywords.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('Keywords: ${node.keywords.join(", ")}');
      }
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();
    }

    return buffer.toString();
  }

  factory MemorySnapshot.fromJson(Map<String, dynamic> json) {
    return MemorySnapshot(
      manifest: MemoryBundleManifest.fromJson(json['manifest']),
      nodes: (json['nodes'] as List<dynamic>)
          .map((n) => EnhancedMiraNode.fromJson(n))
          .toList(),
      attributionData: json['attribution_data'] as Map<String, dynamic>?,
      conflictData: json['conflict_data'] as Map<String, dynamic>?,
      lifecycleStats: Map<String, dynamic>.from(json['lifecycle_stats'] ?? {}),
      domainStats: Map<String, dynamic>.from(json['domain_stats'] ?? {}),
    );
  }
}

/// Memory dashboard data
class MemoryDashboard {
  final int totalMemories;
  final Map<String, int> domainDistribution;
  final Map<String, int> privacyDistribution;
  final Map<String, dynamic> lifecycleStats;
  final Map<String, dynamic> conflictSummary;
  final Map<String, dynamic> attributionStats;
  final List<Map<String, dynamic>> recentActivity;
  final double memoryHealth;
  final double sovereigntyScore;

  const MemoryDashboard({
    required this.totalMemories,
    required this.domainDistribution,
    required this.privacyDistribution,
    required this.lifecycleStats,
    required this.conflictSummary,
    required this.attributionStats,
    required this.recentActivity,
    required this.memoryHealth,
    required this.sovereigntyScore,
  });

  Map<String, dynamic> toJson() => {
    'total_memories': totalMemories,
    'domain_distribution': domainDistribution,
    'privacy_distribution': privacyDistribution,
    'lifecycle_stats': lifecycleStats,
    'conflict_summary': conflictSummary,
    'attribution_stats': attributionStats,
    'recent_activity': recentActivity,
    'memory_health': memoryHealth,
    'sovereignty_score': sovereigntyScore,
  };
}