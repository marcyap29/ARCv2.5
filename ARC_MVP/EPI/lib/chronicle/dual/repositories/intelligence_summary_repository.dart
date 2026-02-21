// lib/chronicle/dual/repositories/intelligence_summary_repository.dart
//
// Persistence for Intelligence Summary (Layer 3). Stored under LUMARA CHRONICLE.

import 'dart:convert';
import '../models/intelligence_summary_models.dart';
import '../storage/chronicle_storage.dart';

class IntelligenceSummaryRepository {
  IntelligenceSummaryRepository([ChronicleStorage? storage])
      : _storage = storage ?? ChronicleStorage();

  final ChronicleStorage _storage;

  static const String _latestFile = 'intelligence_summary/latest.json';
  static const String _staleFile = 'intelligence_summary/stale.json';
  static const String _versionsDir = 'intelligence_summary/versions';

  Map<String, dynamic>? _tryDecode(String raw) {
    try {
      return jsonDecode(raw) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<IntelligenceSummary?> getLatest(String userId) async {
    final json = await _storage.loadLumaraChronicle(userId, _latestFile);
    if (json == null) return null;
    try {
      return IntelligenceSummary.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<IntelligenceSummaryVersion?> getVersion(
      String userId, int version) async {
    final path = '$_versionsDir/$version.json';
    final json = await _storage.loadLumaraChronicle(userId, path);
    if (json == null) return null;
    try {
      return IntelligenceSummaryVersion.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<List<IntelligenceSummaryVersion>> getVersionHistory(
      String userId) async {
    final dir = await _storage.getLumaraChronicleDir(userId, _versionsDir);
    final files = await _storage.listJsonFiles(dir);
    final list = <IntelligenceSummaryVersion>[];
    for (final file in files) {
      final json = _tryDecode(await file.readAsString());
      if (json != null) {
        try {
          list.add(IntelligenceSummaryVersion.fromJson(json));
        } catch (_) {}
      }
    }
    list.sort((a, b) => b.version.compareTo(a.version));
    return list;
  }

  Future<void> save(IntelligenceSummary summary) async {
    await _storage.saveLumaraChronicle(
        summary.userId, _latestFile, summary.toJson());
  }

  /// Mark summary as stale (needs regeneration after LUMARA CHRONICLE update).
  Future<void> markStale(String userId) async {
    await _storage.saveLumaraChronicle(userId, _staleFile, {
      'stale': true,
      'marked_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Clear stale flag (after successful generation).
  Future<void> clearStale(String userId) async {
    await _storage.saveLumaraChronicle(userId, _staleFile, {
      'stale': false,
      'cleared_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<bool> isStale(String userId) async {
    final json = await _storage.loadLumaraChronicle(userId, _staleFile);
    if (json == null) return true;
    return json['stale'] as bool? ?? true;
  }

  /// Archive a version for history.
  Future<void> archiveVersion(IntelligenceSummaryVersion v) async {
    final path = '$_versionsDir/${v.version}.json';
    await _storage.saveLumaraChronicle(v.userId, path, v.toJson());
  }
}
