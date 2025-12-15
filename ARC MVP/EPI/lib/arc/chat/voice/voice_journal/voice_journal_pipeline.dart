/// Voice Journal Pipeline - Main Orchestrator
/// 
/// Orchestrates the complete voice journaling flow:
/// 1. LISTENING: User speaks, live transcript displayed
/// 2. TRANSCRIBING: Finalize transcript
/// 3. SCRUBBING: PRISM PII scrubbing (local only)
/// 4. THINKING: Send scrubbed text to Gemini
/// 5. SPEAKING: TTS plays LUMARA response
/// 6. SAVED: Journal entry stored
/// 
/// CRITICAL SECURITY REQUIREMENTS:
/// - Raw transcript NEVER leaves device
/// - Only scrubbed text goes to Gemini
/// - PRISM reversible map stays local
/// - No raw text in logs

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../../services/assemblyai_service.dart';
import '../../services/enhanced_lumara_api.dart';
import '../../../core/journal_capture_cubit.dart';
import 'voice_journal_state.dart';
import 'assemblyai_stt.dart';
import 'prism_adapter.dart';
import 'gemini_client.dart';
import 'tts_client.dart';
import 'journal_store.dart';

/// Configuration for voice journal pipeline
class VoiceJournalConfig {
  final SttConfig sttConfig;
  final GeminiConfig geminiConfig;
  final TtsConfig ttsConfig;
  final bool enableLatencyTracking;
  final bool enableDebugLogs;

  const VoiceJournalConfig({
    this.sttConfig = const SttConfig(),
    this.geminiConfig = const GeminiConfig(),
    this.ttsConfig = const TtsConfig(),
    this.enableLatencyTracking = true,
    this.enableDebugLogs = true,
  });
}

/// Callback types for pipeline events
typedef OnStateChange = void Function(VoiceJournalState state);
typedef OnTranscriptUpdate = void Function(String transcript);
typedef OnLumaraResponse = void Function(String response);
typedef OnSessionSaved = void Function(String entryId);
typedef OnPipelineError = void Function(String error);

/// Voice Journal Pipeline - Main Entry Point
/// 
/// Usage:
/// ```dart
/// final pipeline = VoiceJournalPipeline(
///   assemblyAIService: assemblyAIService,
///   lumaraApi: lumaraApi,
///   journalCubit: journalCubit,
/// );
/// 
/// await pipeline.initialize();
/// await pipeline.startSession();
/// // ... user speaks ...
/// await pipeline.endTurn();  // Triggers PRISM -> Gemini -> TTS
/// // ... LUMARA responds ...
/// await pipeline.saveAndEndSession();
/// ```
class VoiceJournalPipeline {
  final AssemblyAIService _assemblyAIService;
  final EnhancedLumaraApi _lumaraApi;
  final JournalCaptureCubit? _journalCubit;
  final VoiceJournalConfig _config;
  
  // Components
  late AssemblyAISttService _stt;
  late PrismAdapter _prism;
  late GeminiJournalClient _gemini;
  late VoiceJournalConversation _conversation;
  late TtsJournalClient _tts;
  late VoiceJournalStore _store;
  
  // State
  final VoiceJournalStateNotifier _stateNotifier = VoiceJournalStateNotifier();
  final VoiceLatencyMetrics _metrics = VoiceLatencyMetrics();
  
  // Session tracking
  String? _currentSessionId;
  final List<VoiceJournalTurn> _turns = [];
  
  // Callbacks
  OnStateChange? onStateChange;
  OnTranscriptUpdate? onTranscriptUpdate;
  OnLumaraResponse? onLumaraResponse;
  OnSessionSaved? onSessionSaved;
  OnPipelineError? onError;
  
  // Audio level stream for UI
  final StreamController<double> _audioLevelController = 
      StreamController<double>.broadcast();
  Stream<double> get audioLevelStream => _audioLevelController.stream;
  
  bool _isInitialized = false;

  VoiceJournalPipeline({
    required AssemblyAIService assemblyAIService,
    required EnhancedLumaraApi lumaraApi,
    JournalCaptureCubit? journalCubit,
    VoiceJournalConfig config = const VoiceJournalConfig(),
  })  : _assemblyAIService = assemblyAIService,
        _lumaraApi = lumaraApi,
        _journalCubit = journalCubit,
        _config = config {
    // Listen to state changes
    _stateNotifier.addListener(_onStateNotifierChange);
  }

  /// Get current state
  VoiceJournalState get state => _stateNotifier.state;
  
  /// Get state notifier for UI binding
  VoiceJournalStateNotifier get stateNotifier => _stateNotifier;
  
