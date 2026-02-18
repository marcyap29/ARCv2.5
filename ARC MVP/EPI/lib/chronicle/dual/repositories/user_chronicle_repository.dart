// lib/chronicle/dual/repositories/user_chronicle_repository.dart
//
// USER'S CHRONICLE REPOSITORY - SACRED
//
// CRITICAL: This repository ONLY accepts user-authored content or user-approved
// annotations. The system CANNOT write here without explicit user action.

import 'dart:convert';
import '../models/chronicle_models.dart';
import '../storage/chronicle_storage.dart';

/// Thrown when code attempts to write non-user content to User Chronicle.
class SacredChronicleViolation implements Exception {
  final String message;
  SacredChronicleViolation(this.message);
  @override
  String toString() => 'ARCHITECTURAL VIOLATION: $message';
}

/// User Chronicle Repository.
/// Enforces: entries must be user-authored; annotations must have explicit user approval.
class UserChronicleRepository {
  UserChronicleRepository([ChronicleStorage? storage])
      : _storage = storage ?? ChronicleStorage();

  final ChronicleStorage _storage;

  static const String _layer0Entries = 'layer0/entries';
  static const String _layer0Annotations = 'layer0/annotations';

  /// Add user-authored entry to timeline.
  /// VALIDATION: Must be user-authored; no synthetic type.
  Future<void> addEntry(String userId, UserEntry entry) async {
    if (entry.authoredBy != 'user') {
      throw SacredChronicleViolation(
        'Only user-authored entries allowed in User Chronicle',
      );
    }
    // No 'synthetic' type in our enum - we reject any attempt to add non-user types
    final subPath = '$_layer0Entries/${entry.id}.json';
    await _storage.saveUserChronicle(userId, subPath, entry.toJson());
    print('[UserChronicle] Entry added: ${entry.id} (user-authored)');
  }

  /// Add user-approved annotation to timeline.
  /// VALIDATION: Must have explicit user approval and approvedAt.
  Future<void> addAnnotation(String userId, UserAnnotation annotation) async {
    if (!annotation.provenance.userApproved) {
      throw SacredChronicleViolation(
        'Annotations require explicit user approval',
      );
    }
    final subPath = '$_layer0Annotations/${annotation.id}.json';
    await _storage.saveUserChronicle(userId, subPath, annotation.toJson());
    print('[UserChronicle] Annotation added: ${annotation.id} (user-approved)');
  }

  /// Load all Layer 0 entries for [userId].
  Future<List<UserEntry>> loadEntries(String userId) async {
    final dir = await _storage.getUserChronicleDir(userId, _layer0Entries);
    final files = await _storage.listJsonFiles(dir);
    final entries = <UserEntry>[];
    for (final file in files) {
      final content = await file.readAsString();
      final json = _tryDecode(content);
      if (json != null) {
        try {
          entries.add(UserEntry.fromJson(json));
        } catch (_) {}
      }
    }
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  /// Load all Layer 0 annotations for [userId].
  Future<List<UserAnnotation>> loadAnnotations(String userId) async {
    final dir = await _storage.getUserChronicleDir(userId, _layer0Annotations);
    final files = await _storage.listJsonFiles(dir);
    final annotations = <UserAnnotation>[];
    for (final file in files) {
      final content = await file.readAsString();
      final json = _tryDecode(content);
      if (json != null) {
        try {
          annotations.add(UserAnnotation.fromJson(json));
        } catch (_) {}
      }
    }
    annotations.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return annotations;
  }

  /// Query Layer 0 entries and annotations, optionally filtered by query relevance.
  /// [query] used for simple text filter; for semantic search, callers can use separate service.
  Future<UserChronicleLayer0Result> queryLayer0(String userId, String query) async {
    final entries = await loadEntries(userId);
    final annotations = await loadAnnotations(userId);
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return UserChronicleLayer0Result(entries: entries, annotations: annotations);
    }
    final relevantEntries = entries.where((e) =>
        e.content.toLowerCase().contains(q) ||
        (e.extractedKeywords?.any((k) => k.toLowerCase().contains(q)) ?? false) ||
        (e.thematicTags?.any((t) => t.toLowerCase().contains(q)) ?? false)).toList();
    final relevantAnnotations = annotations
        .where((a) => a.content.toLowerCase().contains(q))
        .toList();
    return UserChronicleLayer0Result(
      entries: relevantEntries,
      annotations: relevantAnnotations,
    );
  }

  /// Delete entry (user action only).
  Future<void> deleteEntry(String userId, String entryId) async {
    await _storage.deleteUserChronicle(userId, '$_layer0Entries/$entryId.json');
    print('[UserChronicle] Entry deleted by user: $entryId');
  }

  /// Delete annotation (user action only).
  /// Does NOT delete the originating gap-fill event in LUMARA Chronicle.
  Future<void> deleteAnnotation(String userId, String annotationId) async {
    await _storage.deleteUserChronicle(
      userId,
      '$_layer0Annotations/$annotationId.json',
    );
    print('[UserChronicle] Annotation deleted by user: $annotationId');
    print(
      '[UserChronicle] Note: Originating gap-fill event preserved in LUMARA Chronicle',
    );
  }

  Map<String, dynamic>? _tryDecode(String content) {
    try {
      return jsonDecode(content) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }
}

/// Result of querying User Chronicle Layer 0.
class UserChronicleLayer0Result {
  final List<UserEntry> entries;
  final List<UserAnnotation> annotations;

  UserChronicleLayer0Result({
    required this.entries,
    required this.annotations,
  });
}
