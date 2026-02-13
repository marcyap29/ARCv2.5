import 'dart:math';
import '../models/chronicle_index.dart';
import '../models/dominant_theme.dart';
import '../models/theme_cluster.dart';
import '../models/theme_appearance.dart';
import '../models/pattern_insights.dart';
import '../embeddings/local_embedding_service.dart';
import '../matching/three_stage_matcher.dart';
import '../storage/chronicle_index_storage.dart';
import 'monthly_aggregation_adapter.dart';

/// Builds and maintains cross-temporal pattern index.
/// Core responsibilities:
/// - Extract dominant themes from monthly synthesis
/// - Match themes to existing clusters (deduplication)
/// - Create new clusters for novel themes
/// - Track pattern insights and arcs
class ChronicleIndexBuilder {
  final LocalEmbeddingService _embedder;
  final ThreeStagePatternMatcher _matcher;
  final ChronicleIndexStorage _storage;

  ChronicleIndexBuilder({
    required LocalEmbeddingService embedder,
    required ChronicleIndexStorage storage,
  })  : _embedder = embedder,
        _matcher = ThreeStagePatternMatcher(embedder),
        _storage = storage;

  Future<ChronicleIndex> loadIndex(String userId) async {
    final json = await _storage.read(userId);
    if (json.isEmpty) return ChronicleIndex.empty();
    return ChronicleIndex.fromJson(json);
  }

  Future<void> saveIndex(String userId, ChronicleIndex index) async {
    await _storage.write(userId, index.toJson());
  }

  /// Update index after monthly synthesis.
  Future<void> updateIndexAfterSynthesis({
    required String userId,
    required MonthlyAggregation synthesis,
  }) async {
    // ignore: avoid_print
    print('\n📊 Updating index for ${synthesis.period}');

    var index = await loadIndex(userId);

    final dominantThemes = await _extractDominantThemes(synthesis);
    // ignore: avoid_print
    print('   Found ${dominantThemes.length} dominant themes');

    for (final theme in dominantThemes) {
      // ignore: avoid_print
      print('\n   Processing: "${theme.themeLabel}" '
          '(confidence: ${(theme.confidence * 100).toStringAsFixed(0)}%)');

      final matchResult = await _matcher.findMatch(
        queryTheme: theme,
        index: index,
      );

      index = _handleMatchResult(
        index: index,
        theme: theme,
        matchResult: matchResult,
        synthesis: synthesis,
      );
    }

    index = _recalculateAllInsights(index);
    index = _updateArcTracking(index);
    await saveIndex(userId, index);

    // ignore: avoid_print
    print('\n✓ Index update complete');
    // ignore: avoid_print
    print('   Total clusters: ${index.themeClusters.length}');
    // ignore: avoid_print
    print('   Pending echoes: ${index.pendingEchoes.length}');
    // ignore: avoid_print
    print('   Active arcs: ${index.arcs.length}');
  }

  Future<List<DominantTheme>> _extractDominantThemes(
    MonthlyAggregation synthesis,
  ) async {
    final themes = <DominantTheme>[];

    for (final themeLabel in synthesis.dominantThemes) {
      final summary = _generateThemeSummary(
        themeLabel: themeLabel,
        synthesis: synthesis,
      );

      final embedding = await _embedder.embed(summary);

      themes.add(DominantTheme(
        themeLabel: themeLabel,
        themeSummary: summary,
        embedding: embedding,
        confidence: _calculateThemeConfidence(themeLabel, synthesis),
        evidenceRefs: _findEvidenceEntries(themeLabel, synthesis),
        intensity: synthesis.avgEmotionalIntensity,
        phase: synthesis.dominantPhase,
      ));
    }

    return themes;
  }

  String _generateThemeSummary({
    required String themeLabel,
    required MonthlyAggregation synthesis,
  }) {
    final contextSnippet = synthesis.significantEvents.take(2).join(', ');
    return "Theme '$themeLabel' appeared in ${synthesis.period} "
        "during ${synthesis.dominantPhase} phase. "
        "Context: $contextSnippet";
  }

