/// Voice Session Service
/// 
/// Orchestrates the complete voice conversation flow:
/// 1. Initialize transcription (AssemblyAI primary, Apple On-Device fallback)
/// 2. Start listening (audio capture)
/// 3. Handle partial transcripts
/// 4. Detect endpoints with smart detector
/// 5. Scrub via PRISM
/// 6. Send to LUMARA unified API
/// 7. Play TTS response
/// 8. Save turn
/// 9. Loop or finalize session

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../audio/audio_capture_service.dart';
import '../endpoint/smart_endpoint_detector.dart';
import '../transcription/unified_transcription_service.dart';
import '../../../internal/echo/prism_adapter.dart';
import '../voice_journal/tts_client.dart';
import '../prompts/voice_response_builders.dart';
import '../../services/enhanced_lumara_api.dart';
import '../../models/lumara_reflection_options.dart' as models;
import '../models/voice_session.dart';
import '../../../../models/phase_models.dart';
import '../../../../services/lumara/entry_classifier.dart';

/// Voice session state
enum VoiceSessionState {
  idle,
  initializing,
  listening,
  processingTranscript,
  scrubbing,
  waitingForLumara,
  speaking,
  error,
}

/// Callback types
typedef OnSessionStateChanged = void Function(VoiceSessionState state);
typedef OnTranscriptUpdate = void Function(String transcript);
typedef OnLumaraResponse = void Function(String response);
typedef OnTurnComplete = void Function(VoiceConversationTurn turn);
typedef OnSessionComplete = void Function(VoiceSession session);
typedef OnSessionError = void Function(String error);

/// Transcript data class (for unified interface)
class TranscriptData {
  final String text;
  final bool isFinal;
  final DateTime timestamp;
  
  const TranscriptData({
    required this.text,
    required this.isFinal,
    required this.timestamp,
  });
}

/// Voice Session Service
/// 
/// Main orchestrator for voice conversations with LUMARA
/// 
/// Supports automatic fallback between transcription backends:
/// - Wispr Flow (if user has configured their own API key in settings)
/// - AssemblyAI (primary fallback, cloud-based, high accuracy)
/// - Apple On-Device (final fallback, always available, no network required)
class VoiceSessionService {
  final AudioCaptureService _audioCapture;
  final SmartEndpointDetector _endpointDetector;
  final PrismAdapter _prism;
  final TtsJournalClient _tts;
  final EnhancedLumaraApi _lumaraApi;
  final String _userId;
  final UnifiedTranscriptionService _unifiedTranscription;
  
  VoiceSessionState _state = VoiceSessionState.idle;
  VoiceSessionBuilder? _currentSession;
  PhaseLabel _currentPhase = PhaseLabel.discovery;
  
  String _currentTranscript = '';
  DateTime? _turnStartTime;
  bool _isProcessingTranscript = false; // Guard against double processing
  bool _usingOnDeviceFallback = false; // Track if using Apple On-Device fallback
  
  // Callbacks
  OnSessionStateChanged? onStateChanged;
  OnTranscriptUpdate? onTranscriptUpdate;
  OnLumaraResponse? onLumaraResponse;
  OnTurnComplete? onTurnComplete;
  OnSessionComplete? onSessionComplete;
  OnSessionError? onError;
  
  /// Callback for backend status messages
  Function(String message)? onBackendStatusMessage;
  
  // Public getter for endpoint detector (for UI tap handling)
  SmartEndpointDetector get endpointDetector => _endpointDetector;
  
  /// Whether currently using on-device fallback instead of AssemblyAI
  bool get isUsingFallback => _usingOnDeviceFallback;
  
  /// Currently active transcription backend
  TranscriptionBackend get activeBackend {
    return _unifiedTranscription.activeBackend;
  }
  
  VoiceSessionService({
    required AudioCaptureService audioCapture,
    required SmartEndpointDetector endpointDetector,
    required PrismAdapter prism,
    required TtsJournalClient tts,
    required EnhancedLumaraApi lumaraApi,
    required String userId,
    required UnifiedTranscriptionService unifiedTranscription,
  })  : _audioCapture = audioCapture,
        _endpointDetector = endpointDetector,
        _prism = prism,
        _tts = tts,
        _lumaraApi = lumaraApi,
        _userId = userId,
        _unifiedTranscription = unifiedTranscription {
    _setupCallbacks();
  }
  
  VoiceSessionState get state => _state;
  PhaseLabel get currentPhase => _currentPhase;
  VoiceSession? get currentSession => _currentSession?.build();
  
