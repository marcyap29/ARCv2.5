import '../../services/gemini_send.dart';
import '../storage/aggregation_repository.dart';
import '../storage/changelog_repository.dart';
import '../models/chronicle_aggregation.dart';
import '../models/chronicle_layer.dart';

/// Multi-Year Synthesizer (Layer 3)
/// 
/// Synthesizes multiple year summaries into life chapters and meta-patterns.
/// Target compression: 1-2% of multi-year total.

class MultiYearSynthesizer {
  final AggregationRepository _aggregationRepo;
  final ChangelogRepository _changelogRepo;

  MultiYearSynthesizer({
    required AggregationRepository aggregationRepo,
    required ChangelogRepository changelogRepo,
  })  : _aggregationRepo = aggregationRepo,
        _changelogRepo = changelogRepo;

  /// Synthesize multiple years into a multi-year aggregation
  Future<ChronicleAggregation> synthesize({
    required String userId,
    required String startYear,
    required String endYear,
  }) async {
    print('📊 MultiYearSynthesizer: Starting synthesis for $startYear-$endYear');

    // 1. Load all yearly aggregations in the range
    final yearlyAggs = await _getYearlyAggregationsInRange(
      userId,
      startYear,
      endYear,
    );
    
    if (yearlyAggs.length < 2) {
      throw Exception('Need at least 2 years to synthesize multi-year period (found ${yearlyAggs.length})');
    }

    print('📊 MultiYearSynthesizer: Found ${yearlyAggs.length} yearly aggregations');

    // 2. Detect life chapters (major transitions across years)
    final lifeChapters = _detectLifeChapters(yearlyAggs);

    // 3. Find meta-patterns (patterns that appear across all years)
    final metaPatterns = _findMetaPatterns(yearlyAggs);

    // 4. Identify developmental arcs
    final developmentalArcs = _identifyDevelopmentalArcs(yearlyAggs);

    // 5. Calculate total entry count
    final totalEntryCount = yearlyAggs
        .map((agg) => agg.entryCount)
        .reduce((a, b) => a + b);

    // 5b. Generate narrative summary for this period (memory-style, Flesch-Kincaid ~8)
    final periodNarrative = await _generateMultiYearNarrative(
      startYear: startYear,
      endYear: endYear,
      yearlyAggs: yearlyAggs,
    );

    // 6. Generate multi-year markdown
    final markdown = _generateMultiYearMarkdown(
      startYear: startYear,
      endYear: endYear,
      yearCount: yearlyAggs.length,
      entryCount: totalEntryCount,
      lifeChapters: lifeChapters,
      metaPatterns: metaPatterns,
      developmentalArcs: developmentalArcs,
      yearlyAggs: yearlyAggs,
      periodNarrative: periodNarrative,
    );

    // 7. Calculate compression ratio
    final yearlyTokens = yearlyAggs
        .map((agg) => agg.content.split(RegExp(r'\s+')).length)
        .reduce((a, b) => a + b);
    final markdownTokens = markdown.split(RegExp(r'\s+')).length;
    final compressionRatio = markdownTokens / yearlyTokens;

    print('📊 MultiYearSynthesizer: Compression ratio: ${(compressionRatio * 100).toStringAsFixed(1)}%');

    // 8. Create aggregation
    final period = '$startYear-$endYear';
    final aggregation = ChronicleAggregation(
      layer: ChronicleLayer.multiyear,
      period: period,
      synthesisDate: DateTime.now(),
      entryCount: totalEntryCount,
      compressionRatio: compressionRatio,
      content: markdown,
      sourceEntryIds: yearlyAggs.map((agg) => agg.period).toList(), // Store year periods
      userId: userId,
    );

    // 9. Save aggregation
    await _aggregationRepo.saveMultiYear(userId, aggregation);

    // 10. Log to changelog
    await _changelogRepo.log(
      userId: userId,
      layer: ChronicleLayer.multiyear,
      action: 'synthesized',
      metadata: {
        'start_year': startYear,
        'end_year': endYear,
        'year_count': yearlyAggs.length,
        'entry_count': totalEntryCount,
        'compression_ratio': compressionRatio,
        'life_chapters_count': lifeChapters.length,
      },
    );

    print('✅ MultiYearSynthesizer: Synthesis complete for $period');

    return aggregation;
  }

