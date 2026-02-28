// lib/services/gemini_send.dart
// Minimal Gemini send() adapter for ArcLLM.
// PRISM scrubbing and correlation-resistant transformation enabled
// Now uses Firebase proxy to hide API key

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:my_app/services/llm_bridge_adapter.dart';
import 'package:my_app/services/groq_send.dart';
import 'package:my_app/arc/chat/config/api_config.dart';
import 'package:my_app/services/lumara/pii_scrub.dart';
import 'package:my_app/services/firebase_service.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:my_app/arc/internal/echo/prism_adapter.dart';
import 'package:my_app/arc/internal/echo/correlation_resistant_transformer.dart';

/// Extracts response text from proxy result (candidates or response string).
String? _extractTextFromProxyResult(Map<String, dynamic> data) {
  final candidates = data['candidates'] as List?;
  if (candidates != null && candidates.isNotEmpty) {
    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List? ?? const [];
    final buffer = StringBuffer();
    for (final p in parts) {
      final t = (p as Map)['text'];
      if (t is String) buffer.write(t);
    }
    return buffer.toString();
  }
  if (data['response'] is String) return data['response'] as String;
  return null;
}

/// Calls Gemini generateContent API directly (used when not signed in).
Future<String> _geminiDirectGenerateContent({
  required String apiKey,
  required String system,
  required String user,
  bool jsonExpected = false,
}) async {
  final uri = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent?key=$apiKey',
  );
  final body = <String, dynamic>{
    if (system.trim().isNotEmpty)
      'systemInstruction': {
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
    'generationConfig': {
      'temperature': 0.7,
      'maxOutputTokens': 8192,
      if (jsonExpected) 'responseMimeType': 'application/json',
    },
  };
  final client = HttpClient();
  try {
    final request = await client.postUrl(uri);
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
    request.write(jsonEncode(body));
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw HttpException('Cloud AI error: ${response.statusCode} - $responseBody');
    }
    final data = jsonDecode(responseBody) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;
    if (candidates != null && candidates.isNotEmpty) {
      final content = candidates.first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List? ?? const [];
      if (parts.isNotEmpty && parts.first['text'] is String) {
        return (parts.first['text'] as String).trim();
      }
    }
    throw HttpException('Cloud AI returned no text: $responseBody');
  } finally {
    client.close();
  }
}

