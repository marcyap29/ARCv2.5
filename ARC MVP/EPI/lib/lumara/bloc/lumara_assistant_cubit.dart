import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/lumara/data/context_scope.dart';
import 'package:my_app/lumara/data/context_provider.dart';
import 'package:my_app/lumara/data/models/lumara_message.dart';
import 'package:my_app/lumara/llm/rule_based_adapter.dart';
import 'package:my_app/services/gemini_send.dart';
import 'package:my_app/services/llm_bridge_adapter.dart';
import '../services/enhanced_lumara_api.dart';
import '../../mira/memory/enhanced_mira_memory_service.dart';
import '../../mira/memory/enhanced_memory_schema.dart';
import '../../mira/mira_service.dart';
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

  // Enhanced MIRA Memory System
  EnhancedMiraMemoryService? _memoryService;
  String? _userId;
  String? _currentPhase;

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

    // Memory retrieval will be handled in response generation

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

        // Generate explainable response with attribution if memory service available
        if (_memoryService != null) {
          try {
            final responseId = 'resp_${DateTime.now().millisecondsSinceEpoch}';
            final memoryResult = await _memoryService!.retrieveMemories(
              query: text,
              domains: [MemoryDomain.personal, MemoryDomain.creative, MemoryDomain.learning],
              responseId: responseId,
            );

            final explainableResponse = await _memoryService!.generateExplainableResponse(
              content: response,
              referencedNodes: memoryResult.nodes,
              responseId: responseId,
              includeReasoningDetails: true,
            );

            return explainableResponse.content;
          } catch (e) {
            print('LUMARA Memory: Error generating explainable response: $e');
          }
        }

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

        // Generate explainable response with attribution if memory service available
        if (_memoryService != null) {
          try {
            final responseId = 'resp_${DateTime.now().millisecondsSinceEpoch}';
            final memoryResult = await _memoryService!.retrieveMemories(
              query: text,
              domains: [MemoryDomain.personal, MemoryDomain.creative, MemoryDomain.learning],
              responseId: responseId,
            );

            final explainableResponse = await _memoryService!.generateExplainableResponse(
              content: response,
              referencedNodes: memoryResult.nodes,
              responseId: responseId,
              includeReasoningDetails: true,
            );

            return explainableResponse.content;
          } catch (e) {
            print('LUMARA Memory: Error generating explainable response: $e');
          }
        }

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
}
