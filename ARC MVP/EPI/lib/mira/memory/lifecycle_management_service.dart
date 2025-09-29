// lib/mira/memory/lifecycle_management_service.dart
// Lifecycle and decay management service for EPI memory system
// Implements VEIL hooks for natural memory decay, reinforcement, and pruning

import 'dart:math';
import '../core/schema.dart';
import 'enhanced_memory_schema.dart';

/// Service for managing memory lifecycle, decay, and reinforcement
class LifecycleManagementService {
  /// Decay strategies by memory domain
  final Map<MemoryDomain, DecayStrategy> _decayStrategies = {};

  /// Reinforcement rules
  final Map<String, ReinforcementRule> _reinforcementRules = {};

  /// VEIL integration hooks
  final Map<String, VeilHook> _veilHooks = {};

  /// Phase-aware decay multipliers (ATLAS integration)
  final Map<String, double> _phaseDecayMultipliers = {};

  LifecycleManagementService() {
    _initializeDefaultStrategies();
    _initializePhaseMultipliers();
  }

  /// Initialize default decay strategies for each domain
  void _initializeDefaultStrategies() {
    // Personal memories - gradual decay but strong reinforcement potential
    _decayStrategies[MemoryDomain.personal] = DecayStrategy(
      baseDecayRate: 0.02, // 2% per month
      reinforcementSensitivity: 0.8,
      minRetentionScore: 0.1,
      maxAge: const Duration(days: 365 * 5),
      decayFunction: DecayFunction.logarithmic,
    );

    // Work memories - faster decay, less emotional attachment
    _decayStrategies[MemoryDomain.work] = DecayStrategy(
      baseDecayRate: 0.05, // 5% per month
      reinforcementSensitivity: 0.6,
      minRetentionScore: 0.2,
      maxAge: const Duration(days: 365 * 3),
      decayFunction: DecayFunction.exponential,
    );

    // Health memories - very slow decay, high importance
    _decayStrategies[MemoryDomain.health] = DecayStrategy(
      baseDecayRate: 0.01, // 1% per month
      reinforcementSensitivity: 0.9,
      minRetentionScore: 0.05,
      maxAge: const Duration(days: 365 * 10),
      decayFunction: DecayFunction.linear,
    );

    // Creative memories - very slow decay, inspiration value
    _decayStrategies[MemoryDomain.creative] = DecayStrategy(
      baseDecayRate: 0.015, // 1.5% per month
      reinforcementSensitivity: 0.85,
      minRetentionScore: 0.1,
      maxAge: const Duration(days: 365 * 10),
      decayFunction: DecayFunction.logarithmic,
    );

    // Learning memories - moderate decay, knowledge building
    _decayStrategies[MemoryDomain.learning] = DecayStrategy(
      baseDecayRate: 0.03, // 3% per month
      reinforcementSensitivity: 0.75,
      minRetentionScore: 0.15,
      maxAge: const Duration(days: 365 * 7),
      decayFunction: DecayFunction.spaced_repetition,
    );

    // Relationship memories - slow decay, emotional significance
    _decayStrategies[MemoryDomain.relationships] = DecayStrategy(
      baseDecayRate: 0.02, // 2% per month
      reinforcementSensitivity: 0.85,
      minRetentionScore: 0.1,
      maxAge: const Duration(days: 365 * 8),
      decayFunction: DecayFunction.logarithmic,
    );

    // Finance memories - structured decay with regulatory compliance
    _decayStrategies[MemoryDomain.finance] = DecayStrategy(
      baseDecayRate: 0.01, // 1% per month
      reinforcementSensitivity: 0.5,
      minRetentionScore: 0.3,
      maxAge: const Duration(days: 365 * 7),
      decayFunction: DecayFunction.step_wise,
    );

    // Spiritual memories - very slow decay, deep meaning
    _decayStrategies[MemoryDomain.spiritual] = DecayStrategy(
      baseDecayRate: 0.005, // 0.5% per month
      reinforcementSensitivity: 0.95,
      minRetentionScore: 0.05,
      maxAge: const Duration(days: 365 * 15),
      decayFunction: DecayFunction.logarithmic,
    );

    // Meta memories - moderate decay, system housekeeping
    _decayStrategies[MemoryDomain.meta] = DecayStrategy(
      baseDecayRate: 0.08, // 8% per month
      reinforcementSensitivity: 0.4,
      minRetentionScore: 0.3,
      maxAge: const Duration(days: 365 * 2),
      decayFunction: DecayFunction.exponential,
    );
  }

