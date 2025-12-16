/// Unified Voice Service
/// 
/// A single voice service that handles both Journal and Chat modes.
/// The mode determines where data is saved, but the pipeline is identical:
/// 
/// 1. LISTENING: User speaks, live transcript displayed
/// 2. TRANSCRIBING: Finalize transcript
/// 3. SCRUBBING: PRISM PII scrubbing (local only)
/// 4. THINKING: Send scrubbed text to Gemini
/// 5. SPEAKING: TTS plays LUMARA response
/// 
/// Mode-specific behavior:
/// - JOURNAL: Saves to journal repository only
/// - CHAT: Saves to chat history only

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../../services/assemblyai_service.dart';
import '../../services/enhanced_lumara_api.dart';
import '../../../core/journal_capture_cubit.dart';
import '../../bloc/lumara_assistant_cubit.dart';
import 'voice_journal_state.dart';
import 'voice_mode.dart';
import 'assemblyai_stt.dart';
import 'prism_adapter.dart';
import 'gemini_client.dart';
import 'tts_client.dart';
import 'journal_store.dart';
import 'chat_store.dart';

/// Configuration for unified voice service
class UnifiedVoiceConfig {
  final SttConfig sttConfig;
  final TtsConfig ttsConfig;
  final bool enableLatencyTracking;
  final bool enableDebugLogs;
  final bool autoStartNextTurn;

  const UnifiedVoiceConfig({
    this.sttConfig = const SttConfig(),
    this.ttsConfig = const TtsConfig(),
    this.enableLatencyTracking = true,
    this.enableDebugLogs = true,
    this.autoStartNextTurn = true,
  });
}

/// Callback types
typedef OnVoiceStateChange = void Function(VoiceJournalState state);
typedef OnTranscriptUpdate = void Function(String transcript);
typedef OnLumaraResponse = void Function(String response);
typedef OnSessionComplete = void Function(String? entryId);
typedef OnVoiceError = void Function(String error);
typedef OnTranscriptsCollected = void Function(String transcriptText);

/// Unified Voice Service
/// 
/// Supports both Journal and Chat modes with the same pipeline.
class UnifiedVoiceService {
  final AssemblyAIService _assemblyAIService;
  final EnhancedLumaraApi _lumaraApi;
  final JournalCaptureCubit? _journalCubit;
  final LumaraAssistantCubit? _chatCubit;
  final UnifiedVoiceConfig _config;
  
  // Current mode
  VoiceMode _mode;
  VoiceMode get mode => _mode;
  
  // Components
  late AssemblyAISttService _stt;
  late PrismAdapter _prism;
  late GeminiJournalClient _gemini;
  late TtsJournalClient _tts;
  late VoiceJournalStore _journalStore;
  late VoiceChatStore _chatStore;
  
  // Conversation state
  VoiceJournalConversation? _conversation;
  
  // State
  final VoiceJournalStateNotifier _stateNotifier = VoiceJournalStateNotifier();
  final VoiceLatencyMetrics _metrics = VoiceLatencyMetrics();
  
  // Session tracking
  String? _currentSessionId;
  final List<VoiceJournalTurn> _journalTurns = [];
  final List<VoiceChatTurn> _chatTurns = [];
  DateTime? _sessionStart;
  
  // Callbacks
  OnVoiceStateChange? onStateChange;
  OnTranscriptUpdate? onTranscriptUpdate;
  OnLumaraResponse? onLumaraResponse;
  OnSessionComplete? onSessionComplete;
  OnVoiceError? onError;
  OnTranscriptsCollected? onTranscriptsCollected;
  
  // Audio level stream
  final StreamController<double> _audioLevelController = 
      StreamController<double>.broadcast();
  Stream<double> get audioLevelStream => _audioLevelController.stream;
  
  bool _isInitialized = false;

  UnifiedVoiceService({
    required AssemblyAIService assemblyAIService,
    required EnhancedLumaraApi lumaraApi,
    JournalCaptureCubit? journalCubit,
    LumaraAssistantCubit? chatCubit,
    VoiceMode initialMode = VoiceMode.journal,
    UnifiedVoiceConfig config = const UnifiedVoiceConfig(),
  })  : _assemblyAIService = assemblyAIService,
        _lumaraApi = lumaraApi,
        _journalCubit = journalCubit,
        _chatCubit = chatCubit,
        _mode = initialMode,
        _config = config {
    _stateNotifier.addListener(_onStateNotifierChange);
  }

