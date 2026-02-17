import 'package:my_app/chronicle/core/chronicle_repos.dart';
import 'package:my_app/chronicle/models/chronicle_layer.dart';
import 'package:my_app/chronicle/storage/layer0_repository.dart';
import 'package:my_app/lumara/agents/writing/theme_tracker.dart';
import 'package:my_app/lumara/agents/writing/writing_models.dart';
import 'package:my_app/services/user_phase_service.dart';

/// Timeline and phase context for the Writing Agent (and optionally Research).
/// Filled by [TimelineContextService] and injected into the system prompt.
class WritingTimelineContext {
  final String timelineSummary;
  final String recentEntries;
  final String dominantThemes;
  final String patterns;
  final String currentPhase;
  final String phaseDescription;

  const WritingTimelineContext({
    this.timelineSummary = '',
    this.recentEntries = '',
    this.dominantThemes = '',
    this.patterns = '',
    this.currentPhase = 'Discovery',
    this.phaseDescription = '',
  });
}

/// Timeline context for the Research Agent: focus areas, projects, past research, phase.
class ResearchTimelineContext {
  final String timelineSummary;
  final String focusAreas;
  final String currentProjects;
  final String pastResearch;
  final String currentPhase;
  final String phaseDescription;

  const ResearchTimelineContext({
    this.timelineSummary = '',
    this.focusAreas = '',
    this.currentProjects = '',
    this.pastResearch = '',
    this.currentPhase = 'Discovery',
    this.phaseDescription = '',
  });
}

/// Builds timeline summary, recent entries, dominant themes, and patterns
/// for the Writing Agent system prompt. Uses Layer0 + Aggregation repos.
class TimelineContextService {
  TimelineContextService({
    Layer0Repository? layer0Repository,
    ThemeTracker? themeTracker,
  })  : _layer0 = layer0Repository ?? ChronicleRepos.layer0,
        _themeTracker = themeTracker ?? ThemeTracker();

  final Layer0Repository _layer0;
  final ThemeTracker _themeTracker;

  static const int _timelineSummaryMonths = 3;
  static const int _timelineSummaryCharsPerMonth = 500;
  static const int _recentEntriesLimit = 10;
  static const int _recentEntryPreviewChars = 80;

  /// Load timeline context for the Writing Agent (last ~90 days + phase).
  Future<WritingTimelineContext> getWritingContext({
    required String userId,
    String contentTopic = '',
  }) async {
    await _layer0.initialize();

    final timelineSummary = await _buildTimelineSummary(userId);
    final recentEntries = await _buildRecentEntries(userId);
    final themeContext = await _themeTracker.getThemeContext(
      userId: userId,
      contentTopic: contentTopic,
    );
    final dominantThemes = _formatDominantThemes(themeContext);
    final patterns = _formatPatterns(themeContext);
    final phaseStr = await UserPhaseService.getCurrentPhase();
    final phaseDescription = UserPhaseService.getPhaseDescription(phaseStr);

    return WritingTimelineContext(
      timelineSummary: timelineSummary,
      recentEntries: recentEntries,
      dominantThemes: dominantThemes,
      patterns: patterns,
      currentPhase: phaseStr.isEmpty ? 'Discovery' : phaseStr,
      phaseDescription: phaseDescription,
    );
  }

  /// Load timeline context for the Research Agent (focus areas, projects, phase).
  /// [pastResearchSummary] is typically from PriorResearchContext.existingKnowledge.summary.
  Future<ResearchTimelineContext> getResearchContext({
    required String userId,
    String pastResearchSummary = '',
  }) async {
    await _layer0.initialize();
    final timelineSummary = await _buildTimelineSummary(userId);
    final themeContext = await _themeTracker.getThemeContext(
      userId: userId,
      contentTopic: '',
    );
    final focusAreas = _formatDominantThemes(themeContext);
    final currentProjects = _formatPatterns(themeContext);
    final phaseStr = await UserPhaseService.getCurrentPhase();
    final phaseDescription = UserPhaseService.getPhaseDescription(phaseStr);
    return ResearchTimelineContext(
      timelineSummary: timelineSummary,
      focusAreas: focusAreas,
      currentProjects: currentProjects,
      pastResearch: pastResearchSummary.isEmpty ? 'None.' : pastResearchSummary,
      currentPhase: phaseStr.isEmpty ? 'Discovery' : phaseStr,
      phaseDescription: phaseDescription,
    );
  }

  Future<String> _buildTimelineSummary(String userId) async {
    final aggRepo = ChronicleRepos.aggregation;
    final periods = await aggRepo.listPeriods(ChronicleLayer.monthly);
    final recentPeriods = periods.take(_timelineSummaryMonths).toList();
    if (recentPeriods.isEmpty) return 'No monthly summaries yet.';

    final parts = <String>[];
    for (final period in recentPeriods) {
      final agg = await aggRepo.loadLayer(
        userId: userId,
        layer: ChronicleLayer.monthly,
        period: period,
      );
      if (agg == null || agg.content.isEmpty) continue;
      final excerpt = agg.content.length > _timelineSummaryCharsPerMonth
          ? '${agg.content.substring(0, _timelineSummaryCharsPerMonth)}...'
          : agg.content;
      parts.add('[$period]\n$excerpt');
    }
    return parts.isEmpty ? 'No monthly summaries yet.' : parts.join('\n\n');
  }

  Future<String> _buildRecentEntries(String userId) async {
    final entries = await _layer0.getRecentEntries(userId, _recentEntriesLimit);
    if (entries.isEmpty) return 'No recent entries.';

    final lines = entries.map((e) {
      final date = e.timestamp;
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final preview = e.content.length > _recentEntryPreviewChars
          ? '${e.content.substring(0, _recentEntryPreviewChars)}...'
          : e.content;
      return '$dateStr: $preview';
    }).toList();
    return lines.join('\n');
  }

  String _formatDominantThemes(ThemeContext ctx) {
    final themes = ctx.primaryThemes.isEmpty
        ? <String>[]
        : List<String>.from(ctx.primaryThemes);
    if (ctx.recurrentMetaphors.isNotEmpty) {
      themes.addAll(ctx.recurrentMetaphors);
    }
    if (themes.isEmpty) return 'None specified.';
    return themes.take(15).join(', ');
  }

  String _formatPatterns(ThemeContext ctx) {
    final parts = <String>[];
    for (final e in ctx.establishedPositions.entries) {
      parts.add('${e.key}: ${e.value}');
    }
    for (final m in ctx.relatedMoments.take(5)) {
      final y = m.date.year;
      final mo = m.date.month.toString().padLeft(2, '0');
      parts.add('Moment ($y-$mo): ${m.summary.length > 60 ? "${m.summary.substring(0, 60)}..." : m.summary}');
    }
    if (parts.isEmpty) return 'None specified.';
    return parts.join('; ');
  }
}
