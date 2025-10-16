/// VEIL-EDGE Router - Phase group selection and routing logic
/// 
/// Implements the core routing algorithm that maps ATLAS phases to phase groups
/// with hysteresis, cooldown, and SENTINEL safety modifiers.

import '../models/veil_edge_models.dart';

/// Configuration constants for VEIL-EDGE routing
class VeilEdgeConfig {
  static const double confidenceLow = 0.60;
  static const double stabilityMin = 0.55;
  static const double alignOk = 0.62;
  static const double alignLow = 0.45;
  static const int cooldownHours = 48;
  static const int watchModeMaxMinutes = 10;
  
  static Duration get cooldownDuration => Duration(hours: cooldownHours);
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

  /// Select the appropriate phase group based on ATLAS, SENTINEL, and RIVET states
  VeilEdgeRouteResult route({
    required UserSignals signals,
    required AtlasState atlas,
    required SentinelState sentinel,
    required RivetState rivet,
  }) {
    final now = DateTime.now();
    
    // Get base phase group
    final baseGroup = PhaseGroupMapper.getBaseGroup(atlas.phase);
    if (baseGroup == null) {
      throw ArgumentError('Unknown phase: ${atlas.phase}');
    }

    String phaseGroup = baseGroup.name;
    String variant = '';
    List<String> blocks = [];

    // Apply confidence-based blending
    if (atlas.confidence < VeilEdgeConfig.confidenceLow) {
      final neighborGroup = PhaseGroupMapper.getNeighborGroup(atlas.neighbor);
      if (neighborGroup != null) {
        phaseGroup = '${baseGroup.name}+${neighborGroup.name}';
      }
    }

    // Apply hysteresis and cooldown logic
    final timeSinceLastSwitch = now.difference(rivet.lastSwitchTimestamp);
    final canSwitch = timeSinceLastSwitch >= VeilEdgeConfig.cooldownDuration && 
                     rivet.stability >= VeilEdgeConfig.stabilityMin;

    if (canSwitch && atlas.confidence < VeilEdgeConfig.confidenceLow) {
      // Allow phase switching if conditions are met
      final neighborGroup = PhaseGroupMapper.getNeighborGroup(atlas.neighbor);
      if (neighborGroup != null) {
        phaseGroup = '${baseGroup.name}+${neighborGroup.name}';
      }
    }

    // Apply SENTINEL modifiers
    switch (sentinel.state) {
      case 'watch':
        variant = ':safe';
        blocks = _getSafeBlocks(phaseGroup);
        break;
      case 'alert':
        variant = ':alert';
        blocks = _getAlertBlocks(phaseGroup);
        break;
      default:
        blocks = _getStandardBlocks(phaseGroup);
    }

    // Apply RIVET policy for forced safe variants
    if (rivet.align < VeilEdgeConfig.alignLow) {
      variant = ':safe';
      blocks = _getSafeBlocks(phaseGroup);
    }

    return VeilEdgeRouteResult(
      phaseGroup: phaseGroup,
      variant: variant,
      blocks: blocks,
      metadata: {
        'confidence': atlas.confidence,
        'stability': rivet.stability,
        'align': rivet.align,
        'sentinel_state': sentinel.state,
        'can_switch': canSwitch,
        'time_since_switch': timeSinceLastSwitch.inHours,
      },
    );
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
