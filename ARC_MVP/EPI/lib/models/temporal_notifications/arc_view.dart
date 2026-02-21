// lib/models/temporal_notifications/arc_view.dart
// Model for 6-month arc view

import 'package:json_annotation/json_annotation.dart';

part 'arc_view.g.dart';

@JsonSerializable()
class PhaseTransition {
  final String fromPhase;
  final String toPhase;
  final DateTime transitionDate;
  final String? catalyst;  // What triggered the transition

  PhaseTransition({
    required this.fromPhase,
    required this.toPhase,
    required this.transitionDate,
    this.catalyst,
  });

  factory PhaseTransition.fromJson(Map<String, dynamic> json) =>
      _$PhaseTransitionFromJson(json);

  Map<String, dynamic> toJson() => _$PhaseTransitionToJson(this);
}

@JsonSerializable()
class TransformationMoment {
  final DateTime date;
  final String description;
  final double significanceScore;  // 0.0 to 1.0
  final String? entryId;

  TransformationMoment({
    required this.date,
    required this.description,
    required this.significanceScore,
    this.entryId,
  });

  factory TransformationMoment.fromJson(Map<String, dynamic> json) =>
      _$TransformationMomentFromJson(json);

  Map<String, dynamic> toJson() => _$TransformationMomentToJson(this);
}

@JsonSerializable()
class ArcformData {
  final Map<String, double> phaseDistribution;  // Phase -> percentage
  final List<Map<String, dynamic>> timelinePoints;  // For visualization

  ArcformData({
    required this.phaseDistribution,
    required this.timelinePoints,
  });

  factory ArcformData.fromJson(Map<String, dynamic> json) =>
      _$ArcformDataFromJson(json);

  Map<String, dynamic> toJson() => _$ArcformDataToJson(this);
}

@JsonSerializable()
class ArcView {
  final DateTime periodStart;
  final DateTime periodEnd;
  final List<PhaseTransition> phaseJourney;
  final List<String> persistentThemes;
  final List<TransformationMoment> keyMoments;
  final ArcformData arcformVisualization;

  ArcView({
    required this.periodStart,
    required this.periodEnd,
    required this.phaseJourney,
    required this.persistentThemes,
    required this.keyMoments,
    required this.arcformVisualization,
  });

  factory ArcView.fromJson(Map<String, dynamic> json) =>
      _$ArcViewFromJson(json);

  Map<String, dynamic> toJson() => _$ArcViewToJson(this);
}

