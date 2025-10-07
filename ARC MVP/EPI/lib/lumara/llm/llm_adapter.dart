import 'dart:async';
import 'package:flutter/foundation.dart';
import 'model_adapter.dart';
import 'bridge.pigeon.dart' as pigeon;
import 'model_progress_service.dart';
import 'prompts/lumara_prompt_assembler.dart';
import 'prompts/lumara_model_presets.dart';

/// On-device LLM adapter using Pigeon native bridge
/// Supports GGUF models via llama.cpp with Metal acceleration (iOS)
class LLMAdapter implements ModelAdapter {
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

      // Check for GGUF model availability (llama.cpp + Metal)
      try {
        // Check for Llama-3.2-3B model first (priority)
        final llamaDownloaded = await _nativeApi.isModelDownloaded('Llama-3.2-3b-Instruct-Q4_K_M.gguf');
        debugPrint('[LLMAdapter] Llama-3.2-3B model downloaded: $llamaDownloaded');
        
        if (llamaDownloaded) {
          _activeModelId = 'Llama-3.2-3b-Instruct-Q4_K_M.gguf';
          _available = true;
          _isInitialized = true;
          debugPrint('[LLMAdapter] Using Llama-3.2-3B model: $_activeModelId');
        } else {
          // Check for Phi-3.5 model as fallback
          final phiDownloaded = await _nativeApi.isModelDownloaded('Phi-3.5-mini-instruct-Q5_K_M.gguf');
          debugPrint('[LLMAdapter] Phi-3.5 model downloaded: $phiDownloaded');
          
          if (phiDownloaded) {
            _activeModelId = 'Phi-3.5-mini-instruct-Q5_K_M.gguf';
            _available = true;
            _isInitialized = true;
            debugPrint('[LLMAdapter] Using Phi-3.5 model: $_activeModelId');
          } else {
            // Check for Qwen3-4B model as final fallback
            final qwenDownloaded = await _nativeApi.isModelDownloaded('Qwen3-4B-Instruct-2507-Q5_K_M.gguf');
            debugPrint('[LLMAdapter] Qwen3-4B model downloaded: $qwenDownloaded');
            
            if (qwenDownloaded) {
              _activeModelId = 'Qwen3-4B-Instruct-2507-Q5_K_M.gguf';
              _available = true;
              _isInitialized = true;
              debugPrint('[LLMAdapter] Using Qwen3-4B model: $_activeModelId');
            } else {
              _reason = 'no_gguf_models_downloaded';
              _available = false;
              _isInitialized = false;
              debugPrint('[LLMAdapter] No GGUF models downloaded');
              return false;
            }
          }
        }
      } catch (e) {
        debugPrint('[LLMAdapter] Failed to check model availability: $e');
        _reason = 'model_check_error: $e';
        _available = false;
        _isInitialized = false;
        return false;
      }

      // Initialize the selected model
      try {
        debugPrint('[LLMAdapter] Starting async model initialization...');
        final success = await _nativeApi.initModel(_activeModelId!);

        if (success) {
          // Wait for model to finish loading (progress will reach 100%)
          debugPrint('[LLMAdapter] Waiting for model to load...');
          try {
            await ModelProgressService().waitForCompletion(
              _activeModelId!,
              timeout: const Duration(minutes: 2),
            );

            _isInitialized = true;
            _available = true;
            _reason = 'ok';
            debugPrint('[LLMAdapter] Successfully initialized model: $_activeModelId');
            return true;
          } on TimeoutException {
            debugPrint('[LLMAdapter] Model loading timeout');
            _reason = 'model_loading_timeout';
            _available = false;
            _isInitialized = false;
            return false;
          }
        } else {
          _reason = 'model_init_failed';
          _available = false;
          _isInitialized = false;
          return false;
        }
      } catch (e) {
        debugPrint('[LLMAdapter] Model initialization failed: $e');
        _reason = 'init_error: $e';
        _available = false;
        _isInitialized = false;
        return false;
      }
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
      // Build optimized prompt using LUMARA prompt assembler
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
      );

      final promptAssembler = LumaraPromptAssembler(
        contextBuilder: contextBuilder,
        includeFewShotExamples: true,
        includeQualityGuardrails: true,
      );

      // Assemble the complete optimized prompt
      final optimizedPrompt = promptAssembler.assemblePrompt(
        userMessage: userMessage,
        useFewShot: true,
      );

      debugPrint('📝 OPTIMIZED PROMPT LENGTH: ${optimizedPrompt.length} characters');
      debugPrint('📝 PROMPT PREVIEW: ${optimizedPrompt.substring(0, 200)}...');

      // Get model-specific parameters
      final modelName = _activeModelId ?? 'Llama-3.2-3b-Instruct-Q4_K_M.gguf';
      final preset = LumaraModelPresets.getPreset(modelName);
      
      final params = pigeon.GenParams(
        maxTokens: preset['max_new_tokens'] ?? 256,
        temperature: preset['temperature'] ?? 0.7,
        topP: preset['top_p'] ?? 0.9,
        topK: preset['top_k'] ?? 40,
        repeatPenalty: preset['repeat_penalty'] ?? 1.1,
        seed: 101,
      );
      
      debugPrint('⚙️  GENERATION PARAMS: maxTokens=${params.maxTokens}, temp=${params.temperature}, topP=${params.topP}, topK=${params.topK}');
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
        await Future.delayed(const Duration(milliseconds: 30));
      }
      debugPrint('🟩🟩🟩 === DART LLMAdapter.realize COMPLETE === 🟩🟩🟩');
    } catch (e) {
      debugPrint('❌ [LLMAdapter] Generation error: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      debugPrint('🟩🟩🟩 === DART LLMAdapter.realize ERROR === 🟩🟩🟩');
      yield 'Error generating response: $e';
    }
  }

  // Prompt building is now handled entirely by the Swift side (LumaraPromptSystem)
  // which uses the EPI-aware LUMARA Lite system prompt with SAGE Echo, Arcform candidates, etc.
}
