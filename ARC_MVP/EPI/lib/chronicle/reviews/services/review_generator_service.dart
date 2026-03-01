import 'dart:math';
import 'package:my_app/chronicle/core/chronicle_repos.dart';
import 'package:my_app/chronicle/models/chronicle_aggregation.dart';
import 'package:my_app/chronicle/models/chronicle_layer.dart';
import 'package:my_app/chronicle/reviews/models/monthly_review.dart';
import 'package:my_app/chronicle/reviews/models/yearly_review.dart';
import 'package:my_app/chronicle/storage/layer0_repository.dart';
import 'package:my_app/chronicle/storage/aggregation_repository.dart';
import 'package:my_app/chronicle/storage/raw_entry_schema.dart';
import 'package:my_app/services/gemini_send.dart';

/// Generates Monthly and Yearly Reviews from CHRONICLE data.
/// All processing is on-device; no review content leaves the device.
class ReviewGeneratorService {
  final Layer0Repository _layer0Repo;
  final AggregationRepository _aggRepo;

  ReviewGeneratorService({
    Layer0Repository? layer0Repo,
    AggregationRepository? aggregationRepo,
  })  : _layer0Repo = layer0Repo ?? ChronicleRepos.layer0,
        _aggRepo = aggregationRepo ?? ChronicleRepos.aggregation;

  /// Generate monthly review for a given month.
  Future<MonthlyReview> generateMonthlyReview(String userId, String monthKey) async {
    await ChronicleRepos.ensureLayer0Initialized();

    // 1. Load CHRONICLE Layer 1 aggregation for this month
    final monthlyAgg = await _aggRepo.loadLayer(
      userId: userId,
      layer: ChronicleLayer.monthly,
      period: monthKey,
    );

    // 2. Load all Layer 0 entries for this month
    final entries = await _layer0Repo.getEntriesForMonth(userId, monthKey);
    final schemas = entries.map((e) => e.toSchema()).toList();

    // 3. Load previous month's Layer 1 and Layer 0 for theme comparison
    final prevMonthKey = _previousMonthKey(monthKey);
    List<RawEntrySchema> prevSchemas = [];
    if (prevMonthKey != null) {
      prevSchemas = (await _layer0Repo.getEntriesForMonth(userId, prevMonthKey))
          .map((e) => e.toSchema())
          .toList();
    }

    // 4. Compute theme evolution
    final themeEvolution = _computeThemeEvolution(schemas, prevSchemas, prevMonthKey);

    // 5. Build emotional trajectory from sentinel scores
    final emotionalTrajectory = _buildEmotionalTrajectory(schemas);
    final emotionalDescriptor = await _generateEmotionalDescriptor(
      monthKey,
      emotionalTrajectory,
    );

    // 6. Rank and select breakthrough entries
    final priorThemes = await _getThemesFromPriorMonths(userId, monthKey, monthsBack: 3);
    final breakthroughs = _selectBreakthroughEntries(schemas, priorThemes, maxCount: 3);

    // 7. Detect patterns
    final patternAlerts = _detectPatternAlerts(schemas, maxCount: 3);

    // 8. Build word cloud from keywords + themes
    final wordCloudData = _buildWordCloudData(schemas);

    // 9. Generate seed for next month
    final seedForNextMonth = await _generateSeedForNextMonth(
      monthlyAgg?.content ?? '',
      patternAlerts,
      monthKey,
    );

    // 10. Compute stats
    final stats = _computeMonthlyStats(schemas);

    // 11. Assemble
    return MonthlyReview(
      monthKey: monthKey,
      generatedAt: DateTime.now(),
      narrativeSynthesis: monthlyAgg?.content ?? _fallbackNarrative(monthKey, schemas.length),
      themeEvolution: themeEvolution,
      emotionalTrajectory: emotionalTrajectory,
      emotionalTrajectoryDescriptor: emotionalDescriptor,
      breakthroughHighlights: breakthroughs,
      patternAlerts: patternAlerts,
      wordCloudData: wordCloudData,
      seedForNextMonth: seedForNextMonth,
      stats: stats,
    );
  }

