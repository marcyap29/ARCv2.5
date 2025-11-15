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
import 'package:my_app/polymeta/memory/enhanced_mira_memory_service.dart';
import 'package:my_app/polymeta/memory/enhanced_memory_schema.dart';
import 'package:my_app/polymeta/memory/sentence_extraction_util.dart';
import 'package:my_app/polymeta/mira_service.dart';
import 'package:my_app/telemetry/analytics.dart';
import '../chat/chat_repo.dart';
import '../chat/chat_repo_impl.dart';
import '../chat/chat_models.dart';
import '../chat/quickanswers_router.dart';
import 'package:my_app/polymeta/adapters/mira_basics_adapters.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import '../services/lumara_reflection_settings_service.dart';
import 'package:my_app/models/journal_entry_model.dart';

/// LUMARA Assistant Cubit State
abstract class LumaraAssistantState {}

class LumaraAssistantInitial extends LumaraAssistantState {}

class LumaraAssistantLoading extends LumaraAssistantState {}

class LumaraAssistantLoaded extends LumaraAssistantState {
  final List<LumaraMessage> messages;
  final LumaraScope scope;
  final bool isProcessing;
  final String? currentSessionId;

  LumaraAssistantLoaded({
    required this.messages,
    required this.scope,
    this.isProcessing = false,
    this.currentSessionId,
  });

  LumaraAssistantLoaded copyWith({
    List<LumaraMessage>? messages,
    LumaraScope? scope,
    bool? isProcessing,
    String? currentSessionId,
  }) {
    return LumaraAssistantLoaded(
      messages: messages ?? this.messages,
      scope: scope ?? this.scope,
      isProcessing: isProcessing ?? this.isProcessing,
      currentSessionId: currentSessionId ?? this.currentSessionId,
    );
  }
}

class LumaraAssistantError extends LumaraAssistantState {
  final String message;
  
  LumaraAssistantError(this.message);
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
  String? currentChatSessionId;
  
  // Quick Answers System
  QuickAnswersRouter? _quickAnswersRouter;
  
  // Progressive Memory Loader
  late final ProgressiveMemoryLoader _memoryLoader;
  final JournalRepository _journalRepository = JournalRepository();
  
  // Auto-save and compaction - Updated for 25-message summarization
  static const int _maxMessagesBeforeCompaction = 25;
  static const int _compactionThreshold = 25; // Summarize after 25 messages
  bool _isCompacting = false;

  LumaraAssistantCubit({
    required ContextProvider contextProvider,
  }) : _contextProvider = contextProvider,
       _llmAdapter = LLMAdapter(),
       _chatRepo = ChatRepoImpl.instance,
       super(LumaraAssistantInitial()) {
    // Initialize ArcLLM with Gemini integration
    _arcLLM = provideArcLLM();
    // Initialize enhanced LUMARA API
    _enhancedApi = EnhancedLumaraApi(_analytics);
    // Initialize progressive memory loader
    _memoryLoader = ProgressiveMemoryLoader(_journalRepository);
  }
  
