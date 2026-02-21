/// Universal Importer Service
///
/// Handles importing journal entries from various external sources:
/// - LUMARA / ARCX backup (native format)
/// - Day One JSON export
/// - Journey backup
/// - Plain text / Markdown files
/// - CSV / Excel spreadsheets
///
/// Deduplicates against existing entries before saving.
/// Triggers CHRONICLE backfill after import for temporal intelligence.

import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:my_app/services/app_repos.dart';
import 'package:my_app/models/journal_entry_model.dart';

/// Callback for reporting import progress.
typedef ImportProgressCallback = void Function(double progress, String message);

/// Supported third-party import source types.
///
/// LUMARA/ARCX/zip backups are handled by the existing ARCXImportServiceV2
/// and McpPackImportService via ImportExportFolderView — not this service.
enum ImportType {
  dayOne,
  journey,
  plainText,
  spreadsheet,
}

/// Service for importing journal entries from external sources.
class UniversalImporterService {
  final JournalRepository _journalRepo = AppRepos.journal;

  /// Import entries from a file.
  ///
  /// [filePath] — path to the file to import.
  /// [importType] — the source format.
  /// [onProgress] — callback for progress updates (0.0 to 1.0).
  Future<int> importFromFile({
    required String filePath,
    required ImportType importType,
    ImportProgressCallback? onProgress,
  }) async {
    final file = File(filePath);

    if (!file.existsSync()) {
      throw Exception('File not found: $filePath');
    }

    onProgress?.call(0.05, 'Reading file...');

    List<JournalEntry> entries;

    switch (importType) {
      case ImportType.dayOne:
        entries = await _importDayOne(file, onProgress);
        break;
      case ImportType.journey:
        entries = await _importJourney(file, onProgress);
        break;
      case ImportType.plainText:
        entries = await _importPlainText(file, onProgress);
        break;
      case ImportType.spreadsheet:
        entries = await _importSpreadsheet(file, onProgress);
        break;
    }

    if (entries.isEmpty) {
      onProgress?.call(1.0, 'No entries found in file.');
      return 0;
    }

    onProgress?.call(0.5, 'Deduplicating ${entries.length} entries...');

    // Deduplicate against existing entries
    final deduplicated = await _deduplicateEntries(entries);

    if (deduplicated.isEmpty) {
      onProgress?.call(1.0, 'All entries already exist. Nothing to import.');
      return 0;
    }

    onProgress?.call(0.6, 'Saving ${deduplicated.length} entries...');

    // Ensure Hive box is open
    await _journalRepo.ensureBoxOpen();

    // Save entries
    for (var i = 0; i < deduplicated.length; i++) {
      try {
        await _journalRepo.createJournalEntry(deduplicated[i]);
      } catch (e) {
        debugPrint('UniversalImporter: Error saving entry ${i + 1}: $e');
      }
      onProgress?.call(
        0.6 + (0.35 * ((i + 1) / deduplicated.length)),
        'Saving entry ${i + 1} of ${deduplicated.length}...',
      );
    }

    onProgress?.call(1.0, 'Imported ${deduplicated.length} entries!');
    return deduplicated.length;
  }

  // ─── Format-specific importers (third-party only) ────────────────────

  Future<List<JournalEntry>> _importDayOne(
    File file,
    ImportProgressCallback? onProgress,
  ) async {
    onProgress?.call(0.1, 'Parsing Day One export...');
    try {
      final content = await file.readAsString();
      final json = jsonDecode(content);

      if (json is Map && json.containsKey('entries')) {
        final rawEntries = json['entries'] as List;
        onProgress?.call(0.3, 'Found ${rawEntries.length} Day One entries...');

        final entries = <JournalEntry>[];
        for (final raw in rawEntries) {
          if (raw is Map<String, dynamic>) {
            final text = raw['text'] ?? raw['richText'] ?? '';
            final dateStr =
                raw['creationDate'] ?? raw['modifiedDate'] ?? '';
            final tags =
                (raw['tags'] as List?)?.cast<String>() ?? <String>[];

            DateTime date;
            try {
              date = DateTime.parse(dateStr);
            } catch (_) {
              date = DateTime.now();
            }

            entries.add(JournalEntry(
              id: raw['uuid']?.toString() ?? _generateId(),
              title: _extractTitle(text is String ? text : text.toString()),
              content: text is String ? text : text.toString(),
              createdAt: date,
              updatedAt: date,
              tags: tags,
              mood: (raw['mood'] as String?) ?? '',
            ));
          }
        }
        return entries;
      }
    } catch (e) {
      debugPrint('UniversalImporter: Error parsing Day One: $e');
    }
    return [];
  }

