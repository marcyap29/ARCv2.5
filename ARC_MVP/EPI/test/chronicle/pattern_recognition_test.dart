import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/chronicle/embeddings/local_embedding_service.dart';
import 'package:my_app/chronicle/models/chronicle_index.dart';
import 'package:my_app/chronicle/models/dominant_theme.dart';
import 'package:my_app/chronicle/models/theme_cluster.dart';
import 'package:my_app/chronicle/models/pattern_insights.dart';
import 'package:my_app/chronicle/matching/three_stage_matcher.dart';

/// Validation tests for Chronicle cross-temporal pattern recognition.
/// Uses Universal Sentence Encoder (512 dimensions).
/// Tests that need TFLite are skipped when native lib is unavailable (e.g. test VM).
void main() {
  late LocalEmbeddingService embedder;
  bool embedderAvailable = false;

  setUpAll(() async {
    embedder = LocalEmbeddingService();
    try {
      await embedder.initialize();
      embedderAvailable = true;
    } catch (_) {
      // TFLite native lib not available (e.g. desktop test VM)
    }
  });

  tearDownAll(() {
    embedder.dispose();
  });

  group('PatternRecognitionTests', () {
    test('embedding dimension constant is 512 (USE)', () {
      expect(LocalEmbeddingService.embeddingDimension, 512);
    });

    test('embedding generation produces 512-dim normalized vector', () async {
      if (!embedderAvailable) return;
      final embedding = await embedder.embed('product launch anxiety');

      expect(embedding.length, LocalEmbeddingService.embeddingDimension);
      expect(embedding.length, 512);
      for (final v in embedding) {
        expect(v.abs(), lessThanOrEqualTo(1.0 + 1e-6));
      }
    });

    test('semantic matching: similar themes have higher similarity', () async {
      if (!embedderAvailable) return;
      final e1 = await embedder.embed('launch anxiety');
      final e2 = await embedder.embed('pre-release stress');
      final e3 = await embedder.embed('work-life balance');

      final sim12 = embedder.cosineSimilarity(e1, e2);
      final sim13 = embedder.cosineSimilarity(e1, e3);

      expect(sim12, greaterThan(0.5), reason: 'Similar themes should have decent similarity');
      expect(sim12, greaterThan(sim13), reason: 'Similar themes more similar than unrelated');
    });

    test('three-stage matcher: no match when index is empty', () async {
      if (!embedderAvailable) return;
      final matcher = ThreeStagePatternMatcher(embedder);
      final index = ChronicleIndex.empty();
      final embedding = await embedder.embed('some theme');
      final theme = DominantTheme(
        themeLabel: 'some theme',
        themeSummary: 'some theme',
        embedding: embedding,
        confidence: 0.8,
        evidenceRefs: [],
      );

      final result = await matcher.findMatch(queryTheme: theme, index: index);

      expect(result.confidence, MatchConfidence.none);
      expect(result.match, isNull);
    });

    test('three-stage matcher: high-confidence match when cluster exists', () async {
      if (!embedderAvailable) return;
      final matcher = ThreeStagePatternMatcher(embedder);
      final embedding = await embedder.embed('product launch anxiety');
      final cluster = ThemeCluster(
        clusterId: 'test_1',
        canonicalLabel: 'product launch anxiety',
        aliases: ['product launch anxiety'],
        appearances: [],
        insights: PatternInsights.empty(),
        canonicalEmbedding: embedding,
        firstSeen: DateTime.now(),
        lastUpdated: DateTime.now(),
      );
      final index = ChronicleIndex(
        themeClusters: {cluster.clusterId: cluster},
        labelToClusterId: {cluster.canonicalLabel: cluster.clusterId},
        pendingEchoes: {},
        arcs: {},
        lastUpdated: DateTime.now(),
      );
      final queryTheme = DominantTheme(
        themeLabel: 'launch anxiety',
        themeSummary: 'anxiety around product launch',
        embedding: await embedder.embed('anxiety around product launch'),
        confidence: 0.9,
        evidenceRefs: [],
      );

      final result = await matcher.findMatch(queryTheme: queryTheme, index: index);

      expect(result.confidence, MatchConfidence.high);
      expect(result.match, isNotNull);
      expect(result.match!.cluster.clusterId, cluster.clusterId);
    });
  });
}
