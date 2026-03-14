// lib/lumara/agents/research/content_brief.dart
//
// Phase 3 Research: handoff object from research pipeline to (future) writing pipeline.
// ContentBrief = title, summary, keyPoints, sources; serialisable for CHRONICLE.
// Can be built from ResearchAgent's ResearchReport via [ContentBrief.fromResearchReport].

import 'package:my_app/lumara/agents/research/research_models.dart';

/// A single source reference in a ContentBrief.
class SourceRef {
  final String title;
  final String url;
  final String domain;

  const SourceRef({
    required this.title,
    required this.url,
    required this.domain,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'url': url,
        'domain': domain,
      };

  factory SourceRef.fromJson(Map<String, dynamic> json) {
    return SourceRef(
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      domain: json['domain'] as String? ?? '',
    );
  }
}

/// Result of the research pipeline: summary, key points, and sources.
/// Returned by ResearchPipeline.run(); consumed by Research UI and (Phase 5) Writing.
class ContentBrief {
  final String title;
  final String summary;
  final List<String> keyPoints;
  final List<SourceRef> sources;
  final DateTime createdAt;
  final String query;

  const ContentBrief({
    required this.title,
    required this.summary,
    this.keyPoints = const [],
    this.sources = const [],
    required this.createdAt,
    required this.query,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'summary': summary,
        'key_points': keyPoints,
        'sources': sources.map((s) => s.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'query': query,
      };

  factory ContentBrief.fromJson(Map<String, dynamic> json) {
    final sourcesRaw = json['sources'] as List<dynamic>? ?? [];
    return ContentBrief(
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      keyPoints: (json['key_points'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      sources: sourcesRaw
          .map((e) => SourceRef.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      query: json['query'] as String? ?? '',
    );
  }

  /// Build a ContentBrief from ResearchAgent's [ResearchReport] so the Research screen
  /// and Outputs can use the same format whether research is run from chat or the Research screen.
  factory ContentBrief.fromResearchReport(ResearchReport report) {
    final keyPoints = report.abstractBullets.isNotEmpty
        ? report.abstractBullets
        : report.keyInsights.map((i) => i.statement).toList();
    final sources = report.citations
        .map((c) => SourceRef(
              title: c.title,
              url: c.url,
              domain: c.source,
            ))
        .toList();
    final title = report.query.length > 60
        ? '${report.query.substring(0, 60)}...'
        : report.query;
    return ContentBrief(
      title: title,
      summary: report.summary,
      keyPoints: keyPoints,
      sources: sources,
      createdAt: report.generatedAt,
      query: report.query,
    );
  }
}
