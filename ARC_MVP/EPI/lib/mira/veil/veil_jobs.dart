// lib/mira/veil/veil_jobs.dart
// VEIL (Vital Equilibrium for Intelligent Learning) Jobs
// Implements nightly hygiene, pruning, and memory management

import 'dart:math';
import '../core/schema_v2.dart';
import 'package:my_app/arc/chat/chat/ulid.dart';

/// VEIL job result
class VeilJobResult {
  final String jobId;
  final String jobType;
  final bool success;
  final int itemsProcessed;
  final int itemsModified;
  final List<String> errors;
  final Map<String, dynamic> metrics;
  final DateTime timestamp;

  const VeilJobResult({
    required this.jobId,
    required this.jobType,
    required this.success,
    required this.itemsProcessed,
    required this.itemsModified,
    required this.errors,
    required this.metrics,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'job_id': jobId,
    'job_type': jobType,
    'success': success,
    'items_processed': itemsProcessed,
    'items_modified': itemsModified,
    'errors': errors,
    'metrics': metrics,
    'timestamp': timestamp.toUtc().toIso8601String(),
  };
}

/// Decay configuration
class DecayConfig {
  final double halfLife;              // Half-life in days
  final Map<String, double> phaseMultipliers; // Phase-specific multipliers
  final double accessReinforcement;   // Reinforcement from access
  final double pinningBoost;          // Boost for pinned items
  final double maxDecay;              // Maximum decay rate

  const DecayConfig({
    required this.halfLife,
    required this.phaseMultipliers,
    required this.accessReinforcement,
    required this.pinningBoost,
    required this.maxDecay,
  });

  /// Get default decay configuration
  factory DecayConfig.defaultConfig() => const DecayConfig(
    halfLife: 30.0, // 30 days half-life
    phaseMultipliers: {
      'Discovery': 0.5,      // 50% slower decay
      'Expansion': 0.8,      // 20% slower decay
      'Transition': 1.5,     // 50% faster decay
      'Consolidation': 0.6,  // 40% slower decay
      'Recovery': 0.7,       // 30% slower decay
      'Breakthrough': 0.9,   // 10% slower decay
    },
    accessReinforcement: 0.1,  // 10% reinforcement per access
    pinningBoost: 0.3,         // 30% boost for pinned items
    maxDecay: 0.95,            // Maximum 95% decay
  );
}

/// VEIL job scheduler
class VeilJobScheduler {
  final Map<String, VeilJob> _jobs;
  final DecayConfig _decayConfig;

  VeilJobScheduler({
    DecayConfig? decayConfig,
  }) : _jobs = {},
       _decayConfig = decayConfig ?? DecayConfig.defaultConfig();

  /// Register a VEIL job
  void registerJob(String jobType, VeilJob job) {
    _jobs[jobType] = job;
  }

  /// Run all scheduled jobs
  Future<List<VeilJobResult>> runScheduledJobs() async {
    final results = <VeilJobResult>[];
    
    for (final entry in _jobs.entries) {
      final jobType = entry.key;
      final job = entry.value;
      
      try {
        final result = await job.run();
        results.add(result);
      } catch (e) {
        final errorResult = VeilJobResult(
          jobId: ULID.generate(),
          jobType: jobType,
          success: false,
          itemsProcessed: 0,
          itemsModified: 0,
          errors: [e.toString()],
          metrics: {},
          timestamp: DateTime.now().toUtc(),
        );
        results.add(errorResult);
      }
    }
    
    return results;
  }

  /// Run specific job
  Future<VeilJobResult?> runJob(String jobType) async {
    final job = _jobs[jobType];
    if (job == null) return null;
    
    return await job.run();
  }

  /// Get job status
  Map<String, dynamic> getJobStatus() => {
    'registered_jobs': _jobs.keys.toList(),
    'decay_config': {
      'half_life': _decayConfig.halfLife,
      'phase_multipliers': _decayConfig.phaseMultipliers,
      'access_reinforcement': _decayConfig.accessReinforcement,
      'pinning_boost': _decayConfig.pinningBoost,
      'max_decay': _decayConfig.maxDecay,
    },
  };
}

/// Abstract VEIL job
abstract class VeilJob {
  Future<VeilJobResult> run();
}

/// Dedupe summaries job
class DedupeSummariesJob extends VeilJob {
  final List<MiraNodeV2> _nodes;
  final double similarityThreshold;

  DedupeSummariesJob({
    required List<MiraNodeV2> nodes,
    this.similarityThreshold = 0.9,
  }) : _nodes = nodes;