/// Unified LUMARA send: PRISM scrub, optional transformation, proxyGroq, PII restore.
/// Use this for all chat/reflection flows that may contain user PII.
Future<String> lumaraSend({
  required String system,
  required String user,
  bool jsonExpected = false,
  String? entryId,
  String? chatId,
  String intent = 'chat',
  bool skipTransformation = false,
  double temperature = 0.7,
  int? maxTokens,
}) async {
  if (kDebugMode) print('LUMARA Send: PRISM scrub → groqSend → PII restore');

  // Bible questions: preserve names, skip transformation
  final isBibleQuestion = user.contains('[BIBLE_CONTEXT]') || user.contains('[BIBLE_VERSE_CONTEXT]');
  if (isBibleQuestion && !skipTransformation) {
    skipTransformation = true;
  }

  // Step 1: PRISM scrub
  final prismAdapter = PrismAdapter();
  final userPrismResult = prismAdapter.scrub(user);
  final systemPrismResult = system.trim().isNotEmpty
      ? prismAdapter.scrub(system)
      : PrismResult(scrubbedText: system, reversibleMap: {}, findings: []);

  final combinedReversibleMap = <String, String>{
    ...userPrismResult.reversibleMap,
    ...systemPrismResult.reversibleMap,
  };

  if (userPrismResult.hadPII || systemPrismResult.hadPII) {
    if (kDebugMode) print('PRISM: Scrubbed PII before send (user: ${userPrismResult.redactionCount}, system: ${systemPrismResult.redactionCount})');
  }

  if (!prismAdapter.isSafeToSend(userPrismResult.scrubbedText) ||
      (system.trim().isNotEmpty && !prismAdapter.isSafeToSend(systemPrismResult.scrubbedText))) {
    throw const SecurityException('SECURITY: PII still detected after PRISM scrubbing');
  }

  // Step 2: Optional correlation-resistant transformation
  String transformedUserText;
  String transformedSystem = systemPrismResult.scrubbedText;

  if (skipTransformation) {
    transformedUserText = userPrismResult.scrubbedText;
  } else {
    final userTransformation = await prismAdapter.transformToCorrelationResistant(
      prismScrubbedText: userPrismResult.scrubbedText,
      intent: intent,
      prismResult: userPrismResult,
      rotationWindow: RotationWindow.session,
    );
    transformedUserText = userTransformation.cloudPayloadBlock.toJsonString();

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

    if (transformedSystem == systemPrismResult.scrubbedText) {
      transformedSystem += '\n\n**IMPORTANT**: The user input you receive is a structured privacy-preserving payload (JSON format). '
          'The "semantic_summary" field contains an abstract description of the user\'s entry, NOT verbatim text. '
          'NEVER quote or repeat the semantic_summary verbatim. Use it to understand themes and meaning, '
          'then craft your response naturally without repeating the user\'s words.';
    }
  }

  // Step 3: Call proxyGroq
  final rawResponse = await groqSend(
    user: transformedUserText,
    system: transformedSystem.isNotEmpty ? transformedSystem : null,
    temperature: temperature,
    maxTokens: maxTokens,
    entryId: entryId,
    chatId: chatId,
  );

  // Step 4: Restore PII in response
  final restored = PiiScrubber.restore(rawResponse, combinedReversibleMap);
  if (restored != rawResponse && kDebugMode) {
    print('PRISM: Restored PII in response (${combinedReversibleMap.length} items)');
  }
  return restored;
}

