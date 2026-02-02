/// Voice Session Service
/// 
/// Orchestrates the complete voice conversation flow:
/// 1. Initialize transcription (Wispr optional, Apple On-Device default)
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
import '../prompts/voice_response_builders.dart'; // For VoiceResponseConfig only
import '../prompts/phase_voice_prompts.dart'; // Phase-specific voice prompts
import '../../services/enhanced_lumara_api.dart';
import '../../models/lumara_reflection_options.dart' as models;
import '../models/voice_session.dart';
import '../../../../models/phase_models.dart';
import '../../../../models/engagement_discipline.dart';
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

/// Processing choice for voice capture (save as note vs talk with LUMARA vs add to timeline vs cancel)
enum VoiceProcessingChoice {
  saveAsVoiceNote,
  talkWithLumara,
  addToTimeline,
  cancel,
}

/// Callback to request processing choice from UI (returns Future)
/// Called after transcription with the scrubbed text
/// UI shows modal and returns user's choice
typedef OnRequestProcessingChoice = Future<VoiceProcessingChoice> Function(String transcription);

/// Callback when user chooses to save as voice note
typedef OnSaveAsVoiceNote = Future<void> Function(String transcription);

/// Callback when user chooses to add transcription to the normal timeline (as journal entry)
typedef OnAddToTimeline = Future<void> Function(String transcription);

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
/// - Apple On-Device (default, always available, no network required)
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

  /// User-selected engagement mode override for voice (null = use classifier)
  EngagementMode? _engagementModeOverride;
  EngagementMode? get engagementModeOverride => _engagementModeOverride;
  void setEngagementModeOverride(EngagementMode? mode) {
    _engagementModeOverride = mode;
  }
  
  // Callbacks
  OnSessionStateChanged? onStateChanged;
  OnTranscriptUpdate? onTranscriptUpdate;
  OnLumaraResponse? onLumaraResponse;
  OnTurnComplete? onTurnComplete;
  OnSessionComplete? onSessionComplete;
  OnSessionError? onError;
  
  /// Callback for backend status messages
  Function(String message)? onBackendStatusMessage;
  
  /// Callback to request processing choice from UI (voice note vs LUMARA)
  /// If set, shows modal after transcription to let user choose
  /// If null, always continues to LUMARA (original behavior)
  OnRequestProcessingChoice? onRequestProcessingChoice;
  
  /// Callback when user chooses to save as voice note
  /// Called with the raw (unscrubbed) transcription for local storage
  OnSaveAsVoiceNote? onSaveAsVoiceNote;
  
  /// Callback when user chooses to add transcription to the normal timeline (journal entry)
  OnAddToTimeline? onAddToTimeline;
  
  // Public getter for endpoint detector (for UI tap handling)
  SmartEndpointDetector get endpointDetector => _endpointDetector;
  
  /// Whether currently using on-device (not Wispr)
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
  /// - Wispr Flow (if user has their own API key)
  /// - Apple On-Device (default, always available)
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
            
          case TranscriptionBackend.appleOnDevice:
            debugPrint('VoiceSession: Using Apple On-Device');
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
    _waitingForFinalTranscript = false; // Reset waiting flag
    
    debugPrint('VoiceSession: Starting new turn (session: ${_currentSession?.build().sessionId})');
    
    // Start transcription
    final started = await _unifiedTranscription.startListening();
    if (!started) {
      debugPrint('VoiceSession: Failed to start transcription, current state: ${_state.name}');
      onError?.call('Failed to start transcription');
      _updateState(VoiceSessionState.error);
      return;
    }
    
    // Start audio capture (only needed for some backends)
    await _audioCapture.startRecording();
    
    // Start endpoint detector
    _endpointDetector.start();
    
    _updateState(VoiceSessionState.listening);
    debugPrint('VoiceSession: Turn started successfully');
  }
  
  /// Handle audio chunks from microphone
  void _onAudioChunk(Uint8List audioData) {
    if (_state != VoiceSessionState.listening) return;
    
    // Notify endpoint detector of audio
    _endpointDetector.onAudioDetected();
    
    // Send audio to Wispr if using Wispr backend
    // (On-Device handles its own audio capture)
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
    
    // When using Wispr: allow a brief moment for any buffered audio to be sent
    // (recorder may emit in chunks; stopping too soon can yield 0 packets and empty transcript)
    if (_unifiedTranscription.activeBackend == TranscriptionBackend.wisprFlow) {
      await Future.delayed(const Duration(milliseconds: 400));
    }
    
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
    final isEmpty = _currentTranscript.trim().isEmpty;
    if (isEmpty) {
      debugPrint('VoiceSession: Empty transcript — still showing modal so user gets feedback');
    }
    
    _updateState(VoiceSessionState.processingTranscript);
    
    // =========================================================
    // PROGRESSIVE VOICE CAPTURE: Ask user what to do only on FIRST transcript
    // After user chooses "Talk with LUMARA", subsequent turns go straight to LUMARA
    // (no modal). Finish button saves the full conversation to the timeline.
    // =========================================================
    final isFirstTranscript = _currentSession == null || _currentSession!.build().turnCount == 0;
    VoiceProcessingChoice choice;
    if (onRequestProcessingChoice != null && isFirstTranscript) {
      try {
        debugPrint('VoiceSession: First transcript — requesting processing choice from UI');
        choice = await onRequestProcessingChoice!(_currentTranscript);
      } catch (e) {
        debugPrint('VoiceSession: Error getting processing choice: $e, defaulting to LUMARA');
        choice = VoiceProcessingChoice.talkWithLumara;
      }
    } else {
      // Already in conversation: skip modal, send straight to LUMARA
      choice = VoiceProcessingChoice.talkWithLumara;
      if (!isEmpty) {
        debugPrint('VoiceSession: Conversation turn ${_currentSession?.build().turnCount ?? 0} — sending to LUMARA (no modal)');
      }
    }

    if (choice == VoiceProcessingChoice.saveAsVoiceNote) {
          debugPrint('VoiceSession: User chose to save as voice note');
          
          // Save as voice note via callback (UI may skip if empty)
          if (onSaveAsVoiceNote != null) {
            await onSaveAsVoiceNote!(_currentTranscript);
          }
          
          // Reset state and exit voice mode
          _isProcessingTranscript = false;
          _currentTranscript = '';
          _updateState(VoiceSessionState.idle);
          return;
        }
        
        if (choice == VoiceProcessingChoice.addToTimeline) {
          debugPrint('VoiceSession: User chose to add to timeline');
          
          if (onAddToTimeline != null) {
            await onAddToTimeline!(_currentTranscript);
          }
          
          _isProcessingTranscript = false;
          _currentTranscript = '';
          _updateState(VoiceSessionState.idle);
          return;
        }
        
        if (choice == VoiceProcessingChoice.cancel) {
          debugPrint('VoiceSession: User cancelled (dismissed modal)');
          _isProcessingTranscript = false;
          _currentTranscript = '';
          _updateState(VoiceSessionState.idle);
          return;
        }
        
        // Talk with LUMARA chosen but no speech — don't send empty to LUMARA
        if (isEmpty) {
          debugPrint('VoiceSession: No speech detected, cannot start LUMARA conversation');
          onError?.call('No speech detected. Try speaking and then tapping the orb again.');
          _isProcessingTranscript = false;
          _updateState(VoiceSessionState.idle);
          return;
        }
        
        debugPrint('VoiceSession: User chose to talk with LUMARA, continuing...');
    
    // Empty transcript and no modal (or user chose LUMARA but we already handled empty above)
    if (isEmpty) {
      _isProcessingTranscript = false;
      _updateState(VoiceSessionState.idle);
      return;
    }
    
    try {
      // Scrub PII through PRISM
      _updateState(VoiceSessionState.scrubbing);
      final prismStart = DateTime.now();
      final prismResult = _prism.scrub(_currentTranscript);
      debugPrint('VoiceSession: PRISM took ${DateTime.now().difference(prismStart).inMilliseconds}ms, scrubbed ${prismResult.redactionCount} items');
      
      // =========================================================
      // VOICE ENGAGEMENT: Default = Reflect when not Explore/Integrate
      // Only Explore/Integrate when user explicitly chooses them in dropdown
      // =========================================================
      final depthResult = EntryClassifier.classifyVoiceDepth(prismResult.scrubbedText);
      final engagementMode = _engagementModeOverride ?? EngagementMode.reflect;
      
      // Classify what the user is seeking (validation, exploration, direction, reflection)
      final seekingResult = EntryClassifier.classifySeeking(prismResult.scrubbedText);
      
      debugPrint('VoiceSession: Engagement mode: ${engagementMode.name} '
          '(depth confidence: ${depthResult.confidence.toStringAsFixed(2)}, '
          'triggers: ${depthResult.triggers.join(", ")})');
      debugPrint('VoiceSession: Seeking classification: ${seekingResult.seeking.name} '
          '(confidence: ${seekingResult.confidence.toStringAsFixed(2)}, '
          'triggers: ${seekingResult.triggers.join(", ")})');
      
      // Send to LUMARA
      _updateState(VoiceSessionState.waitingForLumara);
      
      // Build conversation history for context
      final builtSession = _currentSession?.build();
      final conversationHistory = builtSession?.turns.map((turn) {
        return 'User: ${turn.userText}\nLUMARA: ${turn.lumaraResponse}';
      }).toList() ?? [];
      
      // Build voice-specific mode instructions using phase-specific prompts
      final voiceModeInstructions = _buildVoiceModeInstructions(
        engagementMode: engagementMode,
        currentPhase: _currentPhase,
        conversationHistory: conversationHistory,
        detectedTriggers: depthResult.triggers,
        seeking: seekingResult.seeking,
      );
      
      final modeName = engagementMode == EngagementMode.reflect ? 'REFLECT' :
                      engagementMode == EngagementMode.explore ? 'EXPLORE' : 'INTEGRATE';
      debugPrint('VoiceSession: Using $modeName mode with Master Unified Prompt (matches written mode)');
      debugPrint('VoiceSession: Max words: ${VoiceResponseConfig.getMaxWords(engagementMode)}');
      
      // Call LUMARA API - use trimmed voice prompt for ALL voice modes to avoid timeout
      // (Full master prompt ~150k+ chars causes proxyGemini/timeouts; voice prompt ~3–8k chars.)
      // Engagement mode (reflect/explore/integrate) is still passed in control state and instructions.
      // Client-side timeout (120s) so slow Firebase/Gemini responses (e.g. 90–100s) still succeed
      final apiStart = DateTime.now();
      ReflectionResult reflectionResult;
      try {
        reflectionResult = await _lumaraApi.generatePromptedReflection(
          entryText: prismResult.scrubbedText,
          intent: engagementMode == EngagementMode.reflect ? 'conversational' : 'reflective',
          phase: _currentPhase.name,
          userId: _userId,
          chatContext: voiceModeInstructions,
          skipHeavyProcessing: true, // Always use trimmed voice prompt in voice mode (all engagement modes)
          voiceEngagementModeOverride: engagementMode, // Dropdown choice for control state and prompt cap (6k/10k/13k)
          options: models.LumaraReflectionOptions(
            conversationMode: models.ConversationMode.continueThought,
            toneMode: models.ToneMode.normal,
          ),
        ).timeout(
          const Duration(seconds: 120),
          onTimeout: () => throw TimeoutException('LUMARA request timed out'),
        );
      } on TimeoutException {
        debugPrint('VoiceSession: LUMARA request timed out (120s)');
        onError?.call('Request timed out. Please try again.');
        _isProcessingTranscript = false;
        _updateState(VoiceSessionState.error);
        return;
      }
      
      final apiDuration = DateTime.now().difference(apiStart).inMilliseconds;
      final maxLatency = VoiceResponseConfig.getTargetLatencyMs(engagementMode);
      final hardLimit = VoiceResponseConfig.getHardLimitMs(engagementMode);
      
      debugPrint('VoiceSession: LUMARA API took ${apiDuration}ms '
          '(${engagementMode.name} mode, target: ${maxLatency}ms, hard limit: ${hardLimit}ms)');
      
      // Warn if latency exceeds target
      if (apiDuration > maxLatency) {
        debugPrint('VoiceSession: WARNING - Latency exceeded target! '
            '${apiDuration}ms > ${maxLatency}ms');
      }
      
      // Error if latency exceeds hard limit
      if (apiDuration > hardLimit) {
        debugPrint('VoiceSession: ERROR - Latency exceeded hard limit! '
            '${apiDuration}ms > ${hardLimit}ms');
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
    debugPrint('VoiceSession: Current session: ${_currentSession != null ? "exists" : "null"}, turn count: ${_currentSession?.build().turnCount ?? 0}');
    // Go to idle state - user taps to continue conversation
    _updateState(VoiceSessionState.idle);
    debugPrint('VoiceSession: State set to idle, ready for next turn');
  }
  
  /// Handle TTS error
  void _onTtsError(String error) {
    debugPrint('VoiceSession: TTS error: $error');
    // Go to idle state anyway
    _updateState(VoiceSessionState.idle);
  }
  
  /// Start listening (for tap-to-toggle interaction)
  Future<void> startListening() async {
    debugPrint('VoiceSession: startListening() called, current state: ${_state.name}');
    
    if (_state != VoiceSessionState.idle) {
      debugPrint('VoiceSession: Cannot start listening - not idle (current: ${_state.name})');
      // If we're in an error state or stuck, try to recover
      if (_state == VoiceSessionState.error || _state == VoiceSessionState.waitingForLumara) {
        debugPrint('VoiceSession: Attempting recovery from ${_state.name} state');
        _updateState(VoiceSessionState.idle);
        // Small delay to ensure state is updated
        await Future.delayed(const Duration(milliseconds: 100));
      } else {
      return;
      }
    }
    
    // IMMEDIATE visual feedback
    _updateState(VoiceSessionState.listening);
    
    // If no session yet, start one
    if (_currentSession == null) {
      debugPrint('VoiceSession: No session exists, starting new session');
      await startSession();
    } else {
      // Continue existing session with new turn
      debugPrint('VoiceSession: Continuing existing session (${_currentSession?.build().turnCount ?? 0} turns), starting new turn');
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
  
  /// Build voice-specific mode instructions for Master Unified Prompt
  /// Now uses phase-specific prompts with good/bad examples for better response quality
  String _buildVoiceModeInstructions({
    required EngagementMode engagementMode,
    required PhaseLabel currentPhase,
    required List<String> conversationHistory,
    List<String> detectedTriggers = const [],
    SeekingType seeking = SeekingType.exploration,
  }) {
    final buffer = StringBuffer();
    
    // Get phase-specific prompt with examples and tone guidance
    final phasePrompt = PhaseVoicePrompts.getPhasePrompt(
      phase: currentPhase.name,
      engagementMode: engagementMode,
      seeking: seeking,
      daysInPhase: null, // Could add if available
      emotionalDensity: null, // Could add from SENTINEL if available
    );
    
    buffer.writeln('═══════════════════════════════════════════════════════════');
    buffer.writeln('VOICE CONVERSATION MODE - PHASE-SPECIFIC INSTRUCTIONS');
    buffer.writeln('═══════════════════════════════════════════════════════════');
    buffer.writeln();
    buffer.writeln(phasePrompt);
    buffer.writeln();
    buffer.writeln('═══════════════════════════════════════════════════════════');
    buffer.writeln('CRITICAL CONTEXT RULES');
    buffer.writeln('═══════════════════════════════════════════════════════════');
    buffer.writeln();
    buffer.writeln('⚠️ THIS IS A REAL-TIME VOICE CONVERSATION, NOT A JOURNAL ENTRY ANALYSIS ⚠️');
    buffer.writeln();
    buffer.writeln('The user is speaking to you RIGHT NOW in a voice conversation.');
    buffer.writeln('Respond ONLY to what they just said in this conversation.');
    buffer.writeln();
    buffer.writeln('🚫 STRICT PROHIBITIONS (unless explicitly asked by the user):');
    buffer.writeln('- Do NOT reference historical journal entries unless directly relevant');
    buffer.writeln('- Do NOT reference scriptures, religious texts, or biblical figures');
    buffer.writeln('- Do NOT provide educational explanations unless the user explicitly asks');
    buffer.writeln();
    buffer.writeln('✅ STAY FOCUSED ON:');
    buffer.writeln('- The current conversation topic');
    buffer.writeln('- What the user just said in this turn');
    buffer.writeln('- Responding naturally and conversationally');
    buffer.writeln();
    
    if (conversationHistory.isNotEmpty) {
      // Cap to last 5 turns to keep voice prompt small and avoid timeout (~4 tokens per char)
      const int maxTurnsForContext = 5;
      final historyToInclude = conversationHistory.length > maxTurnsForContext
          ? conversationHistory.sublist(conversationHistory.length - maxTurnsForContext)
          : conversationHistory;
      buffer.writeln('═══════════════════════════════════════════════════════════');
      buffer.writeln('CONVERSATION HISTORY - CRITICAL FOR MULTI-TURN CONTEXT');
      buffer.writeln('(Last $maxTurnsForContext turns only to keep response fast.)');
      buffer.writeln('═══════════════════════════════════════════════════════════');
      buffer.writeln();
      buffer.writeln('The following is the conversation history up to this point:');
      buffer.writeln();
      buffer.writeln(historyToInclude.join('\n\n'));
      buffer.writeln();
      buffer.writeln('🚨 CRITICAL MULTI-TURN CONVERSATION RULES:');
      buffer.writeln();
      buffer.writeln('1. The current user input (in the "CURRENT TASK" section) is a CONTINUATION of the conversation above.');
      buffer.writeln('2. If you asked a question in the last turn, the current user input is ANSWERING that question.');
      buffer.writeln('3. If you requested information in the last turn, the current user input is PROVIDING that information.');
      buffer.writeln('4. DO NOT repeat questions you already asked - the user has answered them.');
      buffer.writeln('5. DO NOT ask for information you already requested - the user has provided it.');
      buffer.writeln('6. USE the information the user just provided to fulfill their original request.');
      buffer.writeln();
      buffer.writeln('Example scenario:');
      buffer.writeln('- Turn 1: User asks "Can you find scriptures about hope?"');
      buffer.writeln('- Turn 2: LUMARA asks "What themes or feelings do you want the verses to address?"');
      buffer.writeln('- Turn 3 (CURRENT): User says "I want verses about hope and strength"');
      buffer.writeln('→ CORRECT: Provide scriptures about hope and strength (fulfill the original request)');
      buffer.writeln('→ WRONG: Ask "What themes or feelings do you want the verses to address?" again (you already asked, they answered)');
      buffer.writeln();
      buffer.writeln('When the user provides information you requested, immediately use it to complete their original request.');
      buffer.writeln('Do not ask for clarification unless the information is genuinely unclear or incomplete.');
      buffer.writeln();
    }
    
    return buffer.toString();
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
