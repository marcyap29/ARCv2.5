// Adapter from Research Agent (research/research_models) to UI (agents/models/research_models).

import 'package:my_app/models/phase_models.dart';
import 'package:my_app/lumara/agents/models/research_models.dart' as ui;
import 'package:my_app/lumara/agents/research/research_models.dart' as agent;

/// Convert agent report + sessionId to UI ResearchReport for detail screen.
ui.ResearchReport toUiReport(agent.ResearchReport report, String sessionId) {
  return ui.ResearchReport(
    id: sessionId,
    query: report.query,
    summary: report.summary,
    detailedFindings: report.detailedFindings,
    strategicImplications: report.strategicImplications,
    keyInsights: report.keyInsights
        .map((i) => ui.KeyInsight(
              statement: i.statement,
              evidence: i.evidence,
              citationIds: i.citationIds,
              confidence: i.confidence,
            ))
        .toList(),
    nextSteps: report.nextSteps,
    citations: report.citations
        .map((c) => ui.ResearchCitation(
              id: c.id,
              title: c.title,
              source: c.source,
              url: c.url,
              publishDate: c.publishDate,
            ))
        .toList(),
    phase: _phaseToAtlas(report.phase),
    generatedAt: report.generatedAt,
  );
}

ui.AtlasPhase _phaseToAtlas(PhaseLabel p) {
  switch (p) {
    case PhaseLabel.discovery:
      return ui.AtlasPhase.discovery;
    case PhaseLabel.expansion:
      return ui.AtlasPhase.expansion;
    case PhaseLabel.transition:
      return ui.AtlasPhase.transition;
    case PhaseLabel.consolidation:
      return ui.AtlasPhase.consolidation;
    case PhaseLabel.recovery:
      return ui.AtlasPhase.recovery;
    case PhaseLabel.breakthrough:
      return ui.AtlasPhase.breakthrough;
  }
}
