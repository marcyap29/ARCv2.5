/// Engagement Discipline System for LUMARA
///
/// Integrates with LUMARA's MASTERPROMPT control state system to provide
/// user-controlled engagement boundaries while preserving temporal intelligence.
library;

enum EngagementMode {
  reflect,    // Default: direct, concise, minimal connections
  deeper,     // Connect things: patterns, links, synthesis across entries and time
  // ignore: constant_identifier_names
  explore,    // Legacy alias for deeper — kept for backward source compatibility
  // ignore: constant_identifier_names
  integrate,  // Legacy alias for deeper — kept for backward source compatibility
}

extension EngagementModeExtension on EngagementMode {
  String get displayName {
    switch (this) {
      case EngagementMode.reflect:
        return 'Default';
      case EngagementMode.deeper:
      case EngagementMode.explore:
      case EngagementMode.integrate:
        return 'Deeper';
    }
  }

  String get description {
    switch (this) {
      case EngagementMode.reflect:
        return 'Direct, concise answers. Up to one link to your history; switch to Deeper for more connections.';
      case EngagementMode.deeper:
      case EngagementMode.explore:
      case EngagementMode.integrate:
        return 'Surface patterns, link to other entries and CHRONICLE, and synthesize across domains and time. Best when you want connections.';
    }
  }

  /// Convert to string for JSON serialization
  String toJson() => toString();

  /// Create from string for JSON deserialization. Maps legacy explore/integrate to deeper.
  static EngagementMode fromJson(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.contains('explore') || normalized.contains('integrate')) {
      return EngagementMode.deeper;
    }
    return EngagementMode.values.firstWhere(
      (mode) => mode.toString() == value,
      orElse: () => EngagementMode.reflect,
    );
  }
}

/// Domain synthesis preferences for INTEGRATE mode
/// Simplified: Single toggle for cross-domain connections
class SynthesisPreferences {
  final bool allowCrossDomainSynthesis; // Single toggle replacing 4 separate toggles
  final List<String> protectedDomains;
  final SynthesisDepth synthesisDepth;

  const SynthesisPreferences({
    this.allowCrossDomainSynthesis = true, // Default: allow cross-domain connections
    this.protectedDomains = const [],
    this.synthesisDepth = SynthesisDepth.moderate,
  });
  
  /// Legacy getters for backward compatibility
  @Deprecated('Use allowCrossDomainSynthesis instead')
  bool get allowFaithWorkSynthesis => allowCrossDomainSynthesis;
  
  @Deprecated('Use allowCrossDomainSynthesis instead')
  bool get allowRelationshipWorkSynthesis => allowCrossDomainSynthesis;
  
  @Deprecated('Use allowCrossDomainSynthesis instead')
  bool get allowHealthEmotionalSynthesis => allowCrossDomainSynthesis;
  
  @Deprecated('Use allowCrossDomainSynthesis instead')
  bool get allowCreativeIntellectualSynthesis => allowCrossDomainSynthesis;

  Map<String, dynamic> toJson() => {
    'allowCrossDomainSynthesis': allowCrossDomainSynthesis,
    'protectedDomains': protectedDomains,
    'synthesisDepth': synthesisDepth.toString(),
    // Legacy fields for backward compatibility
    'allowFaithWorkSynthesis': allowCrossDomainSynthesis,
    'allowRelationshipWorkSynthesis': allowCrossDomainSynthesis,
    'allowHealthEmotionalSynthesis': allowCrossDomainSynthesis,
    'allowCreativeIntellectualSynthesis': allowCrossDomainSynthesis,
  };

