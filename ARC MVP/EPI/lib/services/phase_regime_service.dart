// lib/services/phase_regime_service.dart
// Service for managing phase regimes and timeline

import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/phase_models.dart';
import '../models/journal_entry_model.dart';
import 'phase_index.dart';
import 'rivet_sweep_service.dart';
import 'analytics_service.dart';

class PhaseRegimeService {
  static const String _regimesBoxName = 'phase_regimes';
  
  // final AnalyticsService _analytics; // TODO: Use analytics
  final RivetSweepService _rivetSweep;
  
  Box<PhaseRegime>? _regimesBox;
  PhaseIndex? _phaseIndex;
  
  PhaseRegimeService(AnalyticsService analytics, this._rivetSweep);

  /// Initialize the service
  Future<void> initialize() async {
    // Register Hive adapters if not already registered
    if (!Hive.isAdapterRegistered(200)) {
      Hive.registerAdapter(PhaseRegimeAdapter());
    }
    if (!Hive.isAdapterRegistered(201)) {
      Hive.registerAdapter(PhaseInfoAdapter());
    }
    if (!Hive.isAdapterRegistered(202)) {
      Hive.registerAdapter(PhaseWindowAdapter());
    }
    if (!Hive.isAdapterRegistered(203)) {
      Hive.registerAdapter(PhaseLabelAdapter());
    }
    if (!Hive.isAdapterRegistered(204)) {
      Hive.registerAdapter(PhaseSourceAdapter());
    }

    _regimesBox = await Hive.openBox<PhaseRegime>(_regimesBoxName);
    _loadPhaseIndex();
  }

  /// Get the current phase index
  PhaseIndex get phaseIndex {
    if (_phaseIndex == null) {
      _loadPhaseIndex();
    }
    return _phaseIndex ?? PhaseIndex([]);
  }

  /// Load phase index from storage
  void _loadPhaseIndex() {
    final regimes = _regimesBox?.values.toList() ?? [];
    _phaseIndex = PhaseIndex(regimes);
  }

  /// Get current phase
  PhaseLabel? get currentPhase => phaseIndex.currentRegime?.label;

  /// Get phase for a specific timestamp
  PhaseLabel? getPhaseFor(DateTime timestamp) {
    return phaseIndex.phaseFor(timestamp);
  }

