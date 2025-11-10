import '../core/journal_capture_cubit.dart';
import '../core/journal_repository.dart';
import '../../models/journal_entry_model.dart';
import 'package:uuid/uuid.dart';

class JournalManager {
  final JournalRepository _repository = JournalRepository();
  final JournalCaptureCubit? _captureCubit;
  final Uuid _uuid = const Uuid();

  JournalManager({JournalCaptureCubit? captureCubit}) : _captureCubit = captureCubit;

  /// Create a new journal entry
  Future<String> createEntry(String text) async {
    try {
      final entryId = _uuid.v4();
      final now = DateTime.now();
      
      // If we have a capture cubit, use it to save
      if (_captureCubit != null) {
        // Use the cubit's save method
        _captureCubit!.saveEntryWithKeywords(
          content: text,
          mood: 'neutral',
          selectedKeywords: [],
        );
        return entryId;
      } else {
        // Direct repository save
        final entry = JournalEntry(
          id: entryId,
          title: '', // Empty title, will be auto-generated or user can set
          content: text,
          createdAt: now,
          updatedAt: now,
          tags: const [],
          mood: 'neutral',
        );
        await _repository.createJournalEntry(entry);
        return entryId;
      }
    } catch (e) {
      print('Error creating journal entry: $e');
      rethrow;
    }
  }

  /// Append text to today's journal entry
  Future<void> appendToToday(String text) async {
    await appendToDate(DateTime.now(), text);
  }

  /// Append text to a specific date's journal entry
  Future<void> appendToDate(DateTime date, String text) async {
    try {
      // Get all entries and filter by date
      final allEntries = _repository.getAllJournalEntries();
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final entries = allEntries.where((entry) {
        return entry.createdAt.isAfter(startOfDay) && entry.createdAt.isBefore(endOfDay);
      }).toList();

      if (entries.isNotEmpty) {
        // Append to first entry of the day
        final entry = entries.first;
        final updatedText = '${entry.content}\n\n$text';
        final updatedEntry = entry.copyWith(
          content: updatedText,
          updatedAt: DateTime.now(),
        );
        await _repository.updateJournalEntry(updatedEntry);
      } else {
        // Create new entry if none exists
        await createEntry(text);
      }
    } catch (e) {
      print('Error appending to journal: $e');
      rethrow;
    }
  }

  /// Summarize journal entries
  Future<String> summarize({String? query, DateTime? startDate, DateTime? endDate}) async {
    try {
      final start = startDate ?? DateTime.now().subtract(const Duration(days: 7));
      final end = endDate ?? DateTime.now();

      // Get all entries and filter by date range
      final allEntries = _repository.getAllJournalEntries();
      final entries = allEntries.where((entry) {
        return entry.createdAt.isAfter(start) && entry.createdAt.isBefore(end);
      }).toList();
      
      if (entries.isEmpty) {
        return "You don't have any journal entries in this time period.";
      }

      // Simple summary for now - can be enhanced with LLM
      final totalEntries = entries.length;
      final totalWords = entries.fold<int>(
        0,
        (sum, entry) => sum + entry.content.split(' ').length,
      );

      return "You have $totalEntries journal entries with approximately $totalWords words total.";
    } catch (e) {
      print('Error summarizing journal: $e');
      return "I couldn't summarize your journal entries right now.";
    }
  }
}

