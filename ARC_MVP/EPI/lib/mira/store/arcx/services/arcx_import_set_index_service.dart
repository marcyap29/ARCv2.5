/// Tracks which ARCX source files have already been imported so we can
/// "continue import from folder" and skip or diff against them.
library arcx_import_set_index_service;

import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// One recorded import: source file path + mtime + what we imported.
class ImportSetRecord {
  final String sourcePath;
  final int lastModifiedMs;
  final List<String> importedEntryIds;
  final List<String> importedChatIds;
  final String importedAtIso;

  const ImportSetRecord({
    required this.sourcePath,
    required this.lastModifiedMs,
    this.importedEntryIds = const [],
    this.importedChatIds = const [],
    required this.importedAtIso,
  });

  Map<String, dynamic> toJson() => {
        'source_path': sourcePath,
        'last_modified_ms': lastModifiedMs,
        'imported_entry_ids': importedEntryIds,
        'imported_chat_ids': importedChatIds,
        'imported_at_iso': importedAtIso,
      };

  static ImportSetRecord? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final p = json['source_path'] as String?;
    final m = json['last_modified_ms'] as int?;
    final at = json['imported_at_iso'] as String?;
    if (p == null || m == null || at == null) return null;
    return ImportSetRecord(
      sourcePath: p,
      lastModifiedMs: m,
      importedEntryIds: (json['imported_entry_ids'] as List<dynamic>?)?.cast<String>() ?? const [],
      importedChatIds: (json['imported_chat_ids'] as List<dynamic>?)?.cast<String>() ?? const [],
      importedAtIso: at,
    );
  }

  bool matchesFile(File file) {
    try {
      final norm = path.normalize(file.path);
      if (path.normalize(sourcePath) != norm) return false;
      final stat = file.statSync();
      return stat.modified.millisecondsSinceEpoch == lastModifiedMs;
    } catch (_) {
      return false;
    }
  }
}

class ArcxImportSetIndexService {
  ArcxImportSetIndexService._();
  static final ArcxImportSetIndexService instance = ArcxImportSetIndexService._();

  static const _kIndexFileName = 'arcx_import_set_index.json';
  static const _kMaxRecords = 500;

  List<ImportSetRecord> _cache = [];
  bool _loaded = false;

  Future<File> _indexFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final checkpointDir = path.join(dir.path, 'arcx_checkpoints');
    await Directory(checkpointDir).create(recursive: true);
    return File(path.join(checkpointDir, _kIndexFileName));
  }

  Future<List<ImportSetRecord>> _load() async {
    if (_loaded) return _cache;
    final file = await _indexFile();
    if (!await file.exists()) {
      _cache = [];
      _loaded = true;
      return _cache;
    }
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>?;
      final list = json?['processed_sources'] as List<dynamic>? ?? [];
      _cache = list
          .map((e) => ImportSetRecord.fromJson(e as Map<String, dynamic>))
          .whereType<ImportSetRecord>()
          .toList();
      _loaded = true;
      return _cache;
    } catch (_) {
      _cache = [];
      _loaded = true;
      return _cache;
    }
  }

  Future<void> _save() async {
    final file = await _indexFile();
    final list = _cache.take(_kMaxRecords).map((e) => e.toJson()).toList();
    await file.writeAsString(jsonEncode({'processed_sources': list}));
  }

  /// Record a successful import from this source file.
  Future<void> recordImport({
    required String sourcePath,
    required int lastModifiedMs,
    required Set<String> importedEntryIds,
    required Set<String> importedChatIds,
  }) async {
    await _load();
    final record = ImportSetRecord(
      sourcePath: sourcePath,
      lastModifiedMs: lastModifiedMs,
      importedEntryIds: importedEntryIds.toList(),
      importedChatIds: importedChatIds.toList(),
      importedAtIso: DateTime.now().toUtc().toIso8601String(),
    );
    _cache.removeWhere((r) =>
        path.normalize(r.sourcePath) == path.normalize(sourcePath) &&
        r.lastModifiedMs == lastModifiedMs);
    _cache.insert(0, record);
    await _save();
  }

  /// True if we have already imported from this file (same path + mtime).
  Future<bool> hasImported(File file) async {
    final records = await _load();
    return records.any((r) => r.matchesFile(file));
  }

  /// List .arcx files in [folder] and return which are not yet in the index.
  Future<Map<String, dynamic>> getImportSetDiffPreview(Directory folder) async {
    if (!await folder.exists()) {
      return {
        'filesInFolder': 0,
        'filesAlreadyImported': 0,
        'filesToImport': 0,
        'filePaths': <String>[],
        'toImportPaths': <String>[],
      };
    }
    final records = await _load();
    final arcxFiles = <File>[];
    await for (final e in folder.list()) {
      if (e is File && e.path.toLowerCase().endsWith('.arcx')) {
        arcxFiles.add(e);
      }
    }
    final toImport = <String>[];
    for (final f in arcxFiles) {
      final already = records.any((r) => r.matchesFile(f));
      if (!already) toImport.add(f.path);
    }
    return {
      'filesInFolder': arcxFiles.length,
      'filesAlreadyImported': arcxFiles.length - toImport.length,
      'filesToImport': toImport.length,
      'filePaths': arcxFiles.map((f) => f.path).toList(),
      'toImportPaths': toImport,
    };
  }

  /// Clear all records (e.g. for testing or "forget all").
  Future<void> clear() async {
    _cache = [];
    _loaded = true;
    final file = await _indexFile();
    if (await file.exists()) await file.delete();
  }
}
