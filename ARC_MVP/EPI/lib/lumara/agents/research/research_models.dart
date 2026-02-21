// lib/lumara/agents/research/research_models.dart
// Models for the LUMARA Research Agent: plans, reports, citations, sessions.

import 'package:my_app/models/phase_models.dart';

/// Execution strategy for sub-queries: parallel or sequential.
enum ExecutionStrategy {
  parallel,
  sequential,
}

/// Depth of synthesis output (phase- and readiness-aware).
enum SynthesisDepth {
  brief,
  moderate,
  comprehensive,
  deep,
}

/// A single searchable sub-query from the query planner.
class SubQuery {
  final String query;
  final bool prerequisite;
  final int? dependsOn; // index of query this depends on

  const SubQuery({
    required this.query,
    this.prerequisite = false,
    this.dependsOn,
  });

  factory SubQuery.fromJson(Map<String, dynamic> json) {
    return SubQuery(
      query: json['query'] as String? ?? '',
      prerequisite: json['prerequisite'] as bool? ?? false,
      dependsOn: json['depends_on'] as int?,
    );
  }
}

/// Plan produced by QueryPlanner: sub-queries and execution strategy.
class ResearchPlan {
  final String originalQuery;
  final List<SubQuery> subQueries;
  final ExecutionStrategy executionStrategy;
  final Duration estimatedDuration;

  const ResearchPlan({
    required this.originalQuery,
    required this.subQueries,
    required this.executionStrategy,
    required this.estimatedDuration,
  });
}

/// Snippet from a web search result (before full fetch).
class SearchSnippet {
  final String title;
  final String snippet;
  final String url;
  final String? domain;
  final DateTime? publishDate;

  const SearchSnippet({
    required this.title,
    required this.snippet,
    required this.url,
    this.domain,
    this.publishDate,
  });
}

/// Scored result for ranking (recency, authority, relevance).
class ScoredResult {
  final SearchSnippet result;
  final double score;

  const ScoredResult({required this.result, required this.score});
}

/// Full content fetched from a URL (for synthesis).
class FetchedPage {
  final String url;
  final String title;
  final String content;

  const FetchedPage({
    required this.url,
    required this.title,
    required this.content,
  });
}

/// Result of executing one search (query + snippets + optional full pages).
class SearchResult {
  final String query;
  final List<SearchSnippet> snippets;
  final List<FetchedPage> fullContent;
  final List<String> sources;
  final DateTime timestamp;

  const SearchResult({
    required this.query,
    required this.snippets,
    this.fullContent = const [],
    required this.sources,
    required this.timestamp,
  });
}

/// Prior research context from CHRONICLE cross-reference.
class PriorResearchContext {
  final bool hasRelatedResearch;
  final List<ResearchArtifactSummary> priorSessions;
  final List<dynamic> relatedEntries;
  final ExistingKnowledge existingKnowledge;
  final List<String> knowledgeGaps;

  const PriorResearchContext({
    required this.hasRelatedResearch,
    this.priorSessions = const [],
    this.relatedEntries = const [],
    required this.existingKnowledge,
    this.knowledgeGaps = const [],
  });
}

/// Summary of a stored research session (for cross-reference).
class ResearchArtifactSummary {
  final String sessionId;
  final String query;
  final String summary;
  final DateTime timestamp;
  final String phase;

  const ResearchArtifactSummary({
    required this.sessionId,
    required this.query,
    required this.summary,
    required this.timestamp,
    required this.phase,
  });
}

/// Existing knowledge summary (what user already knew).
class ExistingKnowledge {
  final String summary;

  const ExistingKnowledge({this.summary = ''});
}

/// One citation in the report.
class Citation {
  final int id;
  final String url;
  final String title;
  final String source;
  final DateTime? publishDate;
  final double authorityScore;

  const Citation({
    required this.id,
    required this.url,
    required this.title,
    required this.source,
    this.publishDate,
    this.authorityScore = 0.5,
  });
}

/// One structured insight with evidence and citations.
class Insight {
  final String statement;
  final String evidence;
  final List<int> citationIds;
  final double confidence;

  const Insight({
    required this.statement,
    required this.evidence,
    this.citationIds = const [],
    this.confidence = 0.8,
  });
}

/// Full research report (phase-aware synthesis).
class ResearchReport {
  final String query;
  final String summary;
  final List<Insight> keyInsights;
  final String detailedFindings;
  final String strategicImplications;
  final List<String> nextSteps;
  final List<Citation> citations;
  final ExistingKnowledge priorKnowledge;
  final List<String> knowledgeGapsDiscovered;
  final List<SearchResult> searchResults;
  final DateTime generatedAt;
  final PhaseLabel phase;
  final SynthesisDepth depth;

  const ResearchReport({
    required this.query,
    required this.summary,
    this.keyInsights = const [],
    this.detailedFindings = '',
    this.strategicImplications = '',
    this.nextSteps = const [],
    this.citations = const [],
    this.priorKnowledge = const ExistingKnowledge(),
    this.knowledgeGapsDiscovered = const [],
    this.searchResults = const [],
    required this.generatedAt,
    required this.phase,
    this.depth = SynthesisDepth.moderate,
  });
}

/// Stored research artifact (for CHRONICLE / persistence).
class ResearchArtifact {
  final String sessionId;
  final String query;
  final ResearchReport report;
  final DateTime timestamp;
  final PhaseLabel phase;

  const ResearchArtifact({
    required this.sessionId,
    required this.query,
    required this.report,
    required this.timestamp,
    required this.phase,
  });
}

/// Session status for multi-turn research.
enum SessionStatus {
  active,
  completed,
}

/// In-memory research session (multi-turn).
class ResearchSession {
  final String id;
  final String userId;
  final List<String> queries;
  final List<SearchResult> searchResults;
  final List<ResearchReport> synthesisHistory;
  final DateTime createdAt;
  SessionStatus status;
  PhaseLabel phase;
  double readinessScore;

  ResearchSession({
    required this.id,
    required this.userId,
    List<String>? queries,
    List<SearchResult>? searchResults,
    List<ResearchReport>? synthesisHistory,
    required this.createdAt,
    this.status = SessionStatus.active,
    this.phase = PhaseLabel.discovery,
    this.readinessScore = 50.0,
  })  : queries = queries ?? [],
        searchResults = searchResults ?? [],
        synthesisHistory = synthesisHistory ?? [];
}
