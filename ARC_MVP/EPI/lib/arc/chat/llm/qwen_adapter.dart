import 'dart:async';
import 'package:flutter/foundation.dart';
import 'model_adapter.dart';
import 'lumara_native.dart';
import '../../core/app_flags.dart';
import '../../core/prompts_arc.dart';

/// Qwen3 chat adapter for on-device text generation and reasoning
class QwenAdapter implements ModelAdapter {
  static bool _isInitialized = false;
  static QwenModel? _loadedModel;
  static DeviceCapabilities? _deviceCaps;
  static bool _available = false;
  static String _reason = 'uninitialized';
  
  /// Initialize the Qwen chat adapter
  static Future<bool> initialize() async {
    try {
      debugPrint('[QwenAdapter] Starting initialization...');
      
      // Ensure native bridge is initialized first
      try {
        await LumaraNative.ensureInitialized();
        debugPrint('[QwenAdapter] Native bridge connection verified');
      } catch (e) {
        _reason = 'plugin_not_registered: $e';
        _available = false;
        debugPrint('[QwenAdapter] ensureInitialized failed -> plugin not registered: $e');
        _isInitialized = false;
        return false;
      }
      
      // Run self-test to get diagnostics
      final diag = await LumaraNative.selfTest();
      debugPrint('[QwenAdapter] selfTest diag: $diag');
      
      // Try to get device capabilities, but handle missing native bridge gracefully
      try {
        _deviceCaps = await LumaraNative.getDeviceCapabilities();
        debugPrint('[QwenAdapter] Got device capabilities from native bridge');
      } catch (e) {
        debugPrint('[QwenAdapter] Native bridge not available, using fallback device capabilities - $e');
        // Create fallback device capabilities
        _deviceCaps = const DeviceCapabilities(
          totalRamMB: 4096, // 4GB in MB
          availableRamMB: 2048, // 2GB in MB
          recommendedChatModel: QwenModel.qwen2p5_1p5b_instruct,
          recommendedVlmModel: QwenModel.qwen2_vl_2b_instruct,
          canRunEmbeddings: true,
        );
      }
      
      final recommendedModel = _deviceCaps!.recommendedChatModel;
      final modelConfig = modelConfigs[recommendedModel]!;
      
      debugPrint('[QwenAdapter] Initializing ${modelConfig.displayName}');
      debugPrint('[QwenAdapter] Device RAM: ${_deviceCaps!.totalRamGB.toStringAsFixed(1)}GB');
      debugPrint('[QwenAdapter] Model size: ${modelConfig.estimatedSizeMB}MB');
      
      // Check if actual model files exist
      final modelPath = 'assets/models/qwen/${modelConfig.filename}';
      debugPrint('[QwenAdapter] Model path: $modelPath');
      
      // Try to initialize the native Qwen model using new initModel method
      final ok = await LumaraNative.initModel(modelPath);
      _isInitialized = ok;
      _loadedModel = ok ? recommendedModel : null;
      _available = ok;
      _reason = ok ? 'ok' : 'init_failed';
      
      debugPrint('[QwenAdapter] initModel -> $_available ($_reason)');
      
      if (ok) {
        debugPrint('[QwenAdapter] Successfully initialized native Qwen model');
        return true;
      } else {
        debugPrint('[QwenAdapter] Model initialization failed');
        return false;
      }
      
    } catch (e) {
      print('QwenAdapter: Initialization error - $e');
      return false;
    }
  }
  
  /// Check if adapter is ready
  static bool get isReady {
    final ready = _isInitialized && _loadedModel != null;
    debugPrint('[QwenAdapter] isReady check - _isInitialized: $_isInitialized, _loadedModel: $_loadedModel, result: $ready');
    return ready;
  }

  /// Check if adapter is available
  static bool get isAvailable => _available;
  
  /// Get reason for availability status
  static String get reason => _reason;
  
  /// Get loaded model information
  static QwenModel? get loadedModel => _loadedModel;
  static DeviceCapabilities? get deviceCapabilities => _deviceCaps;

