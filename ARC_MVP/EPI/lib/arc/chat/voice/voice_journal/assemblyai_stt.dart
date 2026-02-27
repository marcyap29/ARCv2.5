/// AssemblyAI Streaming STT for Voice Journal
/// 
/// Wrapper around AssemblyAI streaming transcription that:
/// - Provides partial transcript updates for live display
/// - Detects end-of-turn using silence/endpoint detection
/// - Accumulates full transcript across multiple speech segments
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../transcription/transcription_provider.dart';
import '../transcription/assemblyai_provider.dart';
import '../transcription/ondevice_provider.dart' show OnDeviceTranscriptionProvider;
import '../../../../services/assemblyai_service.dart';
import 'voice_journal_state.dart';

/// Configuration for STT end-of-turn detection
class SttConfig {
  /// Silence duration (ms) before considering turn ended
  final int silenceThresholdMs;
  
  /// Minimum transcript length before silence detection activates
  final int minTranscriptLength;
  
  /// Whether to use automatic end-of-turn detection
  final bool autoEndTurn;

  const SttConfig({
    this.silenceThresholdMs = 1500,  // 1.5 seconds of silence = end of turn
    this.minTranscriptLength = 10,   // At least 10 chars before ending
    this.autoEndTurn = false,        // Disable auto-end by default (user controls)
    // Note: Auto-response is intentionally disabled for user control.
    // Users must manually tap the mic button to stop recording and process.
  });
}

/// Callback types for STT events
typedef OnPartialTranscript = void Function(String text);
typedef OnFinalTranscript = void Function(String text);
typedef OnTurnEnd = void Function(String fullTranscript);
typedef OnSttError = void Function(String error);
typedef OnAudioLevel = void Function(double level);

/// AssemblyAI STT Service for Voice Journal
/// 
/// Manages streaming transcription with:
/// - Live partial updates
/// - End-of-turn detection
/// - Accumulated transcript across segments
class AssemblyAISttService {
  final AssemblyAIService _assemblyAIService;
  final SttConfig _config;
  final VoiceLatencyMetrics _metrics;
  
  AssemblyAIProvider? _cloudProvider;
  OnDeviceTranscriptionProvider? _localProvider;
  TranscriptionProvider? _activeProvider;
  
  // Transcript accumulation
  final StringBuffer _accumulatedTranscript = StringBuffer();
  String _currentPartial = '';
  
  // End-of-turn detection
  Timer? _silenceTimer;
  bool _hasSpoken = false;
  
  // Callbacks
  OnPartialTranscript? _onPartial;
  OnFinalTranscript? _onFinal;
  OnTurnEnd? _onTurnEnd;
  OnSttError? _onError;
  OnAudioLevel? _onAudioLevel;
  
  // State
  bool _isListening = false;
  bool _isInitialized = false;

  AssemblyAISttService({
    required AssemblyAIService assemblyAIService,
    SttConfig config = const SttConfig(),
    VoiceLatencyMetrics? metrics,
  })  : _assemblyAIService = assemblyAIService,
        _config = config,
        _metrics = metrics ?? VoiceLatencyMetrics();

  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;
  String get currentTranscript => _accumulatedTranscript.toString() + _currentPartial;

  /// Initialize STT service
  /// 
  /// Attempts to use AssemblyAI cloud first, falls back to on-device
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      // Try cloud provider first
      final token = await _assemblyAIService.getToken();
      if (token != null && token.isNotEmpty) {
        _cloudProvider = AssemblyAIProvider(token: token);
        if (await _cloudProvider!.initialize()) {
          debugPrint('AssemblyAI STT: Cloud provider initialized');
          _activeProvider = _cloudProvider;
          _isInitialized = true;
          return true;
        }
      }
      
      // Fall back to on-device
      debugPrint('AssemblyAI STT: Falling back to on-device provider');
      _localProvider = OnDeviceTranscriptionProvider();
      if (await _localProvider!.initialize()) {
        _activeProvider = _localProvider;
        _isInitialized = true;
        return true;
      }
      
