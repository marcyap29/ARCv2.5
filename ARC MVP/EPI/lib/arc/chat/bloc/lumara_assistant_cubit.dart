import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/arc/chat/data/context_scope.dart';
import 'package:my_app/arc/chat/data/context_provider.dart';
import 'package:my_app/arc/chat/data/models/lumara_message.dart';
import 'package:my_app/arc/chat/llm/llm_adapter.dart';
import 'package:my_app/arc/chat/llm/rule_based_adapter.dart'; // For InsightKind enum
import 'package:my_app/services/gemini_send.dart';
import 'package:my_app/services/llm_bridge_adapter.dart';
import '../services/enhanced_lumara_api.dart';
import '../services/progressive_memory_loader.dart';
import '../config/api_config.dart';
import 'package:my_app/mira/memory/enhanced_mira_memory_service.dart';
import 'package:my_app/mira/memory/enhanced_memory_schema.dart';
import 'package:my_app/mira/memory/sentence_extraction_util.dart';
import 'package:my_app/mira/memory/attribution_service.dart';
import 'package:my_app/mira/mira_service.dart';
import 'package:my_app/telemetry/analytics.dart';
import '../chat/chat_repo.dart';
import '../chat/chat_repo_impl.dart';
import '../chat/chat_models.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import '../services/lumara_reflection_settings_service.dart';
import 'package:my_app/models/journal_entry_model.dart';
import '../../../services/pending_conversation_service.dart';
import 'package:my_app/shared/ui/settings/voiceover_preference_service.dart';
import '../voice/audio_io.dart';
import '../llm/prompts/lumara_master_prompt.dart';
import '../services/lumara_control_state_builder.dart';
import '../services/reflective_query_service.dart';
import '../services/reflective_query_formatter.dart';
import '../services/bible_retrieval_helper.dart';
import 'package:my_app/prism/atlas/phase/phase_history_repository.dart';
import 'package:my_app/aurora/services/circadian_profile_service.dart';
import 'package:my_app/services/sentinel/sentinel_analyzer.dart';
import 'package:my_app/services/sentinel/crisis_mode.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/arc/chat/models/lumara_reflection_options.dart' as models;
import '../services/reflection_handler.dart';
import '../services/chat_phase_service.dart';
import 'package:my_app/repositories/reflection_session_repository.dart';
import 'package:my_app/aurora/reflection/aurora_reflection_service.dart';
import 'package:my_app/arc/chat/reflection/reflection_pattern_analyzer.dart';
import 'package:my_app/arc/chat/reflection/reflection_emotional_analyzer.dart';
import 'package:my_app/services/adaptive/adaptive_sentinel_calculator.dart';
import 'package:my_app/services/sentinel/sentinel_config.dart';
import 'package:hive/hive.dart';
import 'package:my_app/models/reflection_session.dart';

/// LUMARA Assistant Cubit State
abstract class LumaraAssistantState {}

class LumaraAssistantInitial extends LumaraAssistantState {}

class LumaraAssistantLoading extends LumaraAssistantState {}

class LumaraAssistantLoaded extends LumaraAssistantState {
  final List<LumaraMessage> messages;
  final LumaraScope scope;
  final bool isProcessing;
  final String? currentSessionId;
  final String? apiErrorMessage; // Message to show in snackbar after retries fail
  final String? notice; // AURORA level-1 notice (non-blocking)

  LumaraAssistantLoaded({
    required this.messages,
    required this.scope,
    this.isProcessing = false,
    this.currentSessionId,
    this.apiErrorMessage,
    this.notice,
  });

  LumaraAssistantLoaded copyWith({
    List<LumaraMessage>? messages,
    LumaraScope? scope,
    bool? isProcessing,
    String? currentSessionId,
    String? apiErrorMessage,
    String? notice,
  }) {
    return LumaraAssistantLoaded(
      messages: messages ?? this.messages,
      scope: scope ?? this.scope,
      isProcessing: isProcessing ?? this.isProcessing,
      currentSessionId: currentSessionId ?? this.currentSessionId,
      apiErrorMessage: apiErrorMessage,
      notice: notice,
    );
  }
}

class LumaraAssistantError extends LumaraAssistantState {
  final String message;
  
  LumaraAssistantError(this.message);
}

/// Emitted when AURORA reflection monitoring pauses the session.
class LumaraAssistantPaused extends LumaraAssistantState {
  final String message;
  final DateTime? pausedUntil;
  final List<LumaraMessage> previousMessages;
  final LumaraScope scope;

  LumaraAssistantPaused(this.message, this.pausedUntil, this.previousMessages, this.scope);
}

/// LUMARA Assistant Cubit
class LumaraAssistantCubit extends Cubit<LumaraAssistantState> {
  final ContextProvider _contextProvider;
  final LLMAdapter _llmAdapter;
  late final ArcLLM _arcLLM;
  late final EnhancedLumaraApi _enhancedApi;
  final Analytics _analytics = Analytics();

  // Enhanced MIRA Memory System
  EnhancedMiraMemoryService? _memoryService;
  String? _userId;
  String? _currentPhase;
  
  // Chat History System
  late final ChatRepo _chatRepo;
  late final ChatPhaseService _chatPhaseService;
  String? currentChatSessionId;
  
  
  // Progressive Memory Loader
  late final ProgressiveMemoryLoader _memoryLoader;
  final JournalRepository _journalRepository = JournalRepository();
  
  // Attribution Service for creating traces
  final AttributionService _attributionService = AttributionService();
  
  // Reflective Query Service
  late final ReflectiveQueryService _reflectiveQueryService;
  late final ReflectiveQueryFormatter _reflectiveFormatter;
  
  // Auto-save and compaction - Updated for 25-message summarization
  static const int _maxMessagesBeforeCompaction = 25;
  static const int _compactionThreshold = 150; // Summarize after 150 messages
  bool _isCompacting = false;

  // AURORA reflection session monitoring
  ReflectionHandler? _reflectionHandler;
  String? _currentReflectionSessionId;

  Future<ReflectionHandler> _getReflectionHandler() async {
    if (_reflectionHandler != null) return _reflectionHandler!;
    final box = Hive.isBoxOpen('reflection_sessions')
        ? Hive.box<ReflectionSession>('reflection_sessions')
        : await Hive.openBox<ReflectionSession>('reflection_sessions');
    _reflectionHandler = ReflectionHandler(
      sessionRepo: ReflectionSessionRepository(box),
      journalRepo: _journalRepository,
      aurora: AuroraReflectionService(
        patternAnalyzer: ReflectionPatternAnalyzer(),
        emotionalAnalyzer: ReflectionEmotionalAnalyzer(
          AdaptiveSentinelCalculator(SentinelConfig.weekly()),
        ),
      ),
      lumaraApi: _enhancedApi,
    );
    return _reflectionHandler!;
  }
  
  // Voiceover/TTS for AI responses
  AudioIO? _audioIO;

  LumaraAssistantCubit({
    required ContextProvider contextProvider,
  }) : _contextProvider = contextProvider,
       _llmAdapter = LLMAdapter(),
       _chatRepo = ChatRepoImpl.instance,
       _chatPhaseService = ChatPhaseService(ChatRepoImpl.instance),
       super(LumaraAssistantInitial()) {
    // Initialize ArcLLM with Gemini integration
    _arcLLM = provideArcLLM();
    // Initialize enhanced LUMARA API
    _enhancedApi = EnhancedLumaraApi(_analytics);
    // Initialize progressive memory loader
    _memoryLoader = ProgressiveMemoryLoader(_journalRepository);
    // Initialize reflective query service (will be updated after memory service is initialized)
    _reflectiveQueryService = ReflectiveQueryService(
      journalRepository: _journalRepository,
    );
    _reflectiveFormatter = ReflectiveQueryFormatter();
  }
  
  /// Initialize the assistant with parallel service loading
  Future<void> initialize() async {
    try {
      emit(LumaraAssistantLoading());

      // Initialize AudioIO for voiceover
      _audioIO = AudioIO();
      await _audioIO!.initializeTTS();
      
      // Parallelize independent service initializations
      final initializationResults = await Future.wait([
        _memoryLoader.initialize().then((_) => true).catchError((_) => false),
        _enhancedApi.initialize().then((_) => true).catchError((_) => false),
        _initializeMemorySystem().then((_) => true).catchError((_) => false),
        _chatRepo.initialize().then((_) => true).catchError((_) => false),
      ], eagerError: false);

      print('LUMARA: Parallel initialization completed: ${initializationResults.where((r) => r).length}/4 services successful');

      
      // Start with default scope
      const scope = LumaraScope.defaultScope;

      // API key configuration is now handled by LumaraAPIConfig

      // Start or resume a conversation session
      final sessionId = await _getOrCreateSession();

    // Add welcome message (only automated message allowed)
    // Split into paragraphs for better readability
    final welcomeContent = "Hello! I'm LUMARA, your personal assistant.\n\nI can help you understand your patterns, explain your current phase, and provide insights about your journey.\n\nWhat would you like to know?";

      final List<LumaraMessage> messages = [
        LumaraMessage.assistant(content: welcomeContent),
      ];

      // Record welcome message in MCP memory
      await _recordAssistantMessage(welcomeContent);

      emit(LumaraAssistantLoaded(
        messages: messages,
        scope: scope,
        currentSessionId: sessionId,
      ));
    } catch (e) {
      emit(LumaraAssistantError('Failed to initialize LUMARA: $e'));
    }
  }

  /// Alias for initialize method (for UI compatibility)
  Future<void> initializeLumara() async {
    await initialize();
  }

  /// Get enhanced API status
  Map<String, dynamic> getApiStatus() {
    return _enhancedApi.getStatus();
  }

  /// Switch to a different LLM provider
  Future<void> switchProvider(String providerType) async {
    // This would need to be implemented based on the provider type
    // For now, just log the request
    print('LUMARA Debug: Provider switch requested: $providerType');
  }
  
  /// Save pending input for resubmission if conversation is interrupted
  Future<void> _savePendingInput(
    String text, {
    models.ConversationMode? conversationMode,
    String? persona,
  }) async {
    try {
      final currentState = state;
      String? sessionId;
      if (currentState is LumaraAssistantLoaded) {
        // Get session ID from chat repo if available
        try {
          final chatRepo = ChatRepoImpl.instance;
          await chatRepo.initialize();
          final sessions = await chatRepo.listAll();
          if (sessions.isNotEmpty) {
            sessionId = sessions.first.id;
          }
        } catch (e) {
          // Session ID not critical for pending input
        }
      }

      final pendingInput = PendingInput(
        userText: text,
        mode: 'chat',
        timestamp: DateTime.now(),
        context: {
          'conversationMode': conversationMode?.name,
          'persona': persona,
        },
        sessionId: sessionId,
      );
      await PendingConversationService.savePendingInput(pendingInput);
    } catch (e) {
      print('LUMARA Chat: Error saving pending input: $e');
      // Don't fail the process if saving pending input fails
    }
  }

  /// Dismiss AURORA pause and return to chat with previous messages.
  void dismissPause() {
    final currentState = state;
    if (currentState is LumaraAssistantPaused) {
      emit(LumaraAssistantLoaded(
        messages: currentState.previousMessages,
        scope: currentState.scope,
        isProcessing: false,
      ));
    }
  }

  /// Resubmit a pending input (called when user wants to retry after interruption)
  Future<void> resubmitPendingInput() async {
    final pendingInput = await PendingConversationService.getPendingInput();
    if (pendingInput == null || pendingInput.mode != 'chat') {
      print('LUMARA Chat: No pending chat input to resubmit');
      return;
    }

    print('LUMARA Chat: Resubmitting pending input: ${pendingInput.userText.substring(0, pendingInput.userText.length > 50 ? 50 : pendingInput.userText.length)}...');
    
    // Extract context if available
    models.ConversationMode? conversationMode;
    if (pendingInput.context?['conversationMode'] != null) {
      try {
        conversationMode = models.ConversationMode.values.firstWhere(
          (m) => m.name == pendingInput.context!['conversationMode'],
        );
      } catch (e) {
        // Use default if mode not found
        conversationMode = null;
      }
    }
    final persona = pendingInput.context?['persona'] as String?;
    
    // Resubmit the message
    await sendMessage(
      pendingInput.userText,
      conversationMode: conversationMode,
      persona: persona,
    );
  }

