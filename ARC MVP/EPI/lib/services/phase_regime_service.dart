// lib/services/phase_regime_service.dart
// Service for managing phase regimes and timeline

import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/phase_models.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'phase_index.dart';
import 'rivet_sweep_service.dart';
import 'analytics_service.dart';

class PhaseRegimeService {
  static const String _regimesBoxName = 'phase_regimes';
  static const String _lastAnalysisKey = 'last_phase_analysis_date';

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
    // Find overlapping regimes and end any ongoing ones before creating the new regime
    final existingRegimes = allRegimes;
    final overlappingRegimes = existingRegimes.where((existing) {
      return existing.start.isBefore(end ?? DateTime.now()) &&
             (existing.end == null || existing.end!.isAfter(start));
    }).toList();
    
    // End any ongoing regimes that overlap with the new regime's start time
    for (final overlappingRegime in overlappingRegimes) {
      // If the overlapping regime is ongoing and starts before the new regime
      if (overlappingRegime.isOngoing && overlappingRegime.start.isBefore(start)) {
        print('🔄 Ending ongoing regime ${overlappingRegime.label.name} at ${start} to make way for ${label.name}');
        final endedRegime = overlappingRegime.copyWith(
          end: start,
          updatedAt: DateTime.now(),
        );
        await updateRegime(endedRegime);
      } else if (overlappingRegime.isOngoing && overlappingRegime.start.isAtSameMomentAs(start)) {
        // If they start at the same time, update the existing regime instead
        print('🔄 Updating existing regime ${overlappingRegime.label.name} to ${label.name}');
        final updatedRegime = overlappingRegime.copyWith(
          label: label,
          source: source,
          confidence: confidence,
          anchors: anchors,
          updatedAt: DateTime.now(),
        );
        await updateRegime(updatedRegime);
        return updatedRegime;
      } else if (!overlappingRegime.isOngoing) {
        // If there's an exact overlap with a completed regime, skip creating a duplicate
        print('⚠️ Skipping phase regime creation: overlaps with completed regime ${overlappingRegime.label.name}');
        AnalyticsService.trackEvent('phase_regime.duplicate_skipped', properties: {
          'label': label.name,
          'source': source.name,
          'existing_id': overlappingRegime.id,
          'existing_label': overlappingRegime.label.name,
        });
        return overlappingRegime;
      }
    }

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
    _loadPhaseIndex(); // Reload phase index to ensure currentRegime is updated
    
    print('✅ Created phase regime: ${regime.label.name} (${regime.start} - ${regime.end ?? 'ongoing'})');
    
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
    _loadPhaseIndex(); // Reload phase index to ensure currentRegime is updated
    
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

  /// Remove duplicate phase regimes (keeps the first one for each time period)
  Future<int> removeDuplicates() async {
    final regimes = allRegimes;
    final duplicatesToRemove = <String>[];
    
    // Sort regimes by start time
    regimes.sort((a, b) => a.start.compareTo(b.start));
    
    for (int i = 0; i < regimes.length; i++) {
      for (int j = i + 1; j < regimes.length; j++) {
        final regime1 = regimes[i];
        final regime2 = regimes[j];
        
        // Check if they overlap in time
        final hasOverlap = regime1.start.isBefore(regime2.end ?? DateTime.now()) &&
                          (regime1.end == null || regime1.end!.isAfter(regime2.start));
        
        if (hasOverlap) {
          // Keep the first one (earlier start time), remove the second
          duplicatesToRemove.add(regime2.id);
          print('🗑️ Marking duplicate for removal: ${regime2.label.name} (${regime2.start} - ${regime2.end ?? 'ongoing'})');
          print('   Keeping: ${regime1.label.name} (${regime1.start} - ${regime1.end ?? 'ongoing'})');
        }
      }
    }
    
    // Remove duplicates
    for (final regimeId in duplicatesToRemove) {
      await deleteRegime(regimeId);
    }
    
    print('🧹 Cleaned up ${duplicatesToRemove.length} duplicate phase regimes');
    
    AnalyticsService.trackEvent('phase_regimes.duplicates_removed', properties: {
      'count': duplicatesToRemove.length,
    });
    
    return duplicatesToRemove.length;
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

  /// Get last analysis date
  Future<DateTime?> getLastAnalysisDate() async {
    final prefs = await SharedPreferences.getInstance();
    final dateString = prefs.getString(_lastAnalysisKey);
    if (dateString == null) return null;
    try {
      return DateTime.parse(dateString);
    } catch (e) {
      return null;
    }
  }

  /// Set last analysis date
  Future<void> setLastAnalysisDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastAnalysisKey, date.toIso8601String());
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
    int importedCount = 0;
    int skippedCount = 0;
    
    for (final regimeJson in regimesJson) {
      final regime = PhaseRegime.fromJson(regimeJson as Map<String, dynamic>);
      
      // Check for duplicates by time overlap
      final existingRegimes = allRegimes;
      final hasOverlap = existingRegimes.any((existing) {
        return existing.start.isBefore(regime.end ?? DateTime.now()) &&
               (existing.end == null || existing.end!.isAfter(regime.start));
      });
      
      if (hasOverlap) {
        print('⚠️ Skipping phase regime ${regime.id}: overlaps with existing regime');
        skippedCount++;
        continue;
      }
      
      // Check for exact ID duplicates
      if (existingRegimes.any((existing) => existing.id == regime.id)) {
        print('⚠️ Skipping phase regime ${regime.id}: ID already exists');
        skippedCount++;
        continue;
      }
      
      await _regimesBox?.put(regime.id, regime);
      importedCount++;
      print('✅ Imported phase regime: ${regime.label.name} (${regime.start} - ${regime.end ?? 'ongoing'})');
    }
    
    _loadPhaseIndex();
    
    print('📊 Phase regime import complete: $importedCount imported, $skippedCount skipped');
    
    AnalyticsService.trackEvent('phase_regimes.imported', properties: {
      'count': importedCount,
      'skipped': skippedCount,
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
