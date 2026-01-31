// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'becoming_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MilestoneEntry _$MilestoneEntryFromJson(Map<String, dynamic> json) =>
    MilestoneEntry(
      entryId: json['entryId'] as String,
      date: DateTime.parse(json['date'] as String),
      quote: json['quote'] as String,
      significance: json['significance'] as String,
    );

Map<String, dynamic> _$MilestoneEntryToJson(MilestoneEntry instance) =>
    <String, dynamic>{
      'entryId': instance.entryId,
      'date': instance.date.toIso8601String(),
      'quote': instance.quote,
      'significance': instance.significance,
    };

BecomingSummary _$BecomingSummaryFromJson(Map<String, dynamic> json) =>
    BecomingSummary(
      year: (json['year'] as num).toInt(),
      narrativeSummary: json['narrativeSummary'] as String,
      yearPhases: (json['yearPhases'] as List<dynamic>)
          .map((e) => PhaseTransition.fromJson(e as Map<String, dynamic>))
          .toList(),
      themesResolved: (json['themesResolved'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      themesEmergent: (json['themesEmergent'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      themesRecurring: (json['themesRecurring'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      emotionalArcData: (json['emotionalArcData'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ),
      significantEntries: (json['significantEntries'] as List<dynamic>)
          .map((e) => MilestoneEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$BecomingSummaryToJson(BecomingSummary instance) =>
    <String, dynamic>{
      'year': instance.year,
      'narrativeSummary': instance.narrativeSummary,
      'yearPhases': instance.yearPhases,
      'themesResolved': instance.themesResolved,
      'themesEmergent': instance.themesEmergent,
      'themesRecurring': instance.themesRecurring,
      'emotionalArcData': instance.emotionalArcData,
      'significantEntries': instance.significantEntries,
    };
