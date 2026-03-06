import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/chronicle_layer.dart';

/// Changelog entry for synthesis history tracking
class ChangelogEntry {
  final String id;
  final DateTime timestamp;
  final String userId;
  final ChronicleLayer layer;
  final String action; // 'synthesized', 'edited', 'deleted', 'error'
  final Map<String, dynamic> metadata;
  final String? error;

  const ChangelogEntry({
    required this.id,
    required this.timestamp,
    required this.userId,
    required this.layer,
    required this.action,
    required this.metadata,
    this.error,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'user_id': userId,
      'layer': layer.name,
      'action': action,
      'metadata': metadata,
      'error': error,
    };
  }

  factory ChangelogEntry.fromJson(Map<String, dynamic> json) {
    return ChangelogEntry(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      userId: json['user_id'] as String,
      layer: ChronicleLayerHelpers.fromJson(json['layer'] as String),
      action: json['action'] as String,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map),
      error: json['error'] as String?,
    );
  }
}

/// Repository for tracking synthesis history and changelog
class ChangelogRepository {
  static const String changelogDir = 'changelog';
  static const String changelogFile = 'changelog.json';

  /// Get the changelog file
  Future<File> _getChangelogFile() async {
    final appDir = await getApplicationDocumentsDirectory();
    final chronicleDir = Directory(path.join(appDir.path, 'chronicle', changelogDir));
    
    if (!await chronicleDir.exists()) {
      await chronicleDir.create(recursive: true);
    }
    
    return File(path.join(chronicleDir.path, changelogFile));
  }

  /// Load all changelog entries (supports JSONL: one JSON object per line).
  Future<List<ChangelogEntry>> getAllEntries() async {
    final file = await _getChangelogFile();
    
    if (!await file.exists()) {
      return [];
    }

    try {
      final content = await file.readAsString();
      final lines = content.split('\n').where((line) => line.trim().isNotEmpty);
      final entries = <ChangelogEntry>[];
      for (final line in lines) {
        try {
          final map = jsonDecode(line) as Map<String, dynamic>;
          entries.add(ChangelogEntry.fromJson(map));
        } catch (_) {
          // Skip malformed lines
        }
      }
      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return entries;
    } catch (e) {
      print('⚠️ ChangelogRepository: Failed to load changelog: $e');
      return [];
    }
  }

  /// Append imported changelog entries (e.g. from export changelog.jsonl). Preserves original ids and timestamps.
  Future<void> appendEntries(List<ChangelogEntry> entries) async {
    if (entries.isEmpty) return;
    final file = await _getChangelogFile();
    for (final entry in entries) {
      final line = '${jsonEncode(entry.toJson())}\n';
      await file.writeAsString(line, mode: FileMode.append);
    }
    print('📝 ChangelogRepository: Appended ${entries.length} imported entries');
  }

  /// Log a changelog entry
  Future<void> log({
    required String userId,
    required ChronicleLayer layer,
    required String action,
    required Map<String, dynamic> metadata,
    String? error,
  }) async {
    final entry = ChangelogEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      userId: userId,
      layer: layer,
      action: action,
      metadata: metadata,
      error: error,
    );

    final file = await _getChangelogFile();
    
    // Append to file (JSONL format - one JSON object per line)
    final line = '${jsonEncode(entry.toJson())}\n';
    await file.writeAsString(line, mode: FileMode.append);
    
    print('📝 ChangelogRepository: Logged $action for ${layer.name}');
  }

  /// Get last synthesis date for a layer
  Future<DateTime?> getLastSynthesis(String userId, ChronicleLayer layer) async {
    final entries = await getAllEntries();
    
    final synthesisEntries = entries
        .where((e) => 
            e.userId == userId &&
            e.layer == layer &&
            e.action == 'synthesized')
        .toList();

    if (synthesisEntries.isEmpty) {
      return null;
    }

    return synthesisEntries.first.timestamp;
  }

  /// Get synthesis history for a layer
  Future<List<ChangelogEntry>> getSynthesisHistory(
    String userId,
    ChronicleLayer layer,
  ) async {
    final entries = await getAllEntries();
    
    return entries
        .where((e) => 
            e.userId == userId &&
            e.layer == layer)
        .toList();
  }

  /// Log an error
  Future<void> logError({
    required String userId,
    required ChronicleLayer layer,
    required String error,
    Map<String, dynamic>? metadata,
  }) async {
    await log(
      userId: userId,
      layer: layer,
      action: 'error',
      metadata: metadata ?? {},
      error: error,
    );
  }
}
