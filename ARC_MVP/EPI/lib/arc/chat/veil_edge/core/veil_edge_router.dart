/// VEIL-EDGE Router - Phase group selection and routing logic
/// 
/// Implements the core routing algorithm that maps ATLAS phases to phase groups
/// with hysteresis, cooldown, and SENTINEL safety modifiers.
library;

import '../models/veil_edge_models.dart';

/// Configuration constants for VEIL-EDGE routing
class VeilEdgeConfig {
  static const double confidenceLow = 0.60;
  static const double stabilityMin = 0.55;
  static const double alignOk = 0.62;
  static const double alignLow = 0.45;
  static const int cooldownHours = 48;
  static const int watchModeMaxMinutes = 10;
  
  static Duration get cooldownDuration => const Duration(hours: cooldownHours);
}

/// Phase group mapping for ATLAS phases
class PhaseGroupMapper {
  static const Map<String, PhaseGroup> _phaseToGroup = {
    'Discovery': PhaseGroup.dB,
    'Breakthrough': PhaseGroup.dB,
    'Transition': PhaseGroup.tD,
    'Recovery': PhaseGroup.rT,
    'Consolidation': PhaseGroup.cR,
  };

  static const Map<String, PhaseGroup> _neighborToGroup = {
    'Discovery': PhaseGroup.dB,
    'Breakthrough': PhaseGroup.dB,
    'Transition': PhaseGroup.tD,
    'Recovery': PhaseGroup.rT,
    'Consolidation': PhaseGroup.cR,
  };

  /// Get the base phase group for a given phase
  static PhaseGroup? getBaseGroup(String phase) {
    return _phaseToGroup[phase];
  }

  /// Get the phase group for a neighbor phase
  static PhaseGroup? getNeighborGroup(String neighbor) {
    return _neighborToGroup[neighbor];
  }
}

/// VEIL-EDGE Router implementation
class VeilEdgeRouter {

  /// Select the appropriate phase group based on ATLAS, SENTINEL, RIVET, and AURORA states
  VeilEdgeRouteResult route(VeilEdgeInput input) {
    final now = DateTime.now();
    
    // Get base phase group
    final baseGroup = PhaseGroupMapper.getBaseGroup(input.atlas.phase);
    if (baseGroup == null) {
      throw ArgumentError('Unknown phase: ${input.atlas.phase}');
    }

    String phaseGroup = baseGroup.name;
    String variant = '';
    List<String> blocks = [];

    // Apply confidence-based blending
    if (input.atlas.confidence < VeilEdgeConfig.confidenceLow) {
      final neighborGroup = PhaseGroupMapper.getNeighborGroup(input.atlas.neighbor);
      if (neighborGroup != null) {
        phaseGroup = '${baseGroup.name}+${neighborGroup.name}';
      }
    }

    // Apply hysteresis and cooldown logic
    final timeSinceLastSwitch = now.difference(input.rivet.lastSwitchTimestamp);
    final canSwitch = timeSinceLastSwitch >= VeilEdgeConfig.cooldownDuration && 
                     input.rivet.stability >= VeilEdgeConfig.stabilityMin;

    if (canSwitch && input.atlas.confidence < VeilEdgeConfig.confidenceLow) {
      // Allow phase switching if conditions are met
      final neighborGroup = PhaseGroupMapper.getNeighborGroup(input.atlas.neighbor);
      if (neighborGroup != null) {
        phaseGroup = '${baseGroup.name}+${neighborGroup.name}';
      }
    }

    // Get base blocks for phase group
    final baseBlocks = _getStandardBlocks(phaseGroup);
    
    // Apply time-aware policy weights
    final weightedBlocks = _applyTimeAwareWeights(input, baseBlocks);

    // Apply SENTINEL modifiers
    switch (input.sentinel.state) {
      case 'watch':
        variant = ':safe';
        blocks = _getSafeBlocks(phaseGroup);
        break;
      case 'alert':
        variant = ':alert';
        blocks = _getAlertBlocks(phaseGroup);
        break;
      default:
        blocks = weightedBlocks;
    }

    // Apply RIVET policy for forced safe variants
    if (input.rivet.align < VeilEdgeConfig.alignLow) {
      variant = ':safe';
      blocks = _getSafeBlocks(phaseGroup);
    }

    return VeilEdgeRouteResult(
      phaseGroup: phaseGroup,
      variant: variant,
      blocks: blocks,
      metadata: {
        'confidence': input.atlas.confidence,
        'stability': input.rivet.stability,
        'align': input.rivet.align,
        'sentinel_state': input.sentinel.state,
        'can_switch': canSwitch,
        'time_since_switch': timeSinceLastSwitch.inHours,
        'circadian_window': input.circadianWindow,
        'circadian_chronotype': input.circadianChronotype,
        'rhythm_score': input.rhythmScore,
      },
    );
  }

