/// Export History Service
/// 
/// Tracks export history for incremental backups.
/// Stores last export date, exported entry/chat/media IDs, and media hashes
/// for deduplication across exports.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a single export record
class ExportRecord {
  final String exportId;
  final DateTime exportedAt;
  final String? exportPath;
  final Set<String> entryIds;
  final Set<String> chatIds;
  final Set<String> mediaHashes; // SHA-256 hashes of exported media
  final int entriesCount;
  final int chatsCount;
  final int mediaCount;
  final int archiveSizeBytes;
  final bool isFullBackup;
  
  ExportRecord({
    required this.exportId,
    required this.exportedAt,
    this.exportPath,
    required this.entryIds,
    required this.chatIds,
    required this.mediaHashes,
    required this.entriesCount,
    required this.chatsCount,
    required this.mediaCount,
    required this.archiveSizeBytes,
    required this.isFullBackup,
  });
  
  Map<String, dynamic> toJson() => {
    'exportId': exportId,
    'exportedAt': exportedAt.toIso8601String(),
    'exportPath': exportPath,
    'entryIds': entryIds.toList(),
    'chatIds': chatIds.toList(),
    'mediaHashes': mediaHashes.toList(),
    'entriesCount': entriesCount,
    'chatsCount': chatsCount,
    'mediaCount': mediaCount,
    'archiveSizeBytes': archiveSizeBytes,
    'isFullBackup': isFullBackup,
  };
  
  factory ExportRecord.fromJson(Map<String, dynamic> json) => ExportRecord(
    exportId: json['exportId'] as String,
    exportedAt: DateTime.parse(json['exportedAt'] as String),
    exportPath: json['exportPath'] as String?,
    entryIds: Set<String>.from(json['entryIds'] as List? ?? []),
    chatIds: Set<String>.from(json['chatIds'] as List? ?? []),
    mediaHashes: Set<String>.from(json['mediaHashes'] as List? ?? []),
    entriesCount: json['entriesCount'] as int? ?? 0,
    chatsCount: json['chatsCount'] as int? ?? 0,
    mediaCount: json['mediaCount'] as int? ?? 0,
    archiveSizeBytes: json['archiveSizeBytes'] as int? ?? 0,
    isFullBackup: json['isFullBackup'] as bool? ?? true,
  );
}

/// Aggregated export history state
class ExportHistoryState {
  final DateTime? lastExportDate;
  final DateTime? lastFullBackupDate;
  final Set<String> allExportedEntryIds;
  final Set<String> allExportedChatIds;
  final Set<String> allExportedMediaHashes;
  final int totalExports;
  final List<ExportRecord> recentExports; // Last 10 exports for reference
  
  ExportHistoryState({
    this.lastExportDate,
    this.lastFullBackupDate,
    required this.allExportedEntryIds,
    required this.allExportedChatIds,
    required this.allExportedMediaHashes,
    required this.totalExports,
    required this.recentExports,
  });
  
  factory ExportHistoryState.empty() => ExportHistoryState(
    allExportedEntryIds: {},
    allExportedChatIds: {},
    allExportedMediaHashes: {},
    totalExports: 0,
    recentExports: [],
  );
  
  Map<String, dynamic> toJson() => {
    'lastExportDate': lastExportDate?.toIso8601String(),
    'lastFullBackupDate': lastFullBackupDate?.toIso8601String(),
    'allExportedEntryIds': allExportedEntryIds.toList(),
    'allExportedChatIds': allExportedChatIds.toList(),
    'allExportedMediaHashes': allExportedMediaHashes.toList(),
    'totalExports': totalExports,
    'recentExports': recentExports.map((e) => e.toJson()).toList(),
  };
  
