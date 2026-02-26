import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/data/context_scope.dart';
import '../models/data/context_provider.dart';
import '../models/data/models/lumara_message.dart';
import '../providers/llm/rule_based_adapter.dart';
import 'package:my_app/services/gemini_send.dart';
import 'package:my_app/services/llm_bridge_adapter.dart';

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
  late final ArcLLM _arcLLM;

  LumaraAssistantCubit({
    required ContextProvider contextProvider,
  }) : _contextProvider = contextProvider,
       _fallbackAdapter = const RuleBasedAdapter(),
       super(LumaraAssistantInitial()) {
    // Initialize ArcLLM with Gemini integration
    _arcLLM = provideArcLLM();
  }
  
  /// Initialize the assistant
  Future<void> initialize() async {
    try {
      emit(LumaraAssistantLoading());
      
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

    try {
      // Check if Gemini API key is available
      const apiKey = String.fromEnvironment('GEMINI_API_KEY');
      if (apiKey.isNotEmpty) {
        print('LUMARA Debug: Using ArcLLM/Gemini for response generation');

        // Prepare context for ArcLLM
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

        print('LUMARA Debug: ArcLLM/Gemini response length: ${response.length}');
        return response;
      } else {
        print('LUMARA Debug: No Gemini API key found, falling back to rule-based responses');
        throw StateError('GEMINI_API_KEY not provided');
      }
    } catch (e) {
      print('LUMARA Debug: Error with ArcLLM/Gemini, falling back to rule-based: $e');

      // Fallback to rule-based adapter
      print('LUMARA Debug: Using rule-based adapter for response generation');
      final response = await _fallbackAdapter.generateResponse(
        task: task,
        userQuery: text,
        context: context,
      );

      print('LUMARA Debug: Rule-based adapter response length: ${response.length}');
      return response;
    }
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

    print('LUMARA Debug: Using current phase from context: $currentPhase');

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
}