  /// Apply time-aware policy weights to block selection
  List<String> _applyTimeAwareWeights(VeilEdgeInput input, List<String> baseBlocks) {
    final blockWeights = <String, double>{};
    
    // Initialize weights for all blocks
    for (final block in baseBlocks) {
      blockWeights[block] = 1.0;
    }

    // Apply policy hook for Commit block
    if (!allowCommitNow(input)) {
      blockWeights['Commit'] = 0.0;
    }

    // Time-aware nudges based on circadian window
    if (input.isEvening) {
      // Evening: reduce activation, increase containment
      blockWeights['Nudge'] = (blockWeights['Nudge'] ?? 0) * 0.8;
      blockWeights['Orient'] = (blockWeights['Orient'] ?? 0) * 0.8;
      blockWeights['Mirror'] = (blockWeights['Mirror'] ?? 0) * 1.15;
      blockWeights['Safeguard'] = (blockWeights['Safeguard'] ?? 0) * 
          (input.sentinel.isOk ? 1.1 : 1.25);
      blockWeights['Log'] = (blockWeights['Log'] ?? 0) * 1.05;
    } else if (input.isMorning) {
      // Morning: increase orientation and commitment
      blockWeights['Orient'] = (blockWeights['Orient'] ?? 0) * 1.15;
      blockWeights['Mirror'] = (blockWeights['Mirror'] ?? 0) * 0.95;
      blockWeights['Safeguard'] = (blockWeights['Safeguard'] ?? 0) * 0.9;
    } else {
      // Afternoon: synthesis and decision clarity
      blockWeights['Orient'] = (blockWeights['Orient'] ?? 0) * 1.1;
      blockWeights['Nudge'] = (blockWeights['Nudge'] ?? 0) * 1.05;
    }

    // Rhythm coherence guardrails
    if (input.isRhythmFragmented && input.isEvening) {
      // Reduce activation content when rhythm is fragmented in evening
      blockWeights['Commit'] = (blockWeights['Commit'] ?? 0) * 0.5;
      blockWeights['Orient'] = (blockWeights['Orient'] ?? 0) * 0.8;
      blockWeights['Safeguard'] = (blockWeights['Safeguard'] ?? 0) * 1.2;
      blockWeights['Mirror'] = (blockWeights['Mirror'] ?? 0) * 1.1;
    }

    // SENTINEL enforcement (watch/alert tighten further)
    if (!input.sentinel.isOk) {
      blockWeights['Commit'] = (blockWeights['Commit'] ?? 0) * 0.3;
      blockWeights['Nudge'] = (blockWeights['Nudge'] ?? 0) * 0.6;
      blockWeights['Orient'] = (blockWeights['Orient'] ?? 0) * 0.7;
      blockWeights['Safeguard'] = (blockWeights['Safeguard'] ?? 0) * 1.3;
      blockWeights['Mirror'] = (blockWeights['Mirror'] ?? 0) * 1.15;
    }

    // Select top blocks based on weights
    return _selectTopBlocks(blockWeights, baseBlocks);
  }

  /// Select top blocks based on weights
  List<String> _selectTopBlocks(Map<String, double> weights, List<String> baseBlocks) {
    // Sort blocks by weight (descending)
    final sortedBlocks = baseBlocks.toList()
      ..sort((a, b) => (weights[b] ?? 0).compareTo(weights[a] ?? 0));

    // Select top blocks, ensuring we have at least Mirror and Log
    final selectedBlocks = <String>[];
    
    // Always include Mirror and Log
    if (baseBlocks.contains('Mirror')) selectedBlocks.add('Mirror');
    if (baseBlocks.contains('Log')) selectedBlocks.add('Log');
    
    // Add other blocks based on weights
    for (final block in sortedBlocks) {
      if (block != 'Mirror' && block != 'Log' && !selectedBlocks.contains(block)) {
        if (weights[block] != null && weights[block]! > 0.5) {
          selectedBlocks.add(block);
        }
      }
    }

    // Ensure we have at least 3 blocks
    if (selectedBlocks.length < 3) {
      for (final block in sortedBlocks) {
        if (!selectedBlocks.contains(block)) {
          selectedBlocks.add(block);
          if (selectedBlocks.length >= 3) break;
        }
      }
    }

    return selectedBlocks;
  }

