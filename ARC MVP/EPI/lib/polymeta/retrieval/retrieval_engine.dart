// lib/mira/retrieval/retrieval_engine.dart
// MIRA Retrieval Engine with Composite Scoring and Phase Affinity
// Implements advanced ranking algorithms for memory retrieval

import 'dart:math';
import '../core/schema_v2.dart';
import '../policy/policy_engine.dart';

/// Retrieval result with scoring details
class RetrievalResult {
  final MiraNodeV2 node;
  final double compositeScore;
  final double semanticScore;
  final double recencyScore;
  final double phaseAffinityScore;
  final double domainMatchScore;
  final double engagementScore;
  final String reasoning;
  final Map<String, dynamic> metadata;

  const RetrievalResult({
    required this.node,
    required this.compositeScore,
    required this.semanticScore,
    required this.recencyScore,
    required this.phaseAffinityScore,
    required this.domainMatchScore,
    required this.engagementScore,
    required this.reasoning,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'node_id': node.id,
    'composite_score': compositeScore,
    'semantic_score': semanticScore,
    'recency_score': recencyScore,
    'phase_affinity_score': phaseAffinityScore,
    'domain_match_score': domainMatchScore,
    'engagement_score': engagementScore,
    'reasoning': reasoning,
    'metadata': metadata,
  };
}

/// Memory Use Record (MUR) for attribution
class MemoryUseRecord {
  final String murVersion;
  final String responseId;
  final List<UsedMemory> used;
  final int consideredCount;
  final Map<String, dynamic> filters;
  final DateTime timestamp;

  const MemoryUseRecord({
    required this.murVersion,
    required this.responseId,
    required this.used,
    required this.consideredCount,
    required this.filters,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'mur_version': murVersion,
    'response_id': responseId,
    'used': used.map((u) => u.toJson()).toList(),
    'considered_count': consideredCount,
    'filters': filters,
    'timestamp': timestamp.toUtc().toIso8601String(),
  };
}

/// Used memory entry
class UsedMemory {
  final String id;
  final String role;
  final double weight;
  final String reason;

  const UsedMemory({
    required this.id,
    required this.role,
    required this.weight,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'weight': weight,
    'reason': reason,
  };
}

/// Phase vector for affinity calculation
class PhaseVector {
  final List<double> values;
  final String phase;
  final DateTime timestamp;

  const PhaseVector({
    required this.values,
    required this.phase,
    required this.timestamp,
  });

  /// Calculate cosine similarity with another phase vector
  double cosineSimilarity(PhaseVector other) {
    if (values.length != other.values.length) return 0.0;
    
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    
    for (int i = 0; i < values.length; i++) {
      dotProduct += values[i] * other.values[i];
      normA += values[i] * values[i];
      normB += other.values[i] * other.values[i];
    }
    
    if (normA == 0.0 || normB == 0.0) return 0.0;
    
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }
}

/// Retrieval engine with composite scoring
class RetrievalEngine {
  final PolicyEngine _policyEngine;
  final List<String> _hardNegatives;
  final Map<String, PhaseVector> _phaseVectors;

  // Scoring weights (must sum to 1.0)
  static const double SEMANTIC_WEIGHT = 0.45;
  static const double RECENCY_WEIGHT = 0.20;
  static const double PHASE_AFFINITY_WEIGHT = 0.15;
  static const double DOMAIN_MATCH_WEIGHT = 0.10;
  static const double ENGAGEMENT_WEIGHT = 0.10;

  // Maximum memories per response
  static const int MAX_MEMORIES_PER_RESPONSE = 8;

  RetrievalEngine({
    required PolicyEngine policyEngine,
    List<String>? hardNegatives,
    Map<String, PhaseVector>? phaseVectors,
  }) : _policyEngine = policyEngine,
       _hardNegatives = hardNegatives ?? [],
       _phaseVectors = phaseVectors ?? {};

