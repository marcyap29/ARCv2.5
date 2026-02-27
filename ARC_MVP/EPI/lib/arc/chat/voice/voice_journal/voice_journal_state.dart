/// Voice Journal State Machine
/// 
/// States:
/// - IDLE: Ready to start recording
/// - LISTENING: Recording audio, showing live transcript
/// - TRANSCRIBING: Processing final transcript (cloud STT)
/// - SCRUBBING: Running PRISM PII scrubber locally
/// - THINKING: Sending scrubbed text to Gemini, waiting for reply
/// - SPEAKING: TTS playing LUMARA's response
/// - SAVED: Journal entry saved successfully
/// - ERROR: Something went wrong
library;

import 'package:flutter/foundation.dart';

/// Voice journal states
enum VoiceJournalState {
  idle,
  listening,
  transcribing,
  scrubbing,
  thinking,
  speaking,
  saved,
  error,
}

/// Latency metrics for voice pipeline
class VoiceLatencyMetrics {
  DateTime? sessionStart;
  DateTime? firstPartialTranscript;
  DateTime? turnEndDetected;
  DateTime? scrubStart;
  DateTime? scrubEnd;
  DateTime? geminiRequestStart;
  DateTime? firstGeminiToken;
  DateTime? ttsStart;
  DateTime? ttsFirstAudio;
  DateTime? sessionEnd;

  void reset() {
    sessionStart = null;
    firstPartialTranscript = null;
    turnEndDetected = null;
    scrubStart = null;
    scrubEnd = null;
    geminiRequestStart = null;
    firstGeminiToken = null;
    ttsStart = null;
    ttsFirstAudio = null;
    sessionEnd = null;
  }

  Map<String, int?> toLatencyReport() {
    return {
      'time_to_first_partial_ms': _diffMs(sessionStart, firstPartialTranscript),
      'turn_end_to_scrub_start_ms': _diffMs(turnEndDetected, scrubStart),
      'scrub_duration_ms': _diffMs(scrubStart, scrubEnd),
      'scrub_end_to_gemini_ms': _diffMs(scrubEnd, geminiRequestStart),
      'time_to_first_gemini_token_ms': _diffMs(geminiRequestStart, firstGeminiToken),
      'gemini_to_tts_start_ms': _diffMs(firstGeminiToken, ttsStart),
      'time_to_first_audio_ms': _diffMs(ttsStart, ttsFirstAudio),
      'total_session_ms': _diffMs(sessionStart, sessionEnd),
    };
  }

  int? _diffMs(DateTime? start, DateTime? end) {
    if (start == null || end == null) return null;
    return end.difference(start).inMilliseconds;
  }

  @override
  String toString() {
    final report = toLatencyReport();
    final buffer = StringBuffer('Latency Report:\n');
    for (final entry in report.entries) {
      if (entry.value != null) {
        buffer.writeln('  ${entry.key}: ${entry.value}ms');
      }
    }
    return buffer.toString();
  }
}

/// PRISM redaction summary
class PrismRedactionSummary {
  final int totalRedactions;
  final List<String> redactionTypes;
  final Map<String, String> reversibleMap;

  const PrismRedactionSummary({
    required this.totalRedactions,
    required this.redactionTypes,
    required this.reversibleMap,
  });

  Map<String, dynamic> toJson() => {
    'total_redactions': totalRedactions,
    'redaction_types': redactionTypes,
    // Note: reversibleMap is NOT included in JSON - it stays local only
  };

  @override
  String toString() => 
    'PRISM: $totalRedactions redactions (${redactionTypes.join(", ")})';
}

/// Voice journal entry data (for saving)
class VoiceJournalEntry {
  final String sessionId;
  final DateTime timestamp;
  final String rawTranscript;       // LOCAL ONLY - never send to server
  final String scrubbedTranscript;  // Safe to send/store remotely
  final String lumaraReply;
  final VoiceLatencyMetrics? metrics;
  final PrismRedactionSummary? prismSummary;
  final int wordCount;

  const VoiceJournalEntry({
    required this.sessionId,
    required this.timestamp,
    required this.rawTranscript,
    required this.scrubbedTranscript,
    required this.lumaraReply,
    this.metrics,
    this.prismSummary,
    required this.wordCount,
  });

  /// Convert to JSON for local storage (includes raw transcript)
  Map<String, dynamic> toLocalJson() => {
    'session_id': sessionId,
    'timestamp': timestamp.toIso8601String(),
    'raw_transcript': rawTranscript,         // LOCAL ONLY
    'scrubbed_transcript': scrubbedTranscript,
    'lumara_reply': lumaraReply,
    'word_count': wordCount,
    'metrics': metrics?.toLatencyReport(),
    'prism_summary': prismSummary?.toJson(),
  };

  /// Convert to JSON for remote storage (NO raw transcript)
  Map<String, dynamic> toRemoteJson() => {
    'session_id': sessionId,
    'timestamp': timestamp.toIso8601String(),
    // NO raw_transcript - only scrubbed version
    'scrubbed_transcript': scrubbedTranscript,
    'lumara_reply': lumaraReply,
    'word_count': wordCount,
    // NO metrics or prism_summary for remote
  };
}