  @override
  Future<VeilJobResult> run() async {
    final jobId = ULID.generate();
    final errors = <String>[];
    int itemsProcessed = 0;
    int itemsModified = 0;
    final metrics = <String, dynamic>{};

    try {
      // Find summary nodes
      final summaryNodes = _nodes.where((node) => 
        node.type == NodeType.summary && node.isActive
      ).toList();

      itemsProcessed = summaryNodes.length;
      final duplicates = <List<MiraNodeV2>>[];

      // Group similar summaries
      for (int i = 0; i < summaryNodes.length; i++) {
        final node1 = summaryNodes[i];
        if (node1.isTombstoned) continue;

        final similarNodes = <MiraNodeV2>[node1];
        
        for (int j = i + 1; j < summaryNodes.length; j++) {
          final node2 = summaryNodes[j];
          if (node2.isTombstoned) continue;

          final similarity = _calculateJaccardSimilarity(node1, node2);
          if (similarity >= similarityThreshold) {
            similarNodes.add(node2);
          }
        }

        if (similarNodes.length > 1) {
          duplicates.add(similarNodes);
        }
      }

      // Merge duplicate groups
      for (final group in duplicates) {
        if (group.length <= 1) continue;

        // Keep the most recent node, tombstone others
        group.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final tombstoneNodes = group.skip(1).toList();

        for (final _ in tombstoneNodes) {
          // In a real implementation, this would update the repository
          // For now, we just count the modification
          itemsModified++;
        }

        metrics['duplicate_groups'] = (metrics['duplicate_groups'] as int? ?? 0) + 1;
        metrics['nodes_tombstoned'] = (metrics['nodes_tombstoned'] as int? ?? 0) + tombstoneNodes.length;
      }

      return VeilJobResult(
        jobId: jobId,
        jobType: 'dedupe_summaries',
        success: errors.isEmpty,
        itemsProcessed: itemsProcessed,
        itemsModified: itemsModified,
        errors: errors,
        metrics: metrics,
        timestamp: DateTime.now().toUtc(),
      );
    } catch (e) {
      errors.add('Dedupe summaries failed: $e');
      return VeilJobResult(
        jobId: jobId,
        jobType: 'dedupe_summaries',
        success: false,
        itemsProcessed: itemsProcessed,
        itemsModified: itemsModified,
        errors: errors,
        metrics: metrics,
        timestamp: DateTime.now().toUtc(),
      );
    }
  }

  /// Calculate Jaccard similarity between two nodes
  double _calculateJaccardSimilarity(MiraNodeV2 node1, MiraNodeV2 node2) {
    final words1 = node1.narrative.toLowerCase().split(' ').toSet();
    final words2 = node2.narrative.toLowerCase().split(' ').toSet();
    
    final intersection = words1.intersection(words2).length;
    final union = words1.union(words2).length;
    
    if (union == 0) return 0.0;
    return intersection / union;
  }
}

/// Stale edge prune job
class StaleEdgePruneJob extends VeilJob {
  final List<MiraEdgeV2> _edges;
  final double weightThreshold;
  final int daysThreshold;

  StaleEdgePruneJob({
    required List<MiraEdgeV2> edges,
    this.weightThreshold = 0.05,
    this.daysThreshold = 90,
  }) : _edges = edges;

  @override
  Future<VeilJobResult> run() async {
    final jobId = ULID.generate();
    final errors = <String>[];
    int itemsProcessed = 0;
    int itemsModified = 0;
    final metrics = <String, dynamic>{};

    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysThreshold));
      
      for (final edge in _edges) {
        if (edge.isTombstoned) continue;
        
        itemsProcessed++;
        
        final weight = edge.weight;
        final lastTouched = edge.updatedAt;
        
        // Check if edge should be pruned
        if (weight < weightThreshold && lastTouched.isBefore(cutoffDate)) {
          // In a real implementation, this would tombstone the edge
          // For now, we just count the modification
          itemsModified++;
        }
      }

      metrics['weight_threshold'] = weightThreshold;
      metrics['days_threshold'] = daysThreshold;
      metrics['cutoff_date'] = cutoffDate.toUtc().toIso8601String();

      return VeilJobResult(
        jobId: jobId,
        jobType: 'stale_edge_prune',
        success: errors.isEmpty,
        itemsProcessed: itemsProcessed,
        itemsModified: itemsModified,
        errors: errors,
        metrics: metrics,
        timestamp: DateTime.now().toUtc(),
      );
    } catch (e) {
      errors.add('Stale edge prune failed: $e');
      return VeilJobResult(
        jobId: jobId,
        jobType: 'stale_edge_prune',
        success: false,
        itemsProcessed: itemsProcessed,
        itemsModified: itemsModified,
        errors: errors,
        metrics: metrics,
        timestamp: DateTime.now().toUtc(),
      );
    }
  }
}

/// Conflict review batcher job
class ConflictReviewBatcherJob extends VeilJob {
  final List<MiraNodeV2> _nodes;
  final int maxConflictsPerWeek;

  ConflictReviewBatcherJob({
    required List<MiraNodeV2> nodes,
    this.maxConflictsPerWeek = 5,
  }) : _nodes = nodes;