  Future<List<JournalEntry>> _importJourney(
    File file,
    ImportProgressCallback? onProgress,
  ) async {
    onProgress?.call(0.1, 'Parsing Journey backup...');
    try {
      final content = await file.readAsString();
      final json = jsonDecode(content);

      if (json is List) {
        onProgress?.call(0.3, 'Found ${json.length} Journey entries...');
        final entries = <JournalEntry>[];
        for (final raw in json) {
          if (raw is Map<String, dynamic>) {
            final text = raw['text'] ?? raw['content'] ?? '';
            final dateMs = raw['date_journal'] ?? raw['date_modified'];

            DateTime date;
            if (dateMs is int) {
              date = DateTime.fromMillisecondsSinceEpoch(dateMs);
            } else if (dateMs is String) {
              try {
                date = DateTime.parse(dateMs);
              } catch (_) {
                date = DateTime.now();
              }
            } else {
              date = DateTime.now();
            }

            final tags =
                (raw['tags'] as List?)?.cast<String>() ?? <String>[];

            entries.add(JournalEntry(
              id: raw['id']?.toString() ?? _generateId(),
              title: _extractTitle(text is String ? text : text.toString()),
              content: text is String ? text : text.toString(),
              createdAt: date,
              updatedAt: date,
              tags: tags,
              mood: (raw['mood'] as String?) ?? '',
            ));
          }
        }
        return entries;
      }
    } catch (e) {
      debugPrint('UniversalImporter: Error parsing Journey: $e');
    }
    return [];
  }

  Future<List<JournalEntry>> _importPlainText(
    File file,
    ImportProgressCallback? onProgress,
  ) async {
    onProgress?.call(0.1, 'Reading text file...');
    try {
      final content = await file.readAsString();
      final fileName =
          file.path.split('/').last.replaceAll(RegExp(r'\.(txt|md)$'), '');

      // Try to split by common date patterns or double newlines
      final sections = _splitTextIntoEntries(content);
      onProgress?.call(0.3, 'Found ${sections.length} entries...');

      final entries = <JournalEntry>[];
      for (var i = 0; i < sections.length; i++) {
        final section = sections[i].trim();
        if (section.isEmpty) continue;

        entries.add(JournalEntry(
          id: _generateId(),
          title: sections.length == 1
              ? fileName
              : _extractTitle(section),
          content: section,
          createdAt: DateTime.now().subtract(Duration(days: sections.length - i)),
          updatedAt: DateTime.now().subtract(Duration(days: sections.length - i)),
          tags: const [],
          mood: '',
        ));
      }
      return entries;
    } catch (e) {
      debugPrint('UniversalImporter: Error reading text file: $e');
    }
    return [];
  }