  /// Update current phase (affects endpoint detection)
  void updatePhase(PhaseLabel phase) {
    _currentPhase = phase;
    _endpointDetector.updatePhase(phase);
    debugPrint('VoiceSession: Phase updated to ${phase.name}');
  }
  
  /// Setup internal callbacks
  void _setupCallbacks() {
    // Audio capture callbacks
    _audioCapture.onAudioChunk = _onAudioChunk;
    _audioCapture.onAudioLevel = _onAudioLevel;
    _audioCapture.onError = _onAudioError;
    
    // Endpoint detector callbacks
    _endpointDetector.onEndpointDetected = _onEndpointDetected;
    _endpointDetector.onStateChanged = _onEndpointStateChanged;
    
    // TTS callbacks
    _tts.onStart = () => _updateState(VoiceSessionState.speaking);
    _tts.onComplete = _onTtsComplete;
    _tts.onError = _onTtsError;
  }
  
  /// Setup callbacks for unified transcription service
  void _setupUnifiedTranscriptionCallbacks() {
    _unifiedTranscription.onTranscript = (transcript, isFinal) {
      final transcriptData = TranscriptData(
        text: transcript,
        isFinal: isFinal,
        timestamp: DateTime.now(),
      );
      _onTranscript(transcriptData);
    };
    
    _unifiedTranscription.onError = (error) {
      _onTranscriptionError(error);
    };
    
    _unifiedTranscription.onConnected = () {
      debugPrint('VoiceSession: Transcription connected');
    };
    
    _unifiedTranscription.onDisconnected = () {
      debugPrint('VoiceSession: Transcription disconnected');
    };
  }
  
  /// Initialize session
  /// 
  /// Uses unified transcription service:
  /// - Primary: AssemblyAI (cloud-based, high accuracy)
  /// - Fallback: Apple On-Device (always available)
  Future<bool> initialize() async {
    _updateState(VoiceSessionState.initializing);
    _usingOnDeviceFallback = false;
    
    try {
      // Initialize unified transcription service (handles backend selection)
      final result = await _unifiedTranscription.initialize();
      
      if (result.success) {
        _usingOnDeviceFallback = result.backend == TranscriptionBackend.appleOnDevice;
        
        switch (result.backend) {
          case TranscriptionBackend.wisprFlow:
            debugPrint('VoiceSession: Using Wispr Flow (user API key)');
            onBackendStatusMessage?.call('Using Wispr Flow');
            break;
            
          case TranscriptionBackend.assemblyAI:
            debugPrint('VoiceSession: Using AssemblyAI (primary)');
            break;
            
          case TranscriptionBackend.appleOnDevice:
            debugPrint('VoiceSession: Using Apple On-Device (fallback)');
            onBackendStatusMessage?.call('Using on-device transcription');
            break;
            
          case TranscriptionBackend.none:
            break;
        }
        
        // Setup unified transcription callbacks
        _setupUnifiedTranscriptionCallbacks();
        
      } else {
        // Unified service failed - show error message
        final errorMsg = result.errorMessage ?? 'Transcription unavailable';
        debugPrint('VoiceSession: Transcription failed: $errorMsg');
        onError?.call(errorMsg);
        _updateState(VoiceSessionState.error);
        return false;
      }
      
      // Initialize audio capture
      final audioInitialized = await _audioCapture.initialize();
      if (!audioInitialized) {
        onError?.call('Failed to initialize audio');
        _updateState(VoiceSessionState.error);
        return false;
      }
      
      // Initialize TTS
      await _tts.initialize();
      
      debugPrint('VoiceSession: Initialized successfully '
          '(backend: ${_unifiedTranscription.activeBackendName})');
      _updateState(VoiceSessionState.idle);
      return true;
      
    } catch (e) {
      debugPrint('VoiceSession: Initialization error: $e');
      onError?.call('Initialization error: $e');
      _updateState(VoiceSessionState.error);
      return false;
    }
  }
  
  /// Start a new session
  Future<void> startSession() async {
    // Allow starting from idle OR listening (listening set immediately for UI feedback)
    if (_state != VoiceSessionState.idle && _state != VoiceSessionState.listening) {
      debugPrint('VoiceSession: Cannot start - not idle/listening (current state: ${_state.name})');
      return;
    }
    
    try {
      // Create new session
      _currentSession = VoiceSessionBuilder()
        ..setSessionId(const Uuid().v4())
        ..setStartTime(DateTime.now())
        ..setPhase(_currentPhase);
      
      debugPrint('VoiceSession: Session started');
      
      // Start first turn
      await _startTurn();
      
    } catch (e) {
      debugPrint('VoiceSession: Error starting session: $e');
      onError?.call('Error starting session: $e');
      _updateState(VoiceSessionState.error);
    }
  }
  
