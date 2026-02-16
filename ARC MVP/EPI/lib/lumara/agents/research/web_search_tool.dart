// lib/lumara/agents/research/web_search_tool.dart
// Abstract web search and fetch for Research Agent. Implement with real API or MCP.

import 'research_models.dart';

/// Tool interface for web search (and optional page fetch).
/// Implement with SerpAPI, Brave Search, or in-app MCP client.
abstract class WebSearchTool {
  /// Execute a search query; returns snippets (title, snippet, url).
  /// Caller may then fetch full pages for top results.
  Future<List<SearchSnippet>> search(String query);

  /// Fetch full page content for a URL (for synthesis).
  /// Returns null if fetch fails or is unsupported.
  Future<FetchedPage?> fetchPage(String url) async => null;
}

/// Stub implementation: returns empty or minimal results so the pipeline runs.
/// Replace with a real implementation (e.g. Brave Search API, SerpAPI, or MCP).
class StubWebSearchTool implements WebSearchTool {
  @override
  Future<List<SearchSnippet>> search(String query) async {
    // Placeholder: no network call. Integrate real search API when available.
    return [];
  }

  @override
  Future<FetchedPage?> fetchPage(String url) async => null;
}