  /// Initialize ATLAS phase decay multipliers
  void _initializePhaseMultipliers() {
    // Discovery - retain everything, high curiosity
    _phaseDecayMultipliers['Discovery'] = 0.5; // 50% slower decay

    // Expansion - selective retention, focus on growth
    _phaseDecayMultipliers['Expansion'] = 0.8; // 20% slower decay

    // Transition - accelerated pruning, change focus
    _phaseDecayMultipliers['Transition'] = 1.5; // 50% faster decay

    // Consolidation - strong retention, integration
    _phaseDecayMultipliers['Consolidation'] = 0.6; // 40% slower decay

    // Recovery - gentle retention, healing focus
    _phaseDecayMultipliers['Recovery'] = 0.7; // 30% slower decay

    // Breakthrough - selective reinforcement, achievement focus
    _phaseDecayMultipliers['Breakthrough'] = 0.9; // 10% slower decay
  }

  /// Calculate decay score for a memory node
  double calculateDecayScore({
    required EnhancedMiraNode node,
    DateTime? currentTime,
    String? currentPhase,
  }) {
    final now = currentTime ?? DateTime.now().toUtc();
    final age = now.difference(node.createdAt);
    final strategy = _decayStrategies[node.domain];

    if (strategy == null) return 1.0; // No decay if no strategy

    // Base decay calculation
    double decayScore = strategy.calculateDecay(age, node.lifecycle.reinforcementScore);

    // Apply phase-specific multiplier
    if (currentPhase != null && _phaseDecayMultipliers.containsKey(currentPhase)) {
      final phaseMultiplier = _phaseDecayMultipliers[currentPhase]!;
      decayScore = (decayScore * phaseMultiplier).clamp(0.0, 1.0);
    }

    // Apply VEIL hooks if any
    for (final hook in _veilHooks.values) {
      if (hook.appliesToNode(node)) {
        decayScore = hook.modifyDecayScore(decayScore, node);
      }
    }

    return decayScore.clamp(0.0, 1.0);
  }

  /// Apply reinforcement to a memory node
  EnhancedMiraNode reinforceMemory({
    required EnhancedMiraNode node,
    required ReinforcementType type,
    double strength = 1.0,
    String? reason,
  }) {
    final strategy = _decayStrategies[node.domain];
    if (strategy == null) return node;

    // Calculate reinforcement effect
    final reinforcementEffect = strategy.reinforcementSensitivity * strength;
    final newReinforcementScore = (node.lifecycle.reinforcementScore + reinforcementEffect).clamp(0.0, 5.0);

    // Update lifecycle metadata
    final newLifecycle = node.lifecycle.copyWith(
      reinforcementScore: newReinforcementScore,
      accessCount: node.lifecycle.accessCount + 1,
      lastAccessed: DateTime.now().toUtc(),
    );

    // Record reinforcement in metadata
    final reinforcementRecord = {
      'type': type.name,
      'strength': strength,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'reason': reason,
    };

    final newData = Map<String, dynamic>.from(node.data);
    newData.putIfAbsent('reinforcements', () => <Map<String, dynamic>>[]);
    (newData['reinforcements'] as List<Map<String, dynamic>>).add(reinforcementRecord);

    return EnhancedMiraNode(
      id: node.id,
      type: node.type,
      schemaVersion: node.schemaVersion,
      data: newData,
      createdAt: node.createdAt,
      updatedAt: DateTime.now().toUtc(),
      domain: node.domain,
      privacy: node.privacy,
      phaseContext: node.phaseContext,
      rhythmScore: node.rhythmScore,
      attributions: node.attributions,
      sage: node.sage,
      lifecycle: newLifecycle,
      provenance: node.provenance,
      piiFlags: node.piiFlags,
    );
  }

  /// Schedule memory for decay or archival
  Future<void> scheduleDecay({
    required String nodeId,
    required DateTime decayTime,
    DecayAction action = DecayAction.archive,
    String? reason,
  }) async {
    // This would integrate with a job scheduler
    // For now, storing in memory
    final veilHook = VeilHook(
      id: 'decay_$nodeId',
      trigger: VeilTrigger.scheduled,
      action: action,
      scheduledTime: decayTime,
      reason: reason,
    );

    _veilHooks[veilHook.id] = veilHook;
  }

