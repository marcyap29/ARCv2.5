// lib/arc/chat/services/lumara_cloud_generate.dart
// Single entry point for agent (and other) cloud inference using the same API as LUMARA chat:
// Firebase proxy (Groq) when signed in, else Groq API key, else Gemini.

import 'package:my_app/arc/chat/config/api_config.dart';
import 'package:my_app/arc/chat/services/groq_service.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/services/firebase_service.dart';
import 'package:my_app/services/gemini_send.dart';
import 'package:my_app/services/groq_send.dart';

/// Uses the same cloud API as LUMARA: proxy when signed in, else Groq key, else Gemini.
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

  // 1. Firebase proxy (Groq) when signed in – same path as LUMARA chat
  if (firebaseReady && signedIn) {
    try {
      return await groqSend(
        user: userPrompt,
        system: systemPrompt.isNotEmpty ? systemPrompt : null,
        temperature: 0.7,
        maxTokens: maxTokens,
      );
    } catch (e) {
      // Fallback to Gemini (proxy) if Groq proxy fails
      try {
        return await geminiSend(system: systemPrompt, user: userPrompt);
      } catch (_) {
        throw StateError(
          'Cloud AI failed. If you use LUMARA chat, try again or add a Groq/Gemini key in LUMARA settings.',
        );
      }
    }
  }

  // 2. Direct Groq when API key is set
  if (hasGroqKey) {
    try {
      final groq = GroqService(apiKey: groqKey);
      return await groq.generateContent(
        prompt: userPrompt,
        systemPrompt: systemPrompt.isNotEmpty ? systemPrompt : null,
        maxTokens: maxTokens,
        model: GroqModel.llama33_70b,
        temperature: 0.7,
        fallbackToMixtral: true,
      );
    } catch (e) {
      // Fallback to Gemini if Groq fails
      final geminiKey = LumaraAPIConfig.instance.getApiKey(LLMProvider.gemini);
      if (geminiKey != null && geminiKey.trim().isNotEmpty) {
        return await geminiSend(system: systemPrompt, user: userPrompt);
      }
      rethrow;
    }
  }

  // 3. Gemini (proxy or key, depending on app config)
  final geminiKey = LumaraAPIConfig.instance.getApiKey(LLMProvider.gemini);
  if (geminiKey != null && geminiKey.trim().isNotEmpty || (firebaseReady && signedIn)) {
    return await geminiSend(system: systemPrompt, user: userPrompt);
  }

  throw StateError(
    'No cloud AI available. Use the same as LUMARA: sign in for proxy, or add a Groq or Gemini key in Settings → LUMARA.',
  );
}

/// Returns true when the same cloud API LUMARA uses is available (proxy or key).
Future<bool> isLumaraCloudAvailable() async {
  try {
    await LumaraAPIConfig.instance.initialize();
    final groqKey = LumaraAPIConfig.instance.getApiKey(LLMProvider.groq);
    final geminiKey = LumaraAPIConfig.instance.getApiKey(LLMProvider.gemini);
    if (groqKey != null && groqKey.trim().isNotEmpty) return true;
    if (geminiKey != null && geminiKey.trim().isNotEmpty) return true;
    final firebaseReady = await FirebaseService.instance.ensureReady();
    final signedIn = FirebaseAuthService.instance.isSignedIn;
    return firebaseReady && signedIn;
  } catch (_) {
    return false;
  }
}
