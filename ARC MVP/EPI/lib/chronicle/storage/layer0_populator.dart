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
  /// Backwards compatible: tolerates null/empty content and null keywords from legacy entries.
  /// Returns true if saved, false if failed (e.g. legacy/corrupt entry).
  Future<bool> populateFromJournalEntry({
    required JournalEntry journalEntry,
    required String userId,
  }) async {
    try {
      // Backwards compatibility: safe content and keywords (legacy Hive entries may have null)
      final content = _safeContent(journalEntry);
      final keywords = _safeKeywords(journalEntry);

      // 1. Get phase history entry if available
      final phaseHistory = await PhaseHistoryRepository.getEntryByJournalId(journalEntry.id);

      // 2. Extract metadata
      final wordCount = content.isEmpty ? 0 : content.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
      final mediaList = journalEntry.media;
      final mediaIds = mediaList.isNotEmpty
          ? mediaList.map((m) => m.id).whereType<String>().where((id) => id.isNotEmpty).toList()
          : <String>[];

      final metadata = RawEntryMetadata(
        wordCount: wordCount,
        voiceTranscribed: journalEntry.audioUri != null,
        mediaAttachments: mediaIds,
      );

      // 3. Extract analysis data
      final analysis = RawEntryAnalysis(
        atlasPhase: _getEffectivePhase(journalEntry, phaseHistory),
        atlasScores: phaseHistory?.phaseScores,
        extractedThemes: keywords,
        keywords: keywords,
      );

      // 4. Create raw entry schema
      final schema = RawEntrySchema(
        entryId: journalEntry.id,
        timestamp: journalEntry.createdAt,
        content: content,
        metadata: metadata,
        analysis: analysis,
      );

      // 5. Convert to Hive model and save
      final rawEntry = ChronicleRawEntry.fromSchema(schema, userId);
      await _layer0Repo.saveEntry(rawEntry);

      print('✅ Layer0Populator: Populated Layer 0 for entry ${journalEntry.id}');
      return true;
    } catch (e) {
      print('❌ Layer0Populator: Failed to populate Layer 0 for entry ${journalEntry.id}: $e');
      return false;
    }
  }

  /// Backwards compatibility: content may be null on legacy Hive entries
  String _safeContent(JournalEntry entry) {
    try {
      final c = (entry as dynamic).content;
      if (c == null) return '';
      if (c is String) return c;
      return c.toString();
    } catch (_) {
      return '';
    }
  }

  /// Backwards compatibility: keywords may be null on legacy Hive entries
  List<String> _safeKeywords(JournalEntry entry) {
    try {
      final k = (entry as dynamic).keywords;
      if (k == null) return const [];
      if (k is List) return List<String>.from(k.whereType<String>());
      return const [];
    } catch (_) {
      return const [];
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
  Future<({int succeeded, int failed})> populateFromJournalEntries({
    required List<JournalEntry> entries,
    required String userId,
  }) async {
    int succeeded = 0, failed = 0;
    for (final entry in entries) {
      final ok = await populateFromJournalEntry(journalEntry: entry, userId: userId);
      if (ok) succeeded++; else failed++;
    }
    return (succeeded: succeeded, failed: failed);
  }
}
