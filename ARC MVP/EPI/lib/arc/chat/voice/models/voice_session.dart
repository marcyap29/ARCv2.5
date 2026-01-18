/// Voice Session Models
/// 
/// Data models for voice conversation sessions and turns
/// - VoiceSession: Complete voice conversation with multiple turns
/// - VoiceConversationTurn: Single exchange (user speaks, LUMARA responds)
/// - Privacy settings and metadata

import 'package:equatable/equatable.dart';
import '../../../../models/phase_models.dart';

/// Voice Conversation Turn
/// 
/// Represents a single exchange in a voice conversation
class VoiceConversationTurn extends Equatable {
  final String userText;
  final String lumaraResponse;
  final DateTime timestamp;
  final Duration? userSpeakingDuration;
  final Duration? processingLatency;
  final Map<String, String>? prismReversibleMap; // LOCAL ONLY - never send to server
  final double? userSentiment; // Optional analytics
  
  const VoiceConversationTurn({
    required this.userText,
    required this.lumaraResponse,
    required this.timestamp,
    this.userSpeakingDuration,
    this.processingLatency,
    this.prismReversibleMap,
    this.userSentiment,
  });
  
  /// Convert to JSON for local storage (includes reversible map)
  Map<String, dynamic> toLocalJson() => {
    'user_text': userText,
    'lumara_response': lumaraResponse,
    'timestamp': timestamp.toIso8601String(),
    'user_speaking_duration_ms': userSpeakingDuration?.inMilliseconds,
    'processing_latency_ms': processingLatency?.inMilliseconds,
    'prism_reversible_map': prismReversibleMap,
    'user_sentiment': userSentiment,
  };
  
  /// Convert to JSON for remote storage (NO reversible map)
  Map<String, dynamic> toRemoteJson() => {
    'user_text': userText,
    'lumara_response': lumaraResponse,
    'timestamp': timestamp.toIso8601String(),
    'user_speaking_duration_ms': userSpeakingDuration?.inMilliseconds,
    'processing_latency_ms': processingLatency?.inMilliseconds,
    // NO prism_reversible_map - stays local only
    'user_sentiment': userSentiment,
  };
  
  /// Create from JSON
  factory VoiceConversationTurn.fromJson(Map<String, dynamic> json) {
    return VoiceConversationTurn(
      userText: json['user_text'] as String,
      lumaraResponse: json['lumara_response'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      userSpeakingDuration: json['user_speaking_duration_ms'] != null
          ? Duration(milliseconds: json['user_speaking_duration_ms'] as int)
          : null,
      processingLatency: json['processing_latency_ms'] != null
          ? Duration(milliseconds: json['processing_latency_ms'] as int)
          : null,
      prismReversibleMap: json['prism_reversible_map'] != null
          ? Map<String, String>.from(json['prism_reversible_map'] as Map)
          : null,
      userSentiment: json['user_sentiment'] as double?,
    );
  }
  
  @override
  List<Object?> get props => [
    userText,
    lumaraResponse,
    timestamp,
    userSpeakingDuration,
    processingLatency,
    prismReversibleMap,
    userSentiment,
  ];
}

/// Voice Privacy Settings
class VoicePrivacySettings {
  final bool storeRawAudio;
  final bool storeRawTranscripts;
  final bool storeProcessedConversation;
  
  const VoicePrivacySettings({
    this.storeRawAudio = false, // Default: no
    this.storeRawTranscripts = false, // Default: no
    this.storeProcessedConversation = true, // Always true for timeline
  });
  
  Map<String, dynamic> toJson() => {
    'store_raw_audio': storeRawAudio,
    'store_raw_transcripts': storeRawTranscripts,
    'store_processed_conversation': storeProcessedConversation,
  };
  
  factory VoicePrivacySettings.fromJson(Map<String, dynamic> json) {
    return VoicePrivacySettings(
      storeRawAudio: json['store_raw_audio'] as bool? ?? false,
      storeRawTranscripts: json['store_raw_transcripts'] as bool? ?? false,
      storeProcessedConversation: json['store_processed_conversation'] as bool? ?? true,
    );
  }
}

/// Voice Session
/// 
/// Represents a complete voice conversation session with LUMARA
class VoiceSession extends Equatable {
  final String sessionId;
  final DateTime startTime;
  final DateTime? endTime;
  final List<VoiceConversationTurn> turns;
  final PhaseLabel detectedPhase;
  final VoicePrivacySettings privacySettings;
  final Map<String, dynamic>? metadata;
  
  const VoiceSession({
    required this.sessionId,
    required this.startTime,
    this.endTime,
    required this.turns,
    required this.detectedPhase,
    this.privacySettings = const VoicePrivacySettings(),
    this.metadata,
  });
  
