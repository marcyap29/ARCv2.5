import '../storage/aggregation_repository.dart';
import '../storage/changelog_repository.dart';
import '../models/chronicle_aggregation.dart';
import '../models/chronicle_layer.dart';
import 'pattern_detector.dart';

/// Yearly Synthesizer (Layer 2)
/// 
/// Synthesizes monthly aggregations from a year into a yearly aggregation.
/// Detects chapters, sustained patterns, inflection points.
/// Target compression: 5-10% of yearly total.

class YearlySynthesizer {
  final AggregationRepository _aggregationRepo;
  final ChangelogRepository _changelogRepo;
  final PatternDetector _patternDetector;

  YearlySynthesizer({
    required AggregationRepository aggregationRepo,
    required ChangelogRepository changelogRepo,
    PatternDetector? patternDetector,
  })  : _aggregationRepo = aggregationRepo,
        _changelogRepo = changelogRepo,
        _patternDetector = patternDetector ?? PatternDetector();

  /// Synthesize a year's monthly aggregations into a yearly aggregation
  Future<ChronicleAggregation> synthesize({
    required String userId,
    required String year, // Format: "2025"
  }) async {
    print('📊 YearlySynthesizer: Starting synthesis for $year');

    // 1. Load all monthly aggregations for this year
    final monthlyAggs = await _getMonthlyAggregationsForYear(userId, year);
    
    if (monthlyAggs.length < 3) {
      throw Exception('Need at least 3 months to synthesize year (found ${monthlyAggs.length})');
    }

    print('📊 YearlySynthesizer: Found ${monthlyAggs.length} monthly aggregations');

    // 2. Detect chapters (phase transition boundaries + theme shifts)
    final chapters = await _detectChapters(monthlyAggs);

    // 3. Find sustained patterns (appear in 6+ months)
    final sustainedPatterns = _findSustainedPatterns(monthlyAggs);

    // 4. Identify inflection points
    final inflectionPoints = _identifyInflectionPoints(monthlyAggs);

    // 5. Compare to previous years (if available)
    final comparison = await _compareToPreviousYears(userId, year);

    // 6. Calculate total entry count
    final totalEntryCount = monthlyAggs
        .map((agg) => agg.entryCount)
        .reduce((a, b) => a + b);

    // 7. Generate yearly markdown
    final markdown = await _generateYearlyMarkdown(
      year: year,
      monthlyCount: monthlyAggs.length,
      entryCount: totalEntryCount,
      chapters: chapters,
      sustainedPatterns: sustainedPatterns,
      inflectionPoints: inflectionPoints,
      comparison: comparison,
      monthlyAggs: monthlyAggs,
    );

    // 8. Calculate compression ratio
    final monthlyTokens = monthlyAggs
        .map((agg) => agg.content.split(RegExp(r'\s+')).length)
        .reduce((a, b) => a + b);
    final markdownTokens = markdown.split(RegExp(r'\s+')).length;
    final compressionRatio = markdownTokens / monthlyTokens;

    print('📊 YearlySynthesizer: Compression ratio: ${(compressionRatio * 100).toStringAsFixed(1)}%');

    // 9. Create aggregation
    final aggregation = ChronicleAggregation(
      layer: ChronicleLayer.yearly,
      period: year,
      synthesisDate: DateTime.now(),
      entryCount: totalEntryCount,
      compressionRatio: compressionRatio,
      content: markdown,
      sourceEntryIds: monthlyAggs.map((agg) => agg.period).toList(), // Store month periods
      userId: userId,
    );

    // 10. Save aggregation
    await _aggregationRepo.saveYearly(userId, aggregation);

    // 11. Log to changelog
    await _changelogRepo.log(
      userId: userId,
      layer: ChronicleLayer.yearly,
      action: 'synthesized',
      metadata: {
        'year': year,
        'monthly_count': monthlyAggs.length,
        'entry_count': totalEntryCount,
        'compression_ratio': compressionRatio,
        'chapters_count': chapters.length,
      },
    );

    print('✅ YearlySynthesizer: Synthesis complete for $year');

    return aggregation;
  }

