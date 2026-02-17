// lib/lumara/agents/research/synthesis_engine.dart
// Phase-aware synthesis of research findings with optional timeline context.

import 'package:my_app/models/phase_models.dart';

import 'package:my_app/lumara/agents/services/timeline_context_service.dart';
import 'citation_manager.dart';
import 'research_models.dart';
import 'research_prompts.dart';

typedef LlmGenerate = Future<String> Function({
  required String systemPrompt,
  required String userPrompt,
  int? maxTokens,
});

/// Synthesizes search results into a report with phase- and readiness-aware depth.
/// When [timelineContext] is provided, uses the full Research Agent prompt with timeline integration.
class SynthesisEngine {
  final LlmGenerate _generate;
  final CitationManager _citations = CitationManager();

  SynthesisEngine({required LlmGenerate generate}) : _generate = generate;

  Future<ResearchReport> synthesizeFindings({
    required String originalQuery,
    required List<SearchResult> searchResults,
    required PriorResearchContext priorContext,
    required PhaseLabel currentPhase,
    required double readinessScore,
    ResearchTimelineContext? timelineContext,
    String? researchDepthLabel,
  }) async {
    final depth = _calculateSynthesisDepth(currentPhase, readinessScore);
    final depthLabel = researchDepthLabel ?? _synthesisDepthToLabel(depth);
    final systemPrompt = timelineContext != null
        ? _buildEnhancedPrompt(
            timelineContext: timelineContext,
            query: originalQuery,
            depthLabel: depthLabel,
          )
        : _buildSynthesisPrompt(
            depth: depth,
            phase: currentPhase,
            priorContext: priorContext,
          );
    final context = _prepareContext(searchResults, priorContext);

    int maxTokens = depth == SynthesisDepth.brief ? 500 : (depth == SynthesisDepth.deep ? 2000 : 1200);
    String synthesis;
    try {
      synthesis = await _generate(
        systemPrompt: systemPrompt,
        userPrompt: context,
        maxTokens: maxTokens,
      );
    } catch (e) {
      synthesis = _fallbackSynthesis(originalQuery, searchResults);
    }

    final citations = _citations.buildCitations(searchResults);
    final insights = _extractInsightsSimple(synthesis);

    return ResearchReport(
      query: originalQuery,
      summary: _firstParagraph(synthesis),
      keyInsights: insights,
      detailedFindings: synthesis,
      strategicImplications: '',
      nextSteps: [],
      citations: citations,
      priorKnowledge: priorContext.existingKnowledge,
      knowledgeGapsDiscovered: priorContext.knowledgeGaps,
      searchResults: searchResults,
      generatedAt: DateTime.now(),
      phase: currentPhase,
      depth: depth,
    );
  }

  String _synthesisDepthToLabel(SynthesisDepth depth) {
    switch (depth) {
      case SynthesisDepth.brief:
        return 'quick_scan';
      case SynthesisDepth.moderate:
      case SynthesisDepth.comprehensive:
        return 'standard';
      case SynthesisDepth.deep:
        return 'deep_dive';
    }
  }

