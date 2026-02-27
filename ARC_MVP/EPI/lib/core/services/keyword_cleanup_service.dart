/// Keyword Cleanup Service
///
/// Periodically checks all journal entries for duplicate keywords
/// and removes them, preserving the first occurrence's case.
library;

import 'package:flutter/foundation.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/models/journal_entry_model.dart';

class KeywordCleanupService {
  static KeywordCleanupService? _instance;
  static KeywordCleanupService get instance => _instance ??= KeywordCleanupService._();
  KeywordCleanupService._();

  final JournalRepository _repository = JournalRepository();

  /// Clean up duplicate keywords across all entries
  /// Returns the number of entries that were fixed
  Future<int> cleanupAllEntries() async {
    try {
      debugPrint('KeywordCleanupService: Starting cleanup of all entries...');
      
      // Get all entries (using sync method since it's fast for Hive)
      final allEntries = _repository.getAllJournalEntriesSync();
      int fixedCount = 0;
      
      for (final entry in allEntries) {
        final cleanedKeywords = _removeDuplicates(entry.keywords);
        
        // Only update if there were duplicates removed
        if (cleanedKeywords.length != entry.keywords.length) {
          final updatedEntry = entry.copyWith(
            keywords: cleanedKeywords,
            updatedAt: DateTime.now(),
          );
          
          await _repository.updateJournalEntry(updatedEntry);
          fixedCount++;
          
          debugPrint('KeywordCleanupService: Fixed entry ${entry.id} - '
              'removed ${entry.keywords.length - cleanedKeywords.length} duplicate keywords');
        }
      }
      
      debugPrint('KeywordCleanupService: Cleanup complete. Fixed $fixedCount entries.');
      return fixedCount;
    } catch (e) {
      debugPrint('KeywordCleanupService: Error during cleanup: $e');
      rethrow;
    }
  }

  /// Clean up duplicate keywords in a single entry
  Future<bool> cleanupEntry(JournalEntry entry) async {
    try {
      final cleanedKeywords = _removeDuplicates(entry.keywords);
      
      // Only update if there were duplicates removed
      if (cleanedKeywords.length != entry.keywords.length) {
        final updatedEntry = entry.copyWith(
          keywords: cleanedKeywords,
          updatedAt: DateTime.now(),
        );
        
        await _repository.updateJournalEntry(updatedEntry);
        debugPrint('KeywordCleanupService: Fixed entry ${entry.id} - '
            'removed ${entry.keywords.length - cleanedKeywords.length} duplicate keywords');
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('KeywordCleanupService: Error cleaning entry ${entry.id}: $e');
      return false;
    }
  }

  /// Remove duplicate keywords from a list (case-insensitive comparison)
  /// Preserves the first occurrence's case
  List<String> _removeDuplicates(List<String> keywords) {
    if (keywords.isEmpty) return [];
    
    final seen = <String>{};
    final result = <String>[];
    
    for (final keyword in keywords) {
      final normalized = keyword.trim().toLowerCase();
      
      // Skip empty keywords after trimming
      if (normalized.isEmpty) continue;
      
      // Only add if we haven't seen this keyword (case-insensitive)
      if (!seen.contains(normalized)) {
        seen.add(normalized);
        result.add(keyword.trim()); // Preserve original case and trim whitespace
      }
    }
    
    return result;
  }

  /// Get statistics about duplicate keywords across all entries
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final allEntries = _repository.getAllJournalEntriesSync();
      int totalDuplicates = 0;
      int entriesWithDuplicates = 0;
      int totalKeywords = 0;
      
      for (final entry in allEntries) {
        final originalCount = entry.keywords.length;
        final cleaned = _removeDuplicates(entry.keywords);
        final duplicates = originalCount - cleaned.length;
        
        totalKeywords += originalCount;
        totalDuplicates += duplicates;
        
        if (duplicates > 0) {
          entriesWithDuplicates++;
        }
      }
      
      return {
        'total_entries': allEntries.length,
        'entries_with_duplicates': entriesWithDuplicates,
        'total_keywords': totalKeywords,
        'total_duplicates': totalDuplicates,
        'unique_keywords': totalKeywords - totalDuplicates,
      };
    } catch (e) {
      debugPrint('KeywordCleanupService: Error getting statistics: $e');
      return {
        'error': e.toString(),
      };
    }
  }
}