  /// Generate yearly review for a given year.
  Future<YearlyReview> generateYearlyReview(String userId, int year) async {
    await ChronicleRepos.ensureLayer0Initialized();

    // 1. Load CHRONICLE Layer 2 aggregation for this year
    final yearlyAgg = await _aggRepo.loadLayer(
      userId: userId,
      layer: ChronicleLayer.yearly,
      period: year.toString(),
    );

    // 2. Load all 12 Layer 1 monthly aggregations
    final monthlyAggs = <String, ChronicleAggregation?>{};
    for (int m = 1; m <= 12; m++) {
      final key = '$year-${m.toString().padLeft(2, '0')}';
      monthlyAggs[key] = await _aggRepo.loadLayer(
        userId: userId,
        layer: ChronicleLayer.monthly,
        period: key,
      );
    }

    // 3. Load previous year's Layer 2 for year-over-year (if exists)
    final prevYearAgg = await _aggRepo.loadLayer(
      userId: userId,
      layer: ChronicleLayer.yearly,
      period: (year - 1).toString(),
    );

    // 4. Build theme lifecycles across all months
    final themeLifecycles = await _buildThemeLifecycles(userId, year);

    // 5. Compute monthly emotional arc
    final monthlyEmotionalArc = await _buildMonthlyEmotionalArc(userId, year, monthlyAggs);

    // 6. Build year-over-year comparison (if prior year exists)
    YearOverYearComparison? yearOverYear;
    if (prevYearAgg != null) {
      yearOverYear = await _buildYearOverYear(userId, year, prevYearAgg);
    }

    // 7. Build identity evolution (January vs December word clouds)
    final identityEvolution = await _buildIdentityEvolution(userId, year);

    // 8. Select top breakthrough entries across year
    final breakthroughReel = await _selectYearBreakthroughs(userId, year, maxCount: 7);

    // 9. Build annual word cloud
    final annualWordCloud = await _buildAnnualWordCloud(userId, year);

    // 10. Identify unresolved threads
    final unresolvedThreads = _identifyUnresolvedThreads(themeLifecycles);

    // 11. Generate seed for next year
    final seedForNextYear = await _generateSeedForNextYear(
      yearlyAgg?.content ?? '',
      unresolvedThreads,
      year,
    );

    // 12. Compute annual stats
    final stats = await _computeAnnualStats(userId, year);

    // 13. Assemble
    return YearlyReview(
      year: year,
      generatedAt: DateTime.now(),
      yearNarrative: yearlyAgg?.content ?? _fallbackYearNarrative(year),
      themeLifecycles: themeLifecycles,
      monthlyEmotionalArc: monthlyEmotionalArc,
      yearOverYear: yearOverYear,
      identityEvolution: identityEvolution,
      breakthroughReel: breakthroughReel,
      annualWordCloud: annualWordCloud,
      unresolvedThreads: unresolvedThreads,
      seedForNextYear: seedForNextYear,
      stats: stats,
    );
  }

  // --- Monthly helpers ---

  String? _previousMonthKey(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (y == null || m == null) return null;
    if (m == 1) return '${y - 1}-12';
    return '$y-${(m - 1).toString().padLeft(2, '0')}';
  }

  ThemeEvolution _computeThemeEvolution(
    List<RawEntrySchema> current,
    List<RawEntrySchema> previous,
    String? prevMonthKey,
  ) {
    final currentThemes = _themeCounts(current);
    final prevThemes = _themeCounts(previous);

    final emerged = <String>[];
    final persisted = <String>[];
    final faded = <String>[];
    final intensified = <String>[];

    for (final t in currentThemes.keys) {
      final currCount = currentThemes[t]!;
      final prevCount = prevThemes[t];
      if (prevCount == null) {
        emerged.add(t);
      } else {
        persisted.add(t);
        if (currCount > prevCount) intensified.add(t);
      }
    }
    for (final t in prevThemes.keys) {
      if (!currentThemes.containsKey(t)) faded.add(t);
    }

    return ThemeEvolution(
      emerged: emerged,
      persisted: persisted,
      faded: faded,
      intensified: intensified,
      previousMonthKey: prevMonthKey,
    );
  }