  /// Start a new turn
  Future<void> _startTurn() async {
    _currentTranscript = '';
    _turnStartTime = DateTime.now();
    _isProcessingTranscript = false; // Reset for new turn
    
    // Start transcription
    final started = await _unifiedTranscription.startListening();
    if (!started) {
      onError?.call('Failed to start transcription');
      _updateState(VoiceSessionState.error);
      return;
    }
    
    // Start audio capture (only needed for some backends)
    await _audioCapture.startRecording();
    
    // Start endpoint detector
    _endpointDetector.start();
    
    _updateState(VoiceSessionState.listening);
    debugPrint('VoiceSession: Turn started');
  }
  
  /// Handle audio chunks from microphone
  void _onAudioChunk(Uint8List audioData) {
    if (_state != VoiceSessionState.listening) return;
    
    // Notify endpoint detector of audio
    _endpointDetector.onAudioDetected();
    
    // Send audio to Wispr if using Wispr backend
    // (AssemblyAI and On-Device handle their own audio capture)
    if (_unifiedTranscription.activeBackend == TranscriptionBackend.wisprFlow) {
      _unifiedTranscription.sendAudioData(audioData);
    }
  }
  
  /// Handle audio level updates
  void _onAudioLevel(AudioLevel level) {
    // Audio level can be used for visualization
  }
  
  /// Track if we're waiting for final transcript after endpoint detected
  bool _waitingForFinalTranscript = false;
  
  /// Handle transcripts from transcription service
  void _onTranscript(TranscriptData transcript) {
    // Update current transcript
    _currentTranscript = transcript.text;
    
    // Notify UI
    onTranscriptUpdate?.call(transcript.text);
    
    // Update endpoint detector if still listening
    if (_state == VoiceSessionState.listening) {
      _endpointDetector.onTranscriptUpdate(transcript.text);
    }
    
    // If final transcript and we were waiting for it, process now
    if (transcript.isFinal && _waitingForFinalTranscript) {
      debugPrint('VoiceSession: Final transcript received, processing...');
      _waitingForFinalTranscript = false;
      _processTranscript();
    }
  }
  
  /// Handle endpoint detection (auto-detected by smart endpoint detector)
  void _onEndpointDetected() async {
    debugPrint('VoiceSession: Endpoint auto-detected');
    await _stopListeningAndProcess();
  }
  
  /// Stop listening and process transcript (for tap-to-toggle or endpoint detection)
  Future<void> stopListening() async {
    if (_state != VoiceSessionState.listening) {
      debugPrint('VoiceSession: Cannot stop listening - not in listening state');
      return;
    }
    debugPrint('VoiceSession: User tapped to stop listening');
    await _stopListeningAndProcess();
  }
  
  /// Internal method to stop listening and process transcript
  Future<void> _stopListeningAndProcess() async {
    final stopStart = DateTime.now();
    debugPrint('VoiceSession: Stop requested, current transcript: "${_currentTranscript.substring(0, _currentTranscript.length.clamp(0, 50))}..."');
    
    // IMMEDIATE visual feedback - change state right away so UI responds
    _updateState(VoiceSessionState.processingTranscript);
    
    // Stop audio capture
    await _audioCapture.stopRecording();
    
    // Stop endpoint detector
    _endpointDetector.stop();
    
    // Stop transcription
    await _unifiedTranscription.stopListening();
    
    // If we already have a good transcript from partial updates, process immediately
    if (_currentTranscript.trim().isNotEmpty) {
      debugPrint('VoiceSession: Have transcript, processing immediately (${DateTime.now().difference(stopStart).inMilliseconds}ms)');
      await _processTranscript();
      return;
    }
    
    // No transcript yet - wait briefly for any pending data
    _waitingForFinalTranscript = true;
    
    // Poll for transcript arrival with timeout
    const pollInterval = Duration(milliseconds: 100);
    const maxWait = Duration(seconds: 3);
    var elapsed = Duration.zero;
    
    while (_waitingForFinalTranscript && elapsed < maxWait) {
      await Future.delayed(pollInterval);
      elapsed += pollInterval;
      
      // Check if transcript arrived via callback
      if (_currentTranscript.trim().isNotEmpty) {
        debugPrint('VoiceSession: Transcript received after ${elapsed.inMilliseconds}ms');
        _waitingForFinalTranscript = false;
        await _processTranscript();
        return;
      }
    }
    
    // Timeout - process whatever we have (or empty)
    if (_waitingForFinalTranscript) {
      debugPrint('VoiceSession: Timeout after ${elapsed.inMilliseconds}ms, transcript: "${_currentTranscript}"');
      _waitingForFinalTranscript = false;
      await _processTranscript();
    }
  }
  
