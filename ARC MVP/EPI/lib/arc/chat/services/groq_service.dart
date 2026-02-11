// lib/arc/chat/services/groq_service.dart
// Groq API service for LUMARA: Llama 3.3 70B primary, Mixtral 8x7b backup

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

enum GroqModel {
  llama33_70b('llama-3.3-70b-versatile', 128000),
  mixtral_8x7b('mixtral-8x7b-32768', 32768);

  final String id;
  final int contextWindow;
  const GroqModel(this.id, this.contextWindow);
}

class GroqService {
  final String apiKey;
  final String baseUrl = 'https://api.groq.com/openai/v1';

  GroqService({required this.apiKey});

  /// Non-streaming generation (for synthesis tasks)
  Future<String> generateContent({
    required String prompt,
    String? systemPrompt,
    GroqModel model = GroqModel.llama33_70b,
    double temperature = 0.7,
    int? maxTokens,
    bool fallbackToMixtral = true,
  }) async {
    try {
      return await _generate(
        prompt: prompt,
        systemPrompt: systemPrompt,
        model: model,
        temperature: temperature,
        maxTokens: maxTokens,
      );
    } catch (e) {
      // Fallback to Mixtral if Llama fails
      if (fallbackToMixtral && model == GroqModel.llama33_70b) {
        print('Llama 3.3 70B failed, falling back to Mixtral: $e');
        return await _generate(
          prompt: prompt,
          systemPrompt: systemPrompt,
          model: GroqModel.mixtral_8x7b,
          temperature: temperature,
          maxTokens: maxTokens,
        );
      }
      rethrow;
    }
  }

  /// Streaming generation (for fast queries)
  Stream<String> generateContentStream({
    required String prompt,
    String? systemPrompt,
    GroqModel model = GroqModel.llama33_70b,
    double temperature = 0.7,
    int? maxTokens,
  }) async* {
    final messages = <Map<String, String>>[];

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    messages.add({'role': 'user', 'content': prompt});

    final request = http.Request(
      'POST',
      Uri.parse('$baseUrl/chat/completions'),
    );

    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    });

    request.body = jsonEncode({
      'model': model.id,
      'messages': messages,
      'temperature': temperature,
      if (maxTokens != null) 'max_tokens': maxTokens,
      'stream': true,
    });

    final client = http.Client();
    final response = await client.send(request);

    if (response.statusCode != 200) {
      final error = await response.stream.bytesToString();
      client.close();
      throw Exception('Groq API error: ${response.statusCode} - $error');
    }

    await for (final chunk in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      if (chunk.isEmpty || chunk == 'data: [DONE]') continue;

      if (chunk.startsWith('data: ')) {
        try {
          final data = jsonDecode(chunk.substring(6));
          final delta = data['choices']?[0]?['delta']?['content'];
          if (delta != null) {
            yield delta as String;
          }
        } catch (e) {
          // Skip malformed chunks
          continue;
        }
      }
    }
    client.close();
  }

  /// Internal generation method
  Future<String> _generate({
    required String prompt,
    String? systemPrompt,
    required GroqModel model,
    required double temperature,
    int? maxTokens,
  }) async {
    final messages = <Map<String, String>>[];

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    messages.add({'role': 'user', 'content': prompt});

    final response = await http.post(
      Uri.parse('$baseUrl/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model.id,
        'messages': messages,
        'temperature': temperature,
        if (maxTokens != null) 'max_tokens': maxTokens,
        'stream': false,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Groq API error: ${response.statusCode} - ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('Groq API returned no choices');
    }
    final message = choices[0]['message'] as Map<String, dynamic>?;
    final content = message?['content'] as String?;
    if (content == null) {
      throw Exception('Groq API returned empty content');
    }
    return content;
  }

  /// Get usage stats from last response (if needed)
  Map<String, int>? getUsageStats(Map<String, dynamic> response) {
    final usage = response['usage'];
    if (usage != null) {
      return {
        'prompt_tokens': usage['prompt_tokens'] as int,
        'completion_tokens': usage['completion_tokens'] as int,
        'total_tokens': usage['total_tokens'] as int,
      };
    }
    return null;
  }
}
