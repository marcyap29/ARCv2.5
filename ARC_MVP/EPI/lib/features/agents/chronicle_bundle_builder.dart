import 'package:my_app/chronicle/dual/services/chronicle_query_adapter.dart';
import 'package:my_app/chronicle/embeddings/create_embedding_service.dart';
import 'package:my_app/chronicle/search/hybrid_search_engine.dart';
import 'package:my_app/features/agents/worker_service.dart';
import 'package:my_app/lumara/agents/services/timeline_context_service.dart';

String _clip(String s, int max) {
  final t = s.trim();
  if (t.isEmpty) return '';
  return t.length > max ? '${t.substring(0, max)}...' : t;
}

/// Builds [ChronicleBundle] from real CHRONICLE timeline/theme data (not demo personas).
///
/// When [hybridSearchForTopic] is true and [contentTopic] is long enough, runs on-device
/// hybrid (BM25 + semantic) search over Layer 0 entries and attaches top excerpts so the
/// Worker can offer to integrate them when relevant.
Future<ChronicleBundle> buildChronicleBundleForWorkflow({
  required String userId,
  required String contentTopic,
  bool hybridSearchForTopic = false,
}) async {
  final svc = TimelineContextService();
  final ctx = await svc.getWritingContext(
    userId: userId,
    contentTopic: contentTopic,
  );
  final profile = _clip(
    '${ctx.currentPhase}: ${ctx.phaseDescription}'.trim(),
    500,
  );
  final tags = _clip(ctx.dominantThemes, 600);
  final recent = _clip(ctx.recentEntries, 3500);
  final topical = _clip(
    '${ctx.timelineSummary}\n\nDominant themes: ${ctx.dominantThemes}\nPatterns: ${ctx.patterns}',
    4000,
  );

  var bundle = ChronicleBundle(
    profile: profile.isEmpty ? 'Journal timeline (CHRONICLE)' : profile,
    tags: tags.isEmpty ? '—' : tags,
    recent: recent.isEmpty ? 'No recent journal entries indexed yet.' : recent,
    topical: topical.isEmpty ? tags : topical,
  );

  if (!hybridSearchForTopic || contentTopic.trim().length < 8) {
    return bundle;
  }

  try {
    final embedder = await createEmbeddingService();
    await embedder.initialize();
    final adapter = ChronicleQueryAdapter();
    final engine = HybridSearchEngine(
      chronicleAdapter: adapter,
      embeddingService: embedder,
    );
    final hits = await engine.search(
      userId,
      contentTopic,
      options: const HybridSearchOptions(topK: 8, enableReranking: true),
    );
    embedder.dispose();

    if (hits.isEmpty) return bundle;

    final entries = await adapter.loadEntries(userId);
    final byId = {for (final e in entries) e.id: e};
    final semanticHits = <ChronicleSemanticHit>[];

    for (final h in hits.take(6)) {
      final e = byId[h.id];
      if (e == null) continue;
      var clipText = e.content.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (clipText.length > 420) {
        clipText = '${clipText.substring(0, 420)}…';
      }
      if (clipText.isEmpty) continue;
      semanticHits.add(
        ChronicleSemanticHit(
          snippet: clipText,
          score: h.rerankScore,
          entryDate: e.timestamp.toIso8601String(),
        ),
      );
    }

    if (semanticHits.isEmpty) return bundle;

    bundle = ChronicleBundle(
      profile: bundle.profile,
      tags: bundle.tags,
      recent: bundle.recent,
      topical: bundle.topical,
      semanticHits: semanticHits,
      integrationNote:
          'These excerpts matched this request via hybrid keyword + semantic search over CHRONICLE. '
          'Only weave them in when clearly relevant; the author may prefer not to use personal history.',
    );
  } catch (_) {
    /* non-fatal: timeline-only bundle */
  }

  return bundle;
}
