// lib/mira/memory/conflict_resolution_service.dart
// Conflict resolution service for EPI memory system
// Handles contradictions, inconsistencies, and memory conflicts with user dignity

import 'enhanced_memory_schema.dart';

/// Service for detecting and resolving memory conflicts and contradictions
class ConflictResolutionService {
  /// Active conflicts awaiting resolution
  final Map<String, MemoryConflict> _activeConflicts = {};

  /// Resolution history for learning
  final List<ConflictResolution> _resolutionHistory = [];

  /// Conflict detection rules
  final Map<String, ConflictDetectionRule> _detectionRules = {};

  /// Resolution strategies by conflict type
  final Map<ConflictType, ResolutionStrategy> _resolutionStrategies = {};

  ConflictResolutionService() {
    _initializeDetectionRules();
    _initializeResolutionStrategies();
  }

  /// Initialize conflict detection rules
  void _initializeDetectionRules() {
    // Semantic contradiction detection
    _detectionRules['semantic_contradiction'] = const ConflictDetectionRule(
      id: 'semantic_contradiction',
      name: 'Semantic Contradiction',
      description: 'Detects when memories contain contradictory information',
      triggers: [
        TriggerPattern.keyword_opposition,
        TriggerPattern.sentiment_reversal,
        TriggerPattern.factual_contradiction,
      ],
      severity: ConflictSeverity.high,
      domains: MemoryDomain.values,
    );

    // Temporal inconsistency detection
    _detectionRules['temporal_inconsistency'] = const ConflictDetectionRule(
      id: 'temporal_inconsistency',
      name: 'Temporal Inconsistency',
      description: 'Detects timeline inconsistencies in memories',
      triggers: [
        TriggerPattern.timeline_conflict,
        TriggerPattern.sequence_violation,
      ],
      severity: ConflictSeverity.medium,
      domains: MemoryDomain.values,
    );

    // Emotional contradiction detection
    _detectionRules['emotional_contradiction'] = const ConflictDetectionRule(
      id: 'emotional_contradiction',
      name: 'Emotional Contradiction',
      description: 'Detects conflicting emotional states about same topic',
      triggers: [
        TriggerPattern.emotion_opposition,
        TriggerPattern.sentiment_conflict,
      ],
      severity: ConflictSeverity.medium,
      domains: [MemoryDomain.personal, MemoryDomain.relationships, MemoryDomain.spiritual],
    );

    // Value system conflicts
    _detectionRules['value_conflict'] = const ConflictDetectionRule(
      id: 'value_conflict',
      name: 'Value System Conflict',
      description: 'Detects conflicts with core values or beliefs',
      triggers: [
        TriggerPattern.value_violation,
        TriggerPattern.belief_contradiction,
      ],
      severity: ConflictSeverity.high,
      domains: [MemoryDomain.personal, MemoryDomain.spiritual, MemoryDomain.relationships],
    );

    // Phase transition conflicts
    _detectionRules['phase_conflict'] = const ConflictDetectionRule(
      id: 'phase_conflict',
      name: 'Phase Transition Conflict',
      description: 'Detects memories that conflict with current ATLAS phase',
      triggers: [
        TriggerPattern.phase_misalignment,
        TriggerPattern.growth_contradiction,
      ],
      severity: ConflictSeverity.low,
      domains: MemoryDomain.values,
    );
  }