  /// Handle endpoint state changes
  void _onEndpointStateChanged(EndpointState endpointState) {
    // Endpoint state changes can be used for UI updates
  }
  
  /// Process transcript through PRISM and send to LUMARA
  Future<void> _processTranscript() async {
    // Guard against double processing
    if (_isProcessingTranscript) {
      debugPrint('VoiceSession: Already processing transcript, skipping duplicate call');
      return;
    }
    _isProcessingTranscript = true;
    
    final processStart = DateTime.now();
    
    if (_currentTranscript.trim().isEmpty) {
      debugPrint('VoiceSession: Empty transcript, skipping');
      _isProcessingTranscript = false;
      _updateState(VoiceSessionState.idle);
      return;
    }
    
    _updateState(VoiceSessionState.processingTranscript);
    
    try {
      // Scrub PII through PRISM
      _updateState(VoiceSessionState.scrubbing);
      final prismStart = DateTime.now();
      final prismResult = _prism.scrub(_currentTranscript);
      debugPrint('VoiceSession: PRISM took ${DateTime.now().difference(prismStart).inMilliseconds}ms, scrubbed ${prismResult.redactionCount} items');
      
      // =========================================================
      // JARVIS/SAMANTHA DUAL-MODE ROUTING
      // Classify depth and route to appropriate response path
      // =========================================================
      final depthResult = EntryClassifier.classifyVoiceDepth(prismResult.scrubbedText);
      final isReflective = depthResult.depth == VoiceDepthMode.reflective;
      
      debugPrint('VoiceSession: Depth classification: ${depthResult.depth.name} '
          '(confidence: ${depthResult.confidence.toStringAsFixed(2)}, '
          'triggers: ${depthResult.triggers.join(", ")})');
      
      // Send to LUMARA
      _updateState(VoiceSessionState.waitingForLumara);
      
      // Build conversation history for context
      final builtSession = _currentSession?.build();
      final conversationHistory = builtSession?.turns.map((turn) {
        return 'User: ${turn.userText}\nLUMARA: ${turn.lumaraResponse}';
      }).toList() ?? [];
      
      // Build appropriate prompt based on depth mode
      String voicePrompt;
      if (isReflective) {
        // SAMANTHA MODE: Deep, reflective engagement (150-200 words)
        voicePrompt = SamanthaPromptBuilder.build(
          userText: prismResult.scrubbedText,
          currentPhase: _currentPhase,
          conversationHistory: conversationHistory,
          detectedTriggers: depthResult.triggers,
        );
        debugPrint('VoiceSession: Using SAMANTHA mode (reflective)');
      } else {
        // JARVIS MODE: Quick, efficient response (50-100 words)
        voicePrompt = JarvisPromptBuilder.build(
          userText: prismResult.scrubbedText,
          currentPhase: _currentPhase,
          conversationHistory: conversationHistory,
        );
        debugPrint('VoiceSession: Using JARVIS mode (transactional)');
      }
      
      // Call LUMARA API with appropriate mode
      final apiStart = DateTime.now();
      final reflectionResult = await _lumaraApi.generatePromptedReflection(
        entryText: prismResult.scrubbedText,
        intent: isReflective ? 'reflective' : 'conversational',
        phase: _currentPhase.name,
        userId: _userId,
        chatContext: voicePrompt,
        forceQuickResponse: !isReflective,
        options: models.LumaraReflectionOptions(
          conversationMode: models.ConversationMode.think,
          toneMode: models.ToneMode.normal,
        ),
      );
      
      final apiDuration = DateTime.now().difference(apiStart).inMilliseconds;
      final maxLatency = isReflective 
          ? VoiceResponseConfig.samanthaHardLimitMs 
          : VoiceResponseConfig.jarvisTargetLatencyMs;
      
      debugPrint('VoiceSession: LUMARA API took ${apiDuration}ms '
          '(${isReflective ? "Samantha" : "Jarvis"} mode, limit: ${maxLatency}ms)');
      
      // Warn if latency exceeds target
      if (apiDuration > maxLatency) {
        debugPrint('VoiceSession: WARNING - Latency exceeded target! '
            '${apiDuration}ms > ${maxLatency}ms');
      }
      
      final response = reflectionResult.reflection;
      
      // Restore PII in response for TTS
      final restoredResponse = _prism.restore(response, prismResult.reversibleMap);
      
      debugPrint('VoiceSession: Total processing took ${DateTime.now().difference(processStart).inMilliseconds}ms');
      onLumaraResponse?.call(restoredResponse);
      
      // Play TTS
      await _tts.speak(restoredResponse);
      
      // Calculate latencies
      final turnDuration = _turnStartTime != null 
          ? DateTime.now().difference(_turnStartTime!)
          : null;
      
      // Create turn with depth mode metadata
      final turn = VoiceConversationTurn(
        userText: _currentTranscript,
        lumaraResponse: restoredResponse,
        timestamp: DateTime.now(),
        userSpeakingDuration: turnDuration,
        processingLatency: turnDuration,
        prismReversibleMap: prismResult.reversibleMap,
      );
      
      // Add to session
      _currentSession?.addTurn(turn);
      onTurnComplete?.call(turn);
      
      debugPrint('VoiceSession: Turn complete');
      _isProcessingTranscript = false;
      
    } catch (e) {
      debugPrint('VoiceSession: Error processing transcript: $e');
      onError?.call('Error processing: $e');
      _isProcessingTranscript = false;
      _updateState(VoiceSessionState.error);
    }
  }
  