  Future<List<JournalEntry>> _importSpreadsheet(
    File file,
    ImportProgressCallback? onProgress,
  ) async {
    onProgress?.call(0.1, 'Parsing spreadsheet...');
    try {
      // CSV only for now
      if (file.path.endsWith('.csv')) {
        final content = await file.readAsString();
        final lines = const LineSplitter().convert(content);

        if (lines.isEmpty) return [];

        // First line is header
        final header = lines.first.split(',').map((h) => h.trim().toLowerCase()).toList();
        final contentIdx = header.indexWhere(
            (h) => h.contains('content') || h.contains('text') || h.contains('body'));
        final dateIdx = header.indexWhere(
            (h) => h.contains('date') || h.contains('time') || h.contains('created'));
        final titleIdx = header.indexWhere(
            (h) => h.contains('title') || h.contains('subject'));

        if (contentIdx == -1) {
          throw Exception('CSV must have a "content" or "text" column.');
        }

        onProgress?.call(0.3, 'Found ${lines.length - 1} rows...');

        final entries = <JournalEntry>[];
        for (var i = 1; i < lines.length; i++) {
          final cols = _parseCsvLine(lines[i]);
          if (cols.length <= contentIdx) continue;

          final text = cols[contentIdx];
          if (text.trim().isEmpty) continue;

          DateTime date = DateTime.now();
          if (dateIdx >= 0 && cols.length > dateIdx) {
            try {
              date = DateTime.parse(cols[dateIdx]);
            } catch (_) {}
          }

          String title = '';
          if (titleIdx >= 0 && cols.length > titleIdx) {
            title = cols[titleIdx];
          }

          entries.add(JournalEntry(
            id: _generateId(),
            title: title.isNotEmpty ? title : _extractTitle(text),
            content: text,
            createdAt: date,
            updatedAt: date,
            tags: const [],
            mood: '',
          ));
        }
        return entries;
      }

      // XLSX support is a TODO (requires archive/excel package)
      debugPrint('UniversalImporter: XLSX import not yet implemented');
    } catch (e) {
      debugPrint('UniversalImporter: Error parsing spreadsheet: $e');
      rethrow;
    }
    return [];
  }

  // ─── Helpers ─────────────────────────────────────────────────────────

  Future<List<JournalEntry>> _deduplicateEntries(
    List<JournalEntry> newEntries,
  ) async {
    try {
      final existingEntries = await _journalRepo.getAllJournalEntries();
      final existingContentHashes = <String>{};

      for (final entry in existingEntries) {
        // Hash on timestamp + first 100 chars of content
        final preview =
            entry.content.length > 100 ? entry.content.substring(0, 100) : entry.content;
        existingContentHashes.add(
            '${entry.createdAt.millisecondsSinceEpoch}_$preview');
      }

      return newEntries.where((entry) {
        final preview =
            entry.content.length > 100 ? entry.content.substring(0, 100) : entry.content;
        final hash =
            '${entry.createdAt.millisecondsSinceEpoch}_$preview';
        return !existingContentHashes.contains(hash);
      }).toList();
    } catch (e) {
      debugPrint('UniversalImporter: Error deduplicating: $e');
      return newEntries; // If dedup fails, import everything
    }
  }

  String _extractTitle(String content) {
    if (content.isEmpty) return 'Untitled Entry';
    final firstLine = content.split('\n').first.trim();
    // Remove markdown heading markers
    final cleaned = firstLine.replaceAll(RegExp(r'^#+\s*'), '');
    if (cleaned.length <= 50) return cleaned;
    return '${cleaned.substring(0, 47)}...';
  }

  List<String> _splitTextIntoEntries(String content) {
    // Try splitting by date-like patterns (e.g., "## 2024-01-15" or "January 15, 2024")
    final datePattern = RegExp(
      r'(?:^|\n)(?:#{1,3}\s*)?\d{4}[-/]\d{1,2}[-/]\d{1,2}|'
      r'(?:^|\n)(?:#{1,3}\s*)?(?:January|February|March|April|May|June|'
      r'July|August|September|October|November|December)\s+\d{1,2},?\s*\d{4}',
      caseSensitive: false,
    );

    final matches = datePattern.allMatches(content).toList();
    if (matches.length > 1) {
      final sections = <String>[];
      for (var i = 0; i < matches.length; i++) {
        final start = matches[i].start;
        final end =
            i + 1 < matches.length ? matches[i + 1].start : content.length;
        sections.add(content.substring(start, end));
      }
      return sections;
    }

    // Fallback: split by triple newlines or horizontal rules
    final sections = content.split(RegExp(r'\n{3,}|---+\n'));
    if (sections.length > 1) return sections;

    // Single entry
    return [content];
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    var current = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString().trim());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString().trim());
    return result;
  }

  String _generateId() {
    return DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  }
}