  /// Process scheduled decay operations
  Future<List<DecayOperation>> processScheduledDecay({
    DateTime? currentTime,
  }) async {
    final now = currentTime ?? DateTime.now().toUtc();
    final operations = <DecayOperation>[];

    for (final hook in _veilHooks.values) {
      if (hook.trigger == VeilTrigger.scheduled &&
          hook.scheduledTime != null &&
          hook.scheduledTime!.isBefore(now)) {

        operations.add(DecayOperation(
          nodeId: hook.id.replaceFirst('decay_', ''),
          action: hook.action,
          reason: hook.reason ?? 'Scheduled decay',
          timestamp: now,
        ));
      }
    }

    return operations;
  }

  /// Identify memories ready for pruning
  Future<List<PruningCandidate>> identifyPruningCandidates({
    required List<EnhancedMiraNode> nodes,
    double pruningThreshold = 0.1,
    String? currentPhase,
  }) async {
    final candidates = <PruningCandidate>[];

    for (final node in nodes) {
      final decayScore = calculateDecayScore(
        node: node,
        currentPhase: currentPhase,
      );

      final strategy = _decayStrategies[node.domain];
      if (strategy == null) continue;

      // Check if node meets pruning criteria
      if (decayScore < pruningThreshold ||
          decayScore < strategy.minRetentionScore) {

        final candidate = PruningCandidate(
          node: node,
          decayScore: decayScore,
          reason: _generatePruningReason(node, decayScore, strategy),
          recommendedAction: _recommendPruningAction(node, decayScore),
          confidenceScore: _calculatePruningConfidence(node, decayScore),
        );

        candidates.add(candidate);
      }
    }

    // Sort by decay score (most decayed first)
    candidates.sort((a, b) => a.decayScore.compareTo(b.decayScore));

    return candidates;
  }

  /// Apply VEIL resilience restoration
  Future<List<EnhancedMiraNode>> applyResilienceRestoration({
    required List<EnhancedMiraNode> nodes,
    required String trigger,
    Map<String, dynamic>? context,
  }) async {
    final restoredNodes = <EnhancedMiraNode>[];

    for (final node in nodes) {
      // Check if node qualifies for resilience restoration
      if (_qualifiesForResilience(node, trigger, context)) {
        final restoredNode = _restoreResilience(node, trigger);
        restoredNodes.add(restoredNode);
      }
    }

    return restoredNodes;
  }

  /// Get lifecycle statistics
  Map<String, dynamic> getLifecycleStatistics({
    required List<EnhancedMiraNode> nodes,
    String? currentPhase,
  }) {
    final stats = <String, dynamic>{};
    final domainStats = <String, Map<String, dynamic>>{};

    // Overall statistics
    double totalDecayScore = 0;
    int reinforcedCount = 0;
    int scheduledForDecay = 0;

    for (final node in nodes) {
      final decayScore = calculateDecayScore(node: node, currentPhase: currentPhase);
      totalDecayScore += decayScore;

      if (node.lifecycle.reinforcementScore > 1.0) {
        reinforcedCount++;
      }

      // Domain-specific statistics
      final domainName = node.domain.name;
      domainStats.putIfAbsent(domainName, () => {
        'count': 0,
        'avg_decay': 0.0,
        'avg_reinforcement': 0.0,
        'oldest_age_days': 0,
      });

      final domainStat = domainStats[domainName]!;
      domainStat['count'] = (domainStat['count'] as int) + 1;
      domainStat['avg_decay'] = ((domainStat['avg_decay'] as double) + decayScore) / 2;
      domainStat['avg_reinforcement'] = ((domainStat['avg_reinforcement'] as double) + node.lifecycle.reinforcementScore) / 2;

      final ageInDays = DateTime.now().toUtc().difference(node.createdAt).inDays;
      domainStat['oldest_age_days'] = max(domainStat['oldest_age_days'] as int, ageInDays);
    }

    scheduledForDecay = _veilHooks.length;

    return {
      'total_nodes': nodes.length,
      'avg_decay_score': nodes.isNotEmpty ? totalDecayScore / nodes.length : 0.0,
      'reinforced_nodes': reinforcedCount,
      'scheduled_for_decay': scheduledForDecay,
      'domain_statistics': domainStats,
      'phase_context': currentPhase,
      'veil_hooks_active': _veilHooks.length,
    };
  }

