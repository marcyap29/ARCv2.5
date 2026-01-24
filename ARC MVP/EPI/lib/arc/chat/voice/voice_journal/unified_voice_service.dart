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
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../../services/assemblyai_service.dart';
import '../../../../services/firebase_auth_service.dart';
import '../../../../services/analytics_service.dart';
import '../../../../services/rivet_sweep_service.dart';
import '../../../../services/phase_regime_service.dart';
import '../../services/enhanced_lumara_api.dart';
import '../../services/lumara_reflection_settings_service.dart';
import '../../services/lumara_control_state_builder.dart';
import '../../../core/journal_capture_cubit.dart';
import '../../../core/journal_repository.dart';
import '../../bloc/lumara_assistant_cubit.dart';
import 'voice_journal_state.dart';
import 'voice_mode.dart';
import 'assemblyai_stt.dart';
import 'prism_adapter.dart';
import 'gemini_client.dart';
import 'tts_client.dart';
import 'journal_store.dart';
import 'chat_store.dart';
import 'voice_prompt_builder.dart';
import '../../../../services/pending_conversation_service.dart';

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
        mode: _mode,
        userId: _getUserId(),
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
      
      // Ensure LUMARA API is set on journal cubit for summary generation
      if (_journalCubit != null) {
        _journalCubit!.setLumaraApi(_lumaraApi);
        _log('Set LUMARA API on journal cubit for summary generation');
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
      mode: _mode,
      userId: _getUserId(),
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
    
    // Save pending input in case of interruption
    await _savePendingInput(rawTranscript);
    
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
    
    // Build voice context for unified prompt
    final voiceContext = await _buildVoiceContext();
    
    final turnResult = await _conversation!.processTurn(
      rawUserText: rawTranscript,
      voiceContext: voiceContext,
      onChunk: (chunk) {
        _stateNotifier.appendToLumaraReply(chunk);
      },
      onComplete: (response) {
        _stateNotifier.setLumaraReply(response);
        onLumaraResponse?.call(response);
        // Clear pending input when response completes successfully
        PendingConversationService.clearPendingInput();
      },
      onError: (error) {
        _handleError('Gemini error: $error');
        // Don't clear pending input on error - allow resubmission
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

  /// Save pending input for resubmission if conversation is interrupted
  Future<void> _savePendingInput(String rawTranscript) async {
    try {
      final voiceContext = await _buildVoiceContext();
      final pendingInput = PendingInput(
        userText: rawTranscript,
        mode: 'voice',
        timestamp: DateTime.now(),
        context: {
          'voiceMode': _mode == VoiceMode.journal ? 'journal' : 'chat',
          'prismActivity': voiceContext.prismActivity,
          'chronoContext': voiceContext.chronoContext,
          'memoryContext': voiceContext.memoryContext,
          'activeThreads': voiceContext.activeThreads,
          'daysInPhase': voiceContext.daysInPhase,
        },
        sessionId: _mode == VoiceMode.chat ? _chatStore.currentSessionId : null,
      );
      await PendingConversationService.savePendingInput(pendingInput);
    } catch (e) {
      _log('Error saving pending input: $e');
      // Don't fail the process if saving pending input fails
    }
  }

  /// Resubmit a pending input (called when user wants to retry after interruption)
  Future<void> resubmitPendingInput() async {
    final pendingInput = await PendingConversationService.getPendingInput();
    if (pendingInput == null || pendingInput.mode != 'voice') {
      _log('No pending voice input to resubmit');
      return;
    }

    _log('Resubmitting pending input: ${pendingInput.userText.substring(0, pendingInput.userText.length > 50 ? 50 : pendingInput.userText.length)}...');
    
    // Process the pending input as if it were just transcribed
    await _processTranscript(pendingInput.userText);
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
      
      // Generate session summary for memory system
      if ((_mode == VoiceMode.journal && _journalTurns.isNotEmpty) || 
          (_mode == VoiceMode.chat && _chatTurns.isNotEmpty)) {
        await _generateSessionSummary();
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

  /// Get user ID from available sources
  String? _getUserId() {
    try {
      final auth = FirebaseAuthService.instance.auth;
      return auth.currentUser?.uid;
    } catch (e) {
      _log('Error getting user ID: $e');
      return null;
    }
  }

  /// Retrieve memory context from past journal entries
  Future<String?> _retrieveMemoryContext(String? userId) async {
    if (userId == null) return null;
    
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      await settingsService.initialize();
      
      // Get user settings for memory retrieval
      final lookbackYears = await settingsService.getLookbackYears();
      final maxMatches = await settingsService.getMaxMatches();
      
      // Get current session text for context
      final currentText = _mode == VoiceMode.journal
          ? _journalTurns.map((t) => t.rawUserText).join(' ')
          : _chatTurns.map((t) => t.displayUserText).join(' ');
      
      if (currentText.isEmpty) return null;
      
      // Get journal entries from repository
      final journalRepository = JournalRepository();
      final allEntries = await journalRepository.getAllJournalEntries();
      
      // Filter by lookback period
      final cutoffDate = DateTime.now().subtract(Duration(days: (lookbackYears * 365).round()));
      final recentEntries = allEntries
          .where((e) => e.createdAt.isAfter(cutoffDate))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Newest first
      
      if (recentEntries.isEmpty) return null;
      
      // Take top entries (limit to maxMatches, but use top 5 for context)
      final topEntries = recentEntries.take(maxMatches.clamp(1, 10)).toList();
      
      // Format matches as memory context
      final buffer = StringBuffer();
      buffer.writeln('Relevant past entries:');
      for (final entry in topEntries.take(5)) {
        final excerpt = entry.content.length > 200 
            ? '${entry.content.substring(0, 200)}...' 
            : entry.content;
        buffer.writeln('- ${entry.createdAt.year}: $excerpt');
      }
      
      return buffer.toString();
    } catch (e) {
      _log('Error retrieving memory context: $e');
      return null;
    }
  }

  /// Retrieve active psychological threads from RIVET/ATLAS
  Future<List<String>?> _retrieveActiveThreads(String? userId) async {
    if (userId == null) return null;
    
    try {
      // Get recent RIVET events to identify active threads
      // This is a simplified implementation - can be enhanced with full RIVET integration
      final journalRepository = JournalRepository();
      final allEntries = await journalRepository.getAllJournalEntries();
      
      // Get entries from last 30 days to identify recent patterns
      final recentCutoff = DateTime.now().subtract(const Duration(days: 30));
      final recentEntries = allEntries
          .where((e) => e.createdAt.isAfter(recentCutoff))
          .toList();
      
      if (recentEntries.isEmpty) return null;
      
      // Extract keywords/phrases that appear frequently (simple pattern detection)
      // This is a placeholder - full implementation would use RIVET keyword tracking
      final threads = <String>[];
      
      // Look for common themes in recent entries (simplified)
      final commonWords = <String, int>{};
      for (final entry in recentEntries.take(10)) {
        final words = entry.content.toLowerCase().split(RegExp(r'\s+'));
        for (final word in words) {
          if (word.length > 4) { // Only consider words longer than 4 chars
            commonWords[word] = (commonWords[word] ?? 0) + 1;
          }
        }
      }
      
      // Get top 3 most common themes (simplified thread detection)
      final sortedWords = commonWords.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      for (final entry in sortedWords.take(3)) {
        if (entry.value >= 2) { // Appears at least twice
          threads.add('Theme: ${entry.key} (appears ${entry.value} times in recent entries)');
        }
      }
      
      return threads.isEmpty ? null : threads;
    } catch (e) {
      _log('Error retrieving active threads: $e');
      return null;
    }
  }

  /// Get days in current phase from PhaseRegimeService
  Future<int?> _getDaysInPhase() async {
    try {
      // Import and use PhaseRegimeService to get current phase regime
      // This requires importing the service
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();
      
      final phaseIndex = phaseRegimeService.phaseIndex;
      final currentRegime = phaseIndex.currentRegime;
      
      if (currentRegime != null) {
        final daysInPhase = DateTime.now().difference(currentRegime.start).inDays;
        return daysInPhase;
      }
      
      return null;
    } catch (e) {
      _log('Error getting days in phase: $e');
      return null;
    }
  }

  /// Generate session summary for memory system
  Future<void> _generateSessionSummary() async {
    try {
      // Get scrubbed transcript
      final scrubbedTranscript = _mode == VoiceMode.journal
          ? _journalTurns.map((t) => 'User: ${t.scrubbedUserText}\nLUMARA: ${t.scrubbedLumaraResponse}').join('\n\n')
          : _chatTurns.map((t) => 'User: ${t.scrubbedUserText}\nLUMARA: ${t.lumaraResponse}').join('\n\n');
      
      if (scrubbedTranscript.isEmpty) return;
      
      // Get current phase and context
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();
      
      final phaseIndex = phaseRegimeService.phaseIndex;
      final currentRegime = phaseIndex.currentRegime;
      final phase = currentRegime?.label.toString().split('.').last ?? 'Discovery';
      final phaseCapitalized = phase[0].toUpperCase() + phase.substring(1);
      final daysInPhase = currentRegime != null 
          ? DateTime.now().difference(currentRegime.start).inDays 
          : null;
      
      // Get control state to extract engagement mode and persona
      final userId = _getUserId();
      final voiceContext = await _buildVoiceContext();
      final controlStateJson = await LumaraControlStateBuilder.buildControlState(
        userId: userId,
        prismActivity: voiceContext.prismActivity,
        chronoContext: voiceContext.chronoContext,
      );
      final controlState = jsonDecode(controlStateJson) as Map<String, dynamic>;
      final engagement = controlState['engagement'] as Map<String, dynamic>? ?? {};
      final persona = controlState['persona'] as Map<String, dynamic>? ?? {};
      final sentinel = controlState['sentinel'] as Map<String, dynamic>? ?? {};
      
      final engagementMode = engagement['mode'] as String? ?? 'REFLECT';
      final selectedPersona = persona['selected'] as String? ?? 'companion';
      final emotionalDensity = sentinel['emotional_density'] as double?;
      
      // Build summary prompt
      final summaryPrompt = await VoicePromptBuilder.buildSummaryPrompt(
        scrubbedTranscript: scrubbedTranscript,
        phase: phaseCapitalized,
        daysInPhase: daysInPhase,
        emotionalDensity: emotionalDensity,
        engagementMode: engagementMode,
        persona: selectedPersona,
        memoryContext: voiceContext.memoryContext,
      );
      
      // Generate summary using LUMARA API
      final summaryResult = await _lumaraApi.generatePromptedReflection(
        entryText: scrubbedTranscript,
        intent: _mode == VoiceMode.journal ? 'voice_journal' : 'voice_chat',
        phase: null,
        userId: userId,
        chatContext: summaryPrompt,
        onProgress: (msg) {
          _log('Summary generation: $msg');
        },
      );
      
      final summary = summaryResult.reflection;
      _log('Generated session summary: ${summary.length} chars');
      
      // Store summary (can be added to journal entry metadata or stored separately)
      // For now, just log it - can be enhanced to store in entry metadata
      
    } catch (e) {
      _log('Error generating session summary: $e');
      // Don't fail the session save if summary generation fails
    }
  }

  /// Build voice context for unified prompt
  Future<VoicePromptContext> _buildVoiceContext() async {
    // Build PRISM activity from current session
    final prismActivity = <String, dynamic>{
      'journal_entries': _mode == VoiceMode.journal ? _journalTurns.map((t) => t.rawUserText).toList() : [],
      'chats': _mode == VoiceMode.chat ? _chatTurns.map((t) => t.displayUserText).toList() : [],
      'drafts': [],
      'media': [],
      'patterns': [],
      'emotional_tone': 'neutral',
      'cognitive_load': 'moderate',
    };

    // Build chrono context (time of day)
    final now = DateTime.now();
    final hour = now.hour;
    String timeWindow = 'afternoon';
    if (hour >= 5 && hour < 12) {
      timeWindow = 'morning';
    } else if (hour >= 12 && hour < 17) {
      timeWindow = 'afternoon';
    } else if (hour >= 17 && hour < 22) {
      timeWindow = 'evening';
    } else {
      timeWindow = 'night';
    }

    final chronoContext = <String, dynamic>{
      'window': timeWindow,
      'chronotype': 'sporadic',
      'rhythmScore': 0.7,
      'isFragmented': false,
    };

    // Get conversation history from conversation manager
    final conversationHistory = _conversation?.scrubbedHistory;

    // Retrieve memory context from memory system
    final memoryContext = await _retrieveMemoryContext(_getUserId());

    // Retrieve active psychological threads
    final activeThreads = await _retrieveActiveThreads(_getUserId());

    // Get days in phase from ATLAS
    final daysInPhase = await _getDaysInPhase();

    return VoicePromptContext(
      userId: _getUserId(),
      mode: _mode,
      prismActivity: prismActivity,
      chronoContext: chronoContext,
      conversationHistory: conversationHistory,
      memoryContext: memoryContext,
      activeThreads: activeThreads,
      daysInPhase: daysInPhase,
    );
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

