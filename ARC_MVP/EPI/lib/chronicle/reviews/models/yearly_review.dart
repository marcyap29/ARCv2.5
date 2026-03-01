/// LUMARA Yearly Review data model.
///
/// Pulls from CHRONICLE Layer 2 (yearly aggregation), Layer 1 (monthly),
/// and Layer 0 (raw entries). No phase/ATLAS references.

import 'monthly_review.dart';

class YearlyReview {
  final int year;
  final DateTime generatedAt;
  final String yearNarrative; // From CHRONICLE Layer 2
  final List<ThemeLifecycle> themeLifecycles;
  final List<MonthlyEmotionalSummary> monthlyEmotionalArc;
  final YearOverYearComparison? yearOverYear;
  final IdentityEvolution identityEvolution;
  final List<BreakthroughEntry> breakthroughReel;
  final Map<String, int> annualWordCloud;
  final List<UnresolvedThread> unresolvedThreads;
  final String seedForNextYear;
  final AnnualStats stats;

  const YearlyReview({
    required this.year,
    required this.generatedAt,
    required this.yearNarrative,
    required this.themeLifecycles,
    required this.monthlyEmotionalArc,
    this.yearOverYear,
    required this.identityEvolution,
    required this.breakthroughReel,
    required this.annualWordCloud,
    required this.unresolvedThreads,
    required this.seedForNextYear,
    required this.stats,
  });
}

class ThemeLifecycle {
  final String theme;
  final int birthMonth; // 1-12
  final int? peakMonth;
  final int? resolvedMonth; // null if still active
  final String status; // "born", "peaked", "transformed", "resolved", "persistent"
  final Map<int, int> monthlyFrequency; // month -> count

  const ThemeLifecycle({
    required this.theme,
    required this.birthMonth,
    this.peakMonth,
    this.resolvedMonth,
    required this.status,
    this.monthlyFrequency = const {},
  });
}

class MonthlyEmotionalSummary {
  final int month;
  final double averageIntensity;
  final String? annotation;

  const MonthlyEmotionalSummary({
    required this.month,
    required this.averageIntensity,
    this.annotation,
  });
}

class YearOverYearComparison {
  final int previousYear;
  final List<String> newThemes;
  final List<String> droppedThemes;
  final List<String> continuingThemes;
  final double thisYearAvgIntensity;
  final double lastYearAvgIntensity;
  final int thisYearEntryCount;
  final int lastYearEntryCount;

  const YearOverYearComparison({
    required this.previousYear,
    required this.newThemes,
    required this.droppedThemes,
    required this.continuingThemes,
    required this.thisYearAvgIntensity,
    required this.lastYearAvgIntensity,
    required this.thisYearEntryCount,
    required this.lastYearEntryCount,
  });
}

class IdentityEvolution {
  final Map<String, int> januaryWordCloud;
  final Map<String, int> decemberWordCloud;
  final String evolutionNarrative;

  const IdentityEvolution({
    required this.januaryWordCloud,
    required this.decemberWordCloud,
    required this.evolutionNarrative,
  });
}

class UnresolvedThread {
  final String theme;
  final int appearanceCount;
  final List<int> monthsAppeared;
  final String framing;

  const UnresolvedThread({
    required this.theme,
    required this.appearanceCount,
    required this.monthsAppeared,
    required this.framing,
  });
}

class AnnualStats {
  final int totalEntries;
  final int activeMonths;
  final String mostProlificMonth;
  final int longestStreak;
  final int? totalWords;

  const AnnualStats({
    required this.totalEntries,
    required this.activeMonths,
    required this.mostProlificMonth,
    required this.longestStreak,
    this.totalWords,
  });
}
