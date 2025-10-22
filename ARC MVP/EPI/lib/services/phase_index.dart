// lib/services/phase_index.dart
// Efficient timeline resolution for phase regimes

// import 'dart:math'; // Not currently used
import '../models/phase_models.dart';

class PhaseIndex {
  final List<PhaseRegime> _regimes;
  final List<DateTime> _startTimes;
  
  PhaseIndex(List<PhaseRegime> regimes) 
      : _regimes = List.from(regimes)..sort((a, b) => a.start.compareTo(b.start)),
        _startTimes = regimes.map((r) => r.start).toList()..sort();

  /// Find the regime that contains the given timestamp
  PhaseRegime? regimeFor(DateTime timestamp) {
    if (_regimes.isEmpty) return null;
    
    // Binary search for the regime containing this timestamp
    int left = 0;
    int right = _regimes.length - 1;
    
    while (left <= right) {
      int mid = (left + right) ~/ 2;
      final regime = _regimes[mid];
      
      if (regime.contains(timestamp)) {
        return regime;
      } else if (timestamp.isBefore(regime.start)) {
        right = mid - 1;
      } else {
        left = mid + 1;
      }
    }
    
    return null;
  }

  /// Get all regimes that overlap with the given time range
  List<PhaseRegime> regimesInRange(DateTime start, DateTime end) {
    return _regimes.where((regime) {
      return regime.start.isBefore(end) && 
             (regime.end == null || regime.end!.isAfter(start));
    }).toList();
  }

  /// Get the current ongoing regime (if any)
  PhaseRegime? get currentRegime {
    final now = DateTime.now();
    return regimeFor(now);
  }

  /// Get the phase label for a given timestamp
  PhaseLabel? phaseFor(DateTime timestamp) {
    return regimeFor(timestamp)?.label;
  }

  /// Get all regime boundaries (start/end times)
  List<DateTime> get boundaries {
    final boundaries = <DateTime>[];
    for (final regime in _regimes) {
      boundaries.add(regime.start);
      if (regime.end != null) {
        boundaries.add(regime.end!);
      }
    }
    boundaries.sort();
    return boundaries;
  }

  /// Find regimes that need attention (long dwell, low confidence, etc.)
  List<PhaseRegime> findRegimesNeedingAttention({
    Duration minDwell = const Duration(days: 60),
    double minConfidence = 0.5,
  }) {
    return _regimes.where((regime) {
      // Check if regime has been ongoing too long
      if (regime.isOngoing && regime.duration > minDwell) {
        return true;
      }
      
      // Check if rivet regime has low confidence
      if (regime.source == PhaseSource.rivet && 
          (regime.confidence ?? 0.0) < minConfidence) {
        return true;
      }
      
      return false;
    }).toList();
  }

  /// Get timeline statistics
  PhaseTimelineStats get stats {
    final userRegimes = _regimes.where((r) => r.source == PhaseSource.user).length;
    final rivetRegimes = _regimes.where((r) => r.source == PhaseSource.rivet).length;
    
    final phaseDurations = <PhaseLabel, Duration>{};
    for (final regime in _regimes) {
      phaseDurations[regime.label] = 
          (phaseDurations[regime.label] ?? Duration.zero) + regime.duration;
    }
    
    final totalDuration = phaseDurations.values.fold(
      Duration.zero, 
      (sum, duration) => sum + duration,
    );
    
    final recentRegimes = _regimes.take(5).toList();
    
    return PhaseTimelineStats(
      totalRegimes: _regimes.length,
      userRegimes: userRegimes,
      rivetRegimes: rivetRegimes,
      totalDuration: totalDuration,
      phaseDurations: phaseDurations,
      recentRegimes: recentRegimes,
    );
  }

  /// Add a new regime and maintain sorted order
  void addRegime(PhaseRegime regime) {
    _regimes.add(regime);
    _regimes.sort((a, b) => a.start.compareTo(b.start));
    _startTimes.add(regime.start);
    _startTimes.sort();
  }

  /// Remove a regime
  void removeRegime(String regimeId) {
    _regimes.removeWhere((r) => r.id == regimeId);
    _startTimes.clear();
    _startTimes.addAll(_regimes.map((r) => r.start));
    _startTimes.sort();
  }

  /// Update a regime
  void updateRegime(PhaseRegime updatedRegime) {
    final index = _regimes.indexWhere((r) => r.id == updatedRegime.id);
    if (index != -1) {
      _regimes[index] = updatedRegime;
      _regimes.sort((a, b) => a.start.compareTo(b.start));
      _startTimes.clear();
      _startTimes.addAll(_regimes.map((r) => r.start));
      _startTimes.sort();
    }
  }

  /// Split a regime at the given timestamp
  List<PhaseRegime> splitRegime(String regimeId, DateTime splitAt) {
    final regimeIndex = _regimes.indexWhere((r) => r.id == regimeId);
    if (regimeIndex == -1) return [];
    
    final originalRegime = _regimes[regimeIndex];
    if (!originalRegime.contains(splitAt)) return [];
    
    final leftRegime = originalRegime.copyWith(
      end: splitAt,
      updatedAt: DateTime.now(),
    );
    
    final rightRegime = PhaseRegime(
      id: '${originalRegime.id}_split_${DateTime.now().millisecondsSinceEpoch}',
      label: originalRegime.label,
      start: splitAt,
      end: originalRegime.end,
      source: originalRegime.source,
      confidence: originalRegime.confidence,
      inferredAt: originalRegime.inferredAt,
      anchors: originalRegime.anchors,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    _regimes[regimeIndex] = leftRegime;
    addRegime(rightRegime);
    
    return [leftRegime, rightRegime];
  }

  /// Merge two adjacent regimes
  PhaseRegime? mergeRegimes(String leftId, String rightId) {
    final leftIndex = _regimes.indexWhere((r) => r.id == leftId);
    final rightIndex = _regimes.indexWhere((r) => r.id == rightId);
    
    if (leftIndex == -1 || rightIndex == -1) return null;
    if (leftIndex + 1 != rightIndex) return null; // Must be adjacent
    
    final leftRegime = _regimes[leftIndex];
    final rightRegime = _regimes[rightIndex];
    
    // Check if they can be merged (same label or user confirms)
    if (leftRegime.label != rightRegime.label) return null;
    
    final mergedRegime = leftRegime.copyWith(
      end: rightRegime.end,
      anchors: [...leftRegime.anchors, ...rightRegime.anchors],
      updatedAt: DateTime.now(),
    );
    
    _regimes[leftIndex] = mergedRegime;
    removeRegime(rightId);
    
    return mergedRegime;
  }

  /// Get all regimes as a sorted list
  List<PhaseRegime> get allRegimes => List.unmodifiable(_regimes);
}
