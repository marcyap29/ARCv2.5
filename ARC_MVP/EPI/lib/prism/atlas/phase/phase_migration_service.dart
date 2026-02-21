import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/prism/atlas/phase/phase_inference_service.dart';
import 'package:hive/hive.dart';
import 'package:my_app/models/user_profile_model.dart';

/// Result of phase recomputation for a single entry
class PhaseRecomputeSuggestion {
  final String entryId;
  final String? oldAutoPhase;
  final String? oldUserPhaseOverride;
  final String? legacyPhaseTag;
  final int? oldPhaseInferenceVersion;
  final String newAutoPhase;
  final double newConfidence;
  final int newPhaseInferenceVersion;

  const PhaseRecomputeSuggestion({
    required this.entryId,
    this.oldAutoPhase,
    this.oldUserPhaseOverride,
    this.legacyPhaseTag,
    this.oldPhaseInferenceVersion,
    required this.newAutoPhase,
    required this.newConfidence,
    required this.newPhaseInferenceVersion,
  });

  /// Check if the phase actually changed
  bool get phaseChanged => oldAutoPhase != newAutoPhase;
}

/// Result of recompute operation for a user
class PhaseRecomputeResult {
  final List<PhaseRecomputeSuggestion> suggestions;
  final int totalCandidates;
  final int lockedEntriesSkipped;

  const PhaseRecomputeResult({
    required this.suggestions,
    required this.totalCandidates,
    required this.lockedEntriesSkipped,
  });
}

/// Service for on-demand phase migration and recomputation
/// 
/// Finds entries that need phase inference updates and provides
/// suggestions for review before applying changes.
class PhaseMigrationService {
  final JournalRepository _journalRepository;

  PhaseMigrationService({
    JournalRepository? journalRepository,
  }) : _journalRepository = journalRepository ?? JournalRepository();

  /// Recompute phases for all eligible entries for a user
  /// 
  /// Finds entries where:
  /// - phaseInferenceVersion == null OR
  /// - phaseInferenceVersion < CURRENT_VERSION OR
  /// - phaseMigrationStatus == "PENDING"
  /// AND isPhaseLocked == false
  /// 
  /// Returns suggestions with old/new phase comparison
  Future<PhaseRecomputeResult> recomputePhasesForUser() async {
    final allEntries = await _journalRepository.getAllJournalEntries();
    
    // Filter candidates
    final candidates = allEntries.where((entry) {
      // Skip locked entries
      if (entry.isPhaseLocked) {
        return false;
      }
      
      // Check if entry needs migration
      final needsMigration = 
          entry.phaseInferenceVersion == null ||
          entry.phaseInferenceVersion! < CURRENT_PHASE_INFERENCE_VERSION ||
          entry.phaseMigrationStatus == 'PENDING';
      
      return needsMigration;
    }).toList();
    
    final lockedCount = allEntries.length - candidates.length;
    
    // Sort by date (oldest first for context)
    candidates.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    
    // Get user profile for userId
    final userBox = await Hive.openBox<UserProfile>('user_profile');
    final userProfile = userBox.get('profile');
    final userId = userProfile?.id ?? '';
    
    final suggestions = <PhaseRecomputeSuggestion>[];
    
    // Process each candidate
    for (final entry in candidates) {
      try {
        // Get recent entries for context (entries before this one)
        final recentEntries = candidates
            .where((e) => e.createdAt.isBefore(entry.createdAt))
            .take(7)
            .toList();
        
        // Run phase inference
        final inferenceResult = await PhaseInferenceService.inferPhaseForEntry(
          entryContent: entry.content,
          userId: userId,
          createdAt: entry.createdAt,
          recentEntries: recentEntries,
          emotion: entry.emotion,
          emotionReason: entry.emotionReason,
          selectedKeywords: entry.keywords,
        );
        
        // Create suggestion
        final suggestion = PhaseRecomputeSuggestion(
          entryId: entry.id,
          oldAutoPhase: entry.autoPhase,
          oldUserPhaseOverride: entry.userPhaseOverride,
          legacyPhaseTag: entry.legacyPhaseTag,
          oldPhaseInferenceVersion: entry.phaseInferenceVersion,
          newAutoPhase: inferenceResult.phase,
          newConfidence: inferenceResult.confidence,
          newPhaseInferenceVersion: CURRENT_PHASE_INFERENCE_VERSION,
        );
        
        suggestions.add(suggestion);
      } catch (e) {
        print('ERROR: Phase recompute failed for entry ${entry.id}: $e');
      }
    }
    
    return PhaseRecomputeResult(
      suggestions: suggestions,
      totalCandidates: candidates.length,
      lockedEntriesSkipped: lockedCount,
    );
  }

  /// Apply phase recompute suggestions to entries
  /// 
  /// Updates entries with new phase fields based on suggestions.
  /// Only updates entries that are still eligible (not locked).
  Future<int> applyRecomputeSuggestions(List<PhaseRecomputeSuggestion> suggestions) async {
    int applied = 0;
    
    for (final suggestion in suggestions) {
      try {
        final entry = await _journalRepository.getJournalEntryById(suggestion.entryId);
        
        if (entry == null) {
          print('WARNING: Entry ${suggestion.entryId} not found, skipping');
          continue;
        }
        
        // Double-check entry is still eligible (not locked)
        if (entry.isPhaseLocked) {
          print('WARNING: Entry ${suggestion.entryId} is now locked, skipping');
          continue;
        }
        
        // Update entry with new phase fields
        final updatedEntry = entry.copyWith(
          autoPhase: suggestion.newAutoPhase,
          autoPhaseConfidence: suggestion.newConfidence,
          phaseInferenceVersion: suggestion.newPhaseInferenceVersion,
          phaseMigrationStatus: 'DONE',
          // Preserve user override if it exists
          userPhaseOverride: entry.userPhaseOverride,
          isPhaseLocked: entry.isPhaseLocked,
        );
        
        await _journalRepository.updateJournalEntry(updatedEntry);
        applied++;
        
        print('DEBUG: Applied phase recompute for entry ${suggestion.entryId}: ${suggestion.oldAutoPhase} → ${suggestion.newAutoPhase}');
      } catch (e) {
        print('ERROR: Failed to apply suggestion for entry ${suggestion.entryId}: $e');
      }
    }
    
    return applied;
  }

  /// Get entries that need migration (for UI display)
  Future<List<JournalEntry>> getEntriesNeedingMigration() async {
    final allEntries = await _journalRepository.getAllJournalEntries();
    
    return allEntries.where((entry) {
      if (entry.isPhaseLocked) return false;
      
      return entry.phaseInferenceVersion == null ||
          entry.phaseInferenceVersion! < CURRENT_PHASE_INFERENCE_VERSION ||
          entry.phaseMigrationStatus == 'PENDING';
    }).toList();
  }
}

