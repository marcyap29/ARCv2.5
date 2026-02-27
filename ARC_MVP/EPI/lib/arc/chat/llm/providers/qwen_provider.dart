// lib/lumara/llm/providers/qwen_provider.dart
// Qwen internal model provider implementation

import 'package:flutter/foundation.dart';
import '../llm_provider.dart';
import '../../config/api_config.dart';
import '../bridge.pigeon.dart';
import '../ondevice_prompt_service.dart';

/// Qwen internal model provider
class QwenProvider extends LLMProviderBase {
  QwenProvider(LumaraAPIConfig apiConfig) : super(apiConfig, 'Qwen3 4B (Internal)', true);

  @override
  LLMProvider getProviderType() => LLMProvider.qwen4b;

  @override
  Future<bool> isAvailable() async {
    // Check if Qwen model is actually downloaded via native bridge
    try {
      final bridge = LumaraNative();
      final isDownloaded = await bridge.isModelDownloaded('Qwen3-4B-Instruct-2507-Q4_K_S.gguf');
      debugPrint('QwenProvider: Model ${isDownloaded ? "IS" : "IS NOT"} downloaded');
      return isDownloaded;
    } catch (e) {
      debugPrint('QwenProvider: Error checking model availability: $e');
      return false;
    }
  }

  @override
  Future<String> generateResponse(Map<String, dynamic> context) async {
    final systemPrompt = context['systemPrompt'] as String;
    final userPrompt = context['userPrompt'] as String;
    
    // Use on-device specific prompt formatting
    final formattedPrompt = OnDevicePromptService.formatOnDevicePromptLegacy(systemPrompt, userPrompt);
    
    try {
      // Use native bridge to generate response
      final bridge = LumaraNative();
      
      // First, ensure the model is initialized
      const modelId = 'Qwen3-4B-Instruct-2507-Q4_K_S.gguf';
      final initialized = await bridge.initModel(modelId);
      
      if (!initialized) {
        debugPrint('QwenProvider: Failed to initialize model');
        throw StateError('Failed to initialize Qwen model');
      }
      
      // Use the generateText method with appropriate parameters for short responses
      final params = GenParams(
        maxTokens: 50, // Reduced for 5-10 word responses
        temperature: 0.7,
        topP: 0.8,
        repeatPenalty: 1.1,
        seed: 42, // Fixed seed for reproducible results
      );
      
      final result = await bridge.generateText(formattedPrompt, params);
      
      if (result.text.isNotEmpty) {
        // Use on-device specific response cleaning
        return OnDevicePromptService.cleanOnDeviceResponse(result.text);
      }
      
      throw StateError('Empty response from Qwen model');
    } catch (e) {
      debugPrint('QwenProvider: Error generating response: $e');
      rethrow;
    }
  }
}