  /// Get all monthly aggregations for a year
  Future<List<ChronicleAggregation>> _getMonthlyAggregationsForYear(
    String userId,
    String year,
  ) async {
    final allMonthly = await _aggregationRepo.getAllForLayer(
      userId: userId,
      layer: ChronicleLayer.monthly,
    );

    // Filter to this year
    return allMonthly
        .where((agg) => agg.period.startsWith(year))
        .toList()
      ..sort((a, b) => a.period.compareTo(b.period));
  }

  /// Detect chapters (phase transition boundaries + theme shifts)
  Future<List<Chapter>> _detectChapters(List<ChronicleAggregation> months) async {
    if (months.length < 2) return [];

    final chapters = <Chapter>[];
    var currentChapter = <ChronicleAggregation>[months.first];
    var chapterStartMonth = months.first.period;

    for (int i = 1; i < months.length; i++) {
      final prev = months[i - 1];
      final curr = months[i];

      // Detect chapter boundary
      final isPhaseTransition = _isPhaseTransition(prev, curr);
      final isThemeShift = await _isThemeShift(prev, curr);

      if (isPhaseTransition || isThemeShift) {
        // End current chapter, start new one
        chapters.add(Chapter(
          title: _generateChapterTitle(currentChapter),
          months: List.from(currentChapter),
          startMonth: chapterStartMonth,
          endMonth: prev.period,
        ));
        currentChapter = [curr];
        chapterStartMonth = curr.period;
      } else {
        currentChapter.add(curr);
      }
    }

    // Add final chapter
    if (currentChapter.isNotEmpty) {
      chapters.add(Chapter(
        title: _generateChapterTitle(currentChapter),
        months: List.from(currentChapter),
        startMonth: chapterStartMonth,
        endMonth: months.last.period,
      ));
    }

    return chapters;
  }

  /// Check if there's a phase transition between two months
  bool _isPhaseTransition(
    ChronicleAggregation prev,
    ChronicleAggregation curr,
  ) {
    // Extract primary phase from each aggregation's content
    final prevPhase = _extractPrimaryPhase(prev.content);
    final currPhase = _extractPrimaryPhase(curr.content);

    return prevPhase != null &&
        currPhase != null &&
        prevPhase != currPhase;
  }

  /// Extract primary phase from aggregation markdown
  String? _extractPrimaryPhase(String content) {
    final match = RegExp(r'\*\*Primary phase:\*\* (\w+)').firstMatch(content);
    return match?.group(1);
  }

  /// Check if there's a significant theme shift
  Future<bool> _isThemeShift(
    ChronicleAggregation prev,
    ChronicleAggregation curr,
  ) async {
    // Extract themes from each aggregation
    final prevThemes = _extractThemes(prev.content);
    final currThemes = _extractThemes(curr.content);

    // Check if top themes changed significantly
    if (prevThemes.isEmpty || currThemes.isEmpty) return false;

    final prevTop = prevThemes.take(3).map((t) => t.toLowerCase()).toSet();
    final currTop = currThemes.take(3).map((t) => t.toLowerCase()).toSet();

    // If less than 50% overlap, it's a theme shift
    final overlap = prevTop.intersection(currTop).length;
    return overlap < 2; // Less than 2 of top 3 themes overlap
  }

