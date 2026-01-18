/// Voice Session Service
/// 
/// Orchestrates the complete voice conversation flow:
/// 1. Initialize Wispr connection
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
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../wispr/wispr_flow_service.dart';
import '../wispr/wispr_rate_limiter.dart';
import '../audio/audio_capture_service.dart';
import '../endpoint/smart_endpoint_detector.dart';
import '../../../internal/echo/prism_adapter.dart';
import '../voice_journal/tts_client.dart';
import '../../services/enhanced_lumara_api.dart';
import '../../models/lumara_reflection_options.dart' as models;
import '../models/voice_session.dart';
import '../../../../models/phase_models.dart';

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

/// Voice Session Service
/// 
/// Main orchestrator for voice conversations with LUMARA
class VoiceSessionService {
  final WisprFlowService _wisprService;
  final WisprRateLimiter _rateLimiter;
  final AudioCaptureService _audioCapture;
  final SmartEndpointDetector _endpointDetector;
  final PrismAdapter _prism;
  final TtsJournalClient _tts;
  final EnhancedLumaraApi _lumaraApi;
  final String _userId;
  
  VoiceSessionState _state = VoiceSessionState.idle;
  VoiceSessionBuilder? _currentSession;
  PhaseLabel _currentPhase = PhaseLabel.discovery;
  
  String _currentTranscript = '';
  DateTime? _turnStartTime;
  
  // Callbacks
  OnSessionStateChanged? onStateChanged;
  OnTranscriptUpdate? onTranscriptUpdate;
  OnLumaraResponse? onLumaraResponse;
  OnTurnComplete? onTurnComplete;
  OnSessionComplete? onSessionComplete;
  OnSessionError? onError;
  
  // Public getter for endpoint detector (for UI tap handling)
  SmartEndpointDetector get endpointDetector => _endpointDetector;
  
