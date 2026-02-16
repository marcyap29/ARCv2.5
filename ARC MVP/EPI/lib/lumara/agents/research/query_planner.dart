// lib/lumara/agents/research/query_planner.dart
// Decomposes complex research questions into searchable sub-queries.

import 'dart:convert';

import 'package:my_app/models/phase_models.dart';

import 'research_models.dart';

typedef LlmGenerate = Future<String> Function({
  required String systemPrompt,
  required String userPrompt,
  int? maxTokens,
});

/// Breaks user questions into 3–8 searchable sub-queries with optional dependencies.
class QueryPlanner {
  final LlmGenerate _generate;

  QueryPlanner({required LlmGenerate generate}) : _generate = generate;

  /// Plan research: sub-queries and execution strategy.
  Future<ResearchPlan> planResearch({
    required String userQuery,
    required PhaseLabel currentPhase,
  }) async {
    const systemPrompt = r'''
You are a research planning agent. Break this question into specific, searchable sub-queries.

Requirements:
1. Generate 3-8 sub-queries that cover the question comprehensively.
2. Order queries from foundational to specific.
3. Each query should be searchable (3-6 words, specific).
4. Avoid redundancy between queries.
5. Consider what background knowledge is needed vs advanced analysis.

Return ONLY a valid JSON array of objects. No markdown, no explanation. Each object:
- "query": string (the search query)
- "prerequisite": boolean (true if this builds on a previous query)
- "depends_on": optional number (index 0-based of the query this depends on)

Example: [{"query":"SBIR Phase I requirements 2025","prerequisite":false},{"query":"Air Force SBIR AI priorities","prerequisite":true,"depends_on":0}]
''';

    final userPrompt = 'User question: $userQuery';
    String raw;
    try {
      raw = await _generate(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        maxTokens: 600,
      );
    } catch (e) {
      return _fallbackPlan(userQuery);
    }

    final queries = _parseSubQueries(raw);
    final strategy = _determineStrategy(queries);

    return ResearchPlan(
      originalQuery: userQuery,
      subQueries: queries,
      executionStrategy: strategy,
      estimatedDuration: Duration(minutes: queries.length * 2),
    );
  }

  List<SubQuery> _parseSubQueries(String raw) {
    try {
      final trimmed = raw.trim();
      final start = trimmed.indexOf('[');
      final end = trimmed.lastIndexOf(']');
      if (start < 0 || end <= start) return [];
      final jsonStr = trimmed.substring(start, end + 1);
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) => SubQuery.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((q) => q.query.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  ExecutionStrategy _determineStrategy(List<SubQuery> queries) {
    final hasPrerequisites = queries.any((q) => q.prerequisite);
    return hasPrerequisites ? ExecutionStrategy.sequential : ExecutionStrategy.parallel;
  }

  ResearchPlan _fallbackPlan(String userQuery) {
    final simple = SubQuery(query: userQuery, prerequisite: false);
    return ResearchPlan(
      originalQuery: userQuery,
      subQueries: [simple],
      executionStrategy: ExecutionStrategy.parallel,
      estimatedDuration: const Duration(minutes: 2),
    );
  }
}