      debugPrint('AssemblyAI STT: All providers failed to initialize');
      return false;
    } catch (e) {
      debugPrint('AssemblyAI STT initialization error: $e');
      return false;
    }
  }

  /// Start listening for speech
  Future<void> startListening({
    OnPartialTranscript? onPartial,
    OnFinalTranscript? onFinal,
    OnTurnEnd? onTurnEnd,
    OnSttError? onError,
    OnAudioLevel? onAudioLevel,
  }) async {
    if (!_isInitialized || _activeProvider == null) {
      onError?.call('STT not initialized');
      return;
    }
    
    if (_isListening) {
      debugPrint('AssemblyAI STT: Already listening');
      return;
    }
    
    _onPartial = onPartial;
    _onFinal = onFinal;
    _onTurnEnd = onTurnEnd;
    _onError = onError;
    _onAudioLevel = onAudioLevel;
    
    // Reset state
    _accumulatedTranscript.clear();
    _currentPartial = '';
    _hasSpoken = false;
    _metrics.sessionStart = DateTime.now();
    
    _isListening = true;
    
    try {
      await _activeProvider!.startListening(
        onPartialResult: _handlePartialResult,
        onFinalResult: _handleFinalResult,
        onError: _handleError,
        onSoundLevel: _handleSoundLevel,
      );
    } catch (e) {
      _isListening = false;
      _handleError('Failed to start listening: $e');
    }
  }

  void _handlePartialResult(TranscriptSegment segment) {
    // Track first partial timestamp
    _metrics.firstPartialTranscript ??= DateTime.now();
    
    _currentPartial = segment.text;
    _hasSpoken = true;
    
    // Reset silence timer
    _resetSilenceTimer();
    
    // Notify listener
    final fullText = _accumulatedTranscript.toString() + _currentPartial;
    _onPartial?.call(fullText);
  }

  void _handleFinalResult(TranscriptSegment segment) {
    // Add to accumulated transcript
    if (_accumulatedTranscript.isNotEmpty && segment.text.isNotEmpty) {
      _accumulatedTranscript.write(' ');
    }
    _accumulatedTranscript.write(segment.text);
    _currentPartial = '';
    
    // Notify listener
    _onFinal?.call(_accumulatedTranscript.toString());
    
    // Reset silence timer for end-of-turn detection
    _resetSilenceTimer();
  }

  void _handleError(String error) {
    debugPrint('AssemblyAI STT error: $error');
    _onError?.call(error);
  }

  void _handleSoundLevel(double level) {
    _onAudioLevel?.call(level);
    
    // If user is speaking, reset silence timer
    if (level > 0.1 && _hasSpoken) {
      _resetSilenceTimer();
    }
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    
    if (!_config.autoEndTurn) return;
    
    // Only start timer if we have enough transcript
    if (_accumulatedTranscript.length >= _config.minTranscriptLength) {
      _silenceTimer = Timer(
        Duration(milliseconds: _config.silenceThresholdMs),
        _onSilenceDetected,
      );
    }
  }

  void _onSilenceDetected() {
    if (!_isListening) return;
    
    debugPrint('AssemblyAI STT: Silence detected, ending turn');
    _metrics.turnEndDetected = DateTime.now();
    
    // Get final transcript and trigger turn end
    final fullTranscript = _accumulatedTranscript.toString().trim();
    if (fullTranscript.isNotEmpty) {
      _onTurnEnd?.call(fullTranscript);
    }
  }

  /// Manually end the current turn
  /// 
  /// Call this when user presses button to stop recording
  Future<String> endTurn() async {
    _silenceTimer?.cancel();
    _metrics.turnEndDetected = DateTime.now();
    
    // Stop listening to get any final transcript
    await stopListening();
    
    final fullTranscript = _accumulatedTranscript.toString().trim();
    return fullTranscript;
  }

  /// Stop listening without ending turn
  Future<void> stopListening() async {
    if (!_isListening) return;
    
    _silenceTimer?.cancel();
    _isListening = false;
    
    try {
      await _activeProvider?.stopListening();
    } catch (e) {
      debugPrint('AssemblyAI STT: Error stopping: $e');
    }
  }

  /// Cancel listening and discard transcript
  Future<void> cancelListening() async {
    if (!_isListening) return;
    
    _silenceTimer?.cancel();
    _isListening = false;
    _accumulatedTranscript.clear();
    _currentPartial = '';
    
    try {
      await _activeProvider?.cancelListening();
    } catch (e) {
      debugPrint('AssemblyAI STT: Error canceling: $e');
    }
  }

  /// Resume listening (for multi-turn conversations)
  Future<void> resumeListening() async {
    if (_isListening) return;
    
    _currentPartial = '';
    // Keep accumulated transcript for multi-turn
    
    await startListening(
      onPartial: _onPartial,
      onFinal: _onFinal,
      onTurnEnd: _onTurnEnd,
      onError: _onError,
      onAudioLevel: _onAudioLevel,
    );
  }

  /// Clear accumulated transcript (start fresh)
  void clearTranscript() {
    _accumulatedTranscript.clear();
    _currentPartial = '';
    _hasSpoken = false;
  }

  /// Dispose of resources
  Future<void> dispose() async {
    _silenceTimer?.cancel();
    _isListening = false;
    _isInitialized = false;
    
    await _cloudProvider?.dispose();
    await _localProvider?.dispose();
    
    _activeProvider = null;
    _cloudProvider = null;
    _localProvider = null;
  }
}