  /// Send a message to LUMARA
  /// 
  /// [conversationMode] - Optional conversation mode (from UI buttons)
  /// [persona] - Optional persona override (from UI selector, 'companion' default)
  Future<void> sendMessage(
    String text, {
    JournalEntry? currentEntry,
    models.ConversationMode? conversationMode,
    String? persona, // 'companion', 'strategist', 'therapist', 'challenger'
  }) async {
    if (text.trim().isEmpty) return;

    final currentState = state;
    if (currentState is! LumaraAssistantLoaded) return;

    print('LUMARA Debug: Sending message: "$text"');
    print('LUMARA Debug: Current message count: ${currentState.messages.length}');
    if (conversationMode != null) {
      print('LUMARA Debug: Conversation mode: ${conversationMode.name}');
    }
    if (persona != null) {
      print('LUMARA Debug: Persona override: $persona');
    }

    // ═══════════════════════════════════════════════════════════
    // STEP 1: CHECK SENTINEL FOR CRISIS (HIGHEST PRIORITY)
    // ═══════════════════════════════════════════════════════════
    String? effectivePersona = persona;
    bool safetyOverride = false;
    
    try {
      final authService = FirebaseAuthService.instance;
      final user = authService.currentUser;
      if (user != null) {
        // Check if already in crisis mode
        final alreadyInCrisis = await CrisisMode.isInCrisisMode(user.uid);
        
        // Calculate SENTINEL score
        final sentinelScore = await SentinelAnalyzer.calculateSentinelScore(
          userId: user.uid,
          currentEntryText: text,
        );
        
        if (alreadyInCrisis || sentinelScore.alert) {
          // SAFETY OVERRIDE: Force Therapist mode
          effectivePersona = 'therapist';
          safetyOverride = true;
          
          // Activate crisis mode if not already active
          if (!alreadyInCrisis && sentinelScore.alert) {
            await CrisisMode.activateCrisisMode(
              userId: user.uid,
              sentinelScore: sentinelScore,
            );
          }
          
          print('🚨 LUMARA Chat: SAFETY OVERRIDE ACTIVE');
          print('   Sentinel score: ${sentinelScore.score.toStringAsFixed(2)}');
          print('   Reason: ${sentinelScore.reason}');
          print('   → FORCING THERAPIST MODE');
        } else {
          // Use provided persona or default to companion
          effectivePersona = persona ?? 'companion';
          print('🎯 LUMARA Chat: Using persona: $effectivePersona');
        }
      } else {
        // No user ID, use provided persona or default
        effectivePersona = persona ?? 'companion';
      }
    } catch (e) {
      print('⚠️ LUMARA Chat: Error checking Sentinel: $e');
      // Fallback to provided persona or default
      effectivePersona = persona ?? 'companion';
    }

    // Check for memory commands
    if (text.startsWith('/memory')) {
      await _handleMemoryCommand(text);
      return;
    }
    
    // Check for Bible verse requests and fetch verses to include in context
    String? bibleVerses;
    try {
      print('LUMARA: Checking for Bible request in message: "${text.substring(0, text.length > 50 ? 50 : text.length)}..."');
      bibleVerses = await BibleRetrievalHelper.fetchVersesForRequest(text);
      if (bibleVerses != null) {
        print('LUMARA: ✅ Fetched Bible context for request');
        print('LUMARA: Bible context length: ${bibleVerses.length}');
        print('LUMARA: Bible context preview: ${bibleVerses.substring(0, bibleVerses.length > 200 ? 200 : bibleVerses.length)}...');
      } else {
        print('LUMARA: ⚠️ No Bible context returned (not detected as Bible request)');
      }
    } catch (e, stackTrace) {
      print('LUMARA: ❌ Error fetching Bible verses: $e');
      print('LUMARA: Stack trace: $stackTrace');
    }


    // Save pending input in case of interruption
    await _savePendingInput(text, conversationMode: conversationMode, persona: effectivePersona);

    // Add user message to UI immediately and set isProcessing to show loading indicator
    final userMessage = LumaraMessage.user(content: text);
    final updatedMessages = [...currentState.messages, userMessage];

    // Emit state with isProcessing: true immediately to show loading indicator
    emit(currentState.copyWith(
      messages: updatedMessages,
      isProcessing: true,
      apiErrorMessage: null, // Clear any previous error message when starting new message
      notice: null, // Clear AURORA notice when starting new message
    ));

    // Ensure we have an active chat session (auto-create if needed)
    await _ensureActiveChatSession(text);

    // Record user message in MCP memory first
    await _recordUserMessage(text);
    
    // Add user message to chat session (preserve ID for favorites)
    await _addToChatSession(text, 'user', messageId: userMessage.id, timestamp: userMessage.timestamp);

    print('LUMARA Debug: Added user message, new count: ${updatedMessages.length}');

    // Check if this is a reflective query
    final taskType = _determineTaskType(text);
    if (taskType == InsightKind.reflectiveHandledHard ||
        taskType == InsightKind.reflectiveTemporalStruggle ||
        taskType == InsightKind.reflectiveThemeSoftening) {
      await _handleReflectiveQuery(taskType, text, updatedMessages, currentState);
      return;
    }

    try {
      // Get provider status from LumaraAPIConfig (the authoritative source)
      final apiConfig = LumaraAPIConfig.instance;
      await apiConfig.initialize();
      final availableProviders = apiConfig.getAvailableProviders();
      final bestProvider = apiConfig.getBestProvider();
      final onDeviceAvailable = LLMAdapter.isAvailable;

      print('LUMARA Debug: Provider Status Summary:');
      print('LUMARA Debug:   - On-Device (Qwen): ${onDeviceAvailable ? "AVAILABLE ✓" : "Not Available (${LLMAdapter.reason})"}');
      print('LUMARA Debug:   - Cloud API (Groq/Gemini): ${availableProviders.any((p) => p.name == 'Groq (Llama 3.3 70B / Mixtral)' || p.name == 'Google Gemini') ? "AVAILABLE ✓" : "Not Available (no API key)"}');
      print('LUMARA Debug: Security-first fallback chain: On-Device → Cloud API → Rule-Based');

      // Check if user has manually selected a provider
      final currentProvider = _enhancedApi.getCurrentProvider();
      
      // If current provider is the same as the best provider, treat as automatic mode
      final isManualSelection = currentProvider != bestProvider?.name;
      
      print('LUMARA Debug: Current provider: ${currentProvider ?? 'none'}');
      print('LUMARA Debug: Best provider: ${bestProvider?.name ?? 'none'}');
      print('LUMARA Debug: Is manual selection: $isManualSelection');

      // Use Groq or Gemini with full journal context (ArcLLM chat) - Cloud API only
      // Retry logic: 3 attempts total (initial + 2 retries)
      const maxAttempts = 3;
      Exception? lastError;
      
      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          print('LUMARA Debug: [Cloud API] Attempt $attempt/$maxAttempts - Attempting Groq/Gemini with journal context...');
          
          // Get context for Gemini (using current scope from state)
          final context = await _contextProvider.buildContext(scope: currentState.scope);
          final contextResult = await _buildEntryContext(
            context, 
            userQuery: text,
            currentEntry: currentEntry,
          );
          final entryText = contextResult['context'] as String;
          final contextAttributionTraces = contextResult['attributionTraces'] as List<AttributionTrace>;
          final phaseHint = _buildPhaseHint(context);
          final keywords = _buildKeywordsContext(context);
          
          // Include Bible verses in user intent if fetched
          String userIntent = text;
          if (bibleVerses != null && bibleVerses.isNotEmpty) {
            userIntent = '$text\n\n[BIBLE_VERSE_CONTEXT]\n$bibleVerses\n[/BIBLE_VERSE_CONTEXT]';
            print('LUMARA: Including Bible verses in ArcLLM context');
          }
          
          // ═══════════════════════════════════════════════════════════
          // STEP 2: DETECT CONVERSATION MODE FROM TEXT (if not provided)
          // ═══════════════════════════════════════════════════════════
          models.ConversationMode? detectedMode = conversationMode;
          if (detectedMode == null) {
            detectedMode = _detectConversationModeFromText(text);
          }
          
          // ═══════════════════════════════════════════════════════════
          // STEP 3: USE ENHANCED LUMARA API IF CONVERSATION MODE OR SAFETY OVERRIDE
          // ═══════════════════════════════════════════════════════════
          // Use enhanced API when: conversation mode specified, safety override, or persona not companion
          if (detectedMode != null || safetyOverride || effectivePersona != 'companion') {
            print('LUMARA Chat: Using enhanced_lumara_api with mode: ${detectedMode?.name}, safetyOverride: $safetyOverride, persona: $effectivePersona');
            
            try {
              // Convert phase hint JSON to PhaseHint enum
              models.PhaseHint? phaseHintEnum;
              if (phaseHint != null && phaseHint != 'null') {
                try {
                  final phaseData = jsonDecode(phaseHint) as Map<String, dynamic>;
                  final phaseName = phaseData['phase'] as String?;
                  if (phaseName != null) {
                    phaseHintEnum = models.PhaseHint.values.firstWhere(
                      (e) => e.name == phaseName.toLowerCase(),
                      orElse: () => models.PhaseHint.consolidation,
                    );
                  }
                } catch (e) {
                  print('LUMARA Chat: Error parsing phase hint: $e');
                }
              }
              
              // Build reflection request
              final request = models.LumaraReflectionRequest(
                userText: userIntent,
                phaseHint: phaseHintEnum,
                entryType: models.EntryType.chat,
                priorKeywords: [],
                matchedNodeHints: [],
                mediaCandidates: [],
                options: models.LumaraReflectionOptions(
                  conversationMode: detectedMode,
                  toneMode: models.ToneMode.normal,
                  regenerate: false,
                  preferQuestionExpansion: false,
                ),
              );
              
              // Get user ID for enhanced API
              final authService = FirebaseAuthService.instance;
              final user = authService.currentUser;
              final userId = user?.uid;

              String reflectionText;
              var attributionTraces = <AttributionTrace>[];
              String? notice;

              if (currentEntry != null && userId != null && userId.isNotEmpty) {
                final handler = await _getReflectionHandler();
                final response = await handler.handleReflectionRequest(
                  userQuery: userIntent,
                  entryId: currentEntry.id,
                  userId: userId,
                  sessionId: _currentReflectionSessionId,
                  options: models.LumaraReflectionOptions(
                    conversationMode: detectedMode,
                    toneMode: models.ToneMode.normal,
                    regenerate: false,
                    preferQuestionExpansion: false,
                  ),
                );

                if (response.isPaused) {
                  emit(LumaraAssistantPaused(
                    response.text,
                    response.pausedUntil,
                    currentState.messages,
                    currentState.scope,
                  ));
                  return;
                }

                _currentReflectionSessionId = response.sessionId;
                notice = response.notice;
                reflectionText = response.text;
                attributionTraces = response.attributionTraces ?? [];
              } else {
                final result = await _enhancedApi.generatePromptedReflectionV23(
                  request: request,
                  userId: userId,
                );
                reflectionText = result.reflection;
                attributionTraces = result.attributionTraces;
              }
              
              print('LUMARA Chat: Enhanced API response received (${reflectionText.length} chars)');
              
              if (attributionTraces.isNotEmpty) {
                attributionTraces = await _enrichAttributionTraces(attributionTraces);
              }
              
              await _recordAssistantMessage(reflectionText);
              
              final assistantMessage = LumaraMessage.assistant(
                content: reflectionText,
                attributionTraces: attributionTraces,
              );
              
              await _addToChatSession(reflectionText, 'assistant', messageId: assistantMessage.id, timestamp: assistantMessage.timestamp);
              
              var finalMessages = [...updatedMessages, assistantMessage];
              if (hasMoreHistory() && _queryNeedsMoreHistory(text)) {
                final suggestionMsg = _generateLoadMoreSuggestionMessage();
                if (suggestionMsg.isNotEmpty) {
                  final suggestionMessage = LumaraMessage.system(content: suggestionMsg);
                  finalMessages = [...finalMessages, suggestionMessage];
                }
              }
              
              _speakResponseIfEnabled(reflectionText);
              
              emit(currentState.copyWith(
                messages: finalMessages,
                isProcessing: false,
                apiErrorMessage: null,
                notice: notice,
              ));
              
              await PendingConversationService.clearPendingInput();
              
              print('LUMARA Chat: Enhanced API complete');
              return;
            } catch (e) {
              print('LUMARA Chat: Enhanced API failed: $e');
              // Fall through to ArcLLM chat as fallback
            }
          }
          
          // ═══════════════════════════════════════════════════════════
          // STEP 4: FALLBACK TO STANDARD ArcLLM CHAT
          // ═══════════════════════════════════════════════════════════
          // Use ArcLLM to call Gemini directly with all journal context
          final response = await _arcLLM.chat(
            userIntent: userIntent,
            entryText: entryText,
            phaseHintJson: phaseHint,
            lastKeywordsJson: keywords,
          );
          
          print('LUMARA Debug: [Cloud API] ✓ Response received on attempt $attempt, length: ${response.length}');
          
          // Use attribution traces from context building (the actual memory nodes used)
          var attributionTraces = contextAttributionTraces;
          print('LUMARA Debug: Using ${attributionTraces.length} attribution traces from context building');
          
          // Enrich attribution traces with actual journal entry content
          if (attributionTraces.isNotEmpty) {
            attributionTraces = await _enrichAttributionTraces(attributionTraces);
            print('LUMARA Debug: Enriched ${attributionTraces.length} attribution traces with journal entry content');
          }
          
          // Append phase information from attribution traces to response
          final enhancedResponse = _appendPhaseInfoFromAttributions(response, attributionTraces, context);
          
          // Record assistant response in MCP memory
          await _recordAssistantMessage(enhancedResponse);
          
          // Create assistant message first to get ID
          final assistantMessage = LumaraMessage.assistant(
            content: enhancedResponse,
            attributionTraces: attributionTraces,
          );
          
          // Add assistant response to chat session (preserve ID for favorites)
          await _addToChatSession(enhancedResponse, 'assistant', messageId: assistantMessage.id, timestamp: assistantMessage.timestamp);
          
          // Check if we should suggest loading more history
          var finalMessages = [...updatedMessages, assistantMessage];
          
          if (hasMoreHistory() && _queryNeedsMoreHistory(text)) {
            final suggestionMsg = _generateLoadMoreSuggestionMessage();
            if (suggestionMsg.isNotEmpty) {
              final suggestionMessage = LumaraMessage.system(content: suggestionMsg);
              finalMessages = [...finalMessages, suggestionMessage];
            }
          }
          
          // Speak response if voiceover is enabled
          _speakResponseIfEnabled(enhancedResponse);
          
          emit(currentState.copyWith(
            messages: finalMessages,
            isProcessing: false,
            apiErrorMessage: null, // Clear any previous error message
          ));
          
          // Clear pending input when response completes successfully
          await PendingConversationService.clearPendingInput();
          
          print('LUMARA Debug: [Cloud API] Complete - personalized response generated');
          return; // Exit early - Groq/Gemini succeeded
        } catch (e) {
          lastError = e is Exception ? e : Exception(e.toString());
          final errorString = e.toString();
          print('LUMARA Debug: [Cloud API] Attempt $attempt/$maxAttempts failed: $errorString');
          
          // Check if this is an auth/trial error - don't retry, show immediately
          if (errorString.contains('ANONYMOUS_TRIAL_EXPIRED') ||
              errorString.contains('free trial') ||
              errorString.contains('permission-denied') ||
              errorString.contains('unauthenticated')) {
            print('LUMARA Debug: Auth/trial error detected - showing dialog');
            emit(currentState.copyWith(
              messages: updatedMessages,
              isProcessing: false,
              apiErrorMessage: errorString,
            ));
            return;
          }
          
          // If this is not the last attempt, wait before retrying
          if (attempt < maxAttempts) {
            // Exponential backoff: 1s, 2s
            final delaySeconds = attempt;
            print('LUMARA Debug: [Cloud API] Waiting ${delaySeconds}s before retry...');
            await Future.delayed(Duration(seconds: delaySeconds));
          }
        }
      }
      