  /// Get current state
  VoiceJournalState get state => _stateNotifier.state;
  VoiceJournalStateNotifier get stateNotifier => _stateNotifier;
  
  /// Get transcripts
  String get currentTranscript => _stateNotifier.partialTranscript.isNotEmpty 
      ? _stateNotifier.partialTranscript 
      : _stateNotifier.finalTranscript;
  String get lastLumaraResponse => _stateNotifier.lumaraReply;
  
  /// Get all transcripts formatted as text for journal entry
  /// Formats all journal turns into a single text string with user and LUMARA responses
  String getAllTranscriptsText() {
    if (_journalTurns.isEmpty) {
      return '';
    }
    
    final buffer = StringBuffer();
    for (final turn in _journalTurns) {
      buffer.writeln('**You:** ${turn.displayUserText}\n');
      if (turn.displayLumaraResponse.isNotEmpty) {
        buffer.writeln('**LUMARA:** ${turn.displayLumaraResponse}\n');
      }
    }
    return buffer.toString().trim();
  }
  
  /// Get metrics
  VoiceLatencyMetrics get metrics => _metrics;
  
  /// Check if initialized
  bool get isInitialized => _isInitialized;

  void _onStateNotifierChange() {
    onStateChange?.call(_stateNotifier.state);
  }

  /// Initialize the service
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      _log('Initializing Unified Voice Service (${_mode.displayName})...');
      
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
      
