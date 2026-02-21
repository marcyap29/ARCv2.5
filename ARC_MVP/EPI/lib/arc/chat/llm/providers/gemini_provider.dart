// lib/lumara/llm/providers/gemini_provider.dart
// Gemini API provider implementation

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../llm_provider.dart';
import '../../config/api_config.dart';
import '../prompt_templates.dart';

/// Gemini API provider
class GeminiProvider extends LLMProviderBase {
  GeminiProvider(LumaraAPIConfig apiConfig) : super(apiConfig, 'Google Gemini', false);

  @override
  LLMProvider getProviderType() => LLMProvider.gemini;

  @override
  Future<bool> isAvailable() async {
    final config = getConfig();
    return config?.isAvailable == true && config?.apiKey?.isNotEmpty == true;
  }

  @override
  Future<String> generateResponse(Map<String, dynamic> context) async {
    final config = getConfig();
    if (config?.apiKey == null) {
      throw StateError('Cloud AI API key not configured. Add Groq or Gemini in LUMARA Settings.');
    }

    final apiKey = config!.apiKey!;
    final systemPrompt = context['systemPrompt'] as String;
    final userPrompt = context['userPrompt'] as String;

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
    );

    // Use the passed system prompt or default to LUMARA Reflective Intelligence Core
    final lumaraSystemPrompt = systemPrompt.isNotEmpty ? systemPrompt : PromptTemplates.lumaraReflectiveCore;
    
    // Clean the user prompt to remove special characters that cause JSON parsing issues
    final cleanUserPrompt = userPrompt
        .replaceAll('•', '-')  // Replace bullet points with dashes
        .replaceAll('\n\n\n', '\n\n')  // Remove excessive newlines
        .replaceAll(RegExp(r'[^\x00-\x7F]'), '')  // Remove non-ASCII characters
        .trim();
    
    final body = {
      if (lumaraSystemPrompt.trim().isNotEmpty)
        'systemInstruction': {
          'role': 'system',
          'parts': [
            {'text': lumaraSystemPrompt}
          ]
        },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': cleanUserPrompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 8192,  // Maximum allowed by Gemini API - no length limit
        'topP': 0.8,
        'topK': 40,
      },
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
        final candidates = data['candidates'] as List?;
        
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List?;
          
          if (parts != null && parts.isNotEmpty) {
            final text = parts[0]['text'] as String?;
            if (text != null && text.isNotEmpty) {
              return text.trim();
            }
          }
        }
      }

      throw HttpException('Cloud AI error: ${response.statusCode} - $responseBody');
    } catch (e) {
      debugPrint('GeminiProvider: Error generating response: $e');
      rethrow;
    } finally {
      client.close();
    }
  }
}
