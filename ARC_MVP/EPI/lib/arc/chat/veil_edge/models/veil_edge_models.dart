/// VEIL-EDGE — Phase-Reactive Restorative Layer
/// 
/// A fast, cloud-orchestrated variant of VEIL that maintains restorative rhythm
/// without on-device fine-tuning. Functions as a prompt-switching policy layer,
/// routing user context through ATLAS → RIVET → SENTINEL to select phase-pair playbooks.
library;


/// ATLAS state representing current phase and confidence
class AtlasState {
  final String phase; // Discovery | Transition | Recovery | Consolidation | Breakthrough
  final double confidence; // 0.0 to 1.0
  final String neighbor; // Neighboring phase for blending

  const AtlasState({
    required this.phase,
    required this.confidence,
    required this.neighbor,
  });

  factory AtlasState.fromJson(Map<String, dynamic> json) {
    return AtlasState(
      phase: json['phase'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      neighbor: json['neighbor'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phase': phase,
      'confidence': confidence,
      'neighbor': neighbor,
    };
  }
}

/// SENTINEL state for safety monitoring
class SentinelState {
  final String state; // ok | watch | alert
  final List<String> notes;

  const SentinelState({
    required this.state,
    this.notes = const [],
  });

  factory SentinelState.fromJson(Map<String, dynamic> json) {
    return SentinelState(
      state: json['state'] as String,
      notes: List<String>.from(json['notes'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state,
      'notes': notes,
    };
  }

  bool get isOk => state == 'ok';
  bool get isWatch => state == 'watch';
  bool get isAlert => state == 'alert';
}

/// RIVET state for alignment and stability tracking
class RivetState {
  final double align; // 0.0 to 1.0
  final double stability; // 0.0 to 1.0
  final int windowDays; // Rolling window size
  final DateTime lastSwitchTimestamp;

  const RivetState({
    required this.align,
    required this.stability,
    this.windowDays = 7,
    required this.lastSwitchTimestamp,
  });

  factory RivetState.fromJson(Map<String, dynamic> json) {
    return RivetState(
      align: (json['align'] as num).toDouble(),
      stability: (json['stability'] as num).toDouble(),
      windowDays: json['window_days'] as int? ?? 7,
      lastSwitchTimestamp: DateTime.parse(json['last_switch_ts'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'align': align,
      'stability': stability,
      'window_days': windowDays,
      'last_switch_ts': lastSwitchTimestamp.toIso8601String(),
    };
  }
}

/// User signals input
class UserSignals {
  final List<String> actions;
  final List<String> feelings;
  final List<String> words;
  final List<String> outcomes;

  const UserSignals({
    required this.actions,
    required this.feelings,
    required this.words,
    required this.outcomes,
  });

  factory UserSignals.fromJson(Map<String, dynamic> json) {
    return UserSignals(
      actions: List<String>.from(json['actions'] ?? []),
      feelings: List<String>.from(json['feelings'] ?? []),
      words: List<String>.from(json['words'] ?? []),
      outcomes: List<String>.from(json['outcomes'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'actions': actions,
      'feelings': feelings,
      'words': words,
      'outcomes': outcomes,
    };
  }
}

/// Signal extraction result containing processed user signals
class SignalExtraction {
  final UserSignals signals;
  final Map<String, dynamic> metadata;

  const SignalExtraction({
    required this.signals,
    this.metadata = const {},
  });

  factory SignalExtraction.fromJson(Map<String, dynamic> json) {
    return SignalExtraction(
      signals: UserSignals.fromJson(json['signals'] as Map<String, dynamic>),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'signals': signals.toJson(),
      'metadata': metadata,
    };
  }
}

/// VEIL-EDGE input containing all routing context
class VeilEdgeInput {
  final AtlasState atlas;
  final RivetState rivet;
  final SentinelState sentinel;
  final SignalExtraction signals;
  // AURORA circadian context
  final String circadianWindow;     // 'morning'|'afternoon'|'evening'
  final String circadianChronotype; // 'morning'|'balanced'|'evening'
  final double rhythmScore;         // 0..1

  const VeilEdgeInput({
    required this.atlas,
    required this.rivet,
    required this.sentinel,
    required this.signals,
    required this.circadianWindow,
    required this.circadianChronotype,
    required this.rhythmScore,
  });

  factory VeilEdgeInput.fromJson(Map<String, dynamic> json) {
    return VeilEdgeInput(
      atlas: AtlasState.fromJson(json['atlas'] as Map<String, dynamic>),
      rivet: RivetState.fromJson(json['rivet'] as Map<String, dynamic>),
      sentinel: SentinelState.fromJson(json['sentinel'] as Map<String, dynamic>),
      signals: SignalExtraction.fromJson(json['signals'] as Map<String, dynamic>),
      circadianWindow: json['circadian_window'] as String,
      circadianChronotype: json['circadian_chronotype'] as String,
      rhythmScore: (json['rhythm_score'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'atlas': atlas.toJson(),
      'rivet': rivet.toJson(),
      'sentinel': sentinel.toJson(),
      'signals': signals.toJson(),
      'circadian_window': circadianWindow,
      'circadian_chronotype': circadianChronotype,
      'rhythm_score': rhythmScore,
    };
  }

  /// Check if this is an evening context
  bool get isEvening => circadianWindow == 'evening';
  
  /// Check if this is a morning context
  bool get isMorning => circadianWindow == 'morning';
  
  /// Check if this is an afternoon context
  bool get isAfternoon => circadianWindow == 'afternoon';

  /// Check if rhythm is fragmented
  bool get isRhythmFragmented => rhythmScore < 0.45;
  
  /// Check if rhythm is coherent
  bool get isRhythmCoherent => rhythmScore >= 0.55;

  /// Check if user is a morning person
  bool get isMorningPerson => circadianChronotype == 'morning';
  
  /// Check if user is an evening person
  bool get isEveningPerson => circadianChronotype == 'evening';
}

/// Phase group mapping
enum PhaseGroup {
  dB, // Discovery ↔ Breakthrough
  tD, // Transition ↔ Discovery
  rT, // Recovery ↔ Transition
  cR, // Consolidation ↔ Recovery
}

extension PhaseGroupExtension on PhaseGroup {
  String get name {
    switch (this) {
      case PhaseGroup.dB: return 'D-B';
      case PhaseGroup.tD: return 'T-D';
      case PhaseGroup.rT: return 'R-T';
      case PhaseGroup.cR: return 'C-R';
    }
  }
}

/// Routing result from VEIL-EDGE
class VeilEdgeRouteResult {
  final String phaseGroup;
  final String variant;
  final List<String> blocks;
  final Map<String, dynamic> metadata;

  const VeilEdgeRouteResult({
    required this.phaseGroup,
    required this.variant,
    required this.blocks,
    this.metadata = const {},
  });

  factory VeilEdgeRouteResult.fromJson(Map<String, dynamic> json) {
    return VeilEdgeRouteResult(
      phaseGroup: json['phase_group'] as String,
      variant: json['variant'] as String,
      blocks: List<String>.from(json['blocks'] ?? []),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phase_group': phaseGroup,
      'variant': variant,
      'blocks': blocks,
      'metadata': metadata,
    };
  }
}

/// VEIL-EDGE output containing routing result and metadata
class VeilEdgeOutput {
  final VeilEdgeRouteResult routeResult;
  final Map<String, dynamic> metadata;
  final String userText;

  const VeilEdgeOutput({
    required this.routeResult,
    required this.userText,
    this.metadata = const {},
  });

  factory VeilEdgeOutput.fromJson(Map<String, dynamic> json) {
    return VeilEdgeOutput(
      routeResult: VeilEdgeRouteResult.fromJson(json['route_result'] as Map<String, dynamic>),
      userText: json['user_text'] as String,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'route_result': routeResult.toJson(),
      'user_text': userText,
      'metadata': metadata,
    };
  }

  /// Get the phase group
  String get phaseGroup => routeResult.phaseGroup;
  
  /// Get the variant
  String get variant => routeResult.variant;
  
  /// Get the blocks
  List<String> get blocks => routeResult.blocks;
}

/// Log schema for RIVET updates
class LogSchema {
  final DateTime timestamp;
  final String phaseGroup;
  final List<String> blocksUsed;
  final String action;
  final Map<String, dynamic> outcomeMetric;
  final int ease; // 1-5 scale
  final int mood; // 1-5 scale
  final int energy; // 1-5 scale
  final String note;
  final String sentinelState;

  const LogSchema({
    required this.timestamp,
    required this.phaseGroup,
    required this.blocksUsed,
    required this.action,
    required this.outcomeMetric,
    required this.ease,
    required this.mood,
    required this.energy,
    required this.note,
    required this.sentinelState,
  });

  factory LogSchema.fromJson(Map<String, dynamic> json) {
    return LogSchema(
      timestamp: DateTime.parse(json['timestamp'] as String),
      phaseGroup: json['phase_group'] as String,
      blocksUsed: List<String>.from(json['blocks_used'] ?? []),
      action: json['action'] as String,
      outcomeMetric: Map<String, dynamic>.from(json['outcome_metric'] ?? {}),
      ease: json['ease'] as int,
      mood: json['mood'] as int,
      energy: json['energy'] as int,
      note: json['note'] as String,
      sentinelState: json['sentinel_state'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'phase_group': phaseGroup,
      'blocks_used': blocksUsed,
      'action': action,
      'outcome_metric': outcomeMetric,
      'ease': ease,
      'mood': mood,
      'energy': energy,
      'note': note,
      'sentinel_state': sentinelState,
    };
  }
}

/// RIVET update response
class RivetUpdate {
  final bool acknowledged;
  final Map<String, dynamic> rivetUpdates;

  const RivetUpdate({
    required this.acknowledged,
    required this.rivetUpdates,
  });

  factory RivetUpdate.fromJson(Map<String, dynamic> json) {
    return RivetUpdate(
      acknowledged: json['ack'] as bool,
      rivetUpdates: Map<String, dynamic>.from(json['rivet_updates'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ack': acknowledged,
      'rivet_updates': rivetUpdates,
    };
  }
}

/// Prompt block definition
class PromptBlock {
  final String name;
  final String template;
  final List<String> requiredVariables;

  const PromptBlock({
    required this.name,
    required this.template,
    this.requiredVariables = const [],
  });

  factory PromptBlock.fromJson(Map<String, dynamic> json) {
    return PromptBlock(
      name: json['name'] as String,
      template: json['template'] as String,
      requiredVariables: List<String>.from(json['required_variables'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'template': template,
      'required_variables': requiredVariables,
    };
  }

  /// Render the block with provided variables
  String render(Map<String, String> variables) {
    String result = template;
    for (final variable in requiredVariables) {
      final value = variables[variable] ?? '{$variable}';
      result = result.replaceAll('{$variable}', value);
    }
    return result;
  }
}

/// Phase family definition
class PhaseFamily {
  final String system;
  final String style;
  final Map<String, PromptBlock> blocks;

  const PhaseFamily({
    required this.system,
    required this.style,
    required this.blocks,
  });

  factory PhaseFamily.fromJson(Map<String, dynamic> json) {
    final blocksJson = json['blocks'] as Map<String, dynamic>;
    final blocks = blocksJson.map(
      (key, value) => MapEntry(key, PromptBlock.fromJson(value as Map<String, dynamic>)),
    );

    return PhaseFamily(
      system: json['system'] as String,
      style: json['style'] as String,
      blocks: blocks,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'system': system,
      'style': style,
      'blocks': blocks.map((key, value) => MapEntry(key, value.toJson())),
    };
  }
}

/// Prompt registry containing all phase families
class PromptRegistry {
  final String version;
  final Map<String, PhaseFamily> families;

  const PromptRegistry({
    required this.version,
    required this.families,
  });

  factory PromptRegistry.fromJson(Map<String, dynamic> json) {
    final familiesJson = json['families'] as Map<String, dynamic>;
    final families = familiesJson.map(
      (key, value) => MapEntry(key, PhaseFamily.fromJson(value as Map<String, dynamic>)),
    );

    return PromptRegistry(
      version: json['version'] as String,
      families: families,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'families': families.map((key, value) => MapEntry(key, value.toJson())),
    };
  }

  /// Get a specific phase family
  PhaseFamily? getFamily(String phaseGroup) {
    return families[phaseGroup];
  }

  /// Get all available phase groups
  List<String> get availablePhaseGroups => families.keys.toList();
}
