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
  final apiKey = const String.fromEnvironment('GEMINI_API_KEY');
  if (apiKey.isEmpty) {
    throw StateError('GEMINI_API_KEY not provided');
  }

  final uri = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey',
  );

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
    final req = await client.postUrl(uri);
    req.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
    req.write(jsonEncode(body));
    final res = await req.close();

    final text = await res.transform(utf8.decoder).join();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException('Gemini error ${res.statusCode}: $text');
    }
    final json = jsonDecode(text) as Map<String, dynamic>;
    final candidates = json['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return '';
    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List? ?? const [];
    final buffer = StringBuffer();
    for (final p in parts) {
      final t = (p as Map)['text'];
      if (t is String) buffer.write(t);
    }
    return buffer.toString();
  } finally {
    client.close(force: true);
  }
}

/// Convenience factory to obtain an ArcLLM instance backed by Gemini.
ArcLLM provideArcLLM() => ArcLLM(send: ({required system, required user, bool jsonExpected = false}) async {
      return geminiSend(system: system, user: user, jsonExpected: jsonExpected);
    });