  VoiceSessionService({
    required WisprFlowService wisprService,
    required WisprRateLimiter rateLimiter,
    required AudioCaptureService audioCapture,
    required SmartEndpointDetector endpointDetector,
    required PrismAdapter prism,
    required TtsJournalClient tts,
    required EnhancedLumaraApi lumaraApi,
    required String userId,
  })  : _wisprService = wisprService,
        _rateLimiter = rateLimiter,
        _audioCapture = audioCapture,
        _endpointDetector = endpointDetector,
        _prism = prism,
        _tts = tts,
        _lumaraApi = lumaraApi,
        _userId = userId {
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
    // Wispr callbacks
    _wisprService.onConnected = _onWisprConnected;
    _wisprService.onTranscript = _onWisprTranscript;
    _wisprService.onError = _onWisprError;
    _wisprService.onDisconnected = _onWisprDisconnected;
    
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
  
  /// Initialize session
  Future<bool> initialize() async {
    _updateState(VoiceSessionState.initializing);
    
    try {
      // Check rate limits
      final limitCheck = await _rateLimiter.checkLimit();
      if (limitCheck != RateLimitResult.allowed && limitCheck != RateLimitResult.approachingLimit) {
        final stats = await _rateLimiter.getUsageStats();
        final message = _rateLimiter.getWarningMessage(stats);
        onError?.call(message);
        _updateState(VoiceSessionState.error);
        return false;
      }
      
      // Warn if approaching limit
      if (limitCheck == RateLimitResult.approachingLimit) {
        final stats = await _rateLimiter.getUsageStats();
        final message = _rateLimiter.getWarningMessage(stats);
        debugPrint('VoiceSession: $message');
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
      
      // Connect to Wispr
      final wisprConnected = await _wisprService.connect();
      if (!wisprConnected) {
        onError?.call('Failed to connect to transcription service');
        _updateState(VoiceSessionState.error);
        return false;
      }
      
      debugPrint('VoiceSession: Initialized successfully');
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
    if (_state != VoiceSessionState.idle) {
      debugPrint('VoiceSession: Cannot start - not idle (current state: ${_state.name})');
      return;
    }
    
    try {
      // Create new session
      _currentSession = VoiceSessionBuilder()
        ..setSessionId(const Uuid().v4())
        ..setStartTime(DateTime.now())
        ..setPhase(_currentPhase);
      
      debugPrint('VoiceSession: Session started');
      
      // Start rate limiting tracking
      _rateLimiter.startSession();
      
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
    
    // Start Wispr session
    await _wisprService.startSession();
    
    // Start audio capture
    await _audioCapture.startRecording();
    
    // Start endpoint detector
    _endpointDetector.start();
    
    _updateState(VoiceSessionState.listening);
    debugPrint('VoiceSession: Turn started');
  }
  
  /// Handle audio chunks from microphone
  void _onAudioChunk(Uint8List audioData) {
    if (_state != VoiceSessionState.listening) return;
    
    // Send audio to Wispr
    _wisprService.sendAudio(audioData);
    
    // Notify endpoint detector of audio
    _endpointDetector.onAudioDetected();
  }
  
  /// Handle audio level updates
  void _onAudioLevel(AudioLevel level) {
    // Audio level can be used for visualization
    // Passed through to UI via state updates
  }
  
  /// Handle Wispr connection
  void _onWisprConnected() {
    debugPrint('VoiceSession: Wispr connected');
  }
  
  /// Handle transcripts from Wispr
  void _onWisprTranscript(WisprTranscript transcript) {
    if (_state != VoiceSessionState.listening) return;
    
    // Update current transcript
    _currentTranscript = transcript.text;
    
    // Notify UI
    onTranscriptUpdate?.call(transcript.text);
    
    // Update endpoint detector
    _endpointDetector.onTranscriptUpdate(transcript.text);
    
    // If final transcript, commit Wispr session
    if (transcript.isFinal) {
      _wisprService.commitSession();
    }
  }
  
  /// Handle endpoint detection
  void _onEndpointDetected() async {
    debugPrint('VoiceSession: Endpoint detected');
    
    // Stop audio capture
    await _audioCapture.stopRecording();
    
    // Stop endpoint detector
    _endpointDetector.stop();
    
    // Commit Wispr session if not already committed
    await _wisprService.commitSession();
    
    // Process the transcript
    await _processTranscript();
  }
  
  /// Handle endpoint state changes
  void _onEndpointStateChanged(EndpointState endpointState) {
    // Endpoint state changes can be used for UI updates
    // (commitment ring visualization)
  }
  
  /// Process transcript through PRISM and send to LUMARA
  Future<void> _processTranscript() async {
    if (_currentTranscript.trim().isEmpty) {
      debugPrint('VoiceSession: Empty transcript, skipping');
      await _startTurn(); // Start new turn
      return;
    }
    
    _updateState(VoiceSessionState.processingTranscript);
    
    try {
      // Scrub PII through PRISM
      _updateState(VoiceSessionState.scrubbing);
      final prismResult = _prism.scrub(_currentTranscript);
      
      debugPrint('VoiceSession: PRISM scrubbed ${prismResult.redactionCount} PII items');
      
      // Send to LUMARA
      _updateState(VoiceSessionState.waitingForLumara);
      
      // Build context for LUMARA
      final builtSession = _currentSession?.build();
      final conversationHistory = builtSession?.turns.map((turn) {
        return {
          'role': 'user',
          'content': turn.userText,
        };
      }).toList() ?? [];
      
      // Call LUMARA API for voice conversation
      final reflectionResult = await _lumaraApi.generatePromptedReflection(
        entryText: prismResult.scrubbedText,
        intent: 'voice',
        phase: _currentPhase.name,
        userId: _userId,
        chatContext: conversationHistory.isNotEmpty 
            ? conversationHistory.map((msg) => '${msg['role']}: ${msg['content']}').join('\n')
            : null,
        options: models.LumaraReflectionOptions(
          conversationMode: models.ConversationMode.think, // Use 'think' mode for voice conversations
          toneMode: models.ToneMode.normal, // Use 'normal' tone (or 'soft' for gentler)
        ),
      );
      
      final response = reflectionResult.reflection;
      
      // Restore PII in response for TTS
      final restoredResponse = _prism.restore(response, prismResult.reversibleMap);
      
      debugPrint('VoiceSession: LUMARA response received');
      onLumaraResponse?.call(restoredResponse);
      
      // Play TTS
      await _tts.speak(restoredResponse);
      
      // Calculate latencies
      final turnDuration = _turnStartTime != null 
          ? DateTime.now().difference(_turnStartTime!)
          : null;
      
      // Create turn
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
      
    } catch (e) {
      debugPrint('VoiceSession: Error processing transcript: $e');
      onError?.call('Error processing: $e');
      _updateState(VoiceSessionState.error);
    }
  }
  
  /// Handle TTS completion
  void _onTtsComplete() async {
    debugPrint('VoiceSession: TTS complete, starting new turn');
    // Automatically start next turn
    await _startTurn();
  }
  
  /// Handle TTS error
  void _onTtsError(String error) {
    debugPrint('VoiceSession: TTS error: $error');
    // Continue anyway - start new turn
    _startTurn();
  }
  
  /// Handle Wispr errors
  void _onWisprError(String error) {
    debugPrint('VoiceSession: Wispr error: $error');
    onError?.call('Transcription error: $error');
  }
  
  /// Handle Wispr disconnection
  void _onWisprDisconnected() {
    debugPrint('VoiceSession: Wispr disconnected');
  }
  
  /// Handle audio errors
  void _onAudioError(String error) {
    debugPrint('VoiceSession: Audio error: $error');
    onError?.call('Audio error: $error');
  }
  
  /// End session
  Future<VoiceSession?> endSession() async {
    if (_currentSession == null) {
      debugPrint('VoiceSession: No active session to end');
      return null;
    }
    
    try {
      // Stop everything
      await _audioCapture.stopRecording();
      _endpointDetector.stop();
      await _tts.stop();
      
      // End rate limiting tracking
      await _rateLimiter.endSession();
      
      // Build final session
      final session = _currentSession!.build(endTime: DateTime.now());
      
      debugPrint('VoiceSession: Session ended (${session.turnCount} turns, ${session.totalDuration.inSeconds}s)');
      
      onSessionComplete?.call(session);
      
      _currentSession = null;
      _currentTranscript = '';
      _updateState(VoiceSessionState.idle);
      
      return session;
      
    } catch (e) {
      debugPrint('VoiceSession: Error ending session: $e');
      onError?.call('Error ending session: $e');
      return null;
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
    await _wisprService.dispose();
    await _audioCapture.dispose();
    await _tts.dispose();
    _endpointDetector.dispose();
  }
}
