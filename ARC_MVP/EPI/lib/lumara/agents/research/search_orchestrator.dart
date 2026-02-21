// lib/lumara/agents/research/search_orchestrator.dart
// Manages parallel/sequential web searches and result scoring.

import 'research_models.dart';
import 'web_search_tool.dart';

/// Batch size for parallel searches (rate limiting).
const int _batchSize = 5;
const int _delayBetweenBatchesMs = 500;
const int _topPagesToFetch = 3;

/// Executes search plans with optional prior-context filtering.
class SearchOrchestrator {
  final WebSearchTool _searchTool;

  SearchOrchestrator({required WebSearchTool searchTool}) : _searchTool = searchTool;

  Future<List<SearchResult>> executeSearches({
    required List<SubQuery> queries,
    required ExecutionStrategy strategy,
    required PriorResearchContext priorContext,
  }) async {
    final queriesNeeded = _filterWithPriorKnowledge(queries, priorContext);
    if (queriesNeeded.isEmpty) return [];

    if (strategy == ExecutionStrategy.parallel) {
      return await _parallelSearch(queriesNeeded);
    }
    return await _sequentialSearch(queriesNeeded);
  }

  List<SubQuery> _filterWithPriorKnowledge(
    List<SubQuery> queries,
    PriorResearchContext priorContext,
  ) {
    if (!priorContext.hasRelatedResearch) return queries;
    return queries;
  }

  Future<List<SearchResult>> _parallelSearch(List<SubQuery> queries) async {
    final batches = <List<SubQuery>>[];
    for (var i = 0; i < queries.length; i += _batchSize) {
      batches.add(queries.sublist(i, i + _batchSize > queries.length ? queries.length : i + _batchSize));
    }
    final allResults = <SearchResult>[];
    for (var i = 0; i < batches.length; i++) {
      final batch = batches[i];
      final futures = batch.map((q) => _executeSearch(q.query));
      final results = await Future.wait(futures);
      allResults.addAll(results);
      if (i < batches.length - 1) {
        await Future<void>.delayed(const Duration(milliseconds: _delayBetweenBatchesMs));
      }
    }
    return allResults;
  }

  Future<List<SearchResult>> _sequentialSearch(List<SubQuery> queries) async {
    final results = <SearchResult>[];
    for (final q in queries) {
      results.add(await _executeSearch(q.query));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return results;
  }

  Future<SearchResult> _executeSearch(String query) async {
    final snippets = await _searchTool.search(query);
    final scored = _scoreResults(snippets, query);
    final topUrls = scored.take(_topPagesToFetch).map((s) => s.result.url).toList();
    final fullPages = <FetchedPage>[];
    for (final url in topUrls) {
      final page = await _searchTool.fetchPage(url);
      if (page != null) fullPages.add(page);
    }
    return SearchResult(
      query: query,
      snippets: snippets,
      fullContent: fullPages,
      sources: topUrls,
      timestamp: DateTime.now(),
    );
  }

  List<ScoredResult> _scoreResults(List<SearchSnippet> results, String query) {
    if (results.isEmpty) return [];
    final queryLower = query.toLowerCase();
    return results.map((r) {
      final recencyScore = _calculateRecency(r.publishDate);
      final authorityScore = _calculateAuthority(r.domain ?? _domainFromUrl(r.url));
      final relevanceScore = _calculateRelevance(r.snippet, queryLower);
      final total = recencyScore * 0.3 + authorityScore * 0.4 + relevanceScore * 0.3;
      return ScoredResult(result: r, score: total);
    }).toList()..sort((a, b) => b.score.compareTo(a.score));
  }

  double _calculateRecency(DateTime? publishDate) {
    if (publishDate == null) return 0.7;
    final months = DateTime.now().difference(publishDate).inDays / 30;
    if (months <= 6) return 1.0;
    if (months <= 12) return 0.8;
    return (1.0 - (months - 12) * 0.05).clamp(0.2, 1.0);
  }

  double _calculateAuthority(String? domain) {
    if (domain == null || domain.isEmpty) return 0.5;
    final d = domain.toLowerCase();
    if (d.endsWith('.gov') || d.endsWith('.edu')) return 0.95;
    if (d.contains('arxiv') || d.contains('nature') || d.contains('rand')) return 0.9;
    if (d.contains('wikipedia')) return 0.7;
    return 0.5;
  }

  double _calculateRelevance(String snippet, String queryLower) {
    final words = queryLower.split(RegExp(r'\s+')).where((w) => w.length > 2).toSet();
    if (words.isEmpty) return 0.5;
    final snippetLower = snippet.toLowerCase();
    final matches = words.where((w) => snippetLower.contains(w)).length;
    return (matches / words.length).clamp(0.0, 1.0);
  }

  String _domainFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (_) {
      return '';
    }
  }
}
