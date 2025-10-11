import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'rivet_models.g.dart';

/// Evidence source types for RIVET tracking
@HiveType(typeId: 10)
enum EvidenceSource {
  @HiveField(0)
  text,
  @HiveField(1)
  voice,
  @HiveField(2)
  therapistTag,
  @HiveField(3)
  other,
}

/// Single RIVET event capturing user interaction and phase prediction/confirmation
@HiveType(typeId: 11)
class RivetEvent extends Equatable {
  @HiveField(0)
  final String eventId; // unique identifier for delete/edit operations
  
  @HiveField(1)
  final DateTime date;
  
  @HiveField(2)
  final EvidenceSource source;
  
  @HiveField(3)
  final Set<String> keywords; // selected by user
  
  @HiveField(4)
  final String predPhase; // from PhaseRecommender
  
  @HiveField(5)
  final String refPhase; // from user-confirmation dialog
  
  @HiveField(6)
  final Map<String, double> tolerance; // per-phase tolerance (stub for now)
  
  @HiveField(7)
  final int version; // for edit operations

  const RivetEvent({
    required this.eventId,
    required this.date,
    required this.source,
    required this.keywords,
    required this.predPhase,
    required this.refPhase,
    required this.tolerance,
    this.version = 1,
  });

  @override
  List<Object?> get props => [eventId, date, source, keywords, predPhase, refPhase, tolerance, version];

  RivetEvent copyWith({
    String? eventId,
    DateTime? date,
    EvidenceSource? source,
    Set<String>? keywords,
    String? predPhase,
    String? refPhase,
    Map<String, double>? tolerance,
    int? version,
  }) {
    return RivetEvent(
      eventId: eventId ?? this.eventId,
      date: date ?? this.date,
      source: source ?? this.source,
      keywords: keywords ?? this.keywords,
      predPhase: predPhase ?? this.predPhase,
      refPhase: refPhase ?? this.refPhase,
      tolerance: tolerance ?? this.tolerance,
      version: version ?? this.version,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'eventId': eventId,
      'date': date.toIso8601String(),
      'source': source.toString(),
      'keywords': keywords.toList(),
      'predPhase': predPhase,
      'refPhase': refPhase,
      'tolerance': tolerance,
      'version': version,
    };
  }

  factory RivetEvent.fromJson(Map<String, dynamic> json) {
    return RivetEvent(
      eventId: json['eventId'] as String? ?? '',
      date: DateTime.parse(json['date'] as String),
      source: EvidenceSource.values.firstWhere(
        (e) => e.toString() == json['source'],
        orElse: () => EvidenceSource.other,
      ),
      keywords: (json['keywords'] as List<dynamic>).cast<String>().toSet(),
      predPhase: json['predPhase'] as String,
      refPhase: json['refPhase'] as String,
      tolerance: Map<String, double>.from(json['tolerance'] as Map),
      version: json['version'] as int? ?? 1,
    );
  }
}

/// Current RIVET state tracking ALIGN and TRACE values
@HiveType(typeId: 12)
class RivetState extends Equatable {
  @HiveField(0)
  final double align; // [0,1] - fidelity between prediction and reference
  
  @HiveField(1)
  final double trace; // [0,1] - evidence sufficiency, monotone increasing
  
  @HiveField(2)
  final int sustainCount; // consecutive events meeting thresholds
  
  @HiveField(3)
  final bool sawIndependentInWindow; // independence flag for current window
  
  @HiveField(4)
  final String? eventId; // associated event ID for tracking
  
  @HiveField(5)
  final DateTime? date; // timestamp of this state

  const RivetState({
    required this.align,
    required this.trace,
    required this.sustainCount,
    required this.sawIndependentInWindow,
    this.eventId,
    this.date,
  });

  @override
  List<Object?> get props => [align, trace, sustainCount, sawIndependentInWindow, eventId, date];

