import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:my_app/lumara/agents/writing/writing_models.dart';

/// File-based storage for Writing Agent drafts (optional).
/// Stores drafts under app documents in writing_drafts/{userId}/{draftId}.md
/// Frontmatter: phase, word_count, generated_at, voice_score, theme_alignment, status, archived, archived_at
class WritingDraftRepositoryImpl implements WritingDraftRepository {
  static const String _draftsDir = 'writing_drafts';
  static const String _statusDraft = 'draft';
  static const String _statusFinished = 'finished';

  Future<Directory> _getDraftsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(path.join(appDir.path, _draftsDir));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<void> storeDraft({
    required String userId,
    required Draft draft,
    required DraftMetadata metadata,
  }) async {
    try {
      final base = await _getDraftsDirectory();
      final userDir = Directory(path.join(base.path, userId));
      if (!await userDir.exists()) await userDir.create(recursive: true);
      final draftId = '${DateTime.now().millisecondsSinceEpoch}';
      final file = File(path.join(userDir.path, '$draftId.md'));
      final content = _formatDraft(draft, metadata);
      await file.writeAsString(content);
    } catch (e) {
      // ignore: avoid_print
      print('WritingDraftRepository: Failed to store draft: $e');
    }
  }

  String _formatDraft(Draft draft, DraftMetadata metadata, {String status = _statusDraft, bool archived = false, String? archivedAt}) {
    return '''---
phase: ${metadata.phase}
word_count: ${metadata.wordCount}
generated_at: ${metadata.generatedAt.toIso8601String()}
voice_score: ${draft.voiceScore}
theme_alignment: ${draft.themeAlignment}
status: $status
archived: $archived
archived_at: ${archivedAt ?? ''}
---

${draft.content}
''';
  }

  Future<Map<String, String>> _readFrontmatter(File file) async {
    final text = await file.readAsString();
    if (!text.startsWith('---')) return {};
    final end = text.indexOf('---', 3);
    if (end == -1) return {};
    final block = text.substring(3, end).trim();
    final map = <String, String>{};
    for (final line in block.split('\n')) {
      final colon = line.indexOf(':');
      if (colon > 0) {
        final key = line.substring(0, colon).trim();
        final value = line.substring(colon + 1).trim();
        map[key] = value;
      }
    }
    return map;
  }

  String _extractBody(String text) {
    if (!text.startsWith('---')) return text;
    final end = text.indexOf('---', 3);
    if (end == -1) return text;
    return text.substring(end + 3).trim();
  }

  String _firstLine(String body) {
    final line = body.split('\n').first.trim();
    return line.length > 80 ? '${line.substring(0, 80)}...' : line;
  }