  factory SynthesisPreferences.fromJson(Map<String, dynamic> json) {
    // Migration: If old format exists, convert to new format
    final hasOldFormat = json['allowFaithWorkSynthesis'] != null ||
        json['allowRelationshipWorkSynthesis'] != null;
    
    bool allowCrossDomain = json['allowCrossDomainSynthesis'] ?? true;
    
    if (hasOldFormat) {
      // If any of the old toggles were enabled, enable cross-domain
      allowCrossDomain = (json['allowFaithWorkSynthesis'] ?? false) ||
          (json['allowRelationshipWorkSynthesis'] ?? true) ||
          (json['allowHealthEmotionalSynthesis'] ?? true) ||
          (json['allowCreativeIntellectualSynthesis'] ?? true);
    }
    
    return SynthesisPreferences(
      allowCrossDomainSynthesis: allowCrossDomain,
      protectedDomains: List<String>.from(json['protectedDomains'] ?? []),
      synthesisDepth: SynthesisDepth.values.firstWhere(
        (e) => e.toString() == json['synthesisDepth'],
        orElse: () => SynthesisDepth.moderate,
      ),
    );
  }

  SynthesisPreferences copyWith({
    bool? allowCrossDomainSynthesis,
    List<String>? protectedDomains,
    SynthesisDepth? synthesisDepth,
  }) {
    return SynthesisPreferences(
      allowCrossDomainSynthesis: allowCrossDomainSynthesis ?? this.allowCrossDomainSynthesis,
      protectedDomains: protectedDomains ?? this.protectedDomains,
      synthesisDepth: synthesisDepth ?? this.synthesisDepth,
    );
  }
}

enum SynthesisDepth {
  surface,   // Connect 1-2 domains, simple connections
  moderate,  // Connect 2-3 domains, moderate complexity
  deep       // Connect 3+ domains, complex relationships
}

/// Response discipline preferences
/// Auto-determines maxTemporalConnections and maxExplorativeQuestions from EngagementMode
class ResponseDiscipline {
  final int? maxTemporalConnections; // Auto-determined from mode if null
  final int? maxExplorativeQuestions; // Auto-determined from mode if null
  final bool allowTherapeuticLanguage; // Combined therapeutic + prescriptive guidance
  final ResponseLength preferredLength;

  const ResponseDiscipline({
    this.maxTemporalConnections, // null = auto-determine from mode
    this.maxExplorativeQuestions, // null = auto-determine from mode
    this.allowTherapeuticLanguage = false, // Combined setting
    this.preferredLength = ResponseLength.moderate,
  });
  
  /// Get effective maxTemporalConnections based on mode
  int getEffectiveMaxTemporalConnections(EngagementMode mode) {
    return maxTemporalConnections ?? _getModeValue(mode, reflect: 1, deeper: 3);
  }

  /// Get effective maxExplorativeQuestions based on mode
  int getEffectiveMaxExplorativeQuestions(EngagementMode mode) {
    return maxExplorativeQuestions ?? _getModeValue(mode, reflect: 0, deeper: 2);
  }

  int _getModeValue(EngagementMode mode, {required int reflect, required int deeper}) {
    switch (mode) {
      case EngagementMode.reflect:
        return reflect;
      case EngagementMode.deeper:
      case EngagementMode.explore:
      case EngagementMode.integrate:
        return deeper;
    }
  }

  Map<String, dynamic> toJson() => {
    'maxTemporalConnections': maxTemporalConnections,
    'maxExplorativeQuestions': maxExplorativeQuestions,
    'allowTherapeuticLanguage': allowTherapeuticLanguage,
    'preferredLength': preferredLength.toString(),
    // Legacy field for backward compatibility
    'allowPrescriptiveGuidance': allowTherapeuticLanguage,
  };

  factory ResponseDiscipline.fromJson(Map<String, dynamic> json) {
    // Migration: Combine therapeutic language and prescriptive guidance
    final allowTherapeutic = json['allowTherapeuticLanguage'] ?? false;
    final allowPrescriptive = json['allowPrescriptiveGuidance'] ?? false;
    final combinedTherapeutic = allowTherapeutic || allowPrescriptive;
    
    return ResponseDiscipline(
      maxTemporalConnections: json['maxTemporalConnections'], // null = auto-determine
      maxExplorativeQuestions: json['maxExplorativeQuestions'], // null = auto-determine
      allowTherapeuticLanguage: combinedTherapeutic,
      preferredLength: ResponseLength.values.firstWhere(
        (e) => e.toString() == json['preferredLength'],
        orElse: () => ResponseLength.moderate,
      ),
    );
  }

