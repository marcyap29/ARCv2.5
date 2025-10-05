import 'dart:async';
import 'package:flutter/foundation.dart';
import 'model_adapter.dart';
import 'bridge.pigeon.dart' as pigeon;
import 'model_progress_service.dart';

/// On-device LLM adapter using Pigeon native bridge
/// Supports multiple model formats: MLX (iOS), GGUF (Android via llama.cpp)
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

      // Check for specific model availability (same logic as LumaraAPIConfig)
      try {
        // Check for Qwen model first (priority)
        final qwenDownloaded = await _nativeApi.isModelDownloaded('qwen3-1.7b-mlx-4bit');
        debugPrint('[LLMAdapter] Qwen model downloaded: $qwenDownloaded');
        
        if (qwenDownloaded) {
          _activeModelId = 'qwen3-1.7b-mlx-4bit';
          _available = true;
          _isInitialized = true;
          debugPrint('[LLMAdapter] Using Qwen model: $_activeModelId');
        } else {
          // Check for Phi model as fallback
          final phiDownloaded = await _nativeApi.isModelDownloaded('phi-3.5-mini-instruct-4bit');
          debugPrint('[LLMAdapter] Phi model downloaded: $phiDownloaded');
          
          if (phiDownloaded) {
            _activeModelId = 'phi-3.5-mini-instruct-4bit';
            _available = true;
            _isInitialized = true;
            debugPrint('[LLMAdapter] Using Phi model: $_activeModelId');
          } else {
            _reason = 'no_models_downloaded';
            _available = false;
            _isInitialized = false;
            debugPrint('[LLMAdapter] No models downloaded');
            return false;
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
    // The Swift side (LumaraPromptSystem) will handle all prompt formatting
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
      // Generate with native model
      final params = pigeon.GenParams(
        maxTokens: 256,
        temperature: 0.7,
        topP: 0.9,
        repeatPenalty: 1.1,
        seed: 101,
      );
      
      debugPrint('⚙️  GENERATION PARAMS: maxTokens=${params.maxTokens}, temp=${params.temperature}');
      debugPrint('🚀 Calling native generateText with user message...');

      final result = await _nativeApi.generateText(userMessage, params);

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
