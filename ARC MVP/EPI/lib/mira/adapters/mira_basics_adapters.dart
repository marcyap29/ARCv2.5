// File: lib/mira/adapters/mira_basics_adapters.dart
//
// Concrete implementations of MIRA basics interfaces using existing EPI repositories

import 'dart:async';
import '../mira_basics.dart';
import '../../arc/core/journal_repository.dart' as arc;
import '../../atlas/phase_detection/phase_history_repository.dart' as atlas;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/journal_entry_model.dart';

// ------------------------------
// JOURNAL REPOSITORY ADAPTER
// ------------------------------

class EPIJournalRepository implements JournalRepository {
  final arc.JournalRepository _arcRepo;

  EPIJournalRepository(this._arcRepo);

  @override
  Future<List<JournalEntry>> getAll() async {
    try {
      final arcEntries = _arcRepo.getAllJournalEntries();
      return arcEntries.map((entry) => JournalEntry(
        id: entry.id,
        title: entry.title,
        content: entry.content,
        createdAt: entry.createdAt,
        updatedAt: entry.updatedAt,
        tags: entry.tags,
        mood: entry.mood,
        audioUri: entry.audioUri,
        media: entry.media,
        sageAnnotation: entry.sageAnnotation,
        keywords: entry.keywords,
        emotion: entry.emotion,
        emotionReason: entry.emotionReason,
        metadata: entry.metadata,
      )).toList();
    } catch (e) {
      print('EPIJournalRepository: Error getting entries: $e');
      return <JournalEntry>[];
    }
  }
}

// ------------------------------
// MEMORY REPOSITORY ADAPTER
// ------------------------------

class EPIMemoryRepository implements MemoryRepo {
  EPIMemoryRepository();

  @override
  Future<List<String>> topKeywords({int limit = 10}) async {
    try {
      // Use MIRA's keyword extraction if available
      // For now, return empty list as placeholder
      return <String>[];
    } catch (e) {
      print('EPIMemoryRepository: Error getting keywords: $e');
      return <String>[];
    }
  }

  @override
  Future<List<String>> lastUserPrompts({int limit = 5}) async {
    try {
      // Use MIRA's chat history if available
      // For now, return empty list as placeholder
      return <String>[];
    } catch (e) {
      print('EPIMemoryRepository: Error getting prompts: $e');
      return <String>[];
    }
  }

  @override
  Future<String?> currentPhaseFromHistory() async {
    try {
      // Get the most recent phase from history entries
      final recentEntries = await atlas.PhaseHistoryRepository.getRecentEntries(10);
      if (recentEntries.isEmpty) return null;
      
      // Find the phase with the highest score in the most recent entry
      final latestEntry = recentEntries.last;
      String? highestPhase;
      double highestScore = 0.0;
      
      for (final phase in latestEntry.phaseScores.keys) {
        final score = latestEntry.phaseScores[phase] ?? 0.0;
        if (score > highestScore) {
          highestScore = score;
          highestPhase = phase;
        }
      }
      
      return highestPhase;
    } catch (e) {
      print('EPIMemoryRepository: Error getting current phase: $e');
      return null;
    }
  }

  @override
  Future<String?> lastPhaseChangeAt(String phase) async {
    try {
      final entries = await atlas.PhaseHistoryRepository.getEntriesForPhase(phase);
      if (entries.isEmpty) return null;
      
      // Get the most recent entry for this phase
      final mostRecent = entries.last;
      return mostRecent.timestamp.toIso8601String();
    } catch (e) {
      print('EPIMemoryRepository: Error getting phase change time: $e');
      return null;
    }
  }
}

// ------------------------------
// SETTINGS REPOSITORY ADAPTER
// ------------------------------

class EPISettingsRepository implements SettingsRepo {
  static const String _memoryModeKey = 'memory_mode_suggestive';
  static const String _onboardingIntentKey = 'onboarding_intent';

  @override
  Future<bool> get memoryModeSuggestive async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_memoryModeKey) ?? false;
    } catch (e) {
      print('EPISettingsRepository: Error getting memory mode: $e');
      return false;
    }
  }

  @override
  Future<String?> onboardingIntent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_onboardingIntentKey);
    } catch (e) {
      print('EPISettingsRepository: Error getting onboarding intent: $e');
      return null;
    }
  }
}

// ------------------------------
// FACTORY FOR EASY SETUP
// ------------------------------

class MiraBasicsFactory {
  static Future<MiraBasicsProvider> createProvider() async {
    // Initialize repositories
    final arcJournalRepo = arc.JournalRepository();
    final settingsRepo = EPISettingsRepository();

    // Create adapters
    final journalAdapter = EPIJournalRepository(arcJournalRepo);
    final memoryAdapter = EPIMemoryRepository();

    // Create provider
    return MiraBasicsProvider(
      journalRepo: journalAdapter,
      memoryRepo: memoryAdapter,
      settings: settingsRepo,
    );
  }
}