  /// Export lifecycle configuration
  Map<String, dynamic> exportLifecycleConfiguration() {
    return {
      'export_timestamp': DateTime.now().toUtc().toIso8601String(),
      'decay_strategies': _decayStrategies.map((domain, strategy) =>
          MapEntry(domain.name, strategy.toJson())),
      'reinforcement_rules': _reinforcementRules.map((id, rule) =>
          MapEntry(id, rule.toJson())),
      'veil_hooks': _veilHooks.map((id, hook) =>
          MapEntry(id, hook.toJson())),
      'phase_multipliers': _phaseDecayMultipliers,
      'schema_version': 'lifecycle_config.v1',
    };
  }

  // Private helper methods

  String _generatePruningReason(EnhancedMiraNode node, double decayScore, DecayStrategy strategy) {
    final age = DateTime.now().toUtc().difference(node.createdAt);

    if (decayScore < strategy.minRetentionScore) {
      return 'Memory has decayed below minimum retention threshold (${(strategy.minRetentionScore * 100).toStringAsFixed(1)}%)';
    }

    if (age > strategy.maxAge) {
      return 'Memory has exceeded maximum age limit (${strategy.maxAge.inDays} days)';
    }

    return 'Memory shows natural decay pattern (${(decayScore * 100).toStringAsFixed(1)}% retention)';
  }

  PruningAction _recommendPruningAction(EnhancedMiraNode node, double decayScore) {
    if (decayScore < 0.05) return PruningAction.delete;
    if (decayScore < 0.1) return PruningAction.archive;
    return PruningAction.compress;
  }

  double _calculatePruningConfidence(EnhancedMiraNode node, double decayScore) {
    // Higher confidence for very low decay scores
    if (decayScore < 0.05) return 0.95;
    if (decayScore < 0.1) return 0.85;
    if (decayScore < 0.2) return 0.7;
    return 0.5;
  }

  bool _qualifiesForResilience(EnhancedMiraNode node, String trigger, Map<String, dynamic>? context) {
    // Example resilience criteria
    if (node.domain == MemoryDomain.health || node.domain == MemoryDomain.spiritual) {
      return true; // Health and spiritual memories have strong resilience
    }

    if (node.lifecycle.reinforcementScore > 2.0) {
      return true; // Highly reinforced memories are resilient
    }

    return false;
  }

  EnhancedMiraNode _restoreResilience(EnhancedMiraNode node, String trigger) {
    // Boost reinforcement score for resilience
    final boostedLifecycle = node.lifecycle.copyWith(
      reinforcementScore: (node.lifecycle.reinforcementScore * 1.2).clamp(0.0, 5.0),
    );

    return EnhancedMiraNode(
      id: node.id,
      type: node.type,
      schemaVersion: node.schemaVersion,
      data: node.data,
      createdAt: node.createdAt,
      updatedAt: DateTime.now().toUtc(),
      domain: node.domain,
      privacy: node.privacy,
      phaseContext: node.phaseContext,
      rhythmScore: node.rhythmScore,
      attributions: node.attributions,
      sage: node.sage,
      lifecycle: boostedLifecycle,
      provenance: node.provenance,
      piiFlags: node.piiFlags,
    );
  }
}

/// Decay strategy configuration for memory domains
class DecayStrategy {
  final double baseDecayRate;
  final double reinforcementSensitivity;
  final double minRetentionScore;
  final Duration maxAge;
  final DecayFunction decayFunction;

  const DecayStrategy({
    required this.baseDecayRate,
    required this.reinforcementSensitivity,
    required this.minRetentionScore,
    required this.maxAge,
    required this.decayFunction,
  });

  double calculateDecay(Duration age, double reinforcementScore) {
    final ageInMonths = age.inDays / 30.0;
    double decay;

    switch (decayFunction) {
      case DecayFunction.linear:
        decay = 1.0 - (baseDecayRate * ageInMonths);
        break;
      case DecayFunction.exponential:
        decay = exp(-baseDecayRate * ageInMonths);
        break;
      case DecayFunction.logarithmic:
        decay = 1.0 - (baseDecayRate * log(ageInMonths + 1));
        break;
      case DecayFunction.spaced_repetition:
        // Ebbinghaus forgetting curve with spaced repetition
        decay = exp(-baseDecayRate * ageInMonths / reinforcementScore);
        break;
      case DecayFunction.step_wise:
        // Step-wise decay (e.g., for financial records)
        if (ageInMonths < 12) decay = 1.0;
        else if (ageInMonths < 36) decay = 0.8;
        else if (ageInMonths < 84) decay = 0.6;
        else decay = 0.3;
        break;
    }

    // Apply reinforcement boost
    decay = (decay * reinforcementScore).clamp(0.0, 1.0);

    return decay;
  }