  /// Extract theme names from aggregation markdown
  List<String> _extractThemes(String content) {
    final themeSection = RegExp(r'## Dominant Themes(.*?)##', dotAll: true)
        .firstMatch(content);
    if (themeSection == null) return [];

    return RegExp(r'\*\*(\w+(?:\s+\w+)?)\*\*')
        .allMatches(themeSection.group(1) ?? '')
        .map((m) => m.group(1) ?? '')
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// Generate chapter title from months
  String _generateChapterTitle(List<ChronicleAggregation> months) {
    if (months.isEmpty) return 'Unknown Chapter';
    if (months.length == 1) {
      return _formatMonthName(months.first.period);
    }

    final start = _formatMonthName(months.first.period);
    final end = _formatMonthName(months.last.period);
    return '$start - $end';
  }

  String _formatMonthName(String month) {
    // "2025-01" -> "January 2025"
    final parts = month.split('-');
    if (parts.length != 2) return month;
    
    final year = parts[0];
    final monthNum = int.tryParse(parts[1]);
    if (monthNum == null) return month;

    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    if (monthNum < 1 || monthNum > 12) return month;
    return '${monthNames[monthNum - 1]} $year';
  }

  /// Find sustained patterns (appear in 6+ months)
  List<SustainedPattern> _findSustainedPatterns(
    List<ChronicleAggregation> months,
  ) {
    // Extract all themes from all months
    final themeMonths = <String, List<String>>{}; // theme -> list of months

    for (final month in months) {
      final themes = _extractThemes(month.content);
      for (final theme in themes) {
        themeMonths.putIfAbsent(theme, () => []).add(month.period);
      }
    }

    // Find themes that appear in 6+ months
    final sustained = <SustainedPattern>[];
    for (final entry in themeMonths.entries) {
      if (entry.value.length >= 6) {
        sustained.add(SustainedPattern(
          name: entry.key,
          months: entry.value,
          frequency: entry.value.length / months.length,
        ));
      }
    }

    return sustained;
  }

  /// Identify inflection points (major shifts in patterns)
  List<InflectionPoint> _identifyInflectionPoints(
    List<ChronicleAggregation> months,
  ) {
    final points = <InflectionPoint>[];

    // Look for months with significant changes
    for (int i = 1; i < months.length; i++) {
      final prev = months[i - 1];
      final curr = months[i];

      // Check for phase transitions
      if (_isPhaseTransition(prev, curr)) {
        points.add(InflectionPoint(
          month: curr.period,
          type: InflectionType.phaseTransition,
          description: 'Phase transition detected',
        ));
      }

      // Check for significant SENTINEL changes
      final prevSentinel = _extractSentinelAverage(prev.content);
      final currSentinel = _extractSentinelAverage(curr.content);
      if (prevSentinel != null &&
          currSentinel != null &&
          (currSentinel - prevSentinel).abs() > 0.3) {
        points.add(InflectionPoint(
          month: curr.period,
          type: InflectionType.emotionalShift,
          description: 'Significant emotional intensity change',
        ));
      }
    }

    return points;
  }

  /// Extract SENTINEL average from aggregation content
  double? _extractSentinelAverage(String content) {
    final match = RegExp(r'\*\*SENTINEL average:\*\* ([\d.]+)').firstMatch(content);
    if (match == null) return null;
    return double.tryParse(match.group(1) ?? '');
  }

  /// Compare to previous years
  Future<String?> _compareToPreviousYears(String userId, String year) async {
    final yearNum = int.tryParse(year);
    if (yearNum == null) return null;

    final prevYear = (yearNum - 1).toString();
    final prevYearAgg = await _aggregationRepo.loadLayer(
      userId: userId,
      layer: ChronicleLayer.yearly,
      period: prevYear,
    );

    if (prevYearAgg == null) return null;

    // Extract key metrics for comparison
    final prevThemes = _extractThemes(prevYearAgg.content);
    final prevChapters = RegExp(r'## Chapter \d+').allMatches(prevYearAgg.content).length;

    return 'Compared to $prevYear: ${prevChapters} chapters, ${prevThemes.length} major themes';
  }

  /// Generate yearly markdown content (INTEGRATE stage of VEIL cycle)
  /// 
  /// This is the INTEGRATE stage: synthesizing monthly examinations into
  /// a coherent developmental narrative.
  Future<String> _generateYearlyMarkdown({
    required String year,
    required int monthlyCount,
    required int entryCount,
    required List<Chapter> chapters,
    required List<SustainedPattern> sustainedPatterns,
    required List<InflectionPoint> inflectionPoints,
    String? comparison,
    required List<ChronicleAggregation> monthlyAggs,
  }) async {
    final synthesisDate = DateTime.now();

    // Build chapters section
    final chaptersSection = chapters.isEmpty
        ? 'No distinct chapters detected.'
        : chapters.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final chapter = entry.value;
            return '''## Chapter $idx: ${chapter.title}

**Period:** ${_formatMonthName(chapter.startMonth)} - ${_formatMonthName(chapter.endMonth)}
**Months:** ${chapter.months.length}
**Entries:** ${chapter.months.map((m) => m.entryCount).reduce((a, b) => a + b)}

${chapter.months.map((m) => '- ${_formatMonthName(m.period)}: ${m.entryCount} entries').join('\n')}''';
          }).join('\n\n');

