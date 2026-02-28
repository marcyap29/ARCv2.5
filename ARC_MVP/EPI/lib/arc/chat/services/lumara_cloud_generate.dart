// lib/arc/chat/services/lumara_cloud_generate.dart
// Single entry point for agent (and other) cloud inference using the same API as LUMARA chat:
// SwarmSpace gemini-flash when available (Writing/Research agents), else proxyGroq or Groq API key.
// SECURITY: All paths scrub PII before send (lumaraSend or PrismAdapter + GroqService).

import 'package:flutter/foundation.dart';
import 'package:my_app/arc/chat/config/api_config.dart';
import 'package:my_app/arc/chat/services/groq_service.dart';
import 'package:my_app/arc/internal/echo/prism_adapter.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/services/firebase_service.dart';
import 'package:my_app/services/gemini_send.dart';
import 'package:my_app/services/lumara/pii_scrub.dart';
import 'package:my_app/services/swarmspace/swarmspace_client.dart';

/// Tries SwarmSpace gemini-flash first (for Writing/Research agents), then falls back to Groq.
/// Use this for agent synthesis so users can leverage Gemini via SwarmSpace when available.
Future<String> generateForAgents({
  required String systemPrompt,
  required String userPrompt,
  int maxTokens = 1024,
}) async {
  // 1. Try SwarmSpace gemini-flash when signed in
  final firebaseReady = await FirebaseService.instance.ensureReady();
  final signedIn = FirebaseAuthService.instance.isSignedIn;
  if (firebaseReady && signedIn) {
    try {
      final result = await generateWithSwarmSpaceGemini(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        maxTokens: maxTokens,
      );
      if (result != null && result.isNotEmpty) return result;
    } catch (e) {
      if (kDebugMode) print('SwarmSpace gemini-flash failed, falling back to Groq: $e');
    }
  }

  // 2. Fall back to Groq (proxy or direct key)
  return generateWithLumaraCloud(
    systemPrompt: systemPrompt,
    userPrompt: userPrompt,
    maxTokens: maxTokens,
  );
}

/// Invokes SwarmSpace gemini-flash plugin for LLM synthesis.
/// Returns null on failure so caller can fall back to Groq.
Future<String?> generateWithSwarmSpaceGemini({
  required String systemPrompt,
  required String userPrompt,
  int maxTokens = 1024,
}) async {
  final client = SwarmSpaceClient.instance;
  final available = await client.isPluginAvailable('gemini-flash');
  if (!available) return null;

  final result = await client.invoke('gemini-flash', {
    'system': systemPrompt,
    'user': userPrompt,
    'max_tokens': maxTokens,
    'temperature': 0.7,
  });

  if (!result.success || result.data == null) return null;

  // Extract text from common response formats
  final data = result.data!;
  final text = data['text'] as String?;
  if (text != null && text.isNotEmpty) return text.trim();

  final content = data['content'] as String?;
  if (content != null && content.isNotEmpty) return content.trim();

  // Gemini API format: candidates[0].content.parts[0].text
  final candidates = data['candidates'] as List?;
  if (candidates != null && candidates.isNotEmpty) {
    final first = candidates.first as Map<String, dynamic>?;
    final contentObj = first?['content'] as Map<String, dynamic>?;
    final parts = contentObj?['parts'] as List?;
    if (parts != null && parts.isNotEmpty) {
      final part = parts.first as Map<String, dynamic>?;
      final partText = part?['text'] as String?;
      if (partText != null && partText.isNotEmpty) return partText.trim();
    }
  }

  return null;
}

/// Uses the same cloud API as LUMARA: proxyGroq when signed in, else Groq API key.
/// Call this from Writing Agent, Research Agent, and any UI that needs to run inference
/// without requiring the user to configure a separate API key for agents.
Future<String> generateWithLumaraCloud({
  required String systemPrompt,
  required String userPrompt,
  int maxTokens = 1024,
}) async {
  await LumaraAPIConfig.instance.initialize();

  final groqKey = LumaraAPIConfig.instance.getApiKey(LLMProvider.groq);
  final hasGroqKey = groqKey != null && groqKey.trim().isNotEmpty;

  final firebaseReady = await FirebaseService.instance.ensureReady();
  final signedIn = FirebaseAuthService.instance.isSignedIn;

  // 1. Firebase proxy (Groq GPT-OSS 120B) when signed in – PRISM scrub/restore via lumaraSend
  if (firebaseReady && signedIn) {
    return await lumaraSend(
      system: systemPrompt,
      user: userPrompt,
      maxTokens: maxTokens,
      temperature: 0.7,
      skipTransformation: true,
    );
  }

  // 2. Direct Groq when API key is set — PRISM scrub before send, restore on response
  if (hasGroqKey) {
    final prismAdapter = PrismAdapter();
    final userPrism = prismAdapter.scrub(userPrompt);
    final systemPrism = systemPrompt.trim().isNotEmpty
        ? prismAdapter.scrub(systemPrompt)
        : PrismResult(scrubbedText: systemPrompt, reversibleMap: {}, findings: []);

    if (!prismAdapter.isSafeToSend(userPrism.scrubbedText) ||
        (systemPrompt.trim().isNotEmpty &&
            !prismAdapter.isSafeToSend(systemPrism.scrubbedText))) {
      throw const SecurityException(
        'SECURITY: PII still detected after PRISM scrubbing',
      );
    }

    final combinedMap = <String, String>{
      ...userPrism.reversibleMap,
      ...systemPrism.reversibleMap,
    };

    final groq = GroqService(apiKey: groqKey);
    final rawResponse = await groq.generateContent(
      prompt: userPrism.scrubbedText,
      systemPrompt: systemPrism.scrubbedText.isNotEmpty
          ? systemPrism.scrubbedText
          : null,
      maxTokens: maxTokens,
      model: GroqModel.gptOss120b,
      temperature: 0.7,
    );

    return PiiScrubber.restore(rawResponse, combinedMap);
  }

  throw StateError(
    'No cloud AI available. Sign in for proxy access, or add a Groq API key in Settings → LUMARA.',
  );
}

/// Returns true when the same cloud API LUMARA uses is available (proxy or Groq key).
Future<bool> isLumaraCloudAvailable() async {
  try {
    await LumaraAPIConfig.instance.initialize();
    final groqKey = LumaraAPIConfig.instance.getApiKey(LLMProvider.groq);
    if (groqKey != null && groqKey.trim().isNotEmpty) return true;
    final firebaseReady = await FirebaseService.instance.ensureReady();
    final signedIn = FirebaseAuthService.instance.isSignedIn;
    return firebaseReady && signedIn;
  } catch (_) {
    return false;
  }
}