/// Voice journal state notifier
class VoiceJournalStateNotifier extends ChangeNotifier {
  VoiceJournalState _state = VoiceJournalState.idle;
  String? _errorMessage;
  String _partialTranscript = '';
  String _finalTranscript = '';
  String _scrubbedTranscript = '';
  String _lumaraReply = '';
  final VoiceLatencyMetrics _metrics = VoiceLatencyMetrics();

  VoiceJournalState get state => _state;
  String? get errorMessage => _errorMessage;
  String get partialTranscript => _partialTranscript;
  String get finalTranscript => _finalTranscript;
  String get scrubbedTranscript => _scrubbedTranscript;
  String get lumaraReply => _lumaraReply;
  VoiceLatencyMetrics get metrics => _metrics;

  /// Valid state transitions
  static const Map<VoiceJournalState, Set<VoiceJournalState>> _validTransitions = {
    VoiceJournalState.idle: {VoiceJournalState.listening, VoiceJournalState.error},
    VoiceJournalState.listening: {VoiceJournalState.transcribing, VoiceJournalState.idle, VoiceJournalState.error},
    VoiceJournalState.transcribing: {VoiceJournalState.scrubbing, VoiceJournalState.idle, VoiceJournalState.error}, // Allow idle for empty transcripts
    VoiceJournalState.scrubbing: {VoiceJournalState.thinking, VoiceJournalState.error},
    VoiceJournalState.thinking: {VoiceJournalState.speaking, VoiceJournalState.error},
    VoiceJournalState.speaking: {VoiceJournalState.listening, VoiceJournalState.saved, VoiceJournalState.error},
    VoiceJournalState.saved: {VoiceJournalState.idle},
    VoiceJournalState.error: {VoiceJournalState.idle},
  };

  /// Attempt to transition to a new state
  bool transitionTo(VoiceJournalState newState) {
    final validTargets = _validTransitions[_state] ?? {};
    if (!validTargets.contains(newState)) {
      debugPrint('VoiceJournal: Invalid transition from $_state to $newState');
      return false;
    }

    debugPrint('VoiceJournal: State $_state -> $newState');
    _state = newState;
    _errorMessage = null;
    notifyListeners();
    return true;
  }

  /// Set error state with message
  void setError(String message) {
    debugPrint('VoiceJournal ERROR: $message');
    _errorMessage = message;
    _state = VoiceJournalState.error;
    notifyListeners();
  }

  /// Update partial transcript (during listening)
  void updatePartialTranscript(String text) {
    _partialTranscript = text;
    notifyListeners();
  }

  /// Set final transcript (after turn end)
  void setFinalTranscript(String text) {
    _finalTranscript = text;
    _partialTranscript = '';
    notifyListeners();
  }

  /// Set scrubbed transcript (after PRISM)
  void setScrubbedTranscript(String text) {
    _scrubbedTranscript = text;
    notifyListeners();
  }

  /// Set LUMARA reply (after Gemini)
  void setLumaraReply(String text) {
    _lumaraReply = text;
    notifyListeners();
  }

  /// Append to LUMARA reply (for streaming)
  void appendToLumaraReply(String chunk) {
    _lumaraReply += chunk;
    notifyListeners();
  }

  /// Clear current transcript (after turn is added to conversation history)
  void clearCurrentTranscript() {
    _partialTranscript = '';
    _finalTranscript = '';
    _lumaraReply = '';
    notifyListeners();
  }

  /// Reset for new session
  void reset() {
    _state = VoiceJournalState.idle;
    _errorMessage = null;
    _partialTranscript = '';
    _finalTranscript = '';
    _scrubbedTranscript = '';
    _lumaraReply = '';
    _metrics.reset();
    notifyListeners();
  }

  /// Get display text for current state
  String get stateDisplayText {
    switch (_state) {
      case VoiceJournalState.idle:
        return 'Tap to start recording';
      case VoiceJournalState.listening:
        return 'Listening...';
      case VoiceJournalState.transcribing:
        return 'Processing...';
      case VoiceJournalState.scrubbing:
        return 'Securing...';
      case VoiceJournalState.thinking:
        return 'LUMARA is thinking...';
      case VoiceJournalState.speaking:
        return 'LUMARA is speaking...';
      case VoiceJournalState.saved:
        return 'Entry saved!';
      case VoiceJournalState.error:
        return _errorMessage ?? 'Something went wrong';
    }
  }

  /// Check if in a processing state (user should wait)
  bool get isProcessing =>
      _state == VoiceJournalState.transcribing ||
      _state == VoiceJournalState.scrubbing ||
      _state == VoiceJournalState.thinking ||
      _state == VoiceJournalState.speaking;

  /// Check if microphone is active
  bool get isMicrophoneActive => _state == VoiceJournalState.listening;
}

