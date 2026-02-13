import 'package:flutter/foundation.dart';
import '../models/dominant_theme.dart';
import '../models/theme_cluster.dart';
import '../models/chronicle_index.dart';
import '../embeddings/embedding_service.dart';

/// Three-stage pattern matching to prevent false positives.
/// Stage 1: Cheap keyword filter (1ms)
/// Stage 2: Semantic similarity via embeddings (50-100ms)
/// Stage 3: Confirmation logic with supporting evidence
class ThreeStagePatternMatcher {
  final EmbeddingService _embedder;

  ThreeStagePatternMatcher(this._embedder);

  Future<MatchResult> findMatch({
    required DominantTheme queryTheme,
    required ChronicleIndex index,
  }) async {
    // ignore: avoid_print
    print('🔍 Three-stage matching for: "${queryTheme.themeLabel}"');

    // STAGE 1: Cheap keyword filter
    final keywordCandidates = _keywordFilter(queryTheme, index);

    if (keywordCandidates.isEmpty) {
      // ignore: avoid_print
      print('   Stage 1: No keyword candidates');
      return MatchResult.noMatch();
    }

    // ignore: avoid_print
    print('   Stage 1: ${keywordCandidates.length} keyword candidates');

    // STAGE 2: Semantic similarity via embeddings
    final semanticScores = await _semanticMatch(
      queryEmbedding: queryTheme.embedding,
      candidates: keywordCandidates,
    );

    if (semanticScores.isEmpty) {
      // ignore: avoid_print
      print('   Stage 2: No semantic matches');
      return MatchResult.noMatch();
    }

    final best = semanticScores.first;
    // ignore: avoid_print
    print(
      '   Stage 2: Best match "${best.cluster.canonicalLabel}" '
      '(${(best.similarity * 100).toStringAsFixed(0)}%)',
    );

    // STAGE 3: Confirmation logic
    final shouldMerge = _confirmMerge(
      newTheme: queryTheme,
      candidateCluster: best.cluster,
      similarity: best.similarity,
    );

    if (best.similarity >= 0.80) {
      // ignore: avoid_print
      print('   Stage 3: High confidence → AUTO-LINK');
      return MatchResult.autoLink(best);
    } else if (best.similarity >= 0.65 && shouldMerge) {
      // ignore: avoid_print
      print('   Stage 3: Medium confidence + evidence → AUTO-LINK');
      return MatchResult.autoLink(best);
    } else if (best.similarity >= 0.65) {
      // ignore: avoid_print
      print('   Stage 3: Medium confidence, no evidence → CANDIDATE ECHO');
      return MatchResult.candidateEcho(best);
    } else {
      // ignore: avoid_print
      print('   Stage 3: Low confidence → NO MATCH');
      return MatchResult.noMatch();
    }
  }

  List<ThemeCluster> _keywordFilter(
    DominantTheme query,
    ChronicleIndex index,
  ) {
    final queryWords = _normalizeText(query.themeLabel).split(' ').toSet();
    final querySummaryWords =
        _normalizeText(query.themeSummary).split(' ').toSet();
    final allQueryWords = queryWords.union(querySummaryWords);

    return index.themeClusters.values.where((cluster) {
      final canonicalWords =
          _normalizeText(cluster.canonicalLabel).split(' ').toSet();
      if (allQueryWords.intersection(canonicalWords).isNotEmpty) return true;

      for (final alias in cluster.aliases) {
        final aliasWords = _normalizeText(alias).split(' ').toSet();
        if (allQueryWords.intersection(aliasWords).isNotEmpty) return true;
      }

      return false;
    }).toList();
  }

  Future<List<SemanticMatch>> _semanticMatch({
    required List<double> queryEmbedding,
    required List<ThemeCluster> candidates,
  }) async {
    final matches = <SemanticMatch>[];

    for (final candidate in candidates) {
      final similarity = _embedder.cosineSimilarity(
        queryEmbedding,
        candidate.canonicalEmbedding,
      );

      if (similarity >= 0.60) {
        matches.add(SemanticMatch(
          cluster: candidate,
          similarity: similarity,
        ));
      }
    }

    matches.sort((a, b) => b.similarity.compareTo(a.similarity));
    return matches;
  }

  bool _confirmMerge({
    required DominantTheme newTheme,
    required ThemeCluster candidateCluster,
    required double similarity,
  }) {
    if (similarity >= 0.80) return true;

    if (similarity >= 0.65) {
      return _hasSharedEvidence(newTheme, candidateCluster);
    }

    return false;
  }

  bool _hasSharedEvidence(
    DominantTheme newTheme,
    ThemeCluster cluster,
  ) {
    if (newTheme.phase != null &&
        cluster.insights.phaseCorrelation == newTheme.phase) {
      // ignore: avoid_print
      print('      ✓ Shared phase: ${newTheme.phase}');
      return true;
    }

    if (cluster.appearances.isEmpty) return false;
    final lastAppearance = cluster.appearances.last;
    if (_hasSimilarContext(newTheme.themeSummary, lastAppearance.context)) {
      // ignore: avoid_print
      print('      ✓ Similar context detected');
      return true;
    }

    if (newTheme.intensity != null &&
        (newTheme.intensity! - lastAppearance.emotionalIntensity).abs() < 0.3) {
      // ignore: avoid_print
      print('      ✓ Similar intensity');
      return true;
    }

    // ignore: avoid_print
    print('      ✗ No shared evidence');
    return false;
  }

  bool _hasSimilarContext(String newSummary, List<String> existingContext) {
    if (existingContext.isEmpty) return false;

    final newWords = _normalizeText(newSummary).split(' ').toSet();
    final contextWords =
        existingContext.expand((c) => _normalizeText(c).split(' ')).toSet();

    final overlap = newWords.intersection(contextWords).length;
    return overlap >= 2;
  }

  String _normalizeText(String text) {
    return text.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
  }
}

@immutable
class MatchResult {
  final MatchConfidence confidence;
  final SemanticMatch? match;

  const MatchResult({
    required this.confidence,
    this.match,
  });

  factory MatchResult.autoLink(SemanticMatch match) => MatchResult(
        confidence: MatchConfidence.high,
        match: match,
      );

  factory MatchResult.candidateEcho(SemanticMatch match) => MatchResult(
        confidence: MatchConfidence.medium,
        match: match,
      );

  factory MatchResult.noMatch() => const MatchResult(
        confidence: MatchConfidence.none,
      );
}

@immutable
class SemanticMatch {
  final ThemeCluster cluster;
  final double similarity;

  const SemanticMatch({
    required this.cluster,
    required this.similarity,
  });
}

enum MatchConfidence { high, medium, none }