  /// Create a new phase regime
  Future<PhaseRegime> createRegime({
    required PhaseLabel label,
    required DateTime start,
    DateTime? end,
    PhaseSource source = PhaseSource.user,
    double? confidence,
    List<String> anchors = const [],
  }) async {
    final regime = PhaseRegime(
      id: 'regime_${DateTime.now().millisecondsSinceEpoch}',
      label: label,
      start: start,
      end: end,
      source: source,
      confidence: confidence,
      inferredAt: source == PhaseSource.rivet ? DateTime.now() : null,
      anchors: anchors,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _regimesBox?.put(regime.id, regime);
    _phaseIndex?.addRegime(regime);
    
        AnalyticsService.trackEvent('phase_regime.created', properties: {
      'label': label.name,
      'source': source.name,
      'duration_days': regime.duration.inDays,
    });

    return regime;
  }

  /// Update a phase regime
  Future<void> updateRegime(PhaseRegime regime) async {
    final updatedRegime = regime.copyWith(updatedAt: DateTime.now());
    await _regimesBox?.put(regime.id, updatedRegime);
    _phaseIndex?.updateRegime(updatedRegime);
    
        AnalyticsService.trackEvent('phase_regime.updated', properties: {
      'regime_id': regime.id,
      'label': regime.label.name,
    });
  }

  /// Delete a phase regime
  Future<void> deleteRegime(String regimeId) async {
    await _regimesBox?.delete(regimeId);
    _phaseIndex?.removeRegime(regimeId);
    
        AnalyticsService.trackEvent('phase_regime.deleted', properties: {
      'regime_id': regimeId,
    });
  }

  /// Split a regime at a specific timestamp
  Future<List<PhaseRegime>> splitRegime(String regimeId, DateTime splitAt) async {
    final regimes = _phaseIndex?.splitRegime(regimeId, splitAt) ?? [];
    
    for (final regime in regimes) {
      await _regimesBox?.put(regime.id, regime);
    }
    
        AnalyticsService.trackEvent('phase_regime.split', properties: {
      'regime_id': regimeId,
      'split_at': splitAt.toIso8601String(),
      'new_regimes': regimes.length,
    });

    return regimes;
  }

  /// Merge two adjacent regimes
  Future<PhaseRegime?> mergeRegimes(String leftId, String rightId) async {
    final mergedRegime = _phaseIndex?.mergeRegimes(leftId, rightId);
    
    if (mergedRegime != null) {
      await _regimesBox?.put(mergedRegime.id, mergedRegime);
      await _regimesBox?.delete(rightId);
      
          AnalyticsService.trackEvent('phase_regime.merged', properties: {
        'left_id': leftId,
        'right_id': rightId,
        'merged_id': mergedRegime.id,
      });
    }

    return mergedRegime;
  }

  /// Change current phase
  Future<PhaseRegime> changeCurrentPhase(PhaseLabel newLabel) async {
    final now = DateTime.now();
    final currentRegime = phaseIndex.currentRegime;
    
    // End current regime if it exists
    if (currentRegime != null && currentRegime.isOngoing) {
      final endedRegime = currentRegime.copyWith(
        end: now,
        updatedAt: now,
      );
      await updateRegime(endedRegime);
    }
    
    // Create new regime
    return await createRegime(
      label: newLabel,
      start: now,
      source: PhaseSource.user,
    );
  }

  /// Backdate phase change
  Future<PhaseRegime> backdatePhaseChange(PhaseLabel newLabel, DateTime backdateTo) async {
    // Find regime containing the backdate time
    final existingRegime = phaseIndex.regimeFor(backdateTo);
    
    if (existingRegime != null) {
      // Split the existing regime
      final splitRegimes = await splitRegime(existingRegime.id, backdateTo);
      
      // Update the second regime with new label
      if (splitRegimes.length > 1) {
        final updatedRegime = splitRegimes[1].copyWith(
          label: newLabel,
          source: PhaseSource.user,
          updatedAt: DateTime.now(),
        );
        await updateRegime(updatedRegime);
        return updatedRegime;
      }
    }
    
    // Create new regime if no existing regime found
    return await createRegime(
      label: newLabel,
      start: backdateTo,
      source: PhaseSource.user,
    );
  }

  /// Run RIVET Sweep if needed
  Future<bool> runRivetSweepIfNeeded(List<JournalEntry> entries) async {
    if (!needsRivetSweep(entries)) {
      return false;
    }

    try {
      final result = await _rivetSweep.analyzeEntries(entries);
      
      // Auto-apply high confidence segments
      if (result.autoAssign.isNotEmpty) {
        await _rivetSweep.applyProposals(result.autoAssign, phaseIndex);
        
            AnalyticsService.trackEvent('rivet_sweep.auto_applied', properties: {
          'segments': result.autoAssign.length,
        });
      }
      
      // Store sweep result for review
      await _storeSweepResult(result);
      
      return result.review.isNotEmpty || result.lowConfidence.isNotEmpty;
    } catch (e) {
          AnalyticsService.trackEvent('rivet_sweep.failed', properties: {
        'error': e.toString(),
      });
      return false;
    }
  }

  /// Check if RIVET Sweep is needed
  bool needsRivetSweep(List<JournalEntry> entries) {
    return _rivetSweep.needsRivetSweep(entries, phaseIndex);
  }

  /// Get stored sweep result
  Future<RivetSweepResult?> getStoredSweepResult() async {
    final prefs = await SharedPreferences.getInstance();
    final resultJson = prefs.getString('rivet_sweep_result');
    
    if (resultJson == null) return null;
    
    try {
      // This would need proper deserialization
      return null; // Placeholder
    } catch (e) {
      return null;
    }
  }

  /// Store sweep result
  Future<void> _storeSweepResult(RivetSweepResult result) async {
    final prefs = await SharedPreferences.getInstance();
    // This would need proper serialization
    await prefs.setString('rivet_sweep_result', '{}');
  }

  /// Apply sweep proposals
  Future<void> applySweepProposals(List<PhaseSegmentProposal> proposals) async {
    await _rivetSweep.applyProposals(proposals, phaseIndex);
    
        AnalyticsService.trackEvent('rivet_sweep.proposals_applied', properties: {
      'proposals': proposals.length,
    });
  }

  /// Update entry phase references
  Future<void> updateEntryPhaseReferences(List<JournalEntry> entries) async {
    for (final entry in entries) {
      final regime = phaseIndex.regimeFor(entry.createdAt);
      if (regime != null && entry.phaseAtTime != regime.start) {
        // Update entry with phase reference
        // This would need to be saved through the journal repository
      }
    }
  }

  /// Get phase timeline statistics
  PhaseTimelineStats get timelineStats => phaseIndex.stats;

  /// Get all regimes
  List<PhaseRegime> get allRegimes => phaseIndex.allRegimes;

  /// Get regimes in date range
  List<PhaseRegime> getRegimesInRange(DateTime start, DateTime end) {
    return phaseIndex.regimesInRange(start, end);
  }

  /// Export phase regimes for MCP
  Map<String, dynamic> exportForMcp() {
    return {
      'phase_regimes': allRegimes.map((r) => r.toJson()).toList(),
      'exported_at': DateTime.now().toIso8601String(),
      'version': '1.0',
    };
  }

  /// Import phase regimes from MCP
  Future<void> importFromMcp(Map<String, dynamic> data) async {
    final regimesJson = data['phase_regimes'] as List<dynamic>? ?? [];
    
    for (final regimeJson in regimesJson) {
      final regime = PhaseRegime.fromJson(regimeJson as Map<String, dynamic>);
      await _regimesBox?.put(regime.id, regime);
    }
    
    _loadPhaseIndex();
    
        AnalyticsService.trackEvent('phase_regimes.imported', properties: {
      'count': regimesJson.length,
    });
  }

  /// Clear all phase regimes
  Future<void> clearAllRegimes() async {
    await _regimesBox?.clear();
    _loadPhaseIndex();
    
        AnalyticsService.trackEvent('phase_regimes.cleared');
  }

  /// Migrate legacy phase data
  Future<void> migrateLegacyPhases(List<JournalEntry> entries) async {
    final phaseGroups = <String, List<JournalEntry>>{};
    
    // Group entries by legacy phase
    for (final entry in entries) {
      if (entry.phase != null) {
        phaseGroups.putIfAbsent(entry.phase!, () => []).add(entry);
      }
    }
    
    // Create regimes for each phase group
    for (final entry in phaseGroups.entries) {
      final phaseName = entry.key;
      final phaseEntries = entry.value;
      
      if (phaseEntries.isEmpty) continue;
      
      // Sort entries by date
      phaseEntries.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      // Find consecutive groups
      final consecutiveGroups = <List<JournalEntry>>[];
      List<JournalEntry> currentGroup = [phaseEntries.first];
      
      for (int i = 1; i < phaseEntries.length; i++) {
        final current = phaseEntries[i];
        final previous = phaseEntries[i - 1];
        
        // If gap is more than 7 days, start new group
        if (current.createdAt.difference(previous.createdAt).inDays > 7) {
          consecutiveGroups.add(currentGroup);
          currentGroup = [current];
        } else {
          currentGroup.add(current);
        }
      }
      consecutiveGroups.add(currentGroup);
      
      // Create regimes for each consecutive group
      for (final group in consecutiveGroups) {
        if (group.isEmpty) continue;
        
        final start = group.first.createdAt;
        final end = group.last.createdAt;
        final anchors = group.map((e) => e.id).toList();
        
        // Map legacy phase name to PhaseLabel
        PhaseLabel? phaseLabel;
        try {
          phaseLabel = PhaseLabel.values.firstWhere(
            (p) => p.name == phaseName.toLowerCase(),
          );
        } catch (e) {
          phaseLabel = PhaseLabel.discovery; // Default
        }
        
        await createRegime(
          label: phaseLabel,
          start: start,
          end: end,
          source: PhaseSource.user,
          anchors: anchors,
        );
      }
    }
    
        AnalyticsService.trackEvent('phase_regimes.migrated', properties: {
      'legacy_phases': phaseGroups.length,
      'total_entries': entries.length,
    });
  }
}