  /// Initialize resolution strategies
  void _initializeResolutionStrategies() {
    // High-dignity user confirmation strategy
    _resolutionStrategies[ConflictType.factual] = const ResolutionStrategy(
      type: ConflictType.factual,
      approach: ResolutionApproach.user_confirmation,
      prompt: ResolutionPrompt.dignified_clarification,
      preserveBoth: false,
      requiresConsent: true,
    );

    // Temporal reconciliation strategy
    _resolutionStrategies[ConflictType.temporal] = const ResolutionStrategy(
      type: ConflictType.temporal,
      approach: ResolutionApproach.timeline_reconciliation,
      prompt: ResolutionPrompt.timeline_clarification,
      preserveBoth: true,
      requiresConsent: false,
    );

    // Emotional evolution strategy
    _resolutionStrategies[ConflictType.emotional] = const ResolutionStrategy(
      type: ConflictType.emotional,
      approach: ResolutionApproach.evolution_acknowledgment,
      prompt: ResolutionPrompt.growth_recognition,
      preserveBoth: true,
      requiresConsent: false,
    );

    // Value system integration strategy
    _resolutionStrategies[ConflictType.value_system] = const ResolutionStrategy(
      type: ConflictType.value_system,
      approach: ResolutionApproach.integration_synthesis,
      prompt: ResolutionPrompt.wisdom_integration,
      preserveBoth: true,
      requiresConsent: true,
    );

    // Phase-aware reconciliation strategy
    _resolutionStrategies[ConflictType.phase] = const ResolutionStrategy(
      type: ConflictType.phase,
      approach: ResolutionApproach.phase_contextual,
      prompt: ResolutionPrompt.phase_awareness,
      preserveBoth: true,
      requiresConsent: false,
    );
  }

  /// Detect conflicts when adding new memory
  Future<List<MemoryConflict>> detectConflicts({
    required EnhancedMiraNode newNode,
    required List<EnhancedMiraNode> existingNodes,
    String? currentPhase,
  }) async {
    final conflicts = <MemoryConflict>[];

    for (final existingNode in existingNodes) {
      // Skip if nodes are from incompatible domains
      if (!_domainsCanConflict(newNode.domain, existingNode.domain)) {
        continue;
      }

      // Apply each detection rule
      for (final rule in _detectionRules.values) {
        if (rule.domains.contains(newNode.domain) || rule.domains.contains(existingNode.domain)) {
          final conflict = _checkConflictRule(rule, newNode, existingNode, currentPhase);
          if (conflict != null) {
            conflicts.add(conflict);
          }
        }
      }
    }

    // Store active conflicts
    for (final conflict in conflicts) {
      _activeConflicts[conflict.id] = conflict;
    }

    return conflicts;
  }

  /// Generate dignified resolution prompt for user
  String generateResolutionPrompt({
    required MemoryConflict conflict,
    required EnhancedMiraNode nodeA,
    required EnhancedMiraNode nodeB,
  }) {
    final strategy = _resolutionStrategies[_classifyConflict(conflict)];
    if (strategy == null) {
      return _generateGenericPrompt(conflict, nodeA, nodeB);
    }

    switch (strategy.prompt) {
      case ResolutionPrompt.dignified_clarification:
        return _generateDignifiedClarificationPrompt(conflict, nodeA, nodeB);
      case ResolutionPrompt.timeline_clarification:
        return _generateTimelineClarificationPrompt(conflict, nodeA, nodeB);
      case ResolutionPrompt.growth_recognition:
        return _generateGrowthRecognitionPrompt(conflict, nodeA, nodeB);
      case ResolutionPrompt.wisdom_integration:
        return _generateWisdomIntegrationPrompt(conflict, nodeA, nodeB);
      case ResolutionPrompt.phase_awareness:
        return _generatePhaseAwarenessPrompt(conflict, nodeA, nodeB);
    }
  }

  /// Resolve conflict based on user input
  Future<ConflictResolution> resolveConflict({
    required String conflictId,
    required UserResolution userResolution,
    String? userExplanation,
    Map<String, dynamic>? context,
  }) async {
    final conflict = _activeConflicts[conflictId];
    if (conflict == null) {
      throw Exception('Conflict not found: $conflictId');
    }

    final resolution = ConflictResolution(
      id: _generateResolutionId(),
      conflictId: conflictId,
      resolution: userResolution,
      userExplanation: userExplanation,
      timestamp: DateTime.now().toUtc(),
      context: context ?? {},
    );

    // Apply resolution
    await _applyResolution(conflict, resolution);

    // Store in history
    _resolutionHistory.add(resolution);

    // Remove from active conflicts
    _activeConflicts.remove(conflictId);

    return resolution;
  }

