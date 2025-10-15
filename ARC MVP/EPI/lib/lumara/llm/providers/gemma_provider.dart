// lib/lumara/llm/providers/gemma_provider.dart
// Google Gemma internal model provider implementation

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../llm_provider.dart';
import '../../config/api_config.dart';
import '../bridge.pigeon.dart';
import '../prompts/prompt_profile_manager.dart';
import '../ondevice_prompt_service.dart';

/// Google Gemma internal model provider
class GemmaProvider extends LLMProviderBase {
  GemmaProvider(LumaraAPIConfig apiConfig) : super(apiConfig, 'Google Gemma 3n E2B (Internal)', true);

  @override
  LLMProvider getProviderType() => LLMProvider.gemma3n;

  @override
  Future<bool> isAvailable() async {
    // Check if Gemma model is actually downloaded via native bridge
    try {
      final bridge = LumaraNative();
      final isDownloaded = await bridge.isModelDownloaded('google_gemma-3n-E2B-it-Q6_K_L.gguf');
      debugPrint('GemmaProvider: Model ${isDownloaded ? "IS" : "IS NOT"} downloaded');
      return isDownloaded;
    } catch (e) {
      debugPrint('GemmaProvider: Error checking model availability: $e');
      return false;
    }
  }

  @override
  Future<String> generateResponse(Map<String, dynamic> context) async {
    final systemPrompt = context['systemPrompt'] as String;
    final userPrompt = context['userPrompt'] as String;
    
    // Format the prompt for Gemma
    final formattedPrompt = _formatPrompt(systemPrompt, userPrompt);
    
    try {
      debugPrint('GemmaProvider: Generating response for prompt length: ${formattedPrompt.length}');
      
      // Check availability first
      if (!await isAvailable()) {
        throw Exception('Gemma model not available - please download it first');
      }

      // Use native bridge to generate response
      final bridge = LumaraNative();
      
      // First, ensure the model is initialized
      final modelPath = 'google_gemma-3n-E2B-it-Q6_K_L.gguf';
      final initialized = await bridge.initModel(modelPath);
      
      if (!initialized) {
        debugPrint('GemmaProvider: Failed to initialize model');
        throw StateError('Failed to initialize Gemma model');
      }
      
      // Use the generateText method with appropriate parameters
      final params = GenParams(
        maxTokens: 50, // Reduced for 5-10 word responses
        temperature: 0.7,
        topP: 0.8,
        repeatPenalty: 1.1,
        seed: 42, // Fixed seed for reproducibility
      );
      
      final result = await bridge.generateText(formattedPrompt, params);
      final response = result.text;
      
      debugPrint('GemmaProvider: Generated response length: ${response.length}');
      return response;
    } catch (e) {
      debugPrint('GemmaProvider: Error generating response: $e');
      rethrow;
    }
  }

  @override
  Map<String, dynamic> getStatus() {
    return {
      'name': name,
      'isInternal': true,
      'isAvailable': false, // Will be checked dynamically
      'modelPath': 'google_gemma-3n-E2B-it-Q6_K_L.gguf',
      'providerType': 'gemma3n',
    };
  }

  /// Format prompt for Gemma model
  String _formatPrompt(String systemPrompt, String userPrompt) {
    // Gemma uses a simple format: system prompt + user prompt
    return '$systemPrompt\n\n$userPrompt';
  }
}
