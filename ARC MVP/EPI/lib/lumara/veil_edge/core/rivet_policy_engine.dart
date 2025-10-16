/// RIVET Policy Engine
/// 
/// Manages alignment and stability tracking for VEIL-EDGE phase transitions.
/// Implements the policy requirements for phase changes and safe mode triggers.

import 'dart:math';
import '../models/veil_edge_models.dart';

/// RIVET Policy Engine for managing phase transitions and alignment tracking
class RivetPolicyEngine {
  final List<LogSchema> _logHistory = [];
  final Map<String, double> _alignmentHistory = {};
  final Map<String, double> _stabilityHistory = {};

  /// Process a new log and update RIVET state
  RivetUpdate processLog(LogSchema log) {
    _logHistory.add(log);
    
    // Update alignment based on log data
    final alignment = _calculateAlignment(log);
    _alignmentHistory[log.timestamp.toIso8601String()] = alignment;
    
    // Update stability based on recent trends
    final stability = _calculateStability();
    _stabilityHistory[log.timestamp.toIso8601String()] = stability;
    
    // Check for policy violations
    final violations = _checkPolicyViolations();
    
    return RivetUpdate(
      acknowledged: true,
      rivetUpdates: {
        'alignment': alignment,
        'stability': stability,
        'violations': violations,
        'recommendations': _generateRecommendations(alignment, stability, violations),
      },
    );
  }

  /// Calculate alignment score from log data
  double _calculateAlignment(LogSchema log) {
    // Base alignment from ease, mood, and energy scores
    final easeScore = log.ease / 5.0; // Normalize to 0-1
    final moodScore = log.mood / 5.0; // Normalize to 0-1
    final energyScore = log.energy / 5.0; // Normalize to 0-1
    
    // Weighted average with energy having higher weight
    final baseAlignment = (easeScore * 0.3 + moodScore * 0.3 + energyScore * 0.4);
    
    // Adjust based on outcome metric if available
    if (log.outcomeMetric.isNotEmpty) {
      final outcomeValue = log.outcomeMetric['value'] as num?;
      if (outcomeValue != null) {
        final normalizedOutcome = outcomeValue.toDouble() / 10.0; // Assuming 0-10 scale
        return (baseAlignment + normalizedOutcome) / 2.0;
      }
    }
    
    return baseAlignment.clamp(0.0, 1.0);
  }

  /// Calculate stability score from recent trends
  double _calculateStability() {
    if (_alignmentHistory.length < 3) return 0.5; // Default for insufficient data
    
    final recentAlignments = _alignmentHistory.values.take(7).toList();
    if (recentAlignments.length < 2) return 0.5;
    
    // Calculate variance (lower variance = higher stability)
    final mean = recentAlignments.reduce((a, b) => a + b) / recentAlignments.length;
    final variance = recentAlignments
        .map((x) => pow(x - mean, 2))
        .reduce((a, b) => a + b) / recentAlignments.length;
    
    // Convert variance to stability (0-1 scale, higher is more stable)
    final stability = (1.0 - variance).clamp(0.0, 1.0);
    
    return stability;
  }

  /// Check for policy violations
  List<String> _checkPolicyViolations() {
    final violations = <String>[];
    
    if (_alignmentHistory.length >= 2) {
      final recentAlignments = _alignmentHistory.values.take(2).toList();
      final avgRecentAlignment = recentAlignments.reduce((a, b) => a + b) / recentAlignments.length;
      
      if (avgRecentAlignment < 0.45) {
        violations.add('low_alignment');
      }
    }
    
    if (_logHistory.length >= 3) {
      final recentLogs = _logHistory.take(3).toList();
      final avgAlignment = recentLogs.map((log) => 
        _alignmentHistory[log.timestamp.toIso8601String()] ?? 0.5).reduce((a, b) => a + b) / recentLogs.length;
      
      if (avgAlignment < 0.62) {
        violations.add('insufficient_alignment_for_phase_change');
      }
    }
    
    return violations;
  }