  /// Get total duration of session
  Duration get totalDuration {
    if (endTime == null) {
      return DateTime.now().difference(startTime);
    }
    return endTime!.difference(startTime);
  }
  
  /// Get number of turns
  int get turnCount => turns.length;
  
  /// Check if session is active
  bool get isActive => endTime == null;
  
  /// Get formatted transcript of entire conversation
  String getFormattedTranscript() {
    final buffer = StringBuffer();
    
    for (final turn in turns) {
      buffer.writeln('You: ${turn.userText}');
      buffer.writeln('LUMARA: ${turn.lumaraResponse}');
      buffer.writeln();
    }
    
    return buffer.toString().trim();
  }
  
  /// Get all text for semantic indexing (user + LUMARA combined)
  String getAllText() {
    return turns.map((turn) => '${turn.userText} ${turn.lumaraResponse}').join(' ');
  }
  
  /// Convert to JSON for local storage
  Map<String, dynamic> toLocalJson() => {
    'session_id': sessionId,
    'start_time': startTime.toIso8601String(),
    'end_time': endTime?.toIso8601String(),
    'turns': turns.map((t) => t.toLocalJson()).toList(),
    'detected_phase': detectedPhase.name,
    'privacy_settings': privacySettings.toJson(),
    'metadata': metadata,
  };
  
  /// Convert to JSON for remote storage
  Map<String, dynamic> toRemoteJson() => {
    'session_id': sessionId,
    'start_time': startTime.toIso8601String(),
    'end_time': endTime?.toIso8601String(),
    'turns': turns.map((t) => t.toRemoteJson()).toList(),
    'detected_phase': detectedPhase.name,
    // Privacy settings and reversible maps stay local
    'metadata': metadata,
  };
  
  /// Create from JSON
  factory VoiceSession.fromJson(Map<String, dynamic> json) {
    return VoiceSession(
      sessionId: json['session_id'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      turns: (json['turns'] as List<dynamic>)
          .map((t) => VoiceConversationTurn.fromJson(t as Map<String, dynamic>))
          .toList(),
      detectedPhase: PhaseLabel.values.firstWhere(
        (p) => p.name == json['detected_phase'],
        orElse: () => PhaseLabel.discovery,
      ),
      privacySettings: json['privacy_settings'] != null
          ? VoicePrivacySettings.fromJson(json['privacy_settings'] as Map<String, dynamic>)
          : const VoicePrivacySettings(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
  
  /// Create a copy with updates
  VoiceSession copyWith({
    String? sessionId,
    DateTime? startTime,
    DateTime? endTime,
    List<VoiceConversationTurn>? turns,
    PhaseLabel? detectedPhase,
    VoicePrivacySettings? privacySettings,
    Map<String, dynamic>? metadata,
  }) {
    return VoiceSession(
      sessionId: sessionId ?? this.sessionId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      turns: turns ?? this.turns,
      detectedPhase: detectedPhase ?? this.detectedPhase,
      privacySettings: privacySettings ?? this.privacySettings,
      metadata: metadata ?? this.metadata,
    );
  }
  
  @override
  List<Object?> get props => [
    sessionId,
    startTime,
    endTime,
    turns,
    detectedPhase,
    privacySettings,
    metadata,
  ];
}

/// Voice Session Builder
/// 
/// Helper for building sessions incrementally
class VoiceSessionBuilder {
  String? _sessionId;
  DateTime? _startTime;
  final List<VoiceConversationTurn> _turns = [];
  PhaseLabel _detectedPhase = PhaseLabel.discovery;
  VoicePrivacySettings _privacySettings = const VoicePrivacySettings();
  Map<String, dynamic>? _metadata;
  
  void setSessionId(String id) => _sessionId = id;
  void setStartTime(DateTime time) => _startTime = time;
  void setPhase(PhaseLabel phase) => _detectedPhase = phase;
  void setPrivacySettings(VoicePrivacySettings settings) => _privacySettings = settings;
  void setMetadata(Map<String, dynamic> metadata) => _metadata = metadata;
  
  void addTurn(VoiceConversationTurn turn) => _turns.add(turn);
  
  void clearTurns() => _turns.clear();
  
  int get turnCount => _turns.length;
  bool get isEmpty => _turns.isEmpty;
  bool get isNotEmpty => _turns.isNotEmpty;
  
  VoiceSession build({DateTime? endTime}) {
    if (_sessionId == null || _startTime == null) {
      throw StateError('Session ID and start time must be set');
    }
    
    return VoiceSession(
      sessionId: _sessionId!,
      startTime: _startTime!,
      endTime: endTime,
      turns: List.unmodifiable(_turns),
      detectedPhase: _detectedPhase,
      privacySettings: _privacySettings,
      metadata: _metadata,
    );
  }
}