      // Initialize Gemini (with mode-specific prompt)
      _gemini = GeminiJournalClient(
        api: _lumaraApi,
        config: GeminiConfig(systemPrompt: _mode.systemPrompt),
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
      
      // Initialize stores
      _journalStore = VoiceJournalStore(captureCubit: _journalCubit);
      _chatStore = VoiceChatStore(chatCubit: _chatCubit);
      
      _isInitialized = true;
      _log('Unified Voice Service initialized');
      return true;
      
    } catch (e) {
      _handleError('Initialization failed: $e');
      return false;
    }
  }

  /// Switch voice mode
  /// 
  /// Can only switch when idle (no active session)
  bool switchMode(VoiceMode newMode) {
    if (state != VoiceJournalState.idle) {
      _log('Cannot switch mode during active session');
      return false;
    }
    
    if (_mode == newMode) return true;
    
    _mode = newMode;
    
    // Update Gemini with new system prompt
    _gemini = GeminiJournalClient(
      api: _lumaraApi,
      config: GeminiConfig(systemPrompt: _mode.systemPrompt),
      metrics: _metrics,
    );
    
    _conversation = VoiceJournalConversation(
      client: _gemini,
      prism: _prism,
    );
    
    _log('Switched to ${_mode.displayName}');
    return true;
  }

  /// Start a new session
  Future<void> startSession() async {
    if (!_isInitialized) {
      _handleError('Service not initialized');
      return;
    }
    
    // Reset state
    _stateNotifier.reset();
    _metrics.reset();
    _journalTurns.clear();
    _chatTurns.clear();
    _conversation?.clear();
    
    // Generate session ID
    _currentSessionId = const Uuid().v4();
    _sessionStart = DateTime.now();
    _metrics.sessionStart = _sessionStart;
    
    // Start mode-specific session
    if (_mode == VoiceMode.chat) {
      _chatStore.startSession();
    }
    
    _log('Started ${_mode.displayName} session: $_currentSessionId');
  }

  /// Start listening
  Future<void> startListening() async {
    if (state != VoiceJournalState.idle && 
        state != VoiceJournalState.speaking &&
        state != VoiceJournalState.saved) {
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

  /// Stop listening and process
  Future<void> endTurnAndProcess() async {
    if (state != VoiceJournalState.listening) {
      _log('Not in listening state');
      return;
    }
    
    if (!_stateNotifier.transitionTo(VoiceJournalState.transcribing)) {
      return;
    }
    
    final transcript = await _stt.endTurn();
    _stateNotifier.setFinalTranscript(transcript);
    onTranscriptUpdate?.call(transcript);
    
    if (transcript.trim().isEmpty) {
      _log('Empty transcript, returning to idle');
      _stateNotifier.transitionTo(VoiceJournalState.idle);
      return;
    }
    
    await _processTranscript(transcript);
  }

  /// Process transcript through pipeline
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
    
    final turnResult = await _conversation!.processTurn(
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
    
    // Store turn based on mode
    _storeTurn(rawTranscript, turnResult);
    
    // === SPEAKING ===
    if (!_stateNotifier.transitionTo(VoiceJournalState.speaking)) {
      return;
    }
    
    _log('Speaking response...');
    
    await _tts.speak(
      turnResult.displayResponse,
      onStart: () => _log('TTS started'),
      onComplete: () {
        _log('TTS complete');
        // Clear current transcript since it's now in conversation history
        _stateNotifier.clearCurrentTranscript();
        
        if (_config.autoStartNextTurn) {
          // Transition to idle first, then start listening
          if (_stateNotifier.transitionTo(VoiceJournalState.idle)) {
            // Small delay to ensure state transition completes
            Future.delayed(const Duration(milliseconds: 100), () {
              if (_stateNotifier.state == VoiceJournalState.idle) {
                startListening();
              }
            });
          }
        } else {
          _stateNotifier.transitionTo(VoiceJournalState.idle);
        }
      },
      onError: (error) => _handleError('TTS error: $error'),
    );
  }

  /// Store turn based on current mode
  void _storeTurn(String rawTranscript, VoiceJournalTurnResult turnResult) {
    if (_mode == VoiceMode.journal) {
      // Store for journal
      _journalTurns.add(VoiceJournalTurn(
        rawUserText: rawTranscript,
        scrubbedUserText: turnResult.scrubbedUserText,
        displayUserText: rawTranscript,
        lumaraResponse: turnResult.displayResponse,
        scrubbedLumaraResponse: turnResult.scrubbedResponse,
        displayLumaraResponse: turnResult.displayResponse,
        prismSummary: PrismRedactionSummary(
          totalRedactions: turnResult.prismResult.redactionCount,
          redactionTypes: turnResult.prismResult.findings,
          reversibleMap: turnResult.prismResult.reversibleMap,
        ),
      ));
    } else {
      // Store for chat
      final chatTurn = VoiceChatTurn(
        scrubbedUserText: turnResult.scrubbedUserText,
        displayUserText: rawTranscript,
        lumaraResponse: turnResult.displayResponse,
        timestamp: DateTime.now(),
      );
      _chatTurns.add(chatTurn);
      
      // Save incrementally to chat history
      _chatStore.saveTurn(chatTurn);
    }
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

  /// Save and end session
  Future<String?> saveAndEndSession() async {
    if (_currentSessionId == null) {
      _handleError('No active session');
      return null;
    }
    
    await _stt.stopListening();
    await _tts.stop();
    
    _metrics.sessionEnd = DateTime.now();
    
    String? entryId;
    
    try {
      if (_mode == VoiceMode.journal) {
        if (_journalTurns.isEmpty) {
          _log('No journal turns to collect');
        } else {
          // Collect transcripts instead of saving directly
          // User will edit and save through normal journal entry screen
          final transcriptText = getAllTranscriptsText();
          _log('Collected ${_journalTurns.length} journal turns for editing');
          
          // Call callback with formatted transcript text
          onTranscriptsCollected?.call(transcriptText);
          
          // Don't save directly - return null to indicate no entry was created
          entryId = null;
        }
      } else {
        // Chat is saved incrementally, just finalize
        final record = VoiceChatRecord(
          sessionId: _currentSessionId!,
          timestamp: _sessionStart ?? DateTime.now(),
          turns: _chatTurns,
          metrics: _config.enableLatencyTracking ? _metrics : null,
        );
        
        await _chatStore.saveSession(record);
        _log('Chat session finalized');
      }
      
      _stateNotifier.transitionTo(VoiceJournalState.saved);
      _log(_metrics.toString());
      
      onSessionComplete?.call(entryId);
      
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
    _journalTurns.clear();
    _chatTurns.clear();
    _conversation?.clear();
    _metrics.reset();
    
    if (_mode == VoiceMode.chat) {
      _chatStore.endSession();
    }
    
    _log('Session ended without saving');
  }

  void _handleError(String message) {
    _log('ERROR: $message');
    _stateNotifier.setError(message);
    onError?.call(message);
  }

  void _log(String message) {
    if (_config.enableDebugLogs) {
      debugPrint('UnifiedVoice[${_mode.name}]: $message');
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

