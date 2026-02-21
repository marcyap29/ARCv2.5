// lib/lumara/llm/providers/openai_provider.dart
// OpenAI API provider implementation

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../llm_provider.dart';
import '../../config/api_config.dart';

/// OpenAI API provider
class OpenAIProvider extends LLMProviderBase {
  OpenAIProvider(LumaraAPIConfig apiConfig) : super(apiConfig, 'OpenAI GPT', false);

  @override
  LLMProvider getProviderType() => LLMProvider.openai;

  @override
  Future<bool> isAvailable() async {
    final config = getConfig();
    return config?.isAvailable == true && config?.apiKey?.isNotEmpty == true;
  }

  @override
  Future<String> generateResponse(Map<String, dynamic> context) async {
    final config = getConfig();
    if (config?.apiKey == null) {
      throw StateError('OpenAI API key not configured');
    }

    final apiKey = config!.apiKey!;
    final systemPrompt = context['systemPrompt'] as String;
    final userPrompt = context['userPrompt'] as String;

    final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
    
    final body = {
      'model': 'gpt-4o-mini',
      'messages': [
        {
          'role': 'system',
          'content': systemPrompt,
        },
        {
          'role': 'user',
          'content': userPrompt,
        },
      ],
      'max_tokens': 500,
      'temperature': 0.7,
      'top_p': 0.8,
    };

    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Authorization', 'Bearer $apiKey');
      request.write(jsonEncode(body));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        final choices = data['choices'] as List?;
        
        if (choices != null && choices.isNotEmpty) {
          final message = choices[0]['message'] as Map<String, dynamic>?;
          final content = message?['content'] as String?;
          
          if (content != null && content.isNotEmpty) {
            return content.trim();
          }
        }
      }

      throw HttpException('OpenAI API error: ${response.statusCode} - $responseBody');
    } catch (e) {
      debugPrint('OpenAIProvider: Error generating response: $e');
      rethrow;
    } finally {
      client.close();
    }
  }
}
