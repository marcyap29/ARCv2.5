/// RIVET Policy Engine
/// 
/// Manages alignment and stability tracking for VEIL-EDGE phase transitions.
/// Implements the policy requirements for phase changes and safe mode triggers.
/// Now includes AURORA circadian-aware policy hooks.
library;

import 'dart:math';
import '../models/veil_edge_models.dart';
import '../../../aurora/models/circadian_context.dart';

/// RIVET Policy Engine for managing phase transitions and alignment tracking with circadian awareness
class RivetPolicyEngine {
  final List<LogSchema> _logHistory = [];
  final Map<String, double> _alignmentHistory = {};
  final Map<String, double> _stabilityHistory = {};

  /// Process a new log and update RIVET state with circadian context
  RivetUpdate processLog(LogSchema log, {CircadianContext? circadianContext}) {
    _logHistory.add(log);
    
    // Update alignment based on log data
    final alignment = calculateAlignment(log, circadianContext: circadianContext);
    _alignmentHistory[log.timestamp.toIso8601String()] = alignment;
    
    // Update stability based on recent trends
    final stability = _calculateStability();
    _stabilityHistory[log.timestamp.toIso8601String()] = stability;
    
    // Check for policy violations with circadian awareness
    final violations = checkPolicyViolations(circadianContext);
    
    return RivetUpdate(
      acknowledged: true,
      rivetUpdates: {
        'alignment': alignment,
        'stability': stability,
        'violations': violations,
        'recommendations': generateRecommendations(alignment, stability, violations, circadianContext),
        'circadian_context': circadianContext?.toJson(),
      },
    );
  }

