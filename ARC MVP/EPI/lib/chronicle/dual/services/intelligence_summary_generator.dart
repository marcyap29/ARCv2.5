// lib/chronicle/dual/services/intelligence_summary_generator.dart
//
// Generates the Intelligence Summary (Layer 3) from CHRONICLE Layer 0 (entries),
// Layers 1–3 (monthly, yearly, multi-year summaries), and LUMARA CHRONICLE
// (patterns, promoted insights). Output is coherent, user-readable narrative.
// Uses Groq via LumaraAPIConfig.

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:my_app/arc/chat/config/api_config.dart';
import 'package:my_app/arc/chat/services/groq_service.dart';
import 'package:my_app/chronicle/core/chronicle_repos.dart';
import 'package:my_app/chronicle/models/chronicle_aggregation.dart';
import 'package:my_app/chronicle/models/chronicle_layer.dart';
import '../models/chronicle_models.dart';
import '../models/intelligence_summary_models.dart';
import '../repositories/lumara_chronicle_repository.dart';
import '../repositories/intelligence_summary_repository.dart';
import 'chronicle_query_adapter.dart';

class IntelligenceSummaryGenerator {
  IntelligenceSummaryGenerator({
    required ChronicleQueryAdapter chronicleAdapter,
    required LumaraChronicleRepository lumaraRepo,
    required IntelligenceSummaryRepository summaryRepo,
  })  : _chronicleAdapter = chronicleAdapter,
        _lumaraRepo = lumaraRepo,
        _summaryRepo = summaryRepo;

  final ChronicleQueryAdapter _chronicleAdapter;
  final LumaraChronicleRepository _lumaraRepo;
  final IntelligenceSummaryRepository _summaryRepo;

  /// Optional: set to include CHRONICLE Layer 1–3 (monthly, yearly, multi-year) in synthesis.
  static const int maxMonthlySummaries = 6;
  static const int maxYearlySummaries = 2;
  static const int maxMultiyearSummaries = 1;

  /// Generate the full Intelligence Summary for [userId]. Saves and archives previous version.
  /// Uses Groq (LUMARA standard API) when configured; otherwise returns a short stats-only summary.
  Future<IntelligenceSummary> generateSummary(String userId) async {
    final startTime = DateTime.now();
    final intelligence = await _gatherIntelligence(userId);
    String content = _fallbackContent(intelligence);
    bool usedGroq = false;
    try {
      await LumaraAPIConfig.instance.initialize();
      final groqKey = LumaraAPIConfig.instance.getApiKey(LLMProvider.groq);
      if (groqKey != null && groqKey.isNotEmpty) {
        final groq = GroqService(apiKey: groqKey);
        final result = await groq.generateContent(
          prompt: _buildSynthesisPrompt(intelligence),
          systemPrompt: _systemPrompt,
          temperature: 0.3,
          maxTokens: 4096,
        );
        final trimmed = result.trim();
        if (trimmed.isNotEmpty) {
          content = trimmed;
          usedGroq = true;
        }
      }
    } catch (e) {
      print('[IntelligenceSummary] Groq generation failed: $e');
    }
    final metadata = _buildMetadata(intelligence, startTime, usedGroq);
    final nextVersion = await _getNextVersion(userId);
    final summary = IntelligenceSummary(
      userId: userId,
      version: nextVersion,
      generatedAt: DateTime.now().toUtc(),
      content: content,
      contentHash: _hashContent(content),
      metadata: metadata,
      sections: _extractSectionMetadata(content),
    );
    await _archivePreviousVersion(userId);
    await _summaryRepo.save(summary);
    await _summaryRepo.clearStale(userId);
    return summary;
  }

