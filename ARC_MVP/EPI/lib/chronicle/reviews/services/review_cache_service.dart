import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/monthly_review.dart';
import '../models/yearly_review.dart';

/// Caches generated MonthlyReview and YearlyReview to avoid regeneration.
/// Stores as JSON in app documents directory.
class ReviewCacheService {
  static const String _monthlyPrefix = 'monthly_review_';
  static const String _yearlyPrefix = 'yearly_review_';
  static const String _ext = '.json';

  Future<Directory> _getCacheDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(path.join(appDir.path, 'chronicle', 'reviews_cache'));
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  Future<File> _fileForMonthly(String userId, String monthKey) async {
    final dir = await _getCacheDir();
    return File(path.join(dir.path, '${_monthlyPrefix}${userId}_$monthKey$_ext'));
  }

  Future<File> _fileForYearly(String userId, int year) async {
    final dir = await _getCacheDir();
    return File(path.join(dir.path, '${_yearlyPrefix}${userId}_$year$_ext'));
  }

  /// Get cached monthly review, or null if not found/expired.
  Future<MonthlyReview?> getMonthlyReview(String userId, String monthKey) async {
    try {
      final file = await _fileForMonthly(userId, monthKey);
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return _monthlyReviewFromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Get cached yearly review, or null if not found/expired.
  Future<YearlyReview?> getYearlyReview(String userId, int year) async {
    try {
      final file = await _fileForYearly(userId, year);
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return _yearlyReviewFromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Save monthly review to cache.
  Future<void> saveMonthlyReview(String userId, MonthlyReview review) async {
    final file = await _fileForMonthly(userId, review.monthKey);
    await file.writeAsString(jsonEncode(_monthlyReviewToJson(review)));
  }

  /// Save yearly review to cache.
  Future<void> saveYearlyReview(String userId, YearlyReview review) async {
    final file = await _fileForYearly(userId, review.year);
    await file.writeAsString(jsonEncode(_yearlyReviewToJson(review)));
  }

  /// List available monthly review keys for user.
  Future<List<String>> listMonthlyReviewKeys(String userId) async {
    final dir = await _getCacheDir();
    final prefix = '${_monthlyPrefix}${userId}_';
    final files = dir.listSync().whereType<File>();
    final keys = <String>[];
    for (final f in files) {
      final name = path.basenameWithoutExtension(f.path);
      if (name.startsWith(prefix)) {
        keys.add(name.substring(prefix.length));
      }
    }
    keys.sort((a, b) => b.compareTo(a));
    return keys;
  }

  /// List available yearly review years for user.
  Future<List<int>> listYearlyReviewYears(String userId) async {
    final dir = await _getCacheDir();
    final prefix = '${_yearlyPrefix}${userId}_';
    final files = dir.listSync().whereType<File>();
    final years = <int>[];
    for (final f in files) {
      final name = path.basenameWithoutExtension(f.path);
      if (name.startsWith(prefix)) {
        final year = int.tryParse(name.substring(prefix.length));
        if (year != null) years.add(year);
      }
    }
    years.sort((a, b) => b.compareTo(a));
    return years;
  }

  /// Invalidate cache for a month (e.g. after user edits CHRONICLE).
  Future<void> invalidateMonthly(String userId, String monthKey) async {
    final file = await _fileForMonthly(userId, monthKey);
    if (await file.exists()) await file.delete();
  }

  /// Invalidate cache for a year.
  Future<void> invalidateYearly(String userId, int year) async {
    final file = await _fileForYearly(userId, year);
    if (await file.exists()) await file.delete();
  }

  MonthlyReview _monthlyReviewFromJson(Map<String, dynamic> json) {
    final te = json['themeEvolution'] as Map<String, dynamic>;
    final themeEvolution = ThemeEvolution(
      emerged: List<String>.from(te['emerged'] as List),
      persisted: List<String>.from(te['persisted'] as List),
      faded: List<String>.from(te['faded'] as List),
      intensified: List<String>.from(te['intensified'] as List),
      previousMonthKey: te['previousMonthKey'] as String?,
    );
    final emotionalTrajectory = (json['emotionalTrajectory'] as List)
        .map((e) => EmotionalDataPoint(
              date: DateTime.parse(e['date'] as String),
              intensity: (e['intensity'] as num).toDouble(),
            ))
        .toList();
    final breakthroughs = (json['breakthroughHighlights'] as List)
        .map((e) => BreakthroughEntry(
              entryId: e['entryId'] as String,
              date: DateTime.parse(e['date'] as String),
              previewSnippet: e['previewSnippet'] as String,
              highlightReason: e['highlightReason'] as String,
              significanceScore: (e['significanceScore'] as num).toDouble(),
            ))
        .toList();
    final patternAlerts = (json['patternAlerts'] as List)
        .map((e) => PatternAlert(
              description: e['description'] as String,
              patternType: e['patternType'] as String,
              supportingData: Map<String, dynamic>.from(e['supportingData'] as Map? ?? {}),
            ))
        .toList();
    final wordCloudData = (json['wordCloudData'] as Map).map((k, v) => MapEntry(k as String, v as int));
    final stats = json['stats'] as Map<String, dynamic>;
    final monthlyStats = MonthlyStats(
      totalEntries: stats['totalEntries'] as int,
      avgEntriesPerWeek: (stats['avgEntriesPerWeek'] as num).toDouble(),
      longestStreak: stats['longestStreak'] as int,
      mostActiveDay: stats['mostActiveDay'] as String,
    );
    return MonthlyReview(
      monthKey: json['monthKey'] as String,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      narrativeSynthesis: json['narrativeSynthesis'] as String,
      themeEvolution: themeEvolution,
      emotionalTrajectory: emotionalTrajectory,
      emotionalTrajectoryDescriptor: json['emotionalTrajectoryDescriptor'] as String,
      breakthroughHighlights: breakthroughs,
      patternAlerts: patternAlerts,
      wordCloudData: wordCloudData,
      seedForNextMonth: json['seedForNextMonth'] as String,
      stats: monthlyStats,
    );
  }

  Map<String, dynamic> _monthlyReviewToJson(MonthlyReview r) {
    return {
      'monthKey': r.monthKey,
      'generatedAt': r.generatedAt.toIso8601String(),
      'narrativeSynthesis': r.narrativeSynthesis,
      'themeEvolution': {
        'emerged': r.themeEvolution.emerged,
        'persisted': r.themeEvolution.persisted,
        'faded': r.themeEvolution.faded,
        'intensified': r.themeEvolution.intensified,
        'previousMonthKey': r.themeEvolution.previousMonthKey,
      },
      'emotionalTrajectory': r.emotionalTrajectory
          .map((e) => {'date': e.date.toIso8601String(), 'intensity': e.intensity})
          .toList(),
      'emotionalTrajectoryDescriptor': r.emotionalTrajectoryDescriptor,
      'breakthroughHighlights': r.breakthroughHighlights
          .map((e) => {
                'entryId': e.entryId,
                'date': e.date.toIso8601String(),
                'previewSnippet': e.previewSnippet,
                'highlightReason': e.highlightReason,
                'significanceScore': e.significanceScore,
              })
          .toList(),
      'patternAlerts': r.patternAlerts
          .map((e) => {
                'description': e.description,
                'patternType': e.patternType,
                'supportingData': e.supportingData,
              })
          .toList(),
      'wordCloudData': r.wordCloudData,
      'seedForNextMonth': r.seedForNextMonth,
      'stats': {
        'totalEntries': r.stats.totalEntries,
        'avgEntriesPerWeek': r.stats.avgEntriesPerWeek,
        'longestStreak': r.stats.longestStreak,
        'mostActiveDay': r.stats.mostActiveDay,
      },
    };
  }

  YearlyReview _yearlyReviewFromJson(Map<String, dynamic> json) {
    final lifecycles = (json['themeLifecycles'] as List)
        .map((e) {
          final m = e as Map<String, dynamic>;
          final mf = (m['monthlyFrequency'] as Map?)?.map((k, v) => MapEntry(int.parse(k.toString()), (v as num).toInt())) ?? {};
          return ThemeLifecycle(
            theme: m['theme'] as String,
            birthMonth: m['birthMonth'] as int,
            peakMonth: m['peakMonth'] as int?,
            resolvedMonth: m['resolvedMonth'] as int?,
            status: m['status'] as String,
            monthlyFrequency: mf,
          );
        })
        .toList();
    final monthlyArc = (json['monthlyEmotionalArc'] as List)
        .map((e) {
          final m = e as Map<String, dynamic>;
          return MonthlyEmotionalSummary(
            month: m['month'] as int,
            averageIntensity: (m['averageIntensity'] as num).toDouble(),
            annotation: m['annotation'] as String?,
          );
        })
        .toList();
    YearOverYearComparison? yoy;
    if (json['yearOverYear'] != null) {
      final m = json['yearOverYear'] as Map<String, dynamic>;
      yoy = YearOverYearComparison(
        previousYear: m['previousYear'] as int,
        newThemes: List<String>.from(m['newThemes'] as List),
        droppedThemes: List<String>.from(m['droppedThemes'] as List),
        continuingThemes: List<String>.from(m['continuingThemes'] as List),
        thisYearAvgIntensity: (m['thisYearAvgIntensity'] as num).toDouble(),
        lastYearAvgIntensity: (m['lastYearAvgIntensity'] as num).toDouble(),
        thisYearEntryCount: m['thisYearEntryCount'] as int,
        lastYearEntryCount: m['lastYearEntryCount'] as int,
      );
    }
    final identity = json['identityEvolution'] as Map<String, dynamic>;
    final identityEvolution = IdentityEvolution(
      januaryWordCloud: (identity['januaryWordCloud'] as Map).map((k, v) => MapEntry(k as String, v as int)),
      decemberWordCloud: (identity['decemberWordCloud'] as Map).map((k, v) => MapEntry(k as String, v as int)),
      evolutionNarrative: identity['evolutionNarrative'] as String,
    );
    final breakthroughReel = (json['breakthroughReel'] as List)
        .map((e) {
          final m = e as Map<String, dynamic>;
          return BreakthroughEntry(
            entryId: m['entryId'] as String,
            date: DateTime.parse(m['date'] as String),
            previewSnippet: m['previewSnippet'] as String,
            highlightReason: m['highlightReason'] as String,
            significanceScore: (m['significanceScore'] as num).toDouble(),
          );
        })
        .toList();
    final annualWordCloud = (json['annualWordCloud'] as Map).map((k, v) => MapEntry(k as String, v as int));
    final unresolvedThreads = (json['unresolvedThreads'] as List)
        .map((e) {
          final m = e as Map<String, dynamic>;
          return UnresolvedThread(
            theme: m['theme'] as String,
            appearanceCount: m['appearanceCount'] as int,
            monthsAppeared: (m['monthsAppeared'] as List).map((e) => e as int).toList(),
            framing: m['framing'] as String,
          );
        })
        .toList();
    final stats = json['stats'] as Map<String, dynamic>;
    final annualStats = AnnualStats(
      totalEntries: stats['totalEntries'] as int,
      activeMonths: stats['activeMonths'] as int,
      mostProlificMonth: stats['mostProlificMonth'] as String,
      longestStreak: stats['longestStreak'] as int,
      totalWords: stats['totalWords'] as int?,
    );
    return YearlyReview(
      year: json['year'] as int,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      yearNarrative: json['yearNarrative'] as String,
      themeLifecycles: lifecycles,
      monthlyEmotionalArc: monthlyArc,
      yearOverYear: yoy,
      identityEvolution: identityEvolution,
      breakthroughReel: breakthroughReel,
      annualWordCloud: annualWordCloud,
      unresolvedThreads: unresolvedThreads,
      seedForNextYear: json['seedForNextYear'] as String,
      stats: annualStats,
    );
  }

  Map<String, dynamic> _yearlyReviewToJson(YearlyReview r) {
    return {
      'year': r.year,
      'generatedAt': r.generatedAt.toIso8601String(),
      'yearNarrative': r.yearNarrative,
      'themeLifecycles': r.themeLifecycles
          .map((e) => {
                'theme': e.theme,
                'birthMonth': e.birthMonth,
                'peakMonth': e.peakMonth,
                'resolvedMonth': e.resolvedMonth,
                'status': e.status,
                'monthlyFrequency': e.monthlyFrequency.map((k, v) => MapEntry(k.toString(), v)),
              })
          .toList(),
      'monthlyEmotionalArc': r.monthlyEmotionalArc
          .map((e) => {
                'month': e.month,
                'averageIntensity': e.averageIntensity,
                'annotation': e.annotation,
              })
          .toList(),
      'yearOverYear': r.yearOverYear != null
          ? {
              'previousYear': r.yearOverYear!.previousYear,
              'newThemes': r.yearOverYear!.newThemes,
              'droppedThemes': r.yearOverYear!.droppedThemes,
              'continuingThemes': r.yearOverYear!.continuingThemes,
              'thisYearAvgIntensity': r.yearOverYear!.thisYearAvgIntensity,
              'lastYearAvgIntensity': r.yearOverYear!.lastYearAvgIntensity,
              'thisYearEntryCount': r.yearOverYear!.thisYearEntryCount,
              'lastYearEntryCount': r.yearOverYear!.lastYearEntryCount,
            }
          : null,
      'identityEvolution': {
        'januaryWordCloud': r.identityEvolution.januaryWordCloud,
        'decemberWordCloud': r.identityEvolution.decemberWordCloud,
        'evolutionNarrative': r.identityEvolution.evolutionNarrative,
      },
      'breakthroughReel': r.breakthroughReel
          .map((e) => {
                'entryId': e.entryId,
                'date': e.date.toIso8601String(),
                'previewSnippet': e.previewSnippet,
                'highlightReason': e.highlightReason,
                'significanceScore': e.significanceScore,
              })
          .toList(),
      'annualWordCloud': r.annualWordCloud,
      'unresolvedThreads': r.unresolvedThreads
          .map((e) => {
                'theme': e.theme,
                'appearanceCount': e.appearanceCount,
                'monthsAppeared': e.monthsAppeared,
                'framing': e.framing,
              })
          .toList(),
      'seedForNextYear': r.seedForNextYear,
      'stats': {
        'totalEntries': r.stats.totalEntries,
        'activeMonths': r.stats.activeMonths,
        'mostProlificMonth': r.stats.mostProlificMonth,
        'longestStreak': r.stats.longestStreak,
        'totalWords': r.stats.totalWords,
      },
    };
  }
}