  /// Get standard blocks for a phase group
  List<String> _getStandardBlocks(String phaseGroup) {
    switch (phaseGroup) {
      case 'D-B':
        return ['Mirror', 'Orient', 'Nudge', 'Commit', 'Log'];
      case 'T-D':
        return ['Mirror', 'Orient', 'Safeguard', 'Nudge', 'Log'];
      case 'R-T':
        return ['Mirror', 'Safeguard', 'Nudge', 'Commit', 'Log'];
      case 'C-R':
        return ['Mirror', 'Orient', 'Nudge', 'Commit', 'Log'];
      default:
        return ['Mirror', 'Log']; // Fallback
    }
  }

  /// Get safe blocks for watch mode
  List<String> _getSafeBlocks(String phaseGroup) {
    switch (phaseGroup) {
      case 'D-B':
        return ['Mirror', 'Orient', 'Nudge', 'Log'];
      case 'T-D':
        return ['Mirror', 'Safeguard', 'Nudge', 'Log'];
      case 'R-T':
        return ['Mirror', 'Safeguard', 'Nudge', 'Log'];
      case 'C-R':
        return ['Mirror', 'Orient', 'Nudge', 'Log'];
      default:
        return ['Mirror', 'Log'];
    }
  }

  /// Get alert blocks (Safeguard + Mirror only)
  List<String> _getAlertBlocks(String phaseGroup) {
    return ['Mirror', 'Safeguard', 'Log'];
  }

  /// Check if phase change is allowed based on RIVET policy
  bool canChangePhase({
    required List<LogSchema> recentLogs,
    required RivetState currentRivet,
  }) {
    if (recentLogs.length < 3) return false;

    // Check mean alignment over last 3 logs
    final recentAlignments = recentLogs.take(3).map((log) => 
      _extractAlignmentFromLog(log)).toList();
    final meanAlign = recentAlignments.reduce((a, b) => a + b) / recentAlignments.length;

    if (meanAlign < VeilEdgeConfig.alignOk) return false;

    // Check non-negative stability trend over 7 days
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final weekLogs = recentLogs.where((log) => 
      log.timestamp.isAfter(weekAgo)).toList();

    if (weekLogs.length < 2) return false;

    final stabilityTrend = _calculateStabilityTrend(weekLogs);
    if (stabilityTrend < 0) return false;

    return true;
  }

  /// Check if Commit block is allowed based on circadian and policy constraints
  bool allowCommitNow(VeilEdgeInput input) {
    final cooldownOk = _hoursSinceLastPhaseChange(input.rivet.lastSwitchTimestamp) >= 48;
    final rivetOk = input.rivet.align >= 0.62 && input.rivet.stability >= 0.55;
    final sentinelOk = input.sentinel.isOk;
    
    // Evening + fragmented rhythm = no commit
    if (input.isEvening && input.isRhythmFragmented) return false;
    
    return cooldownOk && rivetOk && sentinelOk;
  }

  /// Calculate hours since last phase change
  int _hoursSinceLastPhaseChange(DateTime lastSwitch) {
    return DateTime.now().difference(lastSwitch).inHours;
  }

  /// Extract alignment value from a log (placeholder implementation)
  double _extractAlignmentFromLog(LogSchema log) {
    // This would need to be implemented based on how alignment
    // is calculated from log data
    return 0.5; // Placeholder
  }

  /// Calculate stability trend from logs
  double _calculateStabilityTrend(List<LogSchema> logs) {
    if (logs.length < 2) return 0.0;

    // Calculate trend (simplified - would need actual stability metrics)
    // Placeholder calculation - in reality this would use actual stability metrics
    return 0.1; // Positive trend
  }
}