  /// Generate recommendations based on current state
  List<String> _generateRecommendations(double alignment, double stability, List<String> violations) {
    final recommendations = <String>[];
    
    if (violations.contains('low_alignment')) {
      recommendations.add('Force safe variant for next session');
    }
    
    if (violations.contains('insufficient_alignment_for_phase_change')) {
      recommendations.add('Maintain current phase group');
    }
    
    if (stability < 0.55) {
      recommendations.add('Focus on stabilizing current practices');
    }
    
    if (alignment < 0.5) {
      recommendations.add('Consider restorative activities');
    }
    
    return recommendations;
  }

  /// Check if phase change is allowed based on RIVET policy
  bool canChangePhase() {
    if (_logHistory.length < 3) return false;
    
    // Check mean alignment over last 3 logs
    final recentLogs = _logHistory.take(3).toList();
    final recentAlignments = recentLogs.map((log) => 
      _alignmentHistory[log.timestamp.toIso8601String()] ?? 0.5).toList();
    final meanAlign = recentAlignments.reduce((a, b) => a + b) / recentAlignments.length;
    
    if (meanAlign < 0.62) return false;
    
    // Check non-negative stability trend over 7 days
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final weekLogs = _logHistory.where((log) => 
      log.timestamp.isAfter(weekAgo)).toList();
    
    if (weekLogs.length < 2) return false;
    
    final stabilityTrend = _calculateStabilityTrend(weekLogs);
    if (stabilityTrend < 0) return false;
    
    return true;
  }

  /// Calculate stability trend from logs
  double _calculateStabilityTrend(List<LogSchema> logs) {
    if (logs.length < 2) return 0.0;
    
    // Sort by timestamp
    final sortedLogs = List<LogSchema>.from(logs)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    // Calculate trend using linear regression
    final n = sortedLogs.length;
    final xValues = List.generate(n, (i) => i.toDouble());
    final yValues = sortedLogs.map((log) => 
      _alignmentHistory[log.timestamp.toIso8601String()] ?? 0.5).toList();
    
    final xMean = xValues.reduce((a, b) => a + b) / n;
    final yMean = yValues.reduce((a, b) => a + b) / n;
    
    double numerator = 0.0;
    double denominator = 0.0;
    
    for (int i = 0; i < n; i++) {
      final xDiff = xValues[i] - xMean;
      final yDiff = yValues[i] - yMean;
      numerator += xDiff * yDiff;
      denominator += xDiff * xDiff;
    }
    
    if (denominator == 0) return 0.0;
    
    return numerator / denominator; // Slope of the trend line
  }

  /// Get current RIVET state
  RivetState getCurrentState() {
    final now = DateTime.now();
    final alignment = _alignmentHistory.isNotEmpty 
        ? _alignmentHistory.values.last 
        : 0.5;
    final stability = _stabilityHistory.isNotEmpty 
        ? _stabilityHistory.values.last 
        : 0.5;
    
    return RivetState(
      align: alignment,
      stability: stability,
      windowDays: 7,
      lastSwitchTimestamp: now, // This would be tracked separately in practice
    );
  }

  /// Clear old history to prevent memory bloat
  void cleanupHistory({int maxLogs = 100}) {
    if (_logHistory.length > maxLogs) {
      final cutoff = _logHistory.length - maxLogs;
      _logHistory.removeRange(0, cutoff);
      
      // Clean up corresponding history maps
      final cutoffTime = _logHistory.first.timestamp;
      _alignmentHistory.removeWhere((key, value) => 
        DateTime.parse(key).isBefore(cutoffTime));
      _stabilityHistory.removeWhere((key, value) => 
        DateTime.parse(key).isBefore(cutoffTime));
    }
  }

  /// Get alignment history for analysis
  Map<String, double> get alignmentHistory => Map.unmodifiable(_alignmentHistory);
  
  /// Get stability history for analysis
  Map<String, double> get stabilityHistory => Map.unmodifiable(_stabilityHistory);
  
  /// Get log history for analysis
  List<LogSchema> get logHistory => List.unmodifiable(_logHistory);
}
