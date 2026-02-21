// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'thread_review.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EmotionalThread _$EmotionalThreadFromJson(Map<String, dynamic> json) =>
    EmotionalThread(
      theme: json['theme'] as String,
      intensityTrend: (json['intensityTrend'] as num).toDouble(),
      frequency: (json['frequency'] as num).toInt(),
      entryIds:
          (json['entryIds'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$EmotionalThreadToJson(EmotionalThread instance) =>
    <String, dynamic>{
      'theme': instance.theme,
      'intensityTrend': instance.intensityTrend,
      'frequency': instance.frequency,
      'entryIds': instance.entryIds,
    };

PhaseStatus _$PhaseStatusFromJson(Map<String, dynamic> json) => PhaseStatus(
      currentPhase: json['currentPhase'] as String,
      daysInPhase: (json['daysInPhase'] as num).toInt(),
      microShifts: (json['microShifts'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$PhaseStatusToJson(PhaseStatus instance) =>
    <String, dynamic>{
      'currentPhase': instance.currentPhase,
      'daysInPhase': instance.daysInPhase,
      'microShifts': instance.microShifts,
    };

PatternInsight _$PatternInsightFromJson(Map<String, dynamic> json) =>
    PatternInsight(
      description: json['description'] as String,
      supportingEntryIds: (json['supportingEntryIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$PatternInsightToJson(PatternInsight instance) =>
    <String, dynamic>{
      'description': instance.description,
      'supportingEntryIds': instance.supportingEntryIds,
    };

ThreadReview _$ThreadReviewFromJson(Map<String, dynamic> json) => ThreadReview(
      periodStart: DateTime.parse(json['periodStart'] as String),
      periodEnd: DateTime.parse(json['periodEnd'] as String),
      dominantThreads: (json['dominantThreads'] as List<dynamic>)
          .map((e) => EmotionalThread.fromJson(e as Map<String, dynamic>))
          .toList(),
      phaseStatus:
          PhaseStatus.fromJson(json['phaseStatus'] as Map<String, dynamic>),
      patterns: (json['patterns'] as List<dynamic>)
          .map((e) => PatternInsight.fromJson(e as Map<String, dynamic>))
          .toList(),
      surprisingContradiction: json['surprisingContradiction'] as String?,
      entryCount: (json['entryCount'] as num).toInt(),
    );

Map<String, dynamic> _$ThreadReviewToJson(ThreadReview instance) =>
    <String, dynamic>{
      'periodStart': instance.periodStart.toIso8601String(),
      'periodEnd': instance.periodEnd.toIso8601String(),
      'dominantThreads': instance.dominantThreads,
      'phaseStatus': instance.phaseStatus,
      'patterns': instance.patterns,
      'surprisingContradiction': instance.surprisingContradiction,
      'entryCount': instance.entryCount,
    };