  RivetState copyWith({
    double? align,
    double? trace,
    int? sustainCount,
    bool? sawIndependentInWindow,
    String? eventId,
    DateTime? date,
  }) {
    return RivetState(
      align: align ?? this.align,
      trace: trace ?? this.trace,
      sustainCount: sustainCount ?? this.sustainCount,
      sawIndependentInWindow: sawIndependentInWindow ?? this.sawIndependentInWindow,
      eventId: eventId ?? this.eventId,
      date: date ?? this.date,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'align': align,
      'trace': trace,
      'sustainCount': sustainCount,
      'sawIndependentInWindow': sawIndependentInWindow,
      'eventId': eventId,
      'date': date?.toIso8601String(),
    };
  }

  factory RivetState.fromJson(Map<String, dynamic> json) {
    return RivetState(
      align: (json['align'] as num).toDouble(),
      trace: (json['trace'] as num).toDouble(),
      sustainCount: json['sustainCount'] as int,
      sawIndependentInWindow: json['sawIndependentInWindow'] as bool,
      eventId: json['eventId'] as String?,
      date: json['date'] != null ? DateTime.parse(json['date'] as String) : null,
    );
  }
}

/// RIVET configuration parameters
class RivetConfig {
  final double Athresh; // ALIGN threshold (A*)
  final double Tthresh; // TRACE threshold (T*)
  final int W; // sustainment window size
  final int N; // smoothing parameter for ALIGN
  final double K; // saturation parameter for TRACE

  const RivetConfig({
    this.Athresh = 0.6,
    this.Tthresh = 0.6,
    this.W = 2,
    this.N = 10,
    this.K = 20,
  });
}

/// Checkpoint snapshot for efficient recompute
@HiveType(typeId: 13)
class RivetSnapshot extends Equatable {
  @HiveField(0)
  final String eventId; // last event in this snapshot
  
  @HiveField(1)
  final DateTime date; // timestamp of snapshot
  
  @HiveField(2)
  final double align; // cumulative ALIGN value
  
  @HiveField(3)
  final double trace; // cumulative TRACE value
  
  @HiveField(4)
  final double sumEvidenceSoFar; // cumulative evidence mass for TRACE
  
  @HiveField(5)
  final int eventCount; // number of events in this snapshot

  const RivetSnapshot({
    required this.eventId,
    required this.date,
    required this.align,
    required this.trace,
    required this.sumEvidenceSoFar,
    required this.eventCount,
  });

  @override
  List<Object?> get props => [eventId, date, align, trace, sumEvidenceSoFar, eventCount];

  Map<String, dynamic> toJson() {
    return {
      'eventId': eventId,
      'date': date.toIso8601String(),
      'align': align,
      'trace': trace,
      'sumEvidenceSoFar': sumEvidenceSoFar,
      'eventCount': eventCount,
    };
  }

  factory RivetSnapshot.fromJson(Map<String, dynamic> json) {
    return RivetSnapshot(
      eventId: json['eventId'] as String,
      date: DateTime.parse(json['date'] as String),
      align: (json['align'] as num).toDouble(),
      trace: (json['trace'] as num).toDouble(),
      sumEvidenceSoFar: (json['sumEvidenceSoFar'] as num).toDouble(),
      eventCount: json['eventCount'] as int,
    );
  }
}

/// Gate decision result with transparency
class RivetGateDecision extends Equatable {
  final bool open; // gate opens = allow phase change
  final String? whyNot; // transparency string if gate stays closed
  final RivetState stateAfter; // updated indices

  const RivetGateDecision({
    required this.open,
    required this.stateAfter,
    this.whyNot,
  });

  @override
  List<Object?> get props => [open, whyNot, stateAfter];

  Map<String, dynamic> toJson() {
    return {
      'open': open,
      'whyNot': whyNot,
      'stateAfter': stateAfter.toJson(),
    };
  }

  factory RivetGateDecision.fromJson(Map<String, dynamic> json) {
    return RivetGateDecision(
      open: json['open'] as bool,
      whyNot: json['whyNot'] as String?,
      stateAfter: RivetState.fromJson(json['stateAfter'] as Map<String, dynamic>),
    );
  }
}