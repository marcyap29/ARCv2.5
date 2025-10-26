import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/lumara/data/context_scope.dart';
import 'package:my_app/lumara/data/context_provider.dart';
import 'package:my_app/lumara/data/models/lumara_message.dart';
import 'package:my_app/lumara/llm/llm_adapter.dart';
import 'package:my_app/lumara/llm/rule_based_adapter.dart'; // For InsightKind enum
import 'package:my_app/services/gemini_send.dart';
import 'package:my_app/services/llm_bridge_adapter.dart';
import '../services/enhanced_lumara_api.dart';
import '../config/api_config.dart';
import '../../mira/memory/enhanced_mira_memory_service.dart';
import '../../mira/memory/enhanced_memory_schema.dart';
import '../../mira/mira_service.dart';
import '../../telemetry/analytics.dart';
import '../chat/chat_repo.dart';
import '../chat/chat_repo_impl.dart';
import '../chat/chat_models.dart';
import '../chat/quickanswers_router.dart';
import '../../mira/adapters/mira_basics_adapters.dart';

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
  
  // Auto-save and compaction
  static const int _maxMessagesBeforeCompaction = 50;
  static const int _compactionThreshold = 100;
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
  }
  
  /// Initialize the assistant
  Future<void> initialize() async {
    try {
      emit(LumaraAssistantLoading());

      // Initialize enhanced LUMARA API
      await _enhancedApi.initialize();

      // Initialize MCP Memory System
      await _initializeMemorySystem();
      
      // Initialize Chat History System
      await _chatRepo.initialize();

      // Initialize Quick Answers System
      await _initializeQuickAnswers();

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
  Future<void> sendMessage(String text) async {
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
    final quickAnswer = await _tryQuickAnswer(text);
    if (quickAnswer != null) {
      // Add user message to UI
      final userMessage = LumaraMessage.user(content: text);
      final updatedMessages = [...currentState.messages, userMessage];
      
      // Add quick answer
      final assistantMessage = LumaraMessage.assistant(content: quickAnswer);
      final finalMessages = [...updatedMessages, assistantMessage];
      
      emit(currentState.copyWith(
        messages: finalMessages,
        isProcessing: false,
      ));
      return;
    }

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

      // PRIORITY 1: Try On-Device first (security-first, unless manually overridden)
      if (!isManualSelection) {
        try {
          print('LUMARA Debug: [Priority 1] Attempting on-device LLMAdapter...');

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
          final responseData = await _processMessageWithAttribution(text, currentState.scope);
          print('LUMARA Debug: [On-Device] SUCCESS - Response length: ${responseData['content'].length}');
          print('LUMARA Debug: [On-Device] Attribution traces: ${responseData['attributionTraces']?.length ?? 0}');

          // Record assistant response in MCP memory
          await _recordAssistantMessage(responseData['content']);

          // Add assistant response to chat session
          await _addToChatSession(responseData['content'], 'assistant');

          // Add assistant response to UI with attribution traces
          final assistantMessage = LumaraMessage.assistant(
            content: responseData['content'],
            attributionTraces: responseData['attributionTraces'] ?? [],
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

        // Create placeholder message for streaming
        final streamingMessage = LumaraMessage.assistant(content: '');
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

        // Record assistant response in MCP memory
        await _recordAssistantMessage(responseData['content']);

        // Add assistant response to chat session
        await _addToChatSession(responseData['content'], 'assistant');

        // Add assistant response to UI with attribution traces
        final attributionTraces = responseData['attributionTraces'] as List<AttributionTrace>?;
        print('LUMARA Debug: Creating assistant message with ${attributionTraces?.length ?? 0} attribution traces');

        final assistantMessage = LumaraMessage.assistant(
          content: responseData['content'],
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
  Future<Map<String, dynamic>> _processMessageWithAttribution(String text, LumaraScope scope) async {
    // Get context
    final context = await _contextProvider.buildContext();

    // Determine task type based on query
    final task = _determineTaskType(text);

    // Debug logging
    print('LUMARA Debug: Query: "$text" -> Task: ${task.name}');
    print('LUMARA Debug: Fallback priority: On-Device → Cloud API → Rule-Based');

    // Memory retrieval will be handled in response generation

    // PRIORITY 1: Try on-device LLMAdapter first (privacy-first, security-first)
    try {
      print('LUMARA Debug: [Priority 1] Attempting on-device LLM...');

      // Initialize LLMAdapter if not already done
      if (!LLMAdapter.isReady) {
        debugPrint('[LumaraAssistantCubit] invoking LLMAdapter.initialize(...)');
        final initialized = await LLMAdapter.initialize();
        debugPrint('[LumaraAssistantCubit] LLMAdapter.initialize completed (isAvailable=${LLMAdapter.isAvailable}, reason=${LLMAdapter.reason})');
        if (!initialized) {
          print('LUMARA Debug: [On-Device] LLMAdapter not available, reason: ${LLMAdapter.reason}');
          throw Exception('LLMAdapter not available: ${LLMAdapter.reason}');
        }
      }

      // Use LLMAdapter for on-device generation
      final responseStream = _llmAdapter.realize(
        task: _mapTaskToString(task),
        facts: _buildFactsFromContextWindow(context),
        snippets: _buildSnippetsFromContextWindow(context),
        chat: _buildChatHistoryFromContextWindow(context),
      );
      
      // Collect all streamed words into complete response
      String llmResponse = '';
      await for (final word in responseStream) {
        llmResponse += word;
      }

      print('LUMARA Debug: [On-Device] SUCCESS - Response length: ${llmResponse.length}');

      return {
        'content': llmResponse,
        'attributionTraces': <AttributionTrace>[],
      };
    } catch (onDeviceError) {
      print('LUMARA Debug: [On-Device] Failed: $onDeviceError');
      print('LUMARA Debug: [Priority 2] Falling back to Cloud API...');
    }

    // PRIORITY 2: Try Cloud API if on-device failed
    try {
      // Get API key from LumaraAPIConfig instead of environment variable
      final apiConfig = LumaraAPIConfig.instance;
      await apiConfig.initialize();
      final geminiConfig = apiConfig.getConfig(LLMProvider.gemini);
      final apiKey = geminiConfig?.apiKey ?? '';
      
      if (apiKey.isNotEmpty) {
        print('LUMARA Debug: [Cloud API] Using Gemini API for response generation');
        
        // Build context for ArcLLM
        final entryText = _buildEntryContext(context);
        final phaseHint = _buildPhaseHint(context);
        final keywords = _buildKeywordsContext(context);

        // Use ArcLLM chat function with context
        final response = await _arcLLM.chat(
          userIntent: text,
          entryText: entryText,
          phaseHintJson: phaseHint,
          lastKeywordsJson: keywords,
        );

        print('LUMARA Debug: Direct Gemini API response length: ${response.length}');

        // Generate explainable response with attribution if memory service available
        if (_memoryService != null) {
          try {
            final responseId = 'resp_${DateTime.now().millisecondsSinceEpoch}';
            print('LUMARA Debug: Retrieving memories for query: "$text"');
            
            final memoryResult = await _memoryService!.retrieveMemories(
              query: text,
              domains: [MemoryDomain.personal, MemoryDomain.creative, MemoryDomain.learning],
              responseId: responseId,
            );
            
            print('LUMARA Debug: Retrieved ${memoryResult.nodes.length} memory nodes');
            print('LUMARA Debug: Retrieved ${memoryResult.attributions.length} attribution traces from memory service');

            if (memoryResult.nodes.isEmpty) {
              print('LUMARA Debug: ⚠️ NO MEMORY NODES RETRIEVED - This is why no attribution data is generated');
            } else {
              for (final node in memoryResult.nodes) {
                print('LUMARA Debug: Memory node - ID: ${node.id}, Content: ${node.narrative.substring(0, node.narrative.length > 50 ? 50 : node.narrative.length)}...');
              }
            }

            // Use attribution traces directly from memory retrieval result
            final traces = memoryResult.attributions;

            print('LUMARA Debug: Using ${traces.length} attribution traces from memory retrieval');
            for (final trace in traces) {
              print('LUMARA Debug: Trace - ${trace.nodeRef}: ${trace.relation} (${(trace.confidence * 100).toInt()}%)');
            }

            return {
              'content': response,
              'attributionTraces': traces,
            };
          } catch (e) {
            print('LUMARA Memory: Error generating explainable response: $e');
          }
        }

        return {
          'content': response,
          'attributionTraces': <AttributionTrace>[],
        };
      } else {
        print('LUMARA Debug: [Cloud API] No Gemini API key, trying Enhanced LUMARA API');

        // Try enhanced LUMARA API with multi-provider support
        final entryText = _buildEntryContext(context);
        final phaseHint = _buildPhaseHint(context);

        // Use enhanced API for response generation
        final response = await _enhancedApi.generatePromptedReflection(
          entryText: entryText,
          intent: _mapTaskToIntent(task),
          phase: phaseHint,
        );

        print('LUMARA Debug: [Cloud API] Enhanced API response length: ${response.length}');

        // Generate explainable response with attribution if memory service available
        if (_memoryService != null) {
          try {
            final responseId = 'resp_${DateTime.now().millisecondsSinceEpoch}';
            print('LUMARA Debug: [Enhanced API] Retrieving memories for query: "$text"');
            
            final memoryResult = await _memoryService!.retrieveMemories(
              query: text,
              domains: [MemoryDomain.personal, MemoryDomain.creative, MemoryDomain.learning],
              responseId: responseId,
            );
            
            print('LUMARA Debug: [Enhanced API] Retrieved ${memoryResult.nodes.length} memory nodes');
            print('LUMARA Debug: [Enhanced API] Retrieved ${memoryResult.attributions.length} attribution traces from memory service');

            if (memoryResult.nodes.isEmpty) {
              print('LUMARA Debug: [Enhanced API] ⚠️ NO MEMORY NODES RETRIEVED - This is why no attribution data is generated');
            } else {
              for (final node in memoryResult.nodes) {
                print('LUMARA Debug: [Enhanced API] Memory node - ID: ${node.id}, Content: ${node.narrative.substring(0, node.narrative.length > 50 ? 50 : node.narrative.length)}...');
              }
            }

            // Use attribution traces directly from memory retrieval result
            print('LUMARA Debug: [Enhanced API] About to extract attribution traces...');
            final traces = memoryResult.attributions;
            print('LUMARA Debug: [Enhanced API] Extracted ${traces.length} traces');

            print('LUMARA Debug: [Enhanced API] Using ${traces.length} attribution traces from memory retrieval');
            for (final trace in traces) {
              print('LUMARA Debug: [Enhanced API] Trace - ${trace.nodeRef}: ${trace.relation} (${(trace.confidence * 100).toInt()}%)');
            }

            print('LUMARA Debug: [Enhanced API] Returning response with ${traces.length} traces');
            return {
              'content': response,
              'attributionTraces': traces,
            };
          } catch (e, stackTrace) {
            print('LUMARA Memory: Error in memory attribution processing: $e');
            print('LUMARA Memory: Stack trace: $stackTrace');
          }
        }

        return {
          'content': response,
          'attributionTraces': <AttributionTrace>[],
        };
      }
    } catch (cloudApiError) {
      print('LUMARA Debug: [Cloud API] Failed: $cloudApiError');
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
    // Get context
    final context = await _contextProvider.buildContext();

    // Build context for streaming
    final entryText = _buildEntryContext(context);
    final phaseHint = _buildPhaseHint(context);
    final keywords = _buildKeywordsContext(context);

    // Build system prompt
    final systemPrompt = _buildSystemPrompt(entryText, phaseHint, keywords);

    print('LUMARA Debug: Starting streaming response...');

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
          final updatedMessage = currentMessages[lastIndex].copyWith(
            content: fullResponse.toString(),
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

      // Get attribution traces after streaming completes
      List<AttributionTrace>? attributionTraces;
      if (_memoryService != null) {
        try {
          final responseId = 'resp_${DateTime.now().millisecondsSinceEpoch}';
          print('LUMARA Debug: Retrieving memories for attribution...');

          final memoryResult = await _memoryService!.retrieveMemories(
            query: text,
            domains: [MemoryDomain.personal, MemoryDomain.creative, MemoryDomain.learning],
            responseId: responseId,
          );

          attributionTraces = memoryResult.attributions;
          print('LUMARA Debug: Retrieved ${attributionTraces.length} attribution traces');
        } catch (e) {
          print('LUMARA Debug: Error retrieving attribution traces: $e');
        }
      }

      // Record assistant response in MCP memory
      await _recordAssistantMessage(finalContent);

      // Add assistant response to chat session
      await _addToChatSession(finalContent, 'assistant');

      // Update final message with attribution traces
      if (state is LumaraAssistantLoaded) {
        final currentMessages = (state as LumaraAssistantLoaded).messages;
        if (currentMessages.isNotEmpty) {
          final lastIndex = currentMessages.length - 1;
          final finalMessage = currentMessages[lastIndex].copyWith(
            content: finalContent,
            attributionTraces: attributionTraces,
          );

          final finalMessages = [
            ...currentMessages.sublist(0, lastIndex),
            finalMessage,
          ];

          print('LUMARA Debug: Streaming complete with ${attributionTraces?.length ?? 0} attribution traces');

          emit((state as LumaraAssistantLoaded).copyWith(
            messages: finalMessages,
            isProcessing: false,
          ));
        }
      }
    } catch (e) {
      print('LUMARA Debug: Error during streaming: $e');

      // Handle error by showing error message
      if (state is LumaraAssistantLoaded) {
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
    
    emit(currentState.copyWith(scope: newScope));
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
  
  /// Get context summary
  Future<String> getContextSummary() async {
    return await _contextProvider.getContextSummary();
  }

  /// Build entry context for ArcLLM
  String _buildEntryContext(ContextWindow context) {
    final recentEntries = context.nodes.where((n) => n['type'] == 'journal').toList();
    if (recentEntries.isEmpty) return '';

    final buffer = StringBuffer();
    for (final entry in recentEntries.take(3)) {
      final text = entry['text'] as String? ?? '';
      if (text.isNotEmpty) {
        buffer.writeln(text);
      }
    }
    return buffer.toString().trim();
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

      // Get current phase from context
      final context = await _contextProvider.buildContext();
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

  /// Generate subject from first message in "subject-year_month_day" format
  String generateSubject(String message) {
    final now = DateTime.now();
    final dateStr = '${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}';
    
    // Extract key words from message
    final words = message
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]'), '')
      .split(RegExp(r'\s+'))
      .where((word) => word.length > 3)
      .take(3)
      .toList();
    
    final subject = words.isNotEmpty ? words.join('-') : 'chat';
    return '$subject-$dateStr';
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
      
      if (messages.length >= _compactionThreshold) {
        await _compactConversation(messages);
      }
    } catch (e) {
      print('LUMARA Chat: Error checking compaction: $e');
    }
  }

  /// Compact conversation by summarizing old messages
  Future<void> _compactConversation(List<ChatMessage> messages) async {
    if (_isCompacting || currentChatSessionId == null) return;
    
    _isCompacting = true;
    
    try {
      // Keep recent messages and create summary of older ones
      final oldMessages = messages.take(messages.length - _maxMessagesBeforeCompaction).toList();
      
      if (oldMessages.isEmpty) return;
      
      // Create summary of old messages
      final summary = await _createConversationSummary(oldMessages);
      
      // Create a summary message
      final summaryMessage = ChatMessage.createLegacy(
        sessionId: currentChatSessionId!,
        role: 'system',
        content: summary,
      );
      
      // Replace old messages with summary
      await _replaceMessagesWithSummary(oldMessages, summaryMessage);
      
      print('LUMARA Chat: Compacted conversation - ${oldMessages.length} messages summarized');
      
      // Show notification to user
      _showCompactionNotification(oldMessages.length);
      
    } catch (e) {
      print('LUMARA Chat: Error compacting conversation: $e');
    } finally {
      _isCompacting = false;
    }
  }

  /// Create a summary of old messages
  Future<String> _createConversationSummary(List<ChatMessage> messages) async {
    // Group messages by role and create summary
    final userMessages = messages.where((m) => m.role == 'user').map((m) => m.textContent).toList();
    final assistantMessages = messages.where((m) => m.role == 'assistant').map((m) => m.textContent).toList();
    
    return '''📝 **Conversation Summary** (${messages.length} messages compacted)

**Key Topics Discussed:**
${userMessages.take(5).map((m) => '• ${m.length > 100 ? m.substring(0, 100) + '...' : m}').join('\n')}

**Assistant Responses:**
${assistantMessages.take(3).map((m) => '• ${m.length > 150 ? m.substring(0, 150) + '...' : m}').join('\n')}

*This conversation was automatically compacted to improve performance. The full conversation history is preserved in the MCP memory system.*''';
  }

  /// Replace old messages with summary
  Future<void> _replaceMessagesWithSummary(List<ChatMessage> oldMessages, ChatMessage summaryMessage) async {
    // This would need to be implemented in the ChatRepo
    // For now, just add the summary message
    await _chatRepo.addMessage(
      sessionId: currentChatSessionId!,
      role: 'system',
      content: summaryMessage.textContent,
    );
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

  /// Try to get a quick answer for basic questions
  Future<String?> _tryQuickAnswer(String text) async {
    if (_quickAnswersRouter == null) return null;
    
    try {
      return await _quickAnswersRouter!.handleUserMessage(text);
    } catch (e) {
      print('LUMARA Debug: Error in quick answers: $e');
      return null;
    }
  }
}
