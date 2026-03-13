// test/lumara/research/research_pipeline_test.dart
//
// Phase 3: Research pipeline tests with mocked PrismService (invoker).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/lumara/agents/research/content_brief.dart';
import 'package:my_app/lumara/agents/research/research_pipeline.dart';
import 'package:my_app/services/swarmspace/prism_service.dart';
import 'package:my_app/services/swarmspace/swarmspace_client.dart';

void main() {
  group('ContentBrief model', () {
    test('toJson and fromJson round-trip', () {
      final brief = ContentBrief(
        title: 'Test title',
        summary: 'Test summary',
        keyPoints: ['A', 'B'],
        sources: [
          const SourceRef(title: 'S1', url: 'https://a.com', domain: 'web'),
        ],
        createdAt: DateTime(2025, 3, 1, 12, 0),
        query: 'test query',
      );
      final json = brief.toJson();
      final restored = ContentBrief.fromJson(json);
      expect(restored.title, brief.title);
      expect(restored.summary, brief.summary);
      expect(restored.keyPoints, brief.keyPoints);
      expect(restored.sources.length, brief.sources.length);
      expect(restored.sources.first.url, brief.sources.first.url);
      expect(restored.query, brief.query);
    });
  });

  group('runResearchPipeline', () {
    test('ContentBrief populated when all three plugins return results', () async {
      final stages = <String>[];
      Future<PrismCallResult> invoker(String pluginId, Map<String, dynamic> params) async {
        if (pluginId == 'brave-search') {
          return PrismSuccessResult(SwarmSpaceResult.fromData({
            'web': {
              'results': [
                {'title': 'Web 1', 'description': 'D1', 'url': 'https://w1.com'},
              ],
            },
          }));
        }
        if (pluginId == 'semantic-scholar') {
          return PrismSuccessResult(SwarmSpaceResult.fromData({
            'data': [
              {'title': 'Paper 1', 'url': 'https://s2.com/p1', 'paperId': 'p1'},
            ],
          }));
        }
        if (pluginId == 'gemini-flash') {
          return PrismSuccessResult(SwarmSpaceResult.fromData({
            'text': '''
{"title": "Brief title", "summary": "A short summary.", "keyPoints": ["Point 1", "Point 2"], "sources": [{"title": "Web 1", "url": "https://w1.com", "domain": "web"}]}
''',
          }));
        }
        return const PrismDeniedResult();
      }

      final errorOut = <String>[];
      final brief = await runResearchPipeline(
        query: 'test query',
        context: null,
        onStage: stages.add,
        errorOut: errorOut,
        invoker: invoker,
      );

      expect(brief, isNotNull);
      expect(brief!.title, 'Brief title');
      expect(brief.summary, 'A short summary.');
      expect(brief.keyPoints, ['Point 1', 'Point 2']);
      expect(brief.sources.length, greaterThanOrEqualTo(1));
      expect(brief.query, 'test query');
      expect(stages, contains('Searching web...'));
      expect(stages, contains('Checking academic sources...'));
      expect(stages, contains('Synthesising...'));
      expect(errorOut, isEmpty);
    });

    test('fallback when brave-search returns empty', () async {
      Future<PrismCallResult> invoker(String pluginId, Map<String, dynamic> params) async {
        if (pluginId == 'brave-search') {
          return PrismSuccessResult(SwarmSpaceResult.fromData({'web': {'results': []}}));
        }
        if (pluginId == 'semantic-scholar') {
          return PrismSuccessResult(SwarmSpaceResult.fromData({
            'data': [
              {'title': 'Only paper', 'url': 'https://s2.com/only'},
            ],
          }));
        }
        if (pluginId == 'gemini-flash') {
          return PrismSuccessResult(SwarmSpaceResult.fromData({
            'text': '{"title": "From academic only", "summary": "Only academic sources were used.", "keyPoints": []}',
          }));
        }
        return const PrismDeniedResult();
      }

      final brief = await runResearchPipeline(
        query: 'test',
        context: null,
        errorOut: <String>[],
        invoker: invoker,
      );

      expect(brief, isNotNull);
      expect(brief!.summary, contains('academic'));
    });

    test('graceful degradation when both search plugins fail', () async {
      Future<PrismCallResult> invoker(String pluginId, Map<String, dynamic> params) async {
        if (pluginId == 'brave-search' || pluginId == 'semantic-scholar') {
          return PrismSuccessResult(SwarmSpaceResult.error('fail'));
        }
        if (pluginId == 'gemini-flash') {
          return PrismSuccessResult(SwarmSpaceResult.fromData({
            'text': '{"title": "Query only", "summary": "No search results; general answer.", "keyPoints": ["One"]}',
          }));
        }
        return const PrismDeniedResult();
      }

      final brief = await runResearchPipeline(
        query: 'query only',
        context: null,
        errorOut: <String>[],
        invoker: invoker,
      );

      expect(brief, isNotNull);
      expect(brief!.query, 'query only');
    });

    test('user-friendly error on total failure (gemini fails)', () async {
      Future<PrismCallResult> invoker(String pluginId, Map<String, dynamic> params) async {
        if (pluginId == 'gemini-flash') {
          return const PrismDeniedResult();
        }
        return PrismSuccessResult(SwarmSpaceResult.fromData({}));
      }

      final errorOut = <String>[];
      final brief = await runResearchPipeline(
        query: 'test',
        context: null,
        errorOut: errorOut,
        invoker: invoker,
      );

      expect(brief, isNull);
      expect(errorOut.length, 1);
      expect(
        errorOut.single,
        kPipelineFailureMessage,
      );
      expect(errorOut.single, isNot(contains('Exception')));
      expect(errorOut.single, isNot(contains('stack')));
    });
  });
}
