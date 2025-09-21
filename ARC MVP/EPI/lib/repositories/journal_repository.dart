import 'package:hive/hive.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/features/timeline/timeline_state.dart';

/// Self-initializing repository with consistent box name.
/// No external init() needed.
class JournalRepository {
  static const String _boxName = 'journal_entries';
  Box<JournalEntry>? _box;

  Future<Box<JournalEntry>> _ensureBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    if (Hive.isBoxOpen(_boxName)) {
      _box = Hive.box<JournalEntry>(_boxName);
    } else {
      try {
        _box = await Hive.openBox<JournalEntry>(_boxName);
      } catch (e) {
        // If the box is already open with a different type, use the existing box
        if (e.toString().contains('already open')) {
          _box = Hive.box<JournalEntry>(_boxName);
        } else {
          rethrow;
        }
      }
    }
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
  List<JournalEntry> getEntriesPaginated({
    required int page,
    required int pageSize,
    TimelineFilter? filter,
  }) {
    final values = Hive.isBoxOpen(_boxName)
        ? Hive.box<JournalEntry>(_boxName).values.toList()
        : <JournalEntry>[];

    final allEntries = values
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Newest first

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
