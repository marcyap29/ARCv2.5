import '../../../models/journal_entry_model.dart';
import '../../../prism/atlas/phase/phase_history_repository.dart';
import 'layer0_repository.dart';
import 'raw_entry_schema.dart';

/// Service for populating Layer 0 from journal entries
/// 
/// Extracts data from:
/// - JournalEntry (content, timestamp, metadata)
/// - PhaseHistoryEntry (phase scores, reason)
/// - SENTINEL/RIVET calculations (if available)
/// - Existing theme/keyword extractors

class Layer0Populator {
  final Layer0Repository _layer0Repo;

  Layer0Populator(this._layer0Repo);

  /// Populate Layer 0 from a journal entry
  /// 
  /// This should be called after a journal entry is saved.
  Future<void> populateFromJournalEntry({
    required JournalEntry journalEntry,
    required String userId,
  }) async {
    try {
      // 1. Get phase history entry if available
      final phaseHistory = await PhaseHistoryRepository.getEntryByJournalId(journalEntry.id);

      // 2. Extract metadata
      final metadata = RawEntryMetadata(
        wordCount: journalEntry.content.split(RegExp(r'\s+')).length,
        voiceTranscribed: journalEntry.audioUri != null,
        mediaAttachments: journalEntry.media
            .map((m) => m.id)
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toList(),
      );

      // 3. Extract analysis data
      final analysis = RawEntryAnalysis(
        atlasPhase: _getEffectivePhase(journalEntry, phaseHistory),
        atlasScores: phaseHistory?.phaseScores,
        extractedThemes: journalEntry.keywords, // TODO: Enhance with theme extraction
        keywords: journalEntry.keywords,
        // TODO: Add SENTINEL score calculation when available
        // TODO: Add RIVET transitions when available
      );

      // 4. Create raw entry schema
      final schema = RawEntrySchema(
        entryId: journalEntry.id,
        timestamp: journalEntry.createdAt,
        content: journalEntry.content,
        metadata: metadata,
        analysis: analysis,
      );

      // 5. Convert to Hive model and save
      final rawEntry = ChronicleRawEntry.fromSchema(schema, userId);
      await _layer0Repo.saveEntry(rawEntry);

      print('✅ Layer0Populator: Populated Layer 0 for entry ${journalEntry.id}');
    } catch (e) {
      print('❌ Layer0Populator: Failed to populate Layer 0 for entry ${journalEntry.id}: $e');
      // Don't rethrow - Layer 0 population failure shouldn't break journal save
    }
  }

  /// Get the effective phase for an entry
  /// Priority: userPhaseOverride > autoPhase > phaseHistory phase > legacy phase
  String? _getEffectivePhase(JournalEntry entry, PhaseHistoryEntry? phaseHistory) {
    // Check user override first
    if (entry.userPhaseOverride != null) {
      return entry.userPhaseOverride;
    }

    // Check auto phase
    if (entry.autoPhase != null) {
      return entry.autoPhase;
    }

    // Check phase history (dominant phase from scores)
    if (phaseHistory != null && phaseHistory.phaseScores.isNotEmpty) {
      final dominantPhase = phaseHistory.phaseScores.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      return dominantPhase;
    }

    // Check legacy phase field
    if (entry.phase != null) {
      return entry.phase;
    }

    return null;
  }

  /// Populate Layer 0 for multiple entries (batch operation)
  Future<void> populateFromJournalEntries({
    required List<JournalEntry> entries,
    required String userId,
  }) async {
    for (final entry in entries) {
      await populateFromJournalEntry(journalEntry: entry, userId: userId);
    }
  }
}
