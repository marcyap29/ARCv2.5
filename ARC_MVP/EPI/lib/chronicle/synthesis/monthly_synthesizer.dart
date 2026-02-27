import 'dart:convert';
import '../../services/gemini_send.dart';
import '../storage/layer0_repository.dart';
import '../storage/raw_entry_schema.dart';
import '../storage/aggregation_repository.dart';
import '../storage/changelog_repository.dart';
import '../models/chronicle_aggregation.dart';
import '../models/chronicle_layer.dart';
import 'pattern_detector.dart';

/// Words that must not be used as theme names (pronouns, articles, fillers, generic verbs).
const _nonThemeWords = {
  'that', 'what', 'this', 'it', 'the', 'a', 'an', 'and', 'or', 'but',
  'is', 'are', 'was', 'were', 'have', 'has', 'had', 'do', 'does', 'did',
  'will', 'would', 'could', 'should', 'may', 'might', 'can', 'something',
  'things', 'how', 'when', 'why', 'where', 'which', 'who', 'them', 'their',
  'there', 'then', 'than', 'just', 'only', 'even', 'also', 'very', 'really',
  'over', 'makes', 'processing', 'slower', 'okay', 'make', 'made', 'getting',
  'being', 'going', 'like', 'into', 'with', 'from', 'for', 'about', 'some',
};

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
      print('📊 MonthlySynthesizer: No entries for $month (run Backfill Layer 0 if you have journal entries)');
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

    // 6a. Decision captures this month (for narrative and markdown)
    final decisionSchemas = entrySchemas.where((e) => e.analysis.isDecision).toList();
    final decisionCapturesText = _formatDecisionCapturesForSynthesis(decisionSchemas);

    // 6b. Generate narrative summary: "What happened this month"
    final monthNarrative = await _generateMonthNarrative(
      month: month,
      entrySchemas: entrySchemas,
      decisionCapturesText: decisionCapturesText,
    );

    // 7. Calculate original token count (before markdown generation)
    final originalTokens = entrySchemas
        .map((e) => e.content.split(RegExp(r'\s+')).length)
        .reduce((a, b) => a + b);

    // 8. Generate markdown content (with linked entries for LUMARA drill-down)
    final markdown = await _generateMonthlyMarkdown(
      month: month,
      entryCount: entrySchemas.length,
      entrySchemas: entrySchemas,
      themes: llmThemes.isNotEmpty ? llmThemes : themes,
      phaseDistribution: phaseDistribution,
      sentinelTrend: sentinelTrend,
      events: events,
      originalTokens: originalTokens,
      monthNarrative: monthNarrative,
      decisionCapturesText: decisionCapturesText,
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
      // Build prompt for theme extraction (more entries and chars for richer detail; compatible with PII scrub/restore)
      final entriesText = entries
          .take(40)
          .map((e) => 'ID: ${e.entryId}\n${e.content.substring(0, e.content.length > 1000 ? 1000 : e.content.length)}')
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
- Theme name: a meaningful topic or concept (1-3 words). Use nouns or noun phrases (e.g. "career transition", "family boundaries", "sleep routine"). Do NOT use pronouns, articles, verbs, or filler words as themes (never: "that", "what", "this", "over", "makes", "processing", "slower", "okay", "how", "when", "why", "something", "things", "like", "getting", "being", "going").
- Confidence level (high/medium/low) - mark as high only if pattern appeared 3+ times
- Entry IDs that support this theme
- Brief pattern description: include specific details from the entries when relevant (names, places, projects, events)—not generic summaries. This feeds temporal memory that may be scrubbed for cloud; specifics are preserved on device and restored in responses.
- Emotional arc if applicable (can reference concrete situations from entries)

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

      final response = await lumaraSend(
        system: systemPrompt,
        user: userPrompt,
        skipTransformation: true,
      );

      // Parse JSON response and filter out non-themes (e.g. "That", "What")
      final json = jsonDecode(response) as List;
      final themes = <DetectedTheme>[];
      for (final item in json) {
        final map = item as Map<String, dynamic>;
        final name = (map['name'] as String? ?? '').trim();
        if (name.isEmpty || _isNonTheme(name)) continue;
        final confidenceStr = (map['confidence'] as String? ?? 'medium').toLowerCase();
        double confidence = 0.5;
        if (confidenceStr == 'high') {
          confidence = 0.9;
        } else if (confidenceStr == 'medium') confidence = 0.7;
        else confidence = 0.5;
        final entryIds = List<String>.from(map['entry_ids'] as List? ?? []);

        themes.add(DetectedTheme(
          name: name,
          confidence: confidence,
          entryIds: entryIds,
          frequency: entries.isEmpty ? 0.0 : entryIds.length / entries.length,
          patternDescription: map['pattern'] as String?,
          emotionalArc: map['emotional_arc'] as String?,
        ));
      }
      return themes;
    } catch (e) {
      print('⚠️ MonthlySynthesizer: LLM theme extraction failed: $e');
      // Fallback to pattern detector (filter non-themes there too)
      final fallback = await _patternDetector.extractThemes(entries: entries, maxThemes: 8);
      return fallback.where((t) => !_isNonTheme(t.name)).toList();
    }
  }

  /// True if [name] is a non-theme (pronoun, article, or common word).
  static bool _isNonTheme(String name) {
    final lower = name.trim().toLowerCase();
    if (lower.isEmpty || lower.length < 2) return true;
    if (_nonThemeWords.contains(lower)) return true;
    // Single "word" that is just digits or punctuation
    if (RegExp(r'^[\d\s\W]+$').hasMatch(lower)) return true;
    return false;
  }

  /// Build text block of decision captures for synthesis prompts.
  String _formatDecisionCapturesForSynthesis(List<RawEntrySchema> decisionSchemas) {
    if (decisionSchemas.isEmpty) return '';
    final buffer = StringBuffer();
    for (final e in decisionSchemas) {
      final data = e.analysis.decisionData;
      if (data == null) continue;
      buffer.writeln('- **Decision:** ${(data['decision_statement'] as String? ?? '').toString().trim()}');
      buffer.writeln('  Context: ${(data['life_context'] as String? ?? '').toString().trim()}');
      buffer.writeln('  Options considered: ${(data['options_considered'] as String? ?? '').toString().trim()}');
      buffer.writeln('  Success marker: ${(data['success_marker'] as String? ?? '').toString().trim()}');
      if (data['outcome_log'] != null && (data['outcome_log'] as String).isNotEmpty) {
        buffer.writeln('  Outcome (logged later): ${data['outcome_log']}');
      }
      buffer.writeln();
    }
    return buffer.toString().trim();
  }

  /// Generate a narrative summary of what happened this month (1–2 paragraphs).
  Future<String> _generateMonthNarrative({
    required String month,
    required List<RawEntrySchema> entrySchemas,
    String decisionCapturesText = '',
  }) async {
    if (entrySchemas.isEmpty) return '';

    final monthName = _formatMonthName(month);
    try {
      // Journal entries only for main narrative (exclude decision entry content from duplicate treatment)
      final journalSchemas = entrySchemas.where((e) => !e.analysis.isDecision).toList();
      final entriesText = (journalSchemas.isEmpty ? entrySchemas : journalSchemas)
          .take(80)
          .map((e) => e.content.substring(0, e.content.length > 1200 ? 1200 : e.content.length))
          .join('\n\n---\n\n');

      const systemPrompt = '''You write detailed month-in-review summaries for a personal journaling app (memory files the owner will read).
Based only on the journal entry content and any DECISION CAPTURES provided, write a detailed narrative in third person that:
- Preserves concrete details: specific names, places, events, dates, and projects from the entries. Pull out and include specific details, not generic summaries.
- Covers what actually happened this month (events, routines, changes), what the person was focused on or struggling with, multiple themes (work, family, health, projects), and notable emotional or relational themes.
- Treats decision captures as significant inflection point markers: note what the person was deciding, what was driving the decision, and (if outcome is provided) how it turned out versus what would have made it feel right. These moments define the month's direction, not just its emotional texture.
Write in clear, narrative prose: flowing paragraphs, no bullet points. Weave specifics from the entries; avoid generic tags like "Personal" or "Family" by themselves. Length: several paragraphs if the month has rich content; be concise only when entries are sparse or vague. Do not mention "References" or entry IDs.
Target readability: Flesch-Kincaid grade level 8. Use clear sentences and common words. Full detail is kept on device; this text may be privacy-scrubbed when sent to cloud and restored in responses.''';

      final decisionSection = decisionCapturesText.isEmpty
          ? ''
          : '\n\nDECISION CAPTURES this month:\n$decisionCapturesText\n\n';

      final userPrompt = '''Journal entries from $monthName:

$entriesText
$decisionSection
Write a detailed narrative of what happened and what mattered this month, preserving specific names, places, events, and projects from the entries. If decision captures are listed, weave them in as inflection points.''';

      final response = await lumaraSend(
        system: systemPrompt,
        user: userPrompt,
        skipTransformation: true,
      );
      final trimmed = response.trim();
      return trimmed.isNotEmpty ? trimmed : '';
    } catch (e) {
      print('⚠️ MonthlySynthesizer: Month narrative failed: $e');
      return '';
    }
  }

  /// Generate monthly markdown content
  Future<String> _generateMonthlyMarkdown({
    required String month,
    required int entryCount,
    required List<RawEntrySchema> entrySchemas,
    required List<DetectedTheme> themes,
    required Map<String, double> phaseDistribution,
    required SentinelTrend sentinelTrend,
    required List<SignificantEvent> events,
    required int originalTokens,
    String monthNarrative = '',
    String decisionCapturesText = '',
  }) async {
    final monthName = _formatMonthName(month);
    final synthesisDate = DateTime.now();

    // Linked entries: date | entry_id so LUMARA can retrieve specific dated entries from this month
    final sortedByDate = List<RawEntrySchema>.from(entrySchemas)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final linkedEntriesSection = sortedByDate
        .map((e) {
          final d = e.timestamp;
          final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          return '$dateStr | ${e.entryId}';
        })
        .join('\n');

    // Build themes section: lead with narrative (pattern/emotional arc), not references or raw keywords
    final themesSection = themes.map((theme) {
      final confidenceLabel = theme.confidence >= 0.8
          ? 'high'
          : theme.confidence >= 0.6
              ? 'medium'
              : 'low';
      final hasDescription = theme.patternDescription != null && theme.patternDescription!.trim().isNotEmpty;
      final parts = <String>[
        '**${theme.name}** (confidence: $confidenceLabel)',
        if (hasDescription) theme.patternDescription!.trim(),
        if (theme.emotionalArc != null && theme.emotionalArc!.trim().isNotEmpty) 'Emotional arc: ${theme.emotionalArc!.trim()}',
        if (!hasDescription) 'Recurred across ${(theme.frequency * 100).toStringAsFixed(0)}% of entries.',
      ];
      return parts.join('\n\n');
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

## What happened this month

${monthNarrative.isNotEmpty ? monthNarrative : '*No narrative summary generated.*'}

## Linked entries (this month)

Each line links this summary to a specific journal entry. LUMARA can use these to retrieve or cite the dated entry.

$linkedEntriesSection

## Dominant themes

$themesSection

## Phase Analysis

$phaseSection

## Emotional Density Patterns

$sentinelSection

## Significant Events

$eventsSection

${decisionCapturesText.isEmpty ? '' : '## Decision captures (Crossroads)\n\n$decisionCapturesText\n\n'}

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
