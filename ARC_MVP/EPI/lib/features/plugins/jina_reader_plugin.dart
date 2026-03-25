import 'package:http/http.dart' as http;

/// SwarmSpace plugin: Jina Reader — free web-to-text via r.jina.ai.
class JinaReaderPlugin {
  JinaReaderPlugin._();

  static const String agentId = 'jina-reader';

  static const String name = 'Jina Reader';
  static const String slug = 'jina-reader';
  static const String description =
      'Fetches any URL and returns clean extracted text. Free, no authentication required. Use when you need to read the contents of a web page for research, summarisation, or data extraction.';
  static const String accessTier = 'free';
  static const String trustTier = 'verified';
  static const int creditCostPerCall = 0;
  static const List<String> semanticTags = [
    'web',
    'extraction',
    'reader',
    'scraping',
    'text',
    'url',
    'fetch',
  ];
  static const String latencyClass = 'standard';
  static const String authMethod = 'none';
  static const String agentGuidance =
      'Use this plugin when you need to read the full text content of a web page. Pass a complete URL including https://. Returns clean readable text stripped of HTML. Best used after a web search returns URLs you want to read in depth. Not suitable for pages behind login walls or paywalls.';

  /// GET `https://r.jina.ai/{url}` and return plain text, trimmed to [charLimit].
  static Future<String> fetch(String url, {int charLimit = 8000}) async {
    final trimmed = url.trim();
    final uri = Uri.parse('https://r.jina.ai/$trimmed');
    try {
      final response = await http
          .get(
            uri,
            headers: const {
              'Accept': 'text/plain',
              'X-Return-Format': 'text',
            },
          )
          .timeout(const Duration(seconds: 15));
      final body = response.body.trim();
      if (body.length <= charLimit) return body;
      return body.substring(0, charLimit);
    } catch (e) {
      return '[fetch failed: $e]';
    }
  }

  /// Full SwarmSpace plugin manifest for discovery and orchestration.
  static Map<String, dynamic> toManifest() {
    return {
      'name': name,
      'slug': slug,
      'description': description,
      'access_tier': accessTier,
      'trust_tier': trustTier,
      'credit_cost_per_call': creditCostPerCall,
      'semantic_tags': semanticTags,
      'latency_class': latencyClass,
      'auth_method': authMethod,
      'agent_guidance': agentGuidance,
      'endpoint_url': 'https://r.jina.ai/{url}',
      'canonical_url': 'https://swarmspace.io/plugins/jina-reader',
      'privacy_data_required': <String>[],
      'developer_name': 'Jina AI',
      'developer_url': 'https://jina.ai',
      'pricing_url': 'https://jina.ai/#pricing',
      'free_tier_limits': 'Unlimited basic use, no key required',
      'data_handling':
          'Only the requested URL is sent. No user personal data transmitted.',
    };
  }
}
