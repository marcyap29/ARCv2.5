// lib/mira/observability/metrics.dart
// MIRA Observability and Metrics Collection
// Tracks retrieval performance, policy decisions, and system health

import 'dart:math';
import '../retrieval/retrieval_engine.dart';
import '../policy/policy_engine.dart';
import '../veil/veil_jobs.dart';

/// Metrics collection for MIRA system
class MiraMetrics {
  final Map<String, int> _counters;
  final Map<String, List<double>> _histograms;
  final Map<String, DateTime> _timestamps;
  final Map<String, dynamic> _gauges;
  final List<Map<String, dynamic>> _events;

  MiraMetrics() : 
    _counters = {},
    _histograms = {},
    _timestamps = {},
    _gauges = {},
    _events = [];

  /// Increment a counter
  void incrementCounter(String name, [int value = 1]) {
    _counters[name] = (_counters[name] ?? 0) + value;
  }

  /// Record a histogram value
  void recordHistogram(String name, double value) {
    _histograms.putIfAbsent(name, () => []).add(value);
  }

  /// Set a gauge value
  void setGauge(String name, dynamic value) {
    _gauges[name] = value;
  }

  /// Record an event
  void recordEvent(String name, Map<String, dynamic> data) {
    _events.add({
      'name': name,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'data': data,
    });
  }

  /// Record timestamp
  void recordTimestamp(String name) {
    _timestamps[name] = DateTime.now().toUtc();
  }

  /// Get counter value
  int getCounter(String name) => _counters[name] ?? 0;

  /// Get histogram statistics
  Map<String, double> getHistogramStats(String name) {
    final values = _histograms[name] ?? [];
    if (values.isEmpty) return {};

    values.sort();
    final count = values.length;
    final sum = values.reduce((a, b) => a + b);
    final mean = sum / count;
    final median = count % 2 == 0 
        ? (values[count ~/ 2 - 1] + values[count ~/ 2]) / 2
        : values[count ~/ 2];
    final p95 = values[(count * 0.95).floor()];
    final p99 = values[(count * 0.99).floor()];

    return {
      'count': count.toDouble(),
      'sum': sum,
      'mean': mean,
      'median': median,
      'min': values.first,
      'max': values.last,
      'p95': p95,
      'p99': p99,
    };
  }

  /// Get gauge value
  dynamic getGauge(String name) => _gauges[name];

  /// Get all metrics
  Map<String, dynamic> getAllMetrics() => {
    'counters': Map<String, int>.from(_counters),
    'histograms': _histograms.map((k, v) => MapEntry(k, getHistogramStats(k))),
    'gauges': Map<String, dynamic>.from(_gauges),
    'timestamps': _timestamps.map((k, v) => MapEntry(k, v.toUtc().toIso8601String())),
    'events': List<Map<String, dynamic>>.from(_events),
  };

  /// Reset all metrics
  void reset() {
    _counters.clear();
    _histograms.clear();
    _timestamps.clear();
    _gauges.clear();
    _events.clear();
  }
}

/// Retrieval metrics collector
class RetrievalMetricsCollector {
  final MiraMetrics _metrics;

  RetrievalMetricsCollector(this._metrics);

  /// Record retrieval operation
  void recordRetrieval({
    required String query,
    required int resultCount,
    required int consideredCount,
    required List<RetrievalResult> results,
    required Duration duration,
  }) {
    _metrics.incrementCounter('retrieval_operations');
    _metrics.recordHistogram('retrieval_duration_ms', duration.inMilliseconds.toDouble());
    _metrics.recordHistogram('retrieval_result_count', resultCount.toDouble());
    _metrics.recordHistogram('retrieval_considered_count', consideredCount.toDouble());

    // Record hit rate
    final hitRate = consideredCount > 0 ? resultCount / consideredCount : 0.0;
    _metrics.recordHistogram('retrieval_hit_rate', hitRate);

    // Record score distribution
    for (final result in results) {
      _metrics.recordHistogram('retrieval_composite_score', result.compositeScore);
      _metrics.recordHistogram('retrieval_semantic_score', result.semanticScore);
      _metrics.recordHistogram('retrieval_recency_score', result.recencyScore);
      _metrics.recordHistogram('retrieval_phase_affinity_score', result.phaseAffinityScore);
      _metrics.recordHistogram('retrieval_domain_match_score', result.domainMatchScore);
      _metrics.recordHistogram('retrieval_engagement_score', result.engagementScore);
    }

    _metrics.recordEvent('retrieval_operation', {
      'query': query,
      'result_count': resultCount,
      'considered_count': consideredCount,
      'duration_ms': duration.inMilliseconds,
      'hit_rate': hitRate,
    });
  }

