// lib/lumara/agents/research/chronicle_cross_reference.dart
// Checks CHRONICLE and research artifacts for prior research before running new searches.

import 'research_artifact_repository.dart';
import 'research_models.dart';

/// Cross-references user query with prior research (stored artifacts).
class ChronicleCrossReference {
  final ResearchArtifactRepository _artifactRepo;

  ChronicleCrossReference({ResearchArtifactRepository? artifactRepository})
      : _artifactRepo = artifactRepository ?? ResearchArtifactRepository();

  /// Check if user has researched this topic before; return context and gaps.
  Future<PriorResearchContext> checkPriorResearch({
    required String userId,
    required String query,
    double threshold = 0.7,
    int limit = 10,
  }) async {
    final priorSessions = await _artifactRepo.findSimilar(
      userId: userId,
      query: query,
      threshold: threshold,
      limit: limit,
    );

    final existingSummary = priorSessions.isEmpty
        ? ''
        : priorSessions.map((s) => '${s.query}: ${s.summary}').join('\n\n');

    final existingKnowledge = ExistingKnowledge(summary: existingSummary);

    final gaps = _identifyGaps(query, existingKnowledge);

    return PriorResearchContext(
      hasRelatedResearch: priorSessions.isNotEmpty,
      priorSessions: priorSessions,
      relatedEntries: const [],
      existingKnowledge: existingKnowledge,
      knowledgeGaps: gaps,
    );
  }

  List<String> _identifyGaps(String query, ExistingKnowledge knowledge) {
    if (knowledge.summary.isEmpty) return [query];
    return [query];
  }
}
