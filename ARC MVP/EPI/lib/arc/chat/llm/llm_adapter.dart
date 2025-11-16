import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:my_app/core/llm/model_adapter.dart';
import 'bridge.pigeon.dart' as pigeon;
import 'prompts/lumara_prompt_assembler.dart';
import 'prompts/lumara_model_presets.dart';
import 'prompts/chat_templates.dart';
import '../services/favorites_service.dart';

/// On-device LLM adapter using Pigeon native bridge
/// GGUF models (Llama/Qwen3) are no longer supported - models not installed
class LLMAdapter implements ModelAdapter {
  /// Compute SHA-256 hash of a string for prompt verification
  static String sha256Of(String s) => crypto.sha256.convert(utf8.encode(s)).toString();
  
  /// Canary test to verify no test stubs are present
  static Future<String> runCanaryTest(String testType) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (!_available) {
      return "Error: LLMAdapter not available - ${_reason}";
    }
    
    String testPrompt;
    String expectedResponse;
    
    switch (testType) {
      case 'echo':
        testPrompt = "Reply with only: ACK";
        expectedResponse = "ACK";
        break;
      case 'system':
        testPrompt = "<<SYSTEM>>\nYou are LUMARA. Reply with only \"LUMARA_OK\".\n\n<<USER>>\nTest";
        expectedResponse = "LUMARA_OK";
        break;
      default:
        return "Error: Unknown test type: $testType";
    }
    
