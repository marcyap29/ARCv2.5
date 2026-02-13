import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'rivet_models.g.dart';

/// Evidence source types for RIVET tracking
@HiveType(typeId: 20)
enum EvidenceSource {
  @HiveField(0)
  text,
  @HiveField(1)
  voice,
  @HiveField(2)
  therapistTag,
  @HiveField(3)
  other,
  // Extended sources for reflective entry system
  @HiveField(4)
  draft,
  @HiveField(5)
  lumaraChat,
  @HiveField(6)
  journal,
  @HiveField(7)
  chat,
  @HiveField(8)
  media,
  @HiveField(9)
  arcform,
  @HiveField(10)
  phase,
  @HiveField(11)
  system,
}

/// Single RIVET event capturing user interaction and phase prediction/confirmation
@HiveType(typeId: 21)
class RivetEvent extends Equatable {
  @HiveField(0)
  final String eventId;
  
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

  const RivetEvent({
    required this.eventId,
    required this.date,
    required this.source,
    required this.keywords,
    required this.predPhase,
    required this.refPhase,
    required this.tolerance,
  });

  @override
  List<Object?> get props => [eventId, date, source, keywords, predPhase, refPhase, tolerance];

  RivetEvent copyWith({
    String? eventId,
    DateTime? date,
    EvidenceSource? source,
    Set<String>? keywords,
    String? predPhase,
    String? refPhase,
    Map<String, double>? tolerance,
  }) {
    return RivetEvent(
      eventId: eventId ?? this.eventId,
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
      'eventId': eventId,
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
    );
  }

  /// Create RivetEvent from LUMARA chat message
  factory RivetEvent.fromLumaraChat({
    required DateTime date,
    required Set<String> keywords,
    required String predPhase,
    String? refPhase,
    Map<String, double> tolerance = const {},
  }) {
    return RivetEvent(
      eventId: 'rivet_${date.millisecondsSinceEpoch}',
      date: date,
      source: EvidenceSource.lumaraChat,
      keywords: keywords,
      predPhase: predPhase,
      refPhase: refPhase ?? predPhase,
      tolerance: tolerance,
    );
  }

  /// Create RivetEvent from draft entry
  factory RivetEvent.fromDraftEntry({
    required DateTime date,
    required Set<String> keywords,
    required String predPhase,
    String? refPhase,
    Map<String, double> tolerance = const {},
  }) {
    return RivetEvent(
      eventId: 'rivet_draft_${date.millisecondsSinceEpoch}',
      date: date,
      source: EvidenceSource.draft,
      keywords: keywords,
      predPhase: predPhase,
      refPhase: refPhase ?? predPhase,
      tolerance: tolerance,
    );
  }

  /// Create RivetEvent from journal entry
  factory RivetEvent.fromJournalEntry({
    required DateTime date,
    required Set<String> keywords,
    required String predPhase,
    String? refPhase,
    Map<String, double> tolerance = const {},
  }) {
    return RivetEvent(
      eventId: 'rivet_journal_${date.millisecondsSinceEpoch}',
      date: date,
      source: EvidenceSource.journal,
      keywords: keywords,
      predPhase: predPhase,
      refPhase: refPhase ?? predPhase,
      tolerance: tolerance,
    );
  }
}

/// Configuration for RIVET reducer computation
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