  /// Get current transcript
  String get currentTranscript => _stateNotifier.partialTranscript.isNotEmpty 
      ? _stateNotifier.partialTranscript 
      : _stateNotifier.finalTranscript;
  
  /// Get LUMARA's last response
  String get lastLumaraResponse => _stateNotifier.lumaraReply;
  
  /// Get latency metrics
  VoiceLatencyMetrics get metrics => _metrics;

  void _onStateNotifierChange() {
    onStateChange?.call(_stateNotifier.state);
  }

  /// Initialize the pipeline
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      _log('Initializing Voice Journal Pipeline...');
      
      // Initialize STT
      _stt = AssemblyAISttService(
        assemblyAIService: _assemblyAIService,
        config: _config.sttConfig,
        metrics: _metrics,
      );
      if (!await _stt.initialize()) {
        _handleError('Failed to initialize speech-to-text');
        return false;
      }
      
      // Initialize PRISM
      _prism = PrismAdapter();
      
      // Initialize Gemini client
      _gemini = GeminiJournalClient(
        api: _lumaraApi,
        config: _config.geminiConfig,
        metrics: _metrics,
      );
      
      // Initialize conversation manager
      _conversation = VoiceJournalConversation(
        client: _gemini,
        prism: _prism,
      );
      
      // Initialize TTS
      _tts = TtsJournalClient(
        config: _config.ttsConfig,
        metrics: _metrics,
      );
      if (!await _tts.initialize()) {
        _handleError('Failed to initialize text-to-speech');
        return false;
      }
      
      // Initialize journal store
      _store = VoiceJournalStore(captureCubit: _journalCubit);
      
