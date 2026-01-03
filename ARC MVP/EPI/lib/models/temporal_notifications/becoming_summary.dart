// lib/models/temporal_notifications/becoming_summary.dart
// Model for yearly becoming summary

import 'package:json_annotation/json_annotation.dart';
import 'arc_view.dart';

part 'becoming_summary.g.dart';

@JsonSerializable()
class MilestoneEntry {
  final String entryId;
  final DateTime date;
  final String quote;  // <15 words
  final String significance;

  MilestoneEntry({
    required this.entryId,
    required this.date,
    required this.quote,
    required this.significance,
  });

  factory MilestoneEntry.fromJson(Map<String, dynamic> json) =>
      _$MilestoneEntryFromJson(json);

  Map<String, dynamic> toJson() => _$MilestoneEntryToJson(this);
}

@JsonSerializable()
class BecomingSummary {
  final int year;
  final String narrativeSummary;        // AI-generated developmental narrative
  final List<PhaseTransition> yearPhases;
  final List<String> themesResolved;
  final List<String> themesEmergent;
  final List<String> themesRecurring;
  final Map<String, double> emotionalArcData;  // For visualization
  final List<MilestoneEntry> significantEntries;

  BecomingSummary({
    required this.year,
    required this.narrativeSummary,
    required this.yearPhases,
    required this.themesResolved,
    required this.themesEmergent,
    required this.themesRecurring,
    required this.emotionalArcData,
    required this.significantEntries,
  });

  factory BecomingSummary.fromJson(Map<String, dynamic> json) =>
      _$BecomingSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$BecomingSummaryToJson(this);
}

