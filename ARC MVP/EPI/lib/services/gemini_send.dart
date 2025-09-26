// lib/services/gemini_send.dart
// Minimal Gemini send() adapter for ArcLLM.

import 'dart:convert';
import 'dart:io';

import 'package:my_app/services/llm_bridge_adapter.dart';

/// Sends a single-turn request to Gemini with an optional system instruction.
/// Returns the concatenated text from candidates[0].content.parts[].text.
Future<String> geminiSend({
  required String system,
  required String user,
  bool jsonExpected = false,
}) async {
  const apiKey = String.fromEnvironment('GEMINI_API_KEY');
  print('DEBUG GEMINI: API Key available: ${apiKey.isNotEmpty}');
  print('DEBUG GEMINI: API Key length: ${apiKey.length}');
  print('DEBUG GEMINI: API Key prefix: ${apiKey.isNotEmpty ? apiKey.substring(0, apiKey.length > 10 ? 10 : apiKey.length) : 'none'}');

  if (apiKey.isEmpty) {
    print('DEBUG GEMINI: No API key found, throwing StateError');
    throw StateError('GEMINI_API_KEY not provided');
  }

  final uri = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
  );

  print('DEBUG GEMINI: Using endpoint: ${uri.toString().replaceAll(apiKey, '[API_KEY]')}');

  final body = {
    if (system.trim().isNotEmpty)
      'systemInstruction': {
        'role': 'system',
        'parts': [
          {'text': system}
        ]
      },
    'contents': [
      {
        'role': 'user',
        'parts': [
          {'text': user}
        ]
      }
    ],
    if (jsonExpected) 'generationConfig': {'responseMimeType': 'application/json'},
  };

  final client = HttpClient();
  try {
    print('DEBUG GEMINI: Making POST request to: ${uri.host}${uri.path}');
    final req = await client.postUrl(uri);
    req.headers.contentType = ContentType('application', 'json', charset: 'utf-8');

    final bodyJson = jsonEncode(body);
    print('DEBUG GEMINI: Request body length: ${bodyJson.length}');
    req.write(bodyJson);

    print('DEBUG GEMINI: Sending request...');
    final res = await req.close();
    print('DEBUG GEMINI: Response status: ${res.statusCode}');
    print('DEBUG GEMINI: Response headers: ${res.headers}');

    final text = await res.transform(utf8.decoder).join();
    print('DEBUG GEMINI: Response body length: ${text.length}');
    print('DEBUG GEMINI: Response preview: ${text.substring(0, text.length > 200 ? 200 : text.length)}...');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      print('DEBUG GEMINI: HTTP Error - Status: ${res.statusCode}, Body: $text');
      throw HttpException('Gemini error ${res.statusCode}: $text');
    }
    final json = jsonDecode(text) as Map<String, dynamic>;
    final candidates = json['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      print('DEBUG GEMINI: No candidates in response');
      return '';
    }

    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List? ?? const [];
    final buffer = StringBuffer();
    for (final p in parts) {
      final t = (p as Map)['text'];
      if (t is String) buffer.write(t);
    }

    final result = buffer.toString();
    print('DEBUG GEMINI: Successfully parsed response, result length: ${result.length}');
    return result;
  } finally {
    client.close(force: true);
  }
}

/// Convenience factory to obtain an ArcLLM instance backed by Gemini.
ArcLLM provideArcLLM() => ArcLLM(send: ({required system, required user, bool jsonExpected = false}) async {
      return geminiSend(system: system, user: user, jsonExpected: jsonExpected);
    });


