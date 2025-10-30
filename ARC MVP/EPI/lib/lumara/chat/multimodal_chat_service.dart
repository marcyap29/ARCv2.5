import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'chat_models.dart';
import 'content_parts.dart';
import '../../core/mcp/orchestrator/chat_multimodal_processor.dart';
import '../../core/mcp/export/chat_mcp_exporter.dart';
import '../../core/mcp/models/mcp_schemas.dart';
import '../../echo/providers/llm/model_adapter.dart';
import '../../echo/providers/llm/llama_adapter.dart';
import '../../echo/providers/llm/ollama_adapter.dart';
import '../../echo/safety/chat_rivet_lite.dart';
import '../../echo/config/echo_config.dart';
import '../../echo/rhythms/veil_aurora_scheduler.dart';

/// Multimodal chat service integrating all components
class MultimodalChatService {
  static MultimodalChatService? _instance;
  static MultimodalChatService get instance => _instance ??= MultimodalChatService._();
  
  MultimodalChatService._();

  // Core components
  final ChatMultimodalProcessor _processor = ChatMultimodalProcessor();
  final ChatRivetLite _rivetLite = ChatRivetLite();
  final EchoConfig _config = EchoConfig.instance;
  
  // Model adapters
  ModelAdapter? _currentAdapter;
  final Map<String, ModelAdapter> _adapters = {};
  
  // State
  bool _isInitialized = false;
  final List<ChatSession> _sessions = [];
  final List<ChatMessage> _messages = [];

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Initialize ECHO configuration
      await _config.initialize();
      
      // Initialize model adapters
      await _initializeAdapters();
      
      // Start VEIL/AURORA scheduler
      await VeilAuroraScheduler.start();
      