  ChronicleIndex _handleMatchResult({
    required ChronicleIndex index,
    required DominantTheme theme,
    required MatchResult matchResult,
    required MonthlyAggregation synthesis,
  }) {
    switch (matchResult.confidence) {
      case MatchConfidence.high:
        // ignore: avoid_print
        print('      → AUTO-LINK to "${matchResult.match!.cluster.canonicalLabel}"');
        return _addToExistingCluster(
          index: index,
          cluster: matchResult.match!.cluster,
          theme: theme,
          synthesis: synthesis,
        );

      case MatchConfidence.medium:
        // ignore: avoid_print
        print('      → CANDIDATE ECHO (flagged for review)');
        return _flagCandidateEcho(
          index: index,
          candidateCluster: matchResult.match!.cluster,
          theme: theme,
          similarity: matchResult.match!.similarity,
        );

      case MatchConfidence.none:
        // ignore: avoid_print
        print('      → NEW CLUSTER created');
        return _createNewCluster(
          index: index,
          theme: theme,
          synthesis: synthesis,
        );
    }
  }

  ChronicleIndex _addToExistingCluster({
    required ChronicleIndex index,
    required ThemeCluster cluster,
    required DominantTheme theme,
    required MonthlyAggregation synthesis,
  }) {
    final appearance = ThemeAppearance(
      period: synthesis.period,
      entryIds: theme.evidenceRefs,
      aliasUsed: theme.themeLabel,
      frequency: _calculateThemeFrequency(theme.themeLabel, synthesis),
      phase: theme.phase ?? 'Unknown',
      emotionalIntensity: theme.intensity ?? 0.5,
      context: synthesis.significantEvents,
      rivetTransitions: synthesis.rivetTransitions ?? [],
      resolution: null,
    );

    var updatedCluster = cluster.addAppearance(appearance);
    if (!updatedCluster.aliases.contains(theme.themeLabel)) {
      updatedCluster = updatedCluster.addAlias(theme.themeLabel);
    }

    final updatedLabelMap = {...index.labelToClusterId};
    updatedLabelMap[theme.themeLabel] = cluster.clusterId;

    return index.copyWith(
      themeClusters: {...index.themeClusters, cluster.clusterId: updatedCluster},
      labelToClusterId: updatedLabelMap,
      lastUpdated: DateTime.now(),
    );
  }

  ChronicleIndex _flagCandidateEcho({
    required ChronicleIndex index,
    required ThemeCluster candidateCluster,
    required DominantTheme theme,
    required double similarity,
  }) {
    final echo = PendingEcho(
      id: _generateId(),
      newTheme: theme,
      candidateCluster: candidateCluster,
      similarity: similarity,
      flaggedDate: DateTime.now(),
    );

    return index.copyWith(
      pendingEchoes: {...index.pendingEchoes, echo.id: echo},
      lastUpdated: DateTime.now(),
    );
  }

  ChronicleIndex _createNewCluster({
    required ChronicleIndex index,
    required DominantTheme theme,
    required MonthlyAggregation synthesis,
  }) {
    final clusterId = _generateId();

    final appearance = ThemeAppearance(
      period: synthesis.period,
      entryIds: theme.evidenceRefs,
      aliasUsed: theme.themeLabel,
      frequency: _calculateThemeFrequency(theme.themeLabel, synthesis),
      phase: theme.phase ?? 'Unknown',
      emotionalIntensity: theme.intensity ?? 0.5,
      context: synthesis.significantEvents,
      rivetTransitions: synthesis.rivetTransitions ?? [],
      resolution: null,
    );

    final cluster = ThemeCluster(
      clusterId: clusterId,
      canonicalLabel: theme.themeLabel,
      aliases: [theme.themeLabel],
      appearances: [appearance],
      insights: PatternInsights.empty(),
      canonicalEmbedding: theme.embedding,
      firstSeen: DateTime.now(),
      lastUpdated: DateTime.now(),
    );

    return index.copyWith(
      themeClusters: {...index.themeClusters, clusterId: cluster},
      labelToClusterId: {...index.labelToClusterId, theme.themeLabel: clusterId},
      lastUpdated: DateTime.now(),
    );
  }

