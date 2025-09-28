import 'dart:async';
import 'package:hive/hive.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/features/timeline/timeline_state.dart';
import 'package:my_app/arc/core/sage_annotation_model.dart';

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

  // Create
  Future<void> createJournalEntry(JournalEntry entry) async {
    final box = await _ensureBox();
    await box.put(entry.id, entry);
  }

  // Read
  List<JournalEntry> getAllJournalEntries() {
    try {
      if (Hive.isBoxOpen(_boxName)) {
        final entries = Hive.box<JournalEntry>(_boxName).values.toList();
        print('🔍 JournalRepository: Retrieved ${entries.length} journal entries from open box');
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
    if (!Hive.isBoxOpen(_boxName)) {
      return const [];
    }
    final box = Hive.box<JournalEntry>(_boxName);
    final entries = <JournalEntry>[];
    for (final key in box.keys) {
      final e = box.get(key);
      if (e == null) continue;
      entries.add(_normalize(e));
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
        media: e.media,
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
    final box = await _ensureBox();
    await box.delete(id);
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

  // Close the box
  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
    }
  }
}