/// Current RIVET state tracking ALIGN and TRACE values
@HiveType(typeId: 22)
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

  /// Computed gate open status based on config
  /// For use in reducer tests - not stored in Hive
  bool getGateOpen(RivetConfig config) {
    return (sustainCount >= config.W) && sawIndependentInWindow &&
           (align >= config.Athresh) && (trace >= config.Tthresh);
  }

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
  final PhaseTransitionInsights? transitionInsights; // phase-approaching metrics

  const RivetGateDecision({
    required this.open,
    required this.stateAfter,
    this.whyNot,
    this.transitionInsights,
  });

  @override
  List<Object?> get props => [open, whyNot, stateAfter, transitionInsights];

  RivetGateDecision copyWith({
    bool? open,
    String? whyNot,
    RivetState? stateAfter,
    PhaseTransitionInsights? transitionInsights,
  }) {
    return RivetGateDecision(
      open: open ?? this.open,
      whyNot: whyNot ?? this.whyNot,
      stateAfter: stateAfter ?? this.stateAfter,
      transitionInsights: transitionInsights ?? this.transitionInsights,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'open': open,
      'whyNot': whyNot,
      'stateAfter': stateAfter.toJson(),
      'transitionInsights': transitionInsights?.toJson(),
    };
  }

  factory RivetGateDecision.fromJson(Map<String, dynamic> json) {
    return RivetGateDecision(
      open: json['open'] as bool,
      whyNot: json['whyNot'] as String?,
      stateAfter: RivetState.fromJson(json['stateAfter'] as Map<String, dynamic>),
      transitionInsights: json['transitionInsights'] != null
          ? PhaseTransitionInsights.fromJson(json['transitionInsights'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Measurable insights about phase transitions and approaching phases
class PhaseTransitionInsights extends Equatable {
  /// Current phase
  final String currentPhase;
  
  /// Approaching/target phase
  final String? approachingPhase;
  
  /// Percentage shift toward the approaching phase (0-100)
  final double shiftPercentage;
  
  /// Measurable signs of intelligence growing (e.g., "Your reflection patterns have shifted 12% toward Expansion")
  final List<String> measurableSigns;
  
  /// Transition confidence (0-1)
  final double transitionConfidence;
  
  /// Direction of shift (toward/away from approaching phase)
  final TransitionDirection direction;
  
  /// Specific metrics contributing to the shift
  final Map<String, double> contributingMetrics;

  const PhaseTransitionInsights({
    required this.currentPhase,
    this.approachingPhase,
    this.shiftPercentage = 0.0,
    this.measurableSigns = const [],
    this.transitionConfidence = 0.0,
    this.direction = TransitionDirection.stable,
    this.contributingMetrics = const {},
  });

  @override
  List<Object?> get props => [
        currentPhase,
        approachingPhase,
        shiftPercentage,
        measurableSigns,
        transitionConfidence,
        direction,
        contributingMetrics,
      ];

  Map<String, dynamic> toJson() {
    return {
      'currentPhase': currentPhase,
      'approachingPhase': approachingPhase,
      'shiftPercentage': shiftPercentage,
      'measurableSigns': measurableSigns,
      'transitionConfidence': transitionConfidence,
      'direction': direction.name,
      'contributingMetrics': contributingMetrics,
    };
  }

  factory PhaseTransitionInsights.fromJson(Map<String, dynamic> json) {
    return PhaseTransitionInsights(
      currentPhase: json['currentPhase'] as String,
      approachingPhase: json['approachingPhase'] as String?,
      shiftPercentage: (json['shiftPercentage'] as num?)?.toDouble() ?? 0.0,
      measurableSigns: (json['measurableSigns'] as List<dynamic>?)?.cast<String>() ?? [],
      transitionConfidence: (json['transitionConfidence'] as num?)?.toDouble() ?? 0.0,
      direction: TransitionDirection.values.firstWhere(
        (d) => d.name == json['direction'],
        orElse: () => TransitionDirection.stable,
      ),
      contributingMetrics: Map<String, double>.from(
        (json['contributingMetrics'] as Map<dynamic, dynamic>?)?.map(
          (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
        ) ?? {},
      ),
    );
  }

  /// Generate a human-readable primary insight message
  String getPrimaryInsight() {
    if (approachingPhase == null || shiftPercentage == 0.0) {
      return 'You\'re currently in $currentPhase phase.';
    }
    
    final phaseName = approachingPhase!;
    final percentage = shiftPercentage.abs().toStringAsFixed(0);
    
    switch (direction) {
      case TransitionDirection.toward:
        return 'Your reflection patterns have shifted $percentage% toward $phaseName.';
      case TransitionDirection.away:
        return 'You\'re moving $percentage% away from $phaseName patterns.';
      case TransitionDirection.stable:
        return 'You\'re maintaining stability in $currentPhase phase.';
    }
  }
}

/// Direction of phase transition
enum TransitionDirection {
  toward,   // Moving toward approaching phase
  away,     // Moving away from approaching phase
  stable,   // No significant shift
}

// ---------------------------------------------------------------------------
// Crossroads: Decision trigger output (runs alongside transition detection)
// ---------------------------------------------------------------------------

/// Category of phrase that triggered decision detection
enum DecisionPhraseCategory {
  consideration,   // thinking about, considering, wondering if
  activeChoice,     // torn between, going back and forth, don't know whether
  seekingOpinion,   // what do you think, should I, do you think I should
  actionFraming,   // I've decided to, I'm going to, I think I'll
  futureWeighing,   // trying to figure out, weighing, not sure if I should
}

/// Signal emitted when RIVET detects a decision moment in message text
class DecisionTriggerSignal extends Equatable {
  final DecisionPhraseCategory phraseCategory;
  final String detectedPhrase;
  /// Phase name at time of detection (e.g. "transition", "recovery")
  final String currentPhase;
  final double phaseWeight;
  final double phraseWeight;
  final String rawMessageContext;

  const DecisionTriggerSignal({
    required this.phraseCategory,
    required this.detectedPhrase,
    required this.currentPhase,
    required this.phaseWeight,
    required this.phraseWeight,
    required this.rawMessageContext,
  });

  @override
  List<Object?> get props => [phraseCategory, detectedPhrase, currentPhase, phaseWeight, phraseWeight, rawMessageContext];
}

/// Type of output from RIVET analysis
enum RivetOutputType {
  phaseTransition,
  decisionTrigger,
}

/// Single output from RIVET (either a phase transition or a decision trigger)
class RivetOutput extends Equatable {
  final RivetOutputType type;
  final double confidenceScore;
  final RivetGateDecision? transition;
  final DecisionTriggerSignal? decisionSignal;
  final DateTime detectedAt;

  const RivetOutput({
    required this.type,
    required this.confidenceScore,
    this.transition,
    this.decisionSignal,
    required this.detectedAt,
  });

  @override
  List<Object?> get props => [type, confidenceScore, transition, decisionSignal, detectedAt];
}