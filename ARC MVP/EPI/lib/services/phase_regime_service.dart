// lib/services/phase_regime_service.dart
// Service for managing phase regimes and timeline

import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/phase_models.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'phase_index.dart';
import 'rivet_sweep_service.dart';
import 'analytics_service.dart';
import 'package:my_app/prism/atlas/rivet/rivet_provider.dart';
import 'package:my_app/prism/pipelines/prism_joiner.dart';
import 'package:my_app/mira/store/mcp/mcp_fs.dart';

class PhaseRegimeService {
  static const String _regimesBoxName = 'phase_regimes';
  static const String _lastAnalysisKey = 'last_phase_analysis_date';
  static const Map<PhaseLabel, String> _colorNames = {
    PhaseLabel.discovery: 'Discovery',
    PhaseLabel.expansion: 'Expansion',
    PhaseLabel.transition: 'Transition',
    PhaseLabel.consolidation: 'Consolidation',
    PhaseLabel.recovery: 'Recovery',
    PhaseLabel.breakthrough: 'Breakthrough',
  };

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

  /// Rebuild phase regimes using a ROLLING 10-DAY WINDOW approach.
  /// 
  /// How it works:
  /// 1. Sort all entries chronologically
  /// 2. Group entries into 10-day windows
  /// 3. For each window, count the autoPhase of each entry
  /// 4. The dominant phase becomes that window's regime
  /// 5. Adjacent windows with the same phase get merged
  /// 
  /// This preserves phase diversity (Discovery, Transition, Consolidation, etc.)
  /// instead of merging everything into one dominant phase.
  Future<void> rebuildRegimesFromEntries(List<JournalEntry> entries, {int windowDays = 10}) async {
    if (entries.isEmpty) {
      return;
    }

    // Sort entries chronologically
    final sortedEntries = List<JournalEntry>.from(entries)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Find the date range
    final firstDate = DateTime(
      sortedEntries.first.createdAt.year,
      sortedEntries.first.createdAt.month,
      sortedEntries.first.createdAt.day,
    );
    final lastDate = DateTime(
      sortedEntries.last.createdAt.year,
      sortedEntries.last.createdAt.month,
      sortedEntries.last.createdAt.day,
    );

    print('DEBUG: rebuildRegimesFromEntries - Processing ${entries.length} entries from $firstDate to $lastDate');

    // Create 10-day windows and calculate dominant phase for each
    final windowRegimes = <_PhaseSegment>[];
    DateTime windowStart = firstDate;

    while (windowStart.isBefore(lastDate) || windowStart.isAtSameMomentAs(lastDate)) {
      final windowEnd = windowStart.add(Duration(days: windowDays - 1));
      
      // Get entries in this window
      final windowEntries = sortedEntries.where((entry) {
        final entryDay = DateTime(entry.createdAt.year, entry.createdAt.month, entry.createdAt.day);
        return entryDay.isAfter(windowStart.subtract(const Duration(days: 1))) &&
               entryDay.isBefore(windowEnd.add(const Duration(days: 1)));
      }).toList();

      if (windowEntries.isNotEmpty) {
        // Count phases in this window using each entry's autoPhase
        final phaseCounts = <PhaseLabel, double>{};
        
        for (final entry in windowEntries) {
          // Use autoPhase first (per-entry detection), then computedPhase, then phase
          final phaseLabel = _normalizePhase(entry.autoPhase ?? entry.computedPhase ?? entry.phase);
          if (phaseLabel != null) {
      final weight = entry.autoPhaseConfidence ?? 1.0;
            phaseCounts[phaseLabel] = (phaseCounts[phaseLabel] ?? 0) + weight;
    }
        }

        if (phaseCounts.isNotEmpty) {
          // Find dominant phase for this window
          final dominantPhase = phaseCounts.entries
              .reduce((a, b) => a.value >= b.value ? a : b)
              .key;

          // Calculate confidence as percentage of entries with dominant phase
          final totalWeight = phaseCounts.values.fold(0.0, (sum, w) => sum + w);
          final confidence = phaseCounts[dominantPhase]! / totalWeight;

          print('DEBUG: Window ${windowStart.toString().substring(0, 10)} - ${windowEnd.toString().substring(0, 10)}: '
                '${windowEntries.length} entries, dominant=${_getPhaseLabelName(dominantPhase)} '
                '(${(confidence * 100).toStringAsFixed(0)}% confidence)');
          
          // Log all phases found in this window
          for (final entry in phaseCounts.entries) {
            print('DEBUG:   - ${_getPhaseLabelName(entry.key)}: ${entry.value.toStringAsFixed(1)} weight');
      }

          windowRegimes.add(_PhaseSegment(dominantPhase, windowStart, windowEnd));
        }
      }

      // Move to next window
      windowStart = windowStart.add(Duration(days: windowDays));
    }

    if (windowRegimes.isEmpty) {
      print('DEBUG: No regimes created from windows');
      return;
    }

    // Merge adjacent windows with the same phase
    final mergedRegimes = <_PhaseSegment>[];
    _PhaseSegment? currentMerge;

    for (final window in windowRegimes) {
      if (currentMerge == null) {
        currentMerge = window;
      } else if (currentMerge.phase == window.phase) {
        // Same phase - extend the current merge
        currentMerge = _PhaseSegment(currentMerge.phase, currentMerge.start, window.end);
          } else {
        // Different phase - save current and start new
        mergedRegimes.add(currentMerge);
        currentMerge = window;
          }
        }
    if (currentMerge != null) {
      mergedRegimes.add(currentMerge);
    }

    print('DEBUG: Created ${windowRegimes.length} windows, merged into ${mergedRegimes.length} regimes');

    // Clear existing and save new regimes
    await _regimesBox?.clear();
    
    for (final seg in mergedRegimes) {
      final regime = PhaseRegime(
        id: 'regime_${seg.start.millisecondsSinceEpoch}',
        label: seg.phase,
        start: seg.start,
        end: seg.end.add(const Duration(days: 1)), // inclusive day -> end at next day midnight
        source: PhaseSource.rivet,
        confidence: 1.0,
        inferredAt: DateTime.now(),
        anchors: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _regimesBox?.put(regime.id, regime);
      print('DEBUG: Saved regime: ${_getPhaseLabelName(seg.phase)} from ${seg.start} to ${seg.end} (${seg.lengthInDays} days)');
    }

    _loadPhaseIndex();
  }

  /// Incrementally add regimes for NEW entries only (preserves existing regimes)
  /// Call this when new entries are added to extend the timeline
  Future<void> extendRegimesWithNewEntries(List<JournalEntry> entries, {int windowDays = 10}) async {
    if (entries.isEmpty) return;

    final existingRegimes = _regimesBox?.values.toList() ?? [];
    if (existingRegimes.isEmpty) {
      // No existing regimes - do full rebuild
      await rebuildRegimesFromEntries(entries, windowDays: windowDays);
      return;
    }

    // Find the latest regime end date
    final sortedRegimes = List<PhaseRegime>.from(existingRegimes)
      ..sort((a, b) => (b.end ?? DateTime.now()).compareTo(a.end ?? DateTime.now()));
    final latestEnd = sortedRegimes.first.end ?? DateTime.now();

    // Find entries after the latest regime
    final newEntries = entries.where((e) => e.createdAt.isAfter(latestEnd)).toList();
    
    if (newEntries.isEmpty) {
      print('DEBUG: No new entries after latest regime end ($latestEnd)');
      return;
    }

    print('DEBUG: Found ${newEntries.length} new entries after $latestEnd');

    // Group new entries into windows and create regimes
    newEntries.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    
    DateTime windowStart = DateTime(
      newEntries.first.createdAt.year,
      newEntries.first.createdAt.month,
      newEntries.first.createdAt.day,
    );
    final lastDate = DateTime(
      newEntries.last.createdAt.year,
      newEntries.last.createdAt.month,
      newEntries.last.createdAt.day,
    );

    while (windowStart.isBefore(lastDate) || windowStart.isAtSameMomentAs(lastDate)) {
      final windowEnd = windowStart.add(Duration(days: windowDays - 1));
      
      final windowEntries = newEntries.where((entry) {
        final entryDay = DateTime(entry.createdAt.year, entry.createdAt.month, entry.createdAt.day);
        return entryDay.isAfter(windowStart.subtract(const Duration(days: 1))) &&
               entryDay.isBefore(windowEnd.add(const Duration(days: 1)));
      }).toList();

      if (windowEntries.isNotEmpty) {
        final phaseCounts = <PhaseLabel, double>{};
        
        for (final entry in windowEntries) {
          final phaseLabel = _normalizePhase(entry.autoPhase ?? entry.computedPhase ?? entry.phase);
          if (phaseLabel != null) {
            final weight = entry.autoPhaseConfidence ?? 1.0;
            phaseCounts[phaseLabel] = (phaseCounts[phaseLabel] ?? 0) + weight;
          }
        }

        if (phaseCounts.isNotEmpty) {
          final dominantPhase = phaseCounts.entries
              .reduce((a, b) => a.value >= b.value ? a : b)
              .key;

          // Check if this can extend the last regime (same phase)
          if (sortedRegimes.first.label == dominantPhase && sortedRegimes.first.end != null) {
            // Extend existing regime
            final existing = sortedRegimes.first;
            final updated = PhaseRegime(
              id: existing.id,
              label: existing.label,
              start: existing.start,
              end: windowEnd.add(const Duration(days: 1)),
              source: existing.source,
              confidence: existing.confidence,
              inferredAt: DateTime.now(),
              anchors: existing.anchors,
              createdAt: existing.createdAt,
              updatedAt: DateTime.now(),
            );
            await _regimesBox?.put(updated.id, updated);
            print('DEBUG: Extended regime ${_getPhaseLabelName(dominantPhase)} to $windowEnd');
          } else {
            // Create new regime
            final regime = PhaseRegime(
              id: 'regime_${windowStart.millisecondsSinceEpoch}',
              label: dominantPhase,
              start: windowStart,
              end: windowEnd.add(const Duration(days: 1)),
              source: PhaseSource.rivet,
              confidence: 1.0,
              inferredAt: DateTime.now(),
              anchors: const [],
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            await _regimesBox?.put(regime.id, regime);
            print('DEBUG: Added new regime: ${_getPhaseLabelName(dominantPhase)} from $windowStart to $windowEnd');
          }
        }
      }

      windowStart = windowStart.add(Duration(days: windowDays));
    }

    _loadPhaseIndex();
  }


  /// Load phase index from storage
  void _loadPhaseIndex() {
    final regimes = _regimesBox?.values.toList() ?? [];
    _phaseIndex = PhaseIndex(regimes);
  }

  PhaseLabel? _normalizePhase(String? phaseName) {
    if (phaseName == null) return null;
    final normalized = phaseName.replaceAll('#', '').replaceAll('_', ' ').trim().toLowerCase();
    switch (normalized) {
      case 'discovery':
        return PhaseLabel.discovery;
      case 'expansion':
        return PhaseLabel.expansion;
      case 'transition':
        return PhaseLabel.transition;
      case 'consolidation':
        return PhaseLabel.consolidation;
      case 'recovery':
        return PhaseLabel.recovery;
      case 'breakthrough':
        return PhaseLabel.breakthrough;
      default:
        return null;
    }
  }

  /// Get current phase
  PhaseLabel? get currentPhase => phaseIndex.currentRegime?.label;

  /// Get phase for a specific timestamp
  PhaseLabel? getPhaseFor(DateTime timestamp) {
    return phaseIndex.phaseFor(timestamp);
  }

  /// Helper to get PhaseLabel name (works with all Dart versions)
  String _getPhaseLabelName(PhaseLabel label) {
    return label.toString().split('.').last;
  }

  /// Create a new phase regime.
  /// Phase labels are determined by callers: RIVET (sweep/gate), ATLAS (scoring), Sentinel (safety override).
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
        print('🔄 Ending ongoing regime ${_getPhaseLabelName(overlappingRegime.label)} at ${start} to make way for ${_getPhaseLabelName(label)}');
        final endedRegime = overlappingRegime.copyWith(
          end: start,
          updatedAt: DateTime.now(),
        );
        await updateRegime(endedRegime);
      } else if (overlappingRegime.isOngoing && overlappingRegime.start.isAtSameMomentAs(start)) {
        // If they start at the same time, update the existing regime instead
        print('🔄 Updating existing regime ${_getPhaseLabelName(overlappingRegime.label)} to ${_getPhaseLabelName(label)}');
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
        print('⚠️ Skipping phase regime creation: overlaps with completed regime ${_getPhaseLabelName(overlappingRegime.label)}');
      AnalyticsService.trackEvent('phase_regime.duplicate_skipped', properties: {
        'label': _getPhaseLabelName(label),
        'source': source.toString().split('.').last,
        'existing_id': overlappingRegime.id,
        'existing_label': _getPhaseLabelName(overlappingRegime.label),
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
    
    // Trigger VEIL policy generation when new regime is created
    _triggerVeilPolicyGeneration();
    
    print('✅ Created phase regime: ${_getPhaseLabelName(regime.label)} (${regime.start} - ${regime.end ?? 'ongoing'})');
    
    AnalyticsService.trackEvent('phase_regime.created', properties: {
      'label': _getPhaseLabelName(label),
      'source': source.toString().split('.').last,
      'duration_days': regime.duration.inDays,
    });

    return regime;
  }

  /// Update a phase regime
  /// If updateHashtags is true and the label changed, updates hashtags in entries
  Future<void> updateRegime(PhaseRegime regime, {bool updateHashtags = false, PhaseLabel? oldLabel}) async {
    // Check if label changed
    PhaseLabel? previousLabel;
    if (updateHashtags && oldLabel != null) {
      previousLabel = oldLabel;
    } else if (updateHashtags) {
      // Try to get the old regime to compare labels
      final oldRegime = _regimesBox?.get(regime.id);
      if (oldRegime != null && oldRegime.label != regime.label) {
        previousLabel = oldRegime.label;
      }
    }
    
    final updatedRegime = regime.copyWith(updatedAt: DateTime.now());
    await _regimesBox?.put(regime.id, updatedRegime);
    _loadPhaseIndex(); // Reload phase index to ensure currentRegime is updated
    
    // Update hashtags if requested and label changed
    if (updateHashtags && previousLabel != null && previousLabel != regime.label) {
      await updateHashtagsForRegime(updatedRegime, oldLabel: previousLabel);
    }
    
    // Trigger VEIL policy generation when regime changes
    _triggerVeilPolicyGeneration();
    
        AnalyticsService.trackEvent('phase_regime.updated', properties: {
      'regime_id': regime.id,
      'label': _getPhaseLabelName(regime.label),
      'hashtags_updated': updateHashtags && previousLabel != null && previousLabel != regime.label,
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
          print('🗑️ Marking duplicate for removal: ${_getPhaseLabelName(regime2.label)} (${regime2.start} - ${regime2.end ?? 'ongoing'})');
          print('   Keeping: ${_getPhaseLabelName(regime1.label)} (${regime1.start} - ${regime1.end ?? 'ongoing'})');
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
    _loadPhaseIndex();
    
    // Trigger VEIL policy generation when regime is split
    _triggerVeilPolicyGeneration();
    
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
      _loadPhaseIndex();
      
      // Trigger VEIL policy generation when regimes are merged
      _triggerVeilPolicyGeneration();
      
          AnalyticsService.trackEvent('phase_regime.merged', properties: {
        'left_id': leftId,
        'right_id': rightId,
        'merged_id': mergedRegime.id,
      });
    }

    return mergedRegime;
  }

  /// Change current phase (user-determined).
  /// If updateHashtags is true, updates hashtags for entries in the new regime.
  /// Resets RIVET so it starts fresh; the gate stays closed until it opens again and ATLAS can determine a new phase.
  Future<PhaseRegime> changeCurrentPhase(PhaseLabel newLabel, {bool updateHashtags = false}) async {
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
    
    // Create new regime (user is determining their phase)
    final newRegime = await createRegime(
      label: newLabel,
      start: now,
      source: PhaseSource.user,
    );
    
    // Update hashtags if requested
    if (updateHashtags) {
      await updateHashtagsForRegime(newRegime);
    }
    
    // User determined phase: reset RIVET to a new start so the gate closes and
    // RIVET will accumulate evidence again until it opens and ATLAS can determine a new phase
    try {
      const userId = 'default_user';
      await RivetProvider().safeClearUserData(userId);
    } catch (e) {
      // Non-fatal: phase change still applied
      print('DEBUG: RIVET reset after user phase change: $e');
    }
    
    return newRegime;
  }

  /// Backdate phase change
  /// If updateHashtags is true, updates hashtags for entries in the affected regime(s)
  Future<PhaseRegime> backdatePhaseChange(PhaseLabel newLabel, DateTime backdateTo, {bool updateHashtags = false}) async {
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
        await updateRegime(updatedRegime, updateHashtags: updateHashtags, oldLabel: existingRegime.label);
        return updatedRegime;
      }
    }
    
    // Create new regime if no existing regime found
    final newRegime = await createRegime(
      label: newLabel,
      start: backdateTo,
      source: PhaseSource.user,
    );
    
    // Update hashtags if requested
    if (updateHashtags) {
      await updateHashtagsForRegime(newRegime);
    }
    
    // Trigger VEIL policy generation when phase is backdated
    _triggerVeilPolicyGeneration();
    
    return newRegime;
  }

  /// Trigger VEIL policy generation in the background when phase regimes change
  /// This runs asynchronously and doesn't block the calling operation
  void _triggerVeilPolicyGeneration() {
    // Run in background without blocking
    Future.microtask(() async {
      try {
        print('DEBUG: Phase regime changed - triggering VEIL policy generation');
        final mcpRoot = await McpFs.base();
        final joiner = PrismJoiner(mcpRoot);
        // Generate policies for last 30 days to ensure current day is covered
        await joiner.joinRange(daysBack: 30);
        print('DEBUG: VEIL policy generation completed after phase regime change');
      } catch (e) {
        // Log error but don't throw - policy generation failure shouldn't block regime changes
        print('DEBUG: Error generating VEIL policies after regime change: $e');
      }
    });
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
      
      // Set pending analysis flag for UI (so user can review results)
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('phase_analysis_pending', true);
        
        final totalSegments = result.autoAssign.length + 
                             result.review.length + 
                             result.lowConfidence.length;
        await prefs.setInt('phase_analysis_segments', totalSegments);
        
        print('ARCX Import: Phase analysis completed - $totalSegments segments found');
      } catch (e) {
        print('ARCX Import: Error setting pending analysis flag: $e');
      }
      
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
      print('✅ Imported phase regime: ${_getPhaseLabelName(regime.label)} (${regime.start} - ${regime.end ?? 'ongoing'})');
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

  /// Get entries within a date range
  List<JournalEntry> _getEntriesInDateRange(DateTime start, DateTime? end) {
    final journalRepo = JournalRepository();
    final allEntries = journalRepo.getAllJournalEntriesSync();
    final endDate = end ?? DateTime.now();
    
    return allEntries.where((entry) {
      return entry.createdAt.isAfter(start.subtract(const Duration(seconds: 1))) &&
             entry.createdAt.isBefore(endDate.add(const Duration(seconds: 1)));
    }).toList();
  }

  /// Count entries that would be affected by a regime change
  int countEntriesForRegime(PhaseRegime regime) {
    return _getEntriesInDateRange(regime.start, regime.end).length;
  }

  /// Returns the date of the latest journal entry in [start, end], or null if none.
  /// Used so the Gantt can show the most recent phase tracking to the last entry.
  DateTime? getLastEntryDateInRange(DateTime start, DateTime? end) {
    final entries = _getEntriesInDateRange(start, end);
    if (entries.isEmpty) return null;
    return entries.map((e) => e.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// If the most recent regime is ongoing (or ends before the last journal entry in its range),
  /// extend its end to that last entry date so the Gantt and stats track to the last entries.
  /// Uses entries from [regime.start, now] so new entries are included.
  Future<bool> extendMostRecentRegimeToLastEntry() async {
    final regimes = _regimesBox?.values.toList() ?? [];
    if (regimes.isEmpty) return false;
    final sorted = List<PhaseRegime>.from(regimes)
      ..sort((a, b) => (b.end ?? DateTime.now()).compareTo(a.end ?? DateTime.now()));
    final mostRecent = sorted.first;
    final lastEntry = getLastEntryDateInRange(mostRecent.start, null);
    if (lastEntry == null) return false;
    final effectiveEnd = lastEntry.isBefore(mostRecent.start)
        ? mostRecent.start
        : lastEntry;
    final bool shouldUpdate = mostRecent.end == null
        ? effectiveEnd.isAfter(mostRecent.start)
        : effectiveEnd.isAfter(mostRecent.end!);
    if (!shouldUpdate) return false;
    final updated = mostRecent.copyWith(end: effectiveEnd, updatedAt: DateTime.now());
    await updateRegime(updated);
    _loadPhaseIndex();
    return true;
  }

  /// Update hashtags for entries in a regime
  /// Removes old phase hashtags and adds the new phase hashtag
  /// If oldRegime is provided, removes hashtags from entries that are no longer in the regime
  Future<int> updateHashtagsForRegime(PhaseRegime regime, {PhaseLabel? oldLabel, PhaseRegime? oldRegime}) async {
    try {
      final journalRepo = JournalRepository();
      final entries = _getEntriesInDateRange(regime.start, regime.end);
      final newPhaseName = _getPhaseLabelName(regime.label).toLowerCase();
      final newHashtag = '#$newPhaseName';
      
      // Get all possible phase hashtags to remove
      final allPhaseHashtags = PhaseLabel.values.map((label) => 
        '#${_getPhaseLabelName(label).toLowerCase()}'
      ).toList();
      
      // If oldLabel is provided, prioritize removing that one
      final oldHashtag = oldLabel != null ? '#${_getPhaseLabelName(oldLabel).toLowerCase()}' : null;
      
      print('DEBUG: Updating hashtags for regime ${regime.id} (${newPhaseName})');
      print('DEBUG: Found ${entries.length} entries in date range');
      
      int updatedCount = 0;
      for (final entry in entries) {
        try {
          String updatedContent = entry.content;
          bool contentChanged = false;
          
          // Remove old phase hashtags
          if (oldHashtag != null) {
            // Remove the specific old hashtag
            final oldHashtagLower = oldHashtag.toLowerCase();
            final contentLower = updatedContent.toLowerCase();
            if (contentLower.contains(oldHashtagLower)) {
              // Remove hashtag (case-insensitive, but preserve original case)
              final regex = RegExp(RegExp.escape(oldHashtag), caseSensitive: false);
              updatedContent = updatedContent.replaceAll(regex, '').trim();
              contentChanged = true;
            }
          } else {
            // Remove all phase hashtags if no specific old label
            for (final hashtag in allPhaseHashtags) {
              if (hashtag == newHashtag) continue; // Don't remove the new one
              final regex = RegExp(RegExp.escape(hashtag), caseSensitive: false);
              if (regex.hasMatch(updatedContent)) {
                updatedContent = updatedContent.replaceAll(regex, '').trim();
                contentChanged = true;
              }
            }
          }
          
          // Add new hashtag if not already present
          final contentLower = updatedContent.toLowerCase();
          if (!contentLower.contains(newHashtag)) {
            updatedContent = '$updatedContent $newHashtag'.trim();
            contentChanged = true;
          }
          
          // Update entry if content changed
          if (contentChanged) {
            final updatedEntry = entry.copyWith(
              content: updatedContent,
              updatedAt: DateTime.now(),
            );
            await journalRepo.updateJournalEntry(updatedEntry);
            updatedCount++;
          }
        } catch (e) {
          print('DEBUG: Error updating entry ${entry.id}: $e');
        }
      }
      
      // If oldRegime is provided, remove hashtags from entries that are no longer in the regime
      if (oldRegime != null) {
        final oldEntries = _getEntriesInDateRange(oldRegime.start, oldRegime.end);
        final newEntryIds = entries.map((e) => e.id).toSet();
        
        int removedCount = 0;
        for (final oldEntry in oldEntries) {
          // Skip if entry is still in the new regime
          if (newEntryIds.contains(oldEntry.id)) continue;
          
          try {
            final phaseName = _getPhaseLabelName(oldRegime.label).toLowerCase();
            final oldHashtag = '#$phaseName';
            final contentLower = oldEntry.content.toLowerCase();
            
            if (contentLower.contains(oldHashtag)) {
              // Remove old hashtag
              final regex = RegExp(RegExp.escape(oldHashtag), caseSensitive: false);
              final updatedContent = oldEntry.content.replaceAll(regex, '').trim();
              
              final updatedEntry = oldEntry.copyWith(
                content: updatedContent,
                updatedAt: DateTime.now(),
              );
              await journalRepo.updateJournalEntry(updatedEntry);
              removedCount++;
            }
          } catch (e) {
            print('DEBUG: Error removing hashtag from entry ${oldEntry.id}: $e');
          }
        }
        
        print('DEBUG: Removed hashtags from $removedCount entries that are no longer in regime');
      }
      
      print('DEBUG: Successfully updated hashtags for $updatedCount/${entries.length} entries');
      return updatedCount;
    } catch (e) {
      print('DEBUG: Error updating hashtags for regime: $e');
      return 0;
    }
  }
}

class _PhaseSegment {
  PhaseLabel phase;
  DateTime start;
  DateTime end;

  _PhaseSegment(this.phase, this.start, this.end);

  int get lengthInDays => end.difference(start).inDays + 1;

  void mergeStart(DateTime newStart) {
    start = newStart.isBefore(start) ? newStart : start;
  }

  void mergeEnd(DateTime newEnd) {
    end = newEnd.isAfter(end) ? newEnd : end;
  }
}

