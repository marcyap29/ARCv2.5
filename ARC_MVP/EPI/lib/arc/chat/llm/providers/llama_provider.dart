// lib/lumara/llm/providers/llama_provider.dart
// Llama internal model provider implementation

import 'package:flutter/foundation.dart';
import '../llm_provider.dart';
import '../../config/api_config.dart';
import '../bridge.pigeon.dart';

/// Llama/Phi internal model provider
class LlamaProvider extends LLMProviderBase {
  LlamaProvider(LumaraAPIConfig apiConfig) : super(apiConfig, 'Llama 3.2 3B (Internal)', true);

  @override
  LLMProvider getProviderType() => LLMProvider.llama3b;

  @override
  Future<bool> isAvailable() async {
    // Check if Phi model is actually downloaded via native bridge
    try {
      final bridge = LumaraNative();
      final isDownloaded = await bridge.isModelDownloaded('Llama-3.2-3b-Instruct-Q4_K_M.gguf');
      debugPrint('LlamaProvider: Model ${isDownloaded ? "IS" : "IS NOT"} downloaded');
      return isDownloaded;
    } catch (e) {
      debugPrint('LlamaProvider: Error checking model availability: $e');
      return false;
    }
  }

  @override
  Future<String> generateResponse(Map<String, dynamic> context) async {
    final systemPrompt = context['systemPrompt'] as String;
    final userPrompt = context['userPrompt'] as String;
    
    // Format the prompt for Llama
    final formattedPrompt = _formatPrompt(systemPrompt, userPrompt);
    
    try {
      // Use native bridge to generate response
      final bridge = LumaraNative();
      
      // First, ensure the model is initialized
      final modelPath = 'Llama-3.2-3b-Instruct-Q4_K_M.gguf';
      final initialized = await bridge.initModel(modelPath);
      
      if (!initialized) {
        debugPrint('LlamaProvider: Failed to initialize model');
        throw StateError('Failed to initialize Llama model');
      }
      
      // Use the generateText method with appropriate parameters
      final params = GenParams(
        maxTokens: 50, // Reduced for 5-10 word responses
        temperature: 0.7,
        topP: 0.8,
        repeatPenalty: 1.1,
        seed: 42, // Fixed seed for reproducible results
      );
      
      final result = await bridge.generateText(formattedPrompt, params);
      final response = result.text;
      
      if (response.isNotEmpty) {
        return _cleanResponse(response);
      }
      
      throw StateError('Empty response from Llama model');
    } catch (e) {
      debugPrint('LlamaProvider: Error generating response: $e');
      rethrow;
    }
  }

  /// Format prompt for Llama model
  String _formatPrompt(String systemPrompt, String userPrompt) {
    return '''<s>[INST] <<SYS>>
$systemPrompt
<</SYS>>

$userPrompt [/INST]''';
  }

  /// Clean response from Llama model
  String _cleanResponse(String response) {
    // Remove common Llama artifacts
    return response
        .replaceAll(RegExp(r'\[INST\].*?\[/INST\]', dotAll: true), '')
        .replaceAll(RegExp(r'<s>|</s>'), '')
        .replaceAll(RegExp(r'<<SYS>>.*?<</SYS>>', dotAll: true), '')
        .trim();
  }
}
