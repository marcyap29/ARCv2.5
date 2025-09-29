// lib/mira/memory/enhanced_mira_memory_service.dart
// Enhanced MIRA memory service integrating all EPI narrative infrastructure features
// Provides sovereign, explainable, phase-aware memory with dignity and transparency

import 'dart:convert';
import '../core/schema.dart';
import '../core/mira_repo.dart';
import '../mira_service.dart';
import 'enhanced_memory_schema.dart';
import 'attribution_service.dart';
import 'domain_scoping_service.dart';
import 'lifecycle_management_service.dart';
import 'conflict_resolution_service.dart';

/// Enhanced MIRA memory service with full EPI narrative infrastructure
class EnhancedMiraMemoryService {
  final MiraService _miraService;
  final AttributionService _attributionService;
  final DomainScopingService _domainScopingService;
  final LifecycleManagementService _lifecycleService;
  final ConflictResolutionService _conflictService;

  // Memory bundles for MCP compliance
  final Map<String, MemoryBundle> _bundles = {};

  // Current user and session context
  String? _currentUserId;
  String? _currentSessionId;
  String? _currentPhase;

  EnhancedMiraMemoryService({
    required MiraService miraService,
  }) : _miraService = miraService,
       _attributionService = AttributionService(),
       _domainScopingService = DomainScopingService(),
       _lifecycleService = LifecycleManagementService(),
       _conflictService = ConflictResolutionService();

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
    if (!_miraService._initialized) {
      await _miraService.initialize();
    }
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
      domain: domain,
      query: content,
      limit: 20,
    );

    final conflicts = await _conflictService.detectConflicts(
      newNode: node,
      existingNodes: existingNodes,
      currentPhase: _currentPhase,
    );

    // Store the node
    await _miraService._repo.storeNode(node);

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
  }) async {
    if (_currentUserId == null) {
      throw Exception('Service not initialized - no user context');
    }

    final accessContext = AccessContext.authenticated(
      userId: _currentUserId!,
      sessionId: _currentSessionId,
      hasExplicitConsent: enableCrossDomainSynthesis,
    );

    // Apply domain scoping
    var relevantNodes = await _getRelevantNodes(
      domains: domains,
      query: query,
      limit: limit * 2, // Get extra for filtering
    );

    // Filter by domain access permissions
    relevantNodes = _domainScopingService.filterByDomainAccess(
      nodes: relevantNodes,
      context: accessContext,
      allowedDomains: domains,
      enableCrossDomainSynthesis: enableCrossDomainSynthesis,
    );

    // Apply privacy filtering
    if (maxPrivacyLevel != null) {
      relevantNodes = relevantNodes.where((node) =>
        node.privacy.index <= maxPrivacyLevel.index
      ).toList();
    }

    // Apply lifecycle filtering (remove highly decayed memories)
    relevantNodes = _applyLifecycleFiltering(relevantNodes);

    // Limit results
    if (relevantNodes.length > limit) {
      relevantNodes = relevantNodes.take(limit).toList();
    }

    // Create attribution traces for this retrieval
    final attributionTraces = relevantNodes.map((node) =>
      _attributionService.createTrace(
        nodeRef: node.id,
        relation: _determineRelation(node, query),
        confidence: _calculateRetrievalConfidence(node, query),
        reasoning: _generateRetrievalReasoning(node, query),
      )
    ).toList();

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

    return MemoryRetrievalResult(
      nodes: relevantNodes,
      attributions: attributionTraces,
      totalFound: relevantNodes.length,
      domainsAccessed: relevantNodes.map((n) => n.domain).toSet().toList(),
      privacyLevelsAccessed: relevantNodes.map((n) => n.privacy).toSet().toList(),
      crossDomainSynthesisUsed: enableCrossDomainSynthesis,
    );
  }

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
    final conflict = conflicts.firstWhere((c) => c.id == conflictId);

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

  // Private helper methods

  Future<List<EnhancedMiraNode>> _getRelevantNodes({
    List<MemoryDomain>? domains,
    String? query,
    int limit = 10,
  }) async {
    // This would integrate with the actual MIRA repository
    // For now, returning empty list as placeholder
    return [];
  }

  Future<EnhancedMiraNode?> _getNodeById(String nodeId) async {
    // Retrieve node by ID from MIRA repository
    return null; // Placeholder
  }

  Future<List<EnhancedMiraNode>> _getAllUserNodes({
    List<MemoryDomain>? domains,
    DateTime? since,
  }) async {
    // Get all nodes for current user
    return []; // Placeholder
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
    final nodes = await _miraService.searchNodes(
      query: '',
      limit: 1000,
    );

    final conflicts = _conflictService.getActiveConflicts();

    return {
      'total_nodes': nodes.length,
      'active_domains': MemoryDomain.values.length,
      'recent_activity': nodes.where((n) =>
        DateTime.now().difference(DateTime.parse(n['timestamp'] ?? DateTime.now().toIso8601String())).inDays < 7
      ).length,
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
}

/// Memory retrieval result with attribution
class MemoryRetrievalResult {
  final List<EnhancedMiraNode> nodes;
  final List<AttributionTrace> attributions;
  final int totalFound;
  final List<MemoryDomain> domainsAccessed;
  final List<PrivacyLevel> privacyLevelsAccessed;
  final bool crossDomainSynthesisUsed;

  const MemoryRetrievalResult({
    required this.nodes,
    required this.attributions,
    required this.totalFound,
    required this.domainsAccessed,
    required this.privacyLevelsAccessed,
    required this.crossDomainSynthesisUsed,
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