      _isInitialized = true;
      _log('Voice Journal Pipeline initialized');
      return true;
      
    } catch (e) {
      _handleError('Initialization failed: $e');
      return false;
    }
  }

  /// Start a new voice journal session
  Future<void> startSession() async {
    if (!_isInitialized) {
      _handleError('Pipeline not initialized');
      return;
    }
    
    // Reset state
    _stateNotifier.reset();
    _metrics.reset();
    _turns.clear();
    _conversation.clear();
    
    // Generate session ID
    _currentSessionId = const Uuid().v4();
    _metrics.sessionStart = DateTime.now();
    
    _log('Started session: $_currentSessionId');
  }

  /// Start listening for speech
  Future<void> startListening() async {
    if (state != VoiceJournalState.idle && 
        state != VoiceJournalState.speaking) {
      _log('Cannot start listening in state: $state');
      return;
    }
    
    if (!_stateNotifier.transitionTo(VoiceJournalState.listening)) {
      return;
    }
    
    await _stt.startListening(
      onPartial: (text) {
        _stateNotifier.updatePartialTranscript(text);
        onTranscriptUpdate?.call(text);
      },
      onFinal: (text) {
        _stateNotifier.setFinalTranscript(text);
        onTranscriptUpdate?.call(text);
      },
      onTurnEnd: (fullTranscript) {
        // Auto-trigger processing if configured
        if (_config.sttConfig.autoEndTurn) {
          _processTranscript(fullTranscript);
        }
      },
      onError: (error) {
        _handleError('STT error: $error');
      },
      onAudioLevel: (level) {
        _audioLevelController.add(level);
      },
    );
  }

  /// Stop listening and process the transcript
  /// 
  /// This triggers the full pipeline:
  /// TRANSCRIBING -> SCRUBBING -> THINKING -> SPEAKING
  Future<void> endTurnAndProcess() async {
    if (state != VoiceJournalState.listening) {
      _log('Not in listening state');
      return;
    }
    
    // Transition to transcribing
    if (!_stateNotifier.transitionTo(VoiceJournalState.transcribing)) {
      return;
    }
    
    // Get final transcript
    final transcript = await _stt.endTurn();
    _stateNotifier.setFinalTranscript(transcript);
    onTranscriptUpdate?.call(transcript);
    
    if (transcript.trim().isEmpty) {
      _log('Empty transcript, returning to idle');
      _stateNotifier.transitionTo(VoiceJournalState.idle);
      return;
    }
    
    // Process the transcript through PRISM -> Gemini -> TTS
    await _processTranscript(transcript);
  }

  /// Process transcript through the pipeline
  Future<void> _processTranscript(String rawTranscript) async {
    _metrics.turnEndDetected = DateTime.now();
    
    // === SCRUBBING ===
    if (!_stateNotifier.transitionTo(VoiceJournalState.scrubbing)) {
      return;
    }
    
    _metrics.scrubStart = DateTime.now();
    _log('Scrubbing PII...');
    
    final scrubResult = _prism.scrub(rawTranscript);
    _stateNotifier.setScrubbedTranscript(scrubResult.scrubbedText);
    
    _metrics.scrubEnd = DateTime.now();
    _log('PRISM: ${scrubResult.redactionCount} redactions');
    
    // SECURITY: Validate before proceeding
    if (!_prism.isSafeToSend(scrubResult.scrubbedText)) {
      _handleError('SECURITY: Scrubbing failed - PII still detected');
      return;
    }
    
    // === THINKING ===
    if (!_stateNotifier.transitionTo(VoiceJournalState.thinking)) {
      return;
    }
    
    _log('Sending to Gemini...');
    
    // Process through conversation manager (handles scrub/restore)
    final turnResult = await _conversation.processTurn(
      rawUserText: rawTranscript,
      onChunk: (chunk) {
        _stateNotifier.appendToLumaraReply(chunk);
      },
      onComplete: (response) {
        _stateNotifier.setLumaraReply(response);
        onLumaraResponse?.call(response);
      },
      onError: (error) {
        _handleError('Gemini error: $error');
      },
    );
    
    // Store turn for session record
    _turns.add(VoiceJournalTurn(
      rawUserText: rawTranscript,
      scrubbedUserText: turnResult.scrubbedUserText,
      displayUserText: rawTranscript,  // Display raw for user
      lumaraResponse: turnResult.displayResponse,
      scrubbedLumaraResponse: turnResult.scrubbedResponse,
      displayLumaraResponse: turnResult.displayResponse,
      prismSummary: PrismRedactionSummary(
        totalRedactions: turnResult.prismResult.redactionCount,
        redactionTypes: turnResult.prismResult.findings,
        reversibleMap: turnResult.prismResult.reversibleMap,
      ),
    ));
    
    // === SPEAKING ===
    if (!_stateNotifier.transitionTo(VoiceJournalState.speaking)) {
      return;
    }
    
    _log('Speaking response...');
    
    await _tts.speak(
      turnResult.displayResponse,
      onStart: () {
        _log('TTS started');
      },
      onComplete: () {
        _log('TTS complete');
        // After speaking, go back to listening state for next turn
        // (or idle if user should explicitly start next turn)
        _stateNotifier.transitionTo(VoiceJournalState.listening);
        // Auto-start listening for next turn
        startListening();
      },
      onError: (error) {
        _handleError('TTS error: $error');
      },
    );
  }

  /// Stop listening without processing
  Future<void> stopListening() async {
    await _stt.stopListening();
    _stateNotifier.transitionTo(VoiceJournalState.idle);
  }

  /// Cancel current operation
  Future<void> cancel() async {
    await _stt.cancelListening();
    await _tts.stop();
    _stateNotifier.reset();
  }

  /// Save session and end
  Future<String?> saveAndEndSession() async {
    if (_currentSessionId == null) {
      _handleError('No active session');
      return null;
    }
    
    if (_turns.isEmpty) {
      _log('No turns to save');
      return null;
    }
    
    // Stop any ongoing operations
    await _stt.stopListening();
    await _tts.stop();
    
    _metrics.sessionEnd = DateTime.now();
    
    // Create session record
    final record = VoiceJournalRecord(
      sessionId: _currentSessionId!,
      timestamp: DateTime.now(),
      turns: _turns,
      metrics: _config.enableLatencyTracking ? _metrics : null,
    );
    
    try {
      final entryId = await _store.saveSession(record);
      
      if (!_stateNotifier.transitionTo(VoiceJournalState.saved)) {
        // Still report success even if state transition fails
      }
      
      _log('Session saved: $entryId');
      _log(_metrics.toString());
      
      onSessionSaved?.call(entryId);
      
      // Clean up
      _currentSessionId = null;
      
      return entryId;
      
    } catch (e) {
      _handleError('Failed to save session: $e');
      return null;
    }
  }

  /// End session without saving
  Future<void> endSession() async {
    await _stt.stopListening();
    await _tts.stop();
    
    _stateNotifier.reset();
    _currentSessionId = null;
    _turns.clear();
    _conversation.clear();
    _metrics.reset();
    
    _log('Session ended without saving');
  }

  void _handleError(String message) {
    _log('ERROR: $message');
    _stateNotifier.setError(message);
    onError?.call(message);
  }

  void _log(String message) {
    if (_config.enableDebugLogs) {
      debugPrint('VoiceJournal: $message');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _stt.dispose();
    await _tts.dispose();
    _audioLevelController.close();
    _stateNotifier.removeListener(_onStateNotifierChange);
    _stateNotifier.dispose();
  }
}