  /// Get all active conflicts
  List<MemoryConflict> getActiveConflicts({
    ConflictSeverity? severity,
    MemoryDomain? domain,
  }) {
    var conflicts = _activeConflicts.values.toList();

    if (severity != null) {
      conflicts = conflicts.where((c) => c.severity == severity).toList();
    }

    // Filter by domain (if either node belongs to the domain)
    if (domain != null) {
      conflicts = conflicts.where((c) =>
        c.context['domain_a'] == domain.name ||
        c.context['domain_b'] == domain.name
      ).toList();
    }

    // Sort by severity and recency
    conflicts.sort((a, b) {
      final severityCompare = b.severity.compareTo(a.severity);
      if (severityCompare != 0) return severityCompare;
      return b.detected.compareTo(a.detected);
    });

    return conflicts;
  }

  /// Convert severity double to string level
  String _getSeverityLevel(double severity) {
    if (severity >= 0.8) return 'critical';
    if (severity >= 0.6) return 'high';
    if (severity >= 0.4) return 'medium';
    if (severity >= 0.2) return 'low';
    return 'minimal';
  }

  /// Generate conflict summary for user dashboard
  Map<String, dynamic> generateConflictSummary() {
    final activeByType = <String, int>{};
    final activeBySeverity = <String, int>{};
    final activeDomains = <String, int>{};

    for (final conflict in _activeConflicts.values) {
      activeByType[conflict.conflictType] = (activeByType[conflict.conflictType] ?? 0) + 1;
      final severityLevel = _getSeverityLevel(conflict.severity);
      activeBySeverity[severityLevel] = (activeBySeverity[severityLevel] ?? 0) + 1;

      final domainA = conflict.context['domain_a'] as String?;
      final domainB = conflict.context['domain_b'] as String?;
      if (domainA != null) activeDomains[domainA] = (activeDomains[domainA] ?? 0) + 1;
      if (domainB != null) activeDomains[domainB] = (activeDomains[domainB] ?? 0) + 1;
    }

    return {
      'total_active_conflicts': _activeConflicts.length,
      'conflicts_by_type': activeByType,
      'conflicts_by_severity': activeBySeverity,
      'affected_domains': activeDomains,
      'resolution_history_count': _resolutionHistory.length,
      'needs_attention': _activeConflicts.values.where((c) => c.severity == ConflictSeverity.high).length,
    };
  }

  /// Export conflict data for analysis
  Map<String, dynamic> exportConflictData() {
    return {
      'export_timestamp': DateTime.now().toUtc().toIso8601String(),
      'active_conflicts': _activeConflicts.values.map((c) => c.toJson()).toList(),
      'resolution_history': _resolutionHistory.map((r) => r.toJson()).toList(),
      'detection_rules': _detectionRules.map((id, rule) => MapEntry(id, rule.toJson())),
      'resolution_strategies': _resolutionStrategies.map((type, strategy) =>
          MapEntry(type.name, strategy.toJson())),
      'schema_version': 'conflict_export.v1',
    };
  }

  // Private helper methods

  bool _domainsCanConflict(MemoryDomain domainA, MemoryDomain domainB) {
    // Some domains are naturally isolated
    if (domainA == MemoryDomain.finance && domainB == MemoryDomain.creative) return false;
    if (domainA == MemoryDomain.work && domainB == MemoryDomain.spiritual) return false;
    return true;
  }

