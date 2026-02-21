// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'arc_view.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PhaseTransition _$PhaseTransitionFromJson(Map<String, dynamic> json) =>
    PhaseTransition(
      fromPhase: json['fromPhase'] as String,
      toPhase: json['toPhase'] as String,
      transitionDate: DateTime.parse(json['transitionDate'] as String),
      catalyst: json['catalyst'] as String?,
    );

Map<String, dynamic> _$PhaseTransitionToJson(PhaseTransition instance) =>
    <String, dynamic>{
      'fromPhase': instance.fromPhase,
      'toPhase': instance.toPhase,
      'transitionDate': instance.transitionDate.toIso8601String(),
      'catalyst': instance.catalyst,
    };

TransformationMoment _$TransformationMomentFromJson(
        Map<String, dynamic> json) =>
    TransformationMoment(
      date: DateTime.parse(json['date'] as String),
      description: json['description'] as String,
      significanceScore: (json['significanceScore'] as num).toDouble(),
      entryId: json['entryId'] as String?,
    );

Map<String, dynamic> _$TransformationMomentToJson(
        TransformationMoment instance) =>
    <String, dynamic>{
      'date': instance.date.toIso8601String(),
      'description': instance.description,
      'significanceScore': instance.significanceScore,
      'entryId': instance.entryId,
    };

ArcformData _$ArcformDataFromJson(Map<String, dynamic> json) => ArcformData(
      phaseDistribution:
          (json['phaseDistribution'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ),
      timelinePoints: (json['timelinePoints'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
    );

Map<String, dynamic> _$ArcformDataToJson(ArcformData instance) =>
    <String, dynamic>{
      'phaseDistribution': instance.phaseDistribution,
      'timelinePoints': instance.timelinePoints,
    };

ArcView _$ArcViewFromJson(Map<String, dynamic> json) => ArcView(
      periodStart: DateTime.parse(json['periodStart'] as String),
      periodEnd: DateTime.parse(json['periodEnd'] as String),
      phaseJourney: (json['phaseJourney'] as List<dynamic>)
          .map((e) => PhaseTransition.fromJson(e as Map<String, dynamic>))
          .toList(),
      persistentThemes: (json['persistentThemes'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      keyMoments: (json['keyMoments'] as List<dynamic>)
          .map((e) => TransformationMoment.fromJson(e as Map<String, dynamic>))
          .toList(),
      arcformVisualization: ArcformData.fromJson(
          json['arcformVisualization'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ArcViewToJson(ArcView instance) => <String, dynamic>{
      'periodStart': instance.periodStart.toIso8601String(),
      'periodEnd': instance.periodEnd.toIso8601String(),
      'phaseJourney': instance.phaseJourney,
      'persistentThemes': instance.persistentThemes,
      'keyMoments': instance.keyMoments,
      'arcformVisualization': instance.arcformVisualization,
    };