  /// Get all yearly aggregations in a range
  Future<List<ChronicleAggregation>> _getYearlyAggregationsInRange(
    String userId,
    String startYear,
    String endYear,
  ) async {
    final allYearly = await _aggregationRepo.getAllForLayer(
      userId: userId,
      layer: ChronicleLayer.yearly,
    );

    final start = int.tryParse(startYear) ?? 0;
    final end = int.tryParse(endYear) ?? 0;

    return allYearly
        .where((agg) {
          final year = int.tryParse(agg.period) ?? 0;
          return year >= start && year <= end;
        })
        .toList()
      ..sort((a, b) => a.period.compareTo(b.period));
  }

  /// Detect life chapters (major transitions across years)
  List<LifeChapter> _detectLifeChapters(List<ChronicleAggregation> years) {
    final chapters = <LifeChapter>[];
    var currentChapter = <ChronicleAggregation>[years.first];
    var chapterStartYear = years.first.period;

    for (int i = 1; i < years.length; i++) {
      final prev = years[i - 1];
      final curr = years[i];

      // Detect major chapter boundary (significant change in patterns)
      final isMajorShift = _isMajorShift(prev, curr);

      if (isMajorShift) {
        chapters.add(LifeChapter(
          title: _generateLifeChapterTitle(currentChapter),
          years: List.from(currentChapter),
          startYear: chapterStartYear,
          endYear: prev.period,
        ));
        currentChapter = [curr];
        chapterStartYear = curr.period;
      } else {
        currentChapter.add(curr);
      }
    }

    // Add final chapter
    if (currentChapter.isNotEmpty) {
      chapters.add(LifeChapter(
        title: _generateLifeChapterTitle(currentChapter),
        years: List.from(currentChapter),
        startYear: chapterStartYear,
        endYear: years.last.period,
      ));
    }

    return chapters;
  }

  /// Check if there's a major shift between years
  bool _isMajorShift(ChronicleAggregation prev, ChronicleAggregation curr) {
    // Extract chapter counts (major transitions)
    final prevChapters = RegExp(r'## Chapter \d+').allMatches(prev.content).length;
    final currChapters = RegExp(r'## Chapter \d+').allMatches(curr.content).length;

    // If chapter count changes significantly, it's a major shift
    if ((currChapters - prevChapters).abs() >= 2) return true;

    // Check for sustained pattern changes
    final prevPatterns = _extractSustainedPatterns(prev.content);
    final currPatterns = _extractSustainedPatterns(curr.content);

    // If less than 50% of patterns overlap, it's a major shift
    final overlap = prevPatterns.intersection(currPatterns).length;
    return overlap < (prevPatterns.length * 0.5);
  }

  /// Extract sustained pattern names from aggregation
  Set<String> _extractSustainedPatterns(String content) {
    final patternsSection = RegExp(r'## Sustained Patterns(.*?)##', dotAll: true)
        .firstMatch(content);
    if (patternsSection == null) return {};

    return RegExp(r'\*\*(\w+(?:\s+\w+)?)\*\*')
        .allMatches(patternsSection.group(1) ?? '')
        .map((m) => (m.group(1) ?? '').toLowerCase())
        .where((p) => p.isNotEmpty)
        .toSet();
  }

  /// Generate life chapter title
  String _generateLifeChapterTitle(List<ChronicleAggregation> years) {
    if (years.isEmpty) return 'Unknown Chapter';
    if (years.length == 1) {
      return 'Year ${years.first.period}';
    }

    return '${years.first.period} - ${years.last.period}';
  }

  /// Find meta-patterns (patterns appearing across all years)
  List<MetaPattern> _findMetaPatterns(List<ChronicleAggregation> years) {
    if (years.isEmpty) return [];

    // Get all patterns from all years
    final patternYears = <String, List<String>>{}; // pattern -> list of years

    for (final year in years) {
      final patterns = _extractSustainedPatterns(year.content);
      for (final pattern in patterns) {
        patternYears.putIfAbsent(pattern, () => []).add(year.period);
      }
    }

    // Find patterns that appear in all or most years
    final metaPatterns = <MetaPattern>[];
    for (final entry in patternYears.entries) {
      final frequency = entry.value.length / years.length;
      if (frequency >= 0.8) { // Appears in 80%+ of years
        metaPatterns.add(MetaPattern(
          name: entry.key,
          years: entry.value,
          frequency: frequency,
        ));
      }
    }

    return metaPatterns;
  }