  MemoryConflict? _checkConflictRule(
    ConflictDetectionRule rule,
    EnhancedMiraNode nodeA,
    EnhancedMiraNode nodeB,
    String? currentPhase,
  ) {
    // Apply rule-specific detection logic
    for (final trigger in rule.triggers) {
      if (_checkTriggerPattern(trigger, nodeA, nodeB, currentPhase)) {
        return MemoryConflict(
          id: _generateConflictId(),
          nodeA: nodeA.id,
          nodeB: nodeB.id,
          conflictType: rule.id,
          description: rule.description,
          severity: _calculateConflictSeverity(rule, nodeA, nodeB),
          detected: DateTime.now().toUtc(),
          context: {
            'rule_id': rule.id,
            'trigger': trigger.name,
            'domain_a': nodeA.domain.name,
            'domain_b': nodeB.domain.name,
            'phase_context': currentPhase,
          },
        );
      }
    }
    return null;
  }

  bool _checkTriggerPattern(
    TriggerPattern pattern,
    EnhancedMiraNode nodeA,
    EnhancedMiraNode nodeB,
    String? currentPhase,
  ) {
    switch (pattern) {
      case TriggerPattern.keyword_opposition:
        return _checkKeywordOpposition(nodeA, nodeB);
      case TriggerPattern.sentiment_reversal:
        return _checkSentimentReversal(nodeA, nodeB);
      case TriggerPattern.factual_contradiction:
        return _checkFactualContradiction(nodeA, nodeB);
      case TriggerPattern.timeline_conflict:
        return _checkTimelineConflict(nodeA, nodeB);
      case TriggerPattern.sequence_violation:
        return _checkSequenceViolation(nodeA, nodeB);
      case TriggerPattern.emotion_opposition:
        return _checkEmotionOpposition(nodeA, nodeB);
      case TriggerPattern.sentiment_conflict:
        return _checkSentimentConflict(nodeA, nodeB);
      case TriggerPattern.value_violation:
        return _checkValueViolation(nodeA, nodeB);
      case TriggerPattern.belief_contradiction:
        return _checkBeliefContradiction(nodeA, nodeB);
      case TriggerPattern.phase_misalignment:
        return _checkPhaseMisalignment(nodeA, nodeB, currentPhase);
      case TriggerPattern.growth_contradiction:
        return _checkGrowthContradiction(nodeA, nodeB);
    }
  }

  // Trigger pattern implementations (simplified)
  bool _checkKeywordOpposition(EnhancedMiraNode nodeA, EnhancedMiraNode nodeB) {
    // Check for opposing keywords like "love/hate", "success/failure", etc.
    final keywordsA = nodeA.keywords.map((k) => k.toLowerCase()).toSet();
    final keywordsB = nodeB.keywords.map((k) => k.toLowerCase()).toSet();

    final oppositions = {
      'love': 'hate',
      'success': 'failure',
      'happy': 'sad',
      'confident': 'insecure',
      'motivated': 'unmotivated',
    };

    for (final entry in oppositions.entries) {
      if ((keywordsA.contains(entry.key) && keywordsB.contains(entry.value)) ||
          (keywordsA.contains(entry.value) && keywordsB.contains(entry.key))) {
        return true;
      }
    }
    return false;
  }

  bool _checkSentimentReversal(EnhancedMiraNode nodeA, EnhancedMiraNode nodeB) {
    // Check for sentiment reversals in similar contexts
    // This would use NLP sentiment analysis
    return false; // Placeholder
  }

  bool _checkFactualContradiction(EnhancedMiraNode nodeA, EnhancedMiraNode nodeB) {
    // Check for factual contradictions
    // This would use fact extraction and comparison
    return false; // Placeholder
  }

  bool _checkTimelineConflict(EnhancedMiraNode nodeA, EnhancedMiraNode nodeB) {
    // Check for timeline inconsistencies
    return false; // Placeholder
  }

  bool _checkSequenceViolation(EnhancedMiraNode nodeA, EnhancedMiraNode nodeB) {
    // Check for sequence violations
    return false; // Placeholder
  }

  bool _checkEmotionOpposition(EnhancedMiraNode nodeA, EnhancedMiraNode nodeB) {
    // Check for opposing emotions about same topic
    return false; // Placeholder
  }

