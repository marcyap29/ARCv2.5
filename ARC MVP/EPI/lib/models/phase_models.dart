// lib/models/phase_models.dart
// Phase timeline and regime models for RIVET Sweep

import 'package:hive/hive.dart';

part 'phase_models.g.dart';

enum PhaseLabel {
  discovery,
  expansion,
  transition,
  consolidation,
  recovery,
  breakthrough,
}

enum PhaseSource {
  user,
  rivet,
}

@HiveType(typeId: 200)
class PhaseRegime {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final PhaseLabel label;
  
  @HiveField(2)
  final DateTime start;
  
  @HiveField(3)
  final DateTime? end; // null = ongoing
  
  @HiveField(4)
  final PhaseSource source;
  
  @HiveField(5)
  final double? confidence; // required if source=rivet
  
  @HiveField(6)
  final DateTime? inferredAt; // if source=rivet
  
  @HiveField(7)
  final List<String> anchors; // entry ids that justify this regime
  
  @HiveField(8)
  final DateTime createdAt;
  
  @HiveField(9)
  final DateTime updatedAt;

  PhaseRegime({
    required this.id,
    required this.label,
    required this.start,
    this.end,
    required this.source,
    this.confidence,
    this.inferredAt,
    this.anchors = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOngoing => end == null;
  
  Duration get duration => (end ?? DateTime.now()).difference(start);
  
  bool contains(DateTime timestamp) {
    return timestamp.isAfter(start) && 
           (end == null || timestamp.isBefore(end!));
  }

  factory PhaseRegime.fromJson(Map<String, dynamic> json) {
    return PhaseRegime(
      id: json['id'] as String,
      label: PhaseLabel.values.firstWhere(
        (e) => e.name == json['label'],
        orElse: () => PhaseLabel.discovery,
      ),
      start: DateTime.parse(json['start']),
      end: json['end'] != null ? DateTime.parse(json['end']) : null,
      source: PhaseSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => PhaseSource.user,
      ),
      confidence: json['confidence'] as double?,
      inferredAt: json['inferred_at'] != null ? DateTime.parse(json['inferred_at']) : null,
      anchors: (json['anchors'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label.name,
      'start': start.toIso8601String(),
      'end': end?.toIso8601String(),
      'source': source.name,
      'confidence': confidence,
      'inferred_at': inferredAt?.toIso8601String(),
      'anchors': anchors,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  PhaseRegime copyWith({
    String? id,
    PhaseLabel? label,
    DateTime? start,
    DateTime? end,
    PhaseSource? source,
    double? confidence,
    DateTime? inferredAt,
    List<String>? anchors,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PhaseRegime(
      id: id ?? this.id,
      label: label ?? this.label,
      start: start ?? this.start,
      end: end ?? this.end,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
      inferredAt: inferredAt ?? this.inferredAt,
      anchors: anchors ?? this.anchors,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

@HiveType(typeId: 201)
class PhaseInfo {
  @HiveField(0)
  final PhaseLabel label;
  
  @HiveField(1)
  final double? confidence; // null for user
  
  @HiveField(2)
  final PhaseSource source;
  
  @HiveField(3)
  final DateTime? inferredAt; // null for user

  const PhaseInfo({
    required this.label,
    this.confidence,
    required this.source,
    this.inferredAt,
  });

  factory PhaseInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PhaseInfo(
      label: PhaseLabel.discovery,
      source: PhaseSource.user,
    );
    
    return PhaseInfo(
      label: PhaseLabel.values.firstWhere(
        (e) => e.name == json['label'],
        orElse: () => PhaseLabel.discovery,
      ),
      confidence: json['confidence'] as double?,
      source: PhaseSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => PhaseSource.user,
      ),
      inferredAt: json['inferred_at'] != null ? DateTime.parse(json['inferred_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label.name,
      'confidence': confidence,
      'source': source.name,
      'inferred_at': inferredAt?.toIso8601String(),
    };
  }
}

@HiveType(typeId: 202)
class PhaseWindow {
  @HiveField(0)
  final DateTime start;
  
  @HiveField(1)
  final DateTime? end; // null if ongoing

  const PhaseWindow({
    required this.start,
    this.end,
  });

  bool get isOngoing => end == null;
  
  Duration get duration => (end ?? DateTime.now()).difference(start);

  factory PhaseWindow.fromJson(Map<String, dynamic>? json) {
    if (json == null) return PhaseWindow(start: DateTime(1970));
    
    return PhaseWindow(
      start: DateTime.parse(json['start']),
      end: json['end'] != null ? DateTime.parse(json['end']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start': start.toIso8601String(),
      'end': end?.toIso8601String(),
    };
  }
}

// Phase change detection result
class PhaseChangePoint {
  final DateTime timestamp;
  final double score;
  final Map<String, double> signals; // topic_shift, emotion_delta, tempo, etc.

  const PhaseChangePoint({
    required this.timestamp,
    required this.score,
    required this.signals,
  });
}

// RIVET Sweep segment proposal
class PhaseSegmentProposal {
  final DateTime start;
  final DateTime end;
  final PhaseLabel proposedLabel;
  final double confidence;
  final Map<String, double> signals;
  final List<String> entryIds;
  final String? summary;
  final List<String> topKeywords;

  const PhaseSegmentProposal({
    required this.start,
    required this.end,
    required this.proposedLabel,
    required this.confidence,
    required this.signals,
    required this.entryIds,
    this.summary,
    this.topKeywords = const [],
  });
}

// Phase timeline statistics
class PhaseTimelineStats {
  final int totalRegimes;
  final int userRegimes;
  final int rivetRegimes;
  final Duration totalDuration;
  final Map<PhaseLabel, Duration> phaseDurations;
  final List<PhaseRegime> recentRegimes;

  const PhaseTimelineStats({
    required this.totalRegimes,
    required this.userRegimes,
    required this.rivetRegimes,
    required this.totalDuration,
    required this.phaseDurations,
    required this.recentRegimes,
  });
}
