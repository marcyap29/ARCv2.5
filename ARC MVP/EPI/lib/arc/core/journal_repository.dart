import 'dart:async';
import 'package:hive/hive.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/arc/ui/timeline/timeline_state.dart';
import 'package:my_app/arc/core/sage_annotation_model.dart';
import 'package:my_app/mira/mira_service.dart';
import 'package:my_app/mira/core/ids.dart';
import 'package:my_app/data/models/media_item.dart';

/// Self-initializing repository with consistent box name.
/// No external init() needed.
class JournalRepository {
  static const String _boxName = 'journal_entries';
  Box<JournalEntry>? _box;

  Future<Box<JournalEntry>> _openBoxSafely({int retries = 5}) async {
    for (var i = 0; i < retries; i++) {
      if (Hive.isBoxOpen(_boxName)) return Hive.box<JournalEntry>(_boxName);
      try {
        return await Hive.openBox<JournalEntry>(_boxName);
      } catch (_) {
        await Future.delayed(Duration(milliseconds: 80 * (i + 1)));
      }
    }
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox<JournalEntry>(_boxName);
    }
    return Hive.box<JournalEntry>(_boxName);
  }

  Future<Box<JournalEntry>> _ensureBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await _openBoxSafely();
    return _box!;
  }

  /// Ensure MediaItem adapter is registered before saving entries with media
  void _ensureMediaItemAdapter() {
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(MediaTypeAdapter());
      print('🔍 JournalRepository: Registered MediaTypeAdapter (ID: 10)');
    }
    if (!Hive.isAdapterRegistered(11)) {
      Hive.registerAdapter(MediaItemAdapter());
      print('🔍 JournalRepository: Registered MediaItemAdapter (ID: 11)');
    }
  }

  // Create
  Future<void> createJournalEntry(JournalEntry entry) async {
    print('🔍 JournalRepository: Creating journal entry with ID: ${entry.id}');
    print('🔍 JournalRepository: Entry content: ${entry.content}');
    print('🔍 JournalRepository: Entry media count: ${entry.media.length}');
    
    // Ensure MediaItem adapter is registered if entry has media
    if (entry.media.isNotEmpty) {
      _ensureMediaItemAdapter();
      if (!Hive.isAdapterRegistered(11)) {
        print('❌ JournalRepository: CRITICAL - MediaItemAdapter (ID: 11) is NOT registered!');
      } else {
        print('✅ JournalRepository: Verified MediaItemAdapter (ID: 11) is registered');
      }
    }
    
    try {
      final box = await _ensureBox();
      await box.put(entry.id, entry);
      print('🔍 JournalRepository: Successfully saved entry ${entry.id} to database');
      
      // Verify the entry was saved
      final savedEntry = box.get(entry.id);
      if (savedEntry != null) {
        print('🔍 JournalRepository: Verification - Entry ${entry.id} found in database');
        print('🔍 JournalRepository: Verification - Saved entry media count: ${savedEntry.media.length}');
        if (savedEntry.media.length != entry.media.length) {
          print('❌ JournalRepository: CRITICAL - Media count mismatch! Saved: ${entry.media.length}, Retrieved: ${savedEntry.media.length}');
          if (savedEntry.media.isEmpty && entry.media.isNotEmpty) {
            print('❌ JournalRepository: Media list was lost during save/retrieve!');
            print('   Original media IDs: ${entry.media.map((m) => m.id).toList()}');
          }
        }
        if (savedEntry.media.isNotEmpty) {
          print('🔍 JournalRepository: First saved media item: id=${savedEntry.media.first.id}, type=${savedEntry.media.first.type}, uri=${savedEntry.media.first.uri}');
        }
      } else {
        print('🔍 JournalRepository: ERROR - Entry ${entry.id} not found in database after save');
      }
    } catch (e) {
      print('🔍 JournalRepository: ERROR saving entry ${entry.id}: $e');
      rethrow;
    }
  }

  // Read
  List<JournalEntry> getAllJournalEntries() {
    try {
      print('🔍 JournalRepository: getAllJournalEntries called');
      
      // Ensure MediaItem adapter is registered before loading entries
      _ensureMediaItemAdapter();
      if (!Hive.isAdapterRegistered(11)) {
        print('❌ JournalRepository: CRITICAL - MediaItemAdapter (ID: 11) is NOT registered when loading entries!');
      } else {
        print('✅ JournalRepository: Verified MediaItemAdapter (ID: 11) is registered when loading');
      }
      
      if (Hive.isBoxOpen(_boxName)) {
        final box = Hive.box<JournalEntry>(_boxName);
        print('🔍 JournalRepository: Box $_boxName is open, retrieving entries...');
        final entries = box.values.toList();
        print('🔍 JournalRepository: Retrieved ${entries.length} journal entries from open box');
        
        // Debug: Print details of each entry
        for (int i = 0; i < entries.length; i++) {
          final entry = entries[i];
          print('🔍 JournalRepository: Entry $i - ID: ${entry.id}, Content: ${entry.content.substring(0, entry.content.length > 50 ? 50 : entry.content.length)}..., Media: ${entry.media.length}');
          if (entry.media.isNotEmpty) {
            print('🔍 JournalRepository: Entry ${entry.id} has ${entry.media.length} media items:');
            for (int j = 0; j < entry.media.length && j < 3; j++) {
              final media = entry.media[j];
              print('  Media $j: id=${media.id}, type=${media.type.name}, uri=${media.uri.substring(0, media.uri.length > 60 ? 60 : media.uri.length)}...');
            }
            if (entry.media.length > 3) {
              print('  ... and ${entry.media.length - 3} more');
            }
          }
        }
        
        return entries;
      } else {
        print('🔍 JournalRepository: WARNING - Box $_boxName is not open, cannot retrieve entries');
        // Try to open the box synchronously if possible
        try {
          final box = Hive.box<JournalEntry>(_boxName);
          final entries = box.values.toList();
          print('🔍 JournalRepository: Successfully opened box and retrieved ${entries.length} entries');
          return entries;
        } catch (e) {
          print('🔍 JournalRepository: ERROR - Could not open box $_boxName: $e');
          return const [];
        }
      }
    } catch (e) {
      print('🔍 JournalRepository: ERROR in getAllJournalEntries: $e');
      return const [];
    }
  }

  // Synchronous version for backward compatibility
  List<JournalEntry> getAllJournalEntriesSync() {
    // Ensure MediaItem adapter is registered before loading entries
    _ensureMediaItemAdapter();
    if (!Hive.isAdapterRegistered(11)) {
      print('❌ JournalRepository: CRITICAL - MediaItemAdapter (ID: 11) is NOT registered when loading entries synchronously!');
    } else {
      print('✅ JournalRepository: Verified MediaItemAdapter (ID: 11) is registered when loading synchronously');
    }
    
    if (!Hive.isBoxOpen(_boxName)) {
      return const [];
    }
    final box = Hive.box<JournalEntry>(_boxName);
    final entries = <JournalEntry>[];
    for (final key in box.keys) {
      final e = box.get(key);
      if (e == null) continue;
      
      // Debug: Check media before normalization
      if (e.media.isNotEmpty) {
        print('🔍 JournalRepository: Entry ${e.id} has ${e.media.length} media items BEFORE normalization');
        for (int j = 0; j < e.media.length && j < 3; j++) {
          final media = e.media[j];
          print('  Media $j: id=${media.id}, type=${media.type.name}, uri=${media.uri.substring(0, media.uri.length > 60 ? 60 : media.uri.length)}...');
        }
      }
      
      final normalized = _normalize(e);
      
      // Debug: Check media after normalization
      if (normalized.media.length != e.media.length) {
        print('❌ JournalRepository: CRITICAL - Media count changed during normalization! Before: ${e.media.length}, After: ${normalized.media.length}');
      }
      if (normalized.media.isNotEmpty) {
        print('🔍 JournalRepository: Entry ${normalized.id} has ${normalized.media.length} media items AFTER normalization');
      }
      
      entries.add(normalized);
    }
    return entries;
  }

    JournalEntry _normalize(JournalEntry e) {
      // Check if we need to migrate legacy metadata to SAGE annotation
      SAGEAnnotation? sageAnnotation = e.sageAnnotation;
      if (sageAnnotation == null && e.metadata?['narrative'] != null) {
        final n = e.metadata!['narrative'] as Map?;
        if (n != null) {
          sageAnnotation = SAGEAnnotation(
            situation: (n['situation'] ?? '').toString(),
            action: (n['action'] ?? '').toString(),
            growth: (n['growth'] ?? '').toString(),
            essence: (n['essence'] ?? '').toString(),
            confidence: 0.8, // Default confidence for migrated annotations
          );
        }
      }

      // Ensure media list is properly preserved (create new list to avoid reference issues)
      final mediaList = List<MediaItem>.from(e.media);
      
      // Debug: Log media preservation
      if (e.media.isNotEmpty && mediaList.isEmpty) {
        print('❌ JournalRepository: CRITICAL - Media list was lost during normalization! Original count: ${e.media.length}');
      }

      // Create a new entry with normalized data
      return JournalEntry(
        id: e.id,
        title: e.title,
        content: e.content,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
        tags: e.tags,
        mood: e.mood,
        audioUri: e.audioUri,
        media: mediaList, // Use preserved media list
        keywords: e.keywords,
        sageAnnotation: sageAnnotation,
        emotion: e.emotion,
        emotionReason: e.emotionReason,
        metadata: e.metadata,
      );
    }

  JournalEntry? getJournalEntryById(String id) {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<JournalEntry>(_boxName).get(id);
    }
    return null;
  }

  // Update
  Future<void> updateJournalEntry(JournalEntry entry) async {
    final box = await _ensureBox();
    await box.put(entry.id, entry);
  }

  // Delete
  Future<void> deleteJournalEntry(String id) async {
    // Get the entry before deleting to clean up MIRA data
    final entry = await getJournalEntryById(id);
    
    // Delete from journal repository
    final box = await _ensureBox();
    await box.delete(id);
    
    // Clean up MIRA nodes and edges if entry existed
    if (entry != null) {
      try {
        final miraService = MiraService.instance;
        final miraNodeId = deterministicEntryId(entry.content, entry.createdAt);
        
        print('🔍 Journal: Cleaning up MIRA data for entry $id (MIRA node: $miraNodeId)');
        
        // Delete the entry node and its edges
        await miraService.deleteNode(miraNodeId);
        
        // Clean up orphaned keyword nodes
        if (entry.keywords.isNotEmpty) {
          await miraService.cleanupOrphanedKeywords(entry.keywords);
        }
        
        print('✅ Journal: Successfully cleaned up MIRA data for entry $id');
      } catch (e) {
        print('❌ Journal: Error cleaning up MIRA data for entry $id: $e');
        // Don't rethrow - journal entry is already deleted
      }
    }
  }

  Future<void> deleteAllEntries() async {
    final box = await _ensureBox();
    await box.clear();
  }

  Future<int> getEntryCount() async {
    final box = await _ensureBox();
    return box.length;
  }

  /// Remove duplicate entries, keeping the most recent version of each
  /// Duplicates are identified by:
  /// 1. Same ID (shouldn't happen with Hive, but check anyway)
  /// 2. Same content + createdAt (within 1 second tolerance)
  Future<int> removeDuplicateEntries() async {
    print('🔍 JournalRepository: Starting duplicate removal...');
    final box = await _ensureBox();
    final allEntries = box.values.toList();
    final originalCount = allEntries.length;
    
    // Track entries to keep and delete
    final entriesToKeep = <String, JournalEntry>{};
    final entriesToDelete = <String>[];
    
    // First pass: Check for duplicate IDs (shouldn't happen, but check)
    final idMap = <String, List<JournalEntry>>{};
    for (final entry in allEntries) {
      if (!idMap.containsKey(entry.id)) {
        idMap[entry.id] = [];
      }
      idMap[entry.id]!.add(entry);
    }
    
    // If we find duplicate IDs, keep the one with the latest updatedAt
    for (final entryList in idMap.values) {
      if (entryList.length > 1) {
        print('⚠️ JournalRepository: Found ${entryList.length} entries with same ID: ${entryList.first.id}');
        // Sort by updatedAt descending, keep the first (most recent)
        entryList.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        entriesToKeep[entryList.first.id] = entryList.first;
        // Mark others for deletion
        for (int i = 1; i < entryList.length; i++) {
          entriesToDelete.add(entryList[i].id);
          print('   Marking duplicate ID entry for deletion: ${entryList[i].id}');
        }
      } else {
        entriesToKeep[entryList.first.id] = entryList.first;
      }
    }
    
    // Helper function to normalize content for comparison
    String normalizeContent(String content) {
      // Remove all whitespace, convert to lowercase, remove punctuation
      return content
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
          .replaceAll(RegExp(r'\s+'), '') // Remove all whitespace
          .trim();
    }
    
    // Helper function to get date-only key (ignore time)
    String getDateKey(DateTime date) {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
    
    // Second pass: Check for duplicate content + date (by day only, normalized content)
    final contentDateMap = <String, List<JournalEntry>>{};
    for (final entry in entriesToKeep.values) {
      // Create a key from normalized content + date (day only)
      final dateKey = getDateKey(entry.createdAt);
      final normalizedContent = normalizeContent(entry.content);
      final key = '$dateKey|$normalizedContent';
      
      if (!contentDateMap.containsKey(key)) {
        contentDateMap[key] = [];
      }
      contentDateMap[key]!.add(entry);
    }
    
    // For entries with same normalized content + date, keep the one with latest updatedAt
    for (final entryList in contentDateMap.values) {
      if (entryList.length > 1) {
        print('⚠️ JournalRepository: Found ${entryList.length} entries with same content and date');
        for (final e in entryList) {
          print('   Entry ID: ${e.id}, Date: ${e.createdAt}, Updated: ${e.updatedAt}');
          print('   Content preview: ${e.content.substring(0, e.content.length > 100 ? 100 : e.content.length)}...');
        }
        
        // Sort by updatedAt descending, keep the first (most recent)
        entryList.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        final keepEntry = entryList.first;
        
        // Mark others for deletion
        for (int i = 1; i < entryList.length; i++) {
          final duplicateEntry = entryList[i];
          // Only delete if not already marked for deletion
          if (!entriesToDelete.contains(duplicateEntry.id)) {
            entriesToDelete.add(duplicateEntry.id);
            print('   ✅ Marking duplicate content entry for deletion: ${duplicateEntry.id} (keeping ${keepEntry.id})');
          }
        }
      }
    }
    
    // Third pass: Also check for entries with very similar content (fuzzy match)
    // This catches cases where content might have minor differences
    if (entriesToDelete.isEmpty) {
      print('🔍 JournalRepository: No exact duplicates found, checking for similar content...');
      final remainingEntries = entriesToKeep.values.where((e) => !entriesToDelete.contains(e.id)).toList();
      
      for (int i = 0; i < remainingEntries.length; i++) {
        final entry1 = remainingEntries[i];
        if (entriesToDelete.contains(entry1.id)) continue;
        
        final date1 = getDateKey(entry1.createdAt);
        final content1 = normalizeContent(entry1.content);
        
        // Skip if content is too short (likely not a real duplicate)
        if (content1.length < 20) continue;
        
        for (int j = i + 1; j < remainingEntries.length; j++) {
          final entry2 = remainingEntries[j];
          if (entriesToDelete.contains(entry2.id)) continue;
          
          final date2 = getDateKey(entry2.createdAt);
          final content2 = normalizeContent(entry2.content);
          
          // Check if same date and very similar content (95% similarity)
          if (date1 == date2 && content1.length > 20 && content2.length > 20) {
            // Calculate similarity
            final longer = content1.length > content2.length ? content1 : content2;
            final shorter = content1.length > content2.length ? content2 : content1;
            
            // Check if shorter is contained in longer (with some tolerance)
            if (longer.contains(shorter) || shorter.length >= longer.length * 0.95) {
              // Very similar content on same date - likely duplicates
              print('⚠️ JournalRepository: Found similar entries (${(shorter.length / longer.length * 100).toStringAsFixed(1)}% match)');
              print('   Entry 1 ID: ${entry1.id}, Date: ${entry1.createdAt}');
              print('   Entry 2 ID: ${entry2.id}, Date: ${entry2.createdAt}');
              
              // Keep the one with latest updatedAt
              final toKeep = entry1.updatedAt.isAfter(entry2.updatedAt) ? entry1 : entry2;
              final toDelete = entry1.updatedAt.isAfter(entry2.updatedAt) ? entry2 : entry1;
              
              if (!entriesToDelete.contains(toDelete.id)) {
                entriesToDelete.add(toDelete.id);
                print('   ✅ Marking similar entry for deletion: ${toDelete.id} (keeping ${toKeep.id})');
              }
            }
          }
        }
      }
    }
    
    // Delete duplicate entries
    int deletedCount = 0;
    for (final entryId in entriesToDelete) {
      try {
        await box.delete(entryId);
        deletedCount++;
        print('✅ JournalRepository: Deleted duplicate entry: $entryId');
      } catch (e) {
        print('❌ JournalRepository: Error deleting duplicate entry $entryId: $e');
      }
    }
    
    final finalCount = box.length;
    print('🔍 JournalRepository: Duplicate removal complete');
    print('   Original entries: $originalCount');
    print('   Duplicates removed: $deletedCount');
    print('   Remaining entries: $finalCount');
    
    return deletedCount;
  }

  // Pagination methods for timeline
  Future<List<JournalEntry>> getEntriesPaginated({
    required int page,
    required int pageSize,
    TimelineFilter? filter,
  }) async {
    final allEntries = getAllJournalEntries();
    allEntries.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Newest first

    // Apply filter if provided
    List<JournalEntry> filtered = allEntries;
    if (filter != null) {
      switch (filter) {
        case TimelineFilter.textOnly:
          filtered = allEntries.where((e) => e.content.isNotEmpty).toList();
          break;
        case TimelineFilter.withArcform:
          filtered = allEntries.where((e) => e.sageAnnotation != null).toList();
          break;
        case TimelineFilter.all:
        default:
          filtered = allEntries;
      }
    }

    final startIndex = page * pageSize;
    if (startIndex >= filtered.length) return [];

    final endIndex = (startIndex + pageSize).clamp(0, filtered.length);
    return filtered.sublist(startIndex, endIndex);
  }

  // Synchronous version for backward compatibility
  List<JournalEntry> getEntriesPaginatedSync({
    required int page,
    required int pageSize,
    TimelineFilter? filter,
  }) {
    final allEntries = getAllJournalEntriesSync();
    allEntries.sort((a, b) => a.createdAt.compareTo(b.createdAt)); // Oldest first

    // Apply filter if provided
    List<JournalEntry> filtered = allEntries;
    if (filter != null) {
      switch (filter) {
        case TimelineFilter.textOnly:
          filtered = allEntries.where((e) => e.content.isNotEmpty).toList();
          break;
        case TimelineFilter.withArcform:
          filtered = allEntries.where((e) => e.sageAnnotation != null).toList();
          break;
        case TimelineFilter.all:
        default:
          filtered = allEntries;
      }
    }

    final startIndex = page * pageSize;
    if (startIndex >= filtered.length) return [];

    final endIndex = (startIndex + pageSize).clamp(0, filtered.length);
    return filtered.sublist(startIndex, endIndex);
  }

  // Close the box
  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
    }
  }
}