  ResponseDiscipline copyWith({
    int? maxTemporalConnections,
    int? maxExplorativeQuestions,
    bool? allowTherapeuticLanguage,
    ResponseLength? preferredLength,
  }) {
    return ResponseDiscipline(
      maxTemporalConnections: maxTemporalConnections ?? this.maxTemporalConnections,
      maxExplorativeQuestions: maxExplorativeQuestions ?? this.maxExplorativeQuestions,
      allowTherapeuticLanguage: allowTherapeuticLanguage ?? this.allowTherapeuticLanguage,
      preferredLength: preferredLength ?? this.preferredLength,
    );
  }
  
  /// Legacy getter for backward compatibility
  @Deprecated('Use allowTherapeuticLanguage instead')
  bool get allowPrescriptiveGuidance => allowTherapeuticLanguage;
}

enum ResponseLength {
  concise,    // 1-2 paragraphs
  moderate,   // 2-4 paragraphs
  detailed    // 4+ paragraphs
}

/// Main engagement settings that integrate with LUMARA Control State
class EngagementSettings {
  final EngagementMode defaultMode;
  final EngagementMode? conversationOverride; // Override for current conversation
  final SynthesisPreferences synthesisPreferences;
  final ResponseDiscipline responseDiscipline;
  final bool adaptToVeilState; // Whether to let VEIL override engagement mode
  final bool adaptToAtlasPhase; // Whether to let ATLAS phase influence engagement

  const EngagementSettings({
    this.defaultMode = EngagementMode.reflect,
    this.conversationOverride,
    this.synthesisPreferences = const SynthesisPreferences(),
    this.responseDiscipline = const ResponseDiscipline(),
    this.adaptToVeilState = true,
    this.adaptToAtlasPhase = true,
  });

  /// Get the active engagement mode considering overrides
  EngagementMode get activeMode => conversationOverride ?? defaultMode;

  /// Derived: Max questions per response based on mode
  int get maxQuestionsPerResponse => activeMode == EngagementMode.reflect ? 0 : 1;

  /// Derived: Allow cross-domain synthesis based on mode
  bool get allowCrossDomainSynthesis => activeMode == EngagementMode.deeper;

  Map<String, dynamic> toJson() => {
    'defaultMode': defaultMode.toString(),
    'conversationOverride': conversationOverride?.toString(),
    'synthesisPreferences': synthesisPreferences.toJson(),
    'responseDiscipline': responseDiscipline.toJson(),
    'adaptToVeilState': adaptToVeilState,
    'adaptToAtlasPhase': adaptToAtlasPhase,
  };

  factory EngagementSettings.fromJson(Map<String, dynamic> json) {
    final modeRaw = json['defaultMode'] as String?;
    final defaultMode = modeRaw != null
        ? EngagementModeExtension.fromJson(modeRaw)
        : EngagementMode.reflect;
    final overrideRaw = json['conversationOverride'] as String?;
    final conversationOverride = overrideRaw != null
        ? EngagementModeExtension.fromJson(overrideRaw)
        : null;
    return EngagementSettings(
      defaultMode: defaultMode,
      conversationOverride: conversationOverride,
      synthesisPreferences: SynthesisPreferences.fromJson(
        json['synthesisPreferences'] ?? {},
      ),
      responseDiscipline: ResponseDiscipline.fromJson(
        json['responseDiscipline'] ?? {},
      ),
      adaptToVeilState: json['adaptToVeilState'] ?? true,
      adaptToAtlasPhase: json['adaptToAtlasPhase'] ?? true,
    );
  }

