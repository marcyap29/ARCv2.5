// lib/lumara/llm/providers/qwen_provider.dart
// Qwen internal model provider implementation

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../llm_provider.dart';
import '../../config/api_config.dart';
import '../bridge.pigeon.dart';

/// Qwen internal model provider
class QwenProvider extends LLMProviderBase {
  QwenProvider(LumaraAPIConfig apiConfig) : super(apiConfig, 'Qwen (Internal)', true);

  @override
  LLMProvider getProviderType() => LLMProvider.qwen;

  @override
  Future<bool> isAvailable() async {
    // Check if Qwen model is actually downloaded via native bridge
    try {
      final bridge = LumaraNative();
      final isDownloaded = await bridge.isModelDownloaded('Llama-3.2-3b-Instruct-Q4_K_M.gguf');
      debugPrint('QwenProvider: Model ${isDownloaded ? "IS" : "IS NOT"} downloaded');
      return isDownloaded;
    } catch (e) {
      debugPrint('QwenProvider: Error checking model availability: $e');
      return false;
    }
  }

  @override
  Future<String> generateResponse(Map<String, dynamic> context) async {
    final config = getConfig();
    if (config?.baseUrl == null) {
      throw StateError('Qwen server URL not configured');
    }

    final systemPrompt = context['systemPrompt'] as String;
    final userPrompt = context['userPrompt'] as String;
    final additionalConfig = config!.additionalConfig ?? {};

    final uri = Uri.parse('${config.baseUrl}/generate');
    
    final body = {
      'prompt': _formatPrompt(systemPrompt, userPrompt),
      'max_tokens': 500,
      'temperature': additionalConfig['temperature'] ?? 0.7,
      'top_p': 0.8,
      'top_k': 40,
      'repetition_penalty': 1.1,
      'stop': ['<|im_end|>', '<|endoftext|>'],
    };

    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.write(jsonEncode(body));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        final text = data['response'] as String?;
        
        if (text != null && text.isNotEmpty) {
          return _cleanResponse(text);
        }
      }

      throw HttpException('Qwen API error: ${response.statusCode} - $responseBody');
    } catch (e) {
      debugPrint('QwenProvider: Error generating response: $e');
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Format prompt for Qwen model
  String _formatPrompt(String systemPrompt, String userPrompt) {
    return '''<|im_start|>system
$systemPrompt
<|im_end|>
<|im_start|>user
$userPrompt
<|im_end|>
<|im_start|>assistant''';
  }

  /// Clean response from Qwen model
  String _cleanResponse(String response) {
    // Remove common Qwen artifacts
    return response
        .replaceAll(RegExp(r'<\|im_start\|>.*?<\|im_end\|>', dotAll: true), '')
        .replaceAll(RegExp(r'<\|endoftext\|>'), '')
        .trim();
  }
}
