import 'dart:convert';
import '../../services/gemini_send.dart';
import '../storage/layer0_repository.dart';
import '../storage/raw_entry_schema.dart';
import '../storage/aggregation_repository.dart';
import '../storage/changelog_repository.dart';
import '../models/chronicle_aggregation.dart';
import '../models/chronicle_layer.dart';
import 'pattern_detector.dart';

/// Monthly Synthesizer (Layer 1)
/// 
/// Synthesizes raw entries from a month into a monthly aggregation.
/// Target compression: 10-20% of original tokens.

class MonthlySynthesizer {
  final Layer0Repository _layer0Repo;
  final AggregationRepository _aggregationRepo;
  final ChangelogRepository _changelogRepo;
  final PatternDetector _patternDetector;

  MonthlySynthesizer({
    required Layer0Repository layer0Repo,
    required AggregationRepository aggregationRepo,
    required ChangelogRepository changelogRepo,
    PatternDetector? patternDetector,
  })  : _layer0Repo = layer0Repo,
        _aggregationRepo = aggregationRepo,
        _changelogRepo = changelogRepo,
        _patternDetector = patternDetector ?? PatternDetector();

  /// Synthesize a month's entries into a monthly aggregation
  Future<ChronicleAggregation> synthesize({
    required String userId,
    required String month, // Format: "2025-01"
  }) async {
    print('📊 MonthlySynthesizer: Starting synthesis for $month');

    // 1. Load all Layer 0 entries for this month
    final rawEntries = await _layer0Repo.getEntriesForMonth(userId, month);
    
    if (rawEntries.isEmpty) {
      throw Exception('No entries found for $month');
    }

    print('📊 MonthlySynthesizer: Found ${rawEntries.length} entries');

    // Convert to schemas for easier processing
    final entrySchemas = rawEntries.map((e) => e.toSchema()).toList();

    // 2. Extract themes using PatternDetector
    final themes = await _patternDetector.extractThemes(
      entries: entrySchemas,
      maxThemes: 5,
    );

    // 3. Calculate phase distribution
    final phaseDistribution = _patternDetector.calculatePhaseDistribution(entrySchemas);

    // 4. Calculate SENTINEL trends
    final sentinelTrend = _patternDetector.calculateSentinelTrend(entrySchemas);

    // 5. Identify significant events
    final events = _patternDetector.identifySignificantEvents(entrySchemas);

    // 6. Extract themes using LLM for richer descriptions
    final llmThemes = await _extractThemesWithLLM(entrySchemas);

    // 7. Calculate original token count (before markdown generation)
    final originalTokens = entrySchemas
        .map((e) => e.content.split(RegExp(r'\s+')).length)
        .reduce((a, b) => a + b);

    // 8. Generate markdown content
    final markdown = await _generateMonthlyMarkdown(
      month: month,
      entryCount: entrySchemas.length,
      themes: llmThemes.isNotEmpty ? llmThemes : themes,
      phaseDistribution: phaseDistribution,
      sentinelTrend: sentinelTrend,
      events: events,
      originalTokens: originalTokens,
    );

    // 9. Calculate compression ratio
    final markdownTokens = markdown.split(RegExp(r'\s+')).length;
    final compressionRatio = markdownTokens / originalTokens;

    print('📊 MonthlySynthesizer: Compression ratio: ${(compressionRatio * 100).toStringAsFixed(1)}%');

    // 9. Create aggregation
    final aggregation = ChronicleAggregation(
      layer: ChronicleLayer.monthly,
      period: month,
      synthesisDate: DateTime.now(),
      entryCount: entrySchemas.length,
      compressionRatio: compressionRatio,
      content: markdown,
      sourceEntryIds: entrySchemas.map((e) => e.entryId).toList(),
      userId: userId,
    );

    // 10. Save aggregation
    await _aggregationRepo.saveMonthly(userId, aggregation);

    // 11. Log to changelog
    await _changelogRepo.log(
      userId: userId,
      layer: ChronicleLayer.monthly,
      action: 'synthesized',
      metadata: {
        'month': month,
        'entry_count': entrySchemas.length,
        'compression_ratio': compressionRatio,
        'themes_count': themes.length,
      },
    );

    print('✅ MonthlySynthesizer: Synthesis complete for $month');

    return aggregation;
  }

