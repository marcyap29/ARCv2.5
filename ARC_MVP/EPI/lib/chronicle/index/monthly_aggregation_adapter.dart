import '../models/chronicle_aggregation.dart';
import '../models/chronicle_layer.dart';

/// Adapter: data from monthly synthesis used to update the cross-temporal index.
/// Built by parsing a [ChronicleAggregation]'s markdown content.
class MonthlyAggregation {
  final String period;
  final List<String> dominantThemes;
  final List<String> sourceEntryIds;
  final String content;
  final String dominantPhase;
  final double? avgEmotionalIntensity;
  final List<String>? rivetTransitions;
  final List<String> significantEvents;

  MonthlyAggregation({
    required this.period,
    required this.dominantThemes,
    required this.sourceEntryIds,
    required this.content,
    required this.dominantPhase,
    this.avgEmotionalIntensity,
    this.rivetTransitions,
    required this.significantEvents,
  });

  /// Build from a monthly [ChronicleAggregation] by parsing its content.
  static MonthlyAggregation fromChronicleAggregation(
    ChronicleAggregation aggregation,
  ) {
    if (aggregation.layer != ChronicleLayer.monthly) {
      throw ArgumentError(
        'Expected monthly aggregation, got ${aggregation.layer.displayName}',
      );
    }

    final content = aggregation.content;

    final dominantThemes = _parseThemes(content);
    final dominantPhase = _parsePrimaryPhase(content);
    final avgEmotionalIntensity = _parseSentinelAverage(content);
    final significantEvents = _parseSignificantEvents(content);

    return MonthlyAggregation(
      period: aggregation.period,
      dominantThemes: dominantThemes,
      sourceEntryIds: List<String>.from(aggregation.sourceEntryIds),
      content: content,
      dominantPhase: dominantPhase,
      avgEmotionalIntensity: avgEmotionalIntensity,
      rivetTransitions: null,
      significantEvents: significantEvents,
    );
  }

  static final RegExp _themePattern =
      RegExp(r'\*\*(.+?)\*\* \(confidence: (\w+)\)');

  static List<String> _parseThemes(String content) {
    final matches = _themePattern.allMatches(content);
    return matches
        .map((m) => (m.group(1) ?? '').trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  static String _parsePrimaryPhase(String content) {
    final phaseMatch = RegExp(r'\*\*Primary phase:\*\* (\w+)').firstMatch(content);
    return phaseMatch?.group(1) ?? 'Unknown';
  }

  static double? _parseSentinelAverage(String content) {
    final sentinelMatch =
        RegExp(r'\*\*SENTINEL average:\*\* ([\d.]+)').firstMatch(content);
    if (sentinelMatch == null) return null;
    return double.tryParse(sentinelMatch.group(1) ?? '');
  }

  static List<String> _parseSignificantEvents(String content) {
    final sectionMatch = RegExp(
      r'## Significant Events\s*(.*?)(?=\n##|\n---|\z)',
      dotAll: true,
    ).firstMatch(content);

    if (sectionMatch == null) return [];

    final section = sectionMatch.group(1) ?? '';
    if (section.trim().startsWith('No significant events')) return [];

    final bulletMatch = RegExp(r'-\s+\*\*[^*]+\*\*:\s*(.+)');
    return bulletMatch
        .allMatches(section)
        .map((m) => (m.group(1) ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
