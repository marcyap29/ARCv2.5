// lib/lumara/llm/providers/anthropic_provider.dart
// Anthropic Claude API provider implementation

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../llm_provider.dart';
import '../../config/api_config.dart';

/// Anthropic Claude API provider
class AnthropicProvider extends LLMProviderBase {
  AnthropicProvider(LumaraAPIConfig apiConfig) : super(apiConfig, 'Anthropic Claude', false);

  @override
  LLMProvider getProviderType() => LLMProvider.anthropic;

  @override
  Future<bool> isAvailable() async {
    final config = getConfig();
    return config?.isAvailable == true && config?.apiKey?.isNotEmpty == true;
  }

  @override
  Future<String> generateResponse(Map<String, dynamic> context) async {
    final config = getConfig();
    if (config?.apiKey == null) {
      throw StateError('Anthropic API key not configured');
    }

    final apiKey = config!.apiKey!;
    final systemPrompt = context['systemPrompt'] as String;
    final userPrompt = context['userPrompt'] as String;

    final uri = Uri.parse('https://api.anthropic.com/v1/messages');
    
    final body = {
      'model': 'claude-3-5-sonnet-20241022',
      'max_tokens': 500,
      'temperature': 0.7,
      'system': systemPrompt,
      'messages': [
        {
          'role': 'user',
          'content': userPrompt,
        },
      ],
    };

    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('x-api-key', apiKey);
      request.headers.set('anthropic-version', '2023-06-01');
      request.write(jsonEncode(body));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        final content = data['content'] as List?;
        
        if (content != null && content.isNotEmpty) {
          final text = content[0]['text'] as String?;
          
          if (text != null && text.isNotEmpty) {
            return text.trim();
          }
        }
      }

      throw HttpException('Anthropic API error: ${response.statusCode} - $responseBody');
    } catch (e) {
      debugPrint('AnthropicProvider: Error generating response: $e');
      rethrow;
    } finally {
      client.close();
    }
  }
}