  /// Identify developmental arcs (long-term trajectories)
  List<DevelopmentalArc> _identifyDevelopmentalArcs(
    List<ChronicleAggregation> years,
  ) {
    final arcs = <DevelopmentalArc>[];

    // Extract phase progression across years
    final phaseProgression = years
        .map((y) => _extractDominantPhase(y.content))
        .whereType<String>()
        .toList();

    if (phaseProgression.length >= 3) {
      // Detect if there's a clear progression
      final uniquePhases = phaseProgression.toSet();
      if (uniquePhases.length >= 2) {
        arcs.add(DevelopmentalArc(
          name: 'Phase Evolution',
          description: 'Progression through phases: ${phaseProgression.join(" → ")}',
          years: years.map((y) => y.period).toList(),
        ));
      }
    }

    // Extract SENTINEL trends
    final sentinelTrends = years
        .map((y) => _extractSentinelAverage(y.content))
        .whereType<double>()
        .toList();

    if (sentinelTrends.length >= 3) {
      final firstHalf = sentinelTrends.sublist(0, sentinelTrends.length ~/ 2);
      final secondHalf = sentinelTrends.sublist(sentinelTrends.length ~/ 2);
      final firstAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
      final secondAvg = secondHalf.reduce((a, b) => a + b) / secondHalf.length;

      if ((secondAvg - firstAvg).abs() > 0.2) {
        arcs.add(DevelopmentalArc(
          name: 'Emotional Intensity Arc',
          description: secondAvg > firstAvg
              ? 'Increasing emotional intensity over time'
              : 'Decreasing emotional intensity over time',
          years: years.map((y) => y.period).toList(),
        ));
      }
    }

    return arcs;
  }

  /// Extract dominant phase from aggregation
  String? _extractDominantPhase(String content) {
    // Try to extract from chapters or phase analysis
    final match = RegExp(r'Primary phase[:\*]+ (\w+)').firstMatch(content);
    return match?.group(1);
  }

  /// Extract SENTINEL average from aggregation
  double? _extractSentinelAverage(String content) {
    final match = RegExp(r'SENTINEL average[:\*]+ ([\d.]+)').firstMatch(content);
    if (match == null) return null;
    return double.tryParse(match.group(1) ?? '');
  }

  /// Generate narrative summary for multi-year period (memory-style, readable by owner).
  Future<String> _generateMultiYearNarrative({
    required String startYear,
    required String endYear,
    required List<ChronicleAggregation> yearlyAggs,
  }) async {
    if (yearlyAggs.isEmpty) return '';
    try {
      final period = '$startYear-$endYear';
      final yearCount = yearlyAggs.length;
      // Use full "Year in review" section from each yearly (or up to 1200 chars fallback) for key specifics; same content is scrubbed when sent to cloud
      final yearlySummaries = yearlyAggs.map((agg) {
        final match = RegExp(r'## Year in review\s*\n([\s\S]*?)(?=\n## |\n---|\z)', caseSensitive: false).firstMatch(agg.content);
        final narrative = match?.group(1)?.trim() ?? agg.content.substring(0, agg.content.length > 1200 ? 1200 : agg.content.length);
        return '**${agg.period}:**\n$narrative';
      }).join('\n\n');

      final systemPrompt = '''You write multi-year memory summaries for a personal journaling app. The owner will read these like "Purpose & context" memory.
Given the yearly summaries below (for $yearCount years), integrate the period $period while preserving key specifics and concrete details across years: important people, projects, turning points, and life chapters. Write 3–5 flowing paragraphs (or more if the period is dense) that cover major throughlines, how the person evolved, recurring themes, and turning points—include concrete details and names/events where the yearly text provides them, not only high-level life themes. Write in third person. No bullet lists in the main narrative—use prose only.
Target readability: Flesch-Kincaid grade level 8. Use clear sentences and common words. Do not mention "References," entry IDs, or internal metadata. This text may be privacy-scrubbed when sent to cloud and restored in responses.''';

      final userPrompt = '''Yearly summaries for $period:

$yearlySummaries

Write a narrative summary for this $yearCount-year period ($period) that preserves key specifics (people, projects, turning points) from the yearly summaries:''';

      final response = await geminiSend(
        system: systemPrompt,
        user: userPrompt,
        jsonExpected: false,
      );
      return response.trim();
    } catch (e) {
      print('⚠️ MultiYearSynthesizer: Period narrative failed: $e');
      return '';
    }
  }

