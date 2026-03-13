// test/lumara/writing/writing_prompt_builder_test.dart
//
// Phase 5b: Prompt builder for format/tone/style/brief.

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/lumara/agents/research/content_brief.dart';
import 'package:my_app/lumara/agents/writing/pipeline_draft.dart';
import 'package:my_app/lumara/agents/writing/writing_prompts.dart';

void main() {
  group('buildPhase5bWritingPrompt', () {
    test('assembles prompt with topic format and tone', () {
      final result = buildPhase5bWritingPrompt(
        topic: 'Why CHRONICLE matters',
        format: WritingFormat.article,
        tone: WritingTone.informative,
      );
      expect(result.userPrompt, contains('Why CHRONICLE matters'));
      expect(result.userPrompt, contains('Article'));
      expect(result.userPrompt, contains('Informative'));
      expect(result.userPrompt, contains('600–900 words'));
    });

    test('includes style excerpt when present', () {
      final result = buildPhase5bWritingPrompt(
        topic: 'Test',
        format: WritingFormat.linkedin,
        tone: WritingTone.conversational,
        styleExcerpt: 'Short sentences. Direct tone.',
      );
      expect(result.userPrompt, contains('personal voice'));
      expect(result.userPrompt, contains('Short sentences'));
    });

    test('includes ContentBrief key points and sources when present', () {
      final brief = ContentBrief(
        title: 'Research on X',
        summary: 'Summary',
        keyPoints: ['Point A', 'Point B'],
        sources: [
          const SourceRef(title: 'Source 1', url: 'https://example.com', domain: 'example.com'),
        ],
        createdAt: DateTime(2025, 3, 1),
        query: 'query',
      );
      final result = buildPhase5bWritingPrompt(
        topic: 'Topic',
        format: WritingFormat.substack,
        tone: WritingTone.reflective,
        brief: brief,
      );
      expect(result.userPrompt, contains('Research on X'));
      expect(result.userPrompt, contains('Point A'));
      expect(result.userPrompt, contains('Point B'));
      expect(result.userPrompt, contains('Source 1'));
      expect(result.userPrompt, contains('https://example.com'));
    });

    test('format-specific instructions: Bluesky 300 chars', () {
      final result = buildPhase5bWritingPrompt(
        topic: 'T',
        format: WritingFormat.bluesky,
        tone: WritingTone.informative,
      );
      expect(result.userPrompt, contains('300 characters'));
    });

    test('format-specific instructions: Threads 150–500', () {
      final result = buildPhase5bWritingPrompt(
        topic: 'T',
        format: WritingFormat.threads,
        tone: WritingTone.informative,
      );
      expect(result.userPrompt, contains('150–500 characters'));
    });
  });
}
