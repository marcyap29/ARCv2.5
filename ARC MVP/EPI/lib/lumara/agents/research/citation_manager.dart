// lib/lumara/agents/research/citation_manager.dart
// Builds numbered citations from search results.

import 'research_models.dart';

/// Builds citation list and authority scores from search results.
class CitationManager {
  /// Extract citations from search results (dedupe by URL, assign ids).
  List<Citation> buildCitations(List<SearchResult> searchResults) {
    final seen = <String>{};
    final citations = <Citation>[];
    var id = 1;
    for (final sr in searchResults) {
      for (final url in sr.sources) {
        if (url.isEmpty || seen.contains(url)) continue;
        seen.add(url);
        SearchSnippet? snippet;
        for (final s in sr.snippets) {
          if (s.url == url) {
            snippet = s;
            break;
          }
        }
        final domain = _domainFromUrl(url);
        citations.add(Citation(
          id: id++,
          url: url,
          title: snippet?.title ?? url,
          source: domain,
          publishDate: snippet?.publishDate,
          authorityScore: _authorityScore(domain),
        ));
      }
    }
    return citations;
  }

  double _authorityScore(String domain) {
    final d = domain.toLowerCase();
    if (d.endsWith('.gov') || d.endsWith('.edu')) return 0.95;
    if (d.contains('arxiv') || d.contains('nature') || d.contains('rand')) return 0.9;
    return 0.5;
  }

  String _domainFromUrl(String url) {
    try {
      return Uri.parse(url).host;
    } catch (_) {
      return url;
    }
  }
}
