import 'package:my_app/chronicle/core/chronicle_repos.dart';
import 'package:my_app/chronicle/models/chronicle_aggregation.dart';
import 'package:my_app/chronicle/models/chronicle_layer.dart';
import 'package:my_app/chronicle/storage/aggregation_repository.dart';
import 'package:my_app/chronicle/storage/layer0_repository.dart';
import 'package:my_app/lumara/agents/writing/writing_models.dart';

/// Builds thematic context from CHRONICLE aggregations and Layer0 for the Writing Agent.
class ThemeTracker {
  // ignore: unused_field - reserved for future Layer0 topic query
  final Layer0Repository _layer0Repo;
  final AggregationRepository _aggregationRepo;

  ThemeTracker({
    Layer0Repository? layer0Repository,
    AggregationRepository? aggregationRepository,
  })  : _layer0Repo = layer0Repository ?? ChronicleRepos.layer0,
        _aggregationRepo = aggregationRepository ?? ChronicleRepos.aggregation;

  /// Get theme context for a content topic (used to build system prompt).
  Future<ThemeContext> getThemeContext({
    required String userId,
    required String contentTopic,
  }) async {
    final primaryThemes = <String>[];
    final relatedMoments = <BiographicalMoment>[];
    final establishedPositions = <String, String>{};
    final recurrentMetaphors = <String>[];

    // Load recent monthly aggregations (last 6)
    final monthlyPeriods = await _aggregationRepo.listPeriods(ChronicleLayer.monthly);
    final recentMonths = monthlyPeriods.take(6).toList();
    final topicLower = contentTopic.toLowerCase();
    final topicWords = topicLower.split(RegExp(r'\s+')).where((w) => w.length > 3).toList();

    for (final period in recentMonths) {
      final agg = await _aggregationRepo.loadLayer(
        userId: userId,
        layer: ChronicleLayer.monthly,
        period: period,
      );
      if (agg == null) continue;
      _extractThemesFromContent(agg.content, primaryThemes);
      _extractBiographicalMoments(agg, contentTopic, topicWords, relatedMoments);
      _extractPositions(agg.content, topicWords, establishedPositions);
      _extractMetaphors(agg.content, recurrentMetaphors);
    }

    // Deduplicate and cap
    final themes = primaryThemes.toSet().toList()..sort();
    final moments = relatedMoments.take(10).toList();
    final metaphors = recurrentMetaphors.toSet().toList();

    return ThemeContext(
      primaryThemes: themes.take(15).toList(),
      relatedMoments: moments,
      establishedPositions: establishedPositions,
      recurrentMetaphors: metaphors.take(10).toList(),
    );
  }

  void _extractThemesFromContent(String content, List<String> out) {
    final words = content.toLowerCase().split(RegExp(r'[\s\n.,;:!?()\[\]-]+'));
    final stop = {'the', 'and', 'for', 'that', 'this', 'with', 'from', 'have', 'has', 'had', 'was', 'were', 'are', 'is', 'been', 'being', 'will', 'would', 'could', 'should', 'can', 'may', 'might'};
    final freq = <String, int>{};
    for (final w in words) {
      if (w.length < 4 || stop.contains(w)) continue;
      freq[w] = (freq[w] ?? 0) + 1;
    }
    final sorted = freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sorted.take(20)) {
      out.add(e.key);
    }
  }

  void _extractBiographicalMoments(
    ChronicleAggregation agg,
    String contentTopic,
    List<String> topicWords,
    List<BiographicalMoment> out,
  ) {
    final content = agg.content;
    if (topicWords.isEmpty) return;
    for (final word in topicWords) {
      if (!content.toLowerCase().contains(word)) continue;
    }
    final year = agg.period.length == 4 ? int.tryParse(agg.period) : null;
    final month = agg.period.length == 7 ? int.tryParse(agg.period.split('-').last) : null;
    final date = DateTime(year ?? DateTime.now().year, month ?? 1, 1);
    final snippet = content.length > 200 ? '${content.substring(0, 200)}...' : content;
    out.add(BiographicalMoment(summary: snippet.trim(), date: date));
    return;
  }

  void _extractPositions(String content, List<String> topicWords, Map<String, String> out) {
    if (topicWords.isEmpty) return;
    for (final word in topicWords) {
      if (content.toLowerCase().contains(word) && !out.containsKey(word)) {
        out[word] = 'Referenced in journal narrative';
      }
    }
  }

  void _extractMetaphors(String content, List<String> out) {
    const metaphors = ['arc reactor', 'jarvis', 'chronicle', 'surveillance', 'collaboration', 'temporal intelligence', 'memory architecture'];
    final lower = content.toLowerCase();
    for (final m in metaphors) {
      if (lower.contains(m)) out.add(m);
    }
  }
}
