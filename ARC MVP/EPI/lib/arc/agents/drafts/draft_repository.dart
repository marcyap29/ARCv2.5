// lib/arc/agents/drafts/draft_repository.dart
// Persists agent drafts (Writing/Research) for the Drafts tab and publish flow.

import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import 'agent_draft.dart';

class DraftNotFoundException implements Exception {
  final String draftId;
  DraftNotFoundException(this.draftId);
  @override
  String toString() => 'DraftNotFoundException: $draftId';
}

/// Repository for agent drafts (auto-saved from Writing/Research agent runs).
class DraftRepository {
  DraftRepository._();
  static final DraftRepository instance = DraftRepository._();

  static const String _fileName = 'agent_drafts.json';
  List<AgentDraft> _cache = [];
  bool _loaded = false;

  Future<String> _getFilePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return path.join(dir.path, _fileName);
  }

  Future<void> _load() async {
    if (_loaded) return;
    try {
      final file = File(await _getFilePath());
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString()) as List<dynamic>;
        _cache = json
            .map((e) => AgentDraft.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        _cache = [];
      }
    } catch (_) {
      _cache = [];
    }
    _loaded = true;
  }

  Future<void> _save() async {
    final file = File(await _getFilePath());
    await file.writeAsString(jsonEncode(_cache.map((d) => d.toJson()).toList()));
  }

  /// Save a new draft (e.g. after Writing Agent completes).
  Future<AgentDraft> saveDraft({
    required AgentType agentType,
    required String content,
    required String originalPrompt,
    String? sourceMaterial,
    Map<String, dynamic> metadata = const {},
  }) async {
    await _load();
    final draft = AgentDraft(
      id: const Uuid().v4(),
      agentType: agentType,
      title: _generateTitle(content, agentType),
      content: content,
      originalPrompt: originalPrompt,
      sourceMaterial: sourceMaterial,
      createdAt: DateTime.now(),
      metadata: metadata,
    );
    _cache.insert(0, draft);
    await _save();
    return draft;
  }

  /// Update an existing draft (e.g. after user edits).
  Future<AgentDraft> updateDraft({
    required String draftId,
    required String content,
    String? title,
    String? editSummary,
  }) async {
    await _load();
    final index = _cache.indexWhere((d) => d.id == draftId);
    if (index < 0) throw DraftNotFoundException(draftId);
    final existing = _cache[index];
    final versions = [...existing.versions, existing.content];
    final updated = existing.copyWith(
      content: content,
      title: title ?? existing.title,
      lastEditedAt: DateTime.now(),
      status: DraftStatus.edited,
      versions: versions,
    );
    _cache[index] = updated;
    await _save();
    return updated;
  }

  /// Get all drafts, optionally filtered. By default excludes archived.
  Future<List<AgentDraft>> getAllDrafts({
    AgentType? filterByType,
    DraftStatus? filterByStatus,
    bool includeArchived = false,
  }) async {
    await _load();
    var list = _cache.toList();
    if (!includeArchived) {
      list = list.where((d) => !d.archived).toList();
    }
    if (filterByType != null) {
      list = list.where((d) => d.agentType == filterByType).toList();
    }
    if (filterByStatus != null) {
      list = list.where((d) => d.status == filterByStatus).toList();
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Get only archived drafts (for Archive tab and agent swap context).
  Future<List<AgentDraft>> getArchivedDrafts({AgentType? filterByType}) async {
    await _load();
    var list = _cache.where((d) => d.archived).toList();
    if (filterByType != null) {
      list = list.where((d) => d.agentType == filterByType).toList();
    }
    list.sort((a, b) => (b.archivedAt ?? b.createdAt).compareTo(a.archivedAt ?? a.createdAt));
    return list;
  }

  /// Move draft to archive. Idempotent.
  Future<void> archiveDraft(String draftId) async {
    await _load();
    final index = _cache.indexWhere((d) => d.id == draftId);
    if (index < 0) return;
    final now = DateTime.now();
    _cache[index] = _cache[index].copyWith(archived: true, archivedAt: now);
    await _save();
  }

  /// Restore draft from archive.
  Future<void> unarchiveDraft(String draftId) async {
    await _load();
    final index = _cache.indexWhere((d) => d.id == draftId);
    if (index < 0) return;
    _cache[index] = _cache[index].copyWith(archived: false, archivedAt: null);
    await _save();
  }

  /// All active drafts + archived drafts for agent context (e.g. writing/research swap).
  /// [draftLimit] and [archiveLimit] cap how many of each to return.
  Future<({List<AgentDraft> drafts, List<AgentDraft> archived})> getDraftsAndArchivedForContext({
    int draftLimit = 20,
    int archiveLimit = 20,
  }) async {
    final drafts = await getAllDrafts(includeArchived: false);
    final archived = await getArchivedDrafts();
    return (
      drafts: drafts.take(draftLimit).toList(),
      archived: archived.take(archiveLimit).toList(),
    );
  }

  /// Get a single draft by id.
  Future<AgentDraft?> getDraft(String draftId) async {
    await _load();
    try {
      return _cache.firstWhere((d) => d.id == draftId);
    } catch (_) {
      return null;
    }
  }

  /// Delete a draft.
  Future<void> deleteDraft(String draftId) async {
    await _load();
    _cache.removeWhere((d) => d.id == draftId);
    await _save();
  }

  String _generateTitle(String content, AgentType type) {
    final headingMatch = RegExp(r'^#{1,2}\s+(.+)$', multiLine: true).firstMatch(content);
    if (headingMatch != null) {
      return (headingMatch.group(1) ?? _defaultTitle(type)).trim();
    }
    final firstSentence = content.split(RegExp(r'[.!?]')).first.trim();
    if (firstSentence.length > 50) {
      return '${firstSentence.substring(0, 50)}...';
    }
    return firstSentence.isEmpty ? _defaultTitle(type) : firstSentence;
  }

  String _defaultTitle(AgentType type) {
    return '${type.displayName} Draft - ${DateFormat('MMM d, h:mm a').format(DateTime.now())}';
  }
}
