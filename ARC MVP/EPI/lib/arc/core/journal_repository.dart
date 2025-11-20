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
