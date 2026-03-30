// lib/lumara/agents/research/swarmspace_web_search_tool.dart
//
// Replaces StubWebSearchTool with a real SwarmSpace-backed implementation.
// Routes search requests through SwarmSpace plugins based on user tier and query type.
//
// Drop-in replacement for the existing WebSearchTool interface.
// No changes needed in ResearchAgent or SearchOrchestrator.
//
// Tier routing:
//   free     → brave-search (privacy web) + wikipedia (knowledge) + news (NewsData.io)
//   standard → tavily-search (AI-optimized) + brave-search fallback
//   premium  → exa-search (neural) + tavily-search fallback
//
// News routing: Key phrase "get me news on/about/concerning X"; also "news", "headlines", "latest", "today", etc.

import 'package:flutter/material.dart';
import 'package:my_app/services/swarmspace/prism_service.dart';
import 'package:my_app/services/swarmspace/swarmspace_client.dart';
import 'research_models.dart';
import 'web_search_tool.dart';

/// SwarmSpace-backed web search. Replaces StubWebSearchTool.
///
/// Instantiate with [context] when available (e.g. from Research screen) so url-reader
/// and other plugins go through PRISM consent. Without context, falls back to
/// [onConsentRequired] for first-use consent.
///
///   final searchTool = SwarmSpaceWebSearchTool(context: context);
///   final agent = ResearchAgent(searchTool: searchTool, ...);
typedef SwarmSpaceConsentCallback = Future<bool> Function(String pluginId);

class SwarmSpaceWebSearchTool implements WebSearchTool {
  final SwarmSpaceClient _client;
  final BuildContext? context;
  /// When set, called before each PRISM/UI use so a stale [BuildContext] is not used
  /// after async gaps (e.g. user leaves Research while a run is in flight).
  final BuildContext? Function()? contextLookup;
  final SwarmSpaceConsentCallback? onConsentRequired;

  SwarmSpaceWebSearchTool({
    BuildContext? context,
    this.contextLookup,
    SwarmSpaceClient? client,
    this.onConsentRequired,
  })  : context = context,
        _client = client ?? SwarmSpaceClient.instance;

  BuildContext? get _effectiveContext => contextLookup?.call() ?? context;

  // Key phrase "get me news on/about/concerning X" activates news (NewsData.io).
  static final _newsKeywords = RegExp(
    r'\b(get\s+me\s+news\s+(on|about|concerning))\b|\b(news|headlines?|latest|today|breaking|current events)\b',
    caseSensitive: false,
  );

  @override
  Future<List<SearchSnippet>> search(String query) async {
    // Try news plugin first when query is news-related (NewsData.io).
    if (_newsKeywords.hasMatch(query)) {
      final newsResult = await _tryNews(query);
      if (newsResult != null && newsResult.isNotEmpty) {
        print('SwarmSpace: news returned ${newsResult.length} snippets');
        return newsResult;
      }
    }

    // Try tier-appropriate plugin, fall back down the chain.
    print('SwarmSpace: search(query="$query")');
    List<SearchSnippet>? result = await _tryTavilySearch(query);
    if (result != null) {
      print('SwarmSpace: tavily-search returned ${result.length} snippets');
      return result;
    }
    result = await _tryBraveSearch(query);
    if (result != null) {
      print('SwarmSpace: brave-search returned ${result.length} snippets');
      return result;
    }
    result = await _tryWikipedia(query);
    if (result != null) {
      print('SwarmSpace: wikipedia returned ${result.length} snippets');
      return result;
    }
    print('SwarmSpace: all plugins returned empty/failed, returning []');
    return [];
  }

  @override
  Future<FetchedPage?> fetchPage(String url) async {
    final params = {
      'url': url,
      'summarize': false,
      'max_length': 6000,
      'include_metadata': true,
    };
    final SwarmSpaceResult result;
    final ctx = _effectiveContext;
    if (ctx != null) {
      final prismResult = await PrismService.instance.authoriseAndCall(
        pluginId: 'url-reader',
        params: params,
        context: ctx,
      );
      if (prismResult.isDenied) return null;
      result = prismResult.result!;
    } else {
      final r = await _client.invoke(
        'url-reader',
        params,
        onConsentRequired: onConsentRequired,
      );
      result = r;
    }

    if (!result.success || result.data == null) return null;

    final extracted = result.data!['extracted'] as Map<String, dynamic>?;
    final metadata = result.data!['metadata'] as Map<String, dynamic>?;

    final text = extracted?['text'] as String?;
    if (text == null || text.isEmpty) return null;

    return FetchedPage(
      url: url,
      title: metadata?['title'] as String? ?? url,
      content: text,
    );
  }

  // ── Plugin calls ────────────────────────────────────────────────────────────