  /// Initialize the assistant with parallel service loading
  Future<void> initialize() async {
    try {
      emit(LumaraAssistantLoading());

      // Parallelize independent service initializations
      final initializationResults = await Future.wait([
        _memoryLoader.initialize().then((_) => true).catchError((_) => false),
        _enhancedApi.initialize().then((_) => true).catchError((_) => false),
        _initializeMemorySystem().then((_) => true).catchError((_) => false),
        _chatRepo.initialize().then((_) => true).catchError((_) => false),
      ], eagerError: false);

      print('LUMARA: Parallel initialization completed: ${initializationResults.where((r) => r).length}/4 services successful');

      // Lazy-load quick answers (only when user types a question)
      // Quick answers are now loaded on-demand instead of during initialization
      
      // Start with default scope
      const scope = LumaraScope.defaultScope;

      // API key configuration is now handled by LumaraAPIConfig

      // Start or resume a conversation session
      final sessionId = await _getOrCreateSession();

      // Add welcome message and record it in memory
      final welcomeContent = "Hello! I'm LUMARA, your personal assistant. I can help you understand your patterns, explain your current phase, and provide insights about your journey. What would you like to know?";

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
  
  /// Send a message to LUMARA
  Future<void> sendMessage(String text, {JournalEntry? currentEntry}) async {
    if (text.trim().isEmpty) return;

    final currentState = state;
    if (currentState is! LumaraAssistantLoaded) return;

    print('LUMARA Debug: Sending message: "$text"');
    print('LUMARA Debug: Current message count: ${currentState.messages.length}');

    // Check for memory commands
    if (text.startsWith('/memory')) {
      await _handleMemoryCommand(text);
      return;
    }

    // Check for quick answers (phase, themes, streak, etc.) - INSTANT response
    // SKIPPED - Use Enhanced API with semantic search for all questions instead
    // final quickAnswer = await _tryQuickAnswer(text);
    // if (quickAnswer != null) {
    //   // Add user message to UI
    //   final userMessage = LumaraMessage.user(content: text);
    //   final updatedMessages = [...currentState.messages, userMessage];
    //   
    //   // Add quick answer
    //   final assistantMessage = LumaraMessage.assistant(content: quickAnswer);
    //   final finalMessages = [...updatedMessages, assistantMessage];
    //   
    //   emit(currentState.copyWith(
    //     messages: finalMessages,
    //     isProcessing: false,
    //   ));
    //   return;
    // }
    print('LUMARA Debug: Skipping quick answers - using Enhanced API with semantic search for all questions');

    // Ensure we have an active chat session (auto-create if needed)
    await _ensureActiveChatSession(text);

    // Record user message in MCP memory first
    await _recordUserMessage(text);
    
    // Add user message to chat session
    await _addToChatSession(text, 'user');

    // Add user message to UI
    final userMessage = LumaraMessage.user(content: text);
    final updatedMessages = [...currentState.messages, userMessage];

    print('LUMARA Debug: Added user message, new count: ${updatedMessages.length}');

    emit(currentState.copyWith(
      messages: updatedMessages,
      isProcessing: true,
    ));

    try {
      // Get provider status from LumaraAPIConfig (the authoritative source)
      final apiConfig = LumaraAPIConfig.instance;
      await apiConfig.initialize();
      final availableProviders = apiConfig.getAvailableProviders();
      final bestProvider = apiConfig.getBestProvider();
      final onDeviceAvailable = LLMAdapter.isAvailable;

      print('LUMARA Debug: Provider Status Summary:');
      print('LUMARA Debug:   - On-Device (Qwen): ${onDeviceAvailable ? "AVAILABLE ✓" : "Not Available (${LLMAdapter.reason})"}');
      print('LUMARA Debug:   - Cloud API (Gemini): ${availableProviders.any((p) => p.name == 'Google Gemini') ? "AVAILABLE ✓" : "Not Available (no API key)"}');
      print('LUMARA Debug: Security-first fallback chain: On-Device → Cloud API → Rule-Based');

      // Check if user has manually selected a provider
      final currentProvider = _enhancedApi.getCurrentProvider();
      
      // If current provider is the same as the best provider, treat as automatic mode
      final isManualSelection = currentProvider != bestProvider?.name;
      
      print('LUMARA Debug: Current provider: ${currentProvider ?? 'none'}');
      print('LUMARA Debug: Best provider: ${bestProvider?.name ?? 'none'}');
      print('LUMARA Debug: Is manual selection: $isManualSelection');

      // PRIORITY 1: Use Gemini with full journal context (ArcLLM chat)
      try {
        print('LUMARA Debug: [Priority 1] Attempting Gemini with journal context...');
        
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
        
        // Use ArcLLM to call Gemini directly with all journal context
        final response = await _arcLLM.chat(
          userIntent: text,
          entryText: entryText,
          phaseHintJson: phaseHint,
          lastKeywordsJson: keywords,
        );
        
        print('LUMARA Debug: [Gemini] ✓ Response received, length: ${response.length}');
        
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
        
        // Add assistant response to chat session
        await _addToChatSession(enhancedResponse, 'assistant');
        
        // Add assistant response to UI with attribution traces
        final assistantMessage = LumaraMessage.assistant(
          content: enhancedResponse,
          attributionTraces: attributionTraces,
        );
        
        // Check if we should suggest loading more history
        var finalMessages = [...updatedMessages, assistantMessage];
        
        if (hasMoreHistory() && _queryNeedsMoreHistory(text)) {
          final suggestionMsg = _generateLoadMoreSuggestionMessage();
          if (suggestionMsg.isNotEmpty) {
            final suggestionMessage = LumaraMessage.system(content: suggestionMsg);
            finalMessages = [...finalMessages, suggestionMessage];
          }
        }
        
        emit(currentState.copyWith(
          messages: finalMessages,
          isProcessing: false,
        ));
        
        print('LUMARA Debug: [Gemini] Complete - personalized response generated');
        return; // Exit early - Gemini succeeded
      } catch (e) {
        print('LUMARA Debug: [Gemini] Failed: $e');
        print('LUMARA Debug: Falling back to on-device or Gemini streaming...');
      }
      
      // PRIORITY 2: Try On-Device fallback (security-first, unless manually overridden)
      if (!isManualSelection) {
        try {
          print('LUMARA Debug: [Priority 2] Attempting on-device LLMAdapter...');

          // Initialize LLMAdapter if not already done
          if (!LLMAdapter.isReady) {
            debugPrint('[LumaraAssistantCubit] invoking LLMAdapter.initialize(...)');
            await LLMAdapter.initialize();
            debugPrint('[LumaraAssistantCubit] LLMAdapter.initialize completed (isAvailable=${LLMAdapter.isAvailable}, reason=${LLMAdapter.reason})');
          }

          // Check if on-device is available
          if (LLMAdapter.isAvailable) {
            print('LUMARA Debug: [On-Device] LLMAdapter available! Using on-device processing.');

          // Use non-streaming on-device processing
          final responseData = await _processMessageWithAttribution(
            text, 
            currentState.scope,
            currentEntry: currentEntry,
          );
          print('LUMARA Debug: [On-Device] SUCCESS - Response length: ${responseData['content'].length}');
          print('LUMARA Debug: [On-Device] Attribution traces: ${responseData['attributionTraces']?.length ?? 0}');

          // Get context for phase info (using current scope from state)
          final context = await _contextProvider.buildContext(scope: currentState.scope);
          var attributionTraces = responseData['attributionTraces'] as List<AttributionTrace>? ?? [];
          
          // Enrich attribution traces with actual journal entry content
          if (attributionTraces.isNotEmpty) {
            attributionTraces = await _enrichAttributionTraces(attributionTraces);
            print('LUMARA Debug: [On-Device] Enriched ${attributionTraces.length} attribution traces with journal entry content');
          }
          
          final enhancedContent = _appendPhaseInfoFromAttributions(
            responseData['content'],
            attributionTraces,
            context,
          );

          // Record assistant response in MCP memory
          await _recordAssistantMessage(enhancedContent);

          // Add assistant response to chat session
          await _addToChatSession(enhancedContent, 'assistant');

          // Add assistant response to UI with attribution traces
          final assistantMessage = LumaraMessage.assistant(
            content: enhancedContent,
            attributionTraces: attributionTraces,
          );
          final finalMessages = [...updatedMessages, assistantMessage];

          emit(currentState.copyWith(
            messages: finalMessages,
            isProcessing: false,
          ));

            print('LUMARA Debug: [On-Device] On-device processing complete - skipping cloud API');
            return; // Exit early - on-device succeeded
          } else {
            print('LUMARA Debug: [On-Device] LLMAdapter not available, reason: ${LLMAdapter.reason}');
            print('LUMARA Debug: [Priority 2] Falling back to Cloud API...');
          }
        } catch (e) {
          print('LUMARA Debug: [On-Device] Error: $e');
          print('LUMARA Debug: [Priority 2] Falling back to Cloud API...');
        }
      } else {
            print('LUMARA Debug: [Manual Selection] Using manually selected provider: ${currentProvider}');
        print('LUMARA Debug: [Priority 2] Falling back to Cloud API...');
      }

      // PRIORITY 2: Fall back to Cloud API (streaming if available)
      final geminiAvailable = availableProviders.any((p) => p.name == 'Google Gemini');
      final useStreaming = geminiAvailable;

      if (useStreaming) {
        print('LUMARA Debug: [Cloud API] Using streaming (Gemini API available)');

        // Create placeholder message for streaming with attribution traces
        // Note: Attribution traces will be added after streaming completes
        final streamingMessage = LumaraMessage.assistant(
          content: '',
          attributionTraces: [], // Will be populated after streaming
        );
        final messagesWithPlaceholder = [...updatedMessages, streamingMessage];

        emit(currentState.copyWith(
          messages: messagesWithPlaceholder,
          isProcessing: true,
        ));

        // Stream the response
        await _processMessageWithStreaming(text, currentState.scope, updatedMessages);
      } else {
        print('LUMARA Debug: [Cloud API] No API key - using non-streaming approach');

        // Fall back to non-streaming approach (will use rule-based if no API)
        final responseData = await _processMessageWithAttribution(text, currentState.scope);
        print('LUMARA Debug: Generated response length: ${responseData['content'].length}');
        print('LUMARA Debug: Attribution traces in response: ${responseData['attributionTraces']?.length ?? 0}');

        // Get context for phase info (using current scope from state)
        final context = await _contextProvider.buildContext(scope: currentState.scope);
        var attributionTraces = responseData['attributionTraces'] as List<AttributionTrace>? ?? [];
        
        // Enrich attribution traces with actual journal entry content
        if (attributionTraces.isNotEmpty) {
          attributionTraces = await _enrichAttributionTraces(attributionTraces);
          print('LUMARA Debug: Enriched ${attributionTraces.length} attribution traces with journal entry content');
        }
        
        final enhancedContent = _appendPhaseInfoFromAttributions(
          responseData['content'],
          attributionTraces,
          context,
        );

        // Record assistant response in MCP memory
        await _recordAssistantMessage(enhancedContent);

        // Add assistant response to chat session
        await _addToChatSession(enhancedContent, 'assistant');

        // Add assistant response to UI with attribution traces
        print('LUMARA Debug: Creating assistant message with ${attributionTraces.length} attribution traces');

        final assistantMessage = LumaraMessage.assistant(
          content: enhancedContent,
          attributionTraces: attributionTraces,
        );
        final finalMessages = [...updatedMessages, assistantMessage];

        print('LUMARA Debug: Added assistant message, final count: ${finalMessages.length}');

        emit(currentState.copyWith(
          messages: finalMessages,
          isProcessing: false,
        ));
      }
    } catch (e) {
      print('LUMARA Debug: Error processing message: $e');

      // Add error message to UI
      final errorMessage = LumaraMessage.assistant(
        content: "I'm sorry, I encountered an error processing your request. Please try again.",
      );

      // Record error in memory too
      await _recordAssistantMessage(errorMessage.content);

      final finalMessages = [...updatedMessages, errorMessage];

      emit(currentState.copyWith(
        messages: finalMessages,
        isProcessing: false,
      ));
    }
  }
  
  /// Process a message and generate response with attribution
  /// Priority: On-Device → Cloud API → Rule-Based (security-first)
  Future<Map<String, dynamic>> _processMessageWithAttribution(
    String text, 
    LumaraScope scope, {
    JournalEntry? currentEntry,
  }) async {
    // Get context (using provided scope)
    final context = await _contextProvider.buildContext(scope: scope);

    // Determine task type based on query
    final task = _determineTaskType(text);

    // Debug logging
    print('LUMARA Debug: Query: "$text" -> Task: ${task.name}');
    print('LUMARA Debug: Fallback priority: Enhanced API (with Gemini) → Direct Gemini → Rule-Based');

    // Memory retrieval will be handled in response generation

    // PRIORITY 1: Try Enhanced API with semantic search (uses Gemini under the hood)
    try {
      debugPrint('LUMARA Debug: ========== STARTING GEMINI PATH ==========');
      print('LUMARA Debug: [Gemini] Calling Gemini with journal context...');
      
      final contextResult = await _buildEntryContext(
        context, 
        userQuery: text,
        currentEntry: currentEntry,
      );
      final entryText = contextResult['context'] as String;
      final contextAttributionTraces = contextResult['attributionTraces'] as List<AttributionTrace>;
      final phaseHint = _buildPhaseHint(context);
      final keywords = _buildKeywordsContext(context);
      
      print('LUMARA Debug: [Gemini] Entry text length: ${entryText.length}');
      print('LUMARA Debug: [Gemini] Phase hint: $phaseHint');
      print('LUMARA Debug: [Gemini] Keywords: $keywords');
      print('LUMARA Debug: [Gemini] Attribution traces from context: ${contextAttributionTraces.length}');

      // Use ArcLLM to call Gemini directly with journal context
      final response = await _arcLLM.chat(
        userIntent: text,
        entryText: entryText,
        phaseHintJson: phaseHint,
        lastKeywordsJson: keywords,
      );

      print('LUMARA Debug: [Gemini] ✓ Response received, length: ${response.length}');

      // Use attribution traces from context building (the actual memory nodes used)
      final traces = contextAttributionTraces;
      print('LUMARA Debug: [Enhanced API] Using ${traces.length} attribution traces from context building');
      
      // Append phase information from attribution traces
      final enhancedResponse = _appendPhaseInfoFromAttributions(response, traces, context);
      return {
        'content': enhancedResponse,
        'attributionTraces': traces,
      };
    } catch (e, stackTrace) {
      debugPrint('LUMARA Debug: [Enhanced API] ✗✗✗ EXCEPTION CAUGHT ✗✗✗');
      debugPrint('LUMARA Debug: [Enhanced API] Exception type: ${e.runtimeType}');
      debugPrint('LUMARA Debug: [Enhanced API] Exception: $e');
      debugPrint('LUMARA Debug: [Enhanced API] Stack trace: $stackTrace');
      print('LUMARA Debug: [Enhanced API] Failed: $e');
    }

    // PRIORITY 2: Try Direct Gemini API fallback
    try {
      // Get API key from LumaraAPIConfig instead of environment variable
      debugPrint('LUMARA Debug: ========== STARTING GEMINI API PATH ==========');
      
      debugPrint('LUMARA Debug: [Gemini] Step 1: Initializing API config...');
      final apiConfig = LumaraAPIConfig.instance;
      await apiConfig.initialize();
      debugPrint('LUMARA Debug: [Gemini] Step 1: ✓ API config initialized');
      
      debugPrint('LUMARA Debug: [Gemini] Step 2: Getting Gemini config...');
      final geminiConfig = apiConfig.getConfig(LLMProvider.gemini);
      final apiKey = geminiConfig?.apiKey ?? '';
      debugPrint('LUMARA Debug: [Gemini] Step 2: Config exists: ${geminiConfig != null}');
      debugPrint('LUMARA Debug: [Gemini] Step 2: API key present: ${apiKey.isNotEmpty}');
      debugPrint('LUMARA Debug: [Gemini] Step 2: API key length: ${apiKey.length}');
      debugPrint('LUMARA Debug: [Gemini] Step 2: Config isAvailable: ${geminiConfig?.isAvailable}');
      
      if (apiKey.isEmpty) {
        debugPrint('LUMARA Debug: [Gemini] Step 2: ✗ FAILED - API key is empty');
        throw Exception('Gemini API key is empty');
      }
      debugPrint('LUMARA Debug: [Gemini] Step 2: ✓ API key validated');
      
      debugPrint('LUMARA Debug: [Gemini] Step 3: Building context for ArcLLM...');
      // Build context for ArcLLM
      final contextResult = await _buildEntryContext(
        context, 
        userQuery: text,
        currentEntry: currentEntry,
      );
      final entryText = contextResult['context'] as String;
      final contextAttributionTraces = contextResult['attributionTraces'] as List<AttributionTrace>;
      final phaseHint = _buildPhaseHint(context);
      final keywords = _buildKeywordsContext(context);
      debugPrint('LUMARA Debug: [Gemini] Step 3: Context built');
      debugPrint('LUMARA Debug: [Gemini] Step 3: Entry text length: ${entryText.length}');
      debugPrint('LUMARA Debug: [Gemini] Step 3: Phase hint: $phaseHint');
      debugPrint('LUMARA Debug: [Gemini] Step 3: Keywords: $keywords');
      debugPrint('LUMARA Debug: [Gemini] Step 3: Attribution traces from context: ${contextAttributionTraces.length}');

      debugPrint('LUMARA Debug: [Gemini] Step 4: Calling _arcLLM.chat()...');
      debugPrint('LUMARA Debug: [Gemini] Step 4: User intent: $text');
      // Use ArcLLM chat function with context
      final response = await _arcLLM.chat(
        userIntent: text,
        entryText: entryText,
        phaseHintJson: phaseHint,
        lastKeywordsJson: keywords,
      );

      debugPrint('LUMARA Debug: [Gemini] Step 4: ✓ Response received');
      debugPrint('LUMARA Debug: [Gemini] Step 4: Response length: ${response.length}');
      debugPrint('LUMARA Debug: [Gemini] Step 4: Response preview: ${response.substring(0, response.length > 100 ? 100 : response.length)}...');

      if (response.isNotEmpty) {
        debugPrint('LUMARA Debug: [Gemini] SUCCESS - Using Gemini response');
        
        // Use attribution traces from context building (the actual memory nodes used)
        final traces = contextAttributionTraces;
        print('LUMARA Debug: Using ${traces.length} attribution traces from context building');
        for (final trace in traces) {
          print('LUMARA Debug: Trace - ${trace.nodeRef}: ${trace.relation} (${(trace.confidence * 100).toInt()}%)');
        }

        debugPrint('LUMARA Debug: ========== GEMINI API PATH COMPLETED ==========');
        // Append phase information from attribution traces
        final enhancedResponse = _appendPhaseInfoFromAttributions(response, traces, context);
        return {
          'content': enhancedResponse,
          'attributionTraces': traces,
        };
      }
      
      debugPrint('LUMARA Debug: [Gemini] ✗ FAILED - Empty response received');
    } catch (e, stackTrace) {
      debugPrint('LUMARA Debug: [Gemini] ✗✗✗ EXCEPTION CAUGHT ✗✗✗');
      debugPrint('LUMARA Debug: [Gemini] Exception type: ${e.runtimeType}');
      debugPrint('LUMARA Debug: [Gemini] Exception message: $e');
      debugPrint('LUMARA Debug: [Gemini] Stack trace: $stackTrace');
    }


    // No providers available - return clear guidance
    print('LUMARA Debug: All providers failed. No inference available.');
    return {
      'content': 'LUMARA needs an AI provider to respond. Please either download an on-device model or configure a cloud API key in Settings. Once configured, LUMARA will be able to provide intelligent reflections.',
      'attributionTraces': <AttributionTrace>[],
    };
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
    List<LumaraMessage> baseMessages,
  ) async {
    // Get context (using provided scope)
    final context = await _contextProvider.buildContext(scope: scope);

    // Build context for streaming
    // Extract user query from baseMessages (last user message)
    final userQuery = baseMessages.lastWhere(
      (m) => m.role == 'user',
      orElse: () => baseMessages.isNotEmpty ? baseMessages.last : LumaraMessage.user(content: ''),
    ).content;
    
      final contextResult = await _buildEntryContext(
        context, 
        userQuery: userQuery,
        currentEntry: null, // Streaming doesn't have current entry context
      );
      final entryText = contextResult['context'] as String;
      final contextAttributionTraces = contextResult['attributionTraces'] as List<AttributionTrace>;
    final phaseHint = _buildPhaseHint(context);
    final keywords = _buildKeywordsContext(context);

    // Build system prompt
    final systemPrompt = _buildSystemPrompt(entryText, phaseHint, keywords);

    print('LUMARA Debug: Starting streaming response...');
    print('LUMARA Debug: Using direct Gemini streaming with journal context');
    print('LUMARA Debug: Attribution traces from context: ${contextAttributionTraces.length}');

    // Stream the response from Gemini with journal context
    final fullResponse = StringBuffer();

    try {
      // Stream the response from Gemini
      await for (final chunk in geminiSendStream(
        system: systemPrompt,
        user: text,
      )) {
        fullResponse.write(chunk);

        // Update the UI with the streaming content
        final currentMessages = state is LumaraAssistantLoaded
            ? (state as LumaraAssistantLoaded).messages
            : baseMessages;

        if (currentMessages.isNotEmpty) {
          final lastIndex = currentMessages.length - 1;
          // Preserve attribution traces during streaming updates
          final existingTraces = currentMessages[lastIndex].attributionTraces;
          final updatedMessage = currentMessages[lastIndex].copyWith(
            content: fullResponse.toString(),
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
      }

      print('LUMARA Debug: Streaming completed, total length: ${fullResponse.length}');

      final finalContent = fullResponse.toString();

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

      // Add assistant response to chat session
      await _addToChatSession(enhancedContent, 'assistant');

      // Update final message with attribution traces
      if (state is LumaraAssistantLoaded) {
        final currentMessages = (state as LumaraAssistantLoaded).messages;
        if (currentMessages.isNotEmpty) {
          final lastIndex = currentMessages.length - 1;
          final finalMessage = currentMessages[lastIndex].copyWith(
            content: enhancedContent,
            attributionTraces: attributionTraces,
          );

          final finalMessages = [
            ...currentMessages.sublist(0, lastIndex),
            finalMessage,
          ];

          print('LUMARA Debug: Streaming complete with ${attributionTraces.length} attribution traces');

          emit((state as LumaraAssistantLoaded).copyWith(
            messages: finalMessages,
            isProcessing: false,
          ));
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
        
        // Only show full error message if we have no partial response
        final errorMessage = LumaraMessage.assistant(
          content: "I'm sorry, I encountered an error while streaming the response. Please try again.",
        );

        final finalMessages = [...baseMessages, errorMessage];

        emit((state as LumaraAssistantLoaded).copyWith(
          messages: finalMessages,
          isProcessing: false,
        ));
      }
    }
  }

  /// Build system prompt for streaming
  String _buildSystemPrompt(String? entryText, String? phaseHint, String? keywords) {
    final buffer = StringBuffer();

    buffer.writeln('You are LUMARA, a compassionate personal assistant for the EPI journaling app.');
    buffer.writeln('Provide thoughtful, dignified responses that honor the user\'s experiences.');

    if (phaseHint != null) {
      buffer.writeln('\nUser\'s current phase context: $phaseHint');
    }

    if (entryText != null && entryText.isNotEmpty) {
      buffer.writeln('\nRecent journal entries:\n$entryText');
    }

    if (keywords != null) {
      buffer.writeln('\nRecent keywords: $keywords');
    }

    return buffer.toString();
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

    // Remove all messages from this one onwards (including the assistant response)
    final messagesToKeep = currentState.messages.sublist(0, messageIndex);
    
    // Update the message with new text
    final updatedMessages = [
      ...messagesToKeep,
      currentState.messages[messageIndex].copyWith(content: newText),
    ];

    // Update state to remove assistant response
    emit(currentState.copyWith(messages: updatedMessages));
  }
  
  /// Start a new chat (saves current chat to history, then clears UI)
  Future<void> startNewChat() async {
    final currentState = state;
    if (currentState is! LumaraAssistantLoaded) {
      // If not loaded, just initialize
      await initialize();
      return;
    }
    
    // Save current chat session to history if it exists and has messages
    if (currentChatSessionId != null && currentState.messages.isNotEmpty) {
      try {
        await _chatRepo.initialize();
        final session = await _chatRepo.getSession(currentChatSessionId!);
        if (session != null) {
          // Ensure session is up-to-date (messages are already saved via _addToChatSession)
          // Update timestamp one final time to mark session as complete
          // Using renameSession with same subject updates the timestamp
          await _chatRepo.renameSession(currentChatSessionId!, session.subject);
          print('LUMARA Chat: Finalized session $currentChatSessionId before starting new chat');
        }
      } catch (e) {
        print('LUMARA Chat: Error finalizing session: $e');
        // Continue anyway - messages should already be saved
      }
    }
    
    // Reset session ID to force new session on next message
    currentChatSessionId = null;
    
    // Create welcome message for new chat (clears the old chat in the UI)
    const welcomeContent = "Hello! I'm LUMARA, your personal assistant. I can help you understand your patterns, explain your current phase, and provide insights about your journey. What would you like to know?";
    
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
              final allEntries = _journalRepository.getAllJournalEntries();
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
          recentCount++;
        }
      }
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
            final allEntries = _journalRepository.getAllJournalEntries();
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
  Future<void> _addToChatSession(String content, String role) async {
    if (currentChatSessionId == null) return;
    
    try {
      // Ensure ChatRepo is initialized before use
      await _chatRepo.initialize();
      
      await _chatRepo.addMessage(
        sessionId: currentChatSessionId!,
        role: role,
        content: content,
      );
      print('LUMARA Chat: Added $role message to session $currentChatSessionId');
      
      // Check if compaction is needed
      await _checkAndCompactIfNeeded();
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
      // Get the first 25 messages to summarize and archive
      final messagesToArchive = messages.take(25).toList();
      
      if (messagesToArchive.isEmpty) return;
      
      // Emit a state to show popup/notice while summarizing
      if (state is LumaraAssistantLoaded) {
        final currentState = state as LumaraAssistantLoaded;
        emit(currentState.copyWith(
          isProcessing: true,
        ));
      }
      
      print('LUMARA Chat: Summarizing first 25 messages...');
      
      // Create summary of the first 25 messages using Gemini
      final summary = await _createConversationSummaryWithLLM(messagesToArchive);
      
      // Create a summary message
      final summaryMessage = ChatMessage.createLegacy(
        sessionId: currentChatSessionId!,
        role: 'system',
        content: '📝 **Conversation Summary** (First 25 messages archived)\n\n$summary',
      );
      
      // Archive the first 25 messages by deleting them (they're preserved in MCP memory)
      await _archiveMessages(messagesToArchive);
      
      // Add the summary message at the beginning
      await _chatRepo.addMessage(
        sessionId: currentChatSessionId!,
        role: 'system',
        content: summaryMessage.textContent,
      );
      
      print('LUMARA Chat: Archived ${messagesToArchive.length} messages and created summary');
      
      // Clear working memory context (reload context without archived messages)
      // This happens automatically when we reload messages
      
      // Show notification to user
      _showCompactionNotification(messagesToArchive.length);
      
      // Resume processing
      if (state is LumaraAssistantLoaded) {
        final currentState = state as LumaraAssistantLoaded;
        emit(currentState.copyWith(
          isProcessing: false,
        ));
      }
      
    } catch (e) {
      print('LUMARA Chat: Error compacting conversation: $e');
      if (state is LumaraAssistantLoaded) {
        final currentState = state as LumaraAssistantLoaded;
        emit(currentState.copyWith(
          isProcessing: false,
        ));
      }
    } finally {
      _isCompacting = false;
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
  Future<void> deleteConversationSession(String sessionId) async {
    if (_memoryService == null) return;

    // TODO: Enhanced memory service manages sessions internally
    // Session deletion not implemented yet
    print('LUMARA Memory: Session deletion not available in enhanced memory system');
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

  /// Initialize Quick Answers System
  Future<void> _initializeQuickAnswers() async {
    try {
      final basicsProvider = await MiraBasicsFactory.createProvider();
      _quickAnswersRouter = QuickAnswersRouter(
        basicsProvider: basicsProvider,
        llm: _llmAdapter,
      );
      print('LUMARA Debug: Quick Answers System initialized');
    } catch (e) {
      print('LUMARA Debug: Error initializing Quick Answers: $e');
      // Continue without quick answers - not critical
    }
  }

  /// Try to get a quick answer for basic questions (lazy-loads quick answers on first use)
  Future<String?> _tryQuickAnswer(String text) async {
    // Lazy-load quick answers on first use
    if (_quickAnswersRouter == null) {
      await _initializeQuickAnswers();
    }
    
    if (_quickAnswersRouter == null) return null;
    
    try {
      return await _quickAnswersRouter!.handleUserMessage(text);
    } catch (e) {
      print('LUMARA Debug: Error in quick answers: $e');
      return null;
    }
  }
}
