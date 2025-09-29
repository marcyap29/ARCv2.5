import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/lumara/data/context_scope.dart';
import 'package:my_app/lumara/data/context_provider.dart';
import 'package:my_app/lumara/data/models/lumara_message.dart';
import 'package:my_app/lumara/llm/rule_based_adapter.dart';
import 'package:my_app/services/gemini_send.dart';
import 'package:my_app/services/llm_bridge_adapter.dart';
import '../services/enhanced_lumara_api.dart';
import '../memory/mcp_memory_service.dart';
import '../memory/memory_index_service.dart';
import '../../telemetry/analytics.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

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
  final RuleBasedAdapter _fallbackAdapter;
  late final ArcLLM _arcLLM;
  late final EnhancedLumaraApi _enhancedApi;
  final Analytics _analytics = Analytics();

  // MCP Memory System
  McpMemoryService? _memoryService;
  MemoryIndexService? _indexService;
  String? _userId;

  LumaraAssistantCubit({
    required ContextProvider contextProvider,
  }) : _contextProvider = contextProvider,
       _fallbackAdapter = const RuleBasedAdapter(),
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

      // Start with default scope
      const scope = LumaraScope.defaultScope;

      // Check if API key is configured
      const apiKey = String.fromEnvironment('GEMINI_API_KEY');
      final hasApiKey = apiKey.isNotEmpty;

      // Start or resume a conversation session
      final sessionId = await _getOrCreateSession();

      // Add welcome message and record it in memory
      final welcomeContent = hasApiKey
        ? "Hello! I'm LUMARA, your personal assistant. I can help you understand your patterns, explain your current phase, and provide insights about your journey. What would you like to know?"
        : "Hello! I'm LUMARA, your personal assistant. I'm currently running in basic mode with rule-based responses. To enable full AI-powered responses, please configure your Gemini API key using the key icon in the top bar. What would you like to know?";

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

    // Record user message in MCP memory first
    await _recordUserMessage(text);

    // Add user message to UI
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

      // Record assistant response in MCP memory
      await _recordAssistantMessage(response);

      // Add assistant response to UI
      final assistantMessage = LumaraMessage.assistant(content: response);
      final finalMessages = [...updatedMessages, assistantMessage];

      print('LUMARA Debug: Added assistant message, final count: ${finalMessages.length}');

      emit(currentState.copyWith(
        messages: finalMessages,
        isProcessing: false,
      ));
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
  
  /// Process a message and generate response
  Future<String> _processMessage(String text, LumaraScope scope) async {
    // Get context
    final context = await _contextProvider.buildContext();

    // Determine task type based on query
    final task = _determineTaskType(text);

    // Debug logging
    print('LUMARA Debug: Query: "$text" -> Task: ${task.name}');

    try {
      // First try direct Gemini API if available
      const apiKey = String.fromEnvironment('GEMINI_API_KEY');
      if (apiKey.isNotEmpty) {
        print('LUMARA Debug: Using direct Gemini API for response generation');
        
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
        return response;
      } else {
        print('LUMARA Debug: No Gemini API key found, trying Enhanced LUMARA API');
        
        // Try enhanced LUMARA API with multi-provider support
        final entryText = _buildEntryContext(context);
        final phaseHint = _buildPhaseHint(context);
        
        // Use enhanced API for response generation
        final response = await _enhancedApi.generatePromptedReflection(
          entryText: entryText,
          intent: _mapTaskToIntent(task),
          phase: phaseHint,
        );

        print('LUMARA Debug: Enhanced API response length: ${response.length}');
        return response;
      }
    } catch (e) {
      print('LUMARA Debug: Error with API, falling back to rule-based: $e');

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

  // MCP Memory System Methods

  /// Initialize the MCP memory system
  Future<void> _initializeMemorySystem() async {
    try {
      // Get user ID (simplified - in real implementation, get from user service)
      _userId = 'user_${DateTime.now().millisecondsSinceEpoch}';

      // Initialize memory service
      _memoryService = McpMemoryService();
      await _memoryService!.initialize(_userId!);

      // Initialize memory index service
      final documentsDir = await getApplicationDocumentsDirectory();
      final indexPath = path.join(documentsDir.path, 'user_profiles', _userId!, 'mcp', 'memory.index.json');
      _indexService = MemoryIndexService(userId: _userId!, indexPath: indexPath);
      await _indexService!.initialize();

      print('LUMARA Memory: MCP memory system initialized for user $_userId');
    } catch (e) {
      print('LUMARA Memory: Error initializing memory system: $e');
    }
  }

  /// Get or create a conversation session
  Future<String> _getOrCreateSession() async {
    if (_memoryService == null) {
      throw Exception('Memory service not initialized');
    }

    // Check if we have an active session, if not create one
    final sessions = await _memoryService!.listSessions();
    if (sessions.isNotEmpty) {
      final latestSession = sessions.first;
      final sessionId = latestSession['session_id'] as String;
      final success = await _memoryService!.resumeSession(sessionId);
      if (success) {
        print('LUMARA Memory: Resumed session $sessionId');
        return sessionId;
      }
    }

    // Create new session
    final sessionId = await _memoryService!.startSession(
      title: 'LUMARA Chat ${DateTime.now().day}/${DateTime.now().month}',
    );
    print('LUMARA Memory: Created new session $sessionId');
    return sessionId;
  }

  /// Record user message in MCP memory
  Future<void> _recordUserMessage(String content) async {
    if (_memoryService == null) return;

    try {
      await _memoryService!.addMessage(
        role: 'user',
        content: content,
      );
      print('LUMARA Memory: Recorded user message');
    } catch (e) {
      print('LUMARA Memory: Error recording user message: $e');
    }
  }

  /// Record assistant message in MCP memory
  Future<void> _recordAssistantMessage(String content) async {
    if (_memoryService == null) return;

    try {
      await _memoryService!.addMessage(
        role: 'assistant',
        content: content,
      );
      print('LUMARA Memory: Recorded assistant message');
    } catch (e) {
      print('LUMARA Memory: Error recording assistant message: $e');
    }
  }

  /// Handle memory commands
  Future<void> _handleMemoryCommand(String command) async {
    final currentState = state;
    if (currentState is! LumaraAssistantLoaded) return;

    try {
      String response;

      if (_memoryService == null) {
        response = 'Memory system not available. Please restart LUMARA.';
      } else {
        response = await _memoryService!.handleMemoryCommand(command);
      }

      // Add command and response to UI
      final userMessage = LumaraMessage.user(content: command);
      final assistantMessage = LumaraMessage.assistant(content: response);
      final updatedMessages = [...currentState.messages, userMessage, assistantMessage];

      emit(currentState.copyWith(messages: updatedMessages));

      print('LUMARA Memory: Handled command: $command');
    } catch (e) {
      final errorMessage = LumaraMessage.assistant(
        content: 'Error processing memory command: $e',
      );
      final updatedMessages = [
        ...currentState.messages,
        LumaraMessage.user(content: command),
        errorMessage,
      ];

      emit(currentState.copyWith(messages: updatedMessages));
      print('LUMARA Memory: Error handling command: $e');
    }
  }

  /// Get conversation history for a session
  Future<List<Map<String, dynamic>>> getConversationHistory([String? sessionId]) async {
    if (_memoryService == null) return [];

    try {
      if (sessionId != null) {
        return await _memoryService!.getSessionMessages(sessionId);
      } else {
        // Get current session messages
        final context = await _memoryService!.getConversationContext();
        return List<Map<String, dynamic>>.from(context['messages'] ?? []);
      }
    } catch (e) {
      print('LUMARA Memory: Error getting conversation history: $e');
      return [];
    }
  }

  /// List all conversation sessions
  Future<List<Map<String, dynamic>>> getConversationSessions() async {
    if (_memoryService == null) return [];

    try {
      return await _memoryService!.listSessions();
    } catch (e) {
      print('LUMARA Memory: Error getting sessions: $e');
      return [];
    }
  }

  /// Switch to a different conversation session
  Future<void> switchToSession(String sessionId) async {
    if (_memoryService == null) return;

    try {
      final success = await _memoryService!.resumeSession(sessionId);
      if (success) {
        final messages = await _memoryService!.getSessionMessages(sessionId);
        final lumaraMessages = messages.map((msg) {
          return msg['role'] == 'user'
              ? LumaraMessage.user(content: msg['content'])
              : LumaraMessage.assistant(content: msg['content']);
        }).toList();

        final currentState = state;
        if (currentState is LumaraAssistantLoaded) {
          emit(currentState.copyWith(
            messages: lumaraMessages,
            currentSessionId: sessionId,
          ));
        }

        print('LUMARA Memory: Switched to session $sessionId with ${messages.length} messages');
      }
    } catch (e) {
      print('LUMARA Memory: Error switching to session: $e');
    }
  }

  /// Delete a conversation session
  Future<void> deleteConversationSession(String sessionId) async {
    if (_memoryService == null) return;

    try {
      await _memoryService!.deleteSession(sessionId);

      // If this was the current session, start a new one
      final currentState = state;
      if (currentState is LumaraAssistantLoaded &&
          currentState.currentSessionId == sessionId) {
        await initialize(); // Restart with new session
      }

      print('LUMARA Memory: Deleted session $sessionId');
    } catch (e) {
      print('LUMARA Memory: Error deleting session: $e');
    }
  }

  /// Get memory statistics
  Future<Map<String, dynamic>> getMemoryStatistics() async {
    final stats = <String, dynamic>{};

    if (_memoryService != null) {
      try {
        final sessions = await _memoryService!.listSessions();
        stats['total_sessions'] = sessions.length;
        stats['total_messages'] = sessions.fold<int>(
          0,
          (sum, session) => sum + (session['message_count'] as int? ?? 0),
        );
      } catch (e) {
        print('LUMARA Memory: Error getting memory stats: $e');
      }
    }

    if (_indexService != null) {
      try {
        final indexStats = _indexService!.getStatistics();
        stats.addAll(indexStats);
      } catch (e) {
        print('LUMARA Memory: Error getting index stats: $e');
      }
    }

    return stats;
  }
}