    try {
      final result = await _nativeApi.generateText(testPrompt, pigeon.GenParams(
        maxTokens: 10,
        temperature: 0.0,
        topP: 1.0,
        repeatPenalty: 1.0,
        seed: 42,
      ));
      
      final response = result.text.trim();
      final isCorrect = response == expectedResponse;
      
      return "Canary Test ($testType): ${isCorrect ? 'PASS' : 'FAIL'}\n" +
             "Expected: '$expectedResponse'\n" +
             "Actual: '$response'\n" +
             "Hash: ${sha256Of(testPrompt)}";
    } catch (e) {
      return "Canary Test ($testType): ERROR - $e";
    }
  }
  static bool _isInitialized = false;
  static String? _activeModelId;
  static bool _available = false;
  static String _reason = 'uninitialized';

  // Pigeon bridge API
  static final _nativeApi = pigeon.LumaraNative();

  /// Initialize the LLM adapter
  static Future<bool> initialize() async {
    try {
      debugPrint('[LLMAdapter] Starting initialization...');

      // Self-test to verify bridge is working
      try {
        final testResult = await _nativeApi.selfTest();
        debugPrint('[LLMAdapter] Self-test: ${testResult.message} (${testResult.platform} v${testResult.version})');

        if (!testResult.ok) {
          _reason = 'self_test_failed';
          _available = false;
          _isInitialized = false;
          return false;
        }
      } catch (e) {
        _reason = 'bridge_not_available: $e';
        _available = false;
        debugPrint('[LLMAdapter] Native bridge not available: $e');
        _isInitialized = false;
        return false;
      }

      // GGUF models (Llama/Qwen3) are no longer supported - models not installed
      _reason = 'no_gguf_models_available';
      _available = false;
      _isInitialized = false;
      debugPrint('[LLMAdapter] GGUF models not available (models not installed)');
      return false;
    } catch (e) {
      debugPrint('[LLMAdapter] Unexpected initialization error: $e');
      _reason = 'unexpected_error: $e';
      _available = false;
      _isInitialized = false;
      return false;
    }
  }

  /// Check if adapter is ready
  static bool get isReady {
    final ready = _isInitialized && _activeModelId != null;
    debugPrint('[LLMAdapter] isReady check - initialized: $_isInitialized, activeModel: $_activeModelId, result: $ready');
    return ready;
  }

  /// Check if adapter is available
  static bool get isAvailable => _available;

  /// Get reason for availability status
  static String get reason => _reason;

  /// Get loaded model information
  static String get loadedModel => _activeModelId ?? 'none';

  /// Get active model name for external use
  static String? get activeModelName => _activeModelId;

  /// Stop the current model and free resources
  static Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      await _nativeApi.stopModel();
      debugPrint('[LLMAdapter] Model stopped successfully');
    } catch (e) {
      debugPrint('[LLMAdapter] Error stopping model: $e');
    }

    _isInitialized = false;
    _activeModelId = null;
    _available = false;
    _reason = 'disposed';
  }

  /// Get model status for diagnostics
  static Future<pigeon.ModelStatus?> getModelStatus(String modelId) async {
    try {
      return await _nativeApi.getModelStatus(modelId);
    } catch (e) {
      debugPrint('[LLMAdapter] Error getting model status: $e');
      return null;
    }
  }

  /// Check if a model is available (downloaded)
  static Future<bool> isModelAvailable(String modelId) async {
    try {
      return await _nativeApi.isModelDownloaded(modelId);
    } catch (e) {
      debugPrint('[LLMAdapter] Error checking model availability: $e');
      return false;
    }
  }

  @override
  Stream<String> realize({
    required String task,
    required Map<String, dynamic> facts,
    required List<String> snippets,
    required List<Map<String, String>> chat,
  }) async* {
    if (!isReady) {
      debugPrint('[LLMAdapter] Not ready - $_reason');
      yield 'LLM not available: $_reason';
      return;
    }

    // Extract the user's actual message from chat
    String userMessage = '';
    if (chat.isNotEmpty) {
      // Get the last user message
      final lastUserTurn = chat.lastWhere(
        (turn) => turn['role'] == 'user',
        orElse: () => {'content': ''},
      );
      userMessage = lastUserTurn['content'] ?? '';
    }
    
    debugPrint('🟩🟩🟩 === DART LLMAdapter.realize === 🟩🟩🟩');
    debugPrint('📥 TASK: $task');
    debugPrint('📥 USER MESSAGE: "$userMessage"');
    debugPrint('📥 USER MESSAGE LENGTH: ${userMessage.length} characters');

    try {
      // Use minimal prompt for simple chat messages (< 20 chars) to avoid slow prefill
      // Only use full context for complex queries
      final useMinimalPrompt = userMessage.length < 20 &&
                               !userMessage.contains('?') &&
                               snippets.isEmpty;

      String optimizedPrompt;

      if (useMinimalPrompt) {
        // Fast path: minimal prompt for quick responses
        debugPrint('⚡ Using MINIMAL prompt for quick chat');
        final systemMessage = "You are LUMARA, a helpful and friendly AI assistant. Keep your responses brief and natural.";
        optimizedPrompt = ChatTemplates.getTemplate(
          _activeModelId ?? 'Llama-3.2-3b-Instruct-Q4_K_M.gguf',
          systemMessage: ChatTemplates.toAscii(systemMessage),
          userMessage: ChatTemplates.toAscii(userMessage),
        );
      } else {
        // Full path: complete context for complex queries
        debugPrint('📚 Using FULL prompt with context');
        
        // Load favorites for style examples
        final favoritesService = FavoritesService.instance;
        await favoritesService.initialize();
        final favorites = await favoritesService.getFavoritesForPrompt(count: 5);
        final favoriteExamples = favorites.map((f) => f.content).toList();
        
        final contextBuilder = LumaraPromptAssembler.createContextBuilder(
          userName: 'Marc Yap', // TODO: Get from user profile
          currentPhase: facts['current_phase'] ?? 'Discovery',
          recentKeywords: snippets.take(10).toList(),
          memorySnippets: snippets.take(8).toList(),
          journalExcerpts: chat
              .where((turn) => turn['role'] == 'user')
              .map((turn) => turn['content'] ?? '')
              .where((content) => content.isNotEmpty)
              .take(3)
              .toList(),
          favoriteExamples: favoriteExamples,
        );

        final promptAssembler = LumaraPromptAssembler(
          contextBuilder: contextBuilder,
          includeFewShotExamples: false, // Disable few-shot for faster prefill
          includeQualityGuardrails: false, // Disable guardrails for faster prefill
        );

        // Assemble the complete optimized prompt
        final assembledPrompt = promptAssembler.assemblePrompt(
          userMessage: userMessage,
          useFewShot: false, // Disable few-shot examples
        );

        // Use model-specific chat template (fallback to generic if no model)
          optimizedPrompt = ChatTemplates.getTemplate(
            _activeModelId ?? 'generic',
            systemMessage: ChatTemplates.toAscii(_extractSystemMessage(assembledPrompt)),
            userMessage: ChatTemplates.toAscii(userMessage),
          );
      }

      debugPrint('📝 OPTIMIZED PROMPT LENGTH: ${optimizedPrompt.length} characters');
      debugPrint('📝 PROMPT PREVIEW: ${optimizedPrompt.substring(0, 200)}...');
      
      // Compute SHA-256 hash for prompt verification
      final promptHash = sha256Of(optimizedPrompt);
      debugPrint('🔐 PROMPT HASH: $promptHash');

      // Get model-specific parameters (fallback to generic if no model)
      final modelName = _activeModelId ?? 'generic';
      final preset = LumaraModelPresets.getPreset(modelName);
      
      // Use optimized parameters for tiny models
      // Increased limits to prevent response cutoff:
      // - Minimal prompts: 128 tokens (allows 2-3 complete sentences)
      // - Normal prompts: Use preset value or 256 default (allows meaningful paragraphs)
      final adaptiveMaxTokens = useMinimalPrompt
          ? 128   // Increased from 32 to allow complete thoughts
          : (preset['max_new_tokens'] ?? 256);  // Use preset value or reasonable default (increased from 64)

      final params = pigeon.GenParams(
        maxTokens: adaptiveMaxTokens,
        temperature: preset['temperature'] ?? 0.35,
        topP: preset['top_p'] ?? 0.9,
        repeatPenalty: preset['repeat_penalty'] ?? 1.08,
        seed: 101,
      );
      
      debugPrint('⚙️  GENERATION PARAMS: maxTokens=${params.maxTokens}, temp=${params.temperature}, topP=${params.topP}, repeatPenalty=${params.repeatPenalty}');
      debugPrint('🚀 Calling native generateText with optimized prompt...');

      final result = await _nativeApi.generateText(optimizedPrompt, params);

      debugPrint('✅ NATIVE GENERATION COMPLETE:');
      debugPrint('  📤 text: "${result.text}"');
      debugPrint('  📤 length: ${result.text.length}');
      debugPrint('  📊 tokensIn: ${result.tokensIn}');
      debugPrint('  📊 tokensOut: ${result.tokensOut}');
      debugPrint('  ⏱️  latencyMs: ${result.latencyMs}');
      debugPrint('  🏷️  provider: ${result.provider}');
      debugPrint('[LLMAdapter] Generated ${result.tokensOut} tokens in ${result.latencyMs}ms (${result.provider})');

      // Stream the response word by word for consistency
      final words = result.text.split(' ');
      debugPrint('🔄 Streaming ${words.length} words to UI...');
      for (int i = 0; i < words.length; i++) {
        yield words[i] + (i < words.length - 1 ? ' ' : '');
        // No delay - instant streaming for maximum responsiveness
      }
      debugPrint('🟩🟩🟩 === DART LLMAdapter.realize COMPLETE === 🟩🟩🟩');
    } catch (e) {
      debugPrint('❌ [LLMAdapter] Generation error: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      debugPrint('🟩🟩🟩 === DART LLMAdapter.realize ERROR === 🟩🟩🟩');
      yield 'Error generating response: $e';
    }
  }

  /// Extract system message from assembled prompt
  static String _extractSystemMessage(String assembledPrompt) {
    final systemStart = assembledPrompt.indexOf('<<SYSTEM>>');
    final contextStart = assembledPrompt.indexOf('<<CONTEXT>>');
    
    if (systemStart != -1 && contextStart != -1) {
      final systemEnd = contextStart;
      return assembledPrompt.substring(systemStart + 10, systemEnd).trim();
    }
    
    return "You are LUMARA, a personal AI assistant.";
  }

  // Prompt building is now handled entirely by the Swift side (LumaraPromptSystem)
  // which uses the EPI-aware LUMARA Lite system prompt with SAGE Echo, Arcform candidates, etc.
}