  /// Retrieve memories with composite scoring
  Future<List<RetrievalResult>> retrieveMemories({
    required String query,
    required List<MemoryDomain> domains,
    required String actor,
    required Purpose purpose,
    PrivacyLevel maxPrivacyLevel = PrivacyLevel.personal,
    int limit = 50,
    String? currentPhase,
    Map<String, dynamic>? context,
  }) async {
    // Get all candidate nodes
    final candidates = await _getCandidateNodes(domains, maxPrivacyLevel);
    
    // Filter by policy
    final policyFiltered = candidates.where((node) {
      final decision = _policyEngine.checkAccess(
        domain: node.metadata['domain'] as MemoryDomain? ?? MemoryDomain.personal,
        privacyLevel: node.metadata['privacy'] as PrivacyLevel? ?? PrivacyLevel.personal,
        actor: actor,
        purpose: purpose,
        context: context,
      );
      return decision.allowed;
    }).toList();

    // Remove hard negatives
    final filteredCandidates = policyFiltered.where((node) => 
      !_hardNegatives.contains(node.id)
    ).toList();

    // Calculate composite scores
    final results = <RetrievalResult>[];
    for (final node in filteredCandidates) {
      final result = _calculateCompositeScore(
        node: node,
        query: query,
        domains: domains,
        currentPhase: currentPhase,
      );
      results.add(result);
    }

    // Sort by composite score (descending)
    results.sort((a, b) => b.compositeScore.compareTo(a.compositeScore));

    // Limit to requested number
    final limitedResults = results.take(limit).toList();

    return limitedResults;
  }

  /// Get candidate nodes (placeholder - would integrate with repository)
  Future<List<MiraNodeV2>> _getCandidateNodes(
    List<MemoryDomain> domains,
    PrivacyLevel maxPrivacyLevel,
  ) async {
    // This would integrate with the actual repository
    // For now, return empty list
    return [];
  }

  /// Calculate composite score for a node
  RetrievalResult _calculateCompositeScore({
    required MiraNodeV2 node,
    required String query,
    required List<MemoryDomain> domains,
    String? currentPhase,
  }) {
    // Calculate individual scores
    final semanticScore = _calculateSemanticScore(node, query);
    final recencyScore = _calculateRecencyScore(node);
    final phaseAffinityScore = _calculatePhaseAffinityScore(node, currentPhase);
    final domainMatchScore = _calculateDomainMatchScore(node, domains);
    final engagementScore = _calculateEngagementScore(node);

    // Calculate composite score
    final compositeScore = 
        semanticScore * SEMANTIC_WEIGHT +
        recencyScore * RECENCY_WEIGHT +
        phaseAffinityScore * PHASE_AFFINITY_WEIGHT +
        domainMatchScore * DOMAIN_MATCH_WEIGHT +
        engagementScore * ENGAGEMENT_WEIGHT;

    // Generate reasoning
    final reasoning = _generateReasoning(
      node: node,
      semanticScore: semanticScore,
      recencyScore: recencyScore,
      phaseAffinityScore: phaseAffinityScore,
      domainMatchScore: domainMatchScore,
      engagementScore: engagementScore,
    );

    return RetrievalResult(
      node: node,
      compositeScore: compositeScore,
      semanticScore: semanticScore,
      recencyScore: recencyScore,
      phaseAffinityScore: phaseAffinityScore,
      domainMatchScore: domainMatchScore,
      engagementScore: engagementScore,
      reasoning: reasoning,
      metadata: {
        'query': query,
        'domains': domains.map((d) => d.name).toList(),
        'current_phase': currentPhase,
      },
    );
  }

  /// Calculate semantic score based on content similarity
  double _calculateSemanticScore(MiraNodeV2 node, String query) {
    final content = node.narrative.toLowerCase();
    final queryLower = query.toLowerCase();
    
    // Exact match boost
    if (content.contains(queryLower)) {
      return 1.0;
    }
    
    // Keyword match
    final keywords = node.keywords;
    final keywordMatches = keywords.where((keyword) =>
      queryLower.contains(keyword.toLowerCase()) ||
      keyword.toLowerCase().contains(queryLower)
    ).length;
    
    if (keywords.isNotEmpty) {
      return (keywordMatches / keywords.length).clamp(0.0, 1.0);
    }
    
    // Basic text similarity (simplified)
    final words = queryLower.split(' ');
    final contentWords = content.split(' ');
    final commonWords = words.where((word) => contentWords.contains(word)).length;
    
    return (commonWords / words.length).clamp(0.0, 1.0);
  }

  /// Calculate recency score
  double _calculateRecencyScore(MiraNodeV2 node) {
    final age = DateTime.now().difference(node.createdAt).inDays;
    
    // Exponential decay: newer = higher score
    if (age <= 1) return 1.0;
    if (age <= 7) return 0.8;
    if (age <= 30) return 0.6;
    if (age <= 90) return 0.4;
    if (age <= 365) return 0.2;
    
    return 0.1;
  }

  /// Calculate phase affinity score
  double _calculatePhaseAffinityScore(MiraNodeV2 node, String? currentPhase) {
    if (currentPhase == null) return 0.5;
    
    final nodePhase = node.metadata['phase_context'] as String?;
    if (nodePhase == null) return 0.5;
    
    // Exact phase match
    if (nodePhase == currentPhase) return 1.0;
    
    // Phase similarity (simplified)
    final phaseSimilarity = _calculatePhaseSimilarity(nodePhase, currentPhase);
    return phaseSimilarity;
  }