  @override
  Future<VeilJobResult> run() async {
    final jobId = ULID.generate();
    final errors = <String>[];
    int itemsProcessed = 0;
    int itemsModified = 0;
    final metrics = <String, dynamic>{};

    try {
      // Find potential conflicts (simplified)
      final conflicts = <List<MiraNodeV2>>[];
      
      // Group nodes by similar content
      final contentGroups = <String, List<MiraNodeV2>>{};
      
      for (final node in _nodes) {
        if (node.isTombstoned) continue;
        
        final content = node.narrative.toLowerCase();
        final words = content.split(' ').where((w) => w.length > 3).toList();
        words.sort();
        final key = words.take(5).join('_'); // Use first 5 words as key
        
        contentGroups.putIfAbsent(key, () => []).add(node);
      }
      
      // Find groups with multiple nodes (potential conflicts)
      for (final group in contentGroups.values) {
        if (group.length > 1) {
          conflicts.add(group);
        }
      }
      
      itemsProcessed = _nodes.length;
      
      // Limit conflicts per week
      final conflictsToReview = conflicts.take(maxConflictsPerWeek).toList();
      itemsModified = conflictsToReview.length;
      
      metrics['total_conflicts_found'] = conflicts.length;
      metrics['conflicts_to_review'] = conflictsToReview.length;
      metrics['max_conflicts_per_week'] = maxConflictsPerWeek;

      return VeilJobResult(
        jobId: jobId,
        jobType: 'conflict_review_batcher',
        success: errors.isEmpty,
        itemsProcessed: itemsProcessed,
        itemsModified: itemsModified,
        errors: errors,
        metrics: metrics,
        timestamp: DateTime.now().toUtc(),
      );
    } catch (e) {
      errors.add('Conflict review batcher failed: $e');
      return VeilJobResult(
        jobId: jobId,
        jobType: 'conflict_review_batcher',
        success: false,
        itemsProcessed: itemsProcessed,
        itemsModified: itemsModified,
        errors: errors,
        metrics: metrics,
        timestamp: DateTime.now().toUtc(),
      );
    }
  }
}

/// Memory decay job
class MemoryDecayJob extends VeilJob {
  final List<MiraNodeV2> _nodes;
  final DecayConfig _decayConfig;

  MemoryDecayJob({
    required List<MiraNodeV2> nodes,
    required DecayConfig decayConfig,
  }) : _nodes = nodes,
       _decayConfig = decayConfig;

  @override
  Future<VeilJobResult> run() async {
    final jobId = ULID.generate();
    final errors = <String>[];
    int itemsProcessed = 0;
    int itemsModified = 0;
    final metrics = <String, dynamic>{};

    try {
      for (final node in _nodes) {
        if (node.isTombstoned) continue;
        
        itemsProcessed++;
        
        // Calculate decay
        final age = DateTime.now().difference(node.createdAt).inDays;
        final phase = node.metadata['phase_context'] as String? ?? 'Discovery';
        final phaseMultiplier = _decayConfig.phaseMultipliers[phase] ?? 1.0;
        final accessCount = node.metadata['access_count'] as int? ?? 0;
        final isPinned = node.metadata['is_pinned'] as bool? ?? false;
        
        // Calculate decay rate
        double decayRate = 1.0 - pow(0.5, age / (_decayConfig.halfLife * phaseMultiplier));
        
        // Apply access reinforcement
        if (accessCount > 0) {
          decayRate -= accessCount * _decayConfig.accessReinforcement;
        }
        
        // Apply pinning boost
        if (isPinned) {
          decayRate -= _decayConfig.pinningBoost;
        }
        
        // Clamp decay rate
        decayRate = decayRate.clamp(0.0, _decayConfig.maxDecay);
        
        // Update node if decay rate changed significantly
        if (decayRate > 0.1) { // Only update if decay is significant
          itemsModified++;
        }
        
        metrics['total_decay_applied'] = (metrics['total_decay_applied'] as double? ?? 0.0) + decayRate;
      }

      metrics['decay_config'] = {
        'half_life': _decayConfig.halfLife,
        'phase_multipliers': _decayConfig.phaseMultipliers,
        'access_reinforcement': _decayConfig.accessReinforcement,
        'pinning_boost': _decayConfig.pinningBoost,
        'max_decay': _decayConfig.maxDecay,
      };

      return VeilJobResult(
        jobId: jobId,
        jobType: 'memory_decay',
        success: errors.isEmpty,
        itemsProcessed: itemsProcessed,
        itemsModified: itemsModified,
        errors: errors,
        metrics: metrics,
        timestamp: DateTime.now().toUtc(),
      );
    } catch (e) {
      errors.add('Memory decay failed: $e');
      return VeilJobResult(
        jobId: jobId,
        jobType: 'memory_decay',
        success: false,
        itemsProcessed: itemsProcessed,
        itemsModified: itemsModified,
        errors: errors,
        metrics: metrics,
        timestamp: DateTime.now().toUtc(),
      );
    }
  }
}