  /// Calculate alignment score from log data with circadian adjustments
  double calculateAlignment(LogSchema log, {CircadianContext? circadianContext}) {
    // Base alignment from ease, mood, and energy scores
    final easeScore = log.ease / 5.0; // Normalize to 0-1
    final moodScore = log.mood / 5.0; // Normalize to 0-1
    final energyScore = log.energy / 5.0; // Normalize to 0-1
    
    // Weighted average with energy having higher weight
    double baseAlignment = (easeScore * 0.3 + moodScore * 0.3 + energyScore * 0.4);
    
    // Apply circadian adjustments
    if (circadianContext != null) {
      baseAlignment = _applyCircadianAlignmentAdjustment(baseAlignment, circadianContext);
    }
    
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

  /// Apply circadian adjustments to alignment score
  double _applyCircadianAlignmentAdjustment(double baseAlignment, CircadianContext circadianContext) {
    double adjustedAlignment = baseAlignment;
    
    // Evening + fragmented rhythm = lower alignment threshold
    if (circadianContext.isEvening && circadianContext.rhythmScore < 0.45) {
      adjustedAlignment *= 0.9; // Slightly reduce alignment expectations
    }
    
    // Morning person in morning = boost alignment
    if (circadianContext.isMorning && circadianContext.isMorningPerson) {
      adjustedAlignment *= 1.05; // Slight boost for natural rhythm alignment
    }
    
    // Evening person in evening = boost alignment
    if (circadianContext.isEvening && circadianContext.isEveningPerson) {
      adjustedAlignment *= 1.05; // Slight boost for natural rhythm alignment
    }
    
    return adjustedAlignment.clamp(0.0, 1.0);
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

  /// Check for policy violations with circadian awareness
  List<String> checkPolicyViolations([CircadianContext? circadianContext]) {
    final violations = <String>[];
    
    if (_alignmentHistory.length >= 2) {
      final recentAlignments = _alignmentHistory.values.take(2).toList();
      final avgRecentAlignment = recentAlignments.reduce((a, b) => a + b) / recentAlignments.length;
      
      // Adjust threshold based on circadian context
      double alignmentThreshold = 0.45;
      if (circadianContext != null) {
        if (circadianContext.isEvening && circadianContext.rhythmScore < 0.45) {
          alignmentThreshold = 0.40; // Lower threshold for fragmented evening rhythm
        } else if (circadianContext.isMorning && circadianContext.isMorningPerson) {
          alignmentThreshold = 0.50; // Higher threshold for morning person in morning
        }
      }
      
      if (avgRecentAlignment < alignmentThreshold) {
        violations.add('low_alignment');
        if (circadianContext != null) {
          violations.add('circadian_adjusted_threshold');
        }
      }
    }
    
    if (_logHistory.length >= 3) {
      final recentLogs = _logHistory.take(3).toList();
      final avgAlignment = recentLogs.map((log) => 
        _alignmentHistory[log.timestamp.toIso8601String()] ?? 0.5).reduce((a, b) => a + b) / recentLogs.length;
      
      // Adjust phase change threshold based on circadian context
      double phaseChangeThreshold = 0.62;
      if (circadianContext != null) {
        if (circadianContext.isEvening && circadianContext.rhythmScore < 0.45) {
          phaseChangeThreshold = 0.70; // Higher threshold for evening + fragmented rhythm
        } else if (circadianContext.isMorning && circadianContext.isMorningPerson) {
          phaseChangeThreshold = 0.58; // Lower threshold for morning person in morning
        }
      }
      
      if (avgAlignment < phaseChangeThreshold) {
        violations.add('insufficient_alignment_for_phase_change');
        if (circadianContext != null) {
          violations.add('circadian_adjusted_phase_change_threshold');
        }
      }
    }
    
    return violations;
  }

  /// Generate recommendations based on current state with circadian awareness
  List<String> generateRecommendations(
    double alignment, 
    double stability, 
    List<String> violations,
    [CircadianContext? circadianContext]
  ) {
    final recommendations = <String>[];
    
    if (violations.contains('low_alignment')) {
      if (circadianContext != null && circadianContext.isEvening && circadianContext.isRhythmFragmented) {
        recommendations.add('Force safe variant - evening rhythm fragmentation detected');
      } else {
        recommendations.add('Force safe variant for next session');
      }
    }
    
    if (violations.contains('insufficient_alignment_for_phase_change')) {
      if (circadianContext != null && circadianContext.isEvening && circadianContext.isRhythmFragmented) {
        recommendations.add('Maintain current phase group - evening rhythm needs stabilization');
      } else {
        recommendations.add('Maintain current phase group');
      }
    }
    
    if (stability < 0.55) {
      if (circadianContext != null && circadianContext.rhythmScore < 0.45) {
        recommendations.add('Focus on stabilizing current practices - rhythm coherence needed');
      } else {
        recommendations.add('Focus on stabilizing current practices');
      }
    }
    
    if (alignment < 0.5) {
      if (circadianContext != null && circadianContext.isEvening) {
        recommendations.add('Consider gentle restorative activities appropriate for evening');
      } else {
        recommendations.add('Consider restorative activities');
      }
    }
    
    // Add circadian-specific recommendations
    if (circadianContext != null) {
          if (circadianContext.rhythmScore < 0.45) {
        recommendations.add('Consider establishing more consistent daily rhythms');
      }
      
      if (circadianContext.isMorning && !circadianContext.isMorningPerson) {
        recommendations.add('Consider adjusting morning activities to match your chronotype');
      }
      
      if (circadianContext.isEvening && !circadianContext.isEveningPerson) {
        recommendations.add('Consider adjusting evening activities to match your chronotype');
      }
    }
    
    return recommendations;
  }

  /// Check if phase change is allowed based on RIVET policy with circadian awareness
  bool canChangePhase({CircadianContext? circadianContext}) {
    if (_logHistory.length < 3) return false;
    
    // Check mean alignment over last 3 logs
    final recentLogs = _logHistory.take(3).toList();
    final recentAlignments = recentLogs.map((log) => 
      _alignmentHistory[log.timestamp.toIso8601String()] ?? 0.5).toList();
    final meanAlign = recentAlignments.reduce((a, b) => a + b) / recentAlignments.length;
    
    // Adjust threshold based on circadian context
    double alignmentThreshold = 0.62;
    if (circadianContext != null) {
      if (circadianContext.isEvening && circadianContext.isRhythmFragmented) {
        alignmentThreshold = 0.70; // Higher threshold for evening + fragmented rhythm
      } else if (circadianContext.isMorning && circadianContext.isMorningPerson) {
        alignmentThreshold = 0.58; // Lower threshold for morning person in morning
      }
    }
    
    if (meanAlign < alignmentThreshold) return false;
    
    // Check non-negative stability trend over 7 days
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final weekLogs = _logHistory.where((log) => 
      log.timestamp.isAfter(weekAgo)).toList();
    
    if (weekLogs.length < 2) return false;
    
    final stabilityTrend = _calculateStabilityTrend(weekLogs);
    if (stabilityTrend < 0) return false;
    
    // Additional circadian constraint: no phase changes in evening with fragmented rhythm
    if (circadianContext != null && circadianContext.isEvening && circadianContext.isRhythmFragmented) {
      return false;
    }
    
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
