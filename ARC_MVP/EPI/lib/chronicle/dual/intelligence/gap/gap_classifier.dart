// lib/chronicle/dual/intelligence/gap/gap_classifier.dart
//
// Classifies gaps into: searchable, clarification, inferrable.

import '../../models/chronicle_models.dart';

class ClassifiedGaps {
  final List<Gap> noGaps;
  final List<Gap> searchableGaps;
  final List<Gap> clarificationGaps;
  final List<Gap> inferrableGaps;

  const ClassifiedGaps({
    this.noGaps = const [],
    this.searchableGaps = const [],
    this.clarificationGaps = const [],
    this.inferrableGaps = const [],
  });
}

/// Classifies gaps for fill strategy.
class GapClassifier {
  Future<ClassifiedGaps> classify(List<Gap> gaps, String userId) async {
    final searchable = <Gap>[];
    final clarification = <Gap>[];
    final inferrable = <Gap>[];

    for (final gap in gaps) {
      final kind = await _classifyGap(gap, userId);
      switch (kind) {
        case GapClassification.searchable:
          searchable.add(gap);
          break;
        case GapClassification.clarification:
          clarification.add(gap);
          break;
        case GapClassification.inferrable:
          inferrable.add(gap);
          break;
      }
    }

    return ClassifiedGaps(
      searchableGaps: searchable,
      clarificationGaps: clarification,
      inferrableGaps: inferrable,
    );
  }

  Future<GapClassification> _classifyGap(Gap gap, String userId) async {
    if (gap.type == GapType.temporal_gap || gap.type == GapType.historical_gap) {
      return GapClassification.searchable;
    }
    if (gap.type == GapType.causal_gap) {
      return GapClassification.clarification;
    }
    if (gap.type == GapType.motivation_gap) {
      return GapClassification.clarification;
    }
    if (gap.type == GapType.context_gap && _requiresInternalState(gap)) {
      return GapClassification.clarification;
    }
    if (gap.fillStrategy == GapFillStrategy.search) {
      return GapClassification.searchable;
    }
    if (gap.fillStrategy == GapFillStrategy.infer) {
      return GapClassification.inferrable;
    }
    return GapClassification.clarification;
  }

  bool _requiresInternalState(Gap gap) {
    final d = gap.description.toLowerCase();
    return d.contains('feel') || d.contains('think') || d.contains('want');
  }
}

enum GapClassification { searchable, clarification, inferrable }