  /// Record MUR (Memory Use Record) metrics
  void recordMur(MemoryUseRecord mur) {
    _metrics.incrementCounter('mur_generated');
    _metrics.recordHistogram('mur_used_count', mur.used.length.toDouble());
    _metrics.recordHistogram('mur_considered_count', mur.consideredCount.toDouble());

    // Record MUR size
    final murSize = mur.toJson().toString().length;
    _metrics.recordHistogram('mur_size_bytes', murSize.toDouble());

    _metrics.recordEvent('mur_generated', {
      'response_id': mur.responseId,
      'used_count': mur.used.length,
      'considered_count': mur.consideredCount,
      'size_bytes': murSize,
    });
  }
}

/// Policy metrics collector
class PolicyMetricsCollector {
  final MiraMetrics _metrics;

  PolicyMetricsCollector(this._metrics);

  /// Record policy decision
  void recordPolicyDecision({
    required PolicyDecision decision,
    required String domain,
    required String privacyLevel,
    required String actor,
    required String purpose,
  }) {
    _metrics.incrementCounter('policy_decisions');
    
    if (decision.allowed) {
      _metrics.incrementCounter('policy_decisions_allowed');
    } else {
      _metrics.incrementCounter('policy_decisions_denied');
    }

    // Record by domain
    _metrics.incrementCounter('policy_decisions_${domain}');
    
    // Record by privacy level
    _metrics.incrementCounter('policy_decisions_${privacyLevel}');
    
    // Record by actor
    _metrics.incrementCounter('policy_decisions_${actor}');
    
    // Record by purpose
    _metrics.incrementCounter('policy_decisions_${purpose}');

    _metrics.recordEvent('policy_decision', {
      'allowed': decision.allowed,
      'reason': decision.reason,
      'domain': domain,
      'privacy_level': privacyLevel,
      'actor': actor,
      'purpose': purpose,
      'conditions': decision.conditions,
    });
  }

  /// Record consent log entry
  void recordConsentLog({
    required String actor,
    required String purpose,
    required String resource,
    required bool granted,
    required String reason,
  }) {
    _metrics.incrementCounter('consent_log_entries');
    
    if (granted) {
      _metrics.incrementCounter('consent_log_granted');
    } else {
      _metrics.incrementCounter('consent_log_denied');
    }

    _metrics.recordEvent('consent_log_entry', {
      'actor': actor,
      'purpose': purpose,
      'resource': resource,
      'granted': granted,
      'reason': reason,
    });
  }
}

/// VEIL job metrics collector
class VeilJobMetricsCollector {
  final MiraMetrics _metrics;

  VeilJobMetricsCollector(this._metrics);

  /// Record VEIL job execution
  void recordJobExecution(VeilJobResult result) {
    _metrics.incrementCounter('veil_jobs_executed');
    _metrics.incrementCounter('veil_jobs_${result.jobType}');
    
    if (result.success) {
      _metrics.incrementCounter('veil_jobs_successful');
    } else {
      _metrics.incrementCounter('veil_jobs_failed');
    }

    _metrics.recordHistogram('veil_jobs_items_processed', result.itemsProcessed.toDouble());
    _metrics.recordHistogram('veil_jobs_items_modified', result.itemsModified.toDouble());
    _metrics.recordHistogram('veil_jobs_errors', result.errors.length.toDouble());

    _metrics.recordEvent('veil_job_execution', {
      'job_id': result.jobId,
      'job_type': result.jobType,
      'success': result.success,
      'items_processed': result.itemsProcessed,
      'items_modified': result.itemsModified,
      'errors_count': result.errors.length,
      'errors': result.errors,
    });
  }
}

/// Export metrics collector
class ExportMetricsCollector {
  final MiraMetrics _metrics;

  ExportMetricsCollector(this._metrics);

  /// Record export operation
  void recordExport({
    required String exportType,
    required int nodeCount,
    required int edgeCount,
    required int pointerCount,
    required Duration duration,
    required bool success,
    String? error,
  }) {
    _metrics.incrementCounter('exports_attempted');
    _metrics.incrementCounter('exports_$exportType');
    
    if (success) {
      _metrics.incrementCounter('exports_successful');
    } else {
      _metrics.incrementCounter('exports_failed');
    }

    _metrics.recordHistogram('export_duration_ms', duration.inMilliseconds.toDouble());
    _metrics.recordHistogram('export_node_count', nodeCount.toDouble());
    _metrics.recordHistogram('export_edge_count', edgeCount.toDouble());
    _metrics.recordHistogram('export_pointer_count', pointerCount.toDouble());

    _metrics.recordEvent('export_operation', {
      'export_type': exportType,
      'node_count': nodeCount,
      'edge_count': edgeCount,
      'pointer_count': pointerCount,
      'duration_ms': duration.inMilliseconds,
      'success': success,
      if (error != null) 'error': error,
    });
  }