  ChronicleIndex _recalculateAllInsights(ChronicleIndex index) {
    final updatedClusters = <String, ThemeCluster>{};

    for (final entry in index.themeClusters.entries) {
      final cluster = entry.value;

      if (cluster.totalAppearances < 2) {
        updatedClusters[entry.key] = cluster;
        continue;
      }

      final insights = _calculatePatternInsights(cluster);

      updatedClusters[entry.key] = ThemeCluster(
        clusterId: cluster.clusterId,
        canonicalLabel: cluster.canonicalLabel,
        aliases: cluster.aliases,
        appearances: cluster.appearances,
        insights: insights,
        canonicalEmbedding: cluster.canonicalEmbedding,
        firstSeen: cluster.firstSeen,
        lastUpdated: DateTime.now(),
      );
    }

    return index.copyWith(
      themeClusters: updatedClusters,
      lastUpdated: DateTime.now(),
    );
  }

  PatternInsights _calculatePatternInsights(ThemeCluster cluster) {
    final appearances = cluster.appearances;

    final recurrenceType = _determineRecurrenceType(appearances);
    final trigger = _detectTrigger(appearances);

    final phases = appearances.map((a) => a.phase).toList();
    final phaseCorrelation = _getMostCommonElement(phases);
    final phaseStrength = phases.isEmpty
        ? 0.0
        : phases.where((p) => p == phaseCorrelation).length / phases.length;

    final durations = appearances
        .where((a) => a.resolution?.daysToResolve != null)
        .map((a) => a.resolution!.daysToResolve!)
        .toList();

    final avgDuration =
        durations.isEmpty ? null : durations.reduce((a, b) => a + b) ~/ durations.length;

    final resolutions = appearances
        .where((a) => a.resolution?.resolved == true)
        .map((a) => a.resolution!.resolutionType ?? '')
        .where((r) => r.isNotEmpty)
        .toList();

    String resolutionConsistency;
    String? primaryResolution;

    if (resolutions.isEmpty) {
      resolutionConsistency = 'none';
    } else {
      final mostCommon = _getMostCommonElement(resolutions);
      final consistency =
          resolutions.where((r) => r == mostCommon).length / resolutions.length;

      if (consistency >= 0.8) {
        resolutionConsistency = 'high';
      } else if (consistency >= 0.5) {
        resolutionConsistency = 'medium';
      } else {
        resolutionConsistency = 'low';
      }
      primaryResolution = mostCommon;
    }

    final confidence = _calculateConfidence(
      appearances.length,
      phaseStrength,
      resolutionConsistency,
    );

    return PatternInsights(
      recurrenceType: recurrenceType,
      trigger: trigger,
      phaseCorrelation: phaseCorrelation,
      phaseCorrelationStrength: phaseStrength,
      typicalDurationDays: avgDuration,
      resolutionConsistency: resolutionConsistency,
      primaryResolution: primaryResolution,
      confidence: confidence,
    );
  }

  String _determineRecurrenceType(List<ThemeAppearance> appearances) {
    if (appearances.length < 3) return 'emerging';

    final milestoneCount = appearances
        .where((a) => a.context.any((c) =>
            c.toLowerCase().contains('launch') ||
            c.toLowerCase().contains('milestone') ||
            c.toLowerCase().contains('release')))
        .length;

    if (milestoneCount >= appearances.length * 0.7) {
      return 'cyclical_milestone';
    }

    if (appearances.length >= 5) return 'chronic_undercurrent';

    final phases = appearances.map((a) => a.phase).toSet();
    if (phases.length == 1) return 'phase_linked';

    return 'sporadic';
  }

  String? _detectTrigger(List<ThemeAppearance> appearances) {
    final allContext = appearances.expand((a) => a.context).toList();
    final keywords = _extractCommonKeywords(allContext);
    return keywords.isNotEmpty ? keywords.first : null;
  }