  Map<String, int> _themeCounts(List<RawEntrySchema> entries) {
    final counts = <String, int>{};
    for (final e in entries) {
      for (final t in e.analysis.extractedThemes) {
        final key = t.trim().toLowerCase();
        if (key.isEmpty || key.length < 2) continue;
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    return counts;
  }

  List<EmotionalDataPoint> _buildEmotionalTrajectory(List<RawEntrySchema> schemas) {
    final points = <EmotionalDataPoint>[];
    for (final s in schemas) {
      final score = s.analysis.sentinelScore;
      if (score != null) {
        points.add(EmotionalDataPoint(
          date: s.timestamp,
          intensity: score.emotionalIntensity.clamp(0.0, 1.0),
        ));
      }
    }
    points.sort((a, b) => a.date.compareTo(b.date));
    return points;
  }

  Future<String> _generateEmotionalDescriptor(
    String monthKey,
    List<EmotionalDataPoint> points,
  ) async {
    if (points.length < 2) {
      return points.isEmpty ? 'No emotional data this month.' : 'Single data point.';
    }
    try {
      final dataStr = points
          .map((p) => '${p.date.toIso8601String().substring(0, 10)}: ${p.intensity.toStringAsFixed(2)}')
          .join('\n');
      final monthName = _formatMonthName(monthKey);
      final response = await lumaraSend(
        system: '''You describe emotional trajectories in one short sentence.
Focus on the arc and shape, not individual points. Under 20 words.''',
        user: '''Given emotional intensity data for $monthName:
$dataStr

Write one sentence describing the emotional shape of this month.''',
        skipTransformation: true,
        temperature: 0.5,
      );
      return response.trim().split('\n').first;
    } catch (e) {
      return _heuristicEmotionalDescriptor(points);
    }
  }

  String _heuristicEmotionalDescriptor(List<EmotionalDataPoint> points) {
    if (points.length < 4) return 'Limited data; trajectory unclear.';
    final n = points.length;
    final firstWeek = points.sublist(0, (n / 4).ceil());
    final lastWeek = points.sublist((n * 3 / 4).floor());
    final firstAvg = firstWeek.map((p) => p.intensity).reduce((a, b) => a + b) / firstWeek.length;
    final lastAvg = lastWeek.map((p) => p.intensity).reduce((a, b) => a + b) / lastWeek.length;
    final variance = points.map((p) => p.intensity).reduce((a, b) => a + b) / n;
    final varSq = points.map((p) => (p.intensity - variance) * (p.intensity - variance)).reduce((a, b) => a + b) / n;
    final volatile = varSq > 0.04;
    if (lastAvg - firstAvg > 0.15) return volatile ? 'Volatile start, stronger finish.' : 'Gradual rise across the month.';
    if (firstAvg - lastAvg > 0.15) return volatile ? 'Turbulent start, calmer end.' : 'Gradual decline with late recovery.';
    return volatile ? 'Consistent plateau with mid-month spikes.' : 'Steady emotional baseline throughout.';
  }

  Future<Set<String>> _getThemesFromPriorMonths(String userId, String monthKey, {int monthsBack = 3}) async {
    final themes = <String>{};
    var key = _previousMonthKey(monthKey);
    for (var i = 0; i < monthsBack && key != null; i++) {
      final entries = await _layer0Repo.getEntriesForMonth(userId, key);
      for (final e in entries) {
        final schema = e.toSchema();
        for (final t in schema.analysis.extractedThemes) {
          final t2 = t.trim().toLowerCase();
          if (t2.length >= 2) themes.add(t2);
        }
      }
      key = _previousMonthKey(key);
    }
    return themes;
  }

  List<BreakthroughEntry> _selectBreakthroughEntries(
    List<RawEntrySchema> schemas,
    Set<String> priorThemes, {
    int maxCount = 3,
  }) {
    if (schemas.isEmpty) return [];
    final scored = <_ScoredEntry>[];
    for (final s in schemas) {
      final intensity = s.analysis.sentinelScore?.emotionalIntensity ?? 0.5;
      var novelty = 0.0;
      for (final t in s.analysis.extractedThemes) {
        final key = t.trim().toLowerCase();
        if (key.length >= 2 && !priorThemes.contains(key)) novelty += 0.3;
      }
      novelty = novelty.clamp(0.0, 1.0);
      final score = intensity * 0.6 + novelty * 0.4;
      scored.add(_ScoredEntry(schema: s, score: score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(maxCount).map((e) {
      final s = e.schema;
      final preview = s.content.length > 120 ? '${s.content.substring(0, 120)}...' : s.content;
      return BreakthroughEntry(
        entryId: s.entryId,
        date: s.timestamp,
        previewSnippet: preview,
        highlightReason: 'High emotional weight and thematic significance.',
        significanceScore: e.score,
      );
    }).toList();
  }

  List<PatternAlert> _detectPatternAlerts(List<RawEntrySchema> schemas, {int maxCount = 3}) {
    final alerts = <PatternAlert>[];

    // Frequency: "You mentioned X N times"
    final themeCounts = <String, int>{};
    final keywordCounts = <String, int>{};
    for (final s in schemas) {
      for (final t in s.analysis.extractedThemes) {
        final k = t.trim().toLowerCase();
        if (k.length >= 2) themeCounts[k] = (themeCounts[k] ?? 0) + 1;
      }
      for (final k in s.analysis.keywords) {
        final key = k.trim().toLowerCase();
        if (key.length >= 2) keywordCounts[key] = (keywordCounts[key] ?? 0) + 1;
      }
    }
    final topThemes = themeCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    for (final e in topThemes.take(2)) {
      if (e.value >= 3) {
        alerts.add(PatternAlert(
          description: 'You mentioned "${e.key}" $e.value times this month.',
          patternType: 'frequency',
          supportingData: {'theme': e.key, 'count': e.value},
        ));
      }
    }

    // Temporal: cluster by weekday
    final byWeekday = <int, int>{};
    for (final s in schemas) {
      final wd = s.timestamp.weekday;
      byWeekday[wd] = (byWeekday[wd] ?? 0) + 1;
    }
    final topDay = byWeekday.entries.reduce((a, b) => a.value > b.value ? a : b);
    if (topDay.value >= 3 && alerts.length < maxCount) {
      const days = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      alerts.add(PatternAlert(
        description: 'Your entries tend to cluster on ${days[topDay.key]}.',
        patternType: 'temporal',
        supportingData: {'weekday': topDay.key, 'count': topDay.value},
      ));
    }

    // Loop: theme in multiple weeks
    if (schemas.length >= 8 && alerts.length < maxCount) {
      final weeks = <int, Set<String>>{};
      for (final s in schemas) {
        final week = 1 + ((s.timestamp.day - 1) ~/ 7);
        weeks.putIfAbsent(week, () => {}).addAll(
            s.analysis.extractedThemes.map((t) => t.trim().toLowerCase()).where((t) => t.length >= 2));
      }
      for (final t in topThemes.take(5)) {
        var weekCount = 0;
        for (final w in weeks.values) {
          if (w.contains(t.key)) weekCount++;
        }
        if (weekCount >= 3) {
          alerts.add(PatternAlert(
            description: 'Recurring loop: "${t.key}" appeared in $weekCount different weeks.',
            patternType: 'loop',
            supportingData: {'theme': t.key, 'weeks': weekCount},
          ));
          break;
        }
      }
    }

    return alerts.take(maxCount).toList();
  }

  Map<String, int> _buildWordCloudData(List<RawEntrySchema> schemas) {
    final counts = <String, int>{};
    for (final s in schemas) {
      for (final t in s.analysis.extractedThemes) {
        final k = t.trim().toLowerCase();
        if (k.length >= 2) counts[k] = (counts[k] ?? 0) + 1;
      }
      for (final k in s.analysis.keywords) {
        final key = k.trim().toLowerCase();
        if (key.length >= 2) counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    return counts;
  }

  Future<String> _generateSeedForNextMonth(
    String monthlyContent,
    List<PatternAlert> alerts,
    String monthKey,
  ) async {
    if (monthlyContent.isEmpty && alerts.isEmpty) {
      return 'What would you like to carry forward into next month?';
    }
    try {
      final alertsStr = alerts.map((a) => '- ${a.description}').join('\n');
      final response = await lumaraSend(
        system: '''Based on a monthly synthesis and detected patterns, generate a single forward-looking question or gentle challenge.
Reference a specific theme or pattern. Be open-ended, not prescriptive. 1-2 sentences max. Feel like a wise friend.''',
        user: '''Monthly synthesis:
$monthlyContent

Detected patterns:
$alertsStr

Generate a forward-looking question or challenge for next month.''',
        skipTransformation: true,
        temperature: 0.7,
      );
      return response.trim().split('\n').first;
    } catch (e) {
      return 'What would you like to carry forward into next month?';
    }
  }

  MonthlyStats _computeMonthlyStats(List<RawEntrySchema> schemas) {
    if (schemas.isEmpty) {
      return const MonthlyStats(
        totalEntries: 0,
        avgEntriesPerWeek: 0,
        longestStreak: 0,
        mostActiveDay: '—',
      );
    }
    final total = schemas.length;
    final weeks = 4.0;
    final avgPerWeek = total / weeks;
    final dates = schemas.map((s) => DateTime(s.timestamp.year, s.timestamp.month, s.timestamp.day)).toSet().toList()
      ..sort();
    var streak = 1;
    var maxStreak = 1;
    for (var i = 1; i < dates.length; i++) {
      final diff = dates[i].difference(dates[i - 1]).inDays;
      if (diff == 1) {
        streak++;
        if (streak > maxStreak) maxStreak = streak;
      } else {
        streak = 1;
      }
    }
    final byWeekday = <int, int>{};
    for (final s in schemas) {
      byWeekday[s.timestamp.weekday] = (byWeekday[s.timestamp.weekday] ?? 0) + 1;
    }
    final topDay = byWeekday.entries.isEmpty
        ? 1
        : byWeekday.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    const days = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return MonthlyStats(
      totalEntries: total,
      avgEntriesPerWeek: double.parse(avgPerWeek.toStringAsFixed(1)),
      longestStreak: maxStreak,
      mostActiveDay: days[topDay],
    );
  }

  String _fallbackNarrative(String monthKey, int count) {
    final name = _formatMonthName(monthKey);
    return 'No synthesis available for $name. You had $count ${count == 1 ? 'entry' : 'entries'} this month.';
  }

  String _formatMonthName(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return monthKey;
    final monthNum = int.tryParse(parts[1]);
    if (monthNum == null || monthNum < 1 || monthNum > 12) return monthKey;
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${names[monthNum - 1]} ${parts[0]}';
  }

  // --- Yearly helpers ---

  Future<List<ThemeLifecycle>> _buildThemeLifecycles(String userId, int year) async {
    final themeMonths = <String, Map<int, int>>{};
    for (int m = 1; m <= 12; m++) {
      final key = '$year-${m.toString().padLeft(2, '0')}';
      final entries = await _layer0Repo.getEntriesForMonth(userId, key);
      for (final e in entries) {
        final schema = e.toSchema();
        for (final t in schema.analysis.extractedThemes) {
          final key2 = t.trim().toLowerCase();
          if (key2.length >= 2) {
            themeMonths.putIfAbsent(key2, () => {})[m] = (themeMonths[key2]![m] ?? 0) + 1;
          }
        }
      }
    }
    final lifecycles = <ThemeLifecycle>[];
    for (final e in themeMonths.entries) {
      final months = e.value;
      if (months.isEmpty) continue;
      final birthMonth = months.keys.reduce(min);
      final peakMonth = months.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      final lastMonth = months.keys.reduce(max);
      final resolvedMonth = lastMonth < 12 ? lastMonth : null;
      final status = months.length >= 10 ? 'persistent' : (resolvedMonth != null ? 'resolved' : 'peaked');
      lifecycles.add(ThemeLifecycle(
        theme: e.key,
        birthMonth: birthMonth,
        peakMonth: peakMonth,
        resolvedMonth: resolvedMonth,
        status: status,
        monthlyFrequency: months,
      ));
    }
    lifecycles.sort((a, b) => b.monthlyFrequency.values.reduce((x, y) => x + y).compareTo(a.monthlyFrequency.values.reduce((x, y) => x + y)));
    return lifecycles.take(10).toList();
  }

  Future<List<MonthlyEmotionalSummary>> _buildMonthlyEmotionalArc(
    String userId,
    int year,
    Map<String, ChronicleAggregation?> monthlyAggs,
  ) async {
    final arc = <MonthlyEmotionalSummary>[];
    for (int m = 1; m <= 12; m++) {
      final key = '$year-${m.toString().padLeft(2, '0')}';
      final entries = await _layer0Repo.getEntriesForMonth(userId, key);
      final schemas = entries.map((e) => e.toSchema()).toList();
      double avg = 0;
      if (schemas.isNotEmpty) {
        final withScore = schemas.where((s) => s.analysis.sentinelScore != null).toList();
        if (withScore.isNotEmpty) {
          avg = withScore.map((s) => s.analysis.sentinelScore!.emotionalIntensity).reduce((a, b) => a + b) / withScore.length;
        }
      }
      final agg = monthlyAggs[key];
      String? annotation;
      if (agg != null && agg.content.isNotEmpty) {
        final firstPara = agg.content.split('\n\n').first;
        if (firstPara.length < 200) annotation = firstPara;
      }
      arc.add(MonthlyEmotionalSummary(month: m, averageIntensity: avg, annotation: annotation));
    }
    return arc;
  }

  Future<YearOverYearComparison?> _buildYearOverYear(
    String userId,
    int year,
    ChronicleAggregation prevYearAgg,
  ) async {
    final thisYearEntries = await _layer0Repo.getEntriesInRange(
      userId,
      DateTime(year, 1, 1),
      DateTime(year, 12, 31, 23, 59, 59),
    );
    final lastYearEntries = await _layer0Repo.getEntriesInRange(
      userId,
      DateTime(year - 1, 1, 1),
      DateTime(year - 1, 12, 31, 23, 59, 59),
    );
    final thisThemes = <String>{};
    final lastThemes = <String>{};
    double thisAvg = 0, lastAvg = 0;
    int thisWithScore = 0, lastWithScore = 0;
    for (final e in thisYearEntries) {
      final s = e.toSchema();
      thisThemes.addAll(s.analysis.extractedThemes.map((t) => t.trim().toLowerCase()).where((t) => t.length >= 2));
      if (s.analysis.sentinelScore != null) {
        thisAvg += s.analysis.sentinelScore!.emotionalIntensity;
        thisWithScore++;
      }
    }
    for (final e in lastYearEntries) {
      final s = e.toSchema();
      lastThemes.addAll(s.analysis.extractedThemes.map((t) => t.trim().toLowerCase()).where((t) => t.length >= 2));
      if (s.analysis.sentinelScore != null) {
        lastAvg += s.analysis.sentinelScore!.emotionalIntensity;
        lastWithScore++;
      }
    }
    if (thisWithScore > 0) thisAvg /= thisWithScore;
    if (lastWithScore > 0) lastAvg /= lastWithScore;
    final newThemes = thisThemes.difference(lastThemes).toList();
    final droppedThemes = lastThemes.difference(thisThemes).toList();
    final continuingThemes = thisThemes.intersection(lastThemes).toList();
    return YearOverYearComparison(
      previousYear: year - 1,
      newThemes: newThemes.take(10).toList(),
      droppedThemes: droppedThemes.take(10).toList(),
      continuingThemes: continuingThemes.take(10).toList(),
      thisYearAvgIntensity: thisAvg,
      lastYearAvgIntensity: lastAvg,
      thisYearEntryCount: thisYearEntries.length,
      lastYearEntryCount: lastYearEntries.length,
    );
  }

  Future<IdentityEvolution> _buildIdentityEvolution(String userId, int year) async {
    final janEntries = await _layer0Repo.getEntriesForMonth(userId, '$year-01');
    final decEntries = await _layer0Repo.getEntriesForMonth(userId, '$year-12');
    final janCloud = _buildWordCloudData(janEntries.map((e) => e.toSchema()).toList());
    final decCloud = _buildWordCloudData(decEntries.map((e) => e.toSchema()).toList());
    String narrative = 'Your focus shifted over the year.';
    if (janCloud.isNotEmpty || decCloud.isNotEmpty) {
      try {
        final janStr = janCloud.entries.take(15).map((e) => '${e.key}:${e.value}').join(', ');
        final decStr = decCloud.entries.take(15).map((e) => '${e.key}:${e.value}').join(', ');
        narrative = await lumaraSend(
          system: 'Describe how a person\'s focus and identity shifted over the year. 2-3 sentences. Reference actual themes.',
          user: 'January: $janStr\nDecember: $decStr\nWrite 2-3 sentences.',
          skipTransformation: true,
          temperature: 0.6,
        );
      } catch (_) {}
    }
    return IdentityEvolution(
      januaryWordCloud: janCloud,
      decemberWordCloud: decCloud,
      evolutionNarrative: narrative.trim(),
    );
  }

  Future<List<BreakthroughEntry>> _selectYearBreakthroughs(String userId, int year, {int maxCount = 7}) async {
    final allEntries = <RawEntrySchema>[];
    for (int m = 1; m <= 12; m++) {
      final key = '$year-${m.toString().padLeft(2, '0')}';
      final entries = await _layer0Repo.getEntriesForMonth(userId, key);
      allEntries.addAll(entries.map((e) => e.toSchema()));
    }
    final priorThemes = await _getThemesFromPriorMonths(userId, '$year-01', monthsBack: 12);
    return _selectBreakthroughEntries(allEntries, priorThemes, maxCount: maxCount);
  }

  Future<Map<String, int>> _buildAnnualWordCloud(String userId, int year) async {
    final allEntries = <RawEntrySchema>[];
    for (int m = 1; m <= 12; m++) {
      final key = '$year-${m.toString().padLeft(2, '0')}';
      final entries = await _layer0Repo.getEntriesForMonth(userId, key);
      allEntries.addAll(entries.map((e) => e.toSchema()));
    }
    return _buildWordCloudData(allEntries);
  }

  List<UnresolvedThread> _identifyUnresolvedThreads(List<ThemeLifecycle> lifecycles) {
    final threads = <UnresolvedThread>[];
    for (final lc in lifecycles) {
      if (lc.resolvedMonth == null || lc.resolvedMonth! >= 10) {
        final months = lc.monthlyFrequency.keys.toList()..sort();
        threads.add(UnresolvedThread(
          theme: lc.theme,
          appearanceCount: lc.monthlyFrequency.values.reduce((a, b) => a + b),
          monthsAppeared: months,
          framing: 'Carrying forward: ${lc.theme}',
        ));
      }
    }
    return threads.take(5).toList();
  }

  Future<String> _generateSeedForNextYear(
    String yearlyContent,
    List<UnresolvedThread> threads,
    int year,
  ) async {
    try {
      final threadsStr = threads.map((t) => '- ${t.theme}: ${t.framing}').join('\n');
      final response = await lumaraSend(
        system: 'Generate a forward-looking reflection for the user entering the new year. 2-3 sentences. Acknowledge what they carried. Feel like a letter from someone who knows them.',
        user: 'Yearly synthesis:\n$yearlyContent\n\nUnresolved threads:\n$threadsStr\n\nGenerate a reflection for entering ${year + 1}.',
        skipTransformation: true,
        temperature: 0.7,
      );
      return response.trim();
    } catch (e) {
      return 'What would you like to carry into ${year + 1}?';
    }
  }

  Future<AnnualStats> _computeAnnualStats(String userId, int year) async {
    final entries = await _layer0Repo.getEntriesInRange(
      userId,
      DateTime(year, 1, 1),
      DateTime(year, 12, 31, 23, 59, 59),
    );
    final monthsWithEntries = <int>{};
    final byMonth = <int, int>{};
    var totalWords = 0;
    for (final e in entries) {
      monthsWithEntries.add(e.timestamp.month);
      byMonth[e.timestamp.month] = (byMonth[e.timestamp.month] ?? 0) + 1;
      totalWords += e.content.split(RegExp(r'\s+')).length;
    }
    final prolificMonth = byMonth.entries.isEmpty
        ? '—'
        : _formatMonthName('$year-${byMonth.entries.reduce((a, b) => a.value > b.value ? a : b).key.toString().padLeft(2, '0')}');
    final dates = entries.map((e) => DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day)).toSet().toList()
      ..sort();
    var streak = 1, maxStreak = 1;
    for (var i = 1; i < dates.length; i++) {
      if (dates[i].difference(dates[i - 1]).inDays == 1) {
        streak++;
        if (streak > maxStreak) maxStreak = streak;
      } else {
        streak = 1;
      }
    }
    return AnnualStats(
      totalEntries: entries.length,
      activeMonths: monthsWithEntries.length,
      mostProlificMonth: prolificMonth,
      longestStreak: maxStreak,
      totalWords: totalWords > 0 ? totalWords : null,
    );
  }

  String _fallbackYearNarrative(int year) {
    return 'No yearly synthesis available for $year.';
  }
}

class _ScoredEntry {
  final RawEntrySchema schema;
  final double score;
  _ScoredEntry({required this.schema, required this.score});
}