  /// Record MCP bundle verification
  void recordBundleVerification({
    required bool success,
    required Duration duration,
    String? error,
  }) {
    _metrics.incrementCounter('bundle_verifications');
    
    if (success) {
      _metrics.incrementCounter('bundle_verifications_successful');
    } else {
      _metrics.incrementCounter('bundle_verifications_failed');
    }

    _metrics.recordHistogram('bundle_verification_duration_ms', duration.inMilliseconds.toDouble());

    _metrics.recordEvent('bundle_verification', {
      'success': success,
      'duration_ms': duration.inMilliseconds,
      if (error != null) 'error': error,
    });
  }
}

/// System health metrics
class SystemHealthMetrics {
  final MiraMetrics _metrics;

  SystemHealthMetrics(this._metrics);

  /// Record memory usage
  void recordMemoryUsage({
    required int nodeCount,
    required int edgeCount,
    required int pointerCount,
    required int tombstonedCount,
  }) {
    _metrics.setGauge('memory_nodes_total', nodeCount);
    _metrics.setGauge('memory_edges_total', edgeCount);
    _metrics.setGauge('memory_pointers_total', pointerCount);
    _metrics.setGauge('memory_tombstoned_total', tombstonedCount);
    _metrics.setGauge('memory_active_total', nodeCount + edgeCount + pointerCount - tombstonedCount);
  }

  /// Record sync status
  void recordSyncStatus({
    required int pendingOperations,
    required int knownDevices,
    required DateTime lastSync,
  }) {
    _metrics.setGauge('sync_pending_operations', pendingOperations);
    _metrics.setGauge('sync_known_devices', knownDevices);
    _metrics.setGauge('sync_last_sync_age_seconds', 
        DateTime.now().difference(lastSync).inSeconds);
  }

  /// Record error
  void recordError({
    required String errorType,
    required String message,
    String? stackTrace,
  }) {
    _metrics.incrementCounter('errors_total');
    _metrics.incrementCounter('errors_$errorType');
    
    _metrics.recordEvent('error_occurred', {
      'error_type': errorType,
      'message': message,
      if (stackTrace != null) 'stack_trace': stackTrace,
    });
  }
}

/// Metrics aggregator for all MIRA components
class MiraMetricsAggregator {
  final MiraMetrics _metrics;
  final RetrievalMetricsCollector _retrievalCollector;
  final PolicyMetricsCollector _policyCollector;
  final VeilJobMetricsCollector _veilCollector;
  final ExportMetricsCollector _exportCollector;
  final SystemHealthMetrics _healthCollector;

  MiraMetricsAggregator() : 
    _metrics = MiraMetrics(),
    _retrievalCollector = RetrievalMetricsCollector(MiraMetrics()),
    _policyCollector = PolicyMetricsCollector(MiraMetrics()),
    _veilCollector = VeilJobMetricsCollector(MiraMetrics()),
    _exportCollector = ExportMetricsCollector(MiraMetrics()),
    _healthCollector = SystemHealthMetrics(MiraMetrics());

  /// Get all metrics
  Map<String, dynamic> getAllMetrics() => {
    'retrieval': _retrievalCollector._metrics.getAllMetrics(),
    'policy': _policyCollector._metrics.getAllMetrics(),
    'veil': _veilCollector._metrics.getAllMetrics(),
    'export': _exportCollector._metrics.getAllMetrics(),
    'system': _healthCollector._metrics.getAllMetrics(),
    'timestamp': DateTime.now().toUtc().toIso8601String(),
  };

  /// Get health status
  Map<String, dynamic> getHealthStatus() {
    final retrievalHitRate = _retrievalCollector._metrics.getHistogramStats('retrieval_hit_rate');
    final policyDenyRate = _policyCollector._metrics.getCounter('policy_decisions_denied') / 
        max(1, _policyCollector._metrics.getCounter('policy_decisions'));
    final errorRate = _healthCollector._metrics.getCounter('errors_total') / 
        max(1, _retrievalCollector._metrics.getCounter('retrieval_operations'));

    return {
      'status': errorRate < 0.05 && policyDenyRate < 0.1 ? 'healthy' : 'degraded',
      'retrieval_hit_rate': retrievalHitRate['mean'] ?? 0.0,
      'policy_deny_rate': policyDenyRate,
      'error_rate': errorRate,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
  }

  /// Reset all metrics
  void resetAllMetrics() {
    _metrics.reset();
    _retrievalCollector._metrics.reset();
    _policyCollector._metrics.reset();
    _veilCollector._metrics.reset();
    _exportCollector._metrics.reset();
    _healthCollector._metrics.reset();
  }

  /// Get collectors
  RetrievalMetricsCollector get retrieval => _retrievalCollector;
  PolicyMetricsCollector get policy => _policyCollector;
  VeilJobMetricsCollector get veil => _veilCollector;
  ExportMetricsCollector get export => _exportCollector;
  SystemHealthMetrics get health => _healthCollector;
}