  bool _checkSentimentConflict(EnhancedMiraNode nodeA, EnhancedMiraNode nodeB) {
    // Check for sentiment conflicts
    return false; // Placeholder
  }

  bool _checkValueViolation(EnhancedMiraNode nodeA, EnhancedMiraNode nodeB) {
    // Check for value system violations
    return false; // Placeholder
  }

  bool _checkBeliefContradiction(EnhancedMiraNode nodeA, EnhancedMiraNode nodeB) {
    // Check for belief contradictions
    return false; // Placeholder
  }

  bool _checkPhaseMisalignment(EnhancedMiraNode nodeA, EnhancedMiraNode nodeB, String? currentPhase) {
    // Check for phase misalignment
    return false; // Placeholder
  }

  bool _checkGrowthContradiction(EnhancedMiraNode nodeA, EnhancedMiraNode nodeB) {
    // Check for growth contradictions
    return false; // Placeholder
  }

  double _calculateConflictSeverity(
    ConflictDetectionRule rule,
    EnhancedMiraNode nodeA,
    EnhancedMiraNode nodeB,
  ) {
    double baseSeverity = switch (rule.severity) {
      ConflictSeverity.low => 0.3,
      ConflictSeverity.medium => 0.6,
      ConflictSeverity.high => 0.9,
    };

    // Adjust based on node properties
    final ageFactorA = DateTime.now().toUtc().difference(nodeA.createdAt).inDays / 365.0;
    final ageFactorB = DateTime.now().toUtc().difference(nodeB.createdAt).inDays / 365.0;
    final ageFactor = (ageFactorA + ageFactorB) / 2;

    // Newer conflicts are more severe
    final adjustedSeverity = baseSeverity * (1.0 + (1.0 - ageFactor.clamp(0.0, 1.0)));

    return adjustedSeverity.clamp(0.0, 1.0);
  }

  ConflictType _classifyConflict(MemoryConflict conflict) {
    switch (conflict.conflictType) {
      case 'semantic_contradiction':
      case 'factual_contradiction':
        return ConflictType.factual;
      case 'temporal_inconsistency':
        return ConflictType.temporal;
      case 'emotional_contradiction':
        return ConflictType.emotional;
      case 'value_conflict':
        return ConflictType.value_system;
      case 'phase_conflict':
        return ConflictType.phase;
      default:
        return ConflictType.factual;
    }
  }

  String _generateGenericPrompt(MemoryConflict conflict, EnhancedMiraNode nodeA, EnhancedMiraNode nodeB) {
    return '''
I've noticed something in your memories that might need clarification.

Two of your reflections seem to have different perspectives:

From ${nodeA.createdAt.toLocal().toString().split(' ')[0]}:
"${nodeA.narrative.length > 150 ? '${nodeA.narrative.substring(0, 150)}...' : nodeA.narrative}"

From ${nodeB.createdAt.toLocal().toString().split(' ')[0]}:
"${nodeB.narrative.length > 150 ? '${nodeB.narrative.substring(0, 150)}...' : nodeB.narrative}"

How would you like me to understand this? Both perspectives are valid parts of your journey.
''';
  }

  String _generateDignifiedClarificationPrompt(MemoryConflict conflict, EnhancedMiraNode nodeA, EnhancedMiraNode nodeB) {
    return '''
I want to honor the complexity of your experience. I've noticed two reflections that seem to hold different truths:

Earlier reflection (${nodeA.createdAt.toLocal().toString().split(' ')[0]}):
"${nodeA.narrative.length > 120 ? '${nodeA.narrative.substring(0, 120)}...' : nodeA.narrative}"

Recent reflection (${nodeB.createdAt.toLocal().toString().split(' ')[0]}):
"${nodeB.narrative.length > 120 ? '${nodeB.narrative.substring(0, 120)}...' : nodeB.narrative}"

Both hold meaning in your story. Would you like to help me understand how these perspectives relate to each other?
''';
  }