  /// Extract themes using LLM for richer descriptions
  Future<List<DetectedTheme>> _extractThemesWithLLM(
    List<RawEntrySchema> entries,
  ) async {
    if (entries.isEmpty) return [];

    try {
      // Build prompt for theme extraction
      final entriesText = entries
          .take(10) // Limit to first 10 entries to avoid token limits
          .map((e) => 'ID: ${e.entryId}\n${e.content.substring(0, e.content.length > 500 ? 500 : e.content.length)}')
          .join('\n\n---\n\n');

      final systemPrompt = '''You are performing the EXAMINE stage of the VEIL narrative integration cycle.

VEIL Context:
- VERBALIZE (Layer 0): User has captured ${entries.length} raw journal entries this month
- EXAMINE (your current task): Identify patterns, themes, and emotional arcs
- INTEGRATE (next stage): This examination will feed into yearly narrative synthesis
- LINK (future stage): Multi-year biographical connections will build on this

Your Role:
Extract meaningful patterns while preserving the user's authentic voice and 
developmental trajectory. This is not summarization - it's pattern recognition 
that reveals what the user was experiencing and becoming this month.

For each theme, provide:
- Theme name (concise, 1-3 words)
- Confidence level (high/medium/low) - mark as high only if pattern appeared 3+ times
- Entry IDs that support this theme
- Brief pattern description
- Emotional arc if applicable

Output as JSON array:
[
  {
    "name": "theme_name",
    "confidence": "high|medium|low",
    "entry_ids": ["id1", "id2"],
    "pattern": "description",
    "emotional_arc": "description if applicable"
  }
]''';

      final userPrompt = '''EXAMINE these ${entries.length} journal entries and identify the top 3-5 dominant themes.

What patterns, questions, concerns, or aspirations recurred?
What emotional patterns and phase progression do you observe?
What behavioral patterns show how they approached challenges?

Entries:
$entriesText

Output JSON array of themes:''';

      final response = await geminiSend(
        system: systemPrompt,
        user: userPrompt,
        jsonExpected: true,
      );

      // Parse JSON response
      final json = jsonDecode(response) as List;
      return json.map((item) {
        final map = item as Map<String, dynamic>;
        final confidenceStr = (map['confidence'] as String? ?? 'medium').toLowerCase();
        double confidence = 0.5;
        if (confidenceStr == 'high') confidence = 0.9;
        else if (confidenceStr == 'medium') confidence = 0.7;
        else confidence = 0.5;

        return DetectedTheme(
          name: map['name'] as String,
          confidence: confidence,
          entryIds: List<String>.from(map['entry_ids'] as List),
          frequency: (map['entry_ids'] as List).length / entries.length,
        );
      }).toList();
    } catch (e) {
      print('⚠️ MonthlySynthesizer: LLM theme extraction failed: $e');
      // Fallback to pattern detector
      return await _patternDetector.extractThemes(entries: entries, maxThemes: 5);
    }
  }

  /// Generate monthly markdown content
  Future<String> _generateMonthlyMarkdown({
    required String month,
    required int entryCount,
    required List<DetectedTheme> themes,
    required Map<String, double> phaseDistribution,
    required SentinelTrend sentinelTrend,
    required List<SignificantEvent> events,
    required int originalTokens,
  }) async {
    final monthName = _formatMonthName(month);
    final synthesisDate = DateTime.now();

    // Build themes section
    final themesSection = themes.map((theme) {
      final confidenceLabel = theme.confidence >= 0.8
          ? 'high'
          : theme.confidence >= 0.6
              ? 'medium'
              : 'low';
      return '''**${theme.name}** (confidence: $confidenceLabel)
- References: entries ${theme.entryIds.take(5).map((id) => '#$id').join(', ')}${theme.entryIds.length > 5 ? '...' : ''}
- Pattern: Appears in ${(theme.frequency * 100).toStringAsFixed(0)}% of entries''';
    }).join('\n\n');

    // Build phase section
    final dominantPhase = phaseDistribution.entries
        .reduce((a, b) => a.value > b.value ? a : b);
    final phaseSection = '''**Primary phase:** ${dominantPhase.key} (${(dominantPhase.value * 100).toStringAsFixed(0)}% of entries)
**Phase distribution:** ${phaseDistribution.entries.map((e) => '${e.key}: ${(e.value * 100).toStringAsFixed(0)}%').join(', ')}''';

    // Build SENTINEL section
    final sentinelSection = '''**SENTINEL average:** ${sentinelTrend.average.toStringAsFixed(2)} (${sentinelTrend.average > 0.7 ? 'high' : sentinelTrend.average > 0.4 ? 'moderate' : 'low'})
**Peak density:** ${sentinelTrend.peak.toStringAsFixed(2)}
**Trend:** ${sentinelTrend.trend > 0.1 ? 'increasing' : sentinelTrend.trend < -0.1 ? 'decreasing' : 'stable'}''';

    // Build events section
    final eventsSection = events.isEmpty
        ? 'No significant events detected.'
        : events.map((e) {
            final dateStr = '${e.date.month}/${e.date.day}';
            return '- **$dateStr:** ${e.description}';
          }).join('\n');

    // Build markdown (compression ratio will be calculated after)
    final markdownContent = '''---
type: monthly_aggregation
month: $month
synthesis_date: ${synthesisDate.toIso8601String()}
entry_count: $entryCount
compression_ratio: 0.0
veil_stage: examine
user_edited: false
version: 1
source_entry_ids: ${themes.expand((t) => t.entryIds).toSet().join(', ')}
---

# Month: $monthName

**VEIL Stage: EXAMINE**  
*Pattern recognition across $entryCount entries*

**Synthesis date:** ${synthesisDate.toIso8601String()}  
**Entry count:** $entryCount entries

## Dominant Themes

$themesSection

## Phase Analysis

$phaseSection

## Emotional Density Patterns

$sentinelSection

## Significant Events

$eventsSection

---
**Confidence note:** This synthesis represents LUMARA's interpretation of developmental patterns. User can edit/correct before propagation to yearly aggregation.
''';

    // Calculate actual compression and update frontmatter
    final markdownTokens = markdownContent.split(RegExp(r'\s+')).length;
    final compressionRatio = markdownTokens / originalTokens;
    final compressionPercent = (compressionRatio * 100).toStringAsFixed(1);
    
    // Replace placeholder compression_ratio in frontmatter
    return markdownContent.replaceFirst(
      'compression_ratio: 0.0',
      'compression_ratio: $compressionPercent%',
    );
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
}
