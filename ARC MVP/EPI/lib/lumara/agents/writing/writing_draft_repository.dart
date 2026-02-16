import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:my_app/lumara/agents/writing/writing_models.dart';

/// File-based storage for Writing Agent drafts (optional).
/// Stores drafts under app documents in writing_drafts/{userId}/{draftId}.md
class WritingDraftRepositoryImpl implements WritingDraftRepository {
  static const String _draftsDir = 'writing_drafts';

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

  String _formatDraft(Draft draft, DraftMetadata metadata) {
    return '''---
phase: ${metadata.phase}
word_count: ${metadata.wordCount}
generated_at: ${metadata.generatedAt.toIso8601String()}
voice_score: ${draft.voiceScore}
theme_alignment: ${draft.themeAlignment}
---

${draft.content}
''';
  }
}