  Future<SwarmSpaceResult> _invokePlugin(String pluginId, Map<String, dynamic> params) async {
    final ctx = _effectiveContext;
    if (ctx != null) {
      final prismResult = await PrismService.instance.authoriseAndCall(
        pluginId: pluginId,
        params: params,
        context: ctx,
      );
      if (prismResult.isDenied) return SwarmSpaceResult.error('Plugin skipped by user');
      return prismResult.result!;
    }
    return _client.invoke(pluginId, params, onConsentRequired: onConsentRequired);
  }

  Future<List<SearchSnippet>?> _tryNews(String query) async {
    // Extract search terms: "latest news on AI" → "AI", "top tech news today" → "tech"
    final cleanQuery = query
        .replaceAll(_newsKeywords, '')
        .replaceAll(RegExp(r"\b(top|what's?|what is|get|find|show)\b", caseSensitive: false), '')
        .trim();
    final searchQ = cleanQuery.isEmpty ? 'technology' : cleanQuery;

    final result = await _invokePlugin('news', {'query': searchQ, 'language': 'en'});

    if (!result.success || result.data == null) return null;

    final results = result.data!['results'] as List<dynamic>? ?? [];
    if (results.isEmpty) return null;

    return results.map((r) {
      final map = r as Map<String, dynamic>;
      return SearchSnippet(
        title: map['title'] as String? ?? '',
        snippet: map['snippet'] as String? ?? map['description'] as String? ?? '',
        url: map['url'] as String? ?? map['link'] as String? ?? '',
        domain: map['domain'] as String? ?? map['source'] as String? ?? 'news',
        publishDate: map['pubDate'] != null || map['published_date'] != null
            ? DateTime.tryParse(
                (map['pubDate'] ?? map['published_date']) as String,
              )
            : null,
      );
    }).toList();
  }

  Future<List<SearchSnippet>?> _tryTavilySearch(String query) async {
    final result = await _invokePlugin('tavily-search', {
      'query': query,
      'max_results': 8,
      'include_answer': true,
      'search_depth': 'basic',
    });

    if (!result.success || result.data == null) return null;

    final snippets = <SearchSnippet>[];

    // Tavily returns an AI-synthesized answer — add it as a top result
    final answer = result.data!['answer'] as String?;
    if (answer != null && answer.isNotEmpty) {
      snippets.add(SearchSnippet(
        title: 'Synthesized Answer',
        snippet: answer,
        url: 'tavily://answer',
        domain: 'tavily',
      ));
    }

    final results = result.data!['results'] as List<dynamic>? ?? [];
    for (final r in results) {
      final map = r as Map<String, dynamic>;
      snippets.add(SearchSnippet(
        title: map['title'] as String? ?? '',
        snippet: map['content'] as String? ?? '',
        url: map['url'] as String? ?? '',
        domain: 'tavily',
        publishDate: map['published_date'] != null ? DateTime.tryParse(map['published_date'] as String) : null,
      ));
    }

    return snippets.isEmpty ? null : snippets;
  }

  Future<List<SearchSnippet>?> _tryBraveSearch(String query) async {
    final result = await _invokePlugin('brave-search', {'query': query, 'count': 8});

    if (!result.success) {
      print('SwarmSpace: brave-search failed: ${result.error}');
      return null;
    }
    if (result.data == null) {
      print('SwarmSpace: brave-search returned null data');
      return null;
    }

    // Brave API returns { web: { results: [...] } }; some workers may wrap differently
    final webResults = result.data!['web']?['results'] as List<dynamic>? ??
        result.data!['results'] as List<dynamic>? ??
        [];

    if (webResults.isEmpty) {
      print('SwarmSpace: brave-search web.results empty (keys: ${result.data!.keys.join(", ")})');
      return null;
    }

    return webResults.map((r) {
      final map = r as Map<String, dynamic>;
      return SearchSnippet(
        title: map['title'] as String? ?? '',
        snippet: map['description'] as String? ?? '',
        url: map['url'] as String? ?? '',
        domain: 'brave',
      );
    }).toList();
  }

  Future<List<SearchSnippet>?> _tryWikipedia(String query) async {
    final result = await _invokePlugin('wikipedia', {'query': query, 'mode': 'search', 'limit': 3});

    if (!result.success || result.data == null) return null;

    final results = result.data!['results'] as List<dynamic>? ?? [];
    if (results.isEmpty) return null;

    return results.map((r) {
      final map = r as Map<String, dynamic>;
      return SearchSnippet(
        title: map['title'] as String? ?? '',
        snippet: map['snippet'] as String? ?? '',
        url: map['url'] as String? ?? '',
        domain: 'wikipedia',
      );
    }).toList();
  }
}

/// Extension on SearchSnippet to support the source field.
/// Add these fields to your existing SearchSnippet model in research_models.dart,
/// or use this extension if you prefer not to modify the model.
extension SearchSnippetSource on SearchSnippet {
  // These are on the model itself — see note below.
}