  String _buildEnhancedPrompt({
    required ResearchTimelineContext timelineContext,
    required String query,
    required String depthLabel,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final timeEstimate = _timeEstimateForDepth(depthLabel);
    return kResearchAgentSystemPromptTemplate
        .replaceAll('{{TIMELINE_SUMMARY}}', timelineContext.timelineSummary)
        .replaceAll('{{FOCUS_AREAS}}', timelineContext.focusAreas)
        .replaceAll('{{CURRENT_PROJECTS}}', timelineContext.currentProjects)
        .replaceAll('{{PAST_RESEARCH}}', timelineContext.pastResearch)
        .replaceAll('{{CURRENT_PHASE}}', timelineContext.currentPhase)
        .replaceAll('{{PHASE_DESCRIPTION}}', timelineContext.phaseDescription)
        .replaceAll('{{USER_PROMPT}}', query)
        .replaceAll('{{RESEARCH_DEPTH}}', depthLabel)
        .replaceAll('{{QUERY}}', query)
        .replaceAll('{{TIMESTAMP}}', timestamp)
        .replaceAll('{{TIME_ESTIMATE}}', timeEstimate);
  }

  String _timeEstimateForDepth(String depthLabel) {
    switch (depthLabel.toLowerCase()) {
      case 'quick_scan':
        return '5-10 min';
      case 'deep_dive':
        return '45-90 min';
      case 'standard':
      default:
        return '15-30 min';
    }
  }

  SynthesisDepth _calculateSynthesisDepth(PhaseLabel phase, double readiness) {
    if (readiness < 40) return SynthesisDepth.brief;
    if (readiness < 60) return SynthesisDepth.moderate;
    if (readiness < 75) return SynthesisDepth.comprehensive;
    return SynthesisDepth.deep;
  }

  String _buildSynthesisPrompt({
    required SynthesisDepth depth,
    required PhaseLabel phase,
    required PriorResearchContext priorContext,
  }) {
    final depthGuidance = _getDepthGuidance(depth);
    return '''
You are synthesizing research findings for a user in ${phase.name} phase.

## SYNTHESIS DEPTH: ${depth.name}
$depthGuidance

## PRIOR KNOWLEDGE
${priorContext.existingKnowledge.summary.isEmpty ? 'None' : priorContext.existingKnowledge.summary}

## KNOWLEDGE GAPS TO ADDRESS
${priorContext.knowledgeGaps.join('\n')}

## REQUIREMENTS
1. Synthesize the provided findings into a coherent narrative.
2. Build on prior knowledge if any; do not repeat it unnecessarily.
3. Focus on gaps. Cite sources inline as [1], [2], etc. when possible.
4. Adjust complexity to ${depth.name} depth.

## OUTPUT FORMAT
Start with a 2-3 sentence summary, then Key Insights (bullets), then Detailed Findings. End with Recommended Next Steps and list Sources if available.

Generate the synthesis now.
''';
  }

  String _getDepthGuidance(SynthesisDepth depth) {
    switch (depth) {
      case SynthesisDepth.brief:
        return 'Summary: 200 words max. Key insights: 3 bullets. No deep analysis.';
      case SynthesisDepth.moderate:
        return 'Summary: 300-500 words. Key insights: 4-5 bullets. Practical implications.';
      case SynthesisDepth.comprehensive:
        return 'Summary: 500-800 words. Key insights: 5-7 bullets. Strategic analysis.';
      case SynthesisDepth.deep:
        return 'Summary: 800-1200 words. Key insights: 7-10 bullets. Competitive positioning, risks.';
    }
  }

  String _prepareContext(List<SearchResult> searchResults, PriorResearchContext priorContext) {
    final buf = StringBuffer();
    buf.writeln('## Search results to synthesize\n');
    for (final sr in searchResults) {
      buf.writeln('### Query: ${sr.query}');
      for (final s in sr.snippets.take(5)) {
        buf.writeln('- ${s.title}: ${s.snippet}');
        buf.writeln('  URL: ${s.url}');
        if (s.publishDate != null) {
          buf.writeln('  Date: ${s.publishDate}');
        }
      }
      for (final p in sr.fullContent) {
        buf.writeln('Full content (${p.title}): ${p.content.length > 2000 ? p.content.substring(0, 2000) : p.content}...');
      }
      buf.writeln();
    }
    return buf.toString();
  }

  List<Insight> _extractInsightsSimple(String synthesis) {
    final lines = synthesis.split('\n');
    final insights = <Insight>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if ((trimmed.startsWith('- ') || trimmed.startsWith('* ')) && trimmed.length > 20) {
        insights.add(Insight(
          statement: trimmed.replaceFirst(RegExp(r'^[-*]\s*'), ''),
          evidence: '',
          confidence: 0.8,
        ));
      }
      if (insights.length >= 7) break;
    }
    if (insights.isEmpty) {
      insights.add(Insight(statement: _firstParagraph(synthesis), evidence: synthesis, confidence: 0.7));
    }
    return insights;
  }

  String _firstParagraph(String text) {
    final end = text.indexOf('\n\n');
    if (end > 0) return text.substring(0, end).trim();
    return text.length > 300 ? '${text.substring(0, 300)}...' : text;
  }

  String _fallbackSynthesis(String query, List<SearchResult> searchResults) {
    final buf = StringBuffer();
    buf.writeln('Summary: Research on "$query" gathered ${searchResults.length} result sets.');
    for (final sr in searchResults) {
      buf.writeln('\n### ${sr.query}');
      for (final s in sr.snippets.take(3)) {
        buf.writeln('- ${s.title}: ${s.snippet}');
      }
    }
    return buf.toString();
  }
}