  List<String> _extractCommonKeywords(List<String> contexts) {
    if (contexts.isEmpty) return [];

    final wordCounts = <String, int>{};

    for (final context in contexts) {
      final words = context.toLowerCase().split(RegExp(r'\s+'));
      for (final word in words) {
        if (word.length > 3) {
          wordCounts[word] = (wordCounts[word] ?? 0) + 1;
        }
      }
    }

    final threshold = contexts.length / 2;
    final entries = wordCounts.entries
        .where((e) => e.value >= threshold)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => e.key).toList();
  }

  String _getMostCommonElement(List<String> elements) {
    if (elements.isEmpty) return '';

    final counts = <String, int>{};
    for (final element in elements) {
      counts[element] = (counts[element] ?? 0) + 1;
    }

    return counts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  double _calculateConfidence(
    int appearances,
    double phaseStrength,
    String resolutionConsistency,
  ) {
    final appearanceScore = (appearances / 10).clamp(0.0, 1.0);
    final phaseScore = phaseStrength;
    final resolutionScore = resolutionConsistency == 'high'
        ? 1.0
        : resolutionConsistency == 'medium'
            ? 0.6
            : resolutionConsistency == 'low'
                ? 0.3
                : 0.0;

    return (appearanceScore * 0.3 + phaseScore * 0.3 + resolutionScore * 0.4);
  }

  ChronicleIndex _updateArcTracking(ChronicleIndex index) {
    final updatedArcs = <String, UnresolvedArc>{};

    for (final cluster in index.themeClusters.values) {
      if (cluster.totalAppearances >= 5) {
        final unresolvedCount =
            cluster.appearances.where((a) => a.inProgress).length;

        if (unresolvedCount >= 4) {
          final intensities =
              cluster.appearances.map((a) => a.emotionalIntensity).toList();

          final arc = UnresolvedArc(
            clusterId: cluster.clusterId,
            firstSeen: cluster.firstSeen,
            totalAppearances: cluster.totalAppearances,
            intensityOverTime: intensities,
            attemptedResolutions: _extractAttemptedResolutions(cluster),
            currentStatus: _determineArcStatus(intensities),
            recommendation: _generateArcRecommendation(cluster),
          );

          updatedArcs[cluster.clusterId] = arc;
        }
      }
    }

    return index.copyWith(arcs: updatedArcs, lastUpdated: DateTime.now());
  }

  List<AttemptedResolution> _extractAttemptedResolutions(ThemeCluster cluster) {
    return cluster.appearances
        .where((a) => a.resolution != null)
        .map((a) => AttemptedResolution(
              period: a.period,
              approach: a.resolution!.resolutionType ?? 'unknown',
              success: a.resolution!.resolved,
              outcome: a.context.isNotEmpty ? a.context.first : null,
            ))
        .toList();
  }

  String _determineArcStatus(List<double> intensities) {
    if (intensities.length < 3) return 'active_concern';

    final recent = intensities.sublist(intensities.length - 3);
    final isIncreasing = recent[2] > recent[0];

    if (isIncreasing && recent[2] > 0.7) {
      return 'escalating';
    } else if (recent.every((i) => i < 0.3)) {
      return 'dormant';
    } else {
      return 'active_concern';
    }
  }

  String? _generateArcRecommendation(ThemeCluster cluster) {
    if (cluster.insights.resolutionConsistency == 'none') {
      return 'This is a chronic undercurrent without consistent resolution. '
          'Consider dedicated strategic attention rather than tactical adjustments.';
    }
    return null;
  }

  double _calculateThemeConfidence(String themeLabel, MonthlyAggregation synthesis) {
    return 0.8;
  }

  List<String> _findEvidenceEntries(String themeLabel, MonthlyAggregation synthesis) {
    return List<String>.from(synthesis.sourceEntryIds);
  }

  int _calculateThemeFrequency(String themeLabel, MonthlyAggregation synthesis) {
    final content = synthesis.content.toLowerCase();
    final themeWords = themeLabel.toLowerCase().split(' ');

    int count = 0;
    for (final word in themeWords) {
      count += word.allMatches(content).length;
    }
    return count;
  }

  String _generateId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = random.nextInt(999999);
    return '${timestamp}_$randomPart';
  }
}