  /// Handle TTS completion
  void _onTtsComplete() async {
    debugPrint('VoiceSession: TTS complete, ready for user to continue');
    // Go to idle state - user taps to continue conversation
    _updateState(VoiceSessionState.idle);
  }
  
  /// Handle TTS error
  void _onTtsError(String error) {
    debugPrint('VoiceSession: TTS error: $error');
    // Go to idle state anyway
    _updateState(VoiceSessionState.idle);
  }
  
  /// Start listening (for tap-to-toggle interaction)
  Future<void> startListening() async {
    if (_state != VoiceSessionState.idle) {
      debugPrint('VoiceSession: Cannot start listening - not idle (current: ${_state.name})');
      return;
    }
    
    // IMMEDIATE visual feedback
    _updateState(VoiceSessionState.listening);
    
    // If no session yet, start one
    if (_currentSession == null) {
      await startSession();
    } else {
      // Continue existing session with new turn
      await _startTurn();
    }
  }
  
  /// Handle transcription errors
  void _onTranscriptionError(String error) {
    debugPrint('VoiceSession: Transcription error: $error');
    onError?.call('Transcription error: $error');
  }
  
  /// Handle audio errors
  void _onAudioError(String error) {
    debugPrint('VoiceSession: Audio error: $error');
    onError?.call('Audio error: $error');
  }
  
  /// End session
  bool _isEndingSession = false;
  
  Future<VoiceSession?> endSession() async {
    // Guard against concurrent calls
    if (_isEndingSession) {
      debugPrint('VoiceSession: Already ending session, ignoring duplicate call');
      return null;
    }
    
    if (_currentSession == null) {
      debugPrint('VoiceSession: No active session to end');
      return null;
    }
    
    _isEndingSession = true;
    
    try {
      // Capture session reference before async operations
      final sessionBuilder = _currentSession;
      if (sessionBuilder == null) {
        debugPrint('VoiceSession: Session was null after guard check');
        return null;
      }
      
      // Clear session reference early to prevent double-ending
      _currentSession = null;
      _currentTranscript = '';
      
      // Stop everything
      await _audioCapture.stopRecording();
      _endpointDetector.stop();
      await _tts.stop();
      await _unifiedTranscription.disconnect();
      
      // Build final session
      final session = sessionBuilder.build(endTime: DateTime.now());
      
      debugPrint('VoiceSession: Session ended (${session.turnCount} turns, ${session.totalDuration.inSeconds}s)');
      
      onSessionComplete?.call(session);
      _updateState(VoiceSessionState.idle);
      
      return session;
      
    } catch (e) {
      debugPrint('VoiceSession: Error ending session: $e');
      onError?.call('Error ending session: $e');
      return null;
    } finally {
      _isEndingSession = false;
    }
  }
  
  /// Update state and notify
  void _updateState(VoiceSessionState newState) {
    if (_state == newState) return;
    
    _state = newState;
    onStateChanged?.call(newState);
    debugPrint('VoiceSession: State changed to ${newState.name}');
  }
  
  /// Dispose resources
  Future<void> dispose() async {
    await endSession();
    await _audioCapture.dispose();
    await _tts.dispose();
    _endpointDetector.dispose();
  }
}