/// DEPRECATED: No longer called from active code paths.
/// Use [lumaraSend] (PRISM + groqSend) or [groqSend] (raw) instead.
@Deprecated('Use lumaraSend() for PII protection, or groqSend() for raw.')
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
  if (kDebugMode) print('DEBUG GEMINI: Using Firebase proxy for API key');

  // Check if this is a Bible question - if so, we need to preserve Bible names and skip transformation
  final isBibleQuestion = user.contains('[BIBLE_CONTEXT]') || user.contains('[BIBLE_VERSE_CONTEXT]');
  
  // Auto-skip transformation for Bible questions to preserve context instructions
  if (isBibleQuestion && !skipTransformation) {
    if (kDebugMode) print('DEBUG GEMINI: ⚠️ Bible question detected - auto-enabling skipTransformation');
    skipTransformation = true;
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
    if (kDebugMode) print('PRISM: Scrubbed PII before cloud API call');
    if (userPrismResult.hadPII) {
      if (kDebugMode) print('PRISM: User text - Found ${userPrismResult.redactionCount} PII items');
      if (isBibleQuestion && kDebugMode) {
        print('PRISM: ⚠️ Bible question detected - checking if Bible names were scrubbed');
        final scrubbedText = userPrismResult.scrubbedText.toLowerCase();
        if (scrubbedText.contains('[name_') && (scrubbedText.contains('habakkuk') || scrubbedText.contains('prophet'))) {
          print('PRISM: ⚠️ WARNING: Bible name may have been scrubbed!');
        }
      }
    }
    if (systemPrismResult.hadPII && kDebugMode) print('PRISM: System prompt - Found ${systemPrismResult.redactionCount} PII items');
  }

  // SECURITY: Validate scrubbing passed
  if (!prismAdapter.isSafeToSend(userPrismResult.scrubbedText) ||
      (system.trim().isNotEmpty && !prismAdapter.isSafeToSend(systemPrismResult.scrubbedText))) {
    throw const SecurityException('SECURITY: PII still detected after PRISM scrubbing');
  }

  // Step 2: Correlation-Resistant Transformation
  // Skip transformation if entry text already abstracted (e.g., journal entries)
  String transformedUserText;
  if (kDebugMode) print('DEBUG GEMINI: skipTransformation flag: $skipTransformation');
  if (skipTransformation) {
    // Entry text already abstracted, use scrubbed version directly
    transformedUserText = userPrismResult.scrubbedText;
    if (kDebugMode) print('DEBUG GEMINI: ✅ Skipping transformation - using scrubbed text directly (length: ${transformedUserText.length})');
  } else {
    // Transform user text to structured payload
    final userTransformation = await prismAdapter.transformToCorrelationResistant(
      prismScrubbedText: userPrismResult.scrubbedText,
      intent: intent,
      prismResult: userPrismResult,
      rotationWindow: RotationWindow.session,
    );
    transformedUserText = userTransformation.cloudPayloadBlock.toJsonString();
    
    // Log local audit blocks (NEVER SEND TO SERVER) — debug only
    if (kDebugMode) {
      print('LOCAL AUDIT: User - Window ID: ${userTransformation.localAuditBlock.windowId}');
      print('LOCAL AUDIT: User - Token classes: ${userTransformation.localAuditBlock.tokenClassCounts}');
    }
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

  if (kDebugMode) {
    print('DEBUG GEMINI: Using Firebase proxy with ${skipTransformation ? 'abstracted (NO TRANSFORMATION)' : 'correlation-resistant'} payload');
    if (skipTransformation) print('DEBUG GEMINI: ✅ Transformation skipped - user text preserved as-is');
  }

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
    final firebaseReady = await FirebaseService.instance.ensureReady();
    final signedIn = FirebaseAuthService.instance.isSignedIn;

    // Use Firebase proxy when signed in; otherwise use direct Gemini API if key is set
    if (firebaseReady && signedIn) {
      if (kDebugMode) print('DEBUG GEMINI: Calling Firebase proxyGemini function...');
      final functions = FirebaseService.instance.getFunctions();
      final callable = functions.httpsCallable('proxyGemini');
      final result = await callable.call(requestData);
      if (kDebugMode) print('DEBUG GEMINI: Got response from Firebase proxy');
      final data = (result.data as Map<Object?, Object?>).cast<String, dynamic>();
      final rawResult = _extractTextFromProxyResult(data);
      if (rawResult == null) return '';
      final restoredResult = PiiScrubber.restore(rawResult, combinedReversibleMap);
      if (restoredResult != rawResult && kDebugMode) print('PRISM: Restored PII in response (restored ${combinedReversibleMap.length} items)');
      if (kDebugMode) print('DEBUG GEMINI: Successfully parsed response, result length: ${restoredResult.length}');
      return restoredResult;
    }

    // Not signed in (or Firebase not ready): use direct Gemini API if key available
    await LumaraAPIConfig.instance.initialize();
    final geminiKey = LumaraAPIConfig.instance.getApiKey(LLMProvider.gemini);
    if (geminiKey != null && geminiKey.trim().isNotEmpty) {
      if (kDebugMode) print('DEBUG GEMINI: Using direct Gemini API (not signed in or proxy unavailable)');
      final rawResult = await _geminiDirectGenerateContent(
        apiKey: geminiKey,
        system: transformedSystem,
        user: transformedUserText,
        jsonExpected: jsonExpected,
      );
      final restoredResult = PiiScrubber.restore(rawResult, combinedReversibleMap);
      if (kDebugMode) print('DEBUG GEMINI: Direct Gemini response length: ${restoredResult.length}');
      return restoredResult;
    }

    throw Exception(
      'Connection to AI failed. Sign in for cloud AI, or add a Groq or Gemini API key in Settings → LUMARA.',
    );
  } on FirebaseFunctionsException catch (e) {
    if (kDebugMode) print('DEBUG GEMINI: Firebase Functions error: ${e.code} - ${e.message}');
    
    // Re-throw usage limit errors with clean message (no [firebase_functions/...] prefix)
    if (e.code == 'resource-exhausted' || e.code == 'permission-denied' || e.code == 'unauthenticated') {
      // Pass the clean message directly - the backend already provides user-friendly messages
      throw Exception(e.message ?? 'Request limit reached');
    }
    
    throw Exception('Connection to AI failed: ${e.message}');
  } catch (e) {
    if (kDebugMode) print('DEBUG GEMINI: Error in geminiSend: $e');
    throw Exception('Connection to AI failed: $e');
  }
}