  Future<BiographicalIntelligence> _gatherIntelligence(String userId) async {
    final entries = await _chronicleAdapter.loadEntries(userId);
    final annotations = await _chronicleAdapter.loadAnnotations(userId);
    final patterns = await _lumaraRepo.loadPatterns(userId);
    final causalChains = await _lumaraRepo.loadCausalChains(userId);
    final relationships = await _lumaraRepo.loadRelationships(userId);
    final gapFills = await _lumaraRepo.loadGapFillEvents(userId);
    final activePatterns = patterns.where((p) => p.status == InferenceStatus.active).toList();
    final activeChains = causalChains.where((c) => c.status == InferenceStatus.active).toList();
    final activeRels = relationships.where((r) => r.status == InferenceStatus.active).toList();

    // CHRONICLE Layers 1–3: monthly, yearly, multi-year summaries (when available)
    List<ChronicleAggregation> monthly = [];
    List<ChronicleAggregation> yearly = [];
    List<ChronicleAggregation> multiyear = [];
    try {
      final aggRepo = ChronicleRepos.aggregation;
      final monthlyPeriods = await aggRepo.listPeriods(ChronicleLayer.monthly);
      for (final period in monthlyPeriods.take(maxMonthlySummaries)) {
        final a = await aggRepo.loadLayer(userId: userId, layer: ChronicleLayer.monthly, period: period);
        if (a != null) monthly.add(a);
      }
      final yearlyPeriods = await aggRepo.listPeriods(ChronicleLayer.yearly);
      for (final period in yearlyPeriods.take(maxYearlySummaries)) {
        final a = await aggRepo.loadLayer(userId: userId, layer: ChronicleLayer.yearly, period: period);
        if (a != null) yearly.add(a);
      }
      final multiyearPeriods = await aggRepo.listPeriods(ChronicleLayer.multiyear);
      for (final period in multiyearPeriods.take(maxMultiyearSummaries)) {
        final a = await aggRepo.loadLayer(userId: userId, layer: ChronicleLayer.multiyear, period: period);
        if (a != null) multiyear.add(a);
      }
    } catch (e) {
      print('[IntelligenceSummary] Could not load CHRONICLE Layer 1–3: $e');
    }

    DateTime? earliest;
    DateTime? latest;
    for (final e in entries) {
      if (earliest == null || e.timestamp.isBefore(earliest)) earliest = e.timestamp;
      if (latest == null || e.timestamp.isAfter(latest)) latest = e.timestamp;
    }
    final monthsCovered = earliest != null && latest != null
        ? (latest.difference(earliest).inDays / 30).ceil().clamp(1, 120)
        : 0;
    return BiographicalIntelligence(
      user: UserIntelligence(
        entries: entries,
        annotations: annotations,
        totalEntries: entries.length,
        temporalSpan: TemporalSpan(
          earliest: earliest ?? DateTime.now(),
          latest: latest ?? DateTime.now(),
          monthsCovered: monthsCovered,
        ),
      ),
      lumara: LumaraIntelligence(
        patterns: activePatterns,
        causalChains: activeChains,
        relationships: activeRels,
        gapFillEvents: gapFills.take(50).toList(),
      ),
      chronicleLayers: ChronicleLayersIntelligence(
        monthly: monthly,
        yearly: yearly,
        multiyear: multiyear,
      ),
      stats: IntelligenceStats(
        entriesAnalyzed: entries.length,
        patternsIdentified: activePatterns.length,
        relationshipsTracked: activeRels.length,
        monthsCovered: monthsCovered,
        confidenceLevel: _confidenceLevel(entries.length, activePatterns.length, activeChains),
      ),
    );
  }

  String _confidenceLevel(
      int entries, int patterns, List<CausalChain> chains) {
    final avgConf = chains.isEmpty
        ? 0.0
        : chains.map((c) => c.confidence).fold<double>(0, (a, b) => a + b) /
            chains.length;
    if (entries < 20 || patterns < 5 || avgConf < 0.5) return 'low';
    if (entries < 100 || patterns < 20 || avgConf < 0.7) return 'medium';
    return 'high';
  }

