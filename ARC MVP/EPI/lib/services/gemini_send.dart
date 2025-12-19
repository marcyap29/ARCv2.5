// lib/services/gemini_send.dart
// Minimal Gemini send() adapter for ArcLLM.
// PRISM scrubbing and correlation-resistant transformation enabled
// Now uses Firebase proxy to hide API key

import 'dart:convert';
import 'dart:io';

import 'package:my_app/services/llm_bridge_adapter.dart';
import 'package:my_app/arc/chat/config/api_config.dart';
import 'package:my_app/services/lumara/pii_scrub.dart';
import 'package:my_app/services/firebase_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:my_app/arc/chat/voice/voice_journal/prism_adapter.dart';
import 'package:my_app/arc/chat/voice/voice_journal/correlation_resistant_transformer.dart';

/// Sends a single-turn request to Gemini with an optional system instruction.
/// Returns the concatenated text from candidates[0].content.parts[].text.
/// PRISM scrubbing and correlation-resistant transformation applied before sending.
/// Responses are restored with original PII for local display.
/// 
/// For in-journal LUMARA, pass [entryId] to enforce per-entry usage limits.
/// For in-chat LUMARA, pass [chatId] to enforce per-chat usage limits.
/// 
/// [skipTransformation]: If true, skips correlation-resistant transformation.
/// Use this when the entry text has already been abstracted (e.g., journal entries).
Future<String> geminiSend({
  required String system,
  required String user,
  bool jsonExpected = false,
  String? entryId, // Optional: for per-entry limit tracking (journal)
  String? chatId, // Optional: for per-chat limit tracking (chat)
  String intent = 'chat', // Optional: intent for correlation-resistant transformation
  bool skipTransformation = false, // Skip transformation if entry already abstracted
}) async {
  // No longer need local API key - using Firebase proxy
  print('DEBUG GEMINI: Using Firebase proxy for API key');

  // Step 1: PRISM - Scrub PII from user input and system prompt
  final prismAdapter = PrismAdapter();
  final userPrismResult = prismAdapter.scrub(user);
  final systemPrismResult = system.trim().isNotEmpty 
      ? prismAdapter.scrub(system) 
      : PrismResult(scrubbedText: system, reversibleMap: {}, findings: []);
  
  // Combine reversible maps (user + system) for restoration
  final combinedReversibleMap = <String, String>{
    ...userPrismResult.reversibleMap,
    ...systemPrismResult.reversibleMap,
  };
  
  if (userPrismResult.hadPII || systemPrismResult.hadPII) {
    print('PRISM: Scrubbed PII before cloud API call');
    if (userPrismResult.hadPII) {
      print('PRISM: User text - Found ${userPrismResult.redactionCount} PII items');
    }
    if (systemPrismResult.hadPII) {
      print('PRISM: System prompt - Found ${systemPrismResult.redactionCount} PII items');
    }
  }

  // SECURITY: Validate scrubbing passed
  if (!prismAdapter.isSafeToSend(userPrismResult.scrubbedText) ||
      (system.trim().isNotEmpty && !prismAdapter.isSafeToSend(systemPrismResult.scrubbedText))) {
    throw SecurityException('SECURITY: PII still detected after PRISM scrubbing');
  }

  // Step 2: Correlation-Resistant Transformation
  // Skip transformation if entry text already abstracted (e.g., journal entries)
  String transformedUserText;
  if (skipTransformation) {
    // Entry text already abstracted, use scrubbed version directly
    transformedUserText = userPrismResult.scrubbedText;
    print('DEBUG GEMINI: Skipping transformation - entry already abstracted');
  } else {
    // Transform user text to structured payload
    final userTransformation = await prismAdapter.transformToCorrelationResistant(
      prismScrubbedText: userPrismResult.scrubbedText,
      intent: intent,
      prismResult: userPrismResult,
      rotationWindow: RotationWindow.session,
    );
    transformedUserText = userTransformation.cloudPayloadBlock.toJsonString();
    
    // Log local audit blocks (NEVER SEND TO SERVER)
    print('LOCAL AUDIT: User - Window ID: ${userTransformation.localAuditBlock.windowId}');
    print('LOCAL AUDIT: User - Token classes: ${userTransformation.localAuditBlock.tokenClassCounts}');
  }

  // Transform system prompt if it had PII, otherwise use as-is
  // System prompts typically don't contain user PII, so we can use the scrubbed version directly
  // Only transform if it actually contains PRISM tokens
  String transformedSystem = systemPrismResult.scrubbedText;
  final hasSystemPrismTokens = RegExp(r'\[(EMAIL|PHONE|NAME|ADDRESS|SSN|CARD|ORG|HANDLE|DATE|COORD|ID|API_KEY)_\d+\]')
      .hasMatch(systemPrismResult.scrubbedText);
  
  if (hasSystemPrismTokens && systemPrismResult.hadPII && system.trim().isNotEmpty) {
    final systemTransformation = await prismAdapter.transformToCorrelationResistant(
      prismScrubbedText: systemPrismResult.scrubbedText,
      intent: 'system_prompt',
      prismResult: systemPrismResult,
      rotationWindow: RotationWindow.session,
    );
    transformedSystem = systemTransformation.cloudPayloadBlock.toJsonString();
  }
  
  // Add instruction to system prompt about handling structured payloads
  // This prevents LUMARA from re-quoting the entry text
  // Only add this when we're actually sending structured JSON (not when skipping transformation)
  if (!skipTransformation && transformedSystem == systemPrismResult.scrubbedText) {
    // Only add if system prompt wasn't transformed (to avoid double instructions)
    transformedSystem += '\n\n**IMPORTANT**: The user input you receive is a structured privacy-preserving payload (JSON format). '
        'The "semantic_summary" field contains an abstract description of the user\'s entry, NOT verbatim text. '
        'NEVER quote or repeat the semantic_summary verbatim. Instead, use it to understand the themes and meaning, '
        'then craft your response naturally without repeating the user\'s words. Focus on reflection, insight, and questions, '
        'not on restating what the user wrote.';
  }

  print('DEBUG GEMINI: Using Firebase proxy with ${skipTransformation ? 'abstracted' : 'correlation-resistant'} payload');

  // Build request body for Firebase proxy
  // Send structured JSON payload (if transformed) or abstracted text (if skipped)
  final requestData = {
    'system': transformedSystem,
    'user': transformedUserText, // Either structured JSON or abstracted text
    if (jsonExpected) 'jsonExpected': true,
    if (entryId != null) 'entryId': entryId,
    if (chatId != null) 'chatId': chatId,
  };

  try {
    print('DEBUG GEMINI: Calling Firebase proxyGemini function...');
    
    // Call Firebase proxy function
    final functions = FirebaseService.instance.getFunctions();
    final callable = functions.httpsCallable('proxyGemini');
    final result = await callable.call(requestData);
    
    print('DEBUG GEMINI: Got response from Firebase proxy');
    
    final data = (result.data as Map<Object?, Object?>).cast<String, dynamic>();

    // Prefer the structured candidates response; fall back to a plain `response` string
    String rawResult = '';
    final candidates = data['candidates'] as List?;
    if (candidates != null && candidates.isNotEmpty) {
      final content = candidates.first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List? ?? const [];
      final buffer = StringBuffer();
      for (final p in parts) {
        final t = (p as Map)['text'];
        if (t is String) buffer.write(t);
      }
      rawResult = buffer.toString();
    } else if (data['response'] is String) {
      rawResult = data['response'] as String;
    } else {
      print('DEBUG GEMINI: No candidates or response string in proxy result');
      return '';
    }
    
    // PRISM: Restore original PII in the response
    final restoredResult = PiiScrubber.restore(rawResult, combinedReversibleMap);
    
    if (restoredResult != rawResult) {
      print('PRISM: Restored PII in response (restored ${combinedReversibleMap.length} items)');
    }
    
    print('DEBUG GEMINI: Successfully parsed response, result length: ${restoredResult.length}');
    return restoredResult;
  } on FirebaseFunctionsException catch (e) {
    print('DEBUG GEMINI: Firebase Functions error: ${e.code} - ${e.message}');
    
    // Re-throw usage limit errors with clean message (no [firebase_functions/...] prefix)
    if (e.code == 'resource-exhausted' || e.code == 'permission-denied' || e.code == 'unauthenticated') {
      // Pass the clean message directly - the backend already provides user-friendly messages
      throw Exception(e.message ?? 'Request limit reached');
    }
    
    throw Exception('Gemini API request failed: ${e.message}');
  } catch (e) {
    print('DEBUG GEMINI: Error in geminiSend: $e');
    throw Exception('Gemini API request failed: $e');
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

  // Step 1: PRISM - Scrub PII from user input and system prompt
  final prismAdapter = PrismAdapter();
  final userPrismResult = prismAdapter.scrub(user);
  final systemPrismResult = system.trim().isNotEmpty 
      ? prismAdapter.scrub(system) 
      : PrismResult(scrubbedText: system, reversibleMap: {}, findings: []);
  
  // Combine reversible maps (user + system) for restoration
  final combinedReversibleMap = <String, String>{
    ...userPrismResult.reversibleMap,
    ...systemPrismResult.reversibleMap,
  };
  
  if (userPrismResult.hadPII || systemPrismResult.hadPII) {
    print('PRISM: Scrubbed PII before cloud API stream call');
    if (userPrismResult.hadPII) {
      print('PRISM: User text - Found ${userPrismResult.redactionCount} PII items');
    }
    if (systemPrismResult.hadPII) {
      print('PRISM: System prompt - Found ${systemPrismResult.redactionCount} PII items');
    }
  }

  // SECURITY: Validate scrubbing passed
  if (!prismAdapter.isSafeToSend(userPrismResult.scrubbedText) ||
      (system.trim().isNotEmpty && !prismAdapter.isSafeToSend(systemPrismResult.scrubbedText))) {
    throw SecurityException('SECURITY: PII still detected after PRISM scrubbing');
  }

  // Step 2: Correlation-Resistant Transformation
  // Transform user text to structured payload
  final userTransformation = await prismAdapter.transformToCorrelationResistant(
    prismScrubbedText: userPrismResult.scrubbedText,
    intent: 'chat_stream',
    prismResult: userPrismResult,
    rotationWindow: RotationWindow.session,
  );

  // Transform system prompt if it had PII, otherwise use as-is
  String transformedSystem = systemPrismResult.scrubbedText;
  if (systemPrismResult.hadPII && system.trim().isNotEmpty) {
    final systemTransformation = await prismAdapter.transformToCorrelationResistant(
      prismScrubbedText: systemPrismResult.scrubbedText,
      intent: 'system_prompt',
      prismResult: systemPrismResult,
      rotationWindow: RotationWindow.session,
    );
    transformedSystem = systemTransformation.cloudPayloadBlock.toJsonString();
  }

  final uri = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent?key=$apiKey&alt=sse',
  );

  print('DEBUG GEMINI STREAM: Using streaming endpoint');

  final body = {
    if (transformedSystem.trim().isNotEmpty)
      'systemInstruction': {
        'role': 'system',
        'parts': [
          {'text': transformedSystem}
        ]
      },
    'contents': [
      {
        'role': 'user',
        'parts': [
          {'text': userTransformation.cloudPayloadBlock.toJsonString()} // Structured payload
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
/// PRIORITY 2: Using Firebase proxy for API key management
ArcLLM provideArcLLM() {
  print('ArcLLM Provider: Using Firebase proxy for Gemini API');
  
  return ArcLLM(
    send: ({
      required String system,
      required String user,
      List<String>? history,
      bool jsonExpected = false,
    }) async {
      return await geminiSend(
        system: system,
        user: user,
        jsonExpected: jsonExpected,
      );
    },
  );
}


/// DEPRECATED: Local Gemini API calls
/// This function is kept for reference but should NOT be called in production
/// All API calls should go through Firebase Functions for:
/// - Centralized rate limiting
/// - Backend-enforced subscription checking  
/// - Secure API key management
/// - Better error handling
@Deprecated('Use Firebase Functions instead: sendChatMessage, generateJournalReflection')
Future<String> geminiSendDEPRECATED({
  required String system,
  required String user,
  bool jsonExpected = false,
}) async {
  return geminiSend(system: system, user: user, jsonExpected: jsonExpected);
}