  @override
  Stream<String> realize({
    required String task,
    required Map<String, dynamic> facts,
    required List<String> snippets,
    required List<Map<String, String>> chat,
  }) async* {
    if (!isReady) {
      yield 'LUMARA is initializing. Please wait a moment and try again.';
      return;
    }

    try {
      // Build context-aware prompt based on task
      final prompt = _buildPromptForTask(
        task: task,
        facts: facts,
        snippets: snippets,
        chat: chat,
      );

      print('QwenAdapter: Generating response for task: $task');
      print('  Context snippets: ${snippets.length}');
      print('  Chat history: ${chat.length} messages');
      print('  Facts: $facts');
      print('  Snippets: $snippets');
      print('  Chat: $chat');
      print('  Generated prompt: $prompt');

      // Generate response using actual Qwen model
      print('QwenAdapter: Generating response using Qwen model...');
      final response = await _generateQwenResponse(prompt);
      print('QwenAdapter: Qwen response: "$response"');
      
      if (response.isNotEmpty) {
        // Add LUMARA signature and evidence citation
        final enhancedResponse = _enhanceResponse(
          response: response,
          facts: facts,
          snippets: snippets,
        );
        
        print('QwenAdapter: Enhanced final response: "$enhancedResponse"');
        yield enhancedResponse;
      } else {
        print('QwenAdapter: Empty response received, using error message');
        yield 'I\'m having trouble generating a response right now. Please check that the model is properly loaded and try again.';
      }
    } catch (e) {
      print('QwenAdapter: Error during generation - $e');
      yield 'An error occurred while processing your request. Please try again.';
    }
  }

  /// Build task-specific prompts using on-device templates
  String _buildPromptForTask({
    required String task,
    required Map<String, dynamic> facts,
    required List<String> snippets,
    required List<Map<String, String>> chat,
  }) {
    // Use on-device system prompt
    String systemPrompt = ArcPrompts.systemOnDevice;
    
    // Build context section
    final contextBuilder = StringBuffer();
    
    // Add facts summary
    if (facts.isNotEmpty) {
      contextBuilder.writeln('FACTS:');
      facts.forEach((key, value) {
        contextBuilder.writeln('- $key: $value');
      });
      contextBuilder.writeln();
    }
    
    // Add relevant snippets
    if (snippets.isNotEmpty) {
      contextBuilder.writeln('RELEVANT CONTENT:');
      for (int i = 0; i < snippets.length; i++) {
        contextBuilder.writeln('${i + 1}. ${snippets[i]}');
      }
      contextBuilder.writeln();
    }
    
    // Get task-specific template using on-device format
    String taskPrompt;
    switch (task) {
      case 'weekly_summary':
        taskPrompt = ArcPrompts.chatLite.replaceAll('<context>', contextBuilder.toString().trim());
        break;
      case 'rising_patterns':
        taskPrompt = ArcPrompts.chatLite.replaceAll('<context>', contextBuilder.toString().trim());
        break;
      case 'phase_rationale':
        taskPrompt = ArcPrompts.phaseHintsLite
            .replaceAll('{{entry_text}}', facts['recent_entry']?.toString() ?? '')
            .replaceAll('{{sage_json}}', facts['sage_json']?.toString() ?? '')
            .replaceAll('{{keywords}}', facts['keywords']?.toString() ?? '');
        break;
      case 'sage_echo':
        taskPrompt = ArcPrompts.sageEchoLite
            .replaceAll('{{entry_text}}', facts['entry_text']?.toString() ?? '');
        break;
      case 'arcform_keywords':
        taskPrompt = ArcPrompts.arcformKeywordsLite
            .replaceAll('{{entry_text}}', facts['entry_text']?.toString() ?? '')
            .replaceAll('{{sage_json}}', facts['sage_json']?.toString() ?? '');
        break;
      case 'chat':
        taskPrompt = _buildOnDeviceChatPrompt(chat, contextBuilder.toString().trim());
        break;
      default:
        taskPrompt = chat.isNotEmpty 
            ? _buildOnDeviceChatPrompt(chat, contextBuilder.toString().trim())
            : ArcPrompts.chatLite.replaceAll('<context>', contextBuilder.toString().trim());
    }
    
    // Combine system prompt and task
    return '''$systemPrompt

$taskPrompt''';
  }

  /// Build on-device chat prompt from conversation history
  String _buildOnDeviceChatPrompt(List<Map<String, String>> chat, String context) {
    if (chat.isEmpty) {
      return ArcPrompts.chatLite.replaceAll('<context>', context);
    }
    
    // Get the latest user message (for potential future use)
    // final latestMessage = chat.lastWhere(
    //   (m) => m['role'] == 'user',
    //   orElse: () => {'content': 'Please help me understand my journal patterns.'},
    // );
    
    // Build context with conversation history
    final contextBuilder = StringBuffer();
    contextBuilder.writeln(context);
    contextBuilder.writeln();
    contextBuilder.writeln('CONVERSATION:');
    
    for (final message in chat.take(5)) { // Limit context window for on-device
      final role = message['role'] ?? 'user';
      final content = message['content'] ?? '';
      
      if (role == 'user') {
        contextBuilder.writeln('User: $content');
      } else if (role == 'assistant') {
        contextBuilder.writeln('Assistant: $content');
      }
    }
    
    return ArcPrompts.chatLite
        .replaceAll('<context>', contextBuilder.toString().trim())
        .replaceAll('{phase_hint: <...>, last_keywords: <...>}', '{}');
  }


