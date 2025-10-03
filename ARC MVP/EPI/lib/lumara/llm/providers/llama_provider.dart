// lib/lumara/llm/providers/llama_provider.dart
// Llama internal model provider implementation

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../llm_provider.dart';
import '../../config/api_config.dart';

/// Llama internal model provider
class LlamaProvider extends LLMProviderBase {
  LlamaProvider(LumaraAPIConfig apiConfig) : super(apiConfig, 'Llama (Internal)', true);

  @override
  LLMProvider getProviderType() => LLMProvider.phi;

  @override
  Future<bool> isAvailable() async {
    final config = getConfig();
    if (config?.baseUrl == null) return false;

    try {
      // Check if local Llama server is running
      final client = HttpClient();
      final uri = Uri.parse('${config!.baseUrl}/health');
      
      final request = await client.getUrl(uri);
      final response = await request.close();
      
      client.close();
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('LlamaProvider: Health check failed: $e');
      return false;
    }
  }

  @override
  Future<String> generateResponse(Map<String, dynamic> context) async {
    final config = getConfig();
    if (config?.baseUrl == null) {
      throw StateError('Llama server URL not configured');
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
      'repeat_penalty': 1.1,
      'stop': ['</s>', '[INST]', '[/INST]'],
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

      throw HttpException('Llama API error: ${response.statusCode} - $responseBody');
    } catch (e) {
      debugPrint('LlamaProvider: Error generating response: $e');
      rethrow;
    } finally {
      client.close();
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
