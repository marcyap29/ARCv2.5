// test/lumara/writing/pipeline_draft_test.dart
// Phase 5b: PipelineDraft serialisation; format/tone enums round-trip.

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/lumara/agents/writing/pipeline_draft.dart';

void main() {
  group('PipelineDraft', () {
    test('toJson and fromJson round-trip', () {
      final draft = PipelineDraft(
        id: 'd1',
        topic: 'Test topic',
        format: WritingFormat.linkedin,
        tone: WritingTone.persuasive,
        body: 'Draft body text.',
        briefId: 'brief-1',
        createdAt: DateTime(2025, 3, 10, 12, 0),
        versions: ['v1', 'v2'],
      );
      final json = draft.toJson();
      final restored = PipelineDraft.fromJson(json);
      expect(restored.id, draft.id);
      expect(restored.topic, draft.topic);
      expect(restored.format, draft.format);
      expect(restored.tone, draft.tone);
      expect(restored.body, draft.body);
      expect(restored.briefId, draft.briefId);
      expect(restored.versions, draft.versions);
    });

    test('format enum round-trips in JSON', () {
      for (final format in WritingFormat.values) {
        final draft = PipelineDraft(
          id: 'x',
          topic: 'T',
          format: format,
          tone: WritingTone.informative,
          body: 'b',
          createdAt: DateTime.now(),
        );
        final restored = PipelineDraft.fromJson(draft.toJson());
        expect(restored.format, format);
      }
    });

    test('tone enum round-trips in JSON', () {
      for (final tone in WritingTone.values) {
        final draft = PipelineDraft(
          id: 'x',
          topic: 'T',
          format: WritingFormat.article,
          tone: tone,
          body: 'b',
          createdAt: DateTime.now(),
        );
        final restored = PipelineDraft.fromJson(draft.toJson());
        expect(restored.tone, tone);
      }
    });

    test('folderKey maps format correctly', () {
      expect(
        PipelineDraft(
          id: 'x',
          topic: 'T',
          format: WritingFormat.article,
          tone: WritingTone.informative,
          body: 'b',
          createdAt: DateTime.now(),
        ).folderKey,
        'articles',
      );
      expect(
        PipelineDraft(
          id: 'x',
          topic: 'T',
          format: WritingFormat.linkedin,
          tone: WritingTone.informative,
          body: 'b',
          createdAt: DateTime.now(),
        ).folderKey,
        'linkedin',
      );
      expect(
        PipelineDraft(
          id: 'x',
          topic: 'T',
          format: WritingFormat.bluesky,
          tone: WritingTone.informative,
          body: 'b',
          createdAt: DateTime.now(),
        ).folderKey,
        'bluesky',
      );
    });
  });
}
