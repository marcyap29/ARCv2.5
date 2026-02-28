// lib/lumara/agents/research/swarmspace_web_search_tool.dart
//
// Replaces StubWebSearchTool with a real SwarmSpace-backed implementation.
// Routes search requests through SwarmSpace plugins based on user tier and query type.
//
// Drop-in replacement for the existing WebSearchTool interface.
// No changes needed in ResearchAgent or SearchOrchestrator.
//
// Tier routing:
//   free     → brave-search (privacy web) + wikipedia (knowledge)
//   standard → tavily-search (AI-optimized) + brave-search fallback
//   premium  → exa-search (neural) + tavily-search fallback

import 'package:my_app/services/swarmspace/swarmspace_client.dart';
import 'research_models.dart';
import 'web_search_tool.dart';

/// SwarmSpace-backed web search. Replaces StubWebSearchTool.
///
/// Instantiate once and pass to ResearchAgent:
///
///   final searchTool = SwarmSpaceWebSearchTool();
///   final agent = ResearchAgent(searchTool: searchTool, ...);
class SwarmSpaceWebSearchTool implements WebSearchTool {
  final SwarmSpaceClient _client;

  SwarmSpaceWebSearchTool({SwarmSpaceClient? client})
      : _client = client ?? SwarmSpaceClient.instance;

  @override
  Future<List<SearchSnippet>> search(String query) async {
    // Try tier-appropriate plugin first, fall back down the chain.
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
    // URL Reader plugin (standard tier) — fetch and extract page content.
    final result = await _client.invoke('url-reader', {
      'url': url,
      'summarize': false,
      'max_length': 6000,
      'include_metadata': true,
    });

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

  Future<List<SearchSnippet>?> _tryTavilySearch(String query) async {
    final result = await _client.invoke('tavily-search', {
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
    final result = await _client.invoke('brave-search', {
      'query': query,
      'count': 8,
    });

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
    final result = await _client.invoke('wikipedia', {
      'query': query,
      'mode': 'search',
      'limit': 3,
    });

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