  Map<String, dynamic> toJson() => {
    'base_decay_rate': baseDecayRate,
    'reinforcement_sensitivity': reinforcementSensitivity,
    'min_retention_score': minRetentionScore,
    'max_age_days': maxAge.inDays,
    'decay_function': decayFunction.name,
  };

  factory DecayStrategy.fromJson(Map<String, dynamic> json) {
    return DecayStrategy(
      baseDecayRate: json['base_decay_rate'].toDouble(),
      reinforcementSensitivity: json['reinforcement_sensitivity'].toDouble(),
      minRetentionScore: json['min_retention_score'].toDouble(),
      maxAge: Duration(days: json['max_age_days']),
      decayFunction: DecayFunction.values.firstWhere((f) => f.name == json['decay_function']),
    );
  }
}

/// Types of decay functions
enum DecayFunction {
  linear,
  exponential,
  logarithmic,
  spaced_repetition,
  step_wise,
}

/// Types of memory reinforcement
enum ReinforcementType {
  access,        // Memory was accessed/recalled
  relevance,     // Memory proved relevant to current context
  emotional,     // Memory triggered emotional response
  reference,     // Memory was referenced by new entry
  synthesis,     // Memory used in cross-domain synthesis
  user_explicit, // User explicitly marked as important
}

/// Reinforcement rule configuration
class ReinforcementRule {
  final String id;
  final ReinforcementType type;
  final double strengthMultiplier;
  final Map<String, dynamic> conditions;

  const ReinforcementRule({
    required this.id,
    required this.type,
    required this.strengthMultiplier,
    this.conditions = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'strength_multiplier': strengthMultiplier,
    'conditions': conditions,
  };

  factory ReinforcementRule.fromJson(Map<String, dynamic> json) {
    return ReinforcementRule(
      id: json['id'],
      type: ReinforcementType.values.firstWhere((t) => t.name == json['type']),
      strengthMultiplier: json['strength_multiplier'].toDouble(),
      conditions: Map<String, dynamic>.from(json['conditions']),
    );
  }
}

/// VEIL integration hook
class VeilHook {
  final String id;
  final VeilTrigger trigger;
  final DecayAction action;
  final DateTime? scheduledTime;
  final String? reason;
  final Map<String, dynamic> metadata;

  const VeilHook({
    required this.id,
    required this.trigger,
    required this.action,
    this.scheduledTime,
    this.reason,
    this.metadata = const {},
  });

  bool appliesToNode(EnhancedMiraNode node) {
    // Implementation would check if this hook applies to the given node
    return id.contains(node.id);
  }

  double modifyDecayScore(double originalScore, EnhancedMiraNode node) {
    // Implementation would modify decay score based on VEIL rules
    return originalScore;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'trigger': trigger.name,
    'action': action.name,
    'scheduled_time': scheduledTime?.toIso8601String(),
    'reason': reason,
    'metadata': metadata,
  };

  factory VeilHook.fromJson(Map<String, dynamic> json) {
    return VeilHook(
      id: json['id'],
      trigger: VeilTrigger.values.firstWhere((t) => t.name == json['trigger']),
      action: DecayAction.values.firstWhere((a) => a.name == json['action']),
      scheduledTime: json['scheduled_time'] != null
          ? DateTime.parse(json['scheduled_time']) : null,
      reason: json['reason'],
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
}

/// VEIL trigger types
enum VeilTrigger {
  scheduled,     // Time-based trigger
  threshold,     // Decay threshold reached
  phase_change,  // ATLAS phase transition
  user_request,  // Explicit user action
  system_event,  // System-generated event
}

/// Decay actions
enum DecayAction {
  archive,   // Move to archive storage
  compress,  // Compress/summarize
  delete,    // Permanent deletion
  restore,   // Restore from decay
}

/// Pruning candidate information
class PruningCandidate {
  final EnhancedMiraNode node;
  final double decayScore;
  final String reason;
  final PruningAction recommendedAction;
  final double confidenceScore;

  const PruningCandidate({
    required this.node,
    required this.decayScore,
    required this.reason,
    required this.recommendedAction,
    required this.confidenceScore,
  });
}

/// Pruning actions
enum PruningAction {
  delete,
  archive,
  compress,
  merge,
}

/// Decay operation record
class DecayOperation {
  final String nodeId;
  final DecayAction action;
  final String reason;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  const DecayOperation({
    required this.nodeId,
    required this.action,
    required this.reason,
    required this.timestamp,
    this.metadata = const {},
  });
}