  EngagementSettings copyWith({
    EngagementMode? defaultMode,
    EngagementMode? conversationOverride,
    SynthesisPreferences? synthesisPreferences,
    ResponseDiscipline? responseDiscipline,
    bool? adaptToVeilState,
    bool? adaptToAtlasPhase,
  }) {
    return EngagementSettings(
      defaultMode: defaultMode ?? this.defaultMode,
      conversationOverride: conversationOverride ?? this.conversationOverride,
      synthesisPreferences: synthesisPreferences ?? this.synthesisPreferences,
      responseDiscipline: responseDiscipline ?? this.responseDiscipline,
      adaptToVeilState: adaptToVeilState ?? this.adaptToVeilState,
      adaptToAtlasPhase: adaptToAtlasPhase ?? this.adaptToAtlasPhase,
    );
  }

  /// Clear conversation override to return to default mode
  EngagementSettings clearConversationOverride() {
    return copyWith(conversationOverride: null);
  }
}

/// Engagement context for LUMARA Control State integration
class EngagementContext {
  final EngagementSettings settings;
  final EngagementMode effectiveMode;
  final Map<String, dynamic> computedBehaviorParams;

  const EngagementContext({
    required this.settings,
    required this.effectiveMode,
    required this.computedBehaviorParams,
  });

  /// Convert to JSON for LUMARA Control State
  Map<String, dynamic> toControlStateJson() => {
    'engagement': {
      'mode': effectiveMode.toString(),
      'synthesis_allowed': _getSynthesisAllowed(),
      'max_temporal_connections': settings.responseDiscipline.getEffectiveMaxTemporalConnections(effectiveMode),
      'max_explorative_questions': settings.responseDiscipline.getEffectiveMaxExplorativeQuestions(effectiveMode),
      'allow_therapeutic_language': settings.responseDiscipline.allowTherapeuticLanguage,
      'allow_prescriptive_guidance': settings.responseDiscipline.allowPrescriptiveGuidance,
      'response_length': settings.responseDiscipline.preferredLength.toString(),
      'synthesis_depth': settings.synthesisPreferences.synthesisDepth.toString(),
      'protected_domains': settings.synthesisPreferences.protectedDomains,
      'behavioral_params': computedBehaviorParams,
    },
  };

  Map<String, bool> _getSynthesisAllowed() => {
    // All domains use the same setting (simplified)
    'faith_work': settings.synthesisPreferences.allowCrossDomainSynthesis,
    'relationship_work': settings.synthesisPreferences.allowCrossDomainSynthesis,
    'health_emotional': settings.synthesisPreferences.allowCrossDomainSynthesis,
    'creative_intellectual': settings.synthesisPreferences.allowCrossDomainSynthesis,
  };
}

/// Engagement behavior computer - integrates with LUMARA's existing behavior computation
class EngagementBehaviorComputer {

  /// Compute engagement-adjusted behavioral parameters
  /// Integrates with VEIL, ATLAS, and FAVORITES to modify base behavior
  static Map<String, dynamic> computeEngagementBehavior({
    required EngagementSettings engagementSettings,
    required String atlasPhase,
    required int readinessScore,
    required Map<String, dynamic> veilState,
    required Map<String, dynamic> favoritesProfile,
    bool sentinelAlert = false,
  }) {
    final mode = engagementSettings.activeMode;

    // Base behavioral parameters from mode
    Map<String, double> baseParams = _getBaseBehaviorForMode(mode);

    // Adapt based on ATLAS phase if enabled
    if (engagementSettings.adaptToAtlasPhase) {
      baseParams = _adaptToAtlasPhase(baseParams, atlasPhase, readinessScore);
    }

    // Adapt based on VEIL state if enabled
    if (engagementSettings.adaptToVeilState) {
      baseParams = _adaptToVeilState(baseParams, veilState);
    }

    // Apply FAVORITES profile influence
    baseParams = _applyFavoritesInfluence(baseParams, favoritesProfile);

    // Apply sentinel alert override (safety first)
    if (sentinelAlert) {
      baseParams = _applySentinelOverride(baseParams);
    }

    return Map<String, dynamic>.from(baseParams);
  }

