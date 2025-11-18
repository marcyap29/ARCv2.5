// lib/lumara/models/lumara_reflection_options.dart
// Consolidated models for LUMARA v2.3 reflection system with all expansion and continuation options

/// Phase hint for LUMARA reflections
enum PhaseHint {
  discovery,
  expansion,
  transition,
  consolidation,
  recovery,
  breakthrough,
}

/// Entry type for LUMARA reflections
enum EntryType {
  journal,
  draft,
  chat,
  photo,
  audio,
  video,
  voice,
}

/// Tone mode for LUMARA reflections
enum ToneMode {
  /// Default tone (balanced, phase-aware)
  normal,
  
  /// Softened tone (gentle, containing, fewer directives)
  soft,
}

/// Conversation mode for continuation dialogues
enum ConversationMode {
  /// Suggest practical ideas from past patterns
  ideas,
  
  /// Help think through with logical scaffolding
  think,
  
  /// Offer different perspective/reframing
  perspective,
  
  /// Suggest next steps (phase-appropriate)
  nextSteps,
  
  /// Reflect more deeply (invoke More Depth pipeline)
  reflectDeeply,

  /// Finish the previous reply without restarting context
  continueThought,
}

/// Media candidate for multimodal context
class MediaCandidate {
  final String id;
  final String type; // "photo"|"audio"|"video"|"chat"|"journal"
  final DateTime? createdAt;
  final String? caption;

  MediaCandidate({
    required this.id,
    required this.type,
    this.createdAt,
    this.caption,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'createdAt': createdAt?.toIso8601String(),
    'caption': caption,
  };

  factory MediaCandidate.fromJson(Map<String, dynamic> json) => MediaCandidate(
    id: json['id'] as String,
    type: json['type'] as String,
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : null,
    caption: json['caption'] as String?,
  );
}

/// Options for LUMARA reflection generation
class LumaraReflectionOptions {
  /// Prefer question expansion (for More Depth)
  final bool preferQuestionExpansion;
  
  /// Tone mode (default or soft)
  final ToneMode toneMode;
  
  /// Regenerate with different rhetorical focus
  final bool regenerate;
  
  /// Conversation mode for continuation dialogues
  final ConversationMode? conversationMode;

  LumaraReflectionOptions({
    this.preferQuestionExpansion = false,
    this.toneMode = ToneMode.normal,
    this.regenerate = false,
    this.conversationMode,
  });

  Map<String, dynamic> toJson() => {
    'preferQuestionExpansion': preferQuestionExpansion,
    'toneMode': toneMode.name,
    'regenerate': regenerate,
    'conversationMode': conversationMode?.name,
  };

  factory LumaraReflectionOptions.fromJson(Map<String, dynamic> json) => LumaraReflectionOptions(
    preferQuestionExpansion: json['preferQuestionExpansion'] as bool? ?? false,
    toneMode: json['toneMode'] != null 
        ? ToneMode.values.firstWhere(
            (e) => e.name == json['toneMode'],
            orElse: () => ToneMode.normal,
          )
        : ToneMode.normal,
    regenerate: json['regenerate'] as bool? ?? false,
    conversationMode: json['conversationMode'] != null
        ? (() {
            try {
              return ConversationMode.values.firstWhere(
                (e) => e.name == json['conversationMode'],
              );
            } catch (_) {
              return null;
            }
          })()
        : null,
  );
}

/// Request model for LUMARA reflection generation
class LumaraReflectionRequest {
  final String userText;
  final PhaseHint? phaseHint;
  final EntryType entryType;
  final List<String> priorKeywords;
  final List<String> matchedNodeHints;
  final List<MediaCandidate> mediaCandidates;
  final LumaraReflectionOptions options;

  LumaraReflectionRequest({
    required this.userText,
    this.phaseHint,
    this.entryType = EntryType.journal,
    this.priorKeywords = const [],
    this.matchedNodeHints = const [],
    this.mediaCandidates = const [],
    required this.options,
  });

  Map<String, dynamic> toJson() => {
    'userText': userText,
    'phaseHint': phaseHint?.name,
    'entryType': entryType.name,
    'priorKeywords': priorKeywords,
    'matchedNodeHints': matchedNodeHints,
    'mediaCandidates': mediaCandidates.map((m) => m.toJson()).toList(),
    'options': options.toJson(),
  };
}

/// Score metrics for LUMARA response quality
class LumaraResponseScore {
  final double empathy;
  final double depth;
  final double agency;
  final double structurePenalty;
  final double tonePenalty;
  final double resonance;

  LumaraResponseScore({
    required this.empathy,
    required this.depth,
    required this.agency,
    this.structurePenalty = 0.0,
    this.tonePenalty = 0.0,
    required this.resonance,
  });

  factory LumaraResponseScore.fromJson(Map<String, dynamic> json) => LumaraResponseScore(
    empathy: (json['empathy'] as num?)?.toDouble() ?? 0.0,
    depth: (json['depth'] as num?)?.toDouble() ?? 0.0,
    agency: (json['agency'] as num?)?.toDouble() ?? 0.0,
    structurePenalty: (json['structurePenalty'] as num?)?.toDouble() ?? 0.0,
    tonePenalty: (json['tonePenalty'] as num?)?.toDouble() ?? 0.0,
    resonance: (json['resonance'] as num?)?.toDouble() ?? 0.0,
  );

  Map<String, dynamic> toJson() => {
    'empathy': empathy,
    'depth': depth,
    'agency': agency,
    'structurePenalty': structurePenalty,
    'tonePenalty': tonePenalty,
    'resonance': resonance,
  };
}

/// Metadata for LUMARA response
class LumaraResponseMeta {
  final int questionsUsed;
  final String? usedHook;
  final String? phaseHint;
  final String entryType;

  LumaraResponseMeta({
    required this.questionsUsed,
    this.usedHook,
    this.phaseHint,
    required this.entryType,
  });

  factory LumaraResponseMeta.fromJson(Map<String, dynamic> json) => LumaraResponseMeta(
    questionsUsed: json['questionsUsed'] as int? ?? 0,
    usedHook: json['usedHook'] as String?,
    phaseHint: json['phaseHint'] as String?,
    entryType: json['entryType'] as String? ?? 'journal',
  );

  Map<String, dynamic> toJson() => {
    'questionsUsed': questionsUsed,
    'usedHook': usedHook,
    'phaseHint': phaseHint,
    'entryType': entryType,
  };
}

/// Response model for LUMARA reflection
class LumaraReflectionResponse {
  final String text;
  final bool isAbstract;
  final LumaraResponseScore score;
  final LumaraResponseMeta meta;

  LumaraReflectionResponse({
    required this.text,
    required this.isAbstract,
    required this.score,
    required this.meta,
  });

  factory LumaraReflectionResponse.fromJson(Map<String, dynamic> json) => LumaraReflectionResponse(
    text: json['text'] as String,
    isAbstract: json['abstract'] as bool? ?? false,
    score: LumaraResponseScore.fromJson(json['score'] as Map<String, dynamic>? ?? {}),
    meta: LumaraResponseMeta.fromJson(json['meta'] as Map<String, dynamic>? ?? {}),
  );

  Map<String, dynamic> toJson() => {
    'text': text,
    'abstract': isAbstract,
    'score': score.toJson(),
    'meta': meta.toJson(),
  };
}