    // Build sustained patterns section
    final patternsSection = sustainedPatterns.isEmpty
        ? 'No sustained patterns detected (themes appearing in 6+ months).'
        : sustainedPatterns.map((pattern) {
            return '''**${pattern.name}**
- Appears in ${pattern.months.length} months (${(pattern.frequency * 100).toStringAsFixed(0)}% of year)
- Months: ${pattern.months.map((m) => _formatMonthName(m)).join(', ')}''';
          }).join('\n\n');

    // Build inflection points section
    final inflectionSection = inflectionPoints.isEmpty
        ? 'No major inflection points detected.'
        : inflectionPoints.map((point) {
            return '- **${_formatMonthName(point.month)}:** ${point.description} (${point.type.name})';
          }).join('\n');

    // Build comparison section
    final comparisonSection = comparison != null
        ? '**Year-over-year comparison:**\n$comparison'
        : 'No previous year data available for comparison.';

    // Calculate total tokens for compression
    final monthlyTokens = monthlyAggs
        .map((agg) => agg.content.split(RegExp(r'\s+')).length)
        .reduce((a, b) => a + b);

    // Build markdown
    final markdownContent = '''---
type: yearly_aggregation
year: $year
synthesis_date: ${synthesisDate.toIso8601String()}
monthly_count: $monthlyCount
entry_count: $entryCount
compression_ratio: 0.0
veil_stage: integrate
user_edited: false
version: 1
source_monthly_periods: ${monthlyAggs.map((m) => m.period).join(', ')}
---

# Year: $year

**VEIL Stage: INTEGRATE**  
*Synthesizing $monthlyCount monthly examinations into coherent developmental narrative*

**Synthesis date:** ${synthesisDate.toIso8601String()}  
**Monthly aggregations:** $monthlyCount  
**Total entries:** $entryCount

## Chapters

$chaptersSection

## Sustained Patterns

$patternsSection

## Inflection Points

$inflectionSection

## Year Comparison

$comparisonSection

---
**Confidence note:** This synthesis represents LUMARA's interpretation of annual patterns. User can edit/correct before propagation to multi-year aggregation.
''';

    // Calculate actual compression and update frontmatter
    final markdownTokens = markdownContent.split(RegExp(r'\s+')).length;
    final compressionRatio = markdownTokens / monthlyTokens;
    final compressionPercent = (compressionRatio * 100).toStringAsFixed(1);
    
    return markdownContent.replaceFirst(
      'compression_ratio: 0.0',
      'compression_ratio: $compressionPercent%',
    );
  }
}

/// Chapter detected in yearly aggregation
class Chapter {
  final String title;
  final List<ChronicleAggregation> months;
  final String startMonth;
  final String endMonth;

  const Chapter({
    required this.title,
    required this.months,
    required this.startMonth,
    required this.endMonth,
  });
}

/// Sustained pattern across months
class SustainedPattern {
  final String name;
  final List<String> months;
  final double frequency;

  const SustainedPattern({
    required this.name,
    required this.months,
    required this.frequency,
  });
}

/// Inflection point in the year
class InflectionPoint {
  final String month;
  final InflectionType type;
  final String description;

  const InflectionPoint({
    required this.month,
    required this.type,
    required this.description,
  });
}

enum InflectionType {
  phaseTransition,
  emotionalShift,
  themeShift,
  other,
}