  static Map<String, double> _getBaseBehaviorForMode(EngagementMode mode) {
    switch (mode) {
      case EngagementMode.reflect:
        return {
          'engagement_intensity': 0.3,  // Low engagement
          'explorative_tendency': 0.2,  // Minimal exploration
          'synthesis_tendency': 0.1,    // No synthesis
          'stopping_threshold': 0.7,    // Stop early
          'question_propensity': 0.1,   // Few questions
        };

      case EngagementMode.deeper:
      case EngagementMode.explore:
      case EngagementMode.integrate:
        return {
          'engagement_intensity': 0.8,  // High engagement
          'explorative_tendency': 0.8,  // High exploration
          'synthesis_tendency': 0.9,    // Full synthesis
          'stopping_threshold': 0.3,    // Continue deeper
          'question_propensity': 0.6,   // More questions
        };
    }
  }

  static Map<String, double> _adaptToAtlasPhase(
    Map<String, double> params,
    String phase,
    int readinessScore,
  ) {
    final phaseMultiplier = _getPhaseMultiplier(phase, params);
    final readinessMultiplier = readinessScore / 100.0;

    params['engagement_intensity'] =
        (params['engagement_intensity']! * phaseMultiplier * readinessMultiplier).clamp(0.0, 1.0);

    return params;
  }

  static double _getPhaseMultiplier(String phase, Map<String, double> params) {
    switch (phase.toLowerCase()) {
      case 'discovery':
        return 1.2;
      case 'recovery':
        params['stopping_threshold'] = params['stopping_threshold']! + 0.2;
        return 0.8;
      case 'breakthrough':
        return 1.1;
      case 'consolidation':
        params['synthesis_tendency'] = params['synthesis_tendency']! + 0.2;
        return 1.0;
      default:
        return 1.0;
    }
  }

  static Map<String, double> _adaptToVeilState(
    Map<String, double> params,
    Map<String, dynamic> veilState,
  ) {
    final health = veilState['health'] as Map<String, dynamic>? ?? {};
    final sleepQuality = health['sleepQuality'] as double? ?? 1.0;
    final energyLevel = health['energyLevel'] as double? ?? 1.0;
    final healthMultiplier = (sleepQuality + energyLevel) / 2.0;

    if (healthMultiplier < 0.5) {
      params['engagement_intensity'] = params['engagement_intensity']! * 0.7;
      params['stopping_threshold'] = params['stopping_threshold']! + 0.2;
    }

    final timeOfDay = veilState['timeOfDay'] as String? ?? 'day';
    if (timeOfDay == 'night' || timeOfDay == 'late_night') {
      params['engagement_intensity'] = params['engagement_intensity']! * 0.8;
      params['question_propensity'] = params['question_propensity']! * 0.7;
    }

    return params;
  }

  static Map<String, double> _applyFavoritesInfluence(
    Map<String, double> params,
    Map<String, dynamic> favoritesProfile,
  ) {
    // Let user's favorites profile influence engagement behavior
    final directness = favoritesProfile['directness'] as double? ?? 0.5;
    final rigor = favoritesProfile['rigor'] as double? ?? 0.5;
    final warmth = favoritesProfile['warmth'] as double? ?? 0.5;

    // High directness reduces question propensity
    params['question_propensity'] = params['question_propensity']! * (1.0 - directness * 0.5);

    // High rigor increases synthesis tendency
    params['synthesis_tendency'] = params['synthesis_tendency']! + rigor * 0.2;

    // High warmth slightly increases engagement
    params['engagement_intensity'] = params['engagement_intensity']! + warmth * 0.1;

    return params;
  }

  static Map<String, double> _applySentinelOverride(Map<String, double> params) {
    // Safety override - reduce all engagement when sentinel alert is active
    return {
      'engagement_intensity': 0.4,
      'explorative_tendency': 0.2,
      'synthesis_tendency': 0.1,
      'stopping_threshold': 0.8,
      'question_propensity': 0.1,
    };
  }
}