import 'dart:async';
import 'package:hive/hive.dart';
import '../models/voice_note.dart';

/// Repository for managing voice notes (Ideas inbox).
/// Provides CRUD operations and reactive streams for voice note data.
/// Uses a static broadcast so that any instance (e.g. from VoiceModeScreen save)
/// notifies all watch() subscribers (e.g. VoiceNotesView) when the box changes.
class VoiceNoteRepository {
  final Box<VoiceNote> _box;
  
  // Stream controller for reactive updates (this instance)
  final _notesController = StreamController<List<VoiceNote>>.broadcast();

  /// Static broadcast: when any repository instance modifies the box, all
  /// watch() subscribers (from any instance) get an update so the list refreshes.
  static final _boxChangeController = StreamController<void>.broadcast();

  VoiceNoteRepository(this._box);

  /// Get the Hive box name for registration
  static const String boxName = 'voice_notes';

  /// Save a new voice note
  Future<void> save(VoiceNote note) async {
    await _box.put(note.id, note);
    _notifyListeners();
    _boxChangeController.add(null);
  }

  /// Update an existing voice note
  Future<void> update(VoiceNote note) async {
    await _box.put(note.id, note);
    _notifyListeners();
    _boxChangeController.add(null);
  }

  /// Get a voice note by ID
  VoiceNote? get(String id) {
    return _box.get(id);
  }

  /// Get all voice notes, optionally including archived
  List<VoiceNote> getAll({bool includeArchived = false, bool includeConverted = false}) {
    var notes = _box.values.where((note) {
      if (!includeArchived && note.archived) return false;
      if (!includeConverted && note.convertedToJournal) return false;
      return true;
    }).toList();

    // Sort by most recent first
    notes.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return notes;
  }

  /// Get count of active (non-archived, non-converted) voice notes
  int get activeCount {
    return _box.values.where((note) => 
      !note.archived && !note.convertedToJournal
    ).length;
  }

  /// Delete a voice note permanently
  Future<void> delete(String id) async {
    await _box.delete(id);
    _notifyListeners();
    _boxChangeController.add(null);
  }

  /// Archive a voice note (soft delete)
  Future<void> archive(String id) async {
    final note = _box.get(id);
    if (note != null) {
      await _box.put(id, note.archive());
      _notifyListeners();
      _boxChangeController.add(null);
    }
  }

  /// Mark a voice note as converted to journal entry
  Future<void> markConverted(String id, String entryId) async {
    final note = _box.get(id);
    if (note != null) {
      await _box.put(id, note.markConverted(entryId));
      _notifyListeners();
      _boxChangeController.add(null);
    }
  }

  /// Add tags to a voice note
  Future<void> addTags(String id, List<String> newTags) async {
    final note = _box.get(id);
    if (note != null) {
      final updatedTags = {...note.tags, ...newTags}.toList();
      await _box.put(id, note.copyWith(tags: updatedTags));
      _notifyListeners();
      _boxChangeController.add(null);
    }
  }

  /// Remove a tag from a voice note
  Future<void> removeTag(String id, String tag) async {
    final note = _box.get(id);
    if (note != null) {
      final updatedTags = note.tags.where((t) => t != tag).toList();
      await _box.put(id, note.copyWith(tags: updatedTags));
      _notifyListeners();
      _boxChangeController.add(null);
    }
  }

  /// Search voice notes by transcription content
  List<VoiceNote> search(String query, {bool includeArchived = false}) {
    final lowerQuery = query.toLowerCase();
    return getAll(includeArchived: includeArchived).where((note) {
      return note.transcription.toLowerCase().contains(lowerQuery) ||
          note.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  /// Get voice notes from a specific date range
  List<VoiceNote> getByDateRange(DateTime start, DateTime end, {bool includeArchived = false}) {
    return getAll(includeArchived: includeArchived).where((note) {
      return note.timestamp.isAfter(start) && note.timestamp.isBefore(end);
    }).toList();
  }

  /// Get voice notes from today
  List<VoiceNote> getToday() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return getByDateRange(startOfDay, endOfDay);
  }

  /// Stream of all voice notes (reactive updates)
  Stream<List<VoiceNote>> watchAll({bool includeArchived = false}) {
    // Emit current state immediately, then listen for changes
    return _notesController.stream.map((_) => getAll(includeArchived: includeArchived));
  }

  /// Stream that emits when any change occurs (this instance or any other
  /// instance writing to the same Hive box, e.g. VoiceModeScreen save).
  Stream<List<VoiceNote>> watch() {
    // Start with current data
    Future.microtask(() => _notifyListeners());
    return Stream.multi((controller) {
      final sub1 = _notesController.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: () {},
      );
      final sub2 = _boxChangeController.stream.listen(
        (_) => controller.add(getAll()),
        onError: controller.addError,
        onDone: () {},
      );
      controller.onCancel = () {
        sub1.cancel();
        sub2.cancel();
      };
    });
  }

  void _notifyListeners() {
    _notesController.add(getAll());
  }

  /// Dispose of resources
  void dispose() {
    _notesController.close();
  }

  /// Delete all voice notes (use with caution)
  Future<void> deleteAll() async {
    await _box.clear();
    _notifyListeners();
    _boxChangeController.add(null);
  }

  /// Export all voice notes as a list of maps (for backup)
  List<Map<String, dynamic>> exportAll() {
    return _box.values.map((note) => {
      'id': note.id,
      'timestamp': note.timestamp.toIso8601String(),
      'transcription': note.transcription,
      'tags': note.tags,
      'archived': note.archived,
      'convertedToJournal': note.convertedToJournal,
      'convertedEntryId': note.convertedEntryId,
      'durationMs': note.durationMs,
    }).toList();
  }
}