  /// Generate multi-year markdown content
  String _generateMultiYearMarkdown({
    required String startYear,
    required String endYear,
    required int yearCount,
    required int entryCount,
    required List<LifeChapter> lifeChapters,
    required List<MetaPattern> metaPatterns,
    required List<DevelopmentalArc> developmentalArcs,
    required List<ChronicleAggregation> yearlyAggs,
    String periodNarrative = '',
  }) {
    final period = '$startYear-$endYear';
    final synthesisDate = DateTime.now();

    // Build life chapters section
    final chaptersSection = lifeChapters.isEmpty
        ? 'No distinct life chapters detected.'
        : lifeChapters.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final chapter = entry.value;
            return '''## Life Chapter $idx: ${chapter.title}

**Period:** ${chapter.startYear} - ${chapter.endYear}
**Years:** ${chapter.years.length}
**Entries:** ${chapter.years.map((y) => y.entryCount).reduce((a, b) => a + b)}

${chapter.years.map((y) => '- Year $y: ${y.entryCount} entries').join('\n')}''';
          }).join('\n\n');

    // Build meta-patterns section
    final metaPatternsSection = metaPatterns.isEmpty
        ? 'No meta-patterns detected (patterns appearing across 80%+ of years).'
        : metaPatterns.map((pattern) {
            return '''**${pattern.name}**
- Appears in ${pattern.years.length} years (${(pattern.frequency * 100).toStringAsFixed(0)}% of period)
- Years: ${pattern.years.join(', ')}''';
          }).join('\n\n');

    // Build developmental arcs section
    final arcsSection = developmentalArcs.isEmpty
        ? 'No clear developmental arcs detected.'
        : developmentalArcs.map((arc) {
            return '''**${arc.name}**
- Description: ${arc.description}
- Years: ${arc.years.join(', ')}''';
          }).join('\n\n');

    // Calculate total tokens for compression
    final yearlyTokens = yearlyAggs
        .map((agg) => agg.content.split(RegExp(r'\s+')).length)
        .reduce((a, b) => a + b);

    // Build markdown
    final markdownContent = '''---
type: multiyear_aggregation
period: $period
synthesis_date: ${synthesisDate.toIso8601String()}
year_count: $yearCount
entry_count: $entryCount
compression_ratio: 0.0
veil_stage: link
user_edited: false
version: 1
source_year_periods: ${yearlyAggs.map((y) => y.period).join(', ')}
---

# Multi-Year Period: $period

**VEIL Stage: LINK**  
*Connecting $yearCount years of integrated narratives to reveal biographical throughlines*

**Synthesis date:** ${synthesisDate.toIso8601String()}  
**Years covered:** $yearCount  
**Total entries:** $entryCount

## Period in review

${periodNarrative.isNotEmpty ? periodNarrative : '*No narrative summary generated.*'}

## Life Chapters

$chaptersSection

## Meta-Patterns

$metaPatternsSection

## Developmental Arcs

$arcsSection

---
**Confidence note:** This synthesis represents LUMARA's interpretation of long-term biographical patterns. User can edit/correct as needed.
''';

    // Calculate actual compression and update frontmatter
    final markdownTokens = markdownContent.split(RegExp(r'\s+')).length;
    final compressionRatio = markdownTokens / yearlyTokens;
    final compressionPercent = (compressionRatio * 100).toStringAsFixed(1);
    
    return markdownContent.replaceFirst(
      'compression_ratio: 0.0',
      'compression_ratio: $compressionPercent%',
    );
  }
}

/// Life chapter across multiple years
class LifeChapter {
  final String title;
  final List<ChronicleAggregation> years;
  final String startYear;
  final String endYear;

  const LifeChapter({
    required this.title,
    required this.years,
    required this.startYear,
    required this.endYear,
  });
}

/// Meta-pattern appearing across years
class MetaPattern {
  final String name;
  final List<String> years;
  final double frequency;

  const MetaPattern({
    required this.name,
    required this.years,
    required this.frequency,
  });
}

/// Developmental arc over time
class DevelopmentalArc {
  final String name;
  final String description;
  final List<String> years;

  const DevelopmentalArc({
    required this.name,
    required this.description,
    required this.years,
  });
}