  /// Calculate phase similarity (simplified)
  double _calculatePhaseSimilarity(String phase1, String phase2) {
    // This would use more sophisticated phase similarity
    // For now, use simple string similarity
    if (phase1 == phase2) return 1.0;
    
    final phases = ['Discovery', 'Expansion', 'Transition', 'Consolidation', 'Recovery', 'Breakthrough'];
    final index1 = phases.indexOf(phase1);
    final index2 = phases.indexOf(phase2);
    
    if (index1 == -1 || index2 == -1) return 0.5;
    
    // Adjacent phases have higher similarity
    final distance = (index1 - index2).abs();
    if (distance == 1) return 0.7;
    if (distance == 2) return 0.5;
    if (distance == 3) return 0.3;
    
    return 0.1;
  }

  /// Calculate domain match score
  double _calculateDomainMatchScore(MiraNodeV2 node, List<MemoryDomain> domains) {
    final nodeDomain = node.metadata['domain'] as MemoryDomain?;
    if (nodeDomain == null) return 0.5;
    
    if (domains.contains(nodeDomain)) return 1.0;
    
    // Cross-domain similarity (simplified)
    return 0.3;
  }

  /// Calculate engagement score
  double _calculateEngagementScore(MiraNodeV2 node) {
    final accessCount = node.metadata['access_count'] as int? ?? 0;
    final isPinned = node.metadata['is_pinned'] as bool? ?? false;
    final reinforcementScore = node.metadata['reinforcement_score'] as double? ?? 1.0;
    
    // Base score from reinforcement
    double score = reinforcementScore;
    
    // Access count boost
    if (accessCount > 0) {
      score += (accessCount / 100.0).clamp(0.0, 0.3);
    }
    
    // Pinned boost
    if (isPinned) {
      score += 0.2;
    }
    
    return score.clamp(0.0, 1.0);
  }

  /// Generate human-readable reasoning
  String _generateReasoning({
    required MiraNodeV2 node,
    required double semanticScore,
    required double recencyScore,
    required double phaseAffinityScore,
    required double domainMatchScore,
    required double engagementScore,
  }) {
    final reasons = <String>[];
    
    if (semanticScore > 0.8) {
      reasons.add('highly relevant content');
    } else if (semanticScore > 0.5) {
      reasons.add('somewhat relevant content');
    }
    
    if (recencyScore > 0.8) {
      reasons.add('very recent');
    } else if (recencyScore > 0.5) {
      reasons.add('recent');
    }
    
    if (phaseAffinityScore > 0.8) {
      reasons.add('matches current life phase');
    }
    
    if (domainMatchScore > 0.8) {
      reasons.add('matches requested domain');
    }
    
    if (engagementScore > 0.8) {
      reasons.add('highly engaged with');
    }
    
    if (reasons.isEmpty) {
      return 'general relevance';
    }
    
    return reasons.join(', ');
  }

  /// Create Memory Use Record
  MemoryUseRecord createMemoryUseRecord({
    required String responseId,
    required List<RetrievalResult> results,
    required int consideredCount,
    required Map<String, dynamic> filters,
  }) {
    // Limit to max memories per response
    final limitedResults = results.take(MAX_MEMORIES_PER_RESPONSE).toList();
    
    final used = limitedResults.map((result) => UsedMemory(
      id: result.node.id,
      role: 'support',
      weight: result.compositeScore,
      reason: result.reasoning,
    )).toList();
    
    return MemoryUseRecord(
      murVersion: '0.2.0',
      responseId: responseId,
      used: used,
      consideredCount: consideredCount,
      filters: filters,
      timestamp: DateTime.now().toUtc(),
    );
  }

  /// Add hard negative
  void addHardNegative(String nodeId) {
    if (!_hardNegatives.contains(nodeId)) {
      _hardNegatives.add(nodeId);
    }
  }

  /// Remove hard negative
  void removeHardNegative(String nodeId) {
    _hardNegatives.remove(nodeId);
  }

  /// Get hard negatives
  List<String> getHardNegatives() => List.unmodifiable(_hardNegatives);

  /// Update phase vector
  void updatePhaseVector(String phase, PhaseVector vector) {
    _phaseVectors[phase] = vector;
  }

  /// Get phase vector
  PhaseVector? getPhaseVector(String phase) => _phaseVectors[phase];

  /// Get all phase vectors
  Map<String, PhaseVector> getPhaseVectors() => Map.unmodifiable(_phaseVectors);
}
