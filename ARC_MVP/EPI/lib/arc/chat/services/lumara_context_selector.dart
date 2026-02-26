/// LUMARA Context Selector
/// 
/// Implements sophisticated context selection based on:
/// - Memory Focus preset (time window + max entry count)
/// - Engagement Mode (sampling strategy)
/// - Semantic relevance
/// - Phase intelligence (RIVET/SENTINEL/ATLAS)
/// 
/// **ARCHITECTURE: Two-Stage Memory System**
/// 
/// This service handles Stage 1: Entry Selection (temporal/phase-aware)
/// Stage 2: Memory Filtering (Polymeta) happens in enhanced_lumara_api.dart
/// 
/// Flow:
/// 1. Context Selector selects entries based on phase/time/engagement mode
/// 2. Polymeta (MemoryModeService) filters memories FROM those selected entries
/// 3. Prompt includes both: entry excerpts + filtered semantic memories
/// 
/// **No Conflict**: These are complementary:
/// - Context Selection: "Which parts of the journey?" (horizontal - time/phases)
/// - Polymeta: "What to remember from those parts?" (vertical - domain/confidence)

import '../../../models/journal_entry_model.dart';
import '../../../models/memory_focus_preset.dart';
import '../../../models/engagement_discipline.dart';
import 'package:my_app/services/app_repos.dart';
import 'lumara_reflection_settings_service.dart';

class LumaraContextSelector {
  final JournalRepository _journalRepo = AppRepos.journal;

  /// Select entries based on Memory Focus + Engagement Mode + Semantic relevance
  Future<List<JournalEntry>> selectContextEntries({
    required MemoryFocusPreset memoryFocus,
    required EngagementMode engagementMode,
    required String currentEntryText,
    required DateTime currentDate,
    String? entryId, // Exclude current entry if provided
    int? customTimeWindowDays,
    int? customMaxEntries,
    double? customSimilarityThreshold,
  }) async {
    // 1. Get time window and max count from Memory Focus
    // If custom values not provided, try to get from settings service
    int? finalTimeWindowDays = customTimeWindowDays;
    int? finalMaxEntries = customMaxEntries;
    double? finalSimilarityThreshold = customSimilarityThreshold;
    
    if (memoryFocus == MemoryFocusPreset.custom && 
        (customTimeWindowDays == null || customMaxEntries == null || customSimilarityThreshold == null)) {
      final customValues = await _getCustomValues(memoryFocus);
      finalTimeWindowDays ??= customValues['timeWindowDays'] as int?;
      finalMaxEntries ??= customValues['maxEntries'] as int?;
      finalSimilarityThreshold ??= customValues['similarityThreshold'] as double?;
    }
    
    final timeWindowDays = _getTimeWindowDays(memoryFocus, finalTimeWindowDays);
    final maxEntries = _getMaxEntries(memoryFocus, finalMaxEntries);
    final cutoffDate = currentDate.subtract(Duration(days: timeWindowDays));
    
    print('🔵 LUMARA Context Selector: Memory Focus=$memoryFocus, Time Window=$timeWindowDays days, Max Entries=$maxEntries');
    
    // 2. Get all entries within time window
    final allEntries = await _getEntriesInWindow(cutoffDate, currentDate);
    
    // Exclude current entry if provided
    final filteredEntries = entryId != null
        ? allEntries.where((e) => e.id != entryId).toList()
        : allEntries;
    
    if (filteredEntries.isEmpty) {
      print('⚠️ LUMARA Context Selector: No entries found in time window');
      return [];
    }
    
    print('🔵 LUMARA Context Selector: Found ${filteredEntries.length} entries in time window');
    
    // 3. Apply engagement mode sampling strategy
    final sampledEntries = _applyEngagementModeSampling(
      entries: filteredEntries,
      mode: engagementMode,
      maxCount: maxEntries,
      currentDate: currentDate,
    );
    
    print('🔵 LUMARA Context Selector: After ${engagementMode.name} sampling: ${sampledEntries.length} entries');
    
    // 4. Enhance with semantic relevance (if similarity threshold is available)
    final similarityThreshold = _getSimilarityThreshold(memoryFocus, customSimilarityThreshold);
    final relevantEntries = await _enhanceWithSemanticRelevance(
      entries: sampledEntries,
      query: currentEntryText,
      similarityThreshold: similarityThreshold,
    );
    
    print('🔵 LUMARA Context Selector: After semantic enhancement: ${relevantEntries.length} entries');
    
    // 5. Integrate phase intelligence (RIVET/SENTINEL/ATLAS) - if available
    final finalEntries = await _integratePhaseIntelligence(
      entries: relevantEntries,
      mode: engagementMode,
      maxCount: maxEntries,
    );
    
    // Final limit to maxEntries
    final result = finalEntries.take(maxEntries).toList();
    print('🔵 LUMARA Context Selector: Final selection: ${result.length} entries');
    
    return result;
  }
  
