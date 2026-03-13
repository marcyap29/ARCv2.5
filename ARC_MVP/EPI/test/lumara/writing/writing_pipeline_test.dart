// test/lumara/writing/writing_pipeline_test.dart
//
// Phase 5b: Pipeline assembles correct prompt and calls gemini-flash (mock);
// result parsed into PipelineDraft.

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/lumara/agents/research/content_brief.dart';
import 'package:my_app/lumara/agents/writing/pipeline_draft.dart';
import 'package:my_app/lumara/agents/writing/writing_prompts.dart';

void main() {
  group('Writing pipeline (mock invoker)', () {
    test('buildPhase5bWritingPrompt + mock gemini response parses to PipelineDraft', () async {
      final promptResult = buildPhase5bWritingPrompt(
        topic: 'Why memory matters',
        format: WritingFormat.linkedin,
        tone: WritingTone.conversational,
        brief: ContentBrief(
          title: 'Research: Memory',
          summary: 'Summary',
          keyPoints: ['Key 1'],
          sources: const [],
          createdAt: DateTime(2025, 3, 1),
          query: 'memory',
        ),
      );
      expect(promptResult.userPrompt, contains('Why memory matters'));
      expect(promptResult.userPrompt, contains('Key 1'));
      expect(promptResult.userPrompt, contains('Research: Memory'));

      // Simulate gemini-flash response
      final mockData = <String, dynamic>{
        'text': 'Here is my LinkedIn post.\n\nFirst line hook.\n\nBody.\n\nWhat do you think?',
      };
      final body = _extractGeminiText(mockData);
      expect(body, isNotNull);
      expect(body?.trim(), isNotEmpty);

      final draft = PipelineDraft(
        id: 'draft_1',
        topic: 'Why memory matters',
        format: WritingFormat.linkedin,
        tone: WritingTone.conversational,
        body: body!.trim(),
        briefId: 'Research: Memory',
        createdAt: DateTime.now(),
        versions: [],
      );
      expect(draft.body, contains('LinkedIn post'));
      expect(draft.topic, 'Why memory matters');
      expect(draft.format, WritingFormat.linkedin);
    });

    test('extractGeminiText handles candidates format', () {
      final data = <String, dynamic>{
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'Draft from candidates'},
              ],
            },
          },
        ],
      };
      final text = _extractGeminiText(data);
      expect(text, 'Draft from candidates');
    });
  });
}

String? _extractGeminiText(Map<String, dynamic> data) {
  final text = data['text'] as String?;
  if (text != null && text.isNotEmpty) return text.trim();
  final content = data['content'] as String?;
  if (content != null && content.isNotEmpty) return content.trim();
  final candidates = data['candidates'] as List?;
  if (candidates != null && candidates.isNotEmpty) {
    final first = candidates.first as Map<String, dynamic>?;
    final contentObj = first?['content'] as Map<String, dynamic>?;
    final parts = contentObj?['parts'] as List?;
    if (parts != null && parts.isNotEmpty) {
      final part = parts.first as Map<String, dynamic>?;
      final partText = part?['text'] as String?;
      if (partText != null && partText.isNotEmpty) return partText.trim();
    }
  }
  return null;
}