  factory ExportHistoryState.fromJson(Map<String, dynamic> json) => ExportHistoryState(
    lastExportDate: json['lastExportDate'] != null 
        ? DateTime.parse(json['lastExportDate'] as String) 
        : null,
    lastFullBackupDate: json['lastFullBackupDate'] != null 
        ? DateTime.parse(json['lastFullBackupDate'] as String) 
        : null,
    allExportedEntryIds: Set<String>.from(json['allExportedEntryIds'] as List? ?? []),
    allExportedChatIds: Set<String>.from(json['allExportedChatIds'] as List? ?? []),
    allExportedMediaHashes: Set<String>.from(json['allExportedMediaHashes'] as List? ?? []),
    totalExports: json['totalExports'] as int? ?? 0,
    recentExports: (json['recentExports'] as List? ?? [])
        .map((e) => ExportRecord.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// Service to manage export history
class ExportHistoryService {
  static final ExportHistoryService _instance = ExportHistoryService._internal();
  factory ExportHistoryService() => _instance;
  ExportHistoryService._internal();
  
  static ExportHistoryService get instance => _instance;
  
  static const String _historyKey = 'arcx_export_history_v1';
  static const int _maxRecentExports = 10;
  
  ExportHistoryState? _cachedState;
  
  /// Load export history from SharedPreferences
  Future<ExportHistoryState> getHistory() async {
    if (_cachedState != null) return _cachedState!;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_historyKey);
      
      if (historyJson == null) {
        _cachedState = ExportHistoryState.empty();
        return _cachedState!;
      }
      
      final json = jsonDecode(historyJson) as Map<String, dynamic>;
      _cachedState = ExportHistoryState.fromJson(json);
      return _cachedState!;
    } catch (e) {
      debugPrint('ExportHistoryService: Error loading history: $e');
      _cachedState = ExportHistoryState.empty();
      return _cachedState!;
    }
  }
  
  /// Record a new export
  Future<void> recordExport(ExportRecord record) async {
    try {
      final currentState = await getHistory();
      
      // Update aggregated state
      final newEntryIds = {...currentState.allExportedEntryIds, ...record.entryIds};
      final newChatIds = {...currentState.allExportedChatIds, ...record.chatIds};
      final newMediaHashes = {...currentState.allExportedMediaHashes, ...record.mediaHashes};
      
      // Keep only last N exports
      final recentExports = [record, ...currentState.recentExports];
      if (recentExports.length > _maxRecentExports) {
        recentExports.removeRange(_maxRecentExports, recentExports.length);
      }
      
      final newState = ExportHistoryState(
        lastExportDate: record.exportedAt,
        lastFullBackupDate: record.isFullBackup 
            ? record.exportedAt 
            : currentState.lastFullBackupDate,
        allExportedEntryIds: newEntryIds,
        allExportedChatIds: newChatIds,
        allExportedMediaHashes: newMediaHashes,
        totalExports: currentState.totalExports + 1,
        recentExports: recentExports,
      );
      
      await _saveHistory(newState);
      _cachedState = newState;
      
      debugPrint('ExportHistoryService: Recorded export ${record.exportId}');
      debugPrint('  Entries: ${record.entriesCount}, Chats: ${record.chatsCount}, Media: ${record.mediaCount}');
      debugPrint('  Total exports: ${newState.totalExports}');
    } catch (e) {
      debugPrint('ExportHistoryService: Error recording export: $e');
      rethrow;
    }
  }
  
  /// Get entries that haven't been exported yet
  Future<Set<String>> getUnexportedEntryIds(List<String> allEntryIds) async {
    final history = await getHistory();
    return allEntryIds.where((id) => !history.allExportedEntryIds.contains(id)).toSet();
  }
  
  /// Get chats that haven't been exported yet
  Future<Set<String>> getUnexportedChatIds(List<String> allChatIds) async {
    final history = await getHistory();
    return allChatIds.where((id) => !history.allExportedChatIds.contains(id)).toSet();
  }
  
  /// Check if a media file (by hash) has been exported
  Future<bool> isMediaExported(String mediaHash) async {
    final history = await getHistory();
    return history.allExportedMediaHashes.contains(mediaHash);
  }
  
  /// Get entries modified since last export
  /// This requires comparing entry.updatedAt with lastExportDate
  Future<DateTime?> getLastExportDate() async {
    final history = await getHistory();
    return history.lastExportDate;
  }
  
  /// Get last full backup date
  Future<DateTime?> getLastFullBackupDate() async {
    final history = await getHistory();
    return history.lastFullBackupDate;
  }
  
  /// Get summary for UI display
  Future<Map<String, dynamic>> getSummary() async {
    final history = await getHistory();
    return {
      'lastExportDate': history.lastExportDate,
      'lastFullBackupDate': history.lastFullBackupDate,
      'totalExports': history.totalExports,
      'entriesExported': history.allExportedEntryIds.length,
      'chatsExported': history.allExportedChatIds.length,
      'mediaExported': history.allExportedMediaHashes.length,
      'recentExports': history.recentExports.take(5).toList(),
    };
  }
  
  /// Clear all export history (use with caution)
  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
      _cachedState = ExportHistoryState.empty();
      debugPrint('ExportHistoryService: History cleared');
    } catch (e) {
      debugPrint('ExportHistoryService: Error clearing history: $e');
      rethrow;
    }
  }
  
  /// Save history to SharedPreferences
  Future<void> _saveHistory(ExportHistoryState state) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(state.toJson());
    await prefs.setString(_historyKey, json);
  }
}