/// DEPRECATED: No longer called from active code paths.
/// All inference is now routed through [groqSend] (proxyGroq / GPT-OSS 120B).
@Deprecated('Use groqSend() instead. proxyGroq (GPT-OSS 120B) is the primary engine.')
Stream<String> geminiSendStream({
  required String system,
  required String user,
  bool jsonExpected = false,
}) async* {
  // Get API key from LumaraAPIConfig (client-side; see doc above)
  final apiConfig = LumaraAPIConfig.instance;
  await apiConfig.initialize();
  final geminiConfig = apiConfig.getConfig(LLMProvider.gemini);
  final apiKey = geminiConfig?.apiKey ?? '';
  
  if (kDebugMode) {
    print('DEBUG GEMINI STREAM: API Key available: ${apiKey.isNotEmpty}');
    print('DEBUG GEMINI STREAM: Gemini config available: ${geminiConfig?.isAvailable}');
  }

  if (apiKey.isEmpty) {
    if (kDebugMode) print('DEBUG GEMINI STREAM: No API key found, throwing StateError');
    throw StateError('No cloud AI API key configured. Add a Groq or Gemini API key in Settings → LUMARA Settings.');
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
  
  if ((userPrismResult.hadPII || systemPrismResult.hadPII) && kDebugMode) {
    print('PRISM: Scrubbed PII before cloud API stream call');
    if (userPrismResult.hadPII) print('PRISM: User text - Found ${userPrismResult.redactionCount} PII items');
    if (systemPrismResult.hadPII) print('PRISM: System prompt - Found ${systemPrismResult.redactionCount} PII items');
  }

  // SECURITY: Validate scrubbing passed
  if (!prismAdapter.isSafeToSend(userPrismResult.scrubbedText) ||
      (system.trim().isNotEmpty && !prismAdapter.isSafeToSend(systemPrismResult.scrubbedText))) {
    throw const SecurityException('SECURITY: PII still detected after PRISM scrubbing');
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
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:streamGenerateContent?key=$apiKey&alt=sse',
  );

  if (kDebugMode) print('DEBUG GEMINI STREAM: Using streaming endpoint');

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
    if (kDebugMode) print('DEBUG GEMINI STREAM: Opening streaming request...');
    final request = await client.postUrl(uri);
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
    request.write(jsonEncode(body));

    final response = await request.close();
    if (kDebugMode) print('DEBUG GEMINI STREAM: Got response, status code: ${response.statusCode}');

    if (response.statusCode != 200) {
      final errorBody = await response.transform(utf8.decoder).join();
      if (kDebugMode) print('DEBUG GEMINI STREAM: Error response: $errorBody');
      throw HttpException('Cloud AI error: ${response.statusCode}\n$errorBody');
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
            if (kDebugMode) print('DEBUG GEMINI STREAM: Error parsing chunk: $e');
            // Continue processing other chunks
          }
        }
      }
    }

    if (kDebugMode) print('DEBUG GEMINI STREAM: Stream completed');
  } finally {
    client.close(force: true);
  }
}

/// Convenience factory to obtain an ArcLLM instance backed by lumaraSend (PRISM + proxyGroq).
ArcLLM provideArcLLM() {
  if (kDebugMode) print('ArcLLM Provider: Using lumaraSend (PRISM + proxyGroq)');
  
  return ArcLLM(
    send: ({
      required String system,
      required String user,
      List<String>? history,
      bool jsonExpected = false,
    }) async {
      return await lumaraSend(
        system: system,
        user: user,
        jsonExpected: jsonExpected,
        skipTransformation: false, // Full PRISM + transformation for chat
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