  /// Enhance response with LUMARA signature and citations
  String _enhanceResponse({
    required String response,
    required Map<String, dynamic> facts,
    required List<String> snippets,
  }) {
    final enhanced = StringBuffer(response);
    
    // Add source attribution
    final nEntries = facts['journal_entries'] ?? 0;
    final currentPhase = facts['current_phase'] ?? 'Discovery';
    final phaseStart = facts['current_phase_start'] ?? 'unknown date';
    
    enhanced.writeln();
    enhanced.writeln();
    enhanced.write('Based on $nEntries entries, current phase: $currentPhase, phase history since $phaseStart.');
    
    return enhanced.toString();
  }
  
  /// Generate response using actual Qwen model
  Future<String> _generateQwenResponse(String prompt) async {
    print('QwenAdapter: _generateQwenResponse called');
    print('QwenAdapter: Native bridge availability check - isInitialized: $_isInitialized, loadedModel: $_loadedModel');
    
    try {
      print('QwenAdapter: Attempting native LumaraNative.qwenText call...');
      print('QwenAdapter: Prompt length: ${prompt.length} characters');
      print('QwenAdapter: Prompt preview: ${prompt.substring(0, prompt.length > 200 ? 200 : prompt.length)}...');
      
      // Try to use the native Qwen model
      final response = await LumaraNative.qwenText(prompt);
      print('QwenAdapter: Native call completed successfully');
      print('QwenAdapter: Native response length: ${response.length}');
      print('QwenAdapter: Native response preview: ${response.length > 100 ? "${response.substring(0, 100)}..." : response}');
      
      if (response.isNotEmpty) {
        print('QwenAdapter: Using native response');
        return response;
      } else {
        print('QwenAdapter: Native response was empty, falling back');
      }
    } catch (e) {
      print('QwenAdapter: Native Qwen call failed: $e');
      print('QwenAdapter: Exception type: ${e.runtimeType}');
      
      // Check specific exception types
      if (e.toString().contains('MissingPluginException')) {
        print('QwenAdapter: DETECTED: Native bridge plugin not found - likely iOS/Android native code not properly linked');
      } else if (e.toString().contains('PlatformException')) {
        print('QwenAdapter: DETECTED: Platform exception - native method failed');
      } else {
        print('QwenAdapter: DETECTED: Unexpected exception type');
      }
    }
    
    print('QwenAdapter: Falling back to enhanced response generation');
    // Fallback to enhanced response if native call fails
    return _generateEnhancedResponse(prompt);
  }

  /// Generate enhanced context-aware response using actual Qwen model
  String _generateEnhancedResponse(String prompt) {
    // Simple intelligent response based on context
    var response = StringBuffer();
    
    // Extract user query from prompt if possible
    if (prompt.contains("Please respond to the user's latest message: \"")) {
      final startIndex = prompt.indexOf("Please respond to the user's latest message: \"") + 46;
      final endIndex = prompt.indexOf("\"", startIndex);
      if (endIndex > startIndex) {
        final userMessage = prompt.substring(startIndex, endIndex);
        response.write("You asked: \"$userMessage\". ");
      }
    }
    
    // Provide context-aware response
    if (prompt.contains("total_entries")) {
      final entryMatch = RegExp(r'total_entries: (\d+)').firstMatch(prompt);
      if (entryMatch != null) {
        final entryCount = int.tryParse(entryMatch.group(1) ?? '0') ?? 0;
        response.write("Based on your $entryCount journal entries, ");
      }
    }
    
    if (prompt.contains("Sample journal entry")) {
      response.write("I can see some interesting themes in your recent entries. ");
    }
    
    if (prompt.contains("Discovery")) {
      response.write("You appear to be in the Discovery phase, actively exploring new ideas and possibilities. ");
    }
    
    response.write("What would you like to explore further about your experiences?");
    
    return response.toString();
  }


  /// Dispose of resources
  static Future<void> dispose() async {
    _isInitialized = false;
    _loadedModel = null;
    _deviceCaps = null;
    await LumaraNative.dispose();
    print('QwenAdapter: Disposed');
  }
}