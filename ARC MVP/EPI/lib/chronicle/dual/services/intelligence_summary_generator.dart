// lib/chronicle/dual/services/intelligence_summary_generator.dart
//
// Generates the Intelligence Summary (Layer 3) from User + LUMARA chronicles.
// Synthesis is done via an injected LLM (Groq/Gemini from app layer).

import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/chronicle_models.dart';
import '../models/intelligence_summary_models.dart';
import '../repositories/user_chronicle_repository.dart';
import '../repositories/lumara_chronicle_repository.dart';
import '../repositories/intelligence_summary_repository.dart';

/// Callback to generate markdown via app's LLM (Groq/Gemini). Optional; if null, generation returns placeholder.
typedef IntelligenceSummaryLLM = Future<String> Function(
  String systemPrompt,
  String userPrompt, {
  int? maxTokens,
});

class IntelligenceSummaryGenerator {
  IntelligenceSummaryGenerator({
    required UserChronicleRepository userRepo,
    required LumaraChronicleRepository lumaraRepo,
    required IntelligenceSummaryRepository summaryRepo,
    IntelligenceSummaryLLM? generate,
  })  : _userRepo = userRepo,
        _lumaraRepo = lumaraRepo,
        _summaryRepo = summaryRepo,
        _generate = generate;

  final UserChronicleRepository _userRepo;
  final LumaraChronicleRepository _lumaraRepo;
  final IntelligenceSummaryRepository _summaryRepo;
  final IntelligenceSummaryLLM? _generate;

  /// Generate the full Intelligence Summary for [userId]. Saves and archives previous version.
  Future<IntelligenceSummary> generateSummary(String userId) async {
    final startTime = DateTime.now();
    final intelligence = await _gatherIntelligence(userId);
    String content;
    if (_generate != null) {
      try {
        content = await _generate!(
          _systemPrompt,
          _buildSynthesisPrompt(intelligence),
          maxTokens: 4096,
        );
        content = content.trim();
        if (content.isEmpty) content = _placeholderContent(intelligence);
      } catch (e) {
        print('[IntelligenceSummary] LLM failed: $e');
        content = _placeholderContent(intelligence);
      }
    } else {
      content = _placeholderContent(intelligence);
    }
    final metadata = _buildMetadata(intelligence, startTime);
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
    final entries = await _userRepo.loadEntries(userId);
    final annotations = await _userRepo.loadAnnotations(userId);
    final patterns = await _lumaraRepo.loadPatterns(userId);
    final causalChains = await _lumaraRepo.loadCausalChains(userId);
    final relationships = await _lumaraRepo.loadRelationships(userId);
    final gapFills = await _lumaraRepo.loadGapFillEvents(userId);
    final activePatterns = patterns.where((p) => p.status == InferenceStatus.active).toList();
    final activeChains = causalChains.where((c) => c.status == InferenceStatus.active).toList();
    final activeRels = relationships.where((r) => r.status == InferenceStatus.active).toList();
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
    sb.writeln('Generate a comprehensive Intelligence Summary in markdown.');
    sb.writeln();
    sb.writeln('# User Chronicle');
    sb.writeln('## Entries (last 30 by recency, excerpted)');
    for (final e in i.user.entries.take(30)) {
      sb.writeln('- [${e.timestamp.toIso8601String()}] (${e.modality.name}): ${e.content.replaceAll('\n', ' ').length > 200 ? "${e.content.substring(0, 200)}..." : e.content}');
    }
    sb.writeln('## Annotations (approved insights)');
    for (final a in i.user.annotations.take(20)) {
      sb.writeln('- ${a.content.replaceAll('\n', ' ').length > 150 ? "${a.content.substring(0, 150)}..." : a.content}');
    }
    sb.writeln();
    sb.writeln('# LUMARA Inferred Intelligence');
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
    sb.writeln('Create a markdown document with these sections:');
    sb.writeln('1. **About You** - Core identity, current focus (2-3 paragraphs)');
    sb.writeln('2. **Current Life Phase** - Readiness, trajectory (1-2 paragraphs)');
    sb.writeln('3. **Key Relationships** - Important people and patterns');
    sb.writeln('4. **Recurring Patterns** - Behavioral/emotional themes');
    sb.writeln('5. **Values and Priorities** - Inferred from entries');
    sb.writeln('6. **Goals and Recent Developments** - Short-term and current');
    sb.writeln('7. **What I Don\'t Know Yet** - Explicit gaps');
    sb.writeln('Style: warm, second person ("You\'re..."). 1500-2500 words. Return ONLY the markdown.');
    return sb.toString();
  }

  String _placeholderContent(BiographicalIntelligence i) {
    final s = i.stats;
    return '''# Intelligence Summary
*Generated from your timeline and LUMARA's learning (no LLM available for full synthesis).*

## About This Summary
Based on **${s.entriesAnalyzed}** entries, **${s.patternsIdentified}** patterns, and **${s.relationshipsTracked}** relationships over **${s.monthsCovered}** months. Confidence: **${s.confidenceLevel}**.

## Next Steps
Enable an API key (Groq or Gemini) in LUMARA settings to generate a full natural-language Intelligence Summary. Until then, you can see raw learning in **Timeline & Learning (Dual Chronicle)**.
''';
  }

  static const String _systemPrompt = '''
You are LUMARA's intelligence synthesis engine. Generate a comprehensive Intelligence Summary in markdown from biographical data.

Principles:
- Natural, warm prose; second person ("You're...").
- Specific: use examples, dates, frequencies.
- Signal confidence: "You consistently..." (high) vs "You seem to..." (low).
- Acknowledge what you don't know.
- Do not invent information or diagnose.
Return ONLY markdown, starting with "# Intelligence Summary".
''';

  IntelligenceSummaryMetadata _buildMetadata(
      BiographicalIntelligence i, DateTime startTime) {
    final durationMs = DateTime.now().difference(startTime).inMilliseconds;
    return IntelligenceSummaryMetadata(
      totalEntries: i.user.totalEntries,
      totalPatterns: i.lumara.patterns.length,
      totalRelationships: i.lumara.relationships.length,
      temporalSpan: i.user.temporalSpan,
      confidenceLevel: i.stats.confidenceLevel,
      sectionsIncluded: const [
        'aboutYou', 'currentPhase', 'relationships', 'patterns',
        'values', 'goals', 'recentDevelopments', 'unknowns',
      ],
      generationDurationMs: durationMs,
      modelUsed: _generate != null ? 'groq_or_gemini' : 'placeholder',
    );
  }

  Map<String, SectionMeta> _extractSectionMetadata(String content) {
    final now = DateTime.now().toUtc();
    final sections = <String, SectionMeta>{};
    for (final name in [
      'aboutYou', 'currentPhase', 'relationships', 'patterns',
      'values', 'goals', 'recentDevelopments', 'unknowns',
    ]) {
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

class BiographicalIntelligence {
  final UserIntelligence user;
  final LumaraIntelligence lumara;
  final IntelligenceStats stats;

  BiographicalIntelligence({
    required this.user,
    required this.lumara,
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