  @override
  Future<List<StoredDraftSummary>> listDrafts(String userId, {bool includeArchived = false}) async {
    try {
      final base = await _getDraftsDirectory();
      final userDir = Directory(path.join(base.path, userId));
      if (!await userDir.exists()) return [];
      final list = <StoredDraftSummary>[];
      await for (final entity in userDir.list()) {
        if (entity is! File || !entity.path.endsWith('.md')) continue;
        final draftId = path.basenameWithoutExtension(entity.path);
        final fm = await _readFrontmatter(entity);
        final archived = fm['archived'] == 'true';
        if (!includeArchived && archived) continue;
        final body = _extractBody(await entity.readAsString());
        final createdStr = fm['generated_at'] ?? '';
        DateTime createdAt = entity.statSync().modified;
        try {
          if (createdStr.isNotEmpty) createdAt = DateTime.parse(createdStr);
        } catch (_) {}
        list.add(StoredDraftSummary(
          draftId: draftId,
          userId: userId,
          title: _firstLine(body).isEmpty ? 'Draft $draftId' : _firstLine(body),
          preview: body.length > 150 ? '${body.substring(0, 150)}...' : body,
          createdAt: createdAt,
          updatedAt: entity.statSync().modified,
          status: fm['status'] == _statusFinished ? DraftStatus.finished : DraftStatus.draft,
          archived: archived,
          archivedAt: fm['archived_at']?.isNotEmpty == true ? DateTime.tryParse(fm['archived_at']!) : null,
          wordCount: int.tryParse(fm['word_count'] ?? '') ?? 0,
          phase: fm['phase'],
        ));
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      // ignore: avoid_print
      print('WritingDraftRepository: listDrafts failed: $e');
      return [];
    }
  }

  @override
  Future<({Draft draft, DraftMetadata metadata})?> getDraft(String userId, String draftId) async {
    try {
      final base = await _getDraftsDirectory();
      final file = File(path.join(base.path, userId, '$draftId.md'));
      if (!await file.exists()) return null;
      final text = await file.readAsString();
      final fm = await _readFrontmatter(file);
      final body = _extractBody(text);
      final phase = fm['phase'] ?? 'Discovery';
      final wordCount = int.tryParse(fm['word_count'] ?? '') ?? 0;
      final generatedAt = DateTime.tryParse(fm['generated_at'] ?? '') ?? DateTime.now();
      final voiceScore = double.tryParse(fm['voice_score'] ?? '');
      final themeAlignment = double.tryParse(fm['theme_alignment'] ?? '');
      final metadata = DraftMetadata(phase: phase, wordCount: wordCount, generatedAt: generatedAt);
      final draft = Draft(
        content: body,
        voiceScore: voiceScore,
        themeAlignment: themeAlignment,
        metadata: metadata,
      );
      return (draft: draft, metadata: metadata);
    } catch (e) {
      // ignore: avoid_print
      print('WritingDraftRepository: getDraft failed: $e');
      return null;
    }
  }

  Future<void> _updateFrontmatter(String userId, String draftId, {String? status, bool? archived, String? archivedAt}) async {
    final base = await _getDraftsDirectory();
    final file = File(path.join(base.path, userId, '$draftId.md'));
    if (!await file.exists()) return;
    final text = await file.readAsString();
    final fm = await _readFrontmatter(file);
    final body = _extractBody(text);
    final newStatus = status ?? fm['status'] ?? _statusDraft;
    final newArchived = archived ?? (fm['archived'] == 'true');
    final newArchivedAt = archivedAt ?? (newArchived ? DateTime.now().toIso8601String() : '');
    final metadata = DraftMetadata(
      phase: fm['phase'] ?? 'Discovery',
      wordCount: int.tryParse(fm['word_count'] ?? '') ?? 0,
      generatedAt: DateTime.tryParse(fm['generated_at'] ?? '') ?? DateTime.now(),
    );
    final draft = Draft(
      content: body,
      voiceScore: double.tryParse(fm['voice_score'] ?? ''),
      themeAlignment: double.tryParse(fm['theme_alignment'] ?? ''),
      metadata: metadata,
    );
    final content = _formatDraft(draft, metadata, status: newStatus, archived: newArchived, archivedAt: newArchivedAt.isEmpty ? null : newArchivedAt);
    await file.writeAsString(content);
  }

  @override
  Future<void> markFinished(String userId, String draftId) async {
    await _updateFrontmatter(userId, draftId, status: _statusFinished);
  }

  @override
  Future<void> archiveDraft(String userId, String draftId) async {
    await _updateFrontmatter(userId, draftId, archived: true, archivedAt: DateTime.now().toIso8601String());
  }

  @override
  Future<void> unarchiveDraft(String userId, String draftId) async {
    await _updateFrontmatter(userId, draftId, archived: false, archivedAt: '');
  }

  @override
  Future<void> deleteDraft(String userId, String draftId) async {
    try {
      final base = await _getDraftsDirectory();
      final file = File(path.join(base.path, userId, '$draftId.md'));
      if (await file.exists()) await file.delete();
    } catch (e) {
      // ignore: avoid_print
      print('WritingDraftRepository: deleteDraft failed: $e');
    }
  }
}
