// Models for the LUMARA Research Agent (ATLAS) reports.
// AtlasPhase aligns with ATLAS phase naming used in research context.

enum AtlasPhase {
  recovery,
  transition,
  discovery,
  expansion,
  breakthrough,
  consolidation,
}

/// A single citation/source in a research report.
class ResearchCitation {
  final int id;
  final String title;
  final String source;
  final String url;
  final DateTime? publishDate;

  const ResearchCitation({
    required this.id,
    required this.title,
    required this.source,
    required this.url,
    this.publishDate,
  });
}

/// A key insight with evidence and optional citation refs.
class KeyInsight {
  final String statement;
  final String evidence;
  final List<int> citationIds;
  final double confidence;

  const KeyInsight({
    required this.statement,
    required this.evidence,
    this.citationIds = const [],
    this.confidence = 1.0,
  });
}

/// A research report produced by the Research (ATLAS) agent.
class ResearchReport {
  final String id;
  final String query;
  final String summary;
  final String detailedFindings;
  final String strategicImplications;
  final List<KeyInsight> keyInsights;
  final List<String> nextSteps;
  final List<ResearchCitation> citations;
  final AtlasPhase phase;
  final DateTime generatedAt;
  final bool archived;
  final DateTime? archivedAt;

  const ResearchReport({
    required this.id,
    required this.query,
    required this.summary,
    required this.detailedFindings,
    this.strategicImplications = '',
    this.keyInsights = const [],
    this.nextSteps = const [],
    this.citations = const [],
    this.phase = AtlasPhase.discovery,
    required this.generatedAt,
    this.archived = false,
    this.archivedAt,
  });
}