  String _buildSynthesisPrompt(BiographicalIntelligence i) {
    final sb = StringBuffer();
    sb.writeln('Synthesize a coherent, user-readable Intelligence Summary in markdown from the following. Only the user will see this; it is their personal project memory.');
    sb.writeln();
    sb.writeln('# Layer 0: User content (chats, reflections, voice, documents)');
    sb.writeln('## Entries (last 30 by recency, excerpted)');
    for (final e in i.user.entries.take(30)) {
      sb.writeln('- [${e.timestamp.toIso8601String()}] (${e.modality.name}): ${e.content.replaceAll('\n', ' ').length > 200 ? "${e.content.substring(0, 200)}..." : e.content}');
    }
    sb.writeln('## Annotations (user-approved insights)');
    for (final a in i.user.annotations.take(20)) {
      sb.writeln('- ${a.content.replaceAll('\n', ' ').length > 150 ? "${a.content.substring(0, 150)}..." : a.content}');
    }
    if (i.chronicleLayers.monthly.isNotEmpty || i.chronicleLayers.yearly.isNotEmpty || i.chronicleLayers.multiyear.isNotEmpty) {
      sb.writeln();
      sb.writeln('# CHRONICLE Layers 1–3: Monthly, yearly, multi-year summaries');
      for (final m in i.chronicleLayers.monthly) {
        sb.writeln('## Monthly (${m.period})');
        sb.writeln(m.content.length > 1200 ? '${m.content.substring(0, 1200)}...' : m.content);
        sb.writeln();
      }
      for (final y in i.chronicleLayers.yearly) {
        sb.writeln('## Yearly (${y.period})');
        sb.writeln(y.content.length > 1500 ? '${y.content.substring(0, 1500)}...' : y.content);
        sb.writeln();
      }
      for (final my in i.chronicleLayers.multiyear) {
        sb.writeln('## Multi-year (${my.period})');
        sb.writeln(my.content.length > 1500 ? '${my.content.substring(0, 1500)}...' : my.content);
        sb.writeln();
      }
    }
    sb.writeln();
    sb.writeln('# LUMARA inferred intelligence');
    sb.writeln('## Patterns (${i.lumara.patterns.length})');
    for (final p in i.lumara.patterns.take(15)) {
      sb.writeln('- ${p.description} (${p.category}, confidence: ${p.confidence})');
    }
    sb.writeln('## Causal chains (${i.lumara.causalChains.length})');
    for (final c in i.lumara.causalChains.take(15)) {
      sb.writeln('- "${c.trigger}" → "${c.response}"');
    }
    sb.writeln('## Relationships (${i.lumara.relationships.length})');
    for (final r in i.lumara.relationships.take(10)) {
      sb.writeln('- ${r.entityName} — ${r.role}: ${r.interactionPattern}');
    }
    sb.writeln('## Recent gap-fill events (learning moments)');
    for (final g in i.lumara.gapFillEvents.take(20)) {
      sb.writeln('- ${g.trigger.originalQuery.replaceAll('\n', ' ').length > 80 ? "${g.trigger.originalQuery.substring(0, 80)}..." : g.trigger.originalQuery}');
    }
    sb.writeln();
    sb.writeln('# Instructions');
    sb.writeln('Create ONE coherent markdown document with these exact section headers. Write in clear, readable prose (third person or second person). Be specific: names, dates, patterns. 1500–2500 words. Return ONLY the markdown.');
    sb.writeln();
    sb.writeln('1. **Purpose & context** — What this person is building or pursuing; their role, vision, and how they describe it.');
    sb.writeln('2. **Current state** — Where things stand now: product, validation, team, timeline, concrete milestones.');
    sb.writeln('3. **On the horizon** — Near-term plans, roadmap, next steps, and what they are considering.');
    sb.writeln('4. **Key learnings & principles** — What they have learned; beliefs and principles that guide their approach.');
    sb.writeln('5. **Approach & patterns** — How they work: habits, tools, decision-making style, recurring themes.');
    sb.writeln('6. **Tools & resources** — Stack, tools, key relationships, and resources they rely on.');
    sb.writeln('7. **What I don\'t know yet** — Explicit gaps, uncertainties, or areas with little signal.');
    sb.writeln();
    sb.writeln('Style: natural, coherent narrative. Do not invent facts. Signal confidence ("consistently" vs "seems to"). Return ONLY the markdown, starting with "# Intelligence Summary".');
    return sb.toString();
  }

  String _fallbackContent(BiographicalIntelligence i) {
    final s = i.stats;
    return '''# Intelligence Summary

## About This Summary
Based on **${s.entriesAnalyzed}** entries, **${s.patternsIdentified}** patterns, and **${s.relationshipsTracked}** relationships over **${s.monthsCovered}** months. Confidence: **${s.confidenceLevel}**.
''';
  }

