import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/lumara/data/context_scope.dart';
import 'package:my_app/lumara/data/context_provider.dart';
import 'package:my_app/lumara/data/models/lumara_message.dart';
import 'package:my_app/lumara/llm/qwen_service.dart';
import 'package:my_app/lumara/llm/rule_based_adapter.dart';

/// LUMARA Assistant Cubit State
abstract class LumaraAssistantState {}

class LumaraAssistantInitial extends LumaraAssistantState {}

class LumaraAssistantLoading extends LumaraAssistantState {}

class LumaraAssistantLoaded extends LumaraAssistantState {
  final List<LumaraMessage> messages;
  final LumaraScope scope;
  final bool isProcessing;
  
  LumaraAssistantLoaded({
    required this.messages,
    required this.scope,
    this.isProcessing = false,
  });
  
  LumaraAssistantLoaded copyWith({
    List<LumaraMessage>? messages,
    LumaraScope? scope,
    bool? isProcessing,
  }) {
    return LumaraAssistantLoaded(
      messages: messages ?? this.messages,
      scope: scope ?? this.scope,
      isProcessing: isProcessing ?? this.isProcessing,
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
  final RuleBasedAdapter _fallbackAdapter;
  
  LumaraAssistantCubit({
    required ContextProvider contextProvider,
  }) : _contextProvider = contextProvider,
       _fallbackAdapter = const RuleBasedAdapter(),
       super(LumaraAssistantInitial());
  
  /// Initialize the assistant
  Future<void> initialize() async {
    try {
      emit(LumaraAssistantLoading());
      
      // Initialize Qwen service (falls back to rule-based if needed)
      await QwenService.initialize();
      
      // Start with default scope
      const scope = LumaraScope.defaultScope;
      
      // Add welcome message
      final List<LumaraMessage> messages = [
        LumaraMessage.assistant(
          content: "Hello! I'm LUMARA, your personal assistant. I can help you understand your patterns, explain your current phase, and provide insights about your journey. What would you like to know?",
        ),
      ];
      
      emit(LumaraAssistantLoaded(
        messages: messages,
        scope: scope,
      ));
    } catch (e) {
      emit(LumaraAssistantError('Failed to initialize LUMARA: $e'));
    }
  }

  /// Alias for initialize method (for UI compatibility)
  Future<void> initializeLumara() async {
    await initialize();
  }
  
  /// Send a message to LUMARA
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    
    final currentState = state;
    if (currentState is! LumaraAssistantLoaded) return;
    
    print('LUMARA Debug: Sending message: "$text"');
    print('LUMARA Debug: Current message count: ${currentState.messages.length}');
    
    // Add user message
    final userMessage = LumaraMessage.user(content: text);
    final updatedMessages = [...currentState.messages, userMessage];
    
    print('LUMARA Debug: Added user message, new count: ${updatedMessages.length}');
    
    emit(currentState.copyWith(
      messages: updatedMessages,
      isProcessing: true,
    ));
    
    try {
      // Process the message
      print('LUMARA Debug: Processing message...');
      final response = await _processMessage(text, currentState.scope);
      print('LUMARA Debug: Generated response length: ${response.length}');
      
      // Add assistant response
          final assistantMessage = LumaraMessage.assistant(content: response);
      final finalMessages = [...updatedMessages, assistantMessage];
      
      print('LUMARA Debug: Added assistant message, final count: ${finalMessages.length}');
      
      emit(currentState.copyWith(
        messages: finalMessages,
        isProcessing: false,
      ));
    } catch (e) {
      print('LUMARA Debug: Error processing message: $e');
      // Add error message
      final errorMessage = LumaraMessage.assistant(
            content: "I'm sorry, I encountered an error processing your request. Please try again.",
      );
      final finalMessages = [...updatedMessages, errorMessage];
      
      emit(currentState.copyWith(
        messages: finalMessages,
        isProcessing: false,
      ));
    }
  }
  
  /// Process a message and generate response
  Future<String> _processMessage(String text, LumaraScope scope) async {
    // Get context
    final context = await _contextProvider.buildContext();
    
    // Determine task type based on query
    final task = _determineTaskType(text);
    
    // Debug logging
    print('LUMARA Debug: Query: "$text" -> Task: ${task.name}');
    
    // Try Qwen AI first, fall back to rule-based
    if (QwenService.isAiEnabled) {
      try {
        print('LUMARA Debug: Using Qwen AI for response generation');
        
        // Convert context to format expected by QwenService
        final facts = {
          'task_type': task.name,
          'user_query': text,
          'total_entries': context.totalEntries,
          'total_arcforms': context.totalArcforms,
          'date_range': '${context.startDate.toIso8601String().split('T')[0]} to ${context.endDate.toIso8601String().split('T')[0]}',
          'scope': scope.enabledScopes.join(', '),
        };
        
        final snippets = context.nodes.map((node) => node['text'] as String).toList();
        
        final chat = [
          {'role': 'user', 'content': text}
        ];
        
        // Get AI response stream and collect first response
        final responseStream = QwenService.generateResponse(
          task: task.name,
          facts: facts,
          snippets: snippets,
          chat: chat,
        );
        
        final response = await responseStream.first;
        print('LUMARA Debug: Qwen AI generated response length: ${response.length}');
        return response;
        
      } catch (e) {
        print('LUMARA Debug: Qwen AI failed, falling back to rule-based: $e');
        // Fall through to rule-based adapter
      }
    } else {
      print('LUMARA Debug: Qwen AI not available, using rule-based adapter');
    }
    
    // Fallback to rule-based adapter
    final response = await _fallbackAdapter.generateResponse(
      task: task,
      userQuery: text,
      context: context,
    );
    
    print('LUMARA Debug: Rule-based adapter response length: ${response.length}');
    return response;
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
}
