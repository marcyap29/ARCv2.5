// lib/arc/chat/services/lumara_cloud_generate.dart
// Writing & Research agents: Gemini-first via [lumaraSend] (forceGeminiPrimary), then Groq/Ollama fallbacks.
// SECURITY: PII scrub/restore via [lumaraSend].
//
// Optional: [generateWithSwarmSpaceGemini] for callers that want the SwarmSpace gemini-flash plugin.

import 'package:my_app/arc/chat/config/api_config.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/services/firebase_service.dart';
import 'package:my_app/services/gemini_send.dart';
import 'package:my_app/services/swarmspace/prism_service.dart';
import 'package:my_app/services/swarmspace/swarmspace_client.dart';

/// Writing & Research agents — **Gemini first** (same routing as long-context chat), then fallbacks.
Future<String> generateForAgents({
  required String systemPrompt,
  required String userPrompt,
  int maxTokens = 1024,
}) async {
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

  final prismResult = await PrismService.instance.authoriseAndCall(
    pluginId: 'gemini-flash',
    params: {
      'system': systemPrompt,
      'user': userPrompt,
      'max_tokens': maxTokens,
      'temperature': 0.7,
    },
    context: null,
  );
  if (prismResult.isDenied) return null;
  final result = prismResult.result!;

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

/// Same stack as LUMARA [lumaraSend]: Gemini first for agents, then Groq/Ollama fallbacks.
Future<String> generateWithLumaraCloud({
  required String systemPrompt,
  required String userPrompt,
  int maxTokens = 1024,
}) async {
  await LumaraAPIConfig.instance.initialize();
  return lumaraSend(
    system: systemPrompt,
    user: userPrompt,
    maxTokens: maxTokens,
    temperature: 0.7,
    skipTransformation: true,
    forceGeminiPrimary: true,
  );
}

/// True when agent inference can run: signed-in proxy, Groq key, or Gemini key.
Future<bool> isLumaraCloudAvailable() async {
  try {
    await LumaraAPIConfig.instance.initialize();
    final groqKey = LumaraAPIConfig.instance.getApiKey(LLMProvider.groq);
    if (groqKey != null && groqKey.trim().isNotEmpty) return true;
    final geminiKey = LumaraAPIConfig.instance.getApiKey(LLMProvider.gemini);
    if (geminiKey != null && geminiKey.trim().isNotEmpty) return true;
    final firebaseReady = await FirebaseService.instance.ensureReady();
    final signedIn = FirebaseAuthService.instance.isSignedIn;
    return firebaseReady && signedIn;
  } catch (_) {
    return false;
  }
}
