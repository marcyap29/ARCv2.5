import 'package:flutter/foundation.dart';

@immutable
class ThemeAppearance {
  final String period;
  final List<String> entryIds;
  final String aliasUsed;
  final int frequency;
  final String phase;
  final double emotionalIntensity;
  final List<String> context;
  final List<String> rivetTransitions;
  final ThemeResolution? resolution;

  const ThemeAppearance({
    required this.period,
    required this.entryIds,
    required this.aliasUsed,
    required this.frequency,
    required this.phase,
    required this.emotionalIntensity,
    required this.context,
    required this.rivetTransitions,
    this.resolution,
  });

  bool get inProgress => resolution == null || !resolution!.resolved;

  ThemeAppearance copyWith({ThemeResolution? resolution}) => ThemeAppearance(
        period: period,
        entryIds: entryIds,
        aliasUsed: aliasUsed,
        frequency: frequency,
        phase: phase,
        emotionalIntensity: emotionalIntensity,
        context: context,
        rivetTransitions: rivetTransitions,
        resolution: resolution ?? this.resolution,
      );

  Map<String, dynamic> toJson() => {
        'period': period,
        'entry_ids': entryIds,
        'alias_used': aliasUsed,
        'frequency': frequency,
        'phase': phase,
        'emotional_intensity': emotionalIntensity,
        'context': context,
        'rivet_transitions': rivetTransitions,
        'resolution': resolution?.toJson(),
      };

  factory ThemeAppearance.fromJson(Map<String, dynamic> json) => ThemeAppearance(
        period: json['period'] as String,
        entryIds: (json['entry_ids'] as List).cast<String>(),
        aliasUsed: json['alias_used'] as String,
        frequency: json['frequency'] as int,
        phase: json['phase'] as String,
        emotionalIntensity: (json['emotional_intensity'] as num).toDouble(),
        context: (json['context'] as List).cast<String>(),
        rivetTransitions: (json['rivet_transitions'] as List).cast<String>(),
        resolution: json['resolution'] != null
            ? ThemeResolution.fromJson(
                json['resolution'] as Map<String, dynamic>,
              )
            : null,
      );
}

@immutable
class ThemeResolution {
  final bool resolved;
  final DateTime? resolutionDate;
  final String? resolutionType;
  final int? daysToResolve;

  const ThemeResolution({
    required this.resolved,
    this.resolutionDate,
    this.resolutionType,
    this.daysToResolve,
  });

  Map<String, dynamic> toJson() => {
        'resolved': resolved,
        'resolution_date': resolutionDate?.toIso8601String(),
        'resolution_type': resolutionType,
        'days_to_resolve': daysToResolve,
      };

  factory ThemeResolution.fromJson(Map<String, dynamic> json) => ThemeResolution(
        resolved: json['resolved'] as bool,
        resolutionDate: json['resolution_date'] != null
            ? DateTime.parse(json['resolution_date'] as String)
            : null,
        resolutionType: json['resolution_type'] as String?,
        daysToResolve: json['days_to_resolve'] as int?,
      );
}
