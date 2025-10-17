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
  @HiveField(4)
  draft,          // Draft journal entries
  @HiveField(5)
  lumaraChat,     // LUMARA-user conversations
}

/// Single RIVET event capturing user interaction and phase prediction/confirmation
@HiveType(typeId: 11)
class RivetEvent extends Equatable {
  @HiveField(0)
  final DateTime date;
  
  @HiveField(1)
  final EvidenceSource source;
  
  @HiveField(2)
  final Set<String> keywords; // selected by user
  
  @HiveField(3)
  final String predPhase; // from PhaseRecommender
  
  @HiveField(4)
  final String refPhase; // from user-confirmation dialog
  
  @HiveField(5)
  final Map<String, double> tolerance; // per-phase tolerance (stub for now)

  const RivetEvent({
    required this.date,
    required this.source,
    required this.keywords,
    required this.predPhase,
    required this.refPhase,
    required this.tolerance,
  });

  @override
  List<Object?> get props => [date, source, keywords, predPhase, refPhase, tolerance];

  RivetEvent copyWith({
    DateTime? date,
    EvidenceSource? source,
    Set<String>? keywords,
    String? predPhase,
    String? refPhase,
    Map<String, double>? tolerance,
  }) {
    return RivetEvent(
      date: date ?? this.date,
      source: source ?? this.source,
      keywords: keywords ?? this.keywords,
      predPhase: predPhase ?? this.predPhase,
      refPhase: refPhase ?? this.refPhase,
      tolerance: tolerance ?? this.tolerance,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'source': source.toString(),
      'keywords': keywords.toList(),
      'predPhase': predPhase,
      'refPhase': refPhase,
      'tolerance': tolerance,
    };
  }

  factory RivetEvent.fromJson(Map<String, dynamic> json) {
    return RivetEvent(
      date: DateTime.parse(json['date'] as String),
      source: EvidenceSource.values.firstWhere(
        (e) => e.toString() == json['source'],
        orElse: () => EvidenceSource.other,
      ),
          keywords: (json['keywords'] as List<dynamic>).cast<String>().toSet(),
      predPhase: json['predPhase'] as String,
      refPhase: json['refPhase'] as String,
      tolerance: Map<String, double>.from(json['tolerance'] as Map),
    );
  }

  /// Create RIVET event from journal entry
  factory RivetEvent.fromJournalEntry({
    required DateTime date,
    required Set<String> keywords,
    required String predPhase,
    required String refPhase,
    Map<String, double> tolerance = const {},
  }) {
    return RivetEvent(
      date: date,
      source: EvidenceSource.text,
      keywords: keywords,
      predPhase: predPhase,
      refPhase: refPhase,
      tolerance: tolerance,
    );
  }

  /// Create RIVET event from draft entry
  factory RivetEvent.fromDraftEntry({
    required DateTime date,
    required Set<String> keywords,
    required String predPhase,
    required String refPhase,
    Map<String, double> tolerance = const {},
  }) {
    return RivetEvent(
      date: date,
      source: EvidenceSource.draft,
      keywords: keywords,
      predPhase: predPhase,
      refPhase: refPhase,
      tolerance: tolerance,
    );
  }

  /// Create RIVET event from LUMARA chat
  factory RivetEvent.fromLumaraChat({
    required DateTime date,
    required Set<String> keywords,
    required String predPhase,
    required String refPhase,
    Map<String, double> tolerance = const {},
  }) {
    return RivetEvent(
      date: date,
      source: EvidenceSource.lumaraChat,
      keywords: keywords,
      predPhase: predPhase,
      refPhase: refPhase,
      tolerance: tolerance,
    );
  }

  /// Get source weight for analysis
  double get sourceWeight {
    switch (source) {
      case EvidenceSource.text:
      case EvidenceSource.voice:
      case EvidenceSource.therapistTag:
        return 1.0; // Full weight for journal entries
      case EvidenceSource.draft:
        return 0.6; // Reduced weight for drafts
      case EvidenceSource.lumaraChat:
        return 0.8; // Medium weight for chat
      case EvidenceSource.other:
        return 0.5; // Lowest weight for other sources
    }
  }

  /// Check if this is a high-confidence event
  bool get isHighConfidence => sourceWeight >= 0.8;

  /// Check if this is a draft event
  bool get isDraft => source == EvidenceSource.draft;

  /// Check if this is a chat event
  bool get isChat => source == EvidenceSource.lumaraChat;

  /// Check if this is a journal event
  bool get isJournal => source == EvidenceSource.text || source == EvidenceSource.voice;
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

  const RivetState({
    required this.align,
    required this.trace,
    required this.sustainCount,
    required this.sawIndependentInWindow,
  });

  @override
  List<Object?> get props => [align, trace, sustainCount, sawIndependentInWindow];

  RivetState copyWith({
    double? align,
    double? trace,
    int? sustainCount,
    bool? sawIndependentInWindow,
  }) {
    return RivetState(
      align: align ?? this.align,
      trace: trace ?? this.trace,
      sustainCount: sustainCount ?? this.sustainCount,
      sawIndependentInWindow: sawIndependentInWindow ?? this.sawIndependentInWindow,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'align': align,
      'trace': trace,
      'sustainCount': sustainCount,
      'sawIndependentInWindow': sawIndependentInWindow,
    };
  }

  factory RivetState.fromJson(Map<String, dynamic> json) {
    return RivetState(
      align: (json['align'] as num).toDouble(),
      trace: (json['trace'] as num).toDouble(),
      sustainCount: json['sustainCount'] as int,
      sawIndependentInWindow: json['sawIndependentInWindow'] as bool,
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