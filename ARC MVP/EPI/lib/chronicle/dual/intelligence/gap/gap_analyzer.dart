// lib/chronicle/dual/intelligence/gap/gap_analyzer.dart
//
// Gap Analyzer: systematic gap analysis between required and available knowledge.
// Operates READ-ONLY on User Chronicle and LUMARA Chronicle.

import '../../models/chronicle_models.dart';
import '../../repositories/user_chronicle_repository.dart';
import '../../repositories/lumara_chronicle_repository.dart';

class RequiredKnowledge {
  final List<String> entities;
  final List<String> patterns;
  final List<String> causalChains;
  final List<String> temporalContext;

  const RequiredKnowledge({
    this.entities = const [],
    this.patterns = const [],
    this.causalChains = const [],
    this.temporalContext = const [],
  });
}

class CurrentKnowledge {
  final List<String> knownEntities;
  final List<String> identifiedPatterns;
  final List<String> establishedCausality;
  final List<String> timelineEvidence;

  const CurrentKnowledge({
    this.knownEntities = const [],
    this.identifiedPatterns = const [],
    this.establishedCausality = const [],
    this.timelineEvidence = const [],
  });
}

class GapAnalysisResult {
  final RequiredKnowledge requiredKnowledge;
  final CurrentKnowledge currentKnowledge;
  final List<Gap> identifiedGaps;
  final int gapCount;

  const GapAnalysisResult({
    required this.requiredKnowledge,
    required this.currentKnowledge,
    required this.identifiedGaps,
    required this.gapCount,
  });
}

/// Performs gap analysis. READ-ONLY on both chronicles.
class GapAnalyzer {
  GapAnalyzer({
    RequiredKnowledgeExtractor? extractor,
    CurrentKnowledgeAssessor? assessor,
  })  : _extractor = extractor ?? RequiredKnowledgeExtractor(),
        _assessor = assessor ?? CurrentKnowledgeAssessor();

  final RequiredKnowledgeExtractor _extractor;
  final CurrentKnowledgeAssessor _assessor;

  Future<GapAnalysisResult> analyze(
    String query,
    UserChronicleLayer0Result userChronicleResults,
    LumaraInferredResult lumaraIntelligence,
  ) async {
    final required = await _extractor.extractRequired(query);
    final current = await _assessor.assessCurrent(
      required,
      userChronicleResults,
      lumaraIntelligence,
    );
    final gaps = _calculateGaps(required, current);
    return GapAnalysisResult(
      requiredKnowledge: required,
      currentKnowledge: current,
      identifiedGaps: gaps,
      gapCount: gaps.length,
    );
  }

  List<Gap> _calculateGaps(RequiredKnowledge required, CurrentKnowledge current) {
    final gaps = <Gap>[];
    final now = DateTime.now();

    for (final e in required.entities) {
      if (!current.knownEntities.contains(e)) {
        gaps.add(Gap(
          id: 'gap_entity_${e.hashCode}_${now.millisecondsSinceEpoch}',
          type: GapType.context_gap,
          severity: GapSeverity.medium,
          description: 'Unknown entity: $e',
          topic: e,
          requiredFor: 'query_context',
          fillStrategy: GapFillStrategy.clarify,
          priority: 5,
          identifiedAt: now,
        ));
      }
    }

    for (final p in required.patterns) {
      if (!current.identifiedPatterns.any((x) => x.toLowerCase().contains(p.toLowerCase()))) {
        gaps.add(Gap(
          id: 'gap_pattern_${p.hashCode}_${now.millisecondsSinceEpoch}',
          type: GapType.context_gap,
          severity: GapSeverity.medium,
          description: 'Pattern not yet identified: $p',
          topic: p,
          requiredFor: 'query_context',
          fillStrategy: GapFillStrategy.search,
          priority: 5,
          identifiedAt: now,
        ));
      }
    }

    for (final c in required.causalChains) {
      if (!current.establishedCausality.any((x) => x.toLowerCase().contains(c.toLowerCase()))) {
        gaps.add(Gap(
          id: 'gap_causal_${c.hashCode}_${now.millisecondsSinceEpoch}',
          type: GapType.causal_gap,
          severity: GapSeverity.high,
          description: 'Causal understanding missing: $c',
          topic: c,
          requiredFor: 'query_context',
          fillStrategy: GapFillStrategy.clarify,
          priority: 7,
          identifiedAt: now,
        ));
      }
    }

    return gaps;
  }
}

/// Extracts what we need to know from the query.
class RequiredKnowledgeExtractor {
  Future<RequiredKnowledge> extractRequired(String query) async {
    final q = query.toLowerCase();
    final entities = <String>[];
    final patterns = <String>[];
    final causalChains = <String>[];
    final temporalContext = <String>[];

    // Simple heuristic: treat significant words as entities/topics
    final words = q.split(RegExp(r'\s+')).where((w) => w.length > 3).toList();
    for (final w in words) {
      if (!_isStopWord(w)) entities.add(w);
    }

    if (q.contains('why') || q.contains('because') || q.contains('cause')) {
      causalChains.add('causal_understanding');
    }
    if (q.contains('always') || q.contains('every time') || q.contains('pattern')) {
      patterns.add('recurrence');
    }
    if (q.contains('last year') || q.contains('last month') || q.contains('when i was')) {
      temporalContext.add('temporal_context');
    }

    return RequiredKnowledge(
      entities: entities,
      patterns: patterns,
      causalChains: causalChains,
      temporalContext: temporalContext,
    );
  }

  bool _isStopWord(String w) {
    const stop = {'that', 'this', 'with', 'from', 'have', 'been', 'what', 'when', 'where'};
    return stop.contains(w);
  }
}

/// Assesses what we currently know from both chronicles.
class CurrentKnowledgeAssessor {
  Future<CurrentKnowledge> assessCurrent(
    RequiredKnowledge required,
    UserChronicleLayer0Result userChronicle,
    LumaraInferredResult lumaraChronicle,
  ) async {
    final knownEntities = required.entities.where((entity) {
      return userChronicle.entries.any((e) =>
              e.content.toLowerCase().contains(entity.toLowerCase())) ||
          userChronicle.annotations.any((a) =>
              a.content.toLowerCase().contains(entity.toLowerCase()));
    }).toList();

    final identifiedPatterns = required.patterns.where((pattern) {
      return lumaraChronicle.patterns.any((p) =>
          p.description.toLowerCase().contains(pattern.toLowerCase()));
    }).toList();

    final establishedCausality = required.causalChains.where((chain) {
      return lumaraChronicle.causalChains.any((c) =>
          c.trigger.toLowerCase().contains(chain.toLowerCase()) ||
          c.response.toLowerCase().contains(chain.toLowerCase()));
    }).toList();

    final timelineEvidence = required.temporalContext.where((t) {
      return userChronicle.entries.isNotEmpty;
    }).toList();

    return CurrentKnowledge(
      knownEntities: knownEntities,
      identifiedPatterns: identifiedPatterns,
      establishedCausality: establishedCausality,
      timelineEvidence: timelineEvidence,
    );
  }
}