  String _generateTimelineClarificationPrompt(MemoryConflict conflict, EnhancedMiraNode nodeA, EnhancedMiraNode nodeB) {
    return '''
I'm seeing an interesting pattern in your timeline that I'd like to understand better.

These two memories seem to have a temporal relationship that isn't quite clear to me:

${nodeA.createdAt.toLocal().toString().split(' ')[0]}: "${nodeA.narrative.length > 100 ? '${nodeA.narrative.substring(0, 100)}...' : nodeA.narrative}"

${nodeB.createdAt.toLocal().toString().split(' ')[0]}: "${nodeB.narrative.length > 100 ? '${nodeB.narrative.substring(0, 100)}...' : nodeB.narrative}"

How do these experiences connect in your journey?
''';
  }

  String _generateGrowthRecognitionPrompt(MemoryConflict conflict, EnhancedMiraNode nodeA, EnhancedMiraNode nodeB) {
    return '''
I can see growth happening in your reflections, and I want to honor that evolution:

Earlier feeling (${nodeA.createdAt.toLocal().toString().split(' ')[0]}):
"${nodeA.narrative.length > 120 ? '${nodeA.narrative.substring(0, 120)}...' : nodeA.narrative}"

Current feeling (${nodeB.createdAt.toLocal().toString().split(' ')[0]}):
"${nodeB.narrative.length > 120 ? '${nodeB.narrative.substring(0, 120)}...' : nodeB.narrative}"

This looks like emotional growth to me. How do you see this change in yourself?
''';
  }

  String _generateWisdomIntegrationPrompt(MemoryConflict conflict, EnhancedMiraNode nodeA, EnhancedMiraNode nodeB) {
    return '''
I'm witnessing the depth of your wisdom as you navigate complex truths:

One part of your understanding:
"${nodeA.narrative.length > 120 ? '${nodeA.narrative.substring(0, 120)}...' : nodeA.narrative}"

Another part of your understanding:
"${nodeB.narrative.length > 120 ? '${nodeB.narrative.substring(0, 120)}...' : nodeB.narrative}"

How do these different aspects of your wisdom work together?
''';
  }

  String _generatePhaseAwarenessPrompt(MemoryConflict conflict, EnhancedMiraNode nodeA, EnhancedMiraNode nodeB) {
    return '''
I notice these reflections might represent different phases of your journey:

From your ${nodeA.phaseContext ?? 'earlier'} phase:
"${nodeA.narrative.length > 120 ? '${nodeA.narrative.substring(0, 120)}...' : nodeA.narrative}"

From your ${nodeB.phaseContext ?? 'current'} phase:
"${nodeB.narrative.length > 120 ? '${nodeB.narrative.substring(0, 120)}...' : nodeB.narrative}"

How do you see your growth between these different phases?
''';
  }

  Future<void> _applyResolution(MemoryConflict conflict, ConflictResolution resolution) async {
    // Apply the resolution to the memory system
    // This would update nodes, create edges, etc.
    // Implementation depends on the specific resolution type
  }

  String _generateConflictId() {
    return 'conflict_${DateTime.now().millisecondsSinceEpoch}_${_activeConflicts.length}';
  }

  String _generateResolutionId() {
    return 'resolution_${DateTime.now().millisecondsSinceEpoch}_${_resolutionHistory.length}';
  }

  /// Clear all conflicts
  void clearAllConflicts() {
    _activeConflicts.clear();
    _resolutionHistory.clear();
  }

  /// Restore conflict from backup
  void restoreConflict(String conflictId, MemoryConflict conflict) {
    _activeConflicts[conflictId] = conflict;
  }

  /// Restore resolution from backup
  void restoreResolution(ConflictResolution resolution) {
    _resolutionHistory.add(resolution);
  }
}

/// Conflict detection rule configuration
class ConflictDetectionRule {
  final String id;
  final String name;
  final String description;
  final List<TriggerPattern> triggers;
  final ConflictSeverity severity;
  final List<MemoryDomain> domains;

