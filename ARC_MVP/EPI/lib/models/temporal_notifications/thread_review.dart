// lib/models/temporal_notifications/thread_review.dart
// Model for monthly thread reviews

import 'package:json_annotation/json_annotation.dart';

part 'thread_review.g.dart';

@JsonSerializable()
class EmotionalThread {
  final String theme;
  final double intensityTrend;  // -1.0 to 1.0 (declining to rising)
  final int frequency;          // Number of mentions
  final List<String> entryIds;  // Supporting entry IDs

  EmotionalThread({
    required this.theme,
    required this.intensityTrend,
    required this.frequency,
    required this.entryIds,
  });

  factory EmotionalThread.fromJson(Map<String, dynamic> json) =>
      _$EmotionalThreadFromJson(json);

  Map<String, dynamic> toJson() => _$EmotionalThreadToJson(this);
}

@JsonSerializable()
class PhaseStatus {
  final String currentPhase;
  final int daysInPhase;
  final List<String> microShifts;  // Detected micro-shifts in phase

  PhaseStatus({
    required this.currentPhase,
    required this.daysInPhase,
    required this.microShifts,
  });

  factory PhaseStatus.fromJson(Map<String, dynamic> json) =>
      _$PhaseStatusFromJson(json);

  Map<String, dynamic> toJson() => _$PhaseStatusToJson(this);
}

@JsonSerializable()
class PatternInsight {
  final String description;
  final List<String> supportingEntryIds;

  PatternInsight({
    required this.description,
    required this.supportingEntryIds,
  });

  factory PatternInsight.fromJson(Map<String, dynamic> json) =>
      _$PatternInsightFromJson(json);

  Map<String, dynamic> toJson() => _$PatternInsightToJson(this);
}

@JsonSerializable()
class ThreadReview {
  final DateTime periodStart;
  final DateTime periodEnd;
  final List<EmotionalThread> dominantThreads;
  final PhaseStatus phaseStatus;
  final List<PatternInsight> patterns;
  final String? surprisingContradiction;
  final int entryCount;

  ThreadReview({
    required this.periodStart,
    required this.periodEnd,
    required this.dominantThreads,
    required this.phaseStatus,
    required this.patterns,
    this.surprisingContradiction,
    required this.entryCount,
  });

  factory ThreadReview.fromJson(Map<String, dynamic> json) =>
      _$ThreadReviewFromJson(json);

  Map<String, dynamic> toJson() => _$ThreadReviewToJson(this);
}