      // All retries failed - show graceful error message
      print('LUMARA Debug: [Cloud API] All $maxAttempts attempts failed. Last error: $lastError');
      print('LUMARA Debug: Cloud API only mode - no automated responses');

      // Check if last error was auth-related
      final lastErrorString = lastError?.toString() ?? '';
      final isAuthError = lastErrorString.contains('ANONYMOUS_TRIAL_EXPIRED') ||
          lastErrorString.contains('free trial') ||
          lastErrorString.contains('permission-denied') ||
          lastErrorString.contains('unauthenticated');

      // Emit error state with message for snackbar
      emit(currentState.copyWith(
        isProcessing: false,
        apiErrorMessage: isAuthError ? lastErrorString : 'LUMARA cannot answer at the moment. Please try again later.',
      ));
      return;
    } catch (e) {
      final errorString = e.toString();
      print('LUMARA Debug: Cloud API failed: $errorString');
      print('LUMARA Debug: Cloud API only mode - NO automated responses');

      // Check if this is an auth/trial error
      final isAuthError = errorString.contains('ANONYMOUS_TRIAL_EXPIRED') ||
          errorString.contains('free trial') ||
          errorString.contains('permission-denied') ||
          errorString.contains('unauthenticated');

      // Emit error state with message for snackbar
      emit(currentState.copyWith(
        messages: updatedMessages,
        isProcessing: false,
        apiErrorMessage: isAuthError ? errorString : 'LUMARA cannot answer at the moment. Please try again later.',
      ));
    }
  }

  Future<void> continueAssistantMessage(
    String messageId, {
    JournalEntry? currentEntry,
  }) async {
    final currentState = state;
    if (currentState is! LumaraAssistantLoaded) return;

    final targetIndex = currentState.messages.lastIndexWhere(
      (m) => m.id == messageId && m.role == LumaraMessageRole.assistant,
    );
    if (targetIndex == -1) {
      print('LUMARA Debug: continueAssistantMessage called with unknown messageId $messageId');
      return;
    }

    final targetMessage = currentState.messages[targetIndex];
    final previousUserMessage = _findPreviousUserMessage(currentState.messages, startIndex: targetIndex);
    final fallbackIntent = 'Please continue the previous reflection exactly where it stopped.';
    final userIntent = previousUserMessage?.content ?? fallbackIntent;

    emit(currentState.copyWith(isProcessing: true, apiErrorMessage: null));

    try {
      final context = await _contextProvider.buildContext(scope: currentState.scope);
      final contextResult = await _buildEntryContext(
        context,
        userQuery: userIntent,
        currentEntry: currentEntry,
      );
      final entryText = contextResult['context'] as String;
      var attributionTraces = contextResult['attributionTraces'] as List<AttributionTrace>;
      final phaseHint = _buildPhaseHint(context);
      final keywords = _buildKeywordsContext(context);

      final response = await _arcLLM.chat(
        userIntent: userIntent,
        entryText: entryText,
        phaseHintJson: phaseHint,
        lastKeywordsJson: keywords,
        isContinuation: true,
        previousAssistantReply: targetMessage.content,
      );

      if (attributionTraces.isNotEmpty) {
        attributionTraces = await _enrichAttributionTraces(attributionTraces);
      }

      await _recordAssistantMessage(response);
      final assistantMessage = LumaraMessage.assistant(
        content: response,
        attributionTraces: attributionTraces,
      );
      await _addToChatSession(response, 'assistant', messageId: assistantMessage.id, timestamp: assistantMessage.timestamp);

      final updatedMessages = [
        ...currentState.messages,
        assistantMessage,
      ];

      _speakResponseIfEnabled(response);
      emit(currentState.copyWith(
        messages: updatedMessages,
        isProcessing: false,
        apiErrorMessage: null,
      ));
      print('LUMARA Debug: Continuation response completed for message $messageId');
    } catch (e) {
      print('LUMARA Debug: Continuation failed: $e');
      emit(currentState.copyWith(
        isProcessing: false,
        apiErrorMessage: 'Unable to continue that response right now. Please try again.',
      ));
    }
  }
  
  /// Map InsightKind to string for on-device model
  String _mapTaskToString(InsightKind task) {
    return switch (task) {
      InsightKind.chat => 'chat',
      InsightKind.weeklySummary => 'weekly_summary',
      InsightKind.risingPatterns => 'rising_patterns',
      InsightKind.phaseRationale => 'phase_rationale',
      InsightKind.comparePeriod => 'compare_period',
      InsightKind.promptSuggestion => 'prompt_suggestion',
      InsightKind.reflectiveHandledHard => 'reflective_handled_hard',
      InsightKind.reflectiveTemporalStruggle => 'reflective_temporal_struggle',
      InsightKind.reflectiveThemeSoftening => 'reflective_theme_softening',
    };
  }

  /// Build facts map from ContextWindow for on-device model
  Map<String, dynamic> _buildFactsFromContextWindow(ContextWindow context) {
    final recentEntries = context.nodes.where((n) => n['type'] == 'journal').toList();
    final arcformNodes = context.nodes.where((n) => n['type'] == 'arcform').toList();
    final phaseNodes = context.nodes.where((n) => n['type'] == 'phase').toList();
    
    return {
      'entry_count': recentEntries.length,
      'avg_valence': 0.5, // Default value
      'top_terms': arcformNodes.map((n) => n['content']?.toString() ?? '').toList(),
      'current_phase': phaseNodes.isNotEmpty ? phaseNodes.first['content']?.toString() : 'Discovery',
      'phase_score': 0.5, // Default value
      'recent_entry': recentEntries.isNotEmpty ? recentEntries.first['content']?.toString() : '',
      'sage_json': '{}', // Default empty JSON
      'keywords': arcformNodes.map((n) => n['content']?.toString() ?? '').toList(),
    };
  }

  /// Build snippets list from ContextWindow for on-device model
  List<String> _buildSnippetsFromContextWindow(ContextWindow context) {
    return context.nodes
        .where((n) => n['type'] == 'journal')
        .map((n) => n['content']?.toString() ?? '')
        .take(5)
        .toList();
  }

  /// Build chat history from ContextWindow for on-device model
  List<Map<String, String>> _buildChatHistoryFromContextWindow(ContextWindow context) {
    final chatHistory = <Map<String, String>>[];
    
    // Add recent conversation context if available
    if (state is LumaraAssistantLoaded) {
      final currentState = state as LumaraAssistantLoaded;
      for (final message in currentState.messages.take(10)) { // Limit context
        chatHistory.add({
          'role': message.role == LumaraMessageRole.user ? 'user' : 'assistant',
          'content': message.content,
        });
      }
    }
    
    return chatHistory;
  }

  /// Process message with streaming response
  Future<void> _processMessageWithStreaming(
    String text,
    LumaraScope scope,
    List<LumaraMessage> baseMessages, [
    List<AttributionTrace>? initialAttributionTraces,
  ]) async {
    // Get context (using provided scope)
    final context = await _contextProvider.buildContext(scope: scope);

    // Build context for streaming
    // Extract user query from baseMessages (last user message)
    final userQuery = baseMessages.lastWhere(
      (m) => m.role == 'user',
      orElse: () => baseMessages.isNotEmpty ? baseMessages.last : LumaraMessage.user(content: ''),
    ).content;
    
      // Use initial attribution traces if provided (from placeholder initialization)
      // Otherwise build context again (shouldn't happen, but fallback for safety)
      List<AttributionTrace> contextAttributionTraces;
      String entryText;
      
      if (initialAttributionTraces != null && initialAttributionTraces.isNotEmpty) {
        // Use the traces we already built for the placeholder
        contextAttributionTraces = initialAttributionTraces;
        // Still need entryText, so build context but don't recreate traces
      final contextResult = await _buildEntryContext(
        context, 
        userQuery: userQuery,
        currentEntry: null, // Streaming doesn't have current entry context
      );
        entryText = contextResult['context'] as String;
        // Use the initial traces we already have
        print('LUMARA Debug: Using ${contextAttributionTraces.length} initial attribution traces for streaming');
      } else {
        // Fallback: build context if traces weren't provided
        final contextResult = await _buildEntryContext(
          context, 
          userQuery: userQuery,
          currentEntry: null, // Streaming doesn't have current entry context
        );
        entryText = contextResult['context'] as String;
        contextAttributionTraces = contextResult['attributionTraces'] as List<AttributionTrace>;
        print('LUMARA Debug: Built context with ${contextAttributionTraces.length} attribution traces (fallback)');
      }
    final phaseHint = _buildPhaseHint(context);
    final keywords = _buildKeywordsContext(context);

    // Build system prompt (pass user message for dynamic persona detection)
    final systemPrompt = await _buildSystemPrompt(entryText, phaseHint, keywords, userMessage: text);

    print('LUMARA Debug: Starting API request...');
    print('LUMARA Debug: Using Firebase proxy with rate limiting');
    print('LUMARA Debug: Attribution traces from context: ${contextAttributionTraces.length}');
    print('LUMARA Debug: Chat session ID for rate limiting: $currentChatSessionId');

    // Check for Bible verse requests and fetch verses to include in context (for streaming path)
    String? bibleVerses;
    try {
      print('LUMARA: Checking for Bible request in streaming path: "${text.substring(0, text.length > 50 ? 50 : text.length)}..."');
      bibleVerses = await BibleRetrievalHelper.fetchVersesForRequest(text);
      if (bibleVerses != null && bibleVerses.isNotEmpty) {
        print('LUMARA: ✅ Fetched Bible verses for streaming request (length: ${bibleVerses.length})');
        print('LUMARA: Bible verses preview: ${bibleVerses.substring(0, bibleVerses.length > 300 ? 300 : bibleVerses.length)}...');
      } else {
        print('LUMARA: ⚠️ No Bible verses returned (null or empty)');
      }
    } catch (e, stackTrace) {
      print('LUMARA: ❌ Error fetching Bible verses for streaming: $e');
      print('LUMARA: Stack trace: $stackTrace');
    }

    // Use Firebase proxy with chatId for per-chat rate limiting
    // (replaces streaming to enable backend rate limiting)
    String responseText;

    try {
      // Include Bible verses in user message if fetched (for streaming path)
      String userMessage = text;
      if (bibleVerses != null && bibleVerses.isNotEmpty) {
        userMessage = '$text\n\n[BIBLE_VERSE_CONTEXT]\n$bibleVerses\n[/BIBLE_VERSE_CONTEXT]';
        print('LUMARA: Including Bible verses in streaming context');
      }
      
      // Skip transformation for Bible questions to preserve [BIBLE_CONTEXT] instructions
      final isBibleQuestion = userMessage.contains('[BIBLE_CONTEXT]') || userMessage.contains('[BIBLE_VERSE_CONTEXT]');
      
      // Call Firebase proxy with chatId for rate limiting
      responseText = await geminiSend(
        system: systemPrompt,
        user: userMessage,
        chatId: currentChatSessionId, // For per-chat usage limit tracking
        skipTransformation: isBibleQuestion, // Skip transformation to preserve Bible context instructions
        intent: isBibleQuestion ? 'bible_query' : 'chat',
      );

      // Update the UI with the full response
        final currentMessages = state is LumaraAssistantLoaded
            ? (state as LumaraAssistantLoaded).messages
            : baseMessages;

        if (currentMessages.isNotEmpty) {
          final lastIndex = currentMessages.length - 1;
        // Preserve attribution traces during update
          final existingTraces = currentMessages[lastIndex].attributionTraces;
          final updatedMessage = currentMessages[lastIndex].copyWith(
          content: responseText,
            attributionTraces: existingTraces, // Preserve existing traces
          );

          final updatedMessages = [
            ...currentMessages.sublist(0, lastIndex),
            updatedMessage,
          ];

          if (state is LumaraAssistantLoaded) {
            emit((state as LumaraAssistantLoaded).copyWith(
              messages: updatedMessages,
              isProcessing: true,
            ));
        }
      }

      print('LUMARA Debug: API request completed, response length: ${responseText.length}');

      final finalContent = responseText;

      // Use attribution traces from context building (the actual memory nodes used)
      var attributionTraces = contextAttributionTraces;
      print('LUMARA Debug: Using ${attributionTraces.length} attribution traces from context building');

      // Enrich attribution traces with actual journal entry content
      if (attributionTraces.isNotEmpty) {
        attributionTraces = await _enrichAttributionTraces(attributionTraces);
        print('LUMARA Debug: Enriched ${attributionTraces.length} attribution traces with journal entry content');
      }

      // Get context for phase info (using provided scope)
      final contextForPhase = await _contextProvider.buildContext(scope: scope);
      final enhancedContent = _appendPhaseInfoFromAttributions(
        finalContent,
        attributionTraces,
        contextForPhase,
      );

      // Record assistant response in MCP memory
      await _recordAssistantMessage(enhancedContent);

      // Update final message with attribution traces
      if (state is LumaraAssistantLoaded) {
        final currentMessages = (state as LumaraAssistantLoaded).messages;
        if (currentMessages.isNotEmpty) {
          final lastIndex = currentMessages.length - 1;
          final finalMessage = currentMessages[lastIndex].copyWith(
            content: enhancedContent,
            attributionTraces: attributionTraces,
          );

          // Add assistant response to chat session (preserve ID for favorites)
          await _addToChatSession(enhancedContent, 'assistant', messageId: finalMessage.id, timestamp: finalMessage.timestamp);

          final finalMessages = [
            ...currentMessages.sublist(0, lastIndex),
            finalMessage,
          ];

          print('LUMARA Debug: Streaming complete with ${attributionTraces.length} attribution traces');

          emit((state as LumaraAssistantLoaded).copyWith(
            messages: finalMessages,
            isProcessing: false,
          ));
          
          // Speak response if voiceover is enabled
          _speakResponseIfEnabled(enhancedContent);
        }
      }
    } catch (e) {
      print('LUMARA Debug: Error during streaming: $e');

      // Handle error by preserving partial response if available
      if (state is LumaraAssistantLoaded) {
        final currentMessages = (state as LumaraAssistantLoaded).messages;
        
        // Check if we have a partial response to preserve
        if (currentMessages.isNotEmpty) {
          final lastIndex = currentMessages.length - 1;
          final lastMessage = currentMessages[lastIndex];
          
          // If we have meaningful partial content, preserve it with error note
          if (lastMessage.content.isNotEmpty && lastMessage.content.length > 20) {
            final partialContent = lastMessage.content;
            final errorMessage = LumaraMessage.assistant(
              content: '$partialContent\n\n[Note: Response was interrupted. You can ask me to continue if needed.]',
            );
            
            final finalMessages = [
              ...currentMessages.sublist(0, lastIndex),
              errorMessage,
            ];
            
            emit((state as LumaraAssistantLoaded).copyWith(
              messages: finalMessages,
              isProcessing: false,
            ));
            return; // Exit early, we've preserved the partial response
          }
        }
        
        // Graceful fallback for streaming failures
        final errorMessage = LumaraMessage.assistant(
          content: "I'm sorry, the connection was lost while I was responding. Please try again in a moment.",
        );

        final finalMessages = [...baseMessages, errorMessage];

        emit((state as LumaraAssistantLoaded).copyWith(
          messages: finalMessages,
          isProcessing: false,
        ));
      }
    }
  }

  /// Build system prompt using unified master prompt with control state
  Future<String> _buildSystemPrompt(String? entryText, String? phaseHint, String? keywords, {String? userMessage}) async {
    // Build PRISM activity context from entry text and keywords
    final prismActivity = <String, dynamic>{
      'journal_entries': entryText != null && entryText.isNotEmpty ? [entryText] : [],
      'drafts': [],
      'chats': [],
      'media': [],
      'patterns': keywords != null && keywords.isNotEmpty ? keywords.split(',').map((e) => e.trim()).toList() : [],
      'emotional_tone': 'neutral', // Could be enhanced with sentiment analysis
      'cognitive_load': 'moderate', // Could be enhanced with analysis
    };
    
    // Build chrono context (time of day inferred from current time)
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
      'chronotype': 'sporadic', // Default, could be enhanced with user settings
      'rhythmScore': 0.7, // Default moderate
      'isFragmented': false,
    };
    
    // Build unified control state JSON (pass user message for dynamic persona/response mode detection)
    // Written chat: no length limit for Reflect, Explore, Integrate (Claude-style)
    final controlStateJson = await LumaraControlStateBuilder.buildControlState(
      userId: _userId,
      prismActivity: prismActivity,
      chronoContext: chronoContext,
      userMessage: userMessage, // Pass user message for question intent detection
      isWrittenConversation: true, // Chat UI → no sentence/word cap
    );
    
    // Build context string if entry text or keywords provided
    String? baseContext;
    if (entryText != null && entryText.isNotEmpty) {
      baseContext = 'Recent journal entry context:\n$entryText';
    } else if (keywords != null && keywords.isNotEmpty) {
      baseContext = 'Recent keywords: $keywords';
    }
    
    // Get unified master prompt (for chat, the "entry text" is the user message)
    String masterPrompt = LumaraMasterPrompt.getMasterPrompt(
      controlStateJson,
      entryText: userMessage ?? '',
      baseContext: baseContext,
    );
    
    // Inject current date/time context for temporal grounding
    // (No recent entries for chat mode, but date context is still important)
    masterPrompt = LumaraMasterPrompt.injectDateContext(masterPrompt);
    
    return masterPrompt;
  }

  /// Map task type to LUMARA intent
  String _mapTaskToIntent(InsightKind task) {
    return switch (task) {
      InsightKind.weeklySummary => 'analyze',
      InsightKind.risingPatterns => 'analyze',
      InsightKind.phaseRationale => 'think',
      InsightKind.comparePeriod => 'analyze',
      InsightKind.promptSuggestion => 'ideas',
      InsightKind.chat => 'think',
      InsightKind.reflectiveHandledHard => 'reflect',
      InsightKind.reflectiveTemporalStruggle => 'reflect',
      InsightKind.reflectiveThemeSoftening => 'reflect',
    };
  }
  
  /// Determine task type from user query
  InsightKind _determineTaskType(String query) {
    final lowerQuery = query.toLowerCase().trim();
    
    print('LUMARA Debug: Analyzing query: "$lowerQuery"');
    
    // Weekly summary patterns
    if (lowerQuery.contains('weekly') || 
        lowerQuery.contains('summary') || 
        lowerQuery.contains('last 7') ||
        lowerQuery.contains('this week') ||
        lowerQuery.contains('recent') ||
        lowerQuery.contains('summarize')) {
      print('LUMARA Debug: Detected weekly summary task');
      return InsightKind.weeklySummary;
    }
    
    // Rising patterns
    if (lowerQuery.contains('rising') || 
        lowerQuery.contains('patterns') || 
        lowerQuery.contains('trending') ||
        lowerQuery.contains('trends')) {
      print('LUMARA Debug: Detected rising patterns task');
      return InsightKind.risingPatterns;
    }
    
    // Phase rationale - more comprehensive matching
    if ((lowerQuery.contains('why') && (lowerQuery.contains('phase') || lowerQuery.contains('in'))) ||
        lowerQuery.contains('current phase') ||
        (lowerQuery.contains('phase') && (lowerQuery.contains('tell') || lowerQuery.contains('about') || lowerQuery.contains('explain'))) ||
        lowerQuery.contains('what phase') ||
        lowerQuery.contains('phase analysis')) {
      print('LUMARA Debug: Detected phase rationale task');
      return InsightKind.phaseRationale;
    }
    
    // Period comparison
    if (lowerQuery.contains('compare') || 
        lowerQuery.contains('changed') || 
        lowerQuery.contains('since') ||
        lowerQuery.contains('difference')) {
      print('LUMARA Debug: Detected period comparison task');
      return InsightKind.comparePeriod;
    }
    
    // Prompt suggestions
    if (lowerQuery.contains('prompt') || 
        lowerQuery.contains('suggest') || 
        lowerQuery.contains('journal') ||
        lowerQuery.contains('write')) {
      print('LUMARA Debug: Detected prompt suggestion task');
      return InsightKind.promptSuggestion;
    }
    
    // Reflective Query 1: "Show me three times I handled something hard"
    if ((lowerQuery.contains('three times') || lowerQuery.contains('3 times')) &&
        (lowerQuery.contains('handled') || lowerQuery.contains('dealt with') || 
         lowerQuery.contains('got through') || lowerQuery.contains('overcame'))) {
      print('LUMARA Debug: Detected reflective handled hard query');
      return InsightKind.reflectiveHandledHard;
    }
    if (lowerQuery.contains('show me') && 
        (lowerQuery.contains('handled') || lowerQuery.contains('hard') || 
         lowerQuery.contains('difficult') || lowerQuery.contains('challenge'))) {
      print('LUMARA Debug: Detected reflective handled hard query (variant)');
      return InsightKind.reflectiveHandledHard;
    }
    
    // Reflective Query 2: "What was I struggling with around this time last year?"
    if ((lowerQuery.contains('struggling') || lowerQuery.contains('struggle')) &&
        (lowerQuery.contains('this time last year') || lowerQuery.contains('around this time') ||
         lowerQuery.contains('same time last year') || lowerQuery.contains('year ago'))) {
      print('LUMARA Debug: Detected reflective temporal struggle query');
      return InsightKind.reflectiveTemporalStruggle;
    }
    if (lowerQuery.contains('what was') && 
        (lowerQuery.contains('last year') || lowerQuery.contains('year ago')) &&
        (lowerQuery.contains('struggling') || lowerQuery.contains('dealing with'))) {
      print('LUMARA Debug: Detected reflective temporal struggle query (variant)');
      return InsightKind.reflectiveTemporalStruggle;
    }
    
    // Reflective Query 3: "Which themes have softened in the last six months?"
    if ((lowerQuery.contains('themes') || lowerQuery.contains('theme')) &&
        (lowerQuery.contains('softened') || lowerQuery.contains('soften') ||
         lowerQuery.contains('less') || lowerQuery.contains('decreased')) &&
        (lowerQuery.contains('six months') || lowerQuery.contains('6 months') ||
         lowerQuery.contains('last 6') || lowerQuery.contains('past 6'))) {
      print('LUMARA Debug: Detected reflective theme softening query');
      return InsightKind.reflectiveThemeSoftening;
    }
    if (lowerQuery.contains('which') && 
        (lowerQuery.contains('softened') || lowerQuery.contains('gotten better') ||
         lowerQuery.contains('improved')) &&
        (lowerQuery.contains('months') || lowerQuery.contains('recent'))) {
      print('LUMARA Debug: Detected reflective theme softening query (variant)');
      return InsightKind.reflectiveThemeSoftening;
    }
    
    // Specific greetings and common queries
    if (lowerQuery.contains('hello') || 
        lowerQuery.contains('hi') || 
        lowerQuery.contains('hey') ||
        lowerQuery.contains('how are you') ||
        lowerQuery.contains('what can you do') ||
        lowerQuery.contains('help')) {
      print('LUMARA Debug: Detected greeting/help task');
      return InsightKind.chat;
    }
    
    print('LUMARA Debug: Defaulting to chat task');
    return InsightKind.chat;
  }
  
  /// Update scope settings
  Future<void> updateScope(LumaraScope newScope) async {
    final currentState = state;
    if (currentState is! LumaraAssistantLoaded) return;
    
    emit(currentState.copyWith(scope: newScope));
  }

  /// Toggle scope setting
  void toggleScope(String scopeType) {
    if (state is! LumaraAssistantLoaded) return;
    
    final currentState = state as LumaraAssistantLoaded;
    LumaraScope newScope;
    
    switch (scopeType) {
      case 'journal':
        newScope = currentState.scope.copyWith(journal: !currentState.scope.journal);
        break;
      case 'phase':
        newScope = currentState.scope.copyWith(phase: !currentState.scope.phase);
        break;
      case 'arcforms':
        newScope = currentState.scope.copyWith(arcforms: !currentState.scope.arcforms);
        break;
      case 'voice':
        newScope = currentState.scope.copyWith(voice: !currentState.scope.voice);
        break;
      case 'media':
        newScope = currentState.scope.copyWith(media: !currentState.scope.media);
        break;
      case 'drafts':
        newScope = currentState.scope.copyWith(drafts: !currentState.scope.drafts);
        break;
      case 'chats':
        newScope = currentState.scope.copyWith(chats: !currentState.scope.chats);
        break;
      default:
        return;
    }
    
    debugPrint('toggleScope: $scopeType - old: ${currentState.scope}, new: $newScope');
    final newState = currentState.copyWith(scope: newScope);
    emit(newState);
    debugPrint('toggleScope: emitted new state with scope: ${newState.scope}');
  }
  
  /// Clear chat history
  void clearChat() {
    final currentState = state;
    if (currentState is! LumaraAssistantLoaded) return;
    
    final List<LumaraMessage> messages = [
      LumaraMessage.assistant(
            content: "Chat cleared. How can I help you today?",
      ),
    ];
    
    emit(currentState.copyWith(messages: messages));
  }

  /// Edit and resubmit a message (removes messages after the edited one)
  void editAndResubmitMessage(String messageId, String newText) {
    final currentState = state;
    if (currentState is! LumaraAssistantLoaded) return;

    // Find the index of the message being edited
    final messageIndex = currentState.messages.indexWhere((m) => m.id == messageId);
    if (messageIndex == -1) return;

    // Remove all messages from this one onwards
    final messagesToKeep = currentState.messages.sublist(0, messageIndex);
    
    // Update state with truncated messages
    emit(currentState.copyWith(messages: messagesToKeep));
  }
  
  /// Fork chat from a specific message - creates new thread with context up to that message
  Future<String?> forkChatFromMessage(String messageId) async {
    final currentState = state;
    if (currentState is! LumaraAssistantLoaded) return null;

    // Find the message index
    final messageIndex = currentState.messages.indexWhere((m) => m.id == messageId);
    if (messageIndex == -1) return null;

    // Get all messages up to and including the fork point
    final messagesToFork = currentState.messages.sublist(0, messageIndex + 1);
    
    // Create new session with fork subject
    final forkSubject = 'Fork: ${ChatSession.generateSubject(messagesToFork.last.content)}';
    final newSessionId = await _chatRepo.createSession(
      subject: forkSubject,
      tags: ['forked'],
    );
    
    // Store fork metadata - get session and update with metadata
    final session = await _chatRepo.getSession(newSessionId);
    if (session != null) {
      // Create updated session with metadata
      final updatedSession = session.copyWith(
        metadata: {
          'forkedFrom': currentChatSessionId,
          'forkedAt': DateTime.now().toIso8601String(),
          'forkedFromMessageId': messageId,
          'originalSessionSubject': currentState.messages.isNotEmpty 
              ? ChatSession.generateSubject(currentState.messages.first.content)
              : 'Unknown',
        },
      );
      // Update session in repo (we'll need to add an update method or use renameSession as workaround)
      // For now, metadata will be stored when session is saved
    }

    // Copy messages to new session
    for (final message in messagesToFork) {
      await _chatRepo.addMessage(
        sessionId: newSessionId,
        role: message.role == LumaraMessageRole.user ? 'user' : 'assistant',
        content: message.content,
        messageId: message.id,
        timestamp: message.timestamp,
      );
    }

    // Update current session ID and load the forked chat
    currentChatSessionId = newSessionId;
    
    // Load messages from new session
    final forkedMessages = await _chatRepo.getMessages(newSessionId);
    final lumaraMessages = forkedMessages.map((msg) {
      return LumaraMessage(
        id: msg.id,
        role: msg.role == 'user' ? LumaraMessageRole.user : LumaraMessageRole.assistant,
        content: msg.textContent,
        timestamp: msg.createdAt,
        metadata: msg.metadata ?? {},
      );
    }).toList();

    emit(currentState.copyWith(
      messages: lumaraMessages,
      currentSessionId: newSessionId,
    ));

    return newSessionId;
  }

  /// Minimum number of LUMARA (assistant) responses required to keep a chat in history or export.
  /// Chats with fewer are discarded so short sessions don't clutter history/backups.
  static const int minLumaraResponsesToKeep = 3;

  /// Start a new chat (saves current chat to history only if LUMARA answered at least twice, then clears UI)
  Future<void> startNewChat() async {
    final currentState = state;
    if (currentState is! LumaraAssistantLoaded) {
      // If not loaded, just initialize
      await initialize();
      return;
    }
    
    // Save current chat session to history only if it has enough LUMARA responses; otherwise delete it
    if (currentChatSessionId != null && currentState.messages.isNotEmpty) {
      try {
        await _chatRepo.initialize();
        final session = await _chatRepo.getSession(currentChatSessionId!);
        if (session != null) {
          final messages = await _chatRepo.getMessages(currentChatSessionId!, lazy: false);
          final assistantCount = messages.where((m) => m.role == 'assistant').length;
          if (assistantCount < minLumaraResponsesToKeep) {
            await _chatRepo.deleteSession(currentChatSessionId!);
            print('LUMARA Chat: Discarded session $currentChatSessionId (only $assistantCount LUMARA response(s), need $minLumaraResponsesToKeep)');
          } else {
            // Ensure session is up-to-date (messages are already saved via _addToChatSession)
            await _chatRepo.renameSession(currentChatSessionId!, session.subject);
            print('LUMARA Chat: Finalized session $currentChatSessionId before starting new chat');
          }
        }
      } catch (e) {
        print('LUMARA Chat: Error finalizing session: $e');
        // Continue anyway - messages should already be saved
      }
    }
    
    // Reset session ID to force new session on next message
    currentChatSessionId = null;
    
    // Add welcome message (only automated message allowed)
    // Split into paragraphs for better readability
    const welcomeContent = "Hello! I'm LUMARA, your personal assistant.\n\nI can help you understand your patterns, explain your current phase, and provide insights about your journey.\n\nWhat would you like to know?";
    
    final List<LumaraMessage> messages = [
      LumaraMessage.assistant(content: welcomeContent),
    ];
    
    // Record welcome message in MCP memory
    await _recordAssistantMessage(welcomeContent);
    
    // Immediately update UI with new welcome message (clears old chat)
    emit(currentState.copyWith(
      messages: messages,
      currentSessionId: null,
    ));
  }
  
  /// Get context summary
  Future<String> getContextSummary() async {
    return await _contextProvider.getContextSummary();
  }

  /// Build entry context for ArcLLM with weighted prioritization
  /// [userQuery] - Optional user query to find semantically relevant entries
  /// [currentEntry] - Optional current journal entry (highest weight)
  /// Returns a map with 'context' (String) and 'attributionTraces' (List<AttributionTrace>)
  /// 
  /// Weighting:
  /// - Tier 1 (Highest): Current journal entry + media content
  /// - Tier 2 (Medium): Recent LUMARA responses from same chat session
  /// - Tier 3 (Lowest): Other earlier entries/chats
  Future<Map<String, dynamic>> _buildEntryContext(
    ContextWindow context, {
    String? userQuery,
    JournalEntry? currentEntry,
  }) async {
    final buffer = StringBuffer();
    final Set<String> addedEntryIds = {}; // Track added entries to avoid duplicates
    final List<AttributionTrace> attributionTraces = []; // Collect attribution traces from memory nodes used
    
    // TIER 1 (HIGHEST WEIGHT): Current journal entry + media content
    if (currentEntry != null) {
      print('LUMARA: [Tier 1] Adding current journal entry with highest weight');
      buffer.writeln('=== CURRENT ENTRY (PRIMARY SOURCE) ===');
      buffer.writeln(currentEntry.content);
      
      // Include media content (OCR, captions, transcripts)
      if (currentEntry.media.isNotEmpty) {
        buffer.writeln('\n=== MEDIA CONTENT FROM CURRENT ENTRY ===');
        for (final mediaItem in currentEntry.media) {
          if (mediaItem.ocrText != null && mediaItem.ocrText!.isNotEmpty) {
            buffer.writeln('Photo OCR: ${mediaItem.ocrText}');
          }
          if (mediaItem.altText != null && mediaItem.altText!.isNotEmpty) {
            buffer.writeln('Photo description: ${mediaItem.altText}');
          }
          if (mediaItem.transcript != null && mediaItem.transcript!.isNotEmpty) {
            buffer.writeln('Audio/Video transcript: ${mediaItem.transcript}');
          }
        }
      }
      
      buffer.writeln('---');
      addedEntryIds.add(currentEntry.id);
      
      // Create attribution trace for current entry
      if (currentEntry.content.isNotEmpty) {
        final excerpt = extractRelevantSentences(
          currentEntry.content,
          query: userQuery,
          keywords: currentEntry.keywords.map((k) => k.toString()).toList(),
          maxSentences: 3,
        );
        
        // Calculate dynamic confidence (0.75-0.85) based on relevance
        final confidence = _calculateCurrentEntryConfidence(currentEntry, userQuery);
        
        final trace = _attributionService.createTrace(
          nodeRef: 'entry:${currentEntry.id}',
          relation: 'primary_source',
          confidence: confidence,
          reasoning: 'Current journal entry - primary source for response',
          phaseContext: currentEntry.emotionReason, // Use emotion reason as phase hint
          excerpt: excerpt,
        );
        attributionTraces.add(trace);
        print('LUMARA: [Tier 1] Created attribution trace for current entry ${currentEntry.id} with confidence $confidence');
      }
      
      print('LUMARA: [Tier 1] Added current entry ${currentEntry.id} with media content');
    }
    
    // TIER 2 (MEDIUM WEIGHT): Recent LUMARA responses from same chat session
    if (currentChatSessionId != null) {
      try {
        final sessionMessages = await _chatRepo.getMessages(currentChatSessionId!, lazy: false);
        // Get recent assistant messages (last 5, excluding the current one being generated)
        final recentAssistantMessages = sessionMessages
            .where((m) => m.role == 'assistant')
            .take(5)
            .toList();
        
        if (recentAssistantMessages.isNotEmpty) {
          print('LUMARA: [Tier 2] Adding ${recentAssistantMessages.length} recent LUMARA responses from same session');
          buffer.writeln('\n=== RECENT LUMARA RESPONSES (SAME CONVERSATION) ===');
          for (final msg in recentAssistantMessages.reversed) {
            buffer.writeln('LUMARA: ${msg.textContent}');
            buffer.writeln('---');
          }
        }
      } catch (e) {
        print('LUMARA: Error getting recent chat messages: $e');
      }
    }
    
    // If we have a query and memory service, use semantic search
    if (userQuery != null && userQuery.isNotEmpty && _memoryService != null) {
      try {
        final settingsService = LumaraReflectionSettingsService.instance;
        final similarityThreshold = await settingsService.getSimilarityThreshold();
        final lookbackYears = await settingsService.getEffectiveLookbackYears();
        final maxMatches = await settingsService.getEffectiveMaxMatches();
        final therapeuticEnabled = await settingsService.isTherapeuticPresenceEnabled();
        final therapeuticDepthLevel = therapeuticEnabled 
            ? await settingsService.getTherapeuticDepthLevel() 
            : null;
        final crossModalEnabled = await settingsService.isCrossModalEnabled();
        
        print('LUMARA: Searching for relevant entries with query: "$userQuery"');
        print('LUMARA: Settings - threshold: $similarityThreshold, lookback: $lookbackYears years, maxMatches: $maxMatches, depth: $therapeuticDepthLevel');
        
        final memoryResult = await _memoryService!.retrieveMemories(
          query: userQuery,
          domains: [MemoryDomain.personal, MemoryDomain.creative, MemoryDomain.learning],
          limit: maxMatches,
          similarityThreshold: similarityThreshold,
          lookbackYears: lookbackYears,
          maxMatches: maxMatches,
          therapeuticDepthLevel: therapeuticDepthLevel,
          crossModalEnabled: crossModalEnabled,
        );
        
        print('LUMARA: Found ${memoryResult.nodes.length} semantically relevant nodes');
        
        // Store attribution traces from memory retrieval - these are the actual nodes used in context
        attributionTraces.addAll(memoryResult.attributions);
        print('LUMARA: Stored ${attributionTraces.length} attribution traces from memory nodes used in context');
        
        // Extract entry IDs from memory nodes and fetch full content
        for (final node in memoryResult.nodes) {
          // Try to extract entry ID from node
          // Entry nodes typically have their ID in the node.id or node.data
          String? entryId;
          
          // Check if node.data contains entry reference
          if (node.data.containsKey('original_entry_id')) {
            entryId = node.data['original_entry_id'] as String?;
          } else if (node.id.startsWith('entry:')) {
            entryId = node.id.replaceFirst('entry:', '');
          } else if (node.id.contains('_')) {
            // Try to extract from ID format
            final parts = node.id.split('_');
            if (parts.length > 1) {
              entryId = parts.last;
            }
          }
          
          // If we found an entry ID, try to get the full entry
          if (entryId != null && !addedEntryIds.contains(entryId)) {
            try {
              final allEntries = await _journalRepository.getAllJournalEntries();
              final entry = allEntries.firstWhere(
                (e) => e.id == entryId,
                orElse: () => allEntries.first, // Fallback
              );
              
              if (entry.content.isNotEmpty) {
                buffer.writeln(entry.content);
                buffer.writeln('---');
                addedEntryIds.add(entryId);
                print('LUMARA: Added entry $entryId from semantic search');
              }
            } catch (e) {
              // If entry not found, use node narrative as fallback
              if (node.narrative.isNotEmpty && !addedEntryIds.contains(node.id)) {
                buffer.writeln(node.narrative);
                buffer.writeln('---');
                addedEntryIds.add(node.id);
                print('LUMARA: Added node ${node.id} narrative as fallback');
              }
            }
          } else if (node.narrative.isNotEmpty && !addedEntryIds.contains(node.id)) {
            // Use node narrative directly if no entry ID found
            buffer.writeln(node.narrative);
            buffer.writeln('---');
            addedEntryIds.add(node.id);
            print('LUMARA: Added node ${node.id} narrative');
          }
        }
      } catch (e) {
        print('LUMARA: Error in semantic search: $e');
        // Fall through to use recent entries
      }
    }
    
    // Also include recent entries from progressive loader for context continuity
    final loadedEntries = _memoryLoader.getLoadedEntries();
    print('LUMARA: Adding ${loadedEntries.length} recent entries from progressive loader');
    
    int recentCount = 0;
    for (final entry in loadedEntries) {
      if (!addedEntryIds.contains(entry.id) && recentCount < 10) {
        if (entry.content.isNotEmpty) {
          buffer.writeln(entry.content);
          buffer.writeln('---');
          addedEntryIds.add(entry.id);
          
          // Create attribution trace for recent entry
          final excerpt = extractRelevantSentences(
            entry.content,
            query: userQuery,
            keywords: entry.keywords.map((k) => k.toString()).toList(),
            maxSentences: 3,
          );
          final trace = _attributionService.createTrace(
            nodeRef: 'entry:${entry.id}',
            relation: 'recent_context',
            confidence: 0.8 - (recentCount * 0.05), // Decreasing confidence for older entries
            reasoning: 'Recent journal entry from progressive loader',
            phaseContext: entry.emotionReason,
            excerpt: excerpt,
          );
          attributionTraces.add(trace);
          
          recentCount++;
        }
      }
    }
    if (recentCount > 0) {
      print('LUMARA: Created ${recentCount} attribution traces for recent entries from progressive loader');
    }
    
    // TIER 3 (LOWEST WEIGHT): Other earlier entries/chats from other sessions
    // Include recent chat sessions for conversation continuity (but lower priority)
    final chatNodes = context.nodes.where((n) => n['type'] == 'chat').toList();
    if (chatNodes.isNotEmpty) {
      print('LUMARA: [Tier 3] Adding ${chatNodes.length} recent chat sessions from other conversations');
      buffer.writeln('\n=== OTHER CONVERSATIONS (LOWER PRIORITY) ===');
      for (final chatNode in chatNodes) {
        final chatText = chatNode['text'] as String?;
        if (chatText != null && chatText.isNotEmpty) {
          buffer.writeln(chatText);
          buffer.writeln('---');
        }
      }
    }
    
    final result = buffer.toString().trim();
    print('LUMARA: Built context with ${addedEntryIds.length} unique entries and ${chatNodes.length} chat sessions');
    print('LUMARA: Returning ${attributionTraces.length} attribution traces from context building');
    
    // Return both context string and attribution traces
    return {
      'context': result,
      'attributionTraces': attributionTraces,
    };
  }

  LumaraMessage? _findPreviousUserMessage(
    List<LumaraMessage> messages, {
    required int startIndex,
  }) {
    for (int i = startIndex; i >= 0; i--) {
      final message = messages[i];
      if (message.role == LumaraMessageRole.user) {
        return message;
      }
    }
    return null;
  }

  /// Calculate dynamic confidence (0.75-0.85) for current entry based on relevance
  /// Factors considered:
  /// - Query match in entry content
  /// - Keyword overlap
  /// - Entry recency (very recent entries get slight boost)
  /// - Media content presence (indicates richer context)
  double _calculateCurrentEntryConfidence(JournalEntry entry, String? userQuery) {
    // Base confidence: 0.75 (minimum)
    double confidence = 0.75;
    
    // If no query, return base confidence
    if (userQuery == null || userQuery.trim().isEmpty) {
      return confidence;
    }
    
    final entryContentLower = entry.content.toLowerCase();
    final queryLower = userQuery.toLowerCase();
    final queryWords = queryLower.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
    
    // Query match boost: +0.05 if query appears in entry
    if (entryContentLower.contains(queryLower)) {
      confidence += 0.05;
    }
    
    // Keyword match boost: +0.02 per matching keyword (max +0.04)
    int keywordMatches = 0;
    for (final keyword in entry.keywords) {
      final keywordLower = keyword.toString().toLowerCase();
      if (queryWords.any((word) => keywordLower.contains(word) || word.contains(keywordLower))) {
        keywordMatches++;
      }
    }
    confidence += (keywordMatches * 0.02).clamp(0.0, 0.04);
    
    // Recency boost: +0.01 if entry is very recent (< 1 hour old)
    final age = DateTime.now().difference(entry.createdAt);
    if (age.inHours < 1) {
      confidence += 0.01;
    }
    
    // Media content boost: +0.01 if entry has media (richer context)
    if (entry.media.isNotEmpty) {
      confidence += 0.01;
    }
    
    // Clamp to 0.75-0.85 range
    return confidence.clamp(0.75, 0.85);
  }

  /// Build phase hint for ArcLLM - uses actual current phase from context provider
  String? _buildPhaseHint(ContextWindow context) {
    // Get current phase (from user setting)
    final currentPhaseNodes = context.nodes
        .where((n) => n['type'] == 'phase' && n['meta']?['current'] == true)
        .toList();

    // Get phase history (from entry analysis)
    final historyPhaseNodes = context.nodes
        .where((n) => n['type'] == 'phase_history')
        .toList();

    if (currentPhaseNodes.isEmpty) return null;

    final currentPhase = currentPhaseNodes.first['text'] as String?;
    if (currentPhase == null) return null;

    print('LUMARA Debug: Using current phase from Phase tab: $currentPhase');

    // Build phase context with current phase prioritized
    final phaseContext = <String, dynamic>{
      'current_phase': currentPhase,
      'current_phase_source': 'user_setting',
      'confidence': 1.0,
    };

    // Add phase history for context
    if (historyPhaseNodes.isNotEmpty) {
      final history = historyPhaseNodes.map((node) => {
        'phase': node['text'],
        'days_ago': node['meta']?['days_ago'] ?? 0,
        'confidence': node['meta']?['confidence'] ?? 0.5,
      }).toList();
      phaseContext['phase_history'] = history;
    }

    return jsonEncode(phaseContext);
  }

  /// Append phase information from attribution traces to response
  String _appendPhaseInfoFromAttributions(
    String response,
    List<AttributionTrace> attributionTraces,
    ContextWindow context,
  ) {
    // Check if response already ends with phase info (to avoid duplicating)
    if (response.contains('Based on') && response.contains('phase history')) {
      return response; // Already has phase info
    }
    
    // Get current phase from context
    final currentPhaseNodes = context.nodes
        .where((n) => n['type'] == 'phase' && n['meta']?['current'] == true)
        .toList();
    final currentPhase = currentPhaseNodes.isNotEmpty
        ? (currentPhaseNodes.first['text'] as String? ?? 'Discovery')
        : 'Discovery';
    
    // Extract unique phases from attribution traces
    final phasesFromTraces = attributionTraces
        .where((trace) => trace.phaseContext != null && trace.phaseContext!.isNotEmpty)
        .map((trace) => trace.phaseContext!)
        .toSet()
        .toList();
    
    // Count entries from context
    final entryCount = context.totalEntries;
    
    // Calculate days since start date
    final daysSince = DateTime.now().difference(context.startDate).inDays;
    
    // Build phase citation
    String phaseCitation;
    if (phasesFromTraces.isNotEmpty && phasesFromTraces.length > 1) {
      phaseCitation = 'Based on $entryCount entries, current phase: $currentPhase, ${phasesFromTraces.length} phases in history since ${daysSince} days ago.';
    } else {
      phaseCitation = 'Based on $entryCount entries, current phase: $currentPhase, phase history since ${daysSince} days ago.';
    }
    
    // Append if not already present
    if (!response.trim().endsWith(phaseCitation.trim())) {
      return '$response\n\n$phaseCitation';
    }
    
    return response;
  }

  /// Enrich attribution traces with actual journal entry content
  /// Replaces LUMARA response excerpts and placeholders with actual journal entry content
  Future<List<AttributionTrace>> _enrichAttributionTraces(List<AttributionTrace> traces) async {
    final enrichedTraces = <AttributionTrace>[];
    
    for (final trace in traces) {
      AttributionTrace enrichedTrace = trace;
      
      // Check if excerpt needs enrichment
      final excerpt = trace.excerpt ?? '';
      final excerptLower = excerpt.toLowerCase();
      
      // Check if excerpt is a LUMARA response or placeholder
      final isLumaraResponse = excerptLower.contains("hello! i'm lumara") ||
          excerptLower.contains("i'm lumara") ||
          excerptLower.contains("i'm your personal assistant") ||
          (excerptLower.startsWith("hello") && excerptLower.contains("lumara")) ||
          excerptLower.contains("[journal entry content") ||
          excerptLower.contains("[memory reference");
      
      if (isLumaraResponse || excerpt.isEmpty) {
        // Try to extract entry ID from node reference
        String? entryId;
        
        // Try different ID patterns
        if (trace.nodeRef.startsWith('entry:')) {
          entryId = trace.nodeRef.replaceFirst('entry:', '');
        } else if (trace.nodeRef.contains('_')) {
          final parts = trace.nodeRef.split('_');
          if (parts.length > 1) {
            entryId = parts.last;
          }
        } else {
          // Try to extract from the excerpt placeholder
          final entryIdMatch = RegExp(r'entry\s+([a-zA-Z0-9_-]+)').firstMatch(excerpt);
          if (entryIdMatch != null) {
            entryId = entryIdMatch.group(1);
          }
        }
        
        // If we found an entry ID, try to get the actual journal entry
        if (entryId != null) {
          try {
            final allEntries = await _journalRepository.getAllJournalEntries();
            JournalEntry entry;
            try {
              entry = allEntries.firstWhere((e) => e.id == entryId);
            } catch (e) {
              // If exact match not found, try partial match
              try {
                final entryIdNonNull = entryId; // We know it's not null here
                entry = allEntries.firstWhere(
                  (e) => e.id.contains(entryIdNonNull) || entryIdNonNull.contains(e.id),
                );
              } catch (e2) {
                // Fallback: skip this trace if entry not found
                enrichedTraces.add(trace);
                continue;
              }
            }
            
            if (entry.content.isNotEmpty) {
              // Extract 2-3 most relevant sentences instead of just first 200 chars
              // Use trace reasoning or relation as query context for relevance
              final queryContext = trace.reasoning ?? trace.relation;
              final actualContent = extractRelevantSentences(
                entry.content,
                query: queryContext,
                maxSentences: 3,
              );
              
              enrichedTrace = AttributionTrace(
                nodeRef: trace.nodeRef,
                relation: trace.relation,
                confidence: trace.confidence,
                timestamp: trace.timestamp,
                reasoning: trace.reasoning,
                phaseContext: trace.phaseContext,
                excerpt: actualContent,
              );
              
              print('LUMARA Chat: Enriched trace ${trace.nodeRef} with ${actualContent.split(RegExp(r'[.!?]+')).where((s) => s.trim().isNotEmpty).length} relevant sentences (${actualContent.length} chars)');
            }
          } catch (e) {
            print('LUMARA Chat: Could not find entry $entryId for trace ${trace.nodeRef}: $e');
            // Keep original trace if entry not found
          }
        }
      }
      
      enrichedTraces.add(enrichedTrace);
    }
    
    return enrichedTraces;
  }

  /// Build keywords context for ArcLLM
  String? _buildKeywordsContext(ContextWindow context) {
    final arcformNodes = context.nodes.where((n) => n['type'] == 'arcform').toList();
    if (arcformNodes.isEmpty) return null;

    final keywords = <String>[];
    for (final node in arcformNodes) {
      final nodeKeywords = node['meta']?['keywords'] as List<dynamic>? ?? [];
      keywords.addAll(nodeKeywords.cast<String>().take(5));
    }

    if (keywords.isEmpty) return null;
    final uniqueKeywords = keywords.take(10).toSet().toList();
    return '{"keywords": [${uniqueKeywords.map((k) => '"$k"').join(', ')}]}';
  }

  /// Get current phase from context (helper for memory initialization)
  String? _getCurrentPhaseFromContext(ContextWindow context) {
    final currentPhaseNodes = context.nodes
        .where((n) => n['type'] == 'phase' && n['meta']?['current'] == true)
        .toList();

    if (currentPhaseNodes.isEmpty) return null;
    return currentPhaseNodes.first['text'] as String?;
  }

  // MCP Memory System Methods

  /// Initialize the Enhanced MIRA memory system
  Future<void> _initializeMemorySystem() async {
    try {
      // Get user ID (simplified - in real implementation, get from user service)
      _userId = 'user_${DateTime.now().millisecondsSinceEpoch}';

      // Get current phase from context (using default scope for initialization)
      final context = await _contextProvider.buildContext(scope: LumaraScope.defaultScope);
      final currentPhase = _getCurrentPhaseFromContext(context);
      _currentPhase = currentPhase; // Store for later use

      // Initialize enhanced memory service
      _memoryService = EnhancedMiraMemoryService(
        miraService: MiraService.instance,
      );

      await _memoryService!.initialize(
        userId: _userId!,
        sessionId: null, // Will be set when session is created
        currentPhase: currentPhase,
      );

      // Update reflective query service with memory service
      _reflectiveQueryService.updateDependencies(
        memoryService: _memoryService,
        phaseHistory: PhaseHistoryRepository(),
      );

      print('LUMARA Memory: Enhanced MIRA memory system initialized for user $_userId');
      if (currentPhase != null) {
        print('LUMARA Memory: Current phase: $currentPhase');
      }
    } catch (e) {
      print('LUMARA Memory: Error initializing enhanced memory system: $e');
    }
  }

  /// Get or create a conversation session
  Future<String> _getOrCreateSession() async {
    if (_memoryService == null) {
      throw Exception('Enhanced memory service not initialized');
    }

    // TODO: Enhanced memory service handles sessions internally
    // Generate a session ID for UI tracking
    final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    print('LUMARA Memory: Using session $sessionId');
    return sessionId;
  }

  /// Record user message in enhanced MIRA memory
  Future<void> _recordUserMessage(String content) async {
    if (_memoryService == null) return;

    try {
      final nodeId = await _memoryService!.storeMemory(
        content: content,
        domain: MemoryDomain.personal, // User conversations are personal
        privacy: PrivacyLevel.personal,
        source: 'LUMARA_Chat',
        metadata: {
          'role': 'user',
          'timestamp': DateTime.now().toIso8601String(),
          'session_type': 'chat',
        },
      );
      print('LUMARA Memory: Recorded user message (node: $nodeId)');
    } catch (e) {
      print('LUMARA Memory: Error recording user message: $e');
    }
  }

  /// Record assistant message in enhanced MIRA memory
  Future<void> _recordAssistantMessage(String content) async {
    if (_memoryService == null) return;

    try {
      final nodeId = await _memoryService!.storeMemory(
        content: content,
        domain: MemoryDomain.personal, // Assistant responses are personal
        privacy: PrivacyLevel.personal,
        source: 'LUMARA_Assistant',
        metadata: {
          'role': 'assistant',
          'timestamp': DateTime.now().toIso8601String(),
          'session_type': 'chat',
        },
      );
      print('LUMARA Memory: Recorded assistant message (node: $nodeId)');
    } catch (e) {
      print('LUMARA Memory: Error recording assistant message: $e');
    }
  }

  /// Handle enhanced memory commands
  Future<void> _handleMemoryCommand(String command) async {
    final currentState = state;
    if (currentState is! LumaraAssistantLoaded) return;

    try {
      String response;

      if (_memoryService == null) {
        response = 'Enhanced memory system not available. Please restart LUMARA.';
      } else {
        // Parse and handle enhanced memory commands
        final parts = command.split(' ');
        final subCommand = parts.length > 1 ? parts[1] : '';

        switch (subCommand.toLowerCase()) {
          case 'show':
          case 'status':
            response = await _handleMemoryStatusCommand();
            break;
          case 'conflicts':
            response = await _handleMemoryConflictsCommand();
            break;
          case 'domains':
            response = await _handleMemoryDomainsCommand();
            break;
          case 'health':
            response = await _handleMemoryHealthCommand();
            break;
          case 'export':
            response = await _handleMemoryExportCommand();
            break;
          default:
            response = '''Enhanced Memory Commands:
• /memory show - View memory status and overview
• /memory conflicts - Review and resolve memory conflicts
• /memory domains - Manage domain access policies
• /memory health - Check memory system health
• /memory export - Export user memory data (MCP bundle)

The enhanced memory system provides user-sovereign, explainable memory with attribution transparency.''';
        }
      }

      // Add command and response to UI
      final userMessage = LumaraMessage.user(content: command);
      final assistantMessage = LumaraMessage.assistant(content: response);
      final updatedMessages = [...currentState.messages, userMessage, assistantMessage];

      emit(currentState.copyWith(messages: updatedMessages));

      print('LUMARA Memory: Handled enhanced command: $command');
    } catch (e) {
      final errorMessage = LumaraMessage.assistant(
        content: 'Error processing enhanced memory command: $e',
      );
      final updatedMessages = [
        ...currentState.messages,
        LumaraMessage.user(content: command),
        errorMessage,
      ];

      emit(currentState.copyWith(messages: updatedMessages));
      print('LUMARA Memory: Error handling enhanced command: $e');
    }
  }

  /// Handle memory status command
  Future<String> _handleMemoryStatusCommand() async {
    if (_memoryService == null) return 'Memory service not available.';

    try {
      final stats = await _memoryService!.getMemoryStatistics();

      return '''Memory System Status:
📊 **Statistics:**
• Total Nodes: ${stats['total_nodes'] ?? 0}
• Memory Domains: ${stats['active_domains'] ?? 0}
• Recent Activity: ${stats['recent_activity'] ?? 0} interactions

🧠 **Health Score:** ${((stats['health_score'] ?? 0.0) * 100).toInt()}%

🎯 **Current Phase:** ${_currentPhase ?? 'Unknown'}

The enhanced memory system is actively learning from your interactions and providing attribution transparency for all responses.''';
    } catch (e) {
      return 'Error retrieving memory status: $e';
    }
  }

  /// Handle memory conflicts command
  Future<String> _handleMemoryConflictsCommand() async {
    if (_memoryService == null) return 'Memory service not available.';

    try {
      final conflicts = await _memoryService!.getActiveConflicts();

      if (conflicts.isEmpty) {
        return '''No Active Memory Conflicts 🎉

Your memories are currently harmonious. The system has detected no contradictions requiring resolution.

Use this command anytime to check for new conflicts as your thoughts and experiences evolve.''';
      }

      final buffer = StringBuffer();
      buffer.writeln('Active Memory Conflicts (${conflicts.length}):');
      buffer.writeln();

      for (final conflict in conflicts.take(3)) {
        buffer.writeln('🔄 **${conflict.conflictType}**');
        buffer.writeln('   ${conflict.description}');
        buffer.writeln('   Severity: ${(conflict.severity * 100).toInt()}%');
        buffer.writeln();
      }

      if (conflicts.length > 3) {
        buffer.writeln('...and ${conflicts.length - 3} more conflicts.');
        buffer.writeln();
      }

      buffer.writeln('These conflicts reflect the natural complexity of your experiences. Would you like to explore resolving any of them?');

      return buffer.toString();
    } catch (e) {
      return 'Error retrieving memory conflicts: $e';
    }
  }

  /// Handle memory domains command
  Future<String> _handleMemoryDomainsCommand() async {
    return '''Memory Domains Overview:

🏠 **Personal** - Private thoughts and experiences
💼 **Work** - Professional activities and insights
🌱 **Creative** - Ideas, inspirations, and projects
📚 **Learning** - Knowledge, skills, and education
💝 **Relationships** - Social connections and interactions
🏥 **Health** - Wellness, medical, and self-care
💰 **Finance** - Financial information and decisions
🙏 **Spiritual** - Beliefs, values, and meaning
⚙️ **Meta** - System and app-level memories

Each domain has independent privacy controls and cross-domain synthesis rules. This ensures your memories remain organized and appropriately protected.''';
  }

  /// Handle memory health command
  Future<String> _handleMemoryHealthCommand() async {
    if (_memoryService == null) return 'Memory service not available.';

    try {
      final health = await _memoryService!.getMemoryStatistics();
      final healthScore = (health['health_score'] ?? 0.0) * 100;

      String healthEmoji = healthScore >= 90 ? '💚' : healthScore >= 70 ? '💛' : '🔴';

      return '''Memory System Health $healthEmoji

**Overall Score:** ${healthScore.toInt()}%

**Key Metrics:**
• Attribution Accuracy: ${((health['attribution_accuracy'] ?? 0.0) * 100).toInt()}%
• Domain Isolation: ${((health['domain_isolation'] ?? 0.0) * 100).toInt()}%
• Conflict Resolution: ${((health['conflict_handling'] ?? 0.0) * 100).toInt()}%
• Memory Decay Balance: ${((health['decay_balance'] ?? 0.0) * 100).toInt()}%

**Recommendations:**
${healthScore >= 90 ? '✅ Memory system is performing excellently!' : healthScore >= 70 ? '⚠️ Consider resolving active conflicts to improve memory harmony.' : '🔧 Memory system may benefit from conflict resolution and cleanup.'}

Your enhanced memory system continuously adapts to your growth and maintains transparent attribution for all AI interactions.''';
    } catch (e) {
      return 'Error checking memory health: $e';
    }
  }

  /// Handle memory export command
  Future<String> _handleMemoryExportCommand() async {
    return '''Memory Export (MCP Bundle) 📦

**User Sovereignty:** Your memory data belongs to you completely.

**Export Features:**
• Complete memory bundle in standard MCP format
• All domains, privacy levels, and attribution records
• Portable across different EPI implementations
• Full audit trail and provenance tracking

**Export Process:**
1. Navigate to Settings → Memory Management
2. Select "Export Memory Bundle"
3. Choose domains and privacy levels to include
4. Download your sovereign memory data

Your exported MCP bundle can be imported into any MCP-compatible system, ensuring complete data portability and user control.

*Note: Export functionality requires UI implementation in settings.*''';
  }

  /// Ensure we have an active chat session (auto-create if needed)
  Future<void> _ensureActiveChatSession(String firstMessage) async {
    if (currentChatSessionId == null || _shouldCreateNewSession()) {
      currentChatSessionId = await _createNewChatSession(firstMessage);
      print('LUMARA Chat: Created new session $currentChatSessionId');
    }
  }

  /// Check if we should create a new session
  bool _shouldCreateNewSession() {
    // For now, always create new session if none exists
    // TODO: Add logic to resume recent sessions
    return currentChatSessionId == null;
  }

  /// Create a new chat session with auto-generated subject
  Future<String> _createNewChatSession(String firstMessage) async {
    // Ensure ChatRepo is initialized before use
    await _chatRepo.initialize();
    
    final subject = generateSubject(firstMessage);
    final sessionId = await _chatRepo.createSession(
      subject: subject,
      tags: ['auto-created', 'lumara'],
    );
    print('LUMARA Chat: Created session "$subject" with ID $sessionId');
    return sessionId;
  }

  /// Generate subject from first message based on topic
  String generateSubject(String message) {
    // Use ChatSession's topic-based subject generation
    return ChatSession.generateSubject(message);
  }

  /// Add message to current chat session
  /// Optionally accepts messageId and timestamp to preserve IDs for favorites
  Future<void> _addToChatSession(String content, String role, {String? messageId, DateTime? timestamp}) async {
    if (currentChatSessionId == null) return;
    
    try {
      // Ensure ChatRepo is initialized before use
      await _chatRepo.initialize();
      
      await _chatRepo.addMessage(
        sessionId: currentChatSessionId!,
        role: role,
        content: content,
        messageId: messageId, // Preserve LumaraMessage ID for favorites
        timestamp: timestamp, // Preserve timestamp
      );
      print('LUMARA Chat: Added $role message to session $currentChatSessionId${messageId != null ? ' (preserved ID: $messageId)' : ''}');
      
      // Check if compaction is needed
      await _checkAndCompactIfNeeded();

      // After each assistant response, (re)classify the session phase.
      // Fire-and-forget so we don't block the UI.
      if (role == 'assistant') {
        _chatPhaseService
            .classifySessionPhase(currentChatSessionId!)
            .catchError((e) { print('ChatPhase: classification error: $e'); return null; });
      }
    } catch (e) {
      print('LUMARA Chat: Error adding message to session: $e');
    }
  }

  /// Check if conversation needs compaction and perform it
  Future<void> _checkAndCompactIfNeeded() async {
    if (currentChatSessionId == null || _isCompacting) return;
    
    try {
      final messages = await _chatRepo.getMessages(currentChatSessionId!, lazy: false);
      
      // Check if we've hit exactly 25 messages (need to summarize and archive)
      if (messages.length == _compactionThreshold) {
        await _compactConversation(messages);
      }
    } catch (e) {
      print('LUMARA Chat: Error checking compaction: $e');
    }
  }

  /// Compact conversation by summarizing first 25 messages and archiving them
  Future<void> _compactConversation(List<ChatMessage> messages) async {
    if (_isCompacting || currentChatSessionId == null) return;
    
    _isCompacting = true;
    
    try {
      // Get the first 150 messages to summarize and archive
      final messagesToArchive = messages.take(150).toList();
      
      if (messagesToArchive.isEmpty) return;
      
      // Emit a state to show popup/notice while summarizing
      // We don't set isProcessing=true so the user can continue chatting
      
      print('LUMARA Chat: Summarizing first 150 messages...');
      
      // Add a temporary system message to show "Summarizing Conversation..."
      final tempSummaryId = 'temp_summary_${DateTime.now().millisecondsSinceEpoch}';
      final tempSummaryMessage = ChatMessage.createLegacy(
        sessionId: currentChatSessionId!,
        role: 'system',
        content: '🔄 **Summarizing Conversation...**\n\nConsolidating older messages to keep our chat fresh. You can continue talking.',
      );
      
      // Add temp message to state
      if (state is LumaraAssistantLoaded) {
        final currentState = state as LumaraAssistantLoaded;
        // Convert ChatMessage to LumaraMessage
        final tempLumaraMessage = LumaraMessage.fromChatMessage(tempSummaryMessage);
        final List<LumaraMessage> messagesWithTemp = [tempLumaraMessage, ...currentState.messages];
        emit(currentState.copyWith(messages: messagesWithTemp));
      }
      
      // Create summary of the messages using Gemini
      final summary = await _createConversationSummaryWithLLM(messagesToArchive);
      
      // Create the final summary message
      final summaryMessage = ChatMessage.createLegacy(
        sessionId: currentChatSessionId!,
        role: 'system',
        content: '📝 **Conversation Summary** (Older messages archived)\n\n$summary',
      );
      
      // Archive the messages by deleting them (they're preserved in MCP memory)
      await _archiveMessages(messagesToArchive);
      
      // Add the summary message at the beginning
      await _chatRepo.addMessage(
        sessionId: currentChatSessionId!,
        role: 'system',
        content: summaryMessage.textContent,
      );
      
      print('LUMARA Chat: Archived ${messagesToArchive.length} messages and created summary');
      
      // Reload messages to reflect changes (this will remove the temp message and show the real summary)
      await _reloadMessages(currentChatSessionId!);
      
      // Show notification to user
      _showCompactionNotification(messagesToArchive.length);
      
    } catch (e) {
      print('LUMARA Chat: Error compacting conversation: $e');
      if (state is LumaraAssistantLoaded) {
        // Reload messages to ensure consistent state on error
        if (currentChatSessionId != null) {
          await _reloadMessages(currentChatSessionId!);
        }
      }
    }
  }

  /// Reload messages from repository and update state
  Future<void> _reloadMessages(String sessionId) async {
    if (state is! LumaraAssistantLoaded) return;
    
    try {
      final chatMessages = await _chatRepo.getMessages(sessionId, lazy: false);
      final lumaraMessages = chatMessages.map((m) => LumaraMessage.fromChatMessage(m)).toList();
      
      if (state is LumaraAssistantLoaded) {
        final currentState = state as LumaraAssistantLoaded;
        emit(currentState.copyWith(messages: lumaraMessages));
      }
    } catch (e) {
      print('LUMARA Chat: Error reloading messages: $e');
    }
  }
  
  /// Create a summary using LLM (Gemini)
  Future<String> _createConversationSummaryWithLLM(List<ChatMessage> messages) async {
    try {
      // Build conversation text
      final conversationText = messages.map((m) {
        final role = m.role == 'user' ? 'User' : 'Assistant';
        return '$role: ${m.textContent}';
      }).join('\n\n');

      // Use Gemini to create a concise summary
      final summaryPrompt = '''Summarize the following conversation in 2-3 paragraphs, highlighting:
1. Main topics discussed
2. Key insights or decisions
3. Important context for future messages

Conversation:
$conversationText

Summary:''';

      final summary = await geminiSend(
        system: 'You are a helpful assistant that creates concise conversation summaries.',
        user: summaryPrompt,
        jsonExpected: false,
      );

      return summary.trim();
    } catch (e) {
      print('LUMARA Chat: Error creating LLM summary: $e');
      // Fallback to simple summary
      return _createConversationSummary(messages);
    }
  }
  
  /// Archive messages by deleting them (they're preserved in MCP memory system)
  Future<void> _archiveMessages(List<ChatMessage> messages) async {
    for (final message in messages) {
      try {
        await _chatRepo.deleteMessage(message.id);
      } catch (e) {
        print('LUMARA Chat: Error archiving message ${message.id}: $e');
      }
    }
  }

  /// Create a simple fallback summary of old messages
  Future<String> _createConversationSummary(List<ChatMessage> messages) async {
    // Group messages by role and create summary
    final userMessages = messages.where((m) => m.role == 'user').map((m) => m.textContent).toList();
    final assistantMessages = messages.where((m) => m.role == 'assistant').map((m) => m.textContent).toList();
    
    return '''**Key Topics Discussed:**
${userMessages.take(5).map((m) => '• ${m.length > 100 ? m.substring(0, 100) + '...' : m}').join('\n')}

**Assistant Responses:**
${assistantMessages.take(3).map((m) => '• ${m.length > 150 ? m.substring(0, 150) + '...' : m}').join('\n')}

*This conversation was automatically compacted to improve performance. The full conversation history is preserved in the MCP memory system.*''';
  }

  /// Load more history (2-3 years back)
  Future<bool> loadMoreHistory() async {
    print('LUMARA: Loading more history...');
    final loaded = await _memoryLoader.loadMoreHistory();
    
    if (loaded) {
      final loadedYears = _memoryLoader.getLoadedYears();
      final entryCount = _memoryLoader.getLoadedEntryCount();
      print('LUMARA: Loaded ${entryCount} entries from years: $loadedYears');
    }
    
    return loaded;
  }
  
  /// Check if more history is available
  bool hasMoreHistory() {
    return _memoryLoader.hasMoreYears();
  }
  
  /// Check if a query might benefit from more history
  bool _queryNeedsMoreHistory(String query) {
    final lowerQuery = query.toLowerCase();
    
    // Queries that likely need more historical context
    final deepHistoryKeywords = [
      'compare', 'change', 'evolution', 'trend', 'over time',
      'since', 'ago', 'months ago', 'years ago', 'progress',
      'journey', 'growth', 'transformation', 'improvement',
      'pattern', 'recurring', 'history', 'past', 'archives',
      'retrospective', 'reflection', 'becoming', 'development'
    ];
    
    return deepHistoryKeywords.any((keyword) => lowerQuery.contains(keyword));
  }
  
  /// Generate suggestion message to load more history
  String _generateLoadMoreSuggestionMessage() {
    final loadedYears = _memoryLoader.getLoadedYears();
    final nextUnloaded = _memoryLoader.getNextUnloadedYear();
    
    if (nextUnloaded == null) {
      return '';
    }
    
    final yearsAgo = DateTime.now().year - nextUnloaded;
    
    return '''Would you like me to search through ${yearsAgo} years of your archive for more comprehensive insights? 

Currently loaded: ${loadedYears.length} year${loadedYears.length > 1 ? 's' : ''} (${loadedYears.first}-${loadedYears.last})
Available: ${yearsAgo} more year${yearsAgo > 1 ? 's' : ''} of history''';
  }
  
  /// Get currently loaded years
  List<int> getLoadedYears() {
    return _memoryLoader.getLoadedYears();
  }
  
  /// Get available years in the data
  List<int> getAvailableYears() {
    return _memoryLoader.getAvailableYears();
  }
  
  /// Handle user request to load more history and re-answer with expanded context
  Future<void> loadMoreAndReAnswer(String originalQuestion) async {
    print('LUMARA: User requested to load more history for: "$originalQuestion"');
    
    if (!hasMoreHistory()) {
      print('LUMARA: No more history available');
      return;
    }
    
    // Load more history
    await loadMoreHistory();
    
    // Show loading indicator
    if (state is LumaraAssistantLoaded) {
      final currentState = state as LumaraAssistantLoaded;
      emit(currentState.copyWith(
        isProcessing: true,
      ));
    }
    
    // Re-answer the original question with expanded context
    await Future.delayed(Duration(milliseconds: 500)); // Brief pause to show loading
    
    await sendMessage(originalQuestion);
  }
  
  /// Show compaction notification to user
  void _showCompactionNotification(int messageCount) {
    // This would be implemented with a proper notification system
    print('LUMARA Chat: Compaction notification - $messageCount messages summarized for better performance');
  }

  /// Auto-save current conversation state
  Future<void> autoSaveConversation() async {
    if (currentChatSessionId == null) return;
    
    try {
      // Force save any pending messages
      await _chatRepo.initialize(); // Ensure repo is ready
      print('LUMARA Chat: Auto-saved conversation $currentChatSessionId');
    } catch (e) {
      print('LUMARA Chat: Error auto-saving conversation: $e');
    }
  }

  /// Get conversation history for a session
  Future<List<Map<String, dynamic>>> getConversationHistory([String? sessionId]) async {
    if (_memoryService == null) return [];

    // TODO: Enhanced memory service handles conversations differently
    // For now, return empty list as sessions are managed internally
    return [];
  }

  /// List all conversation sessions
  Future<List<Map<String, dynamic>>> getConversationSessions() async {
    if (_memoryService == null) return [];

    // TODO: Enhanced memory service manages sessions internally
    // For now, return empty list
    return [];
  }

  /// Switch to a different conversation session
  Future<void> switchToSession(String sessionId) async {
    if (_memoryService == null) return;

    // TODO: Enhanced memory service manages sessions internally
    // Session switching not implemented yet
    print('LUMARA Memory: Session switching not available in enhanced memory system');
  }

  /// Delete a conversation session
  /// Delete a specific message by ID
  Future<void> deleteMessage(String messageId) async {
    final currentState = state;
    if (currentState is! LumaraAssistantLoaded) return;

    // Remove message from state
    final updatedMessages = currentState.messages.where((m) => m.id != messageId).toList();
    
    emit(currentState.copyWith(
      messages: updatedMessages,
    ));

    // Try to delete from chat repo if it exists
    if (currentChatSessionId != null) {
      try {
        await _chatRepo.initialize();
        // Find the ChatMessage that corresponds to this LumaraMessage
        final chatMessages = await _chatRepo.getMessages(currentChatSessionId!, lazy: false);
        final matchingMessages = chatMessages.where((m) => m.id == messageId).toList();
        if (matchingMessages.isNotEmpty) {
          await _chatRepo.deleteMessage(messageId);
          print('LUMARA Chat: Deleted message $messageId from chat session');
        } else {
          print('LUMARA Chat: Message $messageId not found in chat repo (may be in-memory only)');
        }
      } catch (e) {
        print('LUMARA Chat: Error deleting message from chat repo: $e');
        // Continue anyway - message is already removed from UI
      }
    }

    print('LUMARA Debug: Deleted message $messageId (${updatedMessages.length} messages remaining)');
  }

  Future<void> deleteConversationSession(String sessionId) async {
    if (_memoryService == null) return;

    // TODO: Enhanced memory service manages sessions internally
    // Session deletion not implemented yet
    print('LUMARA Memory: Session deletion not available in enhanced memory system');
  }

  /// Handle reflective queries
  Future<void> _handleReflectiveQuery(
    InsightKind taskType,
    String query,
    List<LumaraMessage> updatedMessages,
    LumaraAssistantLoaded currentState,
  ) async {
    try {
      // Get circadian context for night mode
      final allEntries = await _journalRepository.getAllJournalEntries();
      final circadianService = CircadianProfileService();
      final circadianContext = await circadianService.compute(allEntries);
      final nightMode = circadianContext.window == 'evening' || 
                       DateTime.now().hour >= 22 || 
                       DateTime.now().hour < 7;

      String response;
      
      if (taskType == InsightKind.reflectiveHandledHard) {
        final result = await _reflectiveQueryService.queryHandledHard(
          userId: _userId,
          currentPhase: _currentPhase,
          nightMode: nightMode,
        );
        response = await _reflectiveFormatter.formatHandledHard(result);
      } else if (taskType == InsightKind.reflectiveTemporalStruggle) {
        final result = await _reflectiveQueryService.queryTemporalStruggle(
          userId: _userId,
          currentPhase: _currentPhase,
          nightMode: nightMode,
        );
        response = await _reflectiveFormatter.formatTemporalStruggle(result);
      } else if (taskType == InsightKind.reflectiveThemeSoftening) {
        final result = await _reflectiveQueryService.queryThemeSoftening(
          userId: _userId,
        );
        response = await _reflectiveFormatter.formatThemeSoftening(result);
      } else {
        response = 'I\'m not sure how to process that reflective query.';
      }

      // Record assistant response
      await _recordAssistantMessage(response);

      // Create assistant message
      final assistantMessage = LumaraMessage.assistant(content: response);

      // Add to chat session
      await _addToChatSession(response, 'assistant', 
          messageId: assistantMessage.id, 
          timestamp: assistantMessage.timestamp);

      // Speak response if voiceover enabled
      _speakResponseIfEnabled(response);

      emit(currentState.copyWith(
        messages: [...updatedMessages, assistantMessage],
        isProcessing: false,
        apiErrorMessage: null,
      ));
    } catch (e) {
      print('LUMARA ReflectiveQuery: Error: $e');
      final errorMessage = LumaraMessage.assistant(
        content: 'I encountered an error processing your reflective query. Please try again.',
      );
      emit(currentState.copyWith(
        messages: [...updatedMessages, errorMessage],
        isProcessing: false,
        apiErrorMessage: 'Error processing reflective query',
      ));
    }
  }

  /// Detect conversation mode from message text
  models.ConversationMode? _detectConversationModeFromText(String text) {
    final lowerText = text.toLowerCase();
    
    // Check for explicit mode requests
    if (lowerText.contains('regenerate') || lowerText.contains('different approach')) {
      return null; // Regenerate is handled separately
    }
    if (lowerText.contains('reflect more deeply') || lowerText.contains('more depth')) {
      return models.ConversationMode.reflectDeeply;
    }
    if (lowerText.contains('continue thought') || lowerText.contains('continue')) {
      return models.ConversationMode.continueThought;
    }
    if (lowerText.contains('suggest some ideas') || lowerText.contains('suggest ideas')) {
      return models.ConversationMode.ideas;
    }
    if (lowerText.contains('think this through') || lowerText.contains('think through')) {
      return models.ConversationMode.think;
    }
    if (lowerText.contains('different perspective') || lowerText.contains('another way')) {
      return models.ConversationMode.perspective;
    }
    if (lowerText.contains('suggest next steps') || lowerText.contains('next steps')) {
      return models.ConversationMode.nextSteps;
    }
    
    return null; // No mode detected, use default
  }

  /// Get memory statistics
  Future<Map<String, dynamic>> getMemoryStatistics() async {
    if (_memoryService != null) {
      try {
        return await _memoryService!.getMemoryStatistics();
      } catch (e) {
        print('LUMARA Memory: Error getting memory stats: $e');
      }
    }

    return <String, dynamic>{
      'total_nodes': 0,
      'active_domains': 0,
      'recent_activity': 0,
      'health_score': 0.0,
    };
  }

  /// Speak AI response if voiceover mode is enabled
  Future<void> _speakResponseIfEnabled(String response) async {
    try {
      final voiceoverEnabled = await VoiceoverPreferenceService.instance.isVoiceoverEnabled();
      if (voiceoverEnabled && _audioIO != null && response.isNotEmpty) {
        // Clean up the response text (remove markdown, extra whitespace, etc.)
        final cleanText = _cleanTextForSpeech(response);
        if (cleanText.isNotEmpty) {
          await _audioIO!.speak(cleanText);
        }
      }
    } catch (e) {
      print('LUMARA Debug: Error speaking response: $e');
      // Don't throw - voiceover is optional
    }
  }

  /// Clean text for speech (remove markdown, normalize whitespace)
  String _cleanTextForSpeech(String text) {
    // Remove markdown formatting
    String cleaned = text
        .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1') // Bold
        .replaceAll(RegExp(r'\*([^*]+)\*'), r'$1') // Italic
        .replaceAll(RegExp(r'`([^`]+)`'), r'$1') // Code
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1') // Links
        .replaceAll(RegExp(r'#{1,6}\s+'), '') // Headers
        .replaceAll(RegExp(r'\n{3,}'), '\n\n') // Multiple newlines
        .trim();
    
    return cleaned;
  }
}