  const ConflictDetectionRule({
    required this.id,
    required this.name,
    required this.description,
    required this.triggers,
    required this.severity,
    required this.domains,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'triggers': triggers.map((t) => t.name).toList(),
    'severity': severity.name,
    'domains': domains.map((d) => d.name).toList(),
  };

  factory ConflictDetectionRule.fromJson(Map<String, dynamic> json) {
    return ConflictDetectionRule(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      triggers: (json['triggers'] as List<dynamic>)
          .map((t) => TriggerPattern.values.firstWhere((p) => p.name == t))
          .toList(),
      severity: ConflictSeverity.values.firstWhere((s) => s.name == json['severity']),
      domains: (json['domains'] as List<dynamic>)
          .map((d) => MemoryDomain.values.firstWhere((domain) => domain.name == d))
          .toList(),
    );
  }
}

/// Trigger patterns for conflict detection
enum TriggerPattern {
  keyword_opposition,
  sentiment_reversal,
  factual_contradiction,
  timeline_conflict,
  sequence_violation,
  emotion_opposition,
  sentiment_conflict,
  value_violation,
  belief_contradiction,
  phase_misalignment,
  growth_contradiction,
}

/// Conflict severity levels
enum ConflictSeverity {
  low,
  medium,
  high,
}

/// Conflict types for classification
enum ConflictType {
  factual,
  temporal,
  emotional,
  value_system,
  phase,
}

/// Resolution strategy configuration
class ResolutionStrategy {
  final ConflictType type;
  final ResolutionApproach approach;
  final ResolutionPrompt prompt;
  final bool preserveBoth;
  final bool requiresConsent;

  const ResolutionStrategy({
    required this.type,
    required this.approach,
    required this.prompt,
    required this.preserveBoth,
    required this.requiresConsent,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'approach': approach.name,
    'prompt': prompt.name,
    'preserve_both': preserveBoth,
    'requires_consent': requiresConsent,
  };

  factory ResolutionStrategy.fromJson(Map<String, dynamic> json) {
    return ResolutionStrategy(
      type: ConflictType.values.firstWhere((t) => t.name == json['type']),
      approach: ResolutionApproach.values.firstWhere((a) => a.name == json['approach']),
      prompt: ResolutionPrompt.values.firstWhere((p) => p.name == json['prompt']),
      preserveBoth: json['preserve_both'],
      requiresConsent: json['requires_consent'],
    );
  }
}

/// Resolution approaches
enum ResolutionApproach {
  user_confirmation,
  timeline_reconciliation,
  evolution_acknowledgment,
  integration_synthesis,
  phase_contextual,
}

/// Resolution prompt types
enum ResolutionPrompt {
  dignified_clarification,
  timeline_clarification,
  growth_recognition,
  wisdom_integration,
  phase_awareness,
}

/// User resolution choices
enum UserResolution {
  keep_both,
  prefer_newer,
  prefer_older,
  merge_insights,
  contextual_both,
  custom_explanation,
}

/// Conflict resolution record
class ConflictResolution {
  final String id;
  final String conflictId;
  final UserResolution resolution;
  final String? userExplanation;
  final DateTime timestamp;
  final Map<String, dynamic> context;

  const ConflictResolution({
    required this.id,
    required this.conflictId,
    required this.resolution,
    this.userExplanation,
    required this.timestamp,
    this.context = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'conflict_id': conflictId,
    'resolution': resolution.name,
    'user_explanation': userExplanation,
    'timestamp': timestamp.toIso8601String(),
    'context': context,
  };

  factory ConflictResolution.fromJson(Map<String, dynamic> json) {
    return ConflictResolution(
      id: json['id'],
      conflictId: json['conflict_id'],
      resolution: UserResolution.values.firstWhere((r) => r.name == json['resolution']),
      userExplanation: json['user_explanation'],
      timestamp: DateTime.parse(json['timestamp']),
      context: Map<String, dynamic>.from(json['context'] ?? {}),
    );
  }
}