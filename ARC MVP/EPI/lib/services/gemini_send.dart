// lib/services/gemini_send.dart
// Minimal Gemini send() adapter for ArcLLM.
// PRISM scrubbing and restoration enabled

import 'dart:convert';
import 'dart:io';

import 'package:my_app/services/llm_bridge_adapter.dart';
import 'package:my_app/arc/chat/config/api_config.dart';
import 'package:my_app/services/lumara/pii_scrub.dart';

/// Sends a single-turn request to Gemini with an optional system instruction.
/// Returns the concatenated text from candidates[0].content.parts[].text.
/// PRISM scrubbing is applied before sending, and responses are restored.
Future<String> geminiSend({
  required String system,
  required String user,
  bool jsonExpected = false,
}) async {
  // Get API key from LumaraAPIConfig instead of environment variable
  final apiConfig = LumaraAPIConfig.instance;
  
  // Ensure API config is initialized
  await apiConfig.initialize();
  
  final geminiConfig = apiConfig.getConfig(LLMProvider.gemini);
  final apiKey = geminiConfig?.apiKey ?? '';
  
  print('DEBUG GEMINI: API Key available: ${apiKey.isNotEmpty}');
  print('DEBUG GEMINI: API Key length: ${apiKey.length}');
  print('DEBUG GEMINI: API Key prefix: ${apiKey.isNotEmpty ? apiKey.substring(0, apiKey.length > 10 ? 10 : apiKey.length) : 'none'}');
  print('DEBUG GEMINI: Gemini config available: ${geminiConfig?.isAvailable}');

  if (apiKey.isEmpty) {
    print('DEBUG GEMINI: No local API key found');
    throw StateError('No Gemini API key configured. Please add your API key in Settings → LUMARA Settings.');
  }

  // PRISM: Scrub PII from user input and system prompt before sending to cloud API
  final userScrubResult = PiiScrubber.rivetScrubWithMapping(user);
  final systemScrubResult = system.trim().isNotEmpty 
      ? PiiScrubber.rivetScrubWithMapping(system) 
      : ScrubbingResult(scrubbedText: system, reversibleMap: {}, findings: []);
  
  // Combine reversible maps (user + system)
  final combinedReversibleMap = <String, String>{
    ...userScrubResult.reversibleMap,
    ...systemScrubResult.reversibleMap,
  };
  
  if (userScrubResult.findings.isNotEmpty || systemScrubResult.findings.isNotEmpty) {
    print('PRISM: Scrubbed PII before cloud API call');
    if (userScrubResult.findings.isNotEmpty) {
      print('PRISM: User text - Found ${userScrubResult.findings.length} PII items: ${userScrubResult.findings.join(", ")}');
    }
    if (systemScrubResult.findings.isNotEmpty) {
      print('PRISM: System prompt - Found ${systemScrubResult.findings.length} PII items: ${systemScrubResult.findings.join(", ")}');
    }
  }

  final uri = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
  );

  print('DEBUG GEMINI: Using endpoint: ${uri.toString().replaceAll(apiKey, '[API_KEY]')}');

  final body = {
    if (systemScrubResult.scrubbedText.trim().isNotEmpty)
      'systemInstruction': {
        'role': 'system',
        'parts': [
          {'text': systemScrubResult.scrubbedText}
        ]
      },
    'contents': [
      {
        'role': 'user',
        'parts': [
          {'text': userScrubResult.scrubbedText}
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

    final rawResult = buffer.toString();
    
    // PRISM: Restore original PII in the response
    final restoredResult = PiiScrubber.restore(rawResult, combinedReversibleMap);
    
    if (restoredResult != rawResult) {
      print('PRISM: Restored PII in response (restored ${combinedReversibleMap.length} items)');
    }
    
    print('DEBUG GEMINI: Successfully parsed response, result length: ${restoredResult.length}');
    return restoredResult;
  } catch (e) {
    print('DEBUG GEMINI: Error in geminiSend: $e');
    if (e is StateError) {
      rethrow; // Re-throw StateError as-is (API key issues)
    } else if (e is HttpException) {
      rethrow; // Re-throw HttpException as-is (API errors)
    } else {
      throw Exception('Gemini API request failed: $e');
    }
  } finally {
    client.close(force: true);
  }
}

/// Streams a single-turn request to Gemini with an optional system instruction.
/// Yields text chunks as they arrive from the API.
/// PRISM scrubbing is applied before sending, and each chunk is restored.
Stream<String> geminiSendStream({
  required String system,
  required String user,
  bool jsonExpected = false,
}) async* {
  // Get API key from LumaraAPIConfig instead of environment variable
  final apiConfig = LumaraAPIConfig.instance;
  await apiConfig.initialize();
  final geminiConfig = apiConfig.getConfig(LLMProvider.gemini);
  final apiKey = geminiConfig?.apiKey ?? '';
  
  print('DEBUG GEMINI STREAM: API Key available: ${apiKey.isNotEmpty}');
  print('DEBUG GEMINI STREAM: Gemini config available: ${geminiConfig?.isAvailable}');

  if (apiKey.isEmpty) {
    print('DEBUG GEMINI STREAM: No API key found, throwing StateError');
    throw StateError('No Gemini API key configured. Please add your API key in Settings → LUMARA Settings.');
  }

  // PRISM: Scrub PII from user input and system prompt before sending to cloud API
  final userScrubResult = PiiScrubber.rivetScrubWithMapping(user);
  final systemScrubResult = system.trim().isNotEmpty 
      ? PiiScrubber.rivetScrubWithMapping(system) 
      : ScrubbingResult(scrubbedText: system, reversibleMap: {}, findings: []);
  
  // Combine reversible maps (user + system)
  final combinedReversibleMap = <String, String>{
    ...userScrubResult.reversibleMap,
    ...systemScrubResult.reversibleMap,
  };
  
  if (userScrubResult.findings.isNotEmpty || systemScrubResult.findings.isNotEmpty) {
    print('PRISM: Scrubbed PII before cloud API stream call');
    if (userScrubResult.findings.isNotEmpty) {
      print('PRISM: User text - Found ${userScrubResult.findings.length} PII items: ${userScrubResult.findings.join(", ")}');
    }
    if (systemScrubResult.findings.isNotEmpty) {
      print('PRISM: System prompt - Found ${systemScrubResult.findings.length} PII items: ${systemScrubResult.findings.join(", ")}');
    }
  }

  final uri = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent?key=$apiKey&alt=sse',
  );

  print('DEBUG GEMINI STREAM: Using streaming endpoint');

  final body = {
    if (systemScrubResult.scrubbedText.trim().isNotEmpty)
      'systemInstruction': {
        'role': 'system',
        'parts': [
          {'text': systemScrubResult.scrubbedText}
        ]
      },
    'contents': [
      {
        'role': 'user',
        'parts': [
          {'text': userScrubResult.scrubbedText}
        ]
      }
    ],
    if (jsonExpected) 'generationConfig': {'responseMimeType': 'application/json'},
  };

  final client = HttpClient();
  try {
    print('DEBUG GEMINI STREAM: Opening streaming request...');
    final request = await client.postUrl(uri);
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
    request.write(jsonEncode(body));

    final response = await request.close();
    print('DEBUG GEMINI STREAM: Got response, status code: ${response.statusCode}');

    if (response.statusCode != 200) {
      final errorBody = await response.transform(utf8.decoder).join();
      print('DEBUG GEMINI STREAM: Error response: $errorBody');
      throw HttpException('Gemini API error: ${response.statusCode}\n$errorBody');
    }

    // Process Server-Sent Events stream
    await for (final chunk in response.transform(utf8.decoder)) {
      // Split by lines and process each SSE event
      final lines = chunk.split('\n');
      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final jsonStr = line.substring(6); // Remove "data: " prefix
          if (jsonStr.trim().isEmpty || jsonStr.trim() == '[DONE]') continue;

          try {
            final data = jsonDecode(jsonStr) as Map<String, dynamic>;
            final candidates = data['candidates'] as List<dynamic>?;
            if (candidates == null || candidates.isEmpty) continue;

            final content = candidates[0]['content'] as Map<String, dynamic>?;
            if (content == null) continue;

            final parts = content['parts'] as List<dynamic>?;
            if (parts == null || parts.isEmpty) continue;

            for (final part in parts) {
              final text = part['text'] as String?;
              if (text != null && text.isNotEmpty) {
                // PRISM: Restore original PII in each chunk
                final restoredText = PiiScrubber.restore(text, combinedReversibleMap);
                yield restoredText;
              }
            }
          } catch (e) {
            print('DEBUG GEMINI STREAM: Error parsing chunk: $e');
            // Continue processing other chunks
          }
        }
      }
    }

    print('DEBUG GEMINI STREAM: Stream completed');
  } finally {
    client.close(force: true);
  }
}

/// Convenience factory to obtain an ArcLLM instance backed by Gemini.
ArcLLM provideArcLLM() => ArcLLM(send: ({required system, required user, bool jsonExpected = false}) async {
      return geminiSend(system: system, user: user, jsonExpected: jsonExpected);
    });


