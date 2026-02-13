import 'package:flutter/foundation.dart';

@immutable
class PatternInsights {
  final String recurrenceType;
  final String? trigger;
  final String? phaseCorrelation;
  final double? phaseCorrelationStrength;
  final int? typicalDurationDays;
  final String resolutionConsistency;
  final String? primaryResolution;
  final double confidence;

  const PatternInsights({
    required this.recurrenceType,
    this.trigger,
    this.phaseCorrelation,
    this.phaseCorrelationStrength,
    this.typicalDurationDays,
    required this.resolutionConsistency,
    this.primaryResolution,
    required this.confidence,
  });

  factory PatternInsights.empty() => const PatternInsights(
        recurrenceType: 'emerging',
        resolutionConsistency: 'none',
        confidence: 0.0,
      );

  Map<String, dynamic> toJson() => {
        'recurrence_type': recurrenceType,
        'trigger': trigger,
        'phase_correlation': phaseCorrelation,
        'phase_correlation_strength': phaseCorrelationStrength,
        'typical_duration_days': typicalDurationDays,
        'resolution_consistency': resolutionConsistency,
        'primary_resolution': primaryResolution,
        'confidence': confidence,
      };

  factory PatternInsights.fromJson(Map<String, dynamic> json) => PatternInsights(
        recurrenceType: json['recurrence_type'] as String,
        trigger: json['trigger'] as String?,
        phaseCorrelation: json['phase_correlation'] as String?,
        phaseCorrelationStrength:
            (json['phase_correlation_strength'] as num?)?.toDouble(),
        typicalDurationDays: json['typical_duration_days'] as int?,
        resolutionConsistency: json['resolution_consistency'] as String,
        primaryResolution: json['primary_resolution'] as String?,
        confidence: (json['confidence'] as num).toDouble(),
      );
}