      _isInitialized = true;
      print('MultimodalChatService: Initialized successfully');
    } catch (e) {
      print('MultimodalChatService: Error initializing - $e');
      rethrow;
    }
  }

  /// Initialize model adapters
  Future<void> _initializeAdapters() async {
    // Rule-based adapter (always available)
    _adapters['rule_based'] = RuleBasedAdapter();
    
    // Llama adapter
    try {
      final llamaAdapter = LlamaAdapter();
      final initialized = await LlamaAdapter.initialize();
      if (initialized) {
        _adapters['llama'] = llamaAdapter;
        print('MultimodalChatService: Llama adapter initialized');
      }
    } catch (e) {
      print('MultimodalChatService: Failed to initialize Llama adapter - $e');
    }
    
    // Ollama adapter
    try {
      final ollamaAdapter = OllamaAdapter();
      final initialized = await OllamaAdapter.initialize();
      if (initialized) {
        _adapters['ollama'] = ollamaAdapter;
        print('MultimodalChatService: Ollama adapter initialized');
      }
    } catch (e) {
      print('MultimodalChatService: Failed to initialize Ollama adapter - $e');
    }
    
    // Set current adapter
    _currentAdapter = _adapters[_config.config.currentProvider.value];
    if (_currentAdapter == null) {
      _currentAdapter = _adapters['rule_based'];
      print('MultimodalChatService: Using rule-based adapter as fallback');
    }
  }

  /// Create a new chat session
  Future<ChatSession> createSession({
    required String subject,
    List<String> tags = const [],
    String retention = "auto-archive-30d",
  }) async {
    final session = ChatSession.create(
      subject: subject,
      tags: tags,
    ).copyWith(retention: retention);
    
    _sessions.add(session);
    print('MultimodalChatService: Created session ${session.id}');
    
    return session;
  }

  /// Send a message to a chat session
  Future<ChatMessage> sendMessage({
    required String sessionId,
    required List<ContentPart> contentParts,
    Map<String, dynamic>? provenance,
  }) async {
    // Create message
    final message = ChatMessage.create(
      sessionId: sessionId,
      role: MessageRole.user,
      contentParts: contentParts,
      provenance: provenance != null ? provenance.toString() : null,
    );
    
    // Process through OCP + PRISM pipeline
    final processedMessage = await _processor.processMessage(message);
    
    // Add to messages
    _messages.add(processedMessage.originalMessage);
    
    // Update session message count
    _updateSessionMessageCount(sessionId);
    
    // Generate response
    final response = await _generateResponse(sessionId, processedMessage);
    
    // Add response to messages
    _messages.add(response);
    
    // Update session message count
    _updateSessionMessageCount(sessionId);
    
    print('MultimodalChatService: Sent message ${message.id} and response ${response.id}');
    
    return response;
  }

  /// Generate response using current adapter
  Future<ChatMessage> _generateResponse(String sessionId, ProcessedChatMessage processedMessage) async {
    if (_currentAdapter == null) {
      throw StateError('No model adapter available');
    }
    
    // Get context for this session
    final context = _messages.where((m) => m.sessionId == sessionId).toList();
    
    // Extract facts and snippets
    final facts = _extractFacts(processedMessage);
    final snippets = _extractSnippets(context);
    
    // Generate response
    final responseStream = _currentAdapter!.realize(
      task: 'chat',
      facts: facts,
      snippets: snippets,
      chat: _formatChatHistory(context),
    );
    
    // Collect response
    final responseText = await responseStream.join();
    
    // Create response message
    final response = ChatMessage.create(
      sessionId: sessionId,
      role: MessageRole.assistant,
      contentParts: ContentPartUtils.fromLegacyContent(responseText),
      provenance: '${_config.config.currentProvider.value}',
    );
    
    // RIVET-lite assessment
    if (_config.config.enableRivetLite) {
      final assessment = await _rivetLite.assessMessage(
        response,
        context: context,
        retrievedFacts: facts,
      );
      
      print('RIVET-lite Assessment: ${assessment.isReady ? "READY" : "NOT READY"}');
      print('ALIGN: ${assessment.alignScore.toStringAsFixed(2)}, TRACE: ${assessment.traceScore.toStringAsFixed(2)}');
      if (!assessment.isReady) {
        print('Reasons: ${assessment.reasons.join(", ")}');
      }
    }
    
    return response;
  }

  /// Extract facts from processed message
  Map<String, dynamic> _extractFacts(ProcessedChatMessage processedMessage) {
    final facts = <String, dynamic>{};
    
    // Extract from PRISM analysis
    for (final part in processedMessage.processedParts) {
      if (part is PrismContentPart) {
        final summary = part.summary;
        
        if (summary.emotion != null) {
          facts['emotion'] = {
            'valence': summary.emotion!.valence,
            'arousal': summary.emotion!.arousal,
            'dominant': summary.emotion!.dominantEmotion,
          };
        }
        
        if (summary.objects != null) {
          facts['objects'] = summary.objects!;
        }
        
        if (summary.symbols != null) {
          facts['symbols'] = summary.symbols!;
        }
      }
    }
    
    return facts;
  }

  /// Extract snippets from context
  List<String> _extractSnippets(List<ChatMessage> context) {
    return context
        .where((m) => m.role == MessageRole.user)
        .map((m) => m.textContent)
        .where((text) => text.isNotEmpty)
        .take(5)
        .toList();
  }

  /// Format chat history for adapter
  List<Map<String, String>> _formatChatHistory(List<ChatMessage> context) {
    return context
        .map((m) => {
          'role': m.role,
          'content': m.textContent,
        })
        .toList();
  }

  /// Update session message count
  void _updateSessionMessageCount(String sessionId) {
    final sessionIndex = _sessions.indexWhere((s) => s.id == sessionId);
    if (sessionIndex != -1) {
      final messageCount = _messages.where((m) => m.sessionId == sessionId).length;
      _sessions[sessionIndex] = _sessions[sessionIndex].copyWith(
        messageCount: messageCount,
        updatedAt: DateTime.now(),
      );
    }
  }

  /// Switch model provider
  Future<void> switchProvider(ProviderType provider) async {
    await _config.switchProvider(provider);
    
    // Update current adapter
    _currentAdapter = _adapters[provider.value];
    if (_currentAdapter == null) {
      _currentAdapter = _adapters['rule_based'];
      print('MultimodalChatService: Provider ${provider.value} not available, using rule-based');
    } else {
      print('MultimodalChatService: Switched to provider ${provider.value}');
    }
  }

  /// Export chat data to MCP
  Future<ChatMcpExportResult> exportToMcp({
    ChatMcpExportScope scope = ChatMcpExportScope.all,
    DateTime? since,
    DateTime? until,
  }) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${docsDir.path}/mcp_exports/chat_${DateTime.now().millisecondsSinceEpoch}');
      await exportDir.create(recursive: true);
      
      final exporter = ChatMcpExporter(
        outputDir: exportDir,
        storageProfile: McpStorageProfile.balanced,
        notes: 'Chat export - ${scope.name}',
      );
      
      return await exporter.exportChats(
        sessions: _sessions,
        messages: _messages,
        scope: scope,
        since: since,
        until: until,
      );
    } catch (e) {
      return ChatMcpExportResult(
        success: false,
        bundlePath: '',
        sessionCount: 0,
        messageCount: 0,
        pointerCount: 0,
        embeddingCount: 0,
        errors: [e.toString()],
      );
    }
  }

  /// Get chat sessions
  List<ChatSession> getSessions({bool includeArchived = false}) {
    if (includeArchived) {
      return List.unmodifiable(_sessions);
    }
    return _sessions.where((s) => !s.isArchived).toList();
  }

  /// Get messages for a session
  List<ChatMessage> getMessages(String sessionId) {
    return _messages
        .where((m) => m.sessionId == sessionId)
        .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Archive a session
  Future<void> archiveSession(String sessionId) async {
    final sessionIndex = _sessions.indexWhere((s) => s.id == sessionId);
    if (sessionIndex != -1) {
      _sessions[sessionIndex] = _sessions[sessionIndex].copyWith(
        isArchived: true,
        archivedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      print('MultimodalChatService: Archived session $sessionId');
    }
  }

  /// Pin a session
  Future<void> pinSession(String sessionId) async {
    final sessionIndex = _sessions.indexWhere((s) => s.id == sessionId);
    if (sessionIndex != -1) {
      _sessions[sessionIndex] = _sessions[sessionIndex].copyWith(
        isPinned: true,
        updatedAt: DateTime.now(),
      );
      print('MultimodalChatService: Pinned session $sessionId');
    }
  }

  /// Get service status
  Map<String, dynamic> getStatus() {
    return {
      'isInitialized': _isInitialized,
      'currentProvider': _config.config.currentProvider.value,
      'availableProviders': _adapters.keys.toList(),
      'sessionCount': _sessions.length,
      'messageCount': _messages.length,
      'rivetLiteEnabled': _config.config.enableRivetLite,
      'veilAuroraEnabled': _config.config.enableVeilAurora,
      'veilAuroraStatus': VeilAuroraScheduler.getStatus(),
    };
  }

  /// Dispose resources
  Future<void> dispose() async {
    VeilAuroraScheduler.stop();
    _isInitialized = false;
    print('MultimodalChatService: Disposed');
  }
}