  /// Get time window in days from Memory Focus preset
  int _getTimeWindowDays(MemoryFocusPreset preset, int? customDays) {
    return (preset == MemoryFocusPreset.custom && customDays != null)
        ? customDays
        : preset.timeWindowDays;
  }

  /// Get max entries from Memory Focus preset
  int _getMaxEntries(MemoryFocusPreset preset, int? customEntries) {
    return (preset == MemoryFocusPreset.custom && customEntries != null)
        ? customEntries
        : preset.maxEntries;
  }
  
  /// Get custom values from settings service if Custom preset is selected
  Future<Map<String, dynamic>> _getCustomValues(MemoryFocusPreset preset) async {
    if (preset != MemoryFocusPreset.custom) {
      return {};
    }
    
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.initialize();
      final timeWindowDays = await settingsService.getTimeWindowDays();
      final similarityThreshold = await settingsService.getSimilarityThreshold();
      final maxEntries = await settingsService.getMaxMatches();
      return {
        'timeWindowDays': timeWindowDays,
        'similarityThreshold': similarityThreshold,
        'maxEntries': maxEntries,
      };
    } catch (e) {
      print('Error getting custom values: $e');
      return {};
    }
  }
  
  /// Get similarity threshold from Memory Focus preset
  double _getSimilarityThreshold(MemoryFocusPreset preset, double? customThreshold) {
    return (preset == MemoryFocusPreset.custom && customThreshold != null)
        ? customThreshold
        : preset.similarityThreshold;
  }
  
  /// Get all entries within time window
  Future<List<JournalEntry>> _getEntriesInWindow(DateTime cutoffDate, DateTime currentDate) async {
    try {
      final allEntries = await _journalRepo.getAllJournalEntries();
      final endDate = currentDate.add(Duration(days: 1));

      return allEntries
          .where((entry) => entry.createdAt.isAfter(cutoffDate) && entry.createdAt.isBefore(endDate))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      print('Error getting entries in window: $e');
      return [];
    }
  }
  
  /// Apply engagement mode sampling strategy
  List<JournalEntry> _applyEngagementModeSampling({
    required List<JournalEntry> entries,
    required EngagementMode mode,
    required int maxCount,
    required DateTime currentDate,
  }) {
    switch (mode) {
      case EngagementMode.reflect:
        return _applyReflectSampling(entries, maxCount, currentDate);
      case EngagementMode.deeper:
      case EngagementMode.explore:
      case EngagementMode.integrate:
        return _applyIntegrateSampling(entries, maxCount, currentDate);
    }
  }
  
  /// REFLECT Mode: Dense recent sampling (prefer last 14 days)
  List<JournalEntry> _applyReflectSampling(
    List<JournalEntry> entries,
    int maxCount,
    DateTime currentDate,
  ) {
    if (entries.isEmpty) return [];

    final recentCutoff = currentDate.subtract(Duration(days: 14));
    final recentEntries = entries.where((e) => e.createdAt.isAfter(recentCutoff)).toList();
    final olderEntries = entries.where((e) => !e.createdAt.isAfter(recentCutoff)).toList();

    final recentCount = (maxCount * 0.7).round();
    final result = <JournalEntry>[
      ...recentEntries.take(recentCount),
      if (recentEntries.length < recentCount && olderEntries.isNotEmpty)
        ...olderEntries.take(maxCount - recentEntries.length),
    ];

    return result.take(maxCount).toList();
  }
  
  /// EXPLORE Mode: Stratified sampling across time window (40/30/30 split)
  List<JournalEntry> _applyExploreSampling(
    List<JournalEntry> entries,
    int maxCount,
    DateTime currentDate,
  ) {
    if (entries.isEmpty) return [];

    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final total = entries.length;
    final recentCount = (maxCount * 0.4).round();
    final middleCount = (maxCount * 0.3).round();
    final earlyCount = maxCount - recentCount - middleCount;

    final result = [
      ...entries.take(recentCount),
      ...entries.skip(total ~/ 3).take(middleCount),
      ...entries.skip((total * 2) ~/ 3).take(earlyCount),
    ];

    return result.toSet().toList().take(maxCount).toList();
  }
  
  /// INTEGRATE Mode: Phase-aware sampling (phase transitions + current phase)
  List<JournalEntry> _applyIntegrateSampling(
    List<JournalEntry> entries,
    int maxCount,
    DateTime currentDate,
  ) {
    if (entries.isEmpty) return [];

    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final phaseEntries = entries.where((e) => e.metadata?['phase'] != null).toList();
    final nonPhaseEntries = entries.where((e) => e.metadata?['phase'] == null).toList();
    final phaseCount = (maxCount * 0.6).round();

    final result = [
      ...phaseEntries.take(phaseCount),
      ...nonPhaseEntries.take(maxCount - phaseEntries.length.clamp(0, phaseCount)),
    ];

    return result.take(maxCount).toList();
  }
  
  /// Enhance selection with semantic relevance
  Future<List<JournalEntry>> _enhanceWithSemanticRelevance({
    required List<JournalEntry> entries,
    required String query,
    required double similarityThreshold,
  }) async {
    // For now, return entries as-is
    // TODO: Implement semantic similarity scoring when available
    // This would use the semantic similarity service to score and re-rank entries
    
    if (query.isEmpty) {
      return entries;
    }
    
    // Placeholder: Return entries sorted by date (already sorted)
    return entries;
  }
  
  /// Integrate phase intelligence (RIVET/SENTINEL/ATLAS)
  /// 
  /// **Phase-Aware Entry Selection (Stage 1 of Two-Stage Memory System)**
  /// 
  /// This method prioritizes entries based on phase transitions and developmental significance.
  /// After this selection, Polymeta (MemoryModeService) will filter memories FROM these entries.
  /// 
  /// **Integration Pattern:**
  /// 1. This method selects entries (coverage: which time periods/phases matter)
  /// 2. enhanced_lumara_api.dart calls MemoryModeService.retrieveMemories() with selected entry IDs
  /// 3. MemoryModeService applies domain modes, decay, reinforcement (detail: what to remember)
  /// 4. Both entry excerpts + filtered memories are included in prompt
  /// 
  /// **No Conflict**: Context Selection and Polymeta are complementary:
  /// - Context Selection: "Which parts of the journey?" (horizontal - time/phases)
  /// - Polymeta: "What to remember from those parts?" (vertical - domain/confidence)
  Future<List<JournalEntry>> _integratePhaseIntelligence({
    required List<JournalEntry> entries,
    required EngagementMode mode,
    required int maxCount,
  }) async {
    // TODO: Integrate with RIVET to get phase transitions
    // - Prioritize entries from phase transition periods
    // - Weight entries by transition significance
    
    // TODO: Integrate with SENTINEL to get high-density events (top 10%)
    // - Boost entries with high Sentinel density scores
    // - These represent significant emotional/intellectual events
    
    // TODO: Integrate with ATLAS to get current phase entries
    // - In INTEGRATE mode, prioritize entries from current phase
    // - Include entries from adjacent phases for context
    
    if (mode == EngagementMode.deeper) {
      final phaseEntries = entries.where((e) => e.metadata?['phase'] != null).toList();
      final otherEntries = entries.where((e) => e.metadata?['phase'] == null).toList();

      return [...phaseEntries, ...otherEntries].take(maxCount).toList();
    }

    return entries.take(maxCount).toList();
  }
}