  static const String _systemPrompt = '''
You are LUMARA's intelligence synthesis engine. You generate a single, coherent Intelligence Summary that only the user sees—like a project memory or briefing derived from their Layer 0 (chats, reflections, voice, documents), CHRONICLE Layers 1–3 (monthly, yearly, multi-year summaries), and LUMARA's inferred patterns and relationships.

Output must be:
- Coherent and user-readable: one continuous narrative, not bullet soup.
- Structured with the exact section headers provided (Purpose & context, Current state, On the horizon, Key learnings & principles, Approach & patterns, Tools & resources, What I don't know yet).
- Specific: names, dates, frequencies, concrete examples where the data supports it.
- Honest about confidence: "consistently" / "clearly" when strong signal; "seems to" / "has mentioned" when weaker. Acknowledge gaps explicitly in "What I don't know yet".
- Factual: do not invent or diagnose. Only synthesize from the provided inputs.

Return ONLY the markdown, starting with "# Intelligence Summary". No preamble or meta-commentary.
''';

  IntelligenceSummaryMetadata _buildMetadata(
      BiographicalIntelligence i, DateTime startTime, bool usedGroq) {
    final durationMs = DateTime.now().difference(startTime).inMilliseconds;
    return IntelligenceSummaryMetadata(
      totalEntries: i.user.totalEntries,
      totalPatterns: i.lumara.patterns.length,
      totalRelationships: i.lumara.relationships.length,
      temporalSpan: i.user.temporalSpan,
      confidenceLevel: i.stats.confidenceLevel,
      sectionsIncluded: const [
        'purposeAndContext', 'currentState', 'onTheHorizon',
        'keyLearningsAndPrinciples', 'approachAndPatterns', 'toolsAndResources',
        'whatIDontKnowYet',
      ],
      generationDurationMs: durationMs,
      modelUsed: usedGroq ? 'groq' : 'fallback',
    );
  }

  Map<String, SectionMeta> _extractSectionMetadata(String content) {
    final now = DateTime.now().toUtc();
    final sectionNames = [
      'purposeAndContext', 'currentState', 'onTheHorizon',
      'keyLearningsAndPrinciples', 'approachAndPatterns', 'toolsAndResources',
      'whatIDontKnowYet',
    ];
    final sections = <String, SectionMeta>{};
    for (final name in sectionNames) {
      sections[name] = SectionMeta(lastUpdated: now, confidence: 0.7);
    }
    return sections;
  }

  String _hashContent(String content) {
    final bytes = utf8.encode(content);
    return sha256.convert(bytes).toString();
  }

  Future<int> _getNextVersion(String userId) async {
    final latest = await _summaryRepo.getLatest(userId);
    return (latest?.version ?? 0) + 1;
  }

  Future<void> _archivePreviousVersion(String userId) async {
    final latest = await _summaryRepo.getLatest(userId);
    if (latest == null) return;
    final archived = IntelligenceSummaryVersion(
      userId: userId,
      version: latest.version,
      content: latest.content,
      generatedAt: latest.generatedAt,
      archivedAt: DateTime.now().toUtc(),
    );
    await _summaryRepo.archiveVersion(archived);
  }
}

class ChronicleLayersIntelligence {
  final List<ChronicleAggregation> monthly;
  final List<ChronicleAggregation> yearly;
  final List<ChronicleAggregation> multiyear;

  ChronicleLayersIntelligence({
    required this.monthly,
    required this.yearly,
    required this.multiyear,
  });
}

class BiographicalIntelligence {
  final UserIntelligence user;
  final LumaraIntelligence lumara;
  final ChronicleLayersIntelligence chronicleLayers;
  final IntelligenceStats stats;

  BiographicalIntelligence({
    required this.user,
    required this.lumara,
    required this.chronicleLayers,
    required this.stats,
  });
}

class UserIntelligence {
  final List<UserEntry> entries;
  final List<UserAnnotation> annotations;
  final int totalEntries;
  final TemporalSpan temporalSpan;

  UserIntelligence({
    required this.entries,
    required this.annotations,
    required this.totalEntries,
    required this.temporalSpan,
  });
}

class LumaraIntelligence {
  final List<Pattern> patterns;
  final List<CausalChain> causalChains;
  final List<RelationshipModel> relationships;
  final List<GapFillEvent> gapFillEvents;

  LumaraIntelligence({
    required this.patterns,
    required this.causalChains,
    required this.relationships,
    required this.gapFillEvents,
  });
}

class IntelligenceStats {
  final int entriesAnalyzed;
  final int patternsIdentified;
  final int relationshipsTracked;
  final int monthsCovered;
  final String confidenceLevel;

  IntelligenceStats({
    required this.entriesAnalyzed,
    required this.patternsIdentified,
    required this.relationshipsTracked,
    required this.monthsCovered,
    required this.confidenceLevel,
  });
